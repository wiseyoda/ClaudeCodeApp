import SwiftUI

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
