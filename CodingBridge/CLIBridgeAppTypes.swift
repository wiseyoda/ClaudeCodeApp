import Foundation

// MARK: - CLI Bridge App Types
// App-specific types for CLI Bridge integration that aren't generated from OpenAPI.
// These types extend the generated types with app-local state, convenience methods,
// and unified event handling.

// ============================================================================
// MARK: - Type Aliases (Backward Compatibility)
// ============================================================================
// These aliases map old CLI* names to the generated types for backward compatibility.
// New code should use the generated types directly.

// Project Types
public typealias CLIProject = APIProject
public typealias CLIProjectList = ProjectListResponse

// Session Types
public typealias CLISessionMetadata = SessionMetadata
public typealias CLISessionEvent = SessionEventMessage
public typealias CLISessionListResponse = SessionListResult
public typealias CLISessionCountResponse = SessionCountResult
public typealias CLISessionSearchResponse = ProjectsEncodedPathSessionsSearchGet200Response
public typealias CLISessionSearchResult = ProjectsEncodedPathSessionsSearchGet200ResponseAllOfResultsInner
public typealias CLISessionSearchMatch = ProjectsEncodedPathSessionsSearchGet200ResponseAllOfResultsInnerAllOfSnippetsInner

// Pagination Types
public typealias CLIPaginatedMessagesResponse = GetMessagesResponse
public typealias CLIPagination = GetMessagesResponsePagination

// Bulk Operations
public typealias CLIBulkOperationResponse = BulkOperationResult

// File Types
public typealias CLIFileListResponse = DirectoryListing
public typealias CLIFileContentResponse = FileContent
public typealias CLIFileEntry = APIFileEntry

// Search Types
public typealias CLISearchResponse = SearchResponse
public typealias CLISearchResult = SearchResult
public typealias CLISearchSnippet = SearchSnippet

// Push Notification Types
public typealias CLIPushRegisterRequest = RegisterFcmRequest
public typealias CLIPushRegisterResponse = RegisterFcmResponse
public typealias CLIPushInvalidateRequest = InvalidateTokenRequest
public typealias CLIPushStatusResponse = PushStatusResponse
public typealias CLILiveActivityRegisterRequest = RegisterLiveActivityRequest
public typealias CLILiveActivityRegisterResponse = RegisterLiveActivityResponse

// Git Types
public typealias CLIGitStatus = APIGitStatus
// Note: CLISubRepoInfo is defined in CLIBridgeAPIClient.swift as a custom struct

// Permission Types (backward compatibility)
public typealias CLIPermissionChoice = PermissionResponseMessage.Choice
public typealias CLIPermissionMode = SetPermissionModeMessage.Mode
public typealias CLIImageAttachment = APIImageAttachment
public typealias CLIPermissionRequest = PermissionRequestMessage
public typealias CLIQuestionRequest = QuestionMessage

// Bulk Operations Types
public typealias CLIBulkOperationRequest = BulkOperationRequest

// Stream Content Types (backward compatibility)
public typealias CLISubagentStartContent = SubagentStartStreamMessage
public typealias CLISubagentCompleteContent = SubagentCompleteStreamMessage
public typealias CLIProgressContent = ProgressStreamMessage
public typealias CLIUsageContent = UsageStreamMessage
public typealias CLIHistoryPayload = HistoryMessage

// Connection State (backward compatibility with old naming)
typealias ConnectionState = CLIConnectionState

// ============================================================================
// MARK: - Date Formatters
// ============================================================================

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

// ============================================================================
// MARK: - Token Usage
// ============================================================================

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

// ============================================================================
// MARK: - AnyCodableValue
// ============================================================================

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
      value = NSNull()
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
    case is NSNull,
         Optional<Any>.none,
         Optional<String>.none:
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
    case let array as [any Sendable]:
      try container.encode(array.map { AnyCodableValue($0) })
    case let dict as [String: Any]:
      try container.encode(dict.mapValues { AnyCodableValue($0) })
    case let dict as [String: any Sendable]:
      try container.encode(dict.mapValues { AnyCodableValue($0) })
    default:
      throw EncodingError.invalidValue(
        value,
        .init(codingPath: encoder.codingPath, debugDescription: "Unable to encode AnyCodableValue")
      )
    }
  }

  public static func == (lhs: AnyCodableValue, rhs: AnyCodableValue) -> Bool {
    valuesEqual(lhs.value, rhs.value)
  }

  public func hash(into hasher: inout Hasher) {
    Self.hashValue(value, into: &hasher)
  }

  /// Get value as String if it is one
  public var stringValue: String? {
    if let string = value as? String {
      return string
    }
    if let bool = value as? Bool {
      return bool ? "true" : "false"
    }
    if let int = value as? Int {
      return String(int)
    }
    if let double = value as? Double {
      return String(double)
    }
    if let number = value as? NSNumber {
      return number.stringValue
    }
    if value is NSNull {
      return nil
    }
    if let dict = Self.dictionaryValue(from: value) {
      if let stdout = dict["stdout"] as? String {
        return stdout
      }
      return Self.jsonString(from: dict) ?? String(describing: value)
    }
    if let array = Self.arrayValue(from: value) {
      return Self.jsonString(from: array) ?? String(describing: value)
    }
    return String(describing: value)
  }

  private static func unwrapValue(_ value: Any) -> Any {
    if let wrapped = value as? AnyCodableValue {
      return wrapped.value
    }
    return value
  }

  private static func arrayValue(from value: Any) -> [Any]? {
    if let array = value as? [Any] {
      return array.map { unwrapValue($0) }
    }
    if let array = value as? [any Sendable] {
      return array.map { unwrapValue($0) }
    }
    return nil
  }

  private static func dictionaryValue(from value: Any) -> [String: Any]? {
    if let dict = value as? [String: Any] {
      return dict.mapValues { unwrapValue($0) }
    }
    if let dict = value as? [String: any Sendable] {
      return dict.mapValues { unwrapValue($0) }
    }
    return nil
  }

  private static func valuesEqual(_ lhs: Any, _ rhs: Any) -> Bool {
    let lhsValue = unwrapValue(lhs)
    let rhsValue = unwrapValue(rhs)

    switch (lhsValue, rhsValue) {
    case (_ as NSNull, _ as NSNull):
      return true
    case (let lhsBool as Bool, let rhsBool as Bool):
      return lhsBool == rhsBool
    case (let lhsInt as Int, let rhsInt as Int):
      return lhsInt == rhsInt
    case (let lhsDouble as Double, let rhsDouble as Double):
      return lhsDouble == rhsDouble
    case (let lhsInt as Int, let rhsDouble as Double):
      return Double(lhsInt) == rhsDouble
    case (let lhsDouble as Double, let rhsInt as Int):
      return lhsDouble == Double(rhsInt)
    case (let lhsString as String, let rhsString as String):
      return lhsString == rhsString
    default:
      if let lhsArray = arrayValue(from: lhsValue),
         let rhsArray = arrayValue(from: rhsValue) {
        guard lhsArray.count == rhsArray.count else { return false }
        for (lhsElement, rhsElement) in zip(lhsArray, rhsArray) {
          if !valuesEqual(lhsElement, rhsElement) {
            return false
          }
        }
        return true
      }
      if let lhsDict = dictionaryValue(from: lhsValue),
         let rhsDict = dictionaryValue(from: rhsValue) {
        guard lhsDict.count == rhsDict.count else { return false }
        for (key, lhsValue) in lhsDict {
          guard let rhsValue = rhsDict[key],
                valuesEqual(lhsValue, rhsValue) else {
            return false
          }
        }
        return true
      }
      return false
    }
  }

  private static func hashValue(_ value: Any, into hasher: inout Hasher) {
    let unwrapped = unwrapValue(value)

    if unwrapped is NSNull {
      hasher.combine(0)
      return
    }
    if let bool = unwrapped as? Bool {
      hasher.combine(1)
      hasher.combine(bool)
      return
    }
    if let int = unwrapped as? Int {
      hasher.combine(2)
      hasher.combine(int)
      return
    }
    if let double = unwrapped as? Double {
      hasher.combine(2)
      hasher.combine(double)
      return
    }
    if let string = unwrapped as? String {
      hasher.combine(3)
      hasher.combine(string)
      return
    }
    if let array = arrayValue(from: unwrapped) {
      hasher.combine(4)
      for item in array {
        hashValue(item, into: &hasher)
      }
      return
    }
    if let dict = dictionaryValue(from: unwrapped) {
      hasher.combine(5)
      for key in dict.keys.sorted() {
        hasher.combine(key)
        if let item = dict[key] {
          hashValue(item, into: &hasher)
        }
      }
      return
    }
    hasher.combine(6)
    hasher.combine(String(describing: unwrapped))
  }

  private static func jsonString(from value: Any) -> String? {
    guard JSONSerialization.isValidJSONObject(value),
          let data = try? JSONSerialization.data(withJSONObject: value, options: []),
          let string = String(data: data, encoding: .utf8) else {
      return nil
    }
    return string
  }
}

/// Backward-compatible typealias for AnyCodableValue
public typealias AnyCodable = AnyCodableValue

// ============================================================================
// MARK: - StreamEvent (Unified Event Enum)
// ============================================================================
// Single enum consolidating all CLIBridgeManager callbacks into one type.
// Consumers switch on StreamEvent cases.

/// Unified event type emitted by CLIBridgeManager
/// Consumers switch on this enum instead of registering multiple callbacks
public enum StreamEvent: Sendable {
  // MARK: - Content Events (from streaming)

  /// Assistant text content (streaming or final)
  /// - Parameters:
  ///   - text: The text content
  ///   - isFinal: True if this is the final text (not a streaming delta)
  case text(String, isFinal: Bool)

  /// Extended thinking content
  case thinking(String)

  /// Tool invocation started
  /// - Parameters:
  ///   - id: Tool use ID for correlation with result
  ///   - name: Tool name (e.g., "Read", "Bash", "Edit")
  ///   - input: Tool input parameters
  case toolStart(id: String, name: String, input: [String: JSONValue])

  /// Tool execution completed
  /// - Parameters:
  ///   - id: Tool use ID matching the toolStart
  ///   - name: Tool name
  ///   - output: Tool output/result
  ///   - isError: True if the tool failed
  case toolResult(id: String, name: String, output: String, isError: Bool)

  /// System message from Claude
  case system(String)

  /// User message (echoed back for history)
  case user(String)

  /// Progress update for long-running operations
  case progress(ProgressStreamMessage)

  /// Token usage update
  case usage(UsageStreamMessage)

  // MARK: - Agent State Events

  /// Agent state changed
  case stateChanged(CLIAgentState)

  /// Agent stopped (completed, aborted, or errored)
  /// - Parameters:
  ///   - reason: Why the agent stopped
  case stopped(reason: String)

  /// Model changed (either requested or server-assigned)
  case modelChanged(model: String)

  /// Permission mode changed
  case permissionModeChanged(mode: String)

  // MARK: - Session Events

  /// Connected to a session (new or resumed)
  /// - Parameters:
  ///   - sessionId: The session UUID
  ///   - agentId: The agent ID
  ///   - model: Current model
  case connected(sessionId: String, agentId: String, model: String)

  /// Session event (created, updated, deleted)
  case sessionEvent(SessionEventMessage)

  /// History messages received (on reconnect or load)
  case history(HistoryMessage)

  // MARK: - Interactive Events

  /// Permission request from agent
  case permissionRequest(PermissionRequestMessage)

  /// Question from agent requiring user response
  case questionRequest(QuestionMessage)

  // MARK: - Subagent Events

  /// Subagent (Task agent) started
  case subagentStart(SubagentStartStreamMessage)

  /// Subagent completed
  case subagentComplete(SubagentCompleteStreamMessage)

  // MARK: - Queue Events

  /// Input was queued (agent busy)
  /// - Parameter position: Queue position (1 = next)
  case inputQueued(position: Int)

  /// Queue was cleared
  case queueCleared

  // MARK: - Connection Events

  /// Connection was replaced by another client
  case connectionReplaced

  /// Reconnecting to session
  /// - Parameters:
  ///   - attempt: Current attempt number
  ///   - delay: Delay before this attempt
  case reconnecting(attempt: Int, delay: TimeInterval)

  /// Reconnection completed successfully
  case reconnectComplete(ReconnectCompleteMessage)

  /// Connection error
  case connectionError(ConnectionError)

  /// Network status changed
  case networkStatusChanged(isOnline: Bool)

  /// Cursor was evicted (another session took over)
  case cursorEvicted(CursorEvictedMessage)

  /// Cursor is invalid (session expired or corrupted)
  case cursorInvalid(CursorInvalidMessage)

  // MARK: - Error Events

  /// Error from server or protocol
  case error(WsErrorMessage)
}

// MARK: - StreamEvent Convenience Extensions

extension StreamEvent {
  /// Whether this event represents an error condition
  public var isError: Bool {
    switch self {
    case .error, .connectionError:
      return true
    default:
      return false
    }
  }

  /// Whether this event is transient (doesn't need to be persisted)
  public var isTransient: Bool {
    switch self {
    case .progress, .usage, .stateChanged, .reconnecting,
         .networkStatusChanged, .inputQueued, .queueCleared:
      return true
    default:
      return false
    }
  }

  /// Human-readable event type for logging
  public var eventType: String {
    switch self {
    case .text: return "text"
    case .thinking: return "thinking"
    case .toolStart: return "tool_start"
    case .toolResult: return "tool_result"
    case .system: return "system"
    case .user: return "user"
    case .progress: return "progress"
    case .usage: return "usage"
    case .stateChanged: return "state_changed"
    case .stopped: return "stopped"
    case .modelChanged: return "model_changed"
    case .permissionModeChanged: return "permission_mode_changed"
    case .connected: return "connected"
    case .sessionEvent: return "session_event"
    case .history: return "history"
    case .permissionRequest: return "permission_request"
    case .questionRequest: return "question_request"
    case .subagentStart: return "subagent_start"
    case .subagentComplete: return "subagent_complete"
    case .inputQueued: return "input_queued"
    case .queueCleared: return "queue_cleared"
    case .connectionReplaced: return "connection_replaced"
    case .reconnecting: return "reconnecting"
    case .reconnectComplete: return "reconnect_complete"
    case .connectionError: return "connection_error"
    case .networkStatusChanged: return "network_status_changed"
    case .cursorEvicted: return "cursor_evicted"
    case .cursorInvalid: return "cursor_invalid"
    case .error: return "error"
    }
  }
}

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

// ============================================================================
// MARK: - Connection Error
// ============================================================================

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
    case "agent_not_found":
      return .agentTimedOut
    case "session_not_found":
      return .sessionNotFound
    case "session_expired":
      return .sessionExpired
    case "session_invalid", "cursor_invalid":
      return .sessionInvalid
    case "max_agents_reached":
      return .serverAtCapacity
    case "queue_full":
      return .queueFull
    case "rate_limited":
      return .rateLimited(Int(error.retryAfter ?? 0))
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
// MARK: - CLIStoredMessage (Custom Struct)
// ============================================================================
// Custom StoredMessage that uses CLIStreamContent instead of StreamMessage

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
// MARK: - Custom Structs (Not in OpenAPI)
// ============================================================================

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

/// Compatibility struct for search matches
struct SearchMatchCompat: Identifiable {
  let messageId: String
  let role: String
  let snippet: String

  var id: String { messageId }
}

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
