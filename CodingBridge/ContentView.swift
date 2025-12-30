import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    /// API client for CLI Bridge - lazily initialized with settings
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
    @ObservedObject private var sessionStore = SessionStore.shared
    @StateObject private var commandStore = CommandStore.shared
    @ObservedObject private var archivedStore = ArchivedProjectsStore.shared
    @ObservedObject private var projectCache = ProjectCache.shared

    // Project rename state
    @State private var projectToRename: Project?
    @State private var renameText = ""

    // Project detail sheet
    @State private var projectToShowDetail: Project?

    // Git status tracking per project path
    // Local dict used during refresh to show .checking state
    @State private var gitStatuses: [String: GitStatus] = [:]
    @State private var isCheckingGitStatus = false
    @State private var gitRefreshError: String?
    @State private var showGitRefreshError = false

    /// Returns the effective git status for a project path.
    /// Prefers local state when .checking (during refresh), otherwise uses ProjectCache.
    /// This ensures ChatView updates propagate back to the project list.
    private func effectiveGitStatus(for path: String) -> GitStatus {
        let localStatus = gitStatuses[path]
        // During refresh, show .checking from local state
        if localStatus == .checking {
            return .checking
        }
        // Otherwise prefer cache (which ChatView updates)
        return projectCache.cachedGitStatuses[path] ?? localStatus ?? .unknown
    }

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
                    initialGitStatus: effectiveGitStatus(for: project.path),
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
            GlobalSearchView(
                projects: projects,
                serverURL: settings.serverURL,
                onSelect: { result in
                    // Navigate to the session from search result
                    if let project = projects.first(where: { $0.path == result.projectPath }) {
                        selectedProject = project
                        // Set the session ID so ChatView loads this session
                        sessionStore.setSelectedSession(result.sessionId, for: project.path)
                        showGlobalSearch = false
                    }
                }
            )
            .environmentObject(settings)
        }
        .sheet(isPresented: $showCommands) {
            CommandsView(commandStore: commandStore)
                .environmentObject(settings)
        }
        .sheet(item: $projectToShowDetail) { project in
            ProjectDetailView(
                project: project,
                onSelectSession: { sessionId in
                    // Could navigate to session
                    projectToShowDetail = nil
                }
            )
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
        .task {
            await loadProjectsWithCache()
        }
    }

    // MARK: - Cached Loading Flow

    /// Load projects with cache-first strategy for instant startup
    private func loadProjectsWithCache() async {
        let startupStart = CFAbsoluteTimeGetCurrent()
        log.info("[Startup] Beginning loadProjectsWithCache, hasCache=\(projectCache.hasCachedData)")

        // Step 1: Immediately show cached data if available
        if projectCache.hasCachedData {
            projects = projectCache.cachedProjects
            gitStatuses = projectCache.cachedGitStatuses
            isLoading = false
            isFetchingFresh = true
            loadingStatus = "Updating..."
            log.info("[Startup] Loaded \(projects.count) projects from cache")
        }

        // Step 2: Fetch fresh project list from server
        let apiStart = CFAbsoluteTimeGetCurrent()
        await loadProjects()
        log.info("[Startup] loadProjects() took \(String(format: "%.2f", (CFAbsoluteTimeGetCurrent() - apiStart) * 1000))ms")

        // Step 3: Defer heavy operations to after UI is shown
        // Use a small delay to let the UI render first
        if !projects.isEmpty {
            // Start git checks in background (progressive loading)
            loadingStatus = "Checking git..."
            let gitStart = CFAbsoluteTimeGetCurrent()
            await checkAllGitStatusesProgressive()
            log.info("[Startup] Git status checks took \(String(format: "%.2f", (CFAbsoluteTimeGetCurrent() - gitStart) * 1000))ms")

            // Discover sub-repos (lower priority)
            loadingStatus = "Scanning repos..."
            let repoStart = CFAbsoluteTimeGetCurrent()
            await discoverAllSubRepos()
            log.info("[Startup] Sub-repo discovery took \(String(format: "%.2f", (CFAbsoluteTimeGetCurrent() - repoStart) * 1000))ms")

            // Load session counts last
            loadingStatus = nil
            let sessionStart = CFAbsoluteTimeGetCurrent()
            await loadAllSessionCounts()
            log.info("[Startup] Session counts took \(String(format: "%.2f", (CFAbsoluteTimeGetCurrent() - sessionStart) * 1000))ms")

            // Save to cache for next startup
            projectCache.saveProjects(projects, gitStatuses: gitStatuses)
        }

        isFetchingFresh = false
        loadingStatus = nil
        log.info("[Startup] Total startup time: \(String(format: "%.2f", (CFAbsoluteTimeGetCurrent() - startupStart) * 1000))ms")
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

    /// All projects from cli-bridge (no filtering needed - server returns the appropriate list)
    private var workspaceProjects: [Project] {
        // cli-bridge returns all projects with Claude sessions, no client-side filtering needed
        projects
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
            gitStatus: effectiveGitStatus(for: project.path),
            sessionCount: sessionStore.displaySessionCount(for: project.path),
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

            Divider()

            Button {
                projectToShowDetail = project
            } label: {
                Label("View Details", systemImage: "info.circle")
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
            let apiClient = CLIBridgeAPIClient(serverURL: settings.serverURL)
            let cliProjects = try await apiClient.fetchProjects()
            // Convert CLIProject to Project for existing views
            projects = cliProjects.map { cliProject in
                Project(
                    name: cliProject.name,
                    path: cliProject.path,
                    displayName: nil,
                    fullPath: cliProject.path,
                    sessions: nil,
                    sessionMeta: nil
                )
            }

            // Extract git statuses from cli-bridge response
            for cliProject in cliProjects {
                if let git = cliProject.git {
                    gitStatuses[cliProject.path] = git.toGitStatus
                }
            }

            isLoading = false
        } catch CLIBridgeAPIError.unauthorized {
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

        // Skip SSH git checks if SSH is not configured
        // Git status is provided by cli-bridge in the project list response
        guard settings.isSSHConfigured else {
            log.info("[Git] SSH not configured, skipping git status checks (using cli-bridge data)")
            return
        }

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

        // Skip SSH git checks if SSH is not configured
        // Git status is provided by cli-bridge in the project list response
        guard settings.isSSHConfigured else {
            log.info("[Git] SSH not configured, skipping progressive git status checks (using cli-bridge data)")
            return
        }

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
        // Skip if SSH not configured (cli-bridge doesn't provide sub-repo discovery yet)
        guard settings.isSSHConfigured else { return }
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

    /// Load accurate session counts for all projects via SessionStore
    /// Note: Session counts now come from the API Project response, so this is a no-op.
    /// Individual sessions are loaded when entering ChatView.
    private func loadAllSessionCounts() async {
        // Session counts come from API Project response, no separate loading needed
    }
}
#Preview {
    ContentView()
        .environmentObject(AppSettings())
        .preferredColorScheme(.dark)
}
