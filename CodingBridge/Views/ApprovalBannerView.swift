import SwiftUI

/// A compact banner that appears when Claude CLI requests permission for a tool
/// Shows above the status bar in ChatView when bypass permissions is OFF
struct ApprovalBannerView: View {
    let request: ApprovalRequest
    let onApprove: () -> Void
    let onAlwaysAllow: () -> Void
    let onDeny: () -> Void

    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            // Tool info row
            HStack(spacing: 8) {
                // Tool icon
                Image(systemName: request.toolIcon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(CLITheme.cyan(for: colorScheme))
                    .frame(width: 20)

                // Tool name
                Text(request.displayTitle)
                    .font(settings.scaledFont(.body))
                    .fontWeight(.semibold)
                    .foregroundColor(CLITheme.primaryText(for: colorScheme))

                // Description (truncated)
                Text(request.displayDescription)
                    .font(settings.scaledFont(.small))
                    .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()
            }

            // Action buttons row
            HStack(spacing: 12) {
                // Approve button
                Button(action: onApprove) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Approve")
                            .font(settings.scaledFont(.small))
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(CLITheme.green(for: colorScheme))
                    .cornerRadius(6)
                }
                .accessibilityIdentifier("ApprovalBannerApprove")
                .buttonStyle(.plain)

                // Always Allow button
                Button(action: onAlwaysAllow) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Always")
                            .font(settings.scaledFont(.small))
                            .fontWeight(.medium)
                    }
                    .foregroundColor(CLITheme.cyan(for: colorScheme))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(CLITheme.cyan(for: colorScheme).opacity(0.15))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(CLITheme.cyan(for: colorScheme).opacity(0.3), lineWidth: 1)
                    )
                }
                .accessibilityIdentifier("ApprovalBannerAlways")
                .buttonStyle(.plain)

                // Deny button
                Button(action: onDeny) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Deny")
                            .font(settings.scaledFont(.small))
                            .fontWeight(.medium)
                    }
                    .foregroundColor(CLITheme.red(for: colorScheme))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(CLITheme.red(for: colorScheme).opacity(0.1))
                    .cornerRadius(6)
                }
                .accessibilityIdentifier("ApprovalBannerDeny")
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(CLITheme.secondaryBackground(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(CLITheme.cyan(for: colorScheme).opacity(0.4), lineWidth: 1)
                )
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.2), value: request.id)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ApprovalBanner")
    }
}

// MARK: - Compact Variant (for future use)

/// A more compact single-line banner variant
struct CompactApprovalBannerView: View {
    let request: ApprovalRequest
    let onApprove: () -> Void
    let onAlwaysAllow: () -> Void
    let onDeny: () -> Void

    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            // Tool icon + name
            Image(systemName: request.toolIcon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(CLITheme.cyan(for: colorScheme))

            Text(request.displayTitle)
                .font(settings.scaledFont(.small))
                .fontWeight(.medium)
                .foregroundColor(CLITheme.primaryText(for: colorScheme))

            // Description (truncated)
            Text(request.displayDescription)
                .font(settings.scaledFont(.small))
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Compact action buttons
            HStack(spacing: 8) {
                Button(action: onApprove) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(CLITheme.green(for: colorScheme))
                }
                .buttonStyle(.plain)

                Button(action: onAlwaysAllow) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 20))
                        .foregroundColor(CLITheme.cyan(for: colorScheme))
                }
                .buttonStyle(.plain)

                Button(action: onDeny) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(CLITheme.red(for: colorScheme))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(CLITheme.secondaryBackground(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(CLITheme.cyan(for: colorScheme).opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 12)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Preview

#Preview("Approval Banner - Bash") {
    VStack {
        Spacer()
        ApprovalBannerView(
            request: ApprovalRequest(
                id: "test-123",
                toolName: "Bash",
                input: ["command": "git status", "description": "Show git status"],
                receivedAt: Date()
            ),
            onApprove: { print("Approved") },
            onAlwaysAllow: { print("Always Allow") },
            onDeny: { print("Denied") }
        )
        .environmentObject(AppSettings())
    }
    .background(Color.black)
}

#Preview("Approval Banner - Read") {
    VStack {
        Spacer()
        ApprovalBannerView(
            request: ApprovalRequest(
                id: "test-456",
                toolName: "Read",
                input: ["file_path": "/Users/dev/project/src/components/Header.tsx"],
                receivedAt: Date()
            ),
            onApprove: { print("Approved") },
            onAlwaysAllow: { print("Always Allow") },
            onDeny: { print("Denied") }
        )
        .environmentObject(AppSettings())
    }
    .background(Color.black)
}

#Preview("Compact Banner") {
    VStack {
        Spacer()
        CompactApprovalBannerView(
            request: ApprovalRequest(
                id: "test-789",
                toolName: "Bash",
                input: ["command": "npm install && npm run build"],
                receivedAt: Date()
            ),
            onApprove: { print("Approved") },
            onAlwaysAllow: { print("Always Allow") },
            onDeny: { print("Denied") }
        )
        .environmentObject(AppSettings())
    }
    .background(Color.black)
}
