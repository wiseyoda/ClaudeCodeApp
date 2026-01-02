import Foundation

// MARK: - Permission Approval Types

/// Represents a pending permission request from Claude CLI
/// When bypass permissions mode is OFF, Claude CLI sends these requests
/// for user approval before executing certain tools
struct ApprovalRequest: Identifiable, Equatable {
    let id: String  // requestId from server
    let toolName: String
    let input: [String: Any]
    let receivedAt: Date

    // MARK: - Display Properties

    /// Whether this is an ExitPlanMode request (requires special rendering)
    var isExitPlanMode: Bool {
        toolName == "ExitPlanMode"
    }

    /// The plan content for ExitPlanMode requests (markdown format)
    var planContent: String? {
        guard isExitPlanMode else { return nil }
        return input["plan"] as? String
    }

    /// Icon for the tool type
    var toolIcon: String {
        switch toolName.lowercased() {
        case "bash":
            return "terminal"
        case "read":
            return "doc.text"
        case "write":
            return "doc.badge.plus"
        case "edit":
            return "pencil"
        case "glob", "grep":
            return "magnifyingglass"
        case "task":
            return "arrow.triangle.branch"
        case "exitplanmode":
            return "doc.text.magnifyingglass"
        default:
            return "wrench"
        }
    }

    /// Short display title for the banner
    var displayTitle: String {
        if isExitPlanMode {
            return "Exit Plan Mode"
        }
        return toolName
    }

    /// Description extracted from input for display
    var displayDescription: String {
        // ExitPlanMode shows plan in expanded view, use short description here
        if isExitPlanMode {
            return "Review plan before execution"
        }
        // Try to extract meaningful preview from input
        if let command = input["command"] as? String {
            // For Bash - show the command
            return command.prefix(80).description + (command.count > 80 ? "..." : "")
        }
        if let filePath = input["file_path"] as? String {
            // For Read/Write/Edit - show the file path
            return filePath
        }
        if let pattern = input["pattern"] as? String {
            // For Glob/Grep - show the pattern
            return pattern
        }
        if let description = input["description"] as? String {
            // Fallback to description if available
            return description
        }
        // Last resort - just show tool name
        return "Requesting permission..."
    }

    // MARK: - Equatable

    static func == (lhs: ApprovalRequest, rhs: ApprovalRequest) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Parsing

    /// Parse from WebSocket message data
    static func from(_ data: [String: Any]) -> ApprovalRequest? {
        guard let requestId = data["requestId"] as? String,
              let toolName = data["toolName"] as? String else {
            return nil
        }

        let input = data["input"] as? [String: Any] ?? [:]

        return ApprovalRequest(
            id: requestId,
            toolName: toolName,
            input: input,
            receivedAt: Date()
        )
    }
}

/// Response to send back to server for a permission request
/// Backend expects: { type, requestId, decision, alwaysAllow }
/// - decision: "allow" or "deny" (NOT "allow-session" - that breaks backend logic)
/// - alwaysAllow: true to remember decision for this session
struct ApprovalResponse: Encodable {
    let type: String = "permission-response"
    let requestId: String
    let decision: String      // "allow" or "deny"
    let alwaysAllow: Bool     // true = remember for session

    init(requestId: String, allow: Bool, alwaysAllow: Bool = false) {
        self.requestId = requestId
        self.decision = allow ? "allow" : "deny"
        self.alwaysAllow = alwaysAllow
    }
}
