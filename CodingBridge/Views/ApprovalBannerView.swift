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

    // Timeout configuration
    private let warningThreshold: TimeInterval = 120  // 2 minutes
    private let expirationThreshold: TimeInterval = 300  // 5 minutes

    @State private var elapsedTime: TimeInterval = 0
    @State private var showAlwaysConfirmation = false

    // Timer for tracking elapsed time
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var remainingTime: Int {
        max(0, Int(expirationThreshold - elapsedTime))
    }

    private var isWarningShown: Bool {
        elapsedTime >= warningThreshold
    }

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

            // Timeout warning row (shown after 2 minutes)
            if isWarningShown {
                HStack(spacing: 6) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.orange)

                    Text("Auto-deny in \(remainingTime)s")
                        .font(settings.scaledFont(.small))
                        .fontWeight(.medium)
                        .foregroundColor(.orange)

                    Spacer()
                }
                .transition(.opacity)
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
                Button {
                    showAlwaysConfirmation = true
                } label: {
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
                        .stroke(isWarningShown ? Color.orange.opacity(0.6) : CLITheme.cyan(for: colorScheme).opacity(0.4), lineWidth: 1)
                )
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.2), value: request.id)
        .animation(.easeInOut(duration: 0.3), value: isWarningShown)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ApprovalBanner")
        .onAppear {
            // Calculate initial elapsed time based on when request was received
            elapsedTime = Date().timeIntervalSince(request.receivedAt)
        }
        .onReceive(timer) { _ in
            elapsedTime = Date().timeIntervalSince(request.receivedAt)
        }
        .confirmationDialog(
            "Always Allow \(request.toolName)?",
            isPresented: $showAlwaysConfirmation,
            titleVisibility: .visible
        ) {
            Button("Always Allow") {
                onAlwaysAllow()
            }
            Button("Just This Once") {
                onApprove()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will auto-approve \(request.toolName) for this project in the future.")
        }
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

// MARK: - Exit Plan Mode Approval View

/// A full-screen sheet for reviewing and approving ExitPlanMode requests
/// Shows the plan content as markdown with approve/reject buttons
struct ExitPlanModeApprovalView: View {
    let request: ApprovalRequest
    let onApprove: () -> Void
    let onDeny: () -> Void

    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(CLITheme.cyan(for: colorScheme))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Exit Plan Mode")
                                .font(settings.scaledFont(.body))
                                .fontWeight(.semibold)
                                .foregroundColor(CLITheme.primaryText(for: colorScheme))

                            Text("Review the proposed plan before Claude begins execution")
                                .font(settings.scaledFont(.small))
                                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                        }
                    }
                    .padding(.bottom, 8)

                    Divider()

                    // Plan content as markdown
                    if let plan = request.planContent {
                        MarkdownText(plan)
                    } else {
                        Text("No plan content provided")
                            .font(settings.scaledFont(.body))
                            .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                            .italic()
                    }
                }
                .padding()
            }
            .background(CLITheme.background(for: colorScheme))
            .navigationTitle("Review Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reject") {
                        onDeny()
                        dismiss()
                    }
                    .foregroundColor(CLITheme.red(for: colorScheme))
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Approve") {
                        onApprove()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Bottom action buttons (duplicated for visibility)
                HStack(spacing: 16) {
                    Button {
                        onDeny()
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Reject Plan")
                                .font(settings.scaledFont(.body))
                                .fontWeight(.medium)
                        }
                        .foregroundColor(CLITheme.red(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(CLITheme.red(for: colorScheme).opacity(0.1))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)

                    Button {
                        onApprove()
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Approve Plan")
                                .font(settings.scaledFont(.body))
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(CLITheme.green(for: colorScheme))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(
                    CLITheme.secondaryBackground(for: colorScheme)
                        .shadow(color: .black.opacity(0.1), radius: 8, y: -4)
                )
            }
        }
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

#Preview("Exit Plan Mode Approval") {
    ExitPlanModeApprovalView(
        request: ApprovalRequest(
            id: "test-plan",
            toolName: "ExitPlanMode",
            input: [
                "plan": """
                ## Implementation Plan

                ### Phase 1: Setup
                1. Create the new component file
                2. Add basic structure and props

                ### Phase 2: Implementation
                1. Implement the main logic
                2. Add error handling
                3. Write unit tests

                ### Phase 3: Integration
                1. Update parent components
                2. Add to exports
                3. Update documentation
                """
            ],
            receivedAt: Date()
        ),
        onApprove: { print("Plan Approved") },
        onDeny: { print("Plan Rejected") }
    )
    .environmentObject(AppSettings())
}
