import SwiftUI

// MARK: - Git Sync Banner (Compact, Dark Mode Optimized)

struct GitSyncBanner: View {
    let status: GitStatus
    let isAutoPulling: Bool
    let isRefreshing: Bool
    let onDismiss: () -> Void
    let onRefresh: () -> Void
    let onPull: (() -> Void)?
    let onCommit: (() -> Void)?
    let onAskClaude: (() -> Void)?
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            // Status icon (compact)
            if isAutoPulling || isRefreshing {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 14, height: 14)
            } else {
                Image(systemName: status.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            // Status text (single line, compact)
            Text(isRefreshing ? "Checking..." : statusTitle)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(CLITheme.primaryText(for: colorScheme))
                .lineLimit(1)

            Spacer()

            // Action buttons (compact pills)
            if !isAutoPulling && !isRefreshing {
                HStack(spacing: 6) {
                    // Pull button (for behind status)
                    if let onPull = onPull {
                        compactButton(
                            title: "Pull",
                            icon: "arrow.down",
                            color: CLITheme.cyan(for: colorScheme),
                            action: onPull
                        )
                    }

                    // Commit/Push button
                    if let onCommit = onCommit {
                        compactButton(
                            title: commitButtonLabel,
                            icon: commitButtonIcon,
                            color: commitButtonColor,
                            action: onCommit
                        )
                    }

                    // Ask Claude button
                    if let onAskClaude = onAskClaude {
                        compactButton(
                            title: "Ask",
                            icon: "bubble.left",
                            color: CLITheme.purple(for: colorScheme),
                            action: onAskClaude
                        )
                    }

                    // Refresh button (icon only)
                    Button(action: onRefresh) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(CLITheme.mutedText(for: colorScheme))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Dismiss button (compact)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
                    .frame(width: 16, height: 16)
                    .background(
                        Circle()
                            .fill(CLITheme.mutedText(for: colorScheme).opacity(0.15))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(bannerBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(status.accessibilityLabel)
    }

    // MARK: - Compact Button Helper

    @ViewBuilder
    private func compactButton(
        title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                Text(title)
                    .font(.system(size: 10, weight: .bold))
            }
            // Dark mode: white text on colored background for high contrast
            // Light mode: colored text on light colored background
            .foregroundColor(colorScheme == .dark ? .white : color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(colorScheme == .dark ? 0.7 : 0.15))
            )
            .overlay(
                Capsule()
                    .strokeBorder(color.opacity(colorScheme == .dark ? 0.9 : 0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Computed Properties

    private var iconColor: Color {
        switch status.colorName {
        case "green": return CLITheme.green(for: colorScheme)
        case "orange": return CLITheme.yellow(for: colorScheme)
        case "blue": return CLITheme.blue(for: colorScheme)
        case "cyan": return CLITheme.cyan(for: colorScheme)
        case "red": return CLITheme.red(for: colorScheme)
        default: return CLITheme.mutedText(for: colorScheme)
        }
    }

    private var bannerBackground: Color {
        let baseColor: Color = {
            switch status {
            case .dirty, .dirtyAndAhead, .diverged:
                return CLITheme.yellow(for: colorScheme)
            case .behind:
                return CLITheme.cyan(for: colorScheme)
            case .ahead:
                return CLITheme.blue(for: colorScheme)
            case .error:
                return CLITheme.red(for: colorScheme)
            default:
                return CLITheme.mutedText(for: colorScheme)
            }
        }()
        return baseColor.opacity(colorScheme == .dark ? 0.15 : 0.08)
    }

    private var statusTitle: String {
        if isAutoPulling { return "Pulling..." }
        switch status {
        case .dirty: return "Uncommitted changes"
        case .ahead(let count): return "\(count) unpushed"
        case .behind(let count): return "\(count) behind"
        case .dirtyAndAhead: return "Changes + unpushed"
        case .diverged: return "Diverged"
        case .error(let msg): return "Error: \(msg.prefix(20))"
        default: return ""
        }
    }

    private var commitButtonLabel: String {
        switch status {
        case .ahead: return "Push"
        default: return "Commit"
        }
    }

    private var commitButtonIcon: String {
        switch status {
        case .ahead: return "arrow.up"
        default: return "checkmark"
        }
    }

    private var commitButtonColor: Color {
        switch status {
        case .ahead: return CLITheme.blue(for: colorScheme)
        default: return CLITheme.green(for: colorScheme)
        }
    }

    private var commitButtonAccessibilityLabel: String {
        switch status {
        case .dirty, .dirtyAndAhead, .diverged:
            return "Commit changes"
        case .ahead:
            return "Push commits"
        default:
            return "Commit changes"
        }
    }
}
