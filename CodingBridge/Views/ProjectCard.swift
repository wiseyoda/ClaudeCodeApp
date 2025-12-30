import SwiftUI

/// Glass-effect project card for the home screen grid
/// Shows project name, git status, session count, and branch badge
struct ProjectCard: View {
    let project: Project
    let gitStatus: GitStatus
    let branchName: String?
    let onTap: () -> Void

    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    // Animation state for staggered entrance
    var animationDelay: Double = 0

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Header: Name + Status Icon
                HStack(alignment: .top, spacing: 6) {
                    Text(project.title)
                        .font(.system(.subheadline, design: .default, weight: .semibold))
                        .foregroundColor(CLITheme.primaryText(for: colorScheme))
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    statusIcon
                }

                // Branch info (using branch name since we don't have commit hash)
                if let branch = branchName {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 10))
                        Text(branch)
                            .font(.system(.caption2, design: .monospaced))
                    }
                    .foregroundColor(CLITheme.cyan(for: colorScheme))
                }

                Spacer(minLength: 4)

                // Bottom row: Session count + Branch badge
                HStack(alignment: .bottom) {
                    sessionCountView

                    Spacer()

                    branchBadge
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        }
        .buttonStyle(ProjectCardButtonStyle())
        .glassBackground(cornerRadius: 16, isInteractive: true)
    }

    // MARK: - Status Icon

    @ViewBuilder
    private var statusIcon: some View {
        switch gitStatus {
        case .checking:
            ProgressView()
                .scaleEffect(0.7)
                .tint(CLITheme.yellow(for: colorScheme))

        case .clean:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(CLITheme.green(for: colorScheme))

        case .dirty, .dirtyAndAhead:
            Image(systemName: "pencil.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(CLITheme.orange(for: colorScheme))

        case .ahead:
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(CLITheme.blue(for: colorScheme))

        case .behind:
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(CLITheme.cyan(for: colorScheme))

        case .diverged:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(CLITheme.orange(for: colorScheme))

        case .error:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(CLITheme.red(for: colorScheme))

        case .notGitRepo:
            Image(systemName: "folder.fill")
                .font(.system(size: 14))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))

        case .unknown:
            Image(systemName: "questionmark.circle")
                .font(.system(size: 14))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))
        }
    }

    // MARK: - Session Count

    @ViewBuilder
    private var sessionCountView: some View {
        let count = project.totalSessionCount
        let hasActiveSessions = count > 0

        Text("[\(count) session\(count == 1 ? "" : "s")]")
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(hasActiveSessions
                ? CLITheme.cyan(for: colorScheme)
                : CLITheme.mutedText(for: colorScheme))
    }

    // MARK: - Branch Badge

    @ViewBuilder
    private var branchBadge: some View {
        if let branch = branchName {
            let badgeColor = branchBadgeColor
            let badgeBackground = badgeColor.opacity(0.2)

            Text(branchDisplayName(branch))
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(badgeColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(badgeBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(badgeColor.opacity(0.4), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    /// Shorten branch name for badge display
    private func branchDisplayName(_ branch: String) -> String {
        // Shorten common prefixes
        if branch.hasPrefix("feature/") {
            return String(branch.dropFirst(8))
        }
        if branch.hasPrefix("bugfix/") {
            return String(branch.dropFirst(7))
        }
        if branch.hasPrefix("hotfix/") {
            return String(branch.dropFirst(7))
        }
        // Truncate long names
        if branch.count > 12 {
            return String(branch.prefix(10)) + "..."
        }
        return branch
    }

    /// Color for branch badge based on git status and branch name
    private var branchBadgeColor: Color {
        let isMainBranch = branchName == "main" || branchName == "master"

        switch gitStatus {
        case .checking:
            return CLITheme.yellow(for: colorScheme)

        case .clean where isMainBranch:
            return CLITheme.green(for: colorScheme)

        case .clean:
            return CLITheme.mutedText(for: colorScheme)

        case .dirty, .dirtyAndAhead, .ahead, .behind, .diverged:
            return CLITheme.yellow(for: colorScheme)

        case .error:
            return CLITheme.red(for: colorScheme)

        default:
            return CLITheme.blue(for: colorScheme)
        }
    }
}

// MARK: - Button Style

/// Custom button style for project cards with press feedback
struct ProjectCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Skeleton Card (Loading State)

/// Placeholder card shown while loading projects
struct ProjectCardSkeleton: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(CLITheme.mutedText(for: colorScheme).opacity(0.3))
                .frame(width: 100, height: 14)

            // Branch placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(CLITheme.mutedText(for: colorScheme).opacity(0.2))
                .frame(width: 60, height: 10)

            Spacer()

            HStack {
                // Session count placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(CLITheme.mutedText(for: colorScheme).opacity(0.2))
                    .frame(width: 80, height: 12)

                Spacer()

                // Badge placeholder
                RoundedRectangle(cornerRadius: 6)
                    .fill(CLITheme.mutedText(for: colorScheme).opacity(0.2))
                    .frame(width: 40, height: 20)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        .glassBackground(cornerRadius: 16)
        .shimmer()
    }
}

#Preview("Project Card - Clean") {
    ProjectCard(
        project: Project(
            name: "ClaudeCodeApp",
            path: "/Users/dev/ClaudeCodeApp",
            displayName: nil,
            fullPath: "/Users/dev/ClaudeCodeApp",
            sessions: [],
            sessionMeta: ProjectSessionMeta(hasMore: false, total: 3)
        ),
        gitStatus: .clean,
        branchName: "main",
        onTap: {}
    )
    .environmentObject(AppSettings())
    .padding()
    .background(Color.black)
}

#Preview("Project Card - Dirty") {
    ProjectCard(
        project: Project(
            name: "backend-service",
            path: "/Users/dev/backend",
            displayName: nil,
            fullPath: nil,
            sessions: nil,
            sessionMeta: nil
        ),
        gitStatus: .dirty,
        branchName: "feature/new-api",
        onTap: {}
    )
    .environmentObject(AppSettings())
    .padding()
    .background(Color.black)
}

#Preview("Skeleton") {
    ProjectCardSkeleton()
        .padding()
        .background(Color.black)
}
