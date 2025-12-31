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
    @State private var showToolTestHarness = false
    @ObservedObject private var sessionStore = SessionStore.shared
    private var commandStore = CommandStore.shared
    @ObservedObject private var archivedStore = ArchivedProjectsStore.shared
    @ObservedObject private var projectCache = ProjectCache.shared
    @ObservedObject private var projectSettingsStore = ProjectSettingsStore.shared

    // Project rename state
    @State private var projectToRename: Project?
    @State private var renameText = ""

    // Project detail sheet
    @State private var projectToShowDetail: Project?

    // Git status coordinator (manages git status, branch names, multi-repo state)
    @StateObject private var gitStatusCoordinator = GitStatusCoordinator()

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
        .alert("Git Refresh Error", isPresented: $gitStatusCoordinator.showGitRefreshError) {
            Button("OK", role: .cancel) {
                gitStatusCoordinator.gitRefreshError = nil
            }
        } message: {
            if let error = gitStatusCoordinator.gitRefreshError {
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
                gitStatuses: gitStatusCoordinator.gitStatuses,
                branchNames: projectCache.cachedBranchNames.merging(gitStatusCoordinator.branchNames) { _, new in new },
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
            // Note: Using isPresented binding for programmatic navigation from HomeView
            // (not value-based NavigationLink)
            .navigationDestination(isPresented: Binding(
                get: { selectedProject != nil },
                set: { if !$0 { selectedProject = nil } }
            )) {
                if let project = selectedProject {
                    ChatView(
                        project: project,
                        initialGitStatus: gitStatusCoordinator.effectiveGitStatus(for: project.path),
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showToolTestHarness = true
                    } label: {
                        Image(systemName: "hammer.circle")
                            .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                    }
                    .accessibilityLabel("Dev Tools")
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
            .sheet(isPresented: $showToolTestHarness) {
                ToolTestView()
                    .environmentObject(settings)
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
                    // Search & Commands group
                    ToolbarItemGroup(placement: .primaryAction) {
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
                    }

                    // Spacer between info and action groups
                    ToolbarSpacer(.fixed, placement: .primaryAction)

                    // Create project action
                    ToolbarItem(placement: .primaryAction) {
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
                    }

                    // Spacer between action and utilities
                    ToolbarSpacer(.fixed, placement: .primaryAction)

                    // Utilities group
                    ToolbarItemGroup(placement: .primaryAction) {
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
                    initialGitStatus: gitStatusCoordinator.effectiveGitStatus(for: project.path),
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
            gitStatusCoordinator.loadFromCache()
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
                await self.gitStatusCoordinator.discoverAllSubRepos(serverURL: self.settings.serverURL, projects: self.projects)
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
        projectCache.saveProjects(projects, gitStatuses: gitStatusCoordinator.gitStatuses, branchNames: gitStatusCoordinator.branchNames)

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
        ProjectSidebarContent(
            projects: projects,
            isLoading: isLoading,
            hasCachedData: projectCache.hasCachedData,
            errorMessage: errorMessage,
            loadingStatus: loadingStatus,
            selectedProject: $selectedProject,
            gitStatusCoordinator: gitStatusCoordinator,
            onRefresh: {
                await loadProjects()
                if !projects.isEmpty {
                    await gitStatusCoordinator.discoverAllSubRepos(serverURL: settings.serverURL, projects: projects)
                    await loadAllSessionCounts()
                }
            },
            onDeleteProject: { project in
                projectToDelete = project
            },
            onRenameProject: { project in
                projectToRename = project
                renameText = ProjectNamesStore.shared.getName(for: project.path) ?? project.title
            },
            onShowProjectDetail: { project in
                projectToShowDetail = project
            },
            onRefreshGitStatus: { project in
                await gitStatusCoordinator.refreshGitStatus(for: project, serverURL: settings.serverURL)
            }
        )
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
            gitStatusCoordinator.updateFromCLIProjects(cliProjects)

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
                gitStatusCoordinator.gitStatuses.removeValue(forKey: project.path)
                projectToDelete = nil
            }
        } catch {
            log.error("[Projects] Failed to delete project: \(error)")
            await MainActor.run {
                projectToDelete = nil
            }
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
