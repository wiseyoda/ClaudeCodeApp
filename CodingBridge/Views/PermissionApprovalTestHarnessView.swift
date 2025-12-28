import SwiftUI

#if DEBUG
struct PermissionApprovalTestHarnessView: View {
    @State private var request: ApprovalRequest? = PermissionApprovalTestHarnessView.makeRequest()
    @State private var lastDecision: String = "none"
    @State private var remembersDecision = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Permission Approval Test")
                .font(.headline)
                .accessibilityIdentifier("PermissionHarnessTitle")

            Text("Last decision: \(lastDecision)")
                .accessibilityIdentifier("PermissionDecisionLabel")

            Text("Remember decision: \(remembersDecision ? "yes" : "no")")
                .accessibilityIdentifier("PermissionRememberLabel")

            if let request {
                ApprovalBannerView(
                    request: request,
                    onApprove: { handleApprove(alwaysAllow: false) },
                    onAlwaysAllow: { handleApprove(alwaysAllow: true) },
                    onDeny: handleDeny
                )
            }

            HStack(spacing: 12) {
                Button("Reset", action: reset)
                    .accessibilityIdentifier("PermissionResetButton")

                Button("Simulate Timeout", action: simulateTimeout)
                    .accessibilityIdentifier("PermissionTimeoutButton")
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    private func handleApprove(alwaysAllow: Bool) {
        lastDecision = alwaysAllow ? "always" : "approve"
        remembersDecision = alwaysAllow
        request = nil
    }

    private func handleDeny() {
        lastDecision = "deny"
        request = nil
    }

    private func simulateTimeout() {
        lastDecision = "timeout"
        request = nil
    }

    private func reset() {
        lastDecision = "none"
        remembersDecision = false
        request = Self.makeRequest()
    }

    private static func makeRequest() -> ApprovalRequest {
        ApprovalRequest(
            id: "ui-test-request",
            toolName: "Bash",
            input: ["command": "ls -la"],
            receivedAt: Date()
        )
    }
}
#endif
