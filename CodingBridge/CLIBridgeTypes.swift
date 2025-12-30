import Foundation

// MARK: - CLI Bridge Protocol Types
// WebSocket and REST message types for cli-bridge server
// See: requirements/projects/cli-bridge-migration/PROTOCOL-MAPPING.md

// MARK: - Connection State

/// WebSocket connection state
enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var isDisconnected: Bool {
        if case .disconnected = self { return true }
        return false
    }

    var isConnecting: Bool {
        if case .connecting = self { return true }
        return false
    }

    var isReconnecting: Bool {
        if case .reconnecting = self { return true }
        return false
    }

    var displayText: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .reconnecting(let attempt):
            return "Reconnecting (\(attempt))..."
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .disconnected:
            return "Connection status: Disconnected"
        case .connecting:
            return "Connection status: Connecting"
        case .connected:
            return "Connection status: Connected"
        case .reconnecting(let attempt):
            return "Connection status: Reconnecting, attempt \(attempt)"
        }
    }
}

// MARK: - Token Usage

/// Token usage information for display
struct TokenUsage: Equatable {
    let used: Int
    let total: Int

    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total) * 100
    }
}

// MARK: - AnyCodableValue (JSON encoding/decoding)

/// Type-erased wrapper for encoding/decoding arbitrary JSON values
struct AnyCodableValue: Codable, Equatable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodableValue].self) {
            self.value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodableValue].self) {
            self.value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unable to decode AnyCodableValue"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodableValue($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodableValue($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Unable to encode AnyCodableValue"
                )
            )
        }
    }

    static func == (lhs: AnyCodableValue, rhs: AnyCodableValue) -> Bool {
        // Simple equality check for common types
        switch (lhs.value, rhs.value) {
        case (is NSNull, is NSNull):
            return true
        case (let l as Bool, let r as Bool):
            return l == r
        case (let l as Int, let r as Int):
            return l == r
        case (let l as Double, let r as Double):
            return l == r
        case (let l as String, let r as String):
            return l == r
        default:
            return false
        }
    }

    /// Get value as String (for display) - converts any type to string
    var stringValue: String {
        if let s = value as? String { return s }
        if let dict = value as? [String: Any] {
            if let data = try? JSONSerialization.data(withJSONObject: dict),
               let str = String(data: data, encoding: .utf8) {
                return str
            }
        }
        if let array = value as? [Any] {
            if let data = try? JSONSerialization.data(withJSONObject: array),
               let str = String(data: data, encoding: .utf8) {
                return str
            }
        }
        return String(describing: value)
    }

    /// Get value as optional String (strict type check)
    var stringOrNil: String? {
        value as? String
    }

    /// Get value as Int
    var intValue: Int? {
        value as? Int
    }

    /// Get value as Bool
    var boolValue: Bool? {
        value as? Bool
    }

    /// Get value as Dictionary
    var dictValue: [String: Any]? {
        value as? [String: Any]
    }

    /// Get value as Array
    var arrayValue: [Any]? {
        value as? [Any]
    }
}

// MARK: - Client → Server Messages

/// All message types the client can send to cli-bridge
enum CLIClientMessage: Encodable {
    case start(CLIStartPayload)
    case input(CLIInputPayload)
    case permissionResponse(CLIPermissionResponsePayload)
    case questionResponse(CLIQuestionResponsePayload)
    case interrupt
    case stop
    case subscribeSessions(CLISubscribeSessionsPayload)
    case setModel(CLISetModelPayload)
    case setPermissionMode(CLISetPermissionModePayload)
    case cancelQueued
    case retry(CLIRetryPayload)
    case ping

    private enum CodingKeys: String, CodingKey {
        case type
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .start(let payload):
            try container.encode("start", forKey: .type)
            try payload.encode(to: encoder)

        case .input(let payload):
            try container.encode("input", forKey: .type)
            try payload.encode(to: encoder)

        case .permissionResponse(let payload):
            try container.encode("permission_response", forKey: .type)
            try payload.encode(to: encoder)

        case .questionResponse(let payload):
            try container.encode("question_response", forKey: .type)
            try payload.encode(to: encoder)

        case .interrupt:
            try container.encode("interrupt", forKey: .type)

        case .stop:
            try container.encode("stop", forKey: .type)

        case .subscribeSessions(let payload):
            try container.encode("subscribe_sessions", forKey: .type)
            try payload.encode(to: encoder)

        case .setModel(let payload):
            try container.encode("set_model", forKey: .type)
            try payload.encode(to: encoder)

        case .setPermissionMode(let payload):
            try container.encode("set_permission_mode", forKey: .type)
            try payload.encode(to: encoder)

        case .cancelQueued:
            try container.encode("cancel_queued", forKey: .type)

        case .retry(let payload):
            try container.encode("retry", forKey: .type)
            try payload.encode(to: encoder)

        case .ping:
            try container.encode("ping", forKey: .type)
        }
    }
}

// MARK: - Client Message Payloads

struct CLIStartPayload: Encodable {
    let projectPath: String
    let sessionId: String?
    let model: String?
    let helper: Bool?

    init(projectPath: String, sessionId: String? = nil, model: String? = nil, helper: Bool? = nil) {
        self.projectPath = projectPath
        self.sessionId = sessionId
        self.model = model
        self.helper = helper
    }
}

struct CLIInputPayload: Encodable {
    let text: String
    let images: [CLIImageAttachment]?
    let messageId: String?  // For retry correlation
    let thinkingMode: String?  // "think", "think_hard", "think_harder", "ultrathink", or nil

    init(text: String, images: [CLIImageAttachment]? = nil, messageId: String? = nil, thinkingMode: String? = nil) {
        self.text = text
        self.images = images
        self.messageId = messageId
        self.thinkingMode = thinkingMode
    }
}

struct CLIImageAttachment: Codable {
    enum AttachmentType: String, Codable {
        case base64
        case reference
    }

    let type: AttachmentType
    let data: String?      // For base64
    let id: String?        // For reference (uploaded)
    let mimeType: String?

    init(base64Data: String, mimeType: String) {
        self.type = .base64
        self.data = base64Data
        self.id = nil
        self.mimeType = mimeType
    }

    init(referenceId: String) {
        self.type = .reference
        self.data = nil
        self.id = referenceId
        self.mimeType = nil
    }
}

struct CLIPermissionResponsePayload: Encodable {
    let id: String
    let choice: CLIPermissionChoice

    enum CLIPermissionChoice: String, Encodable {
        case allow
        case deny
        case always
    }
}

struct CLIQuestionResponsePayload: Encodable {
    let id: String
    let answers: [String: AnyCodableValue]
}

struct CLISubscribeSessionsPayload: Encodable {
    let projectPath: String?
}

struct CLISetModelPayload: Encodable {
    let model: String
}

struct CLISetPermissionModePayload: Encodable {
    let mode: CLIPermissionMode

    enum CLIPermissionMode: String, Encodable {
        case `default`
        case acceptEdits
        case bypassPermissions
    }
}

struct CLIRetryPayload: Encodable {
    let messageId: String
}

// MARK: - Server → Client Messages

/// All message types the server can send to clients
enum CLIServerMessage: Decodable {
    case connected(CLIConnectedPayload)
    case stream(CLIStreamMessage)
    case permission(CLIPermissionRequest)
    case question(CLIQuestionRequest)
    case sessionEvent(CLISessionEvent)
    case history(CLIHistoryPayload)
    case modelChanged(CLIModelChangedPayload)
    case permissionModeChanged(CLIPermissionModeChangedPayload)
    case queued(CLIQueuedPayload)
    case queueCleared
    case error(CLIErrorPayload)
    case pong(CLIPongPayload)
    // Top-level control messages (not inside stream)
    case stopped(CLIStoppedPayload)
    case interrupted

    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "connected":
            self = .connected(try CLIConnectedPayload(from: decoder))
        case "stream":
            self = .stream(try CLIStreamMessage(from: decoder))
        case "permission":
            self = .permission(try CLIPermissionRequest(from: decoder))
        case "question":
            self = .question(try CLIQuestionRequest(from: decoder))
        case "session_event":
            self = .sessionEvent(try CLISessionEvent(from: decoder))
        case "history":
            self = .history(try CLIHistoryPayload(from: decoder))
        case "model_changed":
            self = .modelChanged(try CLIModelChangedPayload(from: decoder))
        case "permission_mode_changed":
            self = .permissionModeChanged(try CLIPermissionModeChangedPayload(from: decoder))
        case "queued":
            self = .queued(try CLIQueuedPayload(from: decoder))
        case "queue_cleared":
            self = .queueCleared
        case "error":
            self = .error(try CLIErrorPayload(from: decoder))
        case "pong":
            self = .pong(try CLIPongPayload(from: decoder))
        case "stopped":
            self = .stopped(try CLIStoppedPayload(from: decoder))
        case "interrupted":
            self = .interrupted
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown message type: \(type)"
            )
        }
    }
}

// MARK: - Server Message Payloads

/// Payload for top-level stopped message
struct CLIStoppedPayload: Decodable {
    let reason: String
}

struct CLIConnectedPayload: Decodable {
    let agentId: String
    let sessionId: String
    let model: String
    let version: String
    let protocolVersion: String
}

struct CLIModelChangedPayload: Decodable {
    let model: String
    let previousModel: String?  // Model alias before the change
}

/// Payload for permission mode changed confirmation
struct CLIPermissionModeChangedPayload: Decodable {
    let mode: String  // "default", "acceptEdits", "bypassPermissions"
}

/// Payload for pong (keepalive response)
struct CLIPongPayload: Decodable {
    let serverTime: Int?  // Server timestamp (optional)
}

struct CLIQueuedPayload: Decodable {
    let position: Int
}

// MARK: - History Replay (for session resume)

/// Payload for history replay when resuming a session
struct CLIHistoryPayload: Decodable {
    let messages: [CLIHistoryMessage]
    let hasMore: Bool
    let cursor: String?  // For pagination if hasMore=true
}

/// Individual message in history replay
struct CLIHistoryMessage: Decodable {
    let type: String  // "user", "assistant", etc.
    let id: String?
    let content: String?
    let timestamp: String?
    let thinking: String?
    let toolUse: [CLIHistoryToolUse]?

    /// Convert to ChatMessage for UI display
    func toChatMessage() -> ChatMessage {
        let role: ChatMessage.Role
        switch type.lowercased() {
        case "user":
            role = .user
        case "assistant":
            role = .assistant
        case "system":
            role = .system
        default:
            role = .assistant
        }

        // Parse timestamp
        var date = Date()
        if let ts = timestamp {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let parsedDate = formatter.date(from: ts) {
                date = parsedDate
            } else {
                formatter.formatOptions = [.withInternetDateTime]
                date = formatter.date(from: ts) ?? Date()
            }
        }

        // Build content with thinking and tool results
        var fullContent = content ?? ""
        if let thinkingContent = thinking, !thinkingContent.isEmpty {
            fullContent = "<thinking>\n\(thinkingContent)\n</thinking>\n\n" + fullContent
        }

        return ChatMessage(role: role, content: fullContent, timestamp: date)
    }
}

/// Tool use information in history
struct CLIHistoryToolUse: Decodable {
    let tool: String
    let input: AnyCodable?
    let result: String?
}

/// Type-erased Codable for arbitrary JSON values
struct AnyCodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.typeMismatch(
                AnyCodable.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type")
            )
        }
    }

    /// Get value as String (for display) - converts any type to string
    var stringValue: String {
        if let s = value as? String { return s }
        if let dict = value as? [String: Any] {
            // Extract stdout if present (for tool results)
            if let stdout = dict["stdout"] as? String {
                return stdout
            }
            if let data = try? JSONSerialization.data(withJSONObject: dict),
               let str = String(data: data, encoding: .utf8) {
                return str
            }
        }
        return String(describing: value)
    }

    /// Get value as Dictionary
    var dictValue: [String: Any]? {
        value as? [String: Any]
    }
}

struct CLIErrorPayload: Decodable {
    let code: String
    let message: String
    let recoverable: Bool
    let retryable: Bool?
    let retryAfter: Int?  // Seconds to wait before retry

    /// Known error codes from cli-bridge
    enum ErrorCode: String {
        case invalidMessage = "INVALID_MESSAGE"
        case noAgent = "NO_AGENT"
        case agentNotFound = "AGENT_NOT_FOUND"
        case agentBusy = "AGENT_BUSY"
        case sessionNotFound = "SESSION_NOT_FOUND"
        case sessionInvalid = "SESSION_INVALID"
        case projectNotFound = "PROJECT_NOT_FOUND"
        case queueFull = "QUEUE_FULL"
        case rateLimited = "RATE_LIMITED"
        case connectionReplaced = "CONNECTION_REPLACED"
        case permissionDenied = "PERMISSION_DENIED"
        case maxAgentsReached = "MAX_AGENTS_REACHED"
        case agentError = "AGENT_ERROR"
    }

    var errorCode: ErrorCode? {
        ErrorCode(rawValue: code)
    }
}

// MARK: - Connection Errors

/// Connection-level errors for agent lifecycle management
/// Used by CLIBridgeManager for reconnection handling
enum ConnectionError: Error, LocalizedError, Equatable {
    case serverAtCapacity          // MAX_AGENTS_REACHED - Server has no capacity for new agents
    case agentTimedOut             // AGENT_NOT_FOUND - Agent timed out (4hr idle timeout)
    case connectionReplaced        // CONNECTION_REPLACED - Another client took over
    case queueFull                 // QUEUE_FULL - Input queue is full
    case rateLimited(retryAfter: Int)  // RATE_LIMITED - Too many requests
    case reconnectFailed           // Max reconnection attempts reached
    case networkUnavailable        // No network connectivity
    case invalidServerURL          // Server URL is malformed
    case sessionNotFound           // Session doesn't exist
    case sessionInvalid            // Session is corrupted
    case serverError(code: String, message: String, recoverable: Bool)

    var errorDescription: String? {
        switch self {
        case .serverAtCapacity:
            return "Server is at capacity. Please try again later."
        case .agentTimedOut:
            return "Session timed out due to inactivity."
        case .connectionReplaced:
            return "Session opened on another device."
        case .queueFull:
            return "Input queue is full. Please wait."
        case .rateLimited(let retryAfter):
            return "Rate limited. Retry in \(retryAfter) seconds."
        case .reconnectFailed:
            return "Failed to reconnect after multiple attempts."
        case .networkUnavailable:
            return "No network connection available."
        case .invalidServerURL:
            return "Invalid server URL."
        case .sessionNotFound:
            return "Session not found."
        case .sessionInvalid:
            return "Session is corrupted and cannot be restored."
        case .serverError(_, let message, _):
            return message
        }
    }

    /// Whether the error is recoverable by waiting and retrying
    var isRetryable: Bool {
        switch self {
        case .rateLimited, .serverAtCapacity, .networkUnavailable:
            return true
        case .serverError(_, _, let recoverable):
            return recoverable
        default:
            return false
        }
    }

    /// Whether the user should be prompted to take action
    var requiresUserAction: Bool {
        switch self {
        case .connectionReplaced, .sessionNotFound, .sessionInvalid:
            return true
        default:
            return false
        }
    }

    /// Create from CLIErrorPayload
    static func from(_ payload: CLIErrorPayload) -> ConnectionError {
        switch payload.errorCode {
        case .maxAgentsReached:
            return .serverAtCapacity
        case .agentNotFound:
            return .agentTimedOut
        case .connectionReplaced:
            return .connectionReplaced
        case .queueFull:
            return .queueFull
        case .rateLimited:
            return .rateLimited(retryAfter: payload.retryAfter ?? 60)
        case .sessionNotFound:
            return .sessionNotFound
        case .sessionInvalid:
            return .sessionInvalid
        default:
            return .serverError(
                code: payload.code,
                message: payload.message,
                recoverable: payload.recoverable
            )
        }
    }

    static func == (lhs: ConnectionError, rhs: ConnectionError) -> Bool {
        switch (lhs, rhs) {
        case (.serverAtCapacity, .serverAtCapacity): return true
        case (.agentTimedOut, .agentTimedOut): return true
        case (.connectionReplaced, .connectionReplaced): return true
        case (.queueFull, .queueFull): return true
        case (.rateLimited(let a), .rateLimited(let b)): return a == b
        case (.reconnectFailed, .reconnectFailed): return true
        case (.networkUnavailable, .networkUnavailable): return true
        case (.invalidServerURL, .invalidServerURL): return true
        case (.sessionNotFound, .sessionNotFound): return true
        case (.sessionInvalid, .sessionInvalid): return true
        case (.serverError(let c1, let m1, let r1), .serverError(let c2, let m2, let r2)):
            return c1 == c2 && m1 == m2 && r1 == r2
        default: return false
        }
    }
}

// MARK: - Stream Message Types

/// Stream message wrapper - contains the actual message content
struct CLIStreamMessage: Decodable {
    let message: CLIStreamContent

    private enum CodingKeys: String, CodingKey {
        case message
    }
}

/// The content inside a stream message
/// Maps to cli-bridge StreamMessage types
enum CLIStreamContent: Decodable {
    case assistant(CLIAssistantContent)  // Text from Claude
    case user(CLIUserContent)            // User message echo
    case system(CLISystemContent)        // System messages
    case thinking(CLIThinkingContent)    // Extended thinking
    case toolUse(CLIToolUseContent)      // Tool execution starting
    case toolResult(CLIToolResultContent)
    case progress(CLIProgressContent)
    case usage(CLIUsageContent)
    case state(CLIStateContent)          // Agent state changes
    case subagentStart(CLISubagentStartContent)
    case subagentComplete(CLISubagentCompleteContent)
    case question(CLIQuestionRequest)    // AskUserQuestion request (can come via stream)
    case permission(CLIPermissionRequest)  // Permission request (can come via stream)
    // Note: stopped/interrupted are now top-level CLIServerMessage types

    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "assistant":
            self = .assistant(try CLIAssistantContent(from: decoder))
        case "user":
            self = .user(try CLIUserContent(from: decoder))
        case "system":
            self = .system(try CLISystemContent(from: decoder))
        case "thinking":
            self = .thinking(try CLIThinkingContent(from: decoder))
        case "tool_use":
            self = .toolUse(try CLIToolUseContent(from: decoder))
        case "tool_result":
            self = .toolResult(try CLIToolResultContent(from: decoder))
        case "progress":
            self = .progress(try CLIProgressContent(from: decoder))
        case "usage":
            self = .usage(try CLIUsageContent(from: decoder))
        case "state":
            self = .state(try CLIStateContent(from: decoder))
        case "subagent_start":
            self = .subagentStart(try CLISubagentStartContent(from: decoder))
        case "subagent_complete":
            self = .subagentComplete(try CLISubagentCompleteContent(from: decoder))
        case "question":
            self = .question(try CLIQuestionRequest(from: decoder))
        case "permission":
            self = .permission(try CLIPermissionRequest(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown stream content type: \(type)"
            )
        }
    }
}

// MARK: - Stream Content Types

/// Assistant message content (streaming text from Claude)
struct CLIAssistantContent: Decodable {
    let content: String
    let delta: Bool?  // True for streaming chunks, nil/false for complete

    /// Convenience: returns true if this is not a streaming delta
    /// NOTE: When delta is nil (missing from JSON), we treat it as final.
    /// This matches cli-bridge behavior where delta=true means streaming chunk.
    var isFinal: Bool {
        !(delta ?? false)
    }

    // Custom decoding to capture the raw delta value for debugging
    private enum CodingKeys: String, CodingKey {
        case content
        case delta
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = try container.decode(String.self, forKey: .content)
        delta = try container.decodeIfPresent(Bool.self, forKey: .delta)
        // DEBUG: Log raw delta value
        // print("[CLIAssistantContent] Decoded: delta=\(String(describing: delta)), content.count=\(content.count)")
    }
}

/// User message echo (sent back by server)
struct CLIUserContent: Decodable {
    let content: String
}

/// System message content
struct CLISystemContent: Decodable {
    let content: String
    let subtype: String?  // "init" | "result" | "progress"
}

/// Thinking/reasoning block content
struct CLIThinkingContent: Decodable {
    let content: String
    // Note: cli-bridge doesn't send 'id' for thinking blocks
}

/// Tool use message - when a tool starts executing
struct CLIToolUseContent: Decodable {
    let id: String
    let name: String  // Tool name (e.g., "Bash", "Read", "Edit")
    let input: [String: AnyCodableValue]
}

/// Tool result message - when a tool completes
struct CLIToolResultContent: Decodable {
    let id: String
    let tool: String
    let output: String
    let success: Bool
    let isError: Bool?  // Optional additional error flag
}

/// Progress message for long-running tools
struct CLIProgressContent: Decodable {
    let id: String        // Correlates to tool_use.id
    let tool: String
    let elapsed: Double   // Seconds since start (changed to Double for precision)
    let progress: Int?    // 0-100 percentage (optional)
    let detail: String?   // Human-readable status

    // Manual initializer for previews and testing
    init(id: String = "", tool: String, elapsed: Double = 0, progress: Int? = nil, detail: String? = nil) {
        self.id = id
        self.tool = tool
        self.elapsed = elapsed
        self.progress = progress
        self.detail = detail
    }

    /// Elapsed time as Int for UI compatibility
    var elapsedSeconds: Int {
        Int(elapsed)
    }
}

/// Token usage information
struct CLIUsageContent: Decodable {
    // Note: cli-bridge doesn't send 'id' for usage messages
    let inputTokens: Int
    let outputTokens: Int
    let cacheReadTokens: Int?
    let cacheCreateTokens: Int?
    let totalCost: Double?
    let contextUsed: Int?   // Made optional - may not always be present
    let contextLimit: Int?  // Made optional - may not always be present

    /// Total tokens used (input + output)
    var totalTokens: Int {
        inputTokens + outputTokens
    }

    /// Percentage of context window used
    var contextPercentage: Double {
        guard let used = contextUsed, let limit = contextLimit, limit > 0 else { return 0 }
        return Double(used) / Double(limit) * 100
    }
}

/// Agent state change message
struct CLIStateContent: Decodable {
    let state: CLIAgentState
    let tool: String?  // Tool name if state is "executing"
}

struct CLISubagentStartContent: Decodable {
    let id: String
    let description: String
    let agentType: String?  // Optional - agent type (e.g., "code-reviewer")

    // Manual initializer for previews and testing
    init(id: String = "", description: String, agentType: String? = nil) {
        self.id = id
        self.description = description
        self.agentType = agentType
    }

    // Display-friendly agent type
    var displayAgentType: String {
        agentType ?? "Task"
    }
}

struct CLISubagentCompleteContent: Decodable {
    let id: String
    let summary: String?  // Made optional: cli-bridge may not send summary

    // Manual initializer for previews and testing
    init(id: String = "", summary: String? = nil) {
        self.id = id
        self.summary = summary
    }

    /// Display-friendly summary with fallback
    var displaySummary: String {
        summary ?? "Task completed"
    }
}

// MARK: - Agent State

/// Agent state values from cli-bridge
/// Maps to: "starting" | "thinking" | "executing" | "waiting_input" | "waiting_permission" | "idle" | "recovering" | "stopped"
enum CLIAgentState: String, Decodable, Equatable {
    case starting           // Agent initializing
    case thinking           // Processing, generating response
    case executing          // Executing a tool
    case waitingInput = "waiting_input"       // Waiting for user input
    case waitingPermission = "waiting_permission"  // Waiting for permission approval
    case idle               // Ready for input
    case recovering         // Recovering from error/disconnect
    case stopped            // Agent terminated

    var displayText: String {
        switch self {
        case .starting: return "Starting..."
        case .thinking: return "Thinking..."
        case .executing: return "Running tool..."
        case .waitingInput: return "Waiting for input..."
        case .waitingPermission: return "Waiting for approval..."
        case .idle: return "Ready"
        case .recovering: return "Recovering..."
        case .stopped: return "Stopped"
        }
    }

    var isProcessing: Bool {
        switch self {
        case .thinking, .executing, .starting:
            return true
        default:
            return false
        }
    }

    var isWaiting: Bool {
        switch self {
        case .waitingInput, .waitingPermission:
            return true
        default:
            return false
        }
    }

    var canSendInput: Bool {
        switch self {
        case .idle, .thinking, .executing:
            return true  // Can queue input during thinking/executing
        default:
            return false
        }
    }

    /// True if the agent is active (not stopped or starting)
    var isActive: Bool {
        switch self {
        case .stopped:
            return false
        default:
            return true
        }
    }
}

// MARK: - Permission Request

struct CLIPermissionRequest: Decodable {
    let id: String
    let tool: String
    let input: [String: AnyCodableValue]
    let options: [String]  // ["allow", "deny", "always"]

    /// Get a human-readable description of what's being requested
    var description: String {
        // Extract common fields for description
        if let command = input["command"]?.stringValue {
            return "Run command: \(command)"
        }
        if let filePath = input["file_path"]?.stringValue ?? input["filePath"]?.stringValue {
            return "\(tool): \(filePath)"
        }
        return tool
    }
}

// MARK: - Question Request (AskUserQuestion)

struct CLIQuestionRequest: Decodable {
    let id: String
    let questions: [CLIQuestionItem]
}

struct CLIQuestionItem: Decodable {
    let question: String
    let header: String
    let options: [CLIQuestionOption]
    let multiSelect: Bool
}

struct CLIQuestionOption: Decodable {
    let label: String
    let description: String?
}

// MARK: - Session Event

struct CLISessionEvent: Decodable {
    let action: SessionAction
    let projectPath: String
    let sessionId: String
    let metadata: CLISessionMetadata?

    enum SessionAction: String, Decodable {
        case created
        case updated
        case deleted
    }
}

// MARK: - Session Metadata

struct CLISessionMetadata: Decodable {
    let id: String
    let projectPath: String      // Fixed: was 'project', cli-bridge sends 'projectPath'
    let messageCount: Int
    let createdAt: String        // Added: cli-bridge sends this
    let lastActivityAt: String
    let lastUserMessage: String?
    let lastAssistantMessage: String?
    let title: String?
    let customTitle: String?     // Added: cli-bridge sends this (user-set title)
    let model: String?
    let source: SessionSource?

    enum SessionSource: String, Decodable {
        case user
        case agent
        case helper
    }

    /// Parse createdAt as Date
    var createdDate: Date? {
        ISO8601DateFormatter().date(from: createdAt)
    }

    /// Parse lastActivityAt as Date
    var lastActivityDate: Date? {
        ISO8601DateFormatter().date(from: lastActivityAt)
    }

    /// Display title - prefers customTitle over auto-generated title
    /// Parses JSON content block format if present
    /// Falls back to lastUserMessage if title parsing fails
    var displayTitle: String? {
        if let custom = customTitle, !custom.isEmpty {
            return custom
        }

        // Try parsing title first
        if let t = title, !t.isEmpty {
            let parsed = parseContentBlockText(t)
            // If parsing succeeded (doesn't look like raw JSON), use it
            if !parsed.hasPrefix("[{") && !parsed.hasPrefix("[\"") {
                return parsed
            }
            // Title is truncated/unparseable, fall through to lastUserMessage
        }

        // Fallback to parsed lastUserMessage (usually complete, unlike truncated title)
        if let msg = lastUserMessage, !msg.isEmpty {
            let parsed = parseContentBlockText(msg)
            // Only use if parsing succeeded
            if !parsed.hasPrefix("[{") && !parsed.hasPrefix("[\"") {
                return parsed
            }
        }

        // Last resort: return whatever title we have, even if it's JSON-ish
        if let t = title, !t.isEmpty {
            // Strip JSON prefix for display if present
            // [{"type":"text","text":" = 24 characters
            if t.hasPrefix("[{\"type\":\"text\",\"text\":\"") {
                let stripped = String(t.dropFirst(24))
                // Remove trailing incomplete parts
                if let dotDotDot = stripped.range(of: "...") {
                    return String(stripped[..<dotDotDot.lowerBound])
                }
                return stripped.replacingOccurrences(of: "\"}]", with: "")
            }
            return t
        }

        return nil
    }

    /// Parsed last user message (handles JSON content block format)
    var parsedLastUserMessage: String? {
        guard let msg = lastUserMessage else { return nil }
        return parseContentBlockText(msg)
    }

    /// Parse content block JSON format: [{"type":"text","text":"..."}] → plain text
    /// Falls back to original string if not valid JSON
    private func parseContentBlockText(_ text: String) -> String {
        // If it doesn't look like JSON array, return as-is
        guard text.hasPrefix("[") else { return text }

        // Try to parse as JSON array of content blocks
        guard let data = text.data(using: .utf8) else {
            log.debug("[parseContentBlockText] Failed to convert to data: \(text.prefix(50))")
            return extractTextFallback(text)
        }

        // Try parsing as [[String: Any]] (standard format)
        do {
            if let blocks = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                // Extract text from "text" type blocks
                var textParts = blocks.compactMap { block -> String? in
                    guard block["type"] as? String == "text" else { return nil }
                    return block["text"] as? String
                }

                // If no text blocks, also try extracting from "content" field (tool_result blocks)
                if textParts.isEmpty {
                    textParts = blocks.compactMap { block -> String? in
                        if let content = block["content"] as? String {
                            return content
                        }
                        return nil
                    }
                }

                if !textParts.isEmpty {
                    return textParts.joined(separator: " ")
                }
            }
        } catch {
            log.debug("[parseContentBlockText] JSON parsing error: \(error.localizedDescription)")
        }

        // Try parsing as [Any] and handle mixed content
        if let array = try? JSONSerialization.jsonObject(with: data) as? [Any] {
            let textParts = array.compactMap { item -> String? in
                if let dict = item as? [String: Any] {
                    if dict["type"] as? String == "text" {
                        return dict["text"] as? String
                    }
                    // Also try content field for tool results
                    if let content = dict["content"] as? String {
                        return content
                    }
                }
                return nil
            }
            if !textParts.isEmpty {
                return textParts.joined(separator: " ")
            }
        }

        // JSON parsing failed or no content found - try regex-based extraction as last resort
        log.debug("[parseContentBlockText] No content extracted, trying regex fallback: \(text.prefix(100))")
        return extractTextFallback(text)
    }

    /// Fallback text extraction using regex when JSON parsing fails
    /// Extracts content from patterns like "text":"actual content"
    /// Also handles truncated content without closing quotes
    private func extractTextFallback(_ text: String) -> String {
        // First try: Pattern with closing quote - matches complete "text":"content"
        let completePattern = #""text"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)""#
        if let regex = try? NSRegularExpression(pattern: completePattern, options: []) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, options: [], range: range)

            var extractedParts: [String] = []
            for match in matches {
                if match.numberOfRanges >= 2,
                   let captureRange = Range(match.range(at: 1), in: text) {
                    let extracted = String(text[captureRange])
                    // Unescape common JSON escape sequences
                    let unescaped = extracted
                        .replacingOccurrences(of: "\\n", with: "\n")
                        .replacingOccurrences(of: "\\t", with: "\t")
                        .replacingOccurrences(of: "\\\"", with: "\"")
                        .replacingOccurrences(of: "\\\\", with: "\\")
                    extractedParts.append(unescaped)
                }
            }

            if !extractedParts.isEmpty {
                return extractedParts.joined(separator: " ")
            }
        }

        // Second try: Handle truncated titles like [{"type":"text","text":"What...
        // Pattern matches "text":" followed by anything until end (no closing quote required)
        let truncatedPattern = #""text"\s*:\s*"(.+)$"#
        if let regex = try? NSRegularExpression(pattern: truncatedPattern, options: []),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..<text.endIndex, in: text)),
           match.numberOfRanges >= 2,
           let captureRange = Range(match.range(at: 1), in: text) {
            var extracted = String(text[captureRange])
            // Remove trailing truncation markers and incomplete JSON
            extracted = extracted
                .replacingOccurrences(of: "...", with: "")
                .replacingOccurrences(of: "\"}]", with: "")
                .replacingOccurrences(of: "\"}", with: "")
                .replacingOccurrences(of: "\"", with: "")
            // Unescape JSON escape sequences
            let unescaped = extracted
                .replacingOccurrences(of: "\\n", with: " ")
                .replacingOccurrences(of: "\\t", with: " ")
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\\\", with: "\\")
                .trimmingCharacters(in: .whitespaces)
            if !unescaped.isEmpty {
                return unescaped
            }
        }

        // If all else fails, return the original text
        return text
    }

    /// True if this is a helper session (should be hidden from user)
    var isHelper: Bool {
        source == .helper
    }

    /// True if this is a sub-agent session (should be hidden from user)
    var isAgent: Bool {
        source == .agent
    }

    /// True if this should be shown in the user's session list
    var isUserVisible: Bool {
        source == nil || source == .user
    }
}

// MARK: - Project Types

struct CLIProject: Decodable {
    let path: String
    let name: String
    let lastUsed: String?
    let sessionCount: Int?
    let git: CLIGitStatus?

    /// Compute encodedPath from path (cli-bridge doesn't send this)
    var encodedPath: String {
        // Convert /home/dev/project → -home-dev-project
        path.replacingOccurrences(of: "/", with: "-")
    }
}

/// Project detail with README and structure info
struct CLIProjectDetail: Decodable {
    let path: String
    let name: String
    let lastUsed: String?
    let sessionCount: Int?
    let git: CLIGitStatus?
    let readme: String?              // README.md contents (first 5000 chars)
    let structure: CLIProjectStructure?

    /// Compute encodedPath from path
    var encodedPath: String {
        path.replacingOccurrences(of: "/", with: "-")
    }
}

/// Project structure detection
struct CLIProjectStructure: Decodable {
    let hasPackageJson: Bool?        // Node.js project
    let hasCargoToml: Bool?          // Rust project
    let hasGoMod: Bool?              // Go project
    let hasPyproject: Bool?          // Python project
    let hasDenoJson: Bool?           // Deno project
    let primaryLanguage: String?     // Detected primary language

    /// Get project type badges for display
    var projectTypeBadges: [(icon: String, label: String, color: String)] {
        var badges: [(icon: String, label: String, color: String)] = []
        if hasPackageJson == true {
            badges.append(("cube.box", "Node.js", "green"))
        }
        if hasCargoToml == true {
            badges.append(("gearshape.2", "Rust", "orange"))
        }
        if hasGoMod == true {
            badges.append(("bolt", "Go", "cyan"))
        }
        if hasPyproject == true {
            badges.append(("snake", "Python", "yellow"))
        }
        if hasDenoJson == true {
            badges.append(("dinosaur", "Deno", "purple"))
        }
        return badges
    }
}

struct CLIGitStatus: Decodable {
    let branch: String?
    let status: String?          // "clean", "modified", "untracked", "conflict"
    let remote: String?          // Remote name (usually "origin")
    let remoteUrl: String?       // Git remote URL
    let ahead: Int?              // Commits ahead of remote
    let behind: Int?             // Commits behind remote
    let hasUncommitted: Bool?    // Has staged or unstaged changes
    let hasUntracked: Bool?      // Has untracked files

    // cli-bridge specific fields (different from legacy format)
    let isClean: Bool?           // Server sends this directly
    let uncommittedCount: Int?   // Number of uncommitted changes

    /// Whether the repository is clean (checks server field first, then status)
    var repoIsClean: Bool {
        // Prefer server's isClean field if available
        if let serverIsClean = isClean {
            return serverIsClean
        }
        // Fall back to status check for legacy format
        return status == "clean"
    }

    /// Convert to existing GitStatus enum for UI compatibility
    var toGitStatus: GitStatus {
        guard branch != nil else {
            return .notGitRepo
        }

        // Check for conflicts first
        if status == "conflict" {
            return .diverged
        }

        // Check ahead/behind status
        let aheadCount = ahead ?? 0
        let behindCount = behind ?? 0

        // Determine if dirty: check uncommittedCount, hasUncommitted, or isClean
        let isDirty: Bool
        if let count = uncommittedCount {
            isDirty = count > 0
        } else if let hasUncommitted = hasUncommitted {
            isDirty = hasUncommitted
        } else {
            isDirty = !repoIsClean
        }

        if isDirty && aheadCount > 0 {
            return .dirtyAndAhead
        }
        if aheadCount > 0 && behindCount > 0 {
            return .diverged
        }
        if aheadCount > 0 {
            return .ahead(aheadCount)
        }
        if behindCount > 0 {
            return .behind(behindCount)
        }
        if isDirty {
            return .dirty
        }
        return .clean
    }
}

// MARK: - File Browser Types

struct CLIFileEntry: Decodable, Identifiable {
    let name: String
    let path: String
    let type: String?            // "file" or "directory"
    let size: Int?
    let modified: String?
    let `extension`: String?     // File extension (null for directories)
    let childCount: Int?         // Number of children (for directories)

    var id: String { path }

    /// Whether this entry is a directory
    var isDir: Bool {
        type == "directory"
    }

    var modifiedDate: Date? {
        guard let modified = modified else { return nil }
        return ISO8601DateFormatter().date(from: modified)
    }

    /// SF Symbol icon for this file type
    var icon: String {
        if isDir { return "folder.fill" }
        switch `extension`?.lowercased() {
        case "swift": return "swift"
        case "ts", "tsx": return "t.square"
        case "js", "jsx": return "j.square"
        case "json": return "curlybraces"
        case "md", "markdown": return "doc.text"
        case "png", "jpg", "jpeg", "gif", "webp", "svg": return "photo"
        case "pdf": return "doc.richtext"
        case "html", "htm": return "globe"
        case "css", "scss", "less": return "paintbrush"
        case "py": return "chevron.left.forwardslash.chevron.right"
        case "rs": return "gearshape.2"
        case "go": return "bolt"
        case "rb": return "diamond"
        case "java", "kt": return "cup.and.saucer"
        case "sh", "bash", "zsh": return "terminal"
        case "yml", "yaml", "toml": return "gearshape"
        case "lock": return "lock"
        case "env": return "key"
        case "gitignore", "dockerignore": return "eye.slash"
        default: return "doc"
        }
    }

    /// Formatted file size
    var formattedSize: String? {
        guard let size = size, !isDir else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

struct CLIFileListResponse: Decodable {
    let path: String
    let entries: [CLIFileEntry]
    let parent: String?          // Parent directory (null if at root)
}

struct CLIFileContentResponse: Decodable {
    let path: String
    let name: String?
    let content: String
    let size: Int?
    let modified: String?
    let mimeType: String?
    let language: String?        // Detected language for syntax highlighting
    let lineCount: Int?

    /// File name extracted from path
    var fileName: String {
        name ?? (path as NSString).lastPathComponent
    }

    /// Formatted file size
    var formattedSize: String? {
        guard let size = size else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }

    /// Modified date
    var modifiedDate: Date? {
        guard let modified = modified else { return nil }
        return ISO8601DateFormatter().date(from: modified)
    }
}

// MARK: - Search Types

/// A snippet of matching text with highlight information
struct CLISearchSnippet: Codable, Identifiable, Equatable {
    let type: String        // "user", "assistant", "system", "tool_use", "tool_result"
    let text: String        // Matched text with surrounding context
    let matchStart: Int     // Character position where match begins
    let matchLength: Int    // Length of the matched text

    var id: String { "\(type)-\(matchStart)" }

    /// Extract the matched portion
    var matchedText: String {
        let start = text.index(text.startIndex, offsetBy: matchStart, limitedBy: text.endIndex) ?? text.startIndex
        let end = text.index(start, offsetBy: matchLength, limitedBy: text.endIndex) ?? text.endIndex
        return String(text[start..<end])
    }

    /// Text before the match
    var beforeMatch: String {
        let end = text.index(text.startIndex, offsetBy: matchStart, limitedBy: text.endIndex) ?? text.startIndex
        return String(text[..<end])
    }

    /// Text after the match
    var afterMatch: String {
        let matchEnd = matchStart + matchLength
        let start = text.index(text.startIndex, offsetBy: matchEnd, limitedBy: text.endIndex) ?? text.endIndex
        return String(text[start...])
    }

    /// SF Symbol icon for message type
    var messageTypeIcon: String {
        switch type {
        case "user": return "person.fill"
        case "assistant": return "sparkle"
        case "system": return "gearshape.fill"
        case "tool_use": return "hammer.fill"
        case "tool_result": return "doc.text.fill"
        default: return "text.bubble"
        }
    }
}

/// A search result containing session info and matching snippets
struct CLISearchResult: Codable, Identifiable, Equatable {
    let sessionId: String
    let projectPath: String
    let snippets: [CLISearchSnippet]
    let score: Double
    let timestamp: String

    var id: String { sessionId }

    /// Parsed timestamp as Date
    var date: Date? {
        ISO8601DateFormatter().date(from: timestamp)
    }

    /// Project name extracted from path
    var projectName: String {
        URL(fileURLWithPath: projectPath).lastPathComponent
    }

    /// Formatted relative date
    var formattedDate: String {
        guard let date = date else { return timestamp }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Convenience accessor for the first snippet's text
    var snippet: String {
        snippets.first?.text ?? ""
    }
}

/// Search response with pagination
struct CLISearchResponse: Codable {
    let query: String
    let total: Int
    let results: [CLISearchResult]
    let hasMore: Bool
}

/// Error response from search endpoint
struct CLISearchError: Codable {
    let error: String
    let message: String
}

// MARK: - Export Types

/// Export format options
enum CLIExportFormat: String, Codable {
    case markdown
    case json
}

/// Export response - manually constructed since cli-bridge returns raw content
struct CLIExportResponse {
    let sessionId: String
    let format: CLIExportFormat
    let content: String

    init(sessionId: String, format: CLIExportFormat, content: String) {
        self.sessionId = sessionId
        self.format = format
        self.content = content
    }
}

// MARK: - Conversion to App Models

extension CLISessionMetadata {
    /// Convert to ProjectSession for use with existing SessionStore
    /// Parses JSON content block format for title and lastUserMessage
    func toProjectSession() -> ProjectSession {
        return ProjectSession(
            id: id,
            summary: displayTitle,  // Uses parsed title (handles JSON content block format)
            messageCount: messageCount,
            lastActivity: lastActivityAt,
            lastUserMessage: parsedLastUserMessage,  // Parsed from JSON content block format
            lastAssistantMessage: lastAssistantMessage  // Already plain text from Claude
        )
    }
}

extension Array where Element == CLISessionMetadata {
    /// Convert array of CLISessionMetadata to ProjectSession
    func toProjectSessions() -> [ProjectSession] {
        return map { $0.toProjectSession() }
    }
}

extension CLIFileEntry {
    /// Convert to FileEntry for use with existing FilePickerSheet
    func toFileEntry() -> FileEntry {
        return FileEntry(
            name: name,
            path: path,
            isDirectory: isDir,
            isSymlink: false,  // CLI Bridge doesn't expose symlink info
            size: Int64(size ?? 0),
            permissions: ""    // CLI Bridge doesn't expose permissions
        )
    }
}

extension Array where Element == CLIFileEntry {
    /// Convert array of CLIFileEntry to FileEntry
    func toFileEntries() -> [FileEntry] {
        return map { $0.toFileEntry() }
    }
}

// Note: Permission types (PermissionConfig, PermissionConfigUpdate, etc.) are defined in PermissionTypes.swift

// MARK: - Push Notification Types

/// Request to register FCM token for push notifications
struct CLIPushRegisterRequest: Encodable {
    let fcmToken: String
    let platform: String
    let environment: String
    let appVersion: String?
    let osVersion: String?

    init(fcmToken: String, environment: String, appVersion: String? = nil, osVersion: String? = nil) {
        self.fcmToken = fcmToken
        self.platform = "ios"
        self.environment = environment
        self.appVersion = appVersion
        self.osVersion = osVersion
    }
}

/// Response from push token registration
struct CLIPushRegisterResponse: Decodable {
    let success: Bool
    let tokenId: String?
}

/// Request to register Live Activity push token
struct CLILiveActivityRegisterRequest: Encodable {
    let pushToken: String
    let pushToStartToken: String?
    let activityId: String
    let sessionId: String
    let attributesType: String?
    let platform: String
    let environment: String

    init(
        pushToken: String,
        pushToStartToken: String? = nil,
        activityId: String,
        sessionId: String,
        attributesType: String? = "CodingBridgeAttributes",
        environment: String
    ) {
        self.pushToken = pushToken
        self.pushToStartToken = pushToStartToken
        self.activityId = activityId
        self.sessionId = sessionId
        self.attributesType = attributesType
        self.platform = "ios"
        self.environment = environment
    }
}

/// Response from Live Activity token registration
struct CLILiveActivityRegisterResponse: Decodable {
    let success: Bool
    let activityTokenId: String?
}

/// Request to invalidate push token
struct CLIPushInvalidateRequest: Encodable {
    let tokenType: String  // "fcm" or "live_activity"
    let token: String

    enum TokenType: String {
        case fcm
        case liveActivity = "live_activity"
    }

    init(tokenType: TokenType, token: String) {
        self.tokenType = tokenType.rawValue
        self.token = token
    }
}

/// Response from push status endpoint
struct CLIPushStatusResponse: Decodable {
    let provider: String
    let providerEnabled: Bool
    let fcmTokenRegistered: Bool
    let fcmTokenLastUpdated: String?
    let liveActivityTokens: [LiveActivityTokenInfo]
}

/// Information about a registered Live Activity token
struct LiveActivityTokenInfo: Decodable {
    let activityId: String
    let sessionId: String
    let registeredAt: String
    let hasUpdateToken: Bool
    let hasPushToStartToken: Bool
}

/// Generic success response for push operations
struct CLIPushSuccessResponse: Decodable {
    let success: Bool
}
