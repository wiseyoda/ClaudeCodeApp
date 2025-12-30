import SwiftUI

// MARK: - Git Status Indicator

/// Compact git status indicator used in project lists and navigation bars
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
