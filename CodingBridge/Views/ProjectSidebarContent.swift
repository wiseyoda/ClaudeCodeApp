import SwiftUI

/// Sidebar content for the project list in iPad NavigationSplitView layout.
/// Extracted from ContentView to improve modularity.
struct ProjectSidebarContent: View {
    let projects: [Project]
    let isLoading: Bool
    let hasCachedData: Bool
    let errorMessage: String?
    let loadingStatus: String?

    @Binding var selectedProject: Project?
    let gitStatusCoordinator: GitStatusCoordinator

    // Callbacks
    let onRefresh: () async -> Void
    let onDeleteProject: (Project) -> Void
    let onRenameProject: (Project) -> Void
    let onShowProjectDetail: (Project) -> Void
    let onRefreshGitStatus: (Project) async -> Void

    @ObservedObject private var archivedStore = ArchivedProjectsStore.shared
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    /// All projects from cli-bridge
    private var workspaceProjects: [Project] {
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
            return projectList.sorted { p1, p2 in
                let date1 = p1.sessions?.compactMap { $0.lastActivity }.max() ?? ""
                let date2 = p2.sessions?.compactMap { $0.lastActivity }.max() ?? ""
                return date1 > date2
            }
        case .name:
            return projectList.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }

    var body: some View {
        Group {
            if isLoading && !hasCachedData {
                SkeletonProjectList()
            } else if let error = errorMessage, projects.isEmpty {
                errorView(error)
            } else {
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
                    Task { await onRefresh() }
                } label: {
                    Text("[Retry]")
                        .font(CLITheme.monoFont)
                        .foregroundColor(CLITheme.cyan(for: colorScheme))
                }
                .accessibilityLabel("Retry")
                .accessibilityHint("Try loading projects again")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CLITheme.background(for: colorScheme))
    }

    private var projectListView: some View {
        List(selection: $selectedProject) {
            // Active Projects Section
            Section {
                ForEach(activeProjects) { project in
                    projectRow(for: project, isArchived: false)

                    // Sub-repos when expanded
                    if gitStatusCoordinator.expandedProjects.contains(project.path),
                       let multiRepoStatus = gitStatusCoordinator.multiRepoStatuses[project.path],
                       multiRepoStatus.hasSubRepos {
                        ForEach(multiRepoStatus.subRepos) { subRepo in
                            SubRepoRow(
                                subRepo: subRepo,
                                projectPath: project.path,
                                onRefresh: {
                                    Task { await gitStatusCoordinator.refreshAllSubRepos(project: project, serverURL: settings.serverURL) }
                                },
                                onPull: {
                                    Task { await gitStatusCoordinator.pullSubRepo(project: project, subRepo: subRepo, serverURL: settings.serverURL) }
                                }
                            )
                            .listRowBackground(CLITheme.secondaryBackground(for: colorScheme).opacity(0.5))
                            .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                        }

                        SubRepoActionBar(
                            multiRepoStatus: multiRepoStatus,
                            onPullAll: {
                                Task { await gitStatusCoordinator.pullAllBehindSubRepos(project: project, serverURL: settings.serverURL) }
                            },
                            onRefreshAll: {
                                Task { await gitStatusCoordinator.refreshAllSubRepos(project: project, serverURL: settings.serverURL) }
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
            await onRefresh()
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
        let isExpanded = gitStatusCoordinator.expandedProjects.contains(project.path)
        let multiRepoStatus = gitStatusCoordinator.multiRepoStatuses[project.path]

        ProjectRow(
            project: project,
            gitStatus: gitStatusCoordinator.effectiveGitStatus(for: project.path),
            sessionCount: SessionStore.shared.displaySessionCount(for: project.path),
            isSelected: selectedProject?.id == project.id,
            isArchived: isArchived,
            multiRepoStatus: multiRepoStatus,
            isExpanded: isExpanded,
            onToggleExpand: {
                gitStatusCoordinator.toggleExpansion(for: project.path)
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
                onDeleteProject(project)
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
                onRenameProject(project)
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
                Task { await onRefreshGitStatus(project) }
            } label: {
                Label("Refresh Git Status", systemImage: "arrow.triangle.2.circlepath")
            }

            Divider()

            Button {
                onShowProjectDetail(project)
            } label: {
                Label("View Details", systemImage: "info.circle")
            }

            Button(role: .destructive) {
                onDeleteProject(project)
            } label: {
                Label("Delete Project", systemImage: "trash")
            }
        }
    }
}

#Preview {
    ProjectSidebarContent(
        projects: [],
        isLoading: false,
        hasCachedData: false,
        errorMessage: nil,
        loadingStatus: nil,
        selectedProject: .constant(nil),
        gitStatusCoordinator: GitStatusCoordinator(),
        onRefresh: {},
        onDeleteProject: { _ in },
        onRenameProject: { _ in },
        onShowProjectDetail: { _ in },
        onRefreshGitStatus: { _ in }
    )
    .environmentObject(AppSettings())
}
