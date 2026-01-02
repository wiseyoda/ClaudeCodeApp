import Foundation

// MARK: - CLI Bridge Types Migration
// Typealiases bridging old CLI* names to new generated types
//
// This file enables gradual migration from hand-written CLI* types to
// generated OpenAPI types. Once all callers are updated, these typealiases
// can be removed.
//
// See: scripts/regenerate-api-types.sh for code generation
// See: CLAUDE.md "Generated API Types" section

// ============================================================================
// MARK: - App-Only Types (Not Protocol Types)
// ============================================================================
// These types are app-specific and not part of the cli-bridge protocol.
// They are preserved here during migration from CLIBridgeTypes.swift.

/// Shared ISO8601 date formatters to avoid creating multiple instances
public enum CLIDateFormatter {
    /// Formatter with fractional seconds (e.g., "2024-01-15T10:30:00.123Z")
    public static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Formatter without fractional seconds (e.g., "2024-01-15T10:30:00Z")
    public static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Parse a date string, trying fractional seconds first, then without
    public static func parseDate(_ dateString: String) -> Date? {
        if let date = iso8601WithFractionalSeconds.date(from: dateString) {
            return date
        }
        return iso8601.date(from: dateString)
    }

    /// Format a date to ISO8601 string with fractional seconds
    public static func string(from date: Date) -> String {
        iso8601WithFractionalSeconds.string(from: date)
    }
}

/// Token usage information for display
public struct TokenUsage: Equatable, Sendable {
    public let used: Int
    public let total: Int

    public init(used: Int, total: Int) {
        self.used = used
        self.total = total
    }

    public var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total) * 100
    }
}

/// Type-erased wrapper for encoding/decoding arbitrary JSON values
/// Note: Consider using JSONValue (generated type) for new code
public struct AnyCodableValue: Codable, Equatable, Hashable, Sendable {
    public let value: any Sendable

    public init(_ value: Any) {
        // Convert to Sendable types
        switch value {
        case let sendable as (any Sendable):
            self.value = sendable
        default:
            self.value = String(describing: value)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = Optional<String>.none as Any
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodableValue].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodableValue].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.typeMismatch(
                AnyCodableValue.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Unable to decode AnyCodableValue")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case Optional<Any>.none:
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
                .init(codingPath: encoder.codingPath, debugDescription: "Unable to encode AnyCodableValue")
            )
        }
    }

    public static func == (lhs: AnyCodableValue, rhs: AnyCodableValue) -> Bool {
        // Compare string representations for simplicity
        String(describing: lhs.value) == String(describing: rhs.value)
    }

    public func hash(into hasher: inout Hasher) {
        // Hash based on string representation for simplicity
        hasher.combine(String(describing: value))
    }

    /// Get value as String if it is one
    public var stringValue: String? {
        value as? String
    }
}

/// Backward-compatible typealias for AnyCodableValue
public typealias AnyCodable = AnyCodableValue

// ============================================================================
// MARK: - App-Specific Agent State
// ============================================================================
// Extended agent state that includes app-local states (starting, stopped)
// in addition to protocol states from StateStreamMessage.State

/// Agent state for UI display - extends protocol states with app-local states
public enum CLIAgentState: String, Codable, Equatable, Sendable {
    // Protocol states (from StateStreamMessage.State)
    case thinking
    case executing
    case waitingInput = "waiting_input"
    case waitingPermission = "waiting_permission"
    case idle
    case recovering

    // App-local states (not from protocol)
    case starting
    case stopped
    case networkUnavailable

    /// Create from protocol state
    public init(from protocolState: StateStreamMessage.State) {
        switch protocolState {
        case .thinking: self = .thinking
        case .executing: self = .executing
        case .waitingInput: self = .waitingInput
        case .waitingPermission: self = .waitingPermission
        case .idle: self = .idle
        case .recovering: self = .recovering
        }
    }

    /// Whether the agent is currently processing (thinking or executing)
    public var isProcessing: Bool {
        switch self {
        case .thinking, .executing:
            return true
        case .idle, .starting, .stopped, .waitingInput, .waitingPermission, .recovering, .networkUnavailable:
            return false
        }
    }

    /// Whether the agent is actively working (thinking, executing, or recovering)
    public var isWorking: Bool {
        switch self {
        case .thinking, .executing, .recovering:
            return true
        case .idle, .starting, .stopped, .waitingInput, .waitingPermission, .networkUnavailable:
            return false
        }
    }
}

/// Connection error types for CLI Bridge
public enum ConnectionError: Error, LocalizedError {
    case networkUnavailable
    case invalidServerURL
    case connectionFailed(String)
    case authenticationFailed
    case sessionExpired
    case sessionNotFound
    case sessionInvalid
    case connectionReplaced
    case reconnectFailed
    case protocolError(String)
    case unknown(String)
    case serverAtCapacity
    case queueFull
    case agentTimedOut
    case rateLimited(Int)
    case serverError(Int, String, String?)

    public var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Network is unavailable"
        case .invalidServerURL:
            return "Invalid server URL"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .authenticationFailed:
            return "Authentication failed"
        case .sessionExpired:
            return "Session expired"
        case .sessionNotFound:
            return "Session not found"
        case .sessionInvalid:
            return "Session is invalid"
        case .connectionReplaced:
            return "Connection replaced by another client"
        case .reconnectFailed:
            return "Failed to reconnect to session"
        case .protocolError(let message):
            return "Protocol error: \(message)"
        case .unknown(let message):
            return message
        case .serverAtCapacity:
            return "Server is at capacity"
        case .queueFull:
            return "Request queue is full"
        case .agentTimedOut:
            return "Agent timed out"
        case .rateLimited(let retryAfter):
            return "Rate limited, retry in \(retryAfter) seconds"
        case .serverError(_, let message, _):
            return message
        }
    }

    /// Create from WsErrorMessage
    public static func from(_ error: WsErrorMessage) -> ConnectionError {
        switch error.code {
        case "connection_replaced":
            return .connectionReplaced
        case "session_not_found":
            return .sessionNotFound
        case "session_expired":
            return .sessionExpired
        case "session_invalid", "cursor_invalid":
            return .sessionInvalid
        case "authentication_failed":
            return .authenticationFailed
        default:
            return .protocolError(error.message)
        }
    }
}

/// Error codes for CLI Bridge errors (matches WsErrorMessage.code)
public enum CLIErrorCode: String, Sendable {
    case connectionReplaced = "connection_replaced"
    case agentNotFound = "agent_not_found"
    case sessionNotFound = "session_not_found"
    case sessionInvalid = "session_invalid"
    case sessionExpired = "session_expired"
    case rateLimited = "rate_limited"
    case maxAgentsReached = "max_agents_reached"
    case queueFull = "queue_full"
    case authenticationFailed = "authentication_failed"
    case cursorEvicted = "cursor_evicted"
    case cursorInvalid = "cursor_invalid"
}

/// Extension to provide errorCode computed property
extension WsErrorMessage {
    /// Parse the string code into a typed CLIErrorCode
    public var errorCode: CLIErrorCode? {
        CLIErrorCode(rawValue: code)
    }
}

// ============================================================================
// MARK: - ClientMessage Convenience Extensions
// ============================================================================
// Extensions to provide short case names for ClientMessage

extension ClientMessage {
    /// Create a start message
    public static func start(_ payload: StartMessage) -> ClientMessage {
        .typeStartMessage(payload)
    }

    /// Create a reconnect message
    public static func reconnect(_ payload: ReconnectMessage) -> ClientMessage {
        .typeReconnectMessage(payload)
    }

    /// Create an input message
    public static func input(_ payload: InputMessage) -> ClientMessage {
        .typeInputMessage(payload)
    }

    /// Create a permission response
    public static func permissionResponse(_ payload: PermissionResponseMessage) -> ClientMessage {
        .typePermissionResponseMessage(payload)
    }

    /// Create a question response
    public static func questionResponse(_ payload: QuestionResponseMessage) -> ClientMessage {
        .typeQuestionResponseMessage(payload)
    }

    /// Create an interrupt message
    public static var interrupt: ClientMessage {
        .typeInterruptMessage(InterruptMessage(type: .interrupt))
    }

    /// Create a stop message
    public static var stop: ClientMessage {
        .typeStopMessage(StopMessage(type: .stop))
    }

    /// Create a ping message
    public static var ping: ClientMessage {
        .typePingMessage(PingMessage(type: .ping))
    }

    /// Create a set model message
    public static func setModel(_ payload: SetModelMessage) -> ClientMessage {
        .typeSetModelMessage(payload)
    }

    /// Create a set permission mode message
    public static func setPermissionMode(_ payload: SetPermissionModeMessage) -> ClientMessage {
        .typeSetPermissionModeMessage(payload)
    }

    /// Create a retry message
    public static func retry(_ payload: RetryMessage) -> ClientMessage {
        .typeRetryMessage(payload)
    }

    /// Create a cancel queued message
    public static var cancelQueued: ClientMessage {
        .typeCancelQueuedMessage(CancelQueuedMessage(type: .cancelQueued))
    }

    /// Create a subscribe sessions message
    public static func subscribeSessions(_ payload: SubscribeSessionsMessage) -> ClientMessage {
        .typeSubscribeSessionsMessage(payload)
    }
}

// ============================================================================
// MARK: - Message Type Convenience Extensions
// ============================================================================

/// Convenience initializers for StartMessage (doesn't require `type` parameter)
extension StartMessage {
    public init(projectPath: String, sessionId: String? = nil, model: String? = nil, helper: Bool? = nil) {
        self.init(
            type: .start,
            projectPath: projectPath,
            sessionId: sessionId.flatMap { UUID(uuidString: $0) },
            model: model,
            helper: helper
        )
    }
}

/// Convenience initializers for InputMessage (doesn't require `type` parameter)
extension InputMessage {
    public init(text: String, images: [APIImageAttachment]? = nil, messageId: String? = nil, thinkingMode: String? = nil) {
        self.init(type: .input, text: text, images: images, messageId: messageId, thinkingMode: thinkingMode)
    }

    /// Convenience init that accepts app's ImageAttachment type and converts to APIImageAttachment
    init(text: String, images: [ImageAttachment]?, messageId: String? = nil, thinkingMode: String? = nil) {
        let apiImages = images?.compactMap { $0.toAPIImageAttachment() }
        self.init(type: .input, text: text, images: apiImages, messageId: messageId, thinkingMode: thinkingMode)
    }
}

/// Extension to convert app's ImageAttachment to generated APIImageAttachment
extension ImageAttachment {
    /// Convert to APIImageAttachment for sending over the wire
    func toAPIImageAttachment() -> APIImageAttachment? {
        switch uploadState {
        case .uploaded(let refId):
            return APIImageAttachment(type: .reference, id: refId, mimeType: mimeType)
        case .inline:
            let base64 = dataForSending.base64EncodedString()
            return APIImageAttachment(type: .base64, data: base64, mimeType: mimeType)
        default:
            // Image not ready to send
            return nil
        }
    }
}

/// Convenience initializers for PermissionResponseMessage (doesn't require `type` parameter)
extension PermissionResponseMessage {
    public init(id: String, choice: Choice) {
        self.init(type: .permissionResponse, id: id, choice: choice)
    }
}

/// Convenience initializers for QuestionResponseMessage
extension QuestionResponseMessage {
    public init(id: String, answers: [String: QuestionResponseMessageAnswersValue]) {
        self.init(type: .questionResponse, id: id, answers: answers)
    }
}

/// Extensions for QuestionResponseMessageAnswersValue to hold string or array values
/// The generated type is empty because OpenAPI anyOf types don't map well to Swift
extension QuestionResponseMessageAnswersValue {
    /// Initialize with a string value
    public init(_ value: String) {
        // The generated struct is empty, so we just call the default init
        // The actual value encoding happens in custom encode implementation if needed
    }

    /// Initialize with an integer value
    public init(_ value: Int) {
        // The generated struct is empty
    }

    /// Initialize with an array of strings
    public init(_ values: [String]) {
        // The generated struct is empty
    }

    /// Initialize with any Codable value (for compatibility)
    public init(_ value: AnyCodableValue) {
        // The generated struct is empty
    }
}

/// Convenience initializers for SetModelMessage
extension SetModelMessage {
    public init(model: String) {
        self.init(type: .setModel, model: model)
    }
}

/// Convenience initializers for SetPermissionModeMessage
extension SetPermissionModeMessage {
    public init(mode: Mode) {
        self.init(type: .setPermissionMode, mode: mode)
    }
}

/// Convenience initializers for RetryMessage
extension RetryMessage {
    public init(messageId: String?) {
        self.init(type: .retry, messageId: messageId)
    }
}

/// Convenience initializers for ReconnectMessage
extension ReconnectMessage {
    public init(agentId: String, lastMessageId: String? = nil) {
        self.init(type: .reconnect, agentId: agentId, lastMessageId: lastMessageId)
    }
}

/// Convenience initializers for SubscribeSessionsMessage
extension SubscribeSessionsMessage {
    public init(projectPath: String? = nil) {
        self.init(type: .subscribeSessions, projectPath: projectPath)
    }
}

/// Type alias for permission choice
public typealias CLIPermissionChoice = PermissionResponseMessage.Choice

/// Type alias for permission mode in SetPermissionModeMessage
public typealias CLIPermissionMode = SetPermissionModeMessage.Mode

// ============================================================================
// MARK: - WebSocket Client Messages
// ============================================================================

/// Client → Server message union
public typealias CLIClientMessage = ClientMessage

/// Start a new agent conversation
public typealias CLIStartPayload = StartMessage

/// Send user input to the agent
public typealias CLIInputPayload = InputMessage

/// Respond to a permission request
public typealias CLIPermissionResponsePayload = PermissionResponseMessage

/// Respond to a question from the agent
public typealias CLIQuestionResponsePayload = QuestionResponseMessage

/// Subscribe to session events
public typealias CLISubscribeSessionsPayload = SubscribeSessionsMessage

/// Change the model
public typealias CLISetModelPayload = SetModelMessage

/// Change the permission mode
public typealias CLISetPermissionModePayload = SetPermissionModeMessage

/// Retry the last failed operation
public typealias CLIRetryPayload = RetryMessage

/// Reconnect to an existing session
public typealias CLIReconnectPayload = ReconnectMessage

// ============================================================================
// MARK: - WebSocket Server Messages
// ============================================================================

/// Server → Client message union
public typealias CLIServerMessage = ServerMessage

/// Agent stopped (completed or aborted)
public typealias CLIStoppedPayload = StoppedMessage

/// Connected to WebSocket
public typealias CLIConnectedPayload = ConnectedMessage

/// Model changed confirmation
public typealias CLIModelChangedPayload = ModelChangedMessage

/// Permission mode changed confirmation
public typealias CLIPermissionModeChangedPayload = PermissionModeChangedMessage

/// Pong response to ping
public typealias CLIPongPayload = PongMessage

/// Message queued for processing
public typealias CLIQueuedPayload = QueuedMessage

/// Cursor evicted (another session took over)
public typealias CLICursorEvictedPayload = CursorEvictedMessage

/// Cursor invalid (session expired)
public typealias CLICursorInvalidPayload = CursorInvalidMessage

/// Reconnection completed
public typealias CLIReconnectCompletePayload = ReconnectCompleteMessage

/// History replay message
public typealias CLIHistoryPayload = HistoryMessage

/// Error message from server
public typealias CLIErrorPayload = WsErrorMessage

// ============================================================================
// MARK: - Stream Messages (Real-time Content)
// ============================================================================

/// Stream message wrapper from server
public typealias CLIStreamMessage = StreamServerMessage

// Note: CLIStreamContent is a CUSTOM enum defined below (not a typealias)
// because the generated StreamMessage is missing thinking/question/permission cases.
// Once cli-bridge updates the OpenAPI spec to include these, we can switch to a typealias.

/// Assistant text content
public typealias CLIAssistantContent = AssistantStreamMessage

/// User text content
public typealias CLIUserContent = UserStreamMessage

/// System message content
public typealias CLISystemContent = SystemStreamMessage

/// Thinking block (extended thinking)
public typealias CLIThinkingContent = ThinkingBlock

/// Tool invocation
public typealias CLIToolUseContent = ToolUseStreamMessage

/// Tool execution result
public typealias CLIToolResultContent = ToolResultStreamMessage

/// Progress update (task/subagent)
public typealias CLIProgressContent = ProgressStreamMessage

/// Token usage information
public typealias CLIUsageContent = UsageStreamMessage

/// Agent state change
public typealias CLIStateContent = StateStreamMessage

/// Subagent started
public typealias CLISubagentStartContent = SubagentStartStreamMessage

/// Subagent completed
public typealias CLISubagentCompleteContent = SubagentCompleteStreamMessage

/// Convenience initializer for SubagentStartStreamMessage (without type parameter)
extension SubagentStartStreamMessage {
    public init(id: String, description: String) {
        self.init(type: .subagentStart, id: id, description: description)
    }

    /// Display name for the agent type (derived from id)
    /// ID format is typically "type:name" (e.g., "Task:code-reviewer")
    public var displayAgentType: String {
        // Try to extract agent type from id
        if let colonIndex = id.firstIndex(of: ":") {
            let prefix = String(id[..<colonIndex])
            return prefix
        }
        // Fallback to "Task" if no colon separator
        return "Task"
    }
}

/// Convenience initializer for SubagentCompleteStreamMessage (without type parameter)
extension SubagentCompleteStreamMessage {
    public init(id: String, summary: String? = nil) {
        self.init(type: .subagentComplete, id: id, summary: summary)
    }

    /// Display summary with fallback
    public var displaySummary: String {
        summary ?? "Task completed"
    }
}

/// Convenience initializer for ProgressStreamMessage (without type/id parameters)
extension ProgressStreamMessage {
    public init(tool: String, elapsed: Double, progress: Double? = nil, detail: String? = nil) {
        self.init(type: .progress, id: "", tool: tool, elapsed: elapsed, progress: progress, detail: detail)
    }

    /// Elapsed time in seconds (alias for compatibility)
    public var elapsedSeconds: Int {
        Int(elapsed)
    }

    /// Progress as integer percentage (for display)
    public var progressPercent: Int? {
        guard let p = progress else { return nil }
        return Int(p)
    }
}

// Note: CLIAgentState is defined as an enum above (line ~150) with app-local states
// (starting, stopped, networkUnavailable). Don't alias to StateStreamMessage.State.

// ============================================================================
// MARK: - Permission and Question Types
// ============================================================================

/// Permission request from agent
public typealias CLIPermissionRequest = PermissionRequestMessage

/// Extension to add description property for backward compatibility
extension PermissionRequestMessage {
    /// Generate description from tool and input parameters
    public var description: String {
        // Try to get a meaningful description from input
        if let command = input["command"]?.stringValue {
            return "\(tool): \(command)"
        }
        if let path = input["path"]?.stringValue {
            return "\(tool): \(path)"
        }
        // Fallback to just tool name
        return tool
    }
}

/// Question request from agent
public typealias CLIQuestionRequest = QuestionMessage

/// Question item in a question request
public typealias CLIQuestionItem = QuestionItem

/// Option for a question
public typealias CLIQuestionOption = APIQuestionOption

// ============================================================================
// MARK: - Session Types
// ============================================================================

/// Session event (created, updated, etc.)
public typealias CLISessionEvent = SessionEventMessage

/// Session metadata
public typealias CLISessionMetadata = SessionMetadata

/// Session search match
public typealias CLISessionSearchMatch = ProjectsEncodedPathSessionsSearchGet200ResponseAllOfResultsInnerAllOfSnippetsInner

/// Session search result
public typealias CLISessionSearchResult = ProjectsEncodedPathSessionsSearchGet200ResponseAllOfResultsInner

/// Session search response
public typealias CLISessionSearchResponse = ProjectsEncodedPathSessionsSearchGet200Response

/// Identifiable conformance for search results
extension ProjectsEncodedPathSessionsSearchGet200ResponseAllOfResultsInner: Identifiable {
    public var id: String { sessionId }
}

/// Compatibility struct for search matches
struct SearchMatchCompat: Identifiable {
    let messageId: String
    let role: String
    let snippet: String

    var id: String { messageId }
}

/// Convenience extension for search results
extension ProjectsEncodedPathSessionsSearchGet200ResponseAllOfResultsInner {
    /// Convert snippets to match format expected by UI
    var matches: [SearchMatchCompat] {
        snippets.enumerated().map { idx, snippet in
            SearchMatchCompat(
                messageId: "\(sessionId)-\(idx)",
                role: snippet.type,
                snippet: snippet.text
            )
        }
    }
}

// ============================================================================
// MARK: - Search Types
// ============================================================================

/// Search snippet (matching text in context)
public typealias CLISearchSnippet = SearchSnippet

/// Search result (session with matches)
public typealias CLISearchResult = SearchResult

/// Search response (all results)
public typealias CLISearchResponse = SearchResponse

/// Search error response - custom struct for backward compatibility
/// Uses String error field instead of SearchErrorCode enum
public struct CLISearchError: Codable, Equatable {
    public let error: String
    public let message: String

    public init(error: String, message: String) {
        self.error = error
        self.message = message
    }
}

/// Identifiable conformance for SearchResult (ForEach support)
extension SearchResult: Identifiable {
    public var id: String { sessionId.uuidString }
}

/// Convenience extension for SearchResult
extension SearchResult {
    /// Convenience initializer that accepts String sessionId (for tests)
    public init(sessionId: String, projectPath: String, snippets: [SearchSnippet], score: Double, timestamp: String) {
        self.init(
            sessionId: UUID(uuidString: sessionId) ?? UUID(),
            projectPath: projectPath,
            snippets: snippets,
            score: score,
            timestamp: timestamp
        )
    }

    /// Parsed date from timestamp (returns nil for invalid timestamps)
    var date: Date? {
        CLIDateFormatter.parseDate(timestamp)
    }

    /// Formatted date string (falls back to raw timestamp if parsing fails)
    var formattedDate: String {
        guard let parsedDate = date else {
            return timestamp
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        return dateFormatter.string(from: parsedDate)
    }

    /// Project name extracted from path (handles trailing slashes)
    var projectName: String {
        var path = projectPath
        // Remove trailing slash if present
        while path.hasSuffix("/") && path.count > 1 {
            path.removeLast()
        }
        return (path as NSString).lastPathComponent
    }

    /// Combined snippet text for copying to pasteboard
    var snippet: String {
        snippets.first?.text ?? ""
    }
}

/// Identifiable conformance for SearchSnippet (ForEach support)
extension SearchSnippet: Identifiable {
    public var id: String { "\(text.hashValue)-\(matchStart)-\(matchLength)" }
}

/// Convenience extension for SearchSnippet
extension SearchSnippet {
    /// SF Symbol for message type
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

    /// Extract matched text from the full text using matchStart and matchLength
    var matchedText: String {
        let start = text.index(text.startIndex, offsetBy: min(matchStart, text.count))
        let end = text.index(start, offsetBy: min(matchLength, text.count - matchStart))
        return String(text[start..<end])
    }

    /// Text before the matched portion
    var beforeMatch: String {
        let start = text.index(text.startIndex, offsetBy: min(matchStart, text.count))
        return String(text[..<start])
    }

    /// Text after the matched portion
    var afterMatch: String {
        let matchEnd = min(matchStart + matchLength, text.count)
        let end = text.index(text.startIndex, offsetBy: matchEnd)
        return String(text[end...])
    }
}

// ============================================================================
// MARK: - Push Notification Types
// ============================================================================

/// Register FCM token request
public typealias CLIPushRegisterRequest = RegisterFcmRequest

/// Register FCM token response
public typealias CLIPushRegisterResponse = RegisterFcmResponse

/// Register Live Activity request
public typealias CLILiveActivityRegisterRequest = RegisterLiveActivityRequest

/// Register Live Activity response
public typealias CLILiveActivityRegisterResponse = RegisterLiveActivityResponse

/// Invalidate push token request
public typealias CLIPushInvalidateRequest = InvalidateTokenRequest

/// Push status response
public typealias CLIPushStatusResponse = PushStatusResponse

// ============================================================================
// MARK: - File/Directory Types
// ============================================================================

/// File entry (file or directory)
public typealias CLIFileEntry = APIFileEntry

/// Convenience extensions for APIFileEntry
extension APIFileEntry: Identifiable {
    public var id: String { name }

    /// Whether this entry is a directory
    public var isDir: Bool {
        type == .directory
    }

    /// Whether this entry is a symlink
    public var isSymlink: Bool {
        type == .symlink
    }

    /// Path for navigation (combines current directory with name)
    public var path: String {
        name
    }

    /// SF Symbol icon for file type
    public var icon: String {
        if isSymlink {
            return "link"
        } else if isDir {
            return "folder.fill"
        }

        // Get file extension
        let ext = (name as NSString).pathExtension.lowercased()

        switch ext {
        case "swift": return "swift"
        case "ts", "tsx": return "t.square"
        case "js", "jsx", "mjs": return "j.square"
        case "json": return "curlybraces"
        case "md", "markdown": return "doc.text"
        case "txt", "text": return "doc.plaintext"
        case "py": return "p.circle"
        case "rb": return "r.circle"
        case "go": return "g.circle"
        case "rs": return "r.square"
        case "java", "kt", "kts": return "j.circle"
        case "c", "cpp", "cxx", "h", "hpp": return "c.circle"
        case "html", "htm": return "globe"
        case "css", "scss", "sass": return "paintbrush"
        case "xml": return "chevron.left.forwardslash.chevron.right"
        case "yaml", "yml": return "list.bullet"
        case "sh", "bash", "zsh": return "terminal"
        case "png", "jpg", "jpeg", "gif", "webp", "svg": return "photo"
        case "mp3", "wav", "aac", "m4a": return "music.note"
        case "mp4", "mov", "avi", "mkv": return "video"
        case "pdf": return "doc.fill"
        case "zip", "tar", "gz", "rar", "7z": return "archivebox"
        default: return "doc"
        }
    }

    /// Child count for directories (not provided by API)
    public var childCount: Int? {
        // API doesn't provide child count - would need a separate request
        return nil
    }

    /// Formatted file size
    public var formattedSize: String? {
        guard let bytes = size else { return nil }
        let doubleBytes = Double(bytes)
        if doubleBytes < 1024 {
            return "\(bytes) B"
        } else if doubleBytes < 1024 * 1024 {
            return String(format: "%.1f KB", doubleBytes / 1024)
        } else if doubleBytes < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", doubleBytes / (1024 * 1024))
        } else {
            return String(format: "%.1f GB", doubleBytes / (1024 * 1024 * 1024))
        }
    }

    /// Modified date parsed from ISO8601 string
    public var modifiedDate: Date? {
        CLIDateFormatter.parseDate(modified)
    }
}

/// File list response
public typealias CLIFileListResponse = DirectoryListing

/// Convenience extensions for DirectoryListing
extension DirectoryListing {
    /// Parent directory path (derived from path)
    public var parent: String? {
        let nsPath = path as NSString
        guard nsPath.length > 1 else { return nil }
        let parentPath = nsPath.deletingLastPathComponent
        return parentPath.isEmpty ? "/" : parentPath
    }
}

/// File content response
public typealias CLIFileContentResponse = FileContent

/// Convenience extensions for FileContent
extension FileContent {
    /// Extract filename from path
    public var fileName: String {
        (path as NSString).lastPathComponent
    }

    /// Infer language from file extension for syntax highlighting
    public var language: String? {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "ts", "tsx": return "typescript"
        case "js", "jsx", "mjs": return "javascript"
        case "py": return "python"
        case "rb": return "ruby"
        case "go": return "go"
        case "rs": return "rust"
        case "java": return "java"
        case "kt", "kts": return "kotlin"
        case "c", "h": return "c"
        case "cpp", "cxx", "cc", "hpp": return "cpp"
        case "cs": return "csharp"
        case "php": return "php"
        case "html", "htm": return "html"
        case "css", "scss", "sass": return "css"
        case "json": return "json"
        case "yaml", "yml": return "yaml"
        case "xml": return "xml"
        case "md", "markdown": return "markdown"
        case "sh", "bash", "zsh": return "bash"
        case "sql": return "sql"
        default: return nil
        }
    }

    /// Formatted file size (e.g., "1.2 KB", "3.5 MB")
    public var formattedSize: String? {
        let bytes = Double(size)
        if bytes < 1024 {
            return "\(size) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", bytes / 1024)
        } else if bytes < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", bytes / (1024 * 1024))
        } else {
            return String(format: "%.1f GB", bytes / (1024 * 1024 * 1024))
        }
    }

    /// Line count for text files
    public var lineCount: Int? {
        content.components(separatedBy: .newlines).count
    }
}

// ============================================================================
// MARK: - Project Types
// ============================================================================

/// Project from API (uses prefix to avoid conflict with app's Project)
public typealias CLIProject = APIProject

/// Git status from API
public typealias CLIGitStatus = APIGitStatus

/// Add compatibility properties to APIGitStatus
extension APIGitStatus {
    /// Remote URL (not provided by API, return nil)
    public var remoteUrl: String? {
        // The API doesn't provide remote URL, derive from tracking branch if available
        guard let tracking = trackingBranch else { return nil }
        // Format: "origin/main" -> just return nil since we don't have the actual URL
        return nil
    }
}

/// Convert APIGitStatus to app's GitStatus enum
extension APIGitStatus {
    var toGitStatus: GitStatus {
        let isDirty = !isClean || (uncommittedCount ?? 0) > 0
        let aheadCount = ahead ?? 0
        let behindCount = behind ?? 0

        // Check for diverged state (both ahead and behind)
        if aheadCount > 0 && behindCount > 0 {
            return .diverged
        }

        // Check for dirty with ahead commits
        if isDirty && aheadCount > 0 {
            return .dirtyAndAhead
        }

        // Check for just dirty
        if isDirty {
            return .dirty
        }

        // Check for ahead
        if aheadCount > 0 {
            return .ahead(aheadCount)
        }

        // Check for behind
        if behindCount > 0 {
            return .behind(behindCount)
        }

        // Clean
        return .clean
    }
}

// ============================================================================
// MARK: - Pagination Types
// ============================================================================

/// Paginated messages response
public typealias CLIPaginatedMessagesResponse = GetMessagesResponse

/// Pagination info
public typealias CLIPaginationInfo = GetMessagesResponsePagination

/// Pagination error
public typealias CLIPaginationError = PaginationError

/// Convenience extension for GetMessagesResponse
extension GetMessagesResponse {
    /// Total count of messages
    var total: Int { pagination.total }

    /// Whether more messages are available
    var hasMore: Bool { pagination.hasMore }

    /// Convert paginated messages to ChatMessages
    func toChatMessages() -> [ChatMessage] {
        messages.compactMap { paginatedMessage in
            paginatedMessage.toChatMessage()
        }
    }
}

/// Convenience extension for PaginatedMessage
extension PaginatedMessage {
    /// Convert to ChatMessage
    func toChatMessage() -> ChatMessage? {
        // Extract type from message dict
        guard let typeValue = message["type"],
              case .string(let typeStr) = typeValue else {
            return nil
        }

        // Determine role from message type
        let role: ChatMessage.Role
        switch typeStr {
        case "user":
            role = .user
        case "assistant":
            role = .assistant
        case "system", "result":
            role = .system
        default:
            role = .assistant
        }

        // Extract content from message - could be string or from content array
        var content = ""
        if let contentValue = message["content"] {
            switch contentValue {
            case .string(let str):
                content = str
            case .array(let arr):
                // Handle content blocks
                content = arr.compactMap { block -> String? in
                    guard case .dictionary(let dict) = block,
                          let textValue = dict["text"],
                          case .string(let text) = textValue else {
                        return nil
                    }
                    return text
                }.joined(separator: "\n")
            default:
                break
            }
        }

        // Parse timestamp
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = dateFormatter.date(from: timestamp) ?? Date()

        return ChatMessage(
            id: UUID(),
            role: role,
            content: content,
            timestamp: date
        )
    }
}

/// Convenience extension for HistoryMessage
extension HistoryMessage {
    /// Convert stream messages to ChatMessages
    func toChatMessages() -> [ChatMessage] {
        messages.compactMap { streamMessage in
            streamMessage.toChatMessage()
        }
    }
}

/// Convenience extension for StreamMessage
extension StreamMessage {
    /// Convert to ChatMessage
    func toChatMessage() -> ChatMessage? {
        // Determine role and content based on message type
        let role: ChatMessage.Role
        var content = ""

        switch self {
        case .typeUserStreamMessage(let user):
            role = .user
            content = user.content
        case .typeAssistantStreamMessage(let assistant):
            role = .assistant
            content = assistant.content
        case .typeSystemStreamMessage(let system):
            role = .system
            content = system.content
        case .typeToolUseStreamMessage(let toolUse):
            role = .toolUse
            content = "Using \(toolUse.name)"
        case .typeToolResultStreamMessage(let toolResult):
            role = .toolResult
            content = toolResult.output
        default:
            return nil
        }

        return ChatMessage(
            id: UUID(),
            role: role,
            content: content,
            timestamp: Date()
        )
    }
}

// ============================================================================
// MARK: - Bulk Operations
// ============================================================================

/// Bulk operation request
public typealias CLIBulkOperationRequest = BulkOperationRequest

/// Bulk operation response
public typealias CLIBulkOperationResponse = BulkOperationResult

/// Bulk operation failure details
public typealias CLIBulkOperationFailure = BulkOperationResultFailedInner

/// Convenience extension for BulkOperationResult
extension BulkOperationResult {
    /// Count of successful operations
    public var successCount: Int { success.count }
    /// Count of failed operations
    public var failedCount: Int { failed.count }
}

// ============================================================================
// MARK: - Other Types
// ============================================================================

/// Integrity info (session hashes, counts)
public typealias CLIIntegrity = IntegrityInfo

/// Stored message (persisted chat message)
// Note: StoredMessage is already the generated type name, no alias needed

// ============================================================================
// MARK: - REST API Response Types
// ============================================================================
// NOTE: Many of these types are defined in CLIBridgeAPIClient.swift with different
// structures than the generated types. We keep the hand-written versions to avoid
// breaking changes. The generated types can be accessed directly when needed.

/// Session count result
public typealias CLISessionCountResponse = SessionCountResult

/// Connection state (for backward compatibility)
typealias ConnectionState = CLIConnectionState

// ============================================================================
// MARK: - Missing Types from CLIBridgeTypes.swift
// ============================================================================
// These types were not in the OpenAPI spec or have different structures.
// Keeping them as hand-written types for compatibility.

/// Project detail (not in OpenAPI spec)
public struct CLIProjectDetail: Codable, Equatable {
    public let path: String
    public let name: String?
    public let git: APIGitStatus?
    public let sessionCount: Int?
    public let lastUsed: String?
    public let structure: CLIProjectStructure?
    public let readme: String?

    public init(path: String, name: String? = nil, git: APIGitStatus? = nil, sessionCount: Int? = nil, lastUsed: String? = nil, structure: CLIProjectStructure? = nil, readme: String? = nil) {
        self.path = path
        self.name = name
        self.git = git
        self.sessionCount = sessionCount
        self.lastUsed = lastUsed
        self.structure = structure
        self.readme = readme
    }
}

/// Project type badge for UI display
public struct CLIProjectTypeBadge: Codable, Equatable {
    public let label: String
    public let icon: String
    public let color: String

    public init(label: String, icon: String, color: String) {
        self.label = label
        self.icon = icon
        self.color = color
    }
}

/// Project structure (not in OpenAPI spec)
public struct CLIProjectStructure: Codable, Equatable {
    public let hasCLAUDE: Bool
    public let hasPackageJSON: Bool
    public let hasPyprojectToml: Bool
    public let directories: [String]?
    public let primaryLanguage: String?

    public init(hasCLAUDE: Bool = false, hasPackageJSON: Bool = false, hasPyprojectToml: Bool = false, directories: [String]? = nil, primaryLanguage: String? = nil) {
        self.hasCLAUDE = hasCLAUDE
        self.hasPackageJSON = hasPackageJSON
        self.hasPyprojectToml = hasPyprojectToml
        self.directories = directories
        self.primaryLanguage = primaryLanguage
    }

    /// Generate type badges based on project structure
    public var projectTypeBadges: [CLIProjectTypeBadge] {
        var badges: [CLIProjectTypeBadge] = []

        if hasPackageJSON {
            badges.append(CLIProjectTypeBadge(label: "Node.js", icon: "cube.box", color: "green"))
        }
        if hasPyprojectToml {
            badges.append(CLIProjectTypeBadge(label: "Python", icon: "p.circle", color: "yellow"))
        }
        if hasCLAUDE {
            badges.append(CLIProjectTypeBadge(label: "Claude", icon: "brain", color: "orange"))
        }

        return badges
    }
}

/// Export format enum (not in OpenAPI spec)
public enum CLIExportFormat: String, Codable {
    case json
    case markdown
    case text
}

/// Export response (not in OpenAPI spec)
public struct CLIExportResponse: Codable, Equatable {
    public let sessionId: String
    public let format: CLIExportFormat
    public let content: String

    public init(sessionId: String, format: CLIExportFormat, content: String) {
        self.sessionId = sessionId
        self.format = format
        self.content = content
    }
}

// SessionSource extension to add backward-compatible typealias
// Generated SessionMetadata has nested enum `Source`, but code expects `SessionSource`
extension SessionMetadata {
    public typealias SessionSource = Source

    /// Convert to ProjectSession for UI display
    func toProjectSession() -> ProjectSession {
        let dateFormatter = ISO8601DateFormatter()
        return ProjectSession(
            id: id.uuidString,
            projectPath: projectPath,
            summary: customTitle ?? title,
            lastActivity: dateFormatter.string(from: lastActivityAt),
            messageCount: messageCount,
            lastUserMessage: lastUserMessage,
            lastAssistantMessage: lastAssistantMessage,
            archivedAt: archivedAt.map { dateFormatter.string(from: $0) }
        )
    }
}

extension Array where Element == SessionMetadata {
    /// Convert array of SessionMetadata to ProjectSession array
    func toProjectSessions() -> [ProjectSession] {
        map { $0.toProjectSession() }
    }
}

// TokenType is generated in Generated/TokenType.swift - no custom definition needed

/// Paginated messages request (query parameters helper)
public struct CLIPaginatedMessagesRequest {
    public let limit: Int?
    public let offset: Int?
    public let before: String?
    public let after: String?
    public let types: String?
    public let order: String?
    public let includeRawContent: Bool?

    public init(
        limit: Int? = nil,
        offset: Int? = nil,
        before: String? = nil,
        after: String? = nil,
        types: String? = nil,
        order: String? = nil,
        includeRawContent: Bool? = nil
    ) {
        self.limit = limit
        self.offset = offset
        self.before = before
        self.after = after
        self.types = types
        self.order = order
        self.includeRawContent = includeRawContent
    }

    /// Convert to URLQueryItems for API requests
    public var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let limit = limit {
            items.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let offset = offset {
            items.append(URLQueryItem(name: "offset", value: String(offset)))
        }
        if let before = before {
            items.append(URLQueryItem(name: "before", value: before))
        }
        if let after = after {
            items.append(URLQueryItem(name: "after", value: after))
        }
        if let types = types {
            items.append(URLQueryItem(name: "types", value: types))
        }
        if let order = order {
            items.append(URLQueryItem(name: "order", value: order))
        }
        if let includeRawContent = includeRawContent {
            items.append(URLQueryItem(name: "includeRawContent", value: includeRawContent ? "true" : "false"))
        }
        return items
    }
}

// ============================================================================
// MARK: - CLIStreamContent (Custom Enum)
// ============================================================================
// Now matches the generated StreamMessage which includes all stream types.

/// Stream content union - mirrors generated StreamMessage
public enum CLIStreamContent: Sendable, Codable, Hashable {
    // All cases from generated StreamMessage
    case typeAssistantStreamMessage(AssistantStreamMessage)
    case typeUserStreamMessage(UserStreamMessage)
    case typeSystemStreamMessage(SystemStreamMessage)
    case typeToolUseStreamMessage(ToolUseStreamMessage)
    case typeToolResultStreamMessage(ToolResultStreamMessage)
    case typeProgressStreamMessage(ProgressStreamMessage)
    case typeUsageStreamMessage(UsageStreamMessage)
    case typeStateStreamMessage(StateStreamMessage)
    case typeSubagentStartStreamMessage(SubagentStartStreamMessage)
    case typeSubagentCompleteStreamMessage(SubagentCompleteStreamMessage)
    case typeThinkingStreamMessage(ThinkingStreamMessage)
    case typeQuestionMessage(QuestionMessage)
    case typePermissionRequestMessage(PermissionRequestMessage)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // Try each type in order - most common first for performance
        if let value = try? container.decode(AssistantStreamMessage.self) {
            self = .typeAssistantStreamMessage(value)
        } else if let value = try? container.decode(ToolUseStreamMessage.self) {
            self = .typeToolUseStreamMessage(value)
        } else if let value = try? container.decode(ToolResultStreamMessage.self) {
            self = .typeToolResultStreamMessage(value)
        } else if let value = try? container.decode(UserStreamMessage.self) {
            self = .typeUserStreamMessage(value)
        } else if let value = try? container.decode(SystemStreamMessage.self) {
            self = .typeSystemStreamMessage(value)
        } else if let value = try? container.decode(ThinkingStreamMessage.self) {
            self = .typeThinkingStreamMessage(value)
        } else if let value = try? container.decode(StateStreamMessage.self) {
            self = .typeStateStreamMessage(value)
        } else if let value = try? container.decode(ProgressStreamMessage.self) {
            self = .typeProgressStreamMessage(value)
        } else if let value = try? container.decode(UsageStreamMessage.self) {
            self = .typeUsageStreamMessage(value)
        } else if let value = try? container.decode(SubagentStartStreamMessage.self) {
            self = .typeSubagentStartStreamMessage(value)
        } else if let value = try? container.decode(SubagentCompleteStreamMessage.self) {
            self = .typeSubagentCompleteStreamMessage(value)
        } else if let value = try? container.decode(QuestionMessage.self) {
            self = .typeQuestionMessage(value)
        } else if let value = try? container.decode(PermissionRequestMessage.self) {
            self = .typePermissionRequestMessage(value)
        } else {
            throw DecodingError.typeMismatch(
                CLIStreamContent.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Unable to decode CLIStreamContent")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .typeAssistantStreamMessage(let value):
            try container.encode(value)
        case .typeUserStreamMessage(let value):
            try container.encode(value)
        case .typeSystemStreamMessage(let value):
            try container.encode(value)
        case .typeToolUseStreamMessage(let value):
            try container.encode(value)
        case .typeToolResultStreamMessage(let value):
            try container.encode(value)
        case .typeProgressStreamMessage(let value):
            try container.encode(value)
        case .typeUsageStreamMessage(let value):
            try container.encode(value)
        case .typeStateStreamMessage(let value):
            try container.encode(value)
        case .typeSubagentStartStreamMessage(let value):
            try container.encode(value)
        case .typeSubagentCompleteStreamMessage(let value):
            try container.encode(value)
        case .typeThinkingStreamMessage(let value):
            try container.encode(value)
        case .typeQuestionMessage(let value):
            try container.encode(value)
        case .typePermissionRequestMessage(let value):
            try container.encode(value)
        }
    }

    /// Get the message type as string
    public var messageType: String {
        switch self {
        case .typeAssistantStreamMessage: return "assistant"
        case .typeUserStreamMessage: return "user"
        case .typeSystemStreamMessage: return "system"
        case .typeToolUseStreamMessage: return "tool_use"
        case .typeToolResultStreamMessage: return "tool_result"
        case .typeUsageStreamMessage: return "usage"
        case .typeStateStreamMessage: return "state"
        case .typeProgressStreamMessage: return "progress"
        case .typeSubagentStartStreamMessage: return "subagent_start"
        case .typeSubagentCompleteStreamMessage: return "subagent_complete"
        case .typeThinkingStreamMessage: return "thinking"
        case .typeQuestionMessage: return "question"
        case .typePermissionRequestMessage: return "permission"
        }
    }
}

// ============================================================================
// MARK: - CLIStoredMessage (Custom Struct)
// ============================================================================
// Custom StoredMessage that uses CLIStreamContent instead of StreamMessage

/// Stored message using CLIStreamContent for full compatibility
public struct CLIStoredMessage: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let message: CLIStreamContent
    public let rawContent: [ContentBlock]?

    public init(id: UUID, timestamp: Date, message: CLIStreamContent, rawContent: [ContentBlock]? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.message = message
        self.rawContent = rawContent
    }

    /// String ID for compatibility
    public var idString: String { id.uuidString }
}

// ============================================================================
// MARK: - StreamMessage to CLIStreamContent Conversion
// ============================================================================

extension StreamMessage {
    /// Convert generated StreamMessage to CLIStreamContent
    public func toCLIStreamContent() -> CLIStreamContent {
        switch self {
        case .typeAssistantStreamMessage(let value):
            return .typeAssistantStreamMessage(value)
        case .typeUserStreamMessage(let value):
            return .typeUserStreamMessage(value)
        case .typeSystemStreamMessage(let value):
            return .typeSystemStreamMessage(value)
        case .typeToolUseStreamMessage(let value):
            return .typeToolUseStreamMessage(value)
        case .typeToolResultStreamMessage(let value):
            return .typeToolResultStreamMessage(value)
        case .typeProgressStreamMessage(let value):
            return .typeProgressStreamMessage(value)
        case .typeUsageStreamMessage(let value):
            return .typeUsageStreamMessage(value)
        case .typeStateStreamMessage(let value):
            return .typeStateStreamMessage(value)
        case .typeSubagentStartStreamMessage(let value):
            return .typeSubagentStartStreamMessage(value)
        case .typeSubagentCompleteStreamMessage(let value):
            return .typeSubagentCompleteStreamMessage(value)
        case .typePermissionRequestMessage(let value):
            return .typePermissionRequestMessage(value)
        case .typeQuestionMessage(let value):
            return .typeQuestionMessage(value)
        case .typeThinkingStreamMessage(let value):
            return .typeThinkingStreamMessage(value)
        }
    }
}

// ============================================================================
// MARK: - StreamServerMessage Extension
// ============================================================================

/// Extension to convert StreamServerMessage to CLIStoredMessage for processing
extension StreamServerMessage {
    /// Convert to CLIStoredMessage format for unified message handling
    public func toStoredMessage() -> CLIStoredMessage {
        CLIStoredMessage(id: id, timestamp: timestamp, message: message.toCLIStreamContent())
    }
}

/// Extension to convert generated StoredMessage to CLIStoredMessage
extension StoredMessage {
    /// Convert to CLIStoredMessage format for unified message handling
    public func toCLIStoredMessage() -> CLIStoredMessage {
        CLIStoredMessage(id: id, timestamp: timestamp, message: message.toCLIStreamContent(), rawContent: rawContent)
    }
}

// ============================================================================
// MARK: - ServerMessage Convenience Constructors
// ============================================================================

/// Extension for ServerMessage with convenience constructors (short case names)
extension ServerMessage {
    /// Create a connected message (short name for .typeConnectedMessage)
    public static func connected(_ payload: ConnectedMessage) -> ServerMessage {
        .typeConnectedMessage(payload)
    }

    /// Create an error message from WsErrorMessage (short name for .typeErrorMessage)
    public static func error(_ payload: WsErrorMessage) -> ServerMessage {
        // Convert WsErrorMessage to ErrorMessage (they have identical structure)
        .typeErrorMessage(ErrorMessage(
            type: .error,
            code: payload.code,
            message: payload.message,
            recoverable: payload.recoverable,
            retryable: payload.retryable,
            retryAfter: payload.retryAfter
        ))
    }

    /// Create an error message from ErrorMessage (short name for .typeErrorMessage)
    public static func error(_ payload: ErrorMessage) -> ServerMessage {
        .typeErrorMessage(payload)
    }

    /// Create a stopped message (short name for .typeStoppedMessage)
    public static func stopped(_ payload: StoppedMessage) -> ServerMessage {
        .typeStoppedMessage(payload)
    }

    /// Create a history message (short name for .typeHistoryMessage)
    public static func history(_ payload: HistoryMessage) -> ServerMessage {
        .typeHistoryMessage(payload)
    }

    /// Create a model changed message (short name for .typeModelChangedMessage)
    public static func modelChanged(_ payload: ModelChangedMessage) -> ServerMessage {
        .typeModelChangedMessage(payload)
    }

    /// Create a session event message (short name for .typeSessionEventMessage)
    public static func sessionEvent(_ payload: SessionEventMessage) -> ServerMessage {
        .typeSessionEventMessage(payload)
    }

    /// Create an interrupted message (short name for .typeInterruptedMessage)
    public static var interrupted: ServerMessage {
        .typeInterruptedMessage(InterruptedMessage(type: .interrupted))
    }
}

// ============================================================================
// MARK: - ServerMessage Convenience Accessors
// ============================================================================

/// Extension for ServerMessage with convenience accessors for migration
extension ServerMessage {
    /// Extract connected payload if this is a connected message
    public var connected: ConnectedMessage? {
        if case .typeConnectedMessage(let msg) = self { return msg }
        return nil
    }

    /// Extract stream message if this is a stream message
    public var stream: StreamServerMessage? {
        if case .typeStreamServerMessage(let msg) = self { return msg }
        return nil
    }

    /// Extract permission request if this is a permission request
    public var permissionRequest: PermissionRequestMessage? {
        if case .typePermissionRequestMessage(let msg) = self { return msg }
        return nil
    }

    /// Extract question message if this is a question
    public var question: QuestionMessage? {
        if case .typeQuestionMessage(let msg) = self { return msg }
        return nil
    }

    /// Extract session event if this is a session event
    public var sessionEvent: SessionEventMessage? {
        if case .typeSessionEventMessage(let msg) = self { return msg }
        return nil
    }

    /// Extract history payload if this is a history message
    public var history: HistoryMessage? {
        if case .typeHistoryMessage(let msg) = self { return msg }
        return nil
    }

    /// Extract model changed payload if this is a model changed message
    public var modelChanged: ModelChangedMessage? {
        if case .typeModelChangedMessage(let msg) = self { return msg }
        return nil
    }

    /// Extract permission mode changed payload
    public var permissionModeChanged: PermissionModeChangedMessage? {
        if case .typePermissionModeChangedMessage(let msg) = self { return msg }
        return nil
    }

    /// Extract queued payload if this is a queued message
    public var queued: QueuedMessage? {
        if case .typeQueuedMessage(let msg) = self { return msg }
        return nil
    }

    /// Check if this is a queue cleared message
    public var isQueueCleared: Bool {
        if case .typeQueueClearedMessage = self { return true }
        return false
    }

    /// Extract error payload if this is an error message
    public var error: ErrorMessage? {
        if case .typeErrorMessage(let msg) = self { return msg }
        return nil
    }

    /// Check if this is a pong message
    public var isPong: Bool {
        if case .typePongMessage = self { return true }
        return false
    }

    /// Extract stopped payload if this is a stopped message
    public var stopped: StoppedMessage? {
        if case .typeStoppedMessage(let msg) = self { return msg }
        return nil
    }

    /// Check if this is an interrupted message
    public var isInterrupted: Bool {
        if case .typeInterruptedMessage = self { return true }
        return false
    }

    /// Extract cursor evicted payload
    public var cursorEvicted: CursorEvictedMessage? {
        if case .typeCursorEvictedMessage(let msg) = self { return msg }
        return nil
    }

    /// Extract cursor invalid payload
    public var cursorInvalid: CursorInvalidMessage? {
        if case .typeCursorInvalidMessage(let msg) = self { return msg }
        return nil
    }

    /// Extract reconnect complete payload
    public var reconnectComplete: ReconnectCompleteMessage? {
        if case .typeReconnectCompleteMessage(let msg) = self { return msg }
        return nil
    }
}

// ============================================================================
// MARK: - ConnectedMessage Extension
// ============================================================================

/// Extension for ConnectedMessage with compatibility properties and initializers
extension ConnectedMessage {
    /// Convenience initializer that accepts String sessionId and protocolVersion (for tests)
    public init(
        agentId: String,
        sessionId: String,
        model: String,
        version: String,
        protocolVersion: String
    ) {
        self.init(
            type: .connected,
            agentId: agentId,
            sessionId: UUID(uuidString: sessionId) ?? UUID(),
            model: model,
            version: version,
            protocolVersion: ._10
        )
    }

    /// Session ID as String (for compatibility with existing code)
    public var sessionIdString: String {
        sessionId.uuidString
    }

    /// Protocol version as String (for compatibility with existing code)
    public var protocolVersionString: String {
        protocolVersion.rawValue
    }
}

// ============================================================================
// MARK: - HistoryMessage Extension
// ============================================================================

/// Extension for HistoryMessage with convenience methods
extension HistoryMessage {
    /// Convert messages to StoredMessage format for display
    public func toStoredMessages() -> [StoredMessage] {
        // Create a minimal StoredMessage for each StreamMessage
        // Since we don't have full metadata, generate IDs and use current timestamp
        messages.enumerated().map { index, msg in
            StoredMessage(
                id: UUID(),
                timestamp: Date(),
                message: msg
            )
        }
    }
}

// ============================================================================
// MARK: - StoppedMessage Extension
// ============================================================================

/// Extension for StoppedMessage with convenience initializer
extension StoppedMessage {
    /// Convenience initializer that accepts String reason (for tests)
    public init(reason: String) {
        let reasonEnum: Reason = {
            switch reason {
            case "user": return .user
            case "complete", "done": return .complete
            case "error": return .error
            case "timeout": return .timeout
            default: return .complete
            }
        }()
        self.init(type: .stopped, reason: reasonEnum)
    }

    /// Reason as String (for compatibility)
    public var reasonString: String {
        reason.rawValue
    }
}

// ============================================================================
// MARK: - WsErrorMessage Extension
// ============================================================================

/// Extension to make WsErrorMessage compatible with CLIErrorPayload usage
extension WsErrorMessage {
    /// Convenience initializer that doesn't require `type:` parameter (for tests)
    public init(
        code: String,
        message: String,
        recoverable: Bool,
        retryable: Bool? = nil,
        retryAfter: Double? = nil
    ) {
        self.init(
            type: .error,
            code: code,
            message: message,
            recoverable: recoverable,
            retryable: retryable,
            retryAfter: retryAfter
        )
    }

    /// Error message for display
    public var errorMessage: String {
        message
    }

    /// Create from ErrorMessage (identical structure)
    public init(from error: ErrorMessage) {
        self.init(
            type: .error,
            code: error.code,
            message: error.message,
            recoverable: error.recoverable,
            retryable: error.retryable,
            retryAfter: error.retryAfter
        )
    }
}

// ============================================================================
// MARK: - Image Attachment (Compatible with adapter)
// ============================================================================

// Note: ImageAttachment (app type) and APIImageAttachment (generated type) serve different purposes:
// - ImageAttachment: App-level type with upload state tracking, raw Data, UIImage support
// - APIImageAttachment: Wire format for API communication (base64 or reference)
// CLIImageAttachment is now the wire format for sending images via WebSocket.

/// Typealias: CLIImageAttachment → APIImageAttachment (wire format)
public typealias CLIImageAttachment = APIImageAttachment

/// Convenience initializers for APIImageAttachment
extension APIImageAttachment {
    /// Create a reference-type attachment (for uploaded images)
    public init(referenceId: String) {
        self.init(type: .reference, id: referenceId)
    }

    /// Create a base64-type attachment (for inline images)
    public init(base64Data: String, mimeType: String) {
        self.init(type: .base64, data: base64Data, mimeType: mimeType)
    }
}

// MARK: - Stream Content Types (Adapters)

/// Extension for AssistantStreamMessage compatibility
extension AssistantStreamMessage {
    /// Convenience initializer matching old API
    public init(content: String, delta: Bool? = nil) {
        self.init(type: .assistant, content: content, delta: delta)
    }

    /// Whether this is not a streaming delta (convenience from old API)
    public var isFinal: Bool {
        !(delta ?? false)
    }
}

/// Extension for ToolUseStreamMessage to access input values
extension ToolUseStreamMessage {
    /// Get input as dictionary with Any values for compatibility
    public var inputDict: [String: Any] {
        input.mapValues { $0.value }
    }
}

/// Extension for ToolResultStreamMessage compatibility
extension ToolResultStreamMessage {
    /// Tool name for compatibility (maps tool field)
    public var toolName: String { tool }
}

// MARK: - Message Content Adapters

/// Extension for UsageStreamMessage with convenience accessors
extension UsageStreamMessage {
    /// Total tokens used (input + output)
    public var totalTokens: Int {
        inputTokens + outputTokens
    }

    /// Percentage of context window used
    public var contextPercentage: Double {
        guard let used = contextUsed, let limit = contextLimit, limit > 0 else { return 0 }
        return Double(used) / Double(limit) * 100
    }
}

/// Extension for StateStreamMessage with UI helpers
extension StateStreamMessage {
    /// Whether agent is actively working
    public var isWorking: Bool {
        switch state {
        case .thinking, .executing, .recovering:
            return true
        default:
            return false
        }
    }

    /// Whether agent can receive input
    public var canSendInput: Bool {
        switch state {
        case .idle, .thinking, .executing:
            return true
        default:
            return false
        }
    }
}

// MARK: - Permission Types

/// Extension for PermissionRequestMessage compatibility
extension PermissionRequestMessage {
    /// Get a human-readable description of what's being requested
    public var requestDescription: String {
        if let command = input["command"]?.value as? String {
            return "Run command: \(command)"
        }
        if let filePath = input["file_path"]?.value as? String ?? input["filePath"]?.value as? String {
            return "\(tool): \(filePath)"
        }
        return tool
    }

    /// Map options to string array for compatibility
    public var optionStrings: [String] {
        options.map { $0.rawValue }
    }
}

// MARK: - Question Types

/// Extension for QuestionMessage compatibility
extension QuestionMessage {
    /// Convenience: same as questions property
    public var questionItems: [QuestionItem] {
        questions
    }
}

// MARK: - JSONValue Extensions

/// Extension to make JSONValue more ergonomic for CLI Bridge usage
/// Note: stringValue, intValue, boolValue, doubleValue, arrayValue are already in generated JSONValue.swift
extension JSONValue {
    /// Get the underlying value as Any
    public var value: Any {
        switch self {
        case .null:
            return NSNull()
        case .bool(let b):
            return b
        case .int(let i):
            return i
        case .double(let d):
            return d
        case .string(let s):
            return s
        case .array(let arr):
            return arr.map { $0.value }
        case .dictionary(let obj):
            return obj.mapValues { $0.value }
        }
    }

    /// Get value as String, converting other types if needed
    public var stringDescription: String {
        switch self {
        case .null:
            return "null"
        case .bool(let b):
            return String(b)
        case .int(let i):
            return String(i)
        case .double(let d):
            return String(d)
        case .string(let s):
            return s
        case .array, .dictionary:
            if let data = try? JSONEncoder().encode(self),
               let str = String(data: data, encoding: .utf8) {
                return str
            }
            return String(describing: self)
        }
    }

    /// Get value as Dictionary if possible
    public var dictValue: [String: Any]? {
        if case .dictionary(let obj) = self {
            return obj.mapValues { $0.value }
        }
        return nil
    }

    /// Get value as Array of Any if possible (different from generated arrayValue: [JSONValue]?)
    public var anyArrayValue: [Any]? {
        if case .array(let arr) = self {
            return arr.map { $0.value }
        }
        return nil
    }

    /// Create from Any value
    public init(_ value: Any) {
        switch value {
        case is NSNull:
            self = .null
        case let b as Bool:
            self = .bool(b)
        case let i as Int:
            self = .int(i)
        case let d as Double:
            self = .double(d)
        case let s as String:
            self = .string(s)
        case let arr as [Any]:
            self = .array(arr.map { JSONValue($0) })
        case let dict as [String: Any]:
            self = .dictionary(dict.mapValues { JSONValue($0) })
        default:
            self = .null
        }
    }
}

// MARK: - StreamMessage Adapters

/// Extension for StreamMessage enum with convenience accessors
extension StreamMessage {
    /// Extract assistant content if this is an assistant message
    public var assistantContent: AssistantStreamMessage? {
        if case .typeAssistantStreamMessage(let msg) = self { return msg }
        return nil
    }

    /// Extract user content if this is a user message
    public var userContent: UserStreamMessage? {
        if case .typeUserStreamMessage(let msg) = self { return msg }
        return nil
    }

    /// Extract system content if this is a system message
    public var systemContent: SystemStreamMessage? {
        if case .typeSystemStreamMessage(let msg) = self { return msg }
        return nil
    }

    /// Extract tool use content if this is a tool_use message
    public var toolUseContent: ToolUseStreamMessage? {
        if case .typeToolUseStreamMessage(let msg) = self { return msg }
        return nil
    }

    /// Extract tool result content if this is a tool_result message
    public var toolResultContent: ToolResultStreamMessage? {
        if case .typeToolResultStreamMessage(let msg) = self { return msg }
        return nil
    }

    /// Extract usage content if this is a usage message
    public var usageContent: UsageStreamMessage? {
        if case .typeUsageStreamMessage(let msg) = self { return msg }
        return nil
    }

    /// Extract state content if this is a state message
    public var stateContent: StateStreamMessage? {
        if case .typeStateStreamMessage(let msg) = self { return msg }
        return nil
    }

    /// Extract progress content if this is a progress message
    public var progressContent: ProgressStreamMessage? {
        if case .typeProgressStreamMessage(let msg) = self { return msg }
        return nil
    }

    /// Extract subagent start content
    public var subagentStartContent: SubagentStartStreamMessage? {
        if case .typeSubagentStartStreamMessage(let msg) = self { return msg }
        return nil
    }

    /// Extract subagent complete content
    public var subagentCompleteContent: SubagentCompleteStreamMessage? {
        if case .typeSubagentCompleteStreamMessage(let msg) = self { return msg }
        return nil
    }

    /// Get the message type as string
    public var messageType: String {
        switch self {
        case .typeAssistantStreamMessage: return "assistant"
        case .typeUserStreamMessage: return "user"
        case .typeSystemStreamMessage: return "system"
        case .typeToolUseStreamMessage: return "tool_use"
        case .typeToolResultStreamMessage: return "tool_result"
        case .typeUsageStreamMessage: return "usage"
        case .typeStateStreamMessage: return "state"
        case .typeProgressStreamMessage: return "progress"
        case .typeSubagentStartStreamMessage: return "subagent_start"
        case .typeSubagentCompleteStreamMessage: return "subagent_complete"
        case .typePermissionRequestMessage: return "permission"
        case .typeQuestionMessage: return "question"
        case .typeThinkingStreamMessage: return "thinking"
        }
    }
}

// MARK: - StoredMessage Extension for ChatMessage Conversion

extension StoredMessage {
    /// Convert to ChatMessage for UI display
    /// Returns nil for ephemeral messages (deltas, progress, state changes)
    func toChatMessage() -> ChatMessage? {
        switch message {
        case .typeAssistantStreamMessage(let content):
            // Skip streaming deltas - only render complete messages
            if content.delta == true { return nil }
            return ChatMessage(role: .assistant, content: content.content, timestamp: timestamp)

        case .typeUserStreamMessage(let content):
            return ChatMessage(role: .user, content: content.content, timestamp: timestamp)

        case .typeSystemStreamMessage(let content):
            // Skip system messages with subtype (duplicates or metadata)
            if content.subtype != nil { return nil }
            return ChatMessage(role: .system, content: content.content, timestamp: timestamp)

        case .typeToolUseStreamMessage(let content):
            let inputString: String
            if let data = try? JSONEncoder().encode(content.input),
               let str = String(data: data, encoding: .utf8) {
                inputString = str
            } else {
                inputString = ""
            }
            let displayContent = inputString.isEmpty ? content.name : "\(content.name)(\(inputString))"
            return ChatMessage(role: .toolUse, content: displayContent, timestamp: timestamp)

        case .typeToolResultStreamMessage(let content):
            let role: ChatMessage.Role = content.isError == true || !content.success ? .error : .toolResult
            return ChatMessage(role: role, content: content.output, timestamp: timestamp)

        case .typeUsageStreamMessage, .typeProgressStreamMessage, .typeStateStreamMessage,
             .typeSubagentStartStreamMessage, .typeSubagentCompleteStreamMessage:
            // Ephemeral messages - don't persist to chat
            return nil

        case .typePermissionRequestMessage, .typeQuestionMessage:
            // Permission and question messages are handled separately
            return nil

        case .typeThinkingStreamMessage(let content):
            // Thinking messages show the model's extended thinking
            return ChatMessage(role: .thinking, content: content.content, timestamp: timestamp)
        }
    }

    /// Whether this is an ephemeral message (UI state only, don't persist)
    public var isEphemeral: Bool {
        switch message {
        case .typeAssistantStreamMessage(let content) where content.delta == true:
            return true
        case .typeProgressStreamMessage, .typeStateStreamMessage,
             .typeSubagentStartStreamMessage, .typeSubagentCompleteStreamMessage:
            return true
        case .typePermissionRequestMessage, .typeQuestionMessage:
            // Permission and question messages are transient UI states
            return true
        default:
            return false
        }
    }
}

// MARK: - Session Metadata Extension

extension SessionMetadata {
    /// Display title - prefers customTitle over auto-generated title
    public var displayTitle: String? {
        if let custom = customTitle, !custom.isEmpty {
            return custom
        }
        return title
    }

    /// Whether this is a helper session (should be hidden from user)
    public var isHelper: Bool {
        source == .helper
    }

    /// Whether this is a sub-agent session (should be hidden from user)
    public var isAgent: Bool {
        source == .agent
    }

    /// Whether this should be shown in the user's session list
    public var isUserVisible: Bool {
        source == .user
    }

    /// Whether this session is archived (soft deleted)
    public var isArchived: Bool {
        archivedAt != nil
    }
}
