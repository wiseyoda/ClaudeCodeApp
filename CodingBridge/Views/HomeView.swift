import SwiftUI

/// iPhone-only home screen with 2-column glass card grid
/// Shows project cards with git status, session counts, and branch badges
struct HomeView: View {
    let projects: [Project]
    let gitStatuses: [String: GitStatus]
    let branchNames: [String: String]
    let isLoading: Bool
    let onRefresh: () async -> Void
    let onSelectProject: (Project) -> Void
    let onSelectSession: (CLISessionMetadata) -> Void
    var onRenameProject: ((Project) -> Void)? = nil
    var onDeleteProject: ((Project) -> Void)? = nil

    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var archivedStore = ArchivedProjectsStore.shared

    // Grid layout: 2 flexible columns with spacing
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Active Projects Section
                if !activeProjects.isEmpty {
                    projectsSection
                }

                // Recent Sessions Section
                RecentActivitySection(onSelectSession: onSelectSession)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100) // Extra padding for tab bar
        }
        .background(CLITheme.background(for: colorScheme))
        .refreshable {
            await onRefresh()
        }
        .overlay {
            if projects.isEmpty && !isLoading {
                emptyState
            }
        }
        .navigationTitle("Developer Dashboard")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    // MARK: - Active Projects

    private var activeProjects: [Project] {
        let active = projects.filter { !archivedStore.isArchived($0.path) }
        return sortProjects(active)
    }

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

    // MARK: - Projects Section

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            Text("ACTIVE PROJECTS")
                .font(.system(.caption, design: .default, weight: .semibold))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))
                .tracking(1)
                .padding(.horizontal, 4)

            // Grid of cards
            if isLoading && projects.isEmpty {
                // Loading skeleton
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(0..<4, id: \.self) { _ in
                        ProjectCardSkeleton()
                    }
                }
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(activeProjects.enumerated()), id: \.element.id) { index, project in
                        ProjectCard(
                            project: project,
                            gitStatus: gitStatuses[project.path] ?? .unknown,
                            branchName: branchNames[project.path],
                            onTap: { onSelectProject(project) },
                            onRename: onRenameProject != nil ? { onRenameProject?(project) } : nil,
                            onArchive: {
                                if archivedStore.isArchived(project.path) {
                                    archivedStore.unarchive(project.path)
                                } else {
                                    archivedStore.archive(project.path)
                                }
                            },
                            onDelete: onDeleteProject != nil ? { onDeleteProject?(project) } : nil,
                            isArchived: archivedStore.isArchived(project.path),
                            animationDelay: Double(index) * 0.05
                        )
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity
                        ))
                    }
                }
                .animation(.easeOut(duration: 0.3), value: activeProjects.count)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 56))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))

            Text("No Projects Found")
                .font(.system(.title3, design: .default, weight: .semibold))
                .foregroundColor(CLITheme.primaryText(for: colorScheme))

            Text("Open a project with Claude Code to see it here")
                .font(.system(.subheadline))
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Recent Activity Section

/// Shows recent sessions across all projects
struct RecentActivitySection: View {
    let onSelectSession: (CLISessionMetadata) -> Void

    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    @State private var recentSessions: [CLISessionMetadata] = []
    @State private var isLoading = false
    @State private var hasLoaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            Text("RECENT SESSIONS")
                .font(.system(.caption, design: .default, weight: .semibold))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))
                .tracking(1)
                .padding(.horizontal, 4)

            // Activity list in glass panel
            if isLoading && !hasLoaded {
                loadingState
            } else if recentSessions.isEmpty {
                emptyActivityState
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentSessions.enumerated()), id: \.element.id) { index, session in
                        Button {
                            onSelectSession(session)
                        } label: {
                            activityRow(session: session, isLast: index == recentSessions.count - 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .glassBackground(cornerRadius: 16)
            }
        }
        .task {
            await loadRecentSessions()
        }
    }

    private func loadRecentSessions() async {
        guard !isLoading else { return }
        isLoading = true

        do {
            let apiClient = CLIBridgeAPIClient(serverURL: settings.serverURL)
            recentSessions = try await apiClient.fetchRecentSessions(limit: 5)
            hasLoaded = true
        } catch {
            // Silently fail - empty state is fine for activity feed
            log.debug("[HomeView] Failed to load recent sessions: \(error)")
        }

        isLoading = false
    }

    /// Extract project name from full path (last component)
    private func projectName(from path: String) -> String {
        (path as NSString).lastPathComponent
    }

    @ViewBuilder
    private func activityRow(session: CLISessionMetadata, isLast: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Project name row
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 10))
                    .foregroundColor(CLITheme.cyan(for: colorScheme))

                Text(projectName(from: session.projectPath))
                    .font(.system(.caption2, design: .default, weight: .medium))
                    .foregroundColor(CLITheme.cyan(for: colorScheme))

                Spacer()
            }

            // Session title
            Text(session.displayTitle ?? "Untitled session")
                .font(.system(.subheadline, design: .default))
                .foregroundColor(CLITheme.primaryText(for: colorScheme))
                .lineLimit(1)

            // Metadata row
            HStack(spacing: 8) {
                Text(relativeTime(from: session.lastActivityAt))
                    .font(.system(.caption2))
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))

                Text("·")
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))

                Text("\(session.messageCount) messages")
                    .font(.system(.caption2))
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            if !isLast {
                Divider()
                    .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
            }
        }
    }

    /// Convert ISO8601 timestamp to relative time string
    private func relativeTime(from isoString: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: isoString) else {
            return ""
        }

        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return days == 1 ? "Yesterday" : "\(days)d ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }

    private var loadingState: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)

            Text("Loading sessions...")
                .font(.system(.subheadline))
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))

            Spacer()
        }
        .padding(16)
        .glassBackground(cornerRadius: 16)
    }

    private var emptyActivityState: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 16))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))

            Text("No recent sessions")
                .font(.system(.subheadline))
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))

            Spacer()
        }
        .padding(16)
        .glassBackground(cornerRadius: 16)
    }
}

#Preview("HomeView") {
    NavigationStack {
        HomeView(
            projects: [
                Project(name: "ClaudeCodeApp", path: "/dev/ClaudeCodeApp", displayName: nil, fullPath: nil, sessions: nil, sessionMeta: ProjectSessionMeta(hasMore: false, total: 3)),
                Project(name: "agent-ui-kit", path: "/dev/agent-ui-kit", displayName: nil, fullPath: nil, sessions: nil, sessionMeta: nil),
                Project(name: "backend-service-v2", path: "/dev/backend", displayName: nil, fullPath: nil, sessions: nil, sessionMeta: ProjectSessionMeta(hasMore: false, total: 5)),
                Project(name: "new-ml-pipeline", path: "/dev/ml", displayName: nil, fullPath: nil, sessions: nil, sessionMeta: nil)
            ],
            gitStatuses: [
                "/dev/ClaudeCodeApp": .clean,
                "/dev/agent-ui-kit": .unknown,
                "/dev/backend": .checking,
                "/dev/ml": .dirty
            ],
            branchNames: [
                "/dev/ClaudeCodeApp": "main",
                "/dev/agent-ui-kit": "dev",
                "/dev/backend": "feature/api",
                "/dev/ml": "main"
            ],
            isLoading: false,
            onRefresh: {},
            onSelectProject: { _ in },
            onSelectSession: { _ in }
        )
    }
    .environmentObject(AppSettings())
    .preferredColorScheme(.dark)
}

#Preview("HomeView - Loading") {
    NavigationStack {
        HomeView(
            projects: [],
            gitStatuses: [:],
            branchNames: [:],
            isLoading: true,
            onRefresh: {},
            onSelectProject: { _ in },
            onSelectSession: { _ in }
        )
    }
    .environmentObject(AppSettings())
    .preferredColorScheme(.dark)
}
