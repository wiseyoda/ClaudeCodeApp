import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @StateObject private var apiClient = APIClient()
    @State private var projects: [Project] = []
    @State private var isLoading = true
    @State private var isFetchingFresh = false  // True when fetching fresh data (but have cache)
    @State private var errorMessage: String?
    @State private var showSettings = false
    @State private var showTerminal = false
    @State private var showCloneProject = false
    @State private var showNewProject = false
    @State private var projectToDelete: Project?
    @State private var showGlobalSearch = false
    @State private var showCommands = false
    @ObservedObject private var sshManager = SSHManager.shared
    @ObservedObject private var sessionManager = SessionManager.shared
    @StateObject private var commandStore = CommandStore.shared
    @ObservedObject private var archivedStore = ArchivedProjectsStore.shared
    @ObservedObject private var projectCache = ProjectCache.shared

    // Project rename state
    @State private var projectToRename: Project?
    @State private var renameText = ""

    // Git status tracking per project path
    @State private var gitStatuses: [String: GitStatus] = [:]
    @State private var isCheckingGitStatus = false
    @State private var gitRefreshError: String?
    @State private var showGitRefreshError = false

    // Multi-repo (monorepo) tracking
    @State private var multiRepoStatuses: [String: MultiRepoStatus] = [:]
    @State private var expandedProjects: Set<String> = []

    // Selected project for NavigationSplitView
    @State private var selectedProject: Project?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    // Progressive loading state
    @State private var loadingStatus: String?

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar: Project list
            sidebarContent
                .navigationTitle("Coding Bridge")
                // iOS 26+: Use Material for glass-compatible toolbar
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    // iOS 26+: ToolbarSpacer can be used between items for flexible layout
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 16) {
                            Button {
                                showGlobalSearch = true
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                            }
                            .accessibilityLabel("Search all sessions")
                            .accessibilityHint("Search across all projects and sessions")

                            Button {
                                showCommands = true
                            } label: {
                                Image(systemName: "text.book.closed")
                                    .foregroundColor(CLITheme.yellow(for: colorScheme))
                            }
                            .accessibilityLabel("Saved commands")
                            .accessibilityHint("Open saved commands library")

                            Menu {
                                Button {
                                    showNewProject = true
                                } label: {
                                    Label("Create Empty Project", systemImage: "folder.badge.plus")
                                }
                                Button {
                                    showCloneProject = true
                                } label: {
                                    Label("Clone from GitHub", systemImage: "arrow.down.doc")
                                }
                            } label: {
                                Image(systemName: "plus")
                                    .foregroundColor(CLITheme.green(for: colorScheme))
                            }
                            .accessibilityLabel("New project")
                            .accessibilityHint("Create or clone a project")

                            Button {
                                showTerminal = true
                            } label: {
                                Image(systemName: "terminal")
                                    .foregroundColor(CLITheme.cyan(for: colorScheme))
                            }
                            .accessibilityLabel("SSH Terminal")
                            .accessibilityHint("Open SSH terminal to connect to server")

                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gear")
                                    .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                            }
                            .accessibilityLabel("Settings")
                            .accessibilityHint("Open app settings")
                        }
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            Task {
                                await loadProjects()
                                if !projects.isEmpty {
                                    await checkAllGitStatuses()
                                    await loadAllSessionCounts()
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                        }
                        .accessibilityLabel("Refresh projects")
                        .accessibilityHint("Reload project list and git statuses")
                    }
                }
        } detail: {
            // Detail: Chat view or placeholder
            if isLoading && !projectCache.hasCachedData {
                // Show loading in detail pane too (iPhone shows detail first)
                loadingView
            } else if let project = selectedProject {
                ChatView(
                    project: project,
                    apiClient: apiClient,
                    initialGitStatus: gitStatuses[project.path] ?? .unknown,
                    onSessionsChanged: {
                        Task { await loadProjects() }
                    }
                )
            } else {
                noProjectSelectedView
            }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showCloneProject) {
            CloneProjectSheet {
                Task { await loadProjects() }
            }
        }
        .sheet(isPresented: $showNewProject) {
            NewProjectSheet {
                Task { await loadProjects() }
            }
        }
        .sheet(isPresented: $showGlobalSearch) {
            GlobalSearchView(projects: projects)
                .environmentObject(settings)
        }
        .sheet(isPresented: $showCommands) {
            CommandsView(commandStore: commandStore)
                .environmentObject(settings)
        }
        .alert("Delete Project?", isPresented: .init(
            get: { projectToDelete != nil },
            set: { if !$0 { projectToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                projectToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let project = projectToDelete {
                    Task { await deleteProject(project) }
                }
            }
        } message: {
            if let project = projectToDelete {
                Text("This will remove \"\(project.title)\" from your project list. The files will remain on the server.")
            }
        }
        .alert("Rename Project", isPresented: .init(
            get: { projectToRename != nil },
            set: { if !$0 { projectToRename = nil } }
        )) {
            TextField("Project name", text: $renameText)
            Button("Cancel", role: .cancel) {
                projectToRename = nil
                renameText = ""
            }
            Button("Save") {
                if let project = projectToRename {
                    ProjectNamesStore.shared.setName(renameText.isEmpty ? nil : renameText, for: project.path)
                }
                projectToRename = nil
                renameText = ""
            }
        } message: {
            Text("Enter a custom display name for this project")
        }
        .alert("Git Refresh Error", isPresented: $showGitRefreshError) {
            Button("OK", role: .cancel) {
                gitRefreshError = nil
            }
        } message: {
            if let error = gitRefreshError {
                Text(error)
            }
        }
        .fullScreenCover(isPresented: $showTerminal) {
            NavigationStack {
                TerminalView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                showTerminal = false
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text("Projects")
                                }
                                .foregroundColor(CLITheme.cyan(for: colorScheme))
                            }
                            .accessibilityLabel("Close terminal")
                            .accessibilityHint("Return to project list")
                        }
                    }
            }
        }
        .onAppear {
            apiClient.configure(with: settings)
        }
        .task {
            await loadProjectsWithCache()
        }
    }

    // MARK: - Cached Loading Flow

    /// Load projects with cache-first strategy for instant startup
    private func loadProjectsWithCache() async {
        // Step 1: Immediately show cached data if available
        if projectCache.hasCachedData {
            projects = projectCache.cachedProjects
            gitStatuses = projectCache.cachedGitStatuses
            isLoading = false
            isFetchingFresh = true
            loadingStatus = "Updating..."
            log.info("[Startup] Showing \(projects.count) cached projects instantly")
        }

        // Step 2: Fetch fresh project list from server
        await loadProjects()

        // Step 3: Defer heavy operations to after UI is shown
        // Use a small delay to let the UI render first
        if !projects.isEmpty {
            // Start git checks in background (progressive loading)
            loadingStatus = "Checking git..."
            await checkAllGitStatusesProgressive()

            // Discover sub-repos (lower priority)
            loadingStatus = "Scanning repos..."
            await discoverAllSubRepos()

            // Load session counts last
            loadingStatus = nil
            await loadAllSessionCounts()

            // Save to cache for next startup
            projectCache.saveProjects(projects, gitStatuses: gitStatuses)
        }

        isFetchingFresh = false
        loadingStatus = nil
    }

    // MARK: - Sidebar Content

    @ViewBuilder
    private var sidebarContent: some View {
        Group {
            if isLoading && !projectCache.hasCachedData {
                // First launch with no cache - show skeleton
                SkeletonProjectList()
            } else if let error = errorMessage, projects.isEmpty {
                // Error with no data to show
                errorView(error)
            } else {
                // Show project list (cached or fresh)
                ZStack(alignment: .top) {
                    projectListView

                    // Progressive loading banner
                    if let status = loadingStatus {
                        ProgressiveBanner(message: status)
                            .padding(.top, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: loadingStatus)
            }
        }
        .background(CLITheme.background(for: colorScheme))
    }

    // MARK: - No Project Selected Placeholder

    private var noProjectSelectedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))

            Text("Select a Project")
                .font(CLITheme.monoFont)
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))

            Text("Choose a project from the sidebar to start a conversation")
                .font(CLITheme.monoSmall)
                .foregroundColor(CLITheme.mutedText(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CLITheme.background(for: colorScheme))
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(CLITheme.yellow(for: colorScheme))

            Text("Loading projects...")
                .font(CLITheme.monoFont)
                .foregroundColor(CLITheme.yellow(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CLITheme.background(for: colorScheme))
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Text("! Error")
                .font(CLITheme.monoFont)
                .foregroundColor(CLITheme.red(for: colorScheme))

            Text(error)
                .font(CLITheme.monoSmall)
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button {
                    Task { await loadProjects() }
                } label: {
                    Text("[Retry]")
                        .font(CLITheme.monoFont)
                        .foregroundColor(CLITheme.cyan(for: colorScheme))
                }
                .accessibilityLabel("Retry")
                .accessibilityHint("Try loading projects again")

                Button {
                    showSettings = true
                } label: {
                    Text("[Settings]")
                        .font(CLITheme.monoFont)
                        .foregroundColor(CLITheme.cyan(for: colorScheme))
                }
                .accessibilityLabel("Settings")
                .accessibilityHint("Open settings to configure server connection")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CLITheme.background(for: colorScheme))
    }

    /// Workspace prefix to filter and simplify project paths
    private let workspacePrefix = "/home/dev/workspace/"

    /// Projects filtered to only those in the workspace directory
    private var workspaceProjects: [Project] {
        projects.filter { project in
            // Only include projects that are inside /home/dev/workspace/
            // This excludes /home/dev and /home/dev/workspace itself
            project.path.hasPrefix(workspacePrefix) && project.path.count > workspacePrefix.count
        }
    }

    /// Active (non-archived) projects sorted according to user preference
    private var activeProjects: [Project] {
        let active = workspaceProjects.filter { !archivedStore.isArchived($0.path) }
        return sortProjects(active)
    }

    /// Archived projects sorted according to user preference
    private var archivedProjects: [Project] {
        let archived = workspaceProjects.filter { archivedStore.isArchived($0.path) }
        return sortProjects(archived)
    }

    /// Sort projects according to user preference
    private func sortProjects(_ projectList: [Project]) -> [Project] {
        switch settings.projectSortOrder {
        case .date:
            // Sort by most recent activity (most recent first)
            return projectList.sorted { p1, p2 in
                let date1 = p1.sessions?.compactMap { $0.lastActivity }.max() ?? ""
                let date2 = p2.sessions?.compactMap { $0.lastActivity }.max() ?? ""
                return date1 > date2
            }
        case .name:
            // Sort alphabetically by title
            return projectList.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }

    private var projectListView: some View {
        List(selection: $selectedProject) {
            // Active Projects Section
            Section {
                ForEach(activeProjects) { project in
                    projectRow(for: project, isArchived: false)

                    // Sub-repos when expanded
                    if expandedProjects.contains(project.path),
                       let multiRepoStatus = multiRepoStatuses[project.path],
                       multiRepoStatus.hasSubRepos {
                        ForEach(multiRepoStatus.subRepos) { subRepo in
                            SubRepoRow(
                                subRepo: subRepo,
                                projectPath: project.path,
                                onRefresh: {
                                    Task { await refreshSubRepoStatus(project: project, subRepo: subRepo) }
                                },
                                onPull: {
                                    Task { await pullSubRepo(project: project, subRepo: subRepo) }
                                }
                            )
                            .listRowBackground(CLITheme.secondaryBackground(for: colorScheme).opacity(0.5))
                            .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                        }

                        // Action bar for batch operations
                        SubRepoActionBar(
                            multiRepoStatus: multiRepoStatus,
                            onPullAll: {
                                Task { await pullAllBehindSubRepos(project: project) }
                            },
                            onRefreshAll: {
                                Task { await refreshAllSubRepos(project: project) }
                            }
                        )
                        .listRowBackground(CLITheme.secondaryBackground(for: colorScheme).opacity(0.3))
                        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                    }
                }
            } header: {
                if !archivedProjects.isEmpty {
                    Text("Projects")
                        .font(CLITheme.monoSmall)
                        .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                }
            }

            // Archived Projects Section
            if !archivedProjects.isEmpty {
                Section {
                    ForEach(archivedProjects) { project in
                        projectRow(for: project, isArchived: true)
                    }
                } header: {
                    HStack {
                        Image(systemName: "archivebox")
                        Text("Archived")
                    }
                    .font(CLITheme.monoSmall)
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .refreshable {
            await loadProjects()
            if !projects.isEmpty {
                await checkAllGitStatuses()
                await discoverAllSubRepos()
                await loadAllSessionCounts()
            }
        }
        .background(CLITheme.background(for: colorScheme))
        .overlay {
            if projects.isEmpty {
                VStack(spacing: 8) {
                    Text("No projects found")
                        .font(CLITheme.monoFont)
                        .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                    Text("Open a project to see it here")
                        .font(CLITheme.monoSmall)
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
                }
            }
        }
    }

    @ViewBuilder
    private func projectRow(for project: Project, isArchived: Bool) -> some View {
        let isExpanded = expandedProjects.contains(project.path)
        let multiRepoStatus = multiRepoStatuses[project.path]

        ProjectRow(
            project: project,
            gitStatus: gitStatuses[project.path] ?? .unknown,
            sessionCount: sessionManager.sessionCount(for: project.path),
            isSelected: selectedProject?.id == project.id,
            isArchived: isArchived,
            multiRepoStatus: multiRepoStatus,
            isExpanded: isExpanded,
            onToggleExpand: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedProjects.contains(project.path) {
                        expandedProjects.remove(project.path)
                    } else {
                        expandedProjects.insert(project.path)
                    }
                }
            }
        )
        .tag(project)
        .listRowBackground(
            selectedProject?.id == project.id
                ? CLITheme.blue(for: colorScheme).opacity(0.2)
                : CLITheme.background(for: colorScheme)
        )
        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                projectToDelete = project
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                archivedStore.toggleArchive(project.path)
            } label: {
                if isArchived {
                    Label("Unarchive", systemImage: "tray.and.arrow.up")
                } else {
                    Label("Archive", systemImage: "archivebox")
                }
            }
            .tint(isArchived ? CLITheme.green(for: colorScheme) : CLITheme.yellow(for: colorScheme))
        }
        .contextMenu {
            Button {
                projectToRename = project
                renameText = ProjectNamesStore.shared.getName(for: project.path) ?? project.title
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Button {
                archivedStore.toggleArchive(project.path)
            } label: {
                if isArchived {
                    Label("Unarchive", systemImage: "tray.and.arrow.up")
                } else {
                    Label("Archive", systemImage: "archivebox")
                }
            }

            Button {
                Task { await refreshGitStatus(for: project) }
            } label: {
                Label("Refresh Git Status", systemImage: "arrow.triangle.2.circlepath")
            }

            Button(role: .destructive) {
                projectToDelete = project
            } label: {
                Label("Delete Project", systemImage: "trash")
            }
        }
    }

    private func loadProjects() async {
        // Only show full loading if we don't have cached data
        if !projectCache.hasCachedData {
            isLoading = true
        }
        errorMessage = nil

        do {
            let freshProjects = try await apiClient.fetchProjects()
            projects = freshProjects
            isLoading = false

            // If we were showing cached data, log the update
            if isFetchingFresh {
                log.info("[Startup] Updated to \(freshProjects.count) fresh projects")
            }
        } catch APIError.authenticationFailed {
            if !settings.apiKey.isEmpty {
                errorMessage = "API Key authentication failed.\n\nCheck your API key in Settings."
            } else {
                errorMessage = "Authentication failed.\n\nCheck credentials in Settings."
            }
            isLoading = false
        } catch {
            // If we have cached data, show it with a warning instead of blocking
            if projectCache.hasCachedData {
                log.warning("[Startup] Using cached projects due to network error: \(error)")
                // Keep showing cached projects, don't set error that would hide them
            } else {
                errorMessage = "Failed to connect to server.\n\nCheck Tailscale and server at:\n\(settings.serverURL)"
            }
            isLoading = false
        }
    }

    private func deleteProject(_ project: Project) async {
        // Remove project from Claude's project list (not the actual files)
        // The project directory in ~/.claude/projects/ is what makes it appear in the list
        let encodedPath = project.path.replacingOccurrences(of: "/", with: "-")
        // Shell-escape the encoded path to prevent command injection
        let escapedEncodedPath = shellEscape(encodedPath)
        // Use $HOME with double quotes for proper shell expansion, then append escaped path
        let claudeProjectDir = "\"$HOME/.claude/projects/\"\(escapedEncodedPath)"

        do {
            // Connect if needed and delete the Claude project directory
            let deleteCmd = "rm -rf \(claudeProjectDir)"
            _ = try await sshManager.executeCommandWithAutoConnect(deleteCmd, settings: settings)

            // Remove from local list immediately for responsive UI
            await MainActor.run {
                projects.removeAll { $0.id == project.id }
                gitStatuses.removeValue(forKey: project.path)
                projectToDelete = nil
            }
        } catch {
            // Still try to refresh the list
            await loadProjects()
        }
    }

    // MARK: - Git Status Checking

    /// Check git status for all projects in background
    private func checkAllGitStatuses() async {
        guard !isCheckingGitStatus else { return }
        isCheckingGitStatus = true

        // Mark all as checking
        for project in projects {
            gitStatuses[project.path] = .checking
        }

        // Pre-connect SSH once before parallel git checks to avoid race condition
        // where all concurrent tasks try to connect simultaneously
        if !sshManager.isConnected {
            do {
                try await sshManager.autoConnect(settings: settings)
            } catch {
                // SSH not available, all projects will show .unknown
                isCheckingGitStatus = false
                return
            }
        }

        // Check each project's git status concurrently but with some batching
        await withTaskGroup(of: (String, GitStatus).self) { group in
            for project in projects {
                group.addTask {
                    let status = await sshManager.checkGitStatusWithAutoConnect(
                        project.path,
                        settings: settings
                    )
                    return (project.path, status)
                }
            }

            for await (path, status) in group {
                gitStatuses[path] = status
            }
        }

        isCheckingGitStatus = false

        // Check for errors and notify user
        let errorStatuses = gitStatuses.compactMap { (path, status) -> String? in
            if case .error(let message) = status {
                let projectName = projects.first { $0.path == path }?.title ?? path
                return "\(projectName): \(message)"
            }
            return nil
        }

        if !errorStatuses.isEmpty {
            if errorStatuses.count == 1 {
                gitRefreshError = errorStatuses[0]
            } else {
                gitRefreshError = "\(errorStatuses.count) projects failed to refresh git status"
            }
            showGitRefreshError = true
        }
    }

    /// Check git status for all projects with progressive UI updates
    /// Unlike checkAllGitStatuses, this updates the UI as each status comes in
    private func checkAllGitStatusesProgressive() async {
        guard !isCheckingGitStatus else { return }
        isCheckingGitStatus = true

        // Don't mark all as checking - let cached statuses show while we update
        // This provides a smoother visual experience

        // Pre-connect SSH once before parallel git checks
        if !sshManager.isConnected {
            do {
                try await sshManager.autoConnect(settings: settings)
            } catch {
                isCheckingGitStatus = false
                return
            }
        }

        // Check each project's git status concurrently
        // Update UI immediately as each result comes in (progressive loading)
        await withTaskGroup(of: (String, GitStatus).self) { group in
            for project in projects {
                group.addTask {
                    let status = await sshManager.checkGitStatusWithAutoConnect(
                        project.path,
                        settings: settings
                    )
                    return (project.path, status)
                }
            }

            // Progressive update: update UI as each status comes in
            for await (path, status) in group {
                gitStatuses[path] = status
                // Also update the cache progressively
                projectCache.updateGitStatus(for: path, status: status)
            }
        }

        isCheckingGitStatus = false

        // Silent error handling for progressive loading
        // Errors are shown in the UI via status indicators
    }

    /// Refresh git status for a single project
    private func refreshGitStatus(for project: Project) async {
        gitStatuses[project.path] = .checking
        let status = await sshManager.checkGitStatusWithAutoConnect(
            project.path,
            settings: settings
        )
        gitStatuses[project.path] = status
    }

    // MARK: - Multi-Repo (Monorepo) Support

    /// Discover sub-repos for all projects in background
    private func discoverAllSubRepos() async {
        guard sshManager.isConnected else { return }

        await withTaskGroup(of: (String, [String]).self) { group in
            for project in projects {
                group.addTask {
                    let subRepoPaths = await sshManager.discoverSubReposWithAutoConnect(
                        project.path,
                        maxDepth: 2,
                        settings: settings
                    )
                    return (project.path, subRepoPaths)
                }
            }

            for await (projectPath, subRepoPaths) in group {
                if !subRepoPaths.isEmpty {
                    // Create SubRepo objects with unknown status
                    let subRepos = subRepoPaths.map { relativePath in
                        SubRepo(
                            relativePath: relativePath,
                            fullPath: (projectPath as NSString).appendingPathComponent(relativePath),
                            status: .unknown
                        )
                    }
                    multiRepoStatuses[projectPath] = MultiRepoStatus(subRepos: subRepos, isScanning: true)

                    // Now check their statuses
                    Task {
                        await checkSubRepoStatuses(for: projectPath, subRepoPaths: subRepoPaths)
                    }
                }
            }
        }
    }

    /// Check git status for all sub-repos of a project
    private func checkSubRepoStatuses(for projectPath: String, subRepoPaths: [String]) async {
        let statuses = await sshManager.checkMultiRepoStatusWithAutoConnect(
            projectPath,
            subRepoPaths: subRepoPaths,
            settings: settings
        )

        // Update the sub-repos with their statuses
        if var multiRepoStatus = multiRepoStatuses[projectPath] {
            multiRepoStatus.isScanning = false
            multiRepoStatus.subRepos = multiRepoStatus.subRepos.map { subRepo in
                var updated = subRepo
                if let status = statuses[subRepo.relativePath] {
                    updated.status = status
                }
                return updated
            }
            multiRepoStatuses[projectPath] = multiRepoStatus
        }
    }

    /// Refresh a single sub-repo's status
    private func refreshSubRepoStatus(project: Project, subRepo: SubRepo) async {
        guard var multiRepoStatus = multiRepoStatuses[project.path] else { return }

        // Mark as checking
        if let index = multiRepoStatus.subRepos.firstIndex(where: { $0.relativePath == subRepo.relativePath }) {
            multiRepoStatus.subRepos[index].status = .checking
            multiRepoStatuses[project.path] = multiRepoStatus
        }

        // Check status
        let status = await sshManager.checkGitStatusWithAutoConnect(
            subRepo.fullPath,
            settings: settings
        )

        // Update status
        if var updatedStatus = multiRepoStatuses[project.path],
           let index = updatedStatus.subRepos.firstIndex(where: { $0.relativePath == subRepo.relativePath }) {
            updatedStatus.subRepos[index].status = status
            multiRepoStatuses[project.path] = updatedStatus
        }
    }

    /// Refresh all sub-repos for a project
    private func refreshAllSubRepos(project: Project) async {
        guard let multiRepoStatus = multiRepoStatuses[project.path] else { return }

        let subRepoPaths = multiRepoStatus.subRepos.map { $0.relativePath }

        // Mark all as checking
        var updatedStatus = multiRepoStatus
        updatedStatus.isScanning = true
        updatedStatus.subRepos = updatedStatus.subRepos.map { subRepo in
            var updated = subRepo
            updated.status = .checking
            return updated
        }
        multiRepoStatuses[project.path] = updatedStatus

        // Check all statuses
        await checkSubRepoStatuses(for: project.path, subRepoPaths: subRepoPaths)
    }

    /// Pull a single sub-repo
    private func pullSubRepo(project: Project, subRepo: SubRepo) async {
        guard var multiRepoStatus = multiRepoStatuses[project.path],
              let index = multiRepoStatus.subRepos.firstIndex(where: { $0.relativePath == subRepo.relativePath }) else {
            return
        }

        // Mark as checking
        multiRepoStatus.subRepos[index].status = .checking
        multiRepoStatuses[project.path] = multiRepoStatus

        // Perform pull
        let success = await sshManager.pullSubRepo(
            project.path,
            relativePath: subRepo.relativePath,
            settings: settings
        )

        // Refresh status after pull
        let newStatus = await sshManager.checkGitStatusWithAutoConnect(
            subRepo.fullPath,
            settings: settings
        )

        // Update status
        if var updatedStatus = multiRepoStatuses[project.path],
           let updatedIndex = updatedStatus.subRepos.firstIndex(where: { $0.relativePath == subRepo.relativePath }) {
            updatedStatus.subRepos[updatedIndex].status = success ? newStatus : .error("Pull failed")
            multiRepoStatuses[project.path] = updatedStatus
        }
    }

    /// Pull all sub-repos that are behind
    private func pullAllBehindSubRepos(project: Project) async {
        guard var multiRepoStatus = multiRepoStatuses[project.path] else { return }

        let behindRepos = multiRepoStatus.subRepos.filter { $0.status.canAutoPull }
        guard !behindRepos.isEmpty else { return }

        // Mark all as checking
        multiRepoStatus.isScanning = true
        for subRepo in behindRepos {
            if let index = multiRepoStatus.subRepos.firstIndex(where: { $0.relativePath == subRepo.relativePath }) {
                multiRepoStatus.subRepos[index].status = .checking
            }
        }
        multiRepoStatuses[project.path] = multiRepoStatus

        // Pull all in parallel
        _ = await sshManager.pullAllBehindSubRepos(
            project.path,
            subRepos: behindRepos,
            settings: settings
        )

        // Refresh all statuses
        let subRepoPaths = behindRepos.map { $0.relativePath }
        await checkSubRepoStatuses(for: project.path, subRepoPaths: subRepoPaths)
    }

    // MARK: - Session Count Loading

    /// Load accurate session counts for all projects via SessionManager
    private func loadAllSessionCounts() async {
        let projectPaths = projects.map { $0.path }
        await sessionManager.loadSessionCounts(for: projectPaths, settings: settings)
    }
}

// MARK: - Project Row

struct ProjectRow: View {
    let project: Project
    let gitStatus: GitStatus
    var sessionCount: Int? = nil  // SSH-loaded count (overrides API count if set)
    var isSelected: Bool = false
    var isArchived: Bool = false
    var multiRepoStatus: MultiRepoStatus? = nil
    var isExpanded: Bool = false
    var onToggleExpand: (() -> Void)? = nil
    @Environment(\.colorScheme) var colorScheme

    /// Display name: custom name if set, otherwise project.title
    private var displayName: String {
        if let customName = ProjectNamesStore.shared.getName(for: project.path) {
            return customName
        }
        return project.title
    }

    /// Whether this project has a custom name
    private var hasCustomName: Bool {
        ProjectNamesStore.shared.hasCustomName(for: project.path)
    }

    /// Whether this project has sub-repos
    private var hasSubRepos: Bool {
        multiRepoStatus?.hasSubRepos ?? false
    }

    var body: some View {
        HStack(spacing: 8) {
            // Leading indicator: disclosure triangle for monorepos, or selection dot
            if hasSubRepos {
                Button {
                    onToggleExpand?()
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(CLITheme.green(for: colorScheme))
                        .frame(width: 14)
                }
                .buttonStyle(.plain)
            } else {
                Text(isSelected ? "●" : ">")
                    .font(CLITheme.monoFont)
                    .foregroundColor(isSelected ? CLITheme.blue(for: colorScheme) : CLITheme.green(for: colorScheme))
                    .opacity(isArchived ? 0.5 : 1)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(displayName)
                        .font(CLITheme.monoFont)
                        .foregroundColor(CLITheme.primaryText(for: colorScheme))
                        .opacity(isArchived ? 0.6 : 1)

                    // Custom name indicator
                    if hasCustomName {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(CLITheme.mutedText(for: colorScheme))
                    }

                    // Git status indicator
                    if !isArchived {
                        GitStatusIndicator(status: gitStatus)
                    }

                    // Multi-repo summary badge (when collapsed)
                    if hasSubRepos && !isExpanded, let status = multiRepoStatus {
                        MultiRepoSummaryBadge(status: status)
                    }
                }

                // Session count + sub-repo count
                HStack(spacing: 8) {
                    let count = sessionCount ?? project.displaySessions.count
                    if count > 0 {
                        Text("[\(count) sessions]")
                            .font(CLITheme.monoSmall)
                            .foregroundColor(CLITheme.cyan(for: colorScheme))
                            .opacity(isArchived ? 0.6 : 1)
                    }

                    if hasSubRepos, let status = multiRepoStatus {
                        Text("[\(status.subRepos.count) repos]")
                            .font(CLITheme.monoSmall)
                            .foregroundColor(CLITheme.mutedText(for: colorScheme))
                            .opacity(isArchived ? 0.6 : 1)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(CLITheme.monoSmall)
                .foregroundColor(CLITheme.mutedText(for: colorScheme))
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Multi-Repo Summary Badge

struct MultiRepoSummaryBadge: View {
    let status: MultiRepoStatus
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if status.isScanning {
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: 12, height: 12)
        } else if !status.summary.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: status.worstStatus.icon)
                    .font(.system(size: 10))
                Text(status.summary)
                    .font(CLITheme.monoSmall)
            }
            .foregroundColor(badgeColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.15))
            .cornerRadius(4)
        }
    }

    private var badgeColor: Color {
        switch status.worstStatus.colorName {
        case "green":
            return CLITheme.green(for: colorScheme)
        case "orange":
            return CLITheme.yellow(for: colorScheme)
        case "blue":
            return CLITheme.blue(for: colorScheme)
        case "cyan":
            return CLITheme.cyan(for: colorScheme)
        case "red":
            return CLITheme.red(for: colorScheme)
        default:
            return CLITheme.mutedText(for: colorScheme)
        }
    }
}

// MARK: - Sub-Repo Row

struct SubRepoRow: View {
    let subRepo: SubRepo
    let projectPath: String
    var onRefresh: (() -> Void)? = nil
    var onPull: (() -> Void)? = nil
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            // Indentation spacer
            Spacer()
                .frame(width: 24)

            // Tree connector
            Text("├─")
                .font(CLITheme.monoSmall)
                .foregroundColor(CLITheme.mutedText(for: colorScheme))

            // Sub-repo path
            Text(subRepo.relativePath)
                .font(CLITheme.monoSmall)
                .foregroundColor(CLITheme.primaryText(for: colorScheme))
                .lineLimit(1)

            // Status indicator
            GitStatusIndicator(status: subRepo.status)

            Spacer()

            // Action buttons
            if subRepo.status.canAutoPull {
                Button {
                    onPull?()
                } label: {
                    Text("Pull")
                        .font(CLITheme.monoSmall)
                        .foregroundColor(CLITheme.cyan(for: colorScheme))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(CLITheme.cyan(for: colorScheme).opacity(0.15))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }

            Button {
                onRefresh?()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12))
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .padding(.leading, 8)
        .background(CLITheme.secondaryBackground(for: colorScheme).opacity(0.5))
    }
}

// MARK: - Sub-Repo Action Bar

struct SubRepoActionBar: View {
    let multiRepoStatus: MultiRepoStatus
    var onPullAll: (() -> Void)? = nil
    var onRefreshAll: (() -> Void)? = nil
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Spacer()
                .frame(width: 32)

            if multiRepoStatus.pullableCount > 0 {
                Button {
                    onPullAll?()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                        Text("Pull All Behind (\(multiRepoStatus.pullableCount))")
                    }
                    .font(CLITheme.monoSmall)
                    .foregroundColor(CLITheme.cyan(for: colorScheme))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(CLITheme.cyan(for: colorScheme).opacity(0.15))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            Button {
                onRefreshAll?()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Refresh All")
                }
                .font(CLITheme.monoSmall)
                .foregroundColor(CLITheme.mutedText(for: colorScheme))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(CLITheme.secondaryBackground(for: colorScheme))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.leading, 8)
        .background(CLITheme.secondaryBackground(for: colorScheme).opacity(0.3))
    }
}

// MARK: - Git Status Indicator

struct GitStatusIndicator: View {
    let status: GitStatus
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Group {
            switch status {
            case .unknown:
                EmptyView()
            case .checking:
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 14, height: 14)
            case .notGitRepo:
                // Don't show anything for non-git repos
                EmptyView()
            default:
                Image(systemName: status.icon)
                    .font(.system(size: 12))
                    .foregroundColor(statusColor)
            }
        }
        .accessibilityLabel(status.accessibilityLabel)
    }

    private var statusColor: Color {
        switch status.colorName {
        case "green":
            return CLITheme.green(for: colorScheme)
        case "orange":
            return CLITheme.yellow(for: colorScheme)
        case "blue":
            return CLITheme.blue(for: colorScheme)
        case "cyan":
            return CLITheme.cyan(for: colorScheme)
        case "red":
            return CLITheme.red(for: colorScheme)
        default:
            return CLITheme.mutedText(for: colorScheme)
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) var dismiss
    @State private var showSSHKeyImport = false
    @State private var hasSSHKey = KeychainHelper.shared.hasSSHKey

    // Binding for font size picker
    private var fontSizeBinding: Binding<FontSizePreset> {
        Binding(
            get: { FontSizePreset(rawValue: settings.fontSize) ?? .medium },
            set: { settings.fontSize = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Appearance
                Section("Appearance") {
                    Picker("Theme", selection: Binding(
                        get: { settings.appTheme },
                        set: { settings.appTheme = $0 }
                    )) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }

                    Picker("Font Size", selection: fontSizeBinding) {
                        ForEach(FontSizePreset.allCases, id: \.rawValue) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }

                    // Font preview
                    HStack {
                        Text("Preview:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("The quick brown fox")
                            .font(settings.scaledFont(.body))
                    }
                }

                // Section 2: Claude Behavior
                Section {
                    Picker("Default Model", selection: Binding(
                        get: { settings.defaultModel },
                        set: { settings.defaultModel = $0 }
                    )) {
                        ForEach(ClaudeModel.allCases.filter { $0 != .custom }, id: \.self) { model in
                            HStack {
                                Image(systemName: model.icon)
                                Text(model.displayName)
                            }
                            .tag(model)
                        }
                    }

                    Picker("Default Mode", selection: Binding(
                        get: { settings.claudeMode },
                        set: { settings.claudeMode = $0 }
                    )) {
                        ForEach(ClaudeMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }

                    Toggle("Skip Permission Prompts", isOn: $settings.skipPermissions)
                } header: {
                    Text("Claude")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if settings.skipPermissions {
                            Label("All tool executions will be auto-approved without confirmation.", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                        Text("Model: \(settings.defaultModel.description)")
                            .foregroundStyle(.secondary)
                    }
                }

                // Section 3: Chat Display
                Section("Chat Display") {
                    Toggle("Show Thinking Blocks", isOn: $settings.showThinkingBlocks)
                    Toggle("Auto-scroll to Bottom", isOn: $settings.autoScrollEnabled)
                }

                // Section 4: Project List
                Section("Projects") {
                    Picker("Sort Order", selection: Binding(
                        get: { settings.projectSortOrder },
                        set: { settings.projectSortOrder = $0 }
                    )) {
                        ForEach(ProjectSortOrder.allCases, id: \.self) { order in
                            Text(order.displayName).tag(order)
                        }
                    }
                }

                // Section 5: Server Configuration
                Section {
                    TextField("URL", text: $settings.serverURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("Username", text: $settings.authUsername)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("Password", text: $settings.authPassword)
                } header: {
                    Text("Server")
                } footer: {
                    Text("Login credentials for claudecodeui web UI")
                }

                // Section 6: SSH Key (for iPhone - no access to ~/.ssh)
                Section {
                    HStack {
                        Text("SSH Key")
                        Spacer()
                        if hasSSHKey {
                            Label("Configured", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.subheadline)
                        } else {
                            Text("Not configured")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                    }

                    Button {
                        showSSHKeyImport = true
                    } label: {
                        Label(hasSSHKey ? "Replace SSH Key..." : "Import SSH Key...", systemImage: "key")
                    }

                    if hasSSHKey {
                        Button(role: .destructive) {
                            KeychainHelper.shared.clearAll()
                            hasSSHKey = false
                        } label: {
                            Label("Remove SSH Key", systemImage: "trash")
                        }
                    }
                } header: {
                    Text("SSH Key")
                } footer: {
                    Text("Import your private key for SSH authentication. Required for Git operations on iPhone.")
                }

                // Section 7: SSH Configuration (fallback/additional)
                Section {
                    TextField("Host", text: $settings.sshHost)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    HStack {
                        Text("Port")
                        Spacer()
                        TextField("22", value: $settings.sshPort, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    TextField("Username", text: $settings.sshUsername)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("Password (fallback)", text: $settings.sshPassword)
                } header: {
                    Text("SSH Connection")
                } footer: {
                    Text("SSH key is preferred. Password is used as fallback if no key is configured.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showSSHKeyImport) {
                SSHKeyImportSheet(onKeyImported: {
                    hasSSHKey = KeychainHelper.shared.hasSSHKey
                })
            }
        }
    }
}

// MARK: - SSH Key Import Sheet

struct SSHKeyImportSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var keyContent = ""
    @State private var passphrase = ""
    @State private var showFileImporter = false
    @State private var error: String?
    @State private var isValidating = false
    @State private var detectedKeyType: SSHKeyType?

    let onKeyImported: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Icon
                Image(systemName: "key.fill")
                    .font(.system(size: 48))
                    .foregroundColor(CLITheme.cyan(for: colorScheme))
                    .padding(.top, 24)

                Text("Import SSH Private Key")
                    .font(.headline)

                // Key content text editor
                VStack(alignment: .leading, spacing: 8) {
                    Text("Paste your private key:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextEditor(text: $keyContent)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 120, maxHeight: 200)
                        .padding(8)
                        .background(CLITheme.secondaryBackground(for: colorScheme))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .onChange(of: keyContent) { _, newValue in
                            validateKey(newValue)
                        }

                    if let keyType = detectedKeyType {
                        HStack {
                            Image(systemName: keyType.isSupported ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(keyType.isSupported ? .green : .red)
                            Text("Detected: \(keyType.description)")
                                .font(.caption)
                                .foregroundColor(keyType.isSupported ? .gray : .red)
                            if !keyType.isSupported {
                                Text("(not supported)")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .padding(.horizontal)

                // Import from file button
                Button {
                    showFileImporter = true
                } label: {
                    Label("Import from Files", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(CLITheme.secondaryBackground(for: colorScheme))
                        .cornerRadius(8)
                }
                .padding(.horizontal)

                // Passphrase (optional)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Passphrase (if encrypted):")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    SecureField("Optional", text: $passphrase)
                        .padding(12)
                        .background(CLITheme.secondaryBackground(for: colorScheme))
                        .cornerRadius(8)
                }
                .padding(.horizontal)

                // Error message
                if let error = error {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(error)
                    }
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.horizontal)
                }

                Spacer()

                // Save button
                Button {
                    saveKey()
                } label: {
                    Text("Save Key")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canSave ? CLITheme.cyan(for: colorScheme) : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(!canSave)
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(CLITheme.background(for: colorScheme))
            .navigationTitle("Import SSH Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.data, .text],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
        }
    }

    private var canSave: Bool {
        guard !keyContent.isEmpty else { return false }
        guard let keyType = detectedKeyType else { return false }
        return keyType.isSupported
    }

    private func validateKey(_ content: String) {
        guard !content.isEmpty else {
            detectedKeyType = nil
            error = nil
            return
        }

        if SSHKeyDetection.isValidKeyFormat(content) {
            do {
                detectedKeyType = try SSHKeyDetection.detectPrivateKeyType(from: content)
                error = nil
            } catch {
                detectedKeyType = .unknown
                self.error = "Could not detect key type"
            }
        } else {
            detectedKeyType = nil
            error = "Invalid key format. Key should start with '-----BEGIN'"
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Request access to the file
            guard url.startAccessingSecurityScopedResource() else {
                error = "Could not access the selected file"
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                keyContent = content
                validateKey(content)
            } catch {
                self.error = "Could not read file: \(error.localizedDescription)"
            }

        case .failure(let error):
            self.error = "File selection failed: \(error.localizedDescription)"
        }
    }

    private func saveKey() {
        guard canSave else { return }

        // Normalize the key content (fixes truncation issues from paste)
        let normalizedKey = SSHKeyDetection.normalizeSSHKey(keyContent)

        // Store key in Keychain
        if KeychainHelper.shared.storeSSHKey(normalizedKey) {
            // Store passphrase if provided
            if !passphrase.isEmpty {
                KeychainHelper.shared.storePassphrase(passphrase)
            } else {
                KeychainHelper.shared.deletePassphrase()
            }

            onKeyImported()
            dismiss()
        } else {
            error = "Failed to save key to Keychain"
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppSettings())
        .preferredColorScheme(.dark)
}
