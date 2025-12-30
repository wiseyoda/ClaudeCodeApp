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
    @ObservedObject private var sessionStore = SessionStore.shared
    @StateObject private var commandStore = CommandStore.shared
    @ObservedObject private var archivedStore = ArchivedProjectsStore.shared
    @ObservedObject private var projectCache = ProjectCache.shared
    @ObservedObject private var projectSettingsStore = ProjectSettingsStore.shared

    // Project rename state
    @State private var projectToRename: Project?
    @State private var renameText = ""

    // Project detail sheet
    @State private var projectToShowDetail: Project?

    // Git status tracking per project path
    // Local dict used during refresh to show .checking state
    @State private var gitStatuses: [String: GitStatus] = [:]
    @State private var branchNames: [String: String] = [:]
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
        // Adaptive layout: iPhone uses HomeView, iPad uses NavigationSplitView
        Group {
            if horizontalSizeClass == .compact {
                // iPhone: New glass card grid layout
                compactLayout
            } else {
                // iPad: Keep NavigationSplitView
                regularLayout
            }
        }
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

    // MARK: - Adaptive Layout Views

    /// iPhone layout: HomeView with glass card grid
    @ViewBuilder
    private var compactLayout: some View {
        NavigationStack {
            HomeView(
                projects: projects,
                gitStatuses: gitStatuses,
                branchNames: projectCache.cachedBranchNames.merging(branchNames) { _, new in new },
                isLoading: isLoading,
                onRefresh: {
                    await loadProjects()
                    // Note: loadProjects() already extracts git statuses from API
                    if !projects.isEmpty {
                        await loadAllSessionCounts()
                    }
                },
                onSelectProject: { project in
                    selectedProject = project
                },
                onSelectSession: { session in
                    // Find or create project for this session
                    if let project = projects.first(where: { $0.path == session.projectPath }) {
                        // Set session so ChatView loads it
                        sessionStore.setSelectedSession(session.id, for: project.path)
                        selectedProject = project
                    } else {
                        // Project not in list - create temporary one
                        let projectName = (session.projectPath as NSString).lastPathComponent
                        let project = Project(
                            name: projectName,
                            path: session.projectPath,
                            displayName: nil,
                            fullPath: session.projectPath,
                            sessions: nil,
                            sessionMeta: nil
                        )
                        sessionStore.setSelectedSession(session.id, for: project.path)
                        selectedProject = project
                    }
                },
                onRenameProject: { project in
                    projectToRename = project
                    renameText = ProjectNamesStore.shared.getName(for: project.path) ?? project.title
                },
                onDeleteProject: { project in
                    projectToDelete = project
                }
            )
            .navigationDestination(for: Project.self) { project in
                ChatView(
                    project: project,
                    initialGitStatus: effectiveGitStatus(for: project.path),
                    onSessionsChanged: {
                        Task { await loadProjects() }
                    }
                )
                .toolbar(.hidden, for: .tabBar)
            }
            .navigationDestination(isPresented: Binding(
                get: { selectedProject != nil },
                set: { if !$0 { selectedProject = nil } }
            )) {
                if let project = selectedProject {
                    ChatView(
                        project: project,
                        initialGitStatus: effectiveGitStatus(for: project.path),
                        onSessionsChanged: {
                            Task { await loadProjects() }
                        }
                    )
                    .toolbar(.hidden, for: .tabBar)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showGlobalSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task {
                            await loadProjects()
                            // Note: loadProjects() already extracts git statuses from API
                            if !projects.isEmpty {
                                await loadAllSessionCounts()
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                    }
                }
            }
        }
    }

    /// iPad layout: NavigationSplitView with sidebar
    @ViewBuilder
    private var regularLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarContent
                .navigationTitle("Coding Bridge")
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 16) {
                            Button {
                                showGlobalSearch = true
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                            }

                            Button {
                                showCommands = true
                            } label: {
                                Image(systemName: "text.book.closed")
                                    .foregroundColor(CLITheme.yellow(for: colorScheme))
                            }

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

                            Button {
                                showTerminal = true
                            } label: {
                                Image(systemName: "terminal")
                                    .foregroundColor(CLITheme.cyan(for: colorScheme))
                            }

                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gear")
                                    .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                            }
                        }
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            Task {
                                await loadProjects()
                                // Note: loadProjects() already extracts git statuses from API
                                if !projects.isEmpty {
                                    await loadAllSessionCounts()
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                        }
                    }
                }
        } detail: {
            if isLoading && !projectCache.hasCachedData {
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
    }

    // MARK: - Cached Loading Flow

    /// Load projects with cache-first strategy for instant startup
    /// Uses fire-and-forget background tasks for API calls to avoid blocking
    private func loadProjectsWithCache() async {
        let startupStart = CFAbsoluteTimeGetCurrent()
        log.info("[Startup] Beginning loadProjectsWithCache, hasCache=\(projectCache.hasCachedData)")

        // Step 1: INSTANT - Load from cache (projects, git, branches, session counts)
        if projectCache.hasCachedData {
            projects = projectCache.cachedProjects
            gitStatuses = projectCache.cachedGitStatuses
            branchNames = projectCache.cachedBranchNames
            // Session counts are now in ProjectCache too - HomeView will read from there
            isLoading = false
            isFetchingFresh = true
            log.info("[Startup] Loaded \(projects.count) projects from cache in \(String(format: "%.1f", (CFAbsoluteTimeGetCurrent() - startupStart) * 1000))ms")
        }

        // Step 2: BACKGROUND - Fire all API calls without blocking
        // These run in parallel and update state when complete
        Task { @MainActor in
            await refreshProjectsInBackground()
        }

        // UI is now fully responsive - background tasks will update as they complete
        log.info("[Startup] UI ready in \(String(format: "%.1f", (CFAbsoluteTimeGetCurrent() - startupStart) * 1000))ms")
    }

    /// Background refresh of all project data - runs without blocking UI
    private func refreshProjectsInBackground() async {
        let refreshStart = CFAbsoluteTimeGetCurrent()

        // Fetch fresh project list
        await loadProjects()
        log.info("[Background] loadProjects() took \(String(format: "%.1f", (CFAbsoluteTimeGetCurrent() - refreshStart) * 1000))ms")

        guard !projects.isEmpty else {
            isFetchingFresh = false
            return
        }

        // Run remaining tasks in parallel
        await withTaskGroup(of: Void.self) { group in
            // Sub-repo discovery
            group.addTask { @MainActor in
                let start = CFAbsoluteTimeGetCurrent()
                await self.discoverAllSubRepos()
                log.info("[Background] Sub-repo discovery took \(String(format: "%.1f", (CFAbsoluteTimeGetCurrent() - start) * 1000))ms")
            }

            // Session counts
            group.addTask { @MainActor in
                let start = CFAbsoluteTimeGetCurrent()
                await self.loadAllSessionCounts()
                log.info("[Background] Session counts took \(String(format: "%.1f", (CFAbsoluteTimeGetCurrent() - start) * 1000))ms")

                // Save session counts to cache for next startup
                self.saveSessionCountsToCache()
            }
        }

        // Save updated data to cache
        projectCache.saveProjects(projects, gitStatuses: gitStatuses, branchNames: branchNames)

        isFetchingFresh = false
        log.info("[Background] Total refresh took \(String(format: "%.1f", (CFAbsoluteTimeGetCurrent() - refreshStart) * 1000))ms")
    }

    /// Save current session counts from SessionStore to ProjectCache
    private func saveSessionCountsToCache() {
        var counts: [String: Int] = [:]
        for project in projects {
            if sessionStore.hasCountsLoaded(for: project.path) {
                counts[project.path] = sessionStore.userSessionCount(for: project.path)
            }
        }
        if !counts.isEmpty {
            projectCache.updateSessionCounts(counts)
        }
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
            // Note: loadProjects() already extracts git statuses from API
            if !projects.isEmpty {
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
                    sessionMeta: cliProject.sessionCount.map {
                        ProjectSessionMeta(hasMore: false, total: $0)
                    }
                )
            }

            // Extract git statuses and branch names from cli-bridge response
            for cliProject in cliProjects {
                if let git = cliProject.git {
                    gitStatuses[cliProject.path] = git.toGitStatus
                    if let branch = git.branch {
                        branchNames[cliProject.path] = branch
                    }
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
        do {
            let apiClient = CLIBridgeAPIClient(serverURL: settings.serverURL)
            try await apiClient.deleteProject(projectPath: project.path, deleteFiles: true)

            await MainActor.run {
                projects.removeAll { $0.id == project.id }
                gitStatuses.removeValue(forKey: project.path)
                projectToDelete = nil
            }
        } catch {
            log.error("[Projects] Failed to delete project: \(error)")
            await MainActor.run {
                projectToDelete = nil
            }
        }
    }

    // MARK: - Git Status Checking

    /// Refresh git status for all projects via cli-bridge API
    private func checkAllGitStatuses() async {
        guard !isCheckingGitStatus else { return }

        isCheckingGitStatus = true

        // Mark all as checking
        for project in projects {
            gitStatuses[project.path] = .checking
        }

        do {
            let apiClient = CLIBridgeAPIClient(serverURL: settings.serverURL)
            let cliProjects = try await apiClient.fetchProjects()

            // Extract git statuses and branch names from cli-bridge response
            for cliProject in cliProjects {
                if let git = cliProject.git {
                    gitStatuses[cliProject.path] = git.toGitStatus
                    projectCache.updateGitStatus(for: cliProject.path, status: git.toGitStatus, branchName: git.branch)
                    if let branch = git.branch {
                        branchNames[cliProject.path] = branch
                    }
                }
            }
        } catch {
            log.error("[Git] Failed to fetch git statuses from API: \(error)")
            gitRefreshError = "Failed to refresh git status: \(error.localizedDescription)"
            showGitRefreshError = true
        }

        isCheckingGitStatus = false
    }

    /// Check git status for all projects with progressive UI updates
    /// For API-based refresh, this behaves the same as checkAllGitStatuses
    private func checkAllGitStatusesProgressive() async {
        await checkAllGitStatuses()
    }

    /// Refresh git status for a single project via cli-bridge API
    private func refreshGitStatus(for project: Project) async {
        gitStatuses[project.path] = .checking

        do {
            let apiClient = CLIBridgeAPIClient(serverURL: settings.serverURL)
            let cliProjects = try await apiClient.fetchProjects()

            if let cliProject = cliProjects.first(where: { $0.path == project.path }),
               let git = cliProject.git {
                gitStatuses[project.path] = git.toGitStatus
                projectCache.updateGitStatus(for: project.path, status: git.toGitStatus, branchName: git.branch)
                if let branch = git.branch {
                    branchNames[project.path] = branch
                }
            } else {
                gitStatuses[project.path] = .notGitRepo
            }
        } catch {
            log.error("[Git] Failed to refresh git status for \(project.path): \(error)")
            gitStatuses[project.path] = .error(error.localizedDescription)
        }
    }

    // MARK: - Multi-Repo (Monorepo) Support

    /// Discover sub-repos for all projects in parallel
    private func discoverAllSubRepos() async {
        // Filter to only projects with subrepo discovery enabled (opt-in, default off)
        let enabledProjects = projects.filter { projectSettingsStore.isSubrepoDiscoveryEnabled(for: $0.path) }

        guard !enabledProjects.isEmpty else {
            log.debug("[MultiRepo] No projects have subrepo discovery enabled, skipping")
            return
        }

        log.debug("[MultiRepo] Discovering sub-repos for \(enabledProjects.count) projects")
        let apiClient = CLIBridgeAPIClient(serverURL: settings.serverURL)

        // Mark enabled projects as scanning
        await MainActor.run {
            for project in enabledProjects {
                multiRepoStatuses[project.path] = MultiRepoStatus(isScanning: true)
            }
        }

        // Discover in parallel using TaskGroup
        await withTaskGroup(of: (String, [SubRepo]?).self) { group in
            for project in enabledProjects {
                group.addTask {
                    do {
                        let subRepoInfos = try await apiClient.discoverSubRepos(projectPath: project.path)
                        let subRepos = subRepoInfos.map { info in
                            SubRepo(
                                relativePath: info.relativePath,
                                fullPath: "\(project.path)/\(info.relativePath)",
                                status: info.git.toGitStatus
                            )
                        }
                        return (project.path, subRepos)
                    } catch {
                        log.error("[MultiRepo] Failed to discover sub-repos for \(project.path): \(error)")
                        return (project.path, nil)
                    }
                }
            }

            // Collect results
            for await (projectPath, subRepos) in group {
                await MainActor.run {
                    if let subRepos = subRepos {
                        multiRepoStatuses[projectPath] = MultiRepoStatus(subRepos: subRepos)
                    } else {
                        multiRepoStatuses[projectPath] = MultiRepoStatus()
                    }
                }
            }
        }
    }

    /// Check git status for all sub-repos of a project (refreshes via discovery)
    private func checkSubRepoStatuses(for projectPath: String, subRepoPaths: [String]) async {
        let apiClient = CLIBridgeAPIClient(serverURL: settings.serverURL)

        do {
            let subRepoInfos = try await apiClient.discoverSubRepos(projectPath: projectPath)
            let subRepos = subRepoInfos.map { info in
                SubRepo(
                    relativePath: info.relativePath,
                    fullPath: "\(projectPath)/\(info.relativePath)",
                    status: info.git.toGitStatus
                )
            }

            await MainActor.run {
                multiRepoStatuses[projectPath] = MultiRepoStatus(subRepos: subRepos)
            }
        } catch {
            log.error("[MultiRepo] Failed to check sub-repo statuses for \(projectPath): \(error)")
        }
    }

    /// Refresh a single sub-repo's status (refreshes all sub-repos for the project)
    private func refreshSubRepoStatus(project: Project, subRepo: SubRepo) async {
        await refreshAllSubRepos(project: project)
    }

    /// Refresh all sub-repos for a project
    private func refreshAllSubRepos(project: Project) async {
        let apiClient = CLIBridgeAPIClient(serverURL: settings.serverURL)

        await MainActor.run {
            if var status = multiRepoStatuses[project.path] {
                status.isScanning = true
                multiRepoStatuses[project.path] = status
            }
        }

        do {
            let subRepoInfos = try await apiClient.discoverSubRepos(projectPath: project.path)
            let subRepos = subRepoInfos.map { info in
                SubRepo(
                    relativePath: info.relativePath,
                    fullPath: "\(project.path)/\(info.relativePath)",
                    status: info.git.toGitStatus
                )
            }

            await MainActor.run {
                multiRepoStatuses[project.path] = MultiRepoStatus(subRepos: subRepos)
            }
        } catch {
            log.error("[MultiRepo] Failed to refresh sub-repos for \(project.path): \(error)")
            await MainActor.run {
                if var status = multiRepoStatuses[project.path] {
                    status.isScanning = false
                    multiRepoStatuses[project.path] = status
                }
            }
        }
    }

    /// Pull a single sub-repo
    private func pullSubRepo(project: Project, subRepo: SubRepo) async {
        let apiClient = CLIBridgeAPIClient(serverURL: settings.serverURL)

        do {
            let _ = try await apiClient.pullSubRepo(
                projectPath: project.path,
                relativePath: subRepo.relativePath
            )
            // Refresh status after pull
            await refreshAllSubRepos(project: project)
        } catch {
            log.error("[MultiRepo] Failed to pull sub-repo \(subRepo.relativePath): \(error)")
        }
    }

    /// Pull all sub-repos that are behind
    private func pullAllBehindSubRepos(project: Project) async {
        guard let multiRepoStatus = multiRepoStatuses[project.path] else { return }

        let behindSubRepos = multiRepoStatus.subRepos.filter { subRepo in
            if case .behind = subRepo.status { return true }
            return false
        }

        for subRepo in behindSubRepos {
            await pullSubRepo(project: project, subRepo: subRepo)
        }
    }

    // MARK: - Session Count Loading

    /// Load accurate session counts for all projects via SessionStore
    /// Calls the /sessions/count API for each project to get user/agent/helper breakdown.
    /// Individual sessions are loaded when entering ChatView.
    private func loadAllSessionCounts() async {
        // Ensure SessionStore is configured with repository before loading counts
        sessionStore.configure(with: settings)

        // Load session counts from the dedicated count API endpoint for each project
        // This provides accurate user/agent/helper breakdown for display
        await withTaskGroup(of: Void.self) { group in
            for project in projects {
                group.addTask {
                    await sessionStore.loadSessionCounts(for: project.path)
                }
            }
        }
    }
}
#Preview {
    ContentView()
        .environmentObject(AppSettings())
        .preferredColorScheme(.dark)
}
