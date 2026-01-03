import Foundation

// MARK: - CLI Bridge Extensions
// Extensions to generated OpenAPI types adding convenience methods.
// These make the generated types more ergonomic to use in the app.

// ============================================================================
// MARK: - ClientMessage Convenience Extensions
// ============================================================================

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
  public init(text: String, images: [CLIImageAttachment]? = nil, messageId: String? = nil, thinkingMode: String? = nil) {
    self.init(type: .input, text: text, images: images, messageId: messageId, thinkingMode: thinkingMode)
  }

  /// Convenience init that accepts app's ImageAttachment type and converts to CLIImageAttachment
  init(text: String, images: [ImageAttachment]?, messageId: String? = nil, thinkingMode: String? = nil) {
    let cliImages = images?.compactMap { $0.toCLIImageAttachment() }
    self.init(type: .input, text: text, images: cliImages, messageId: messageId, thinkingMode: thinkingMode)
  }
}

/// Extension to convert app's ImageAttachment to generated CLIImageAttachment
extension ImageAttachment {
  /// Convert to CLIImageAttachment for sending over the wire
  func toCLIImageAttachment() -> CLIImageAttachment? {
    switch uploadState {
    case .uploaded(let refId):
      return CLIImageAttachment(type: .reference, id: refId, mimeType: mimeType)
    case .inline:
      let base64 = dataForSending.base64EncodedString()
      return CLIImageAttachment(type: .base64, data: base64, mimeType: mimeType)
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

// ============================================================================
// MARK: - ServerMessage Convenience Constructors
// ============================================================================

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

extension HistoryMessage {
  /// Convert stream messages to ChatMessages
  func toChatMessages() -> [ChatMessage] {
    messages.compactMap { streamMessage in
      streamMessage.toChatMessage()
    }
  }

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
// MARK: - CLIImageAttachment Extensions
// ============================================================================

extension CLIImageAttachment {
  /// Create a reference-type attachment (for uploaded images)
  public init(referenceId: String) {
    self.init(type: .reference, id: referenceId)
  }

  /// Create a base64-type attachment (for inline images)
  public init(base64Data: String, mimeType: String) {
    self.init(type: .base64, data: base64Data, mimeType: mimeType)
  }
}

// ============================================================================
// MARK: - Stream Content Types Extensions
// ============================================================================

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

extension ToolUseStreamMessage {
  /// Get input as dictionary with Any values for compatibility
  public var inputDict: [String: Any] {
    input.mapValues { $0.value }
  }
}

extension ToolResultStreamMessage {
  /// Tool name for compatibility (maps tool field)
  public var toolName: String { tool }
}

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

extension SubagentCompleteStreamMessage {
  public init(id: String, summary: String? = nil) {
    self.init(type: .subagentComplete, id: id, summary: summary)
  }

  /// Display summary with fallback
  public var displaySummary: String {
    summary ?? "Task completed"
  }
}

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

// ============================================================================
// MARK: - Permission Types Extensions
// ============================================================================

extension PermissionRequestMessage {
  /// Generate description from tool and input parameters
  public var description: String {
    requestDescription
  }

  /// Get a human-readable description of what's being requested
  public var requestDescription: String {
    if let command = input["command"]?.stringValue {
      return "Run command: \(command)"
    }
    if let filePath = input["file_path"]?.stringValue
        ?? input["filePath"]?.stringValue
        ?? input["path"]?.stringValue {
      return "\(tool): \(filePath)"
    }
    return tool
  }

  /// Map options to string array for compatibility
  public var optionStrings: [String] {
    options.map { $0.rawValue }
  }
}

extension QuestionMessage {
  /// Convenience: same as questions property
  public var questionItems: [QuestionItem] {
    questions
  }
}

// ============================================================================
// MARK: - JSONValue Extensions
// ============================================================================

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

// ============================================================================
// MARK: - StreamMessage Extensions
// ============================================================================

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

extension StreamServerMessage {
  /// Convert to CLIStoredMessage format for unified message handling
  public func toStoredMessage() -> CLIStoredMessage {
    CLIStoredMessage(id: id, timestamp: timestamp, message: message.toCLIStreamContent())
  }
}

// ============================================================================
// MARK: - StoredMessage Extensions
// ============================================================================

extension SystemStreamMessage {
    private static let sessionInitializedPrefix = "Session initialized"

    var isDisplayable: Bool {
        if let subtype = subtype, subtype != .result { return false }
        return Self.isDisplayableContent(content)
    }

    static func isDisplayableContent(_ content: String) -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return !trimmed.hasPrefix(sessionInitializedPrefix)
    }
}

extension StoredMessage {
  /// Convert to CLIStoredMessage format for unified message handling
  public func toCLIStoredMessage() -> CLIStoredMessage {
    CLIStoredMessage(id: id, timestamp: timestamp, message: message.toCLIStreamContent(), rawContent: rawContent)
  }

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
      // Skip non-displayable system messages (init/progress/metadata)
      guard content.isDisplayable else { return nil }
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

// ============================================================================
// MARK: - Session Metadata Extensions
// ============================================================================

extension SessionMetadata {
  public typealias SessionSource = Source

  /// Convert to ProjectSession for UI display
  func toProjectSession() -> ProjectSession {
    ProjectSession(
      id: id.uuidString,
      projectPath: projectPath,
      summary: displayTitle,
      lastActivity: CLIDateFormatter.string(from: lastActivityAt),
      messageCount: messageCount,
      lastUserMessage: lastUserMessage,
      lastAssistantMessage: lastAssistantMessage,
      archivedAt: archivedAt.map { CLIDateFormatter.string(from: $0) }
    )
  }

  /// Display title - prefers customTitle over auto-generated title
  public var displayTitle: String? {
    if let custom = customTitle, !custom.isEmpty {
      return custom
    }
    if let title = title, !title.isEmpty {
      return title
    }
    if let lastUser = lastUserMessage, !lastUser.isEmpty {
      return lastUser
    }
    return nil
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

extension SessionEventMessageMetadata {
  /// Convert to ProjectSession for UI display
  func toProjectSession() -> ProjectSession {
    let summaryText = customTitle ?? title ?? summary
    return ProjectSession(
      id: id.uuidString,
      projectPath: projectPath,
      summary: summaryText,
      lastActivity: CLIDateFormatter.string(from: lastActivityAt),
      messageCount: messageCount,
      lastUserMessage: nil,
      lastAssistantMessage: nil,
      archivedAt: archivedAt.map { CLIDateFormatter.string(from: $0) }
    )
  }
}

extension Array where Element == SessionMetadata {
  /// Convert array of SessionMetadata to ProjectSession array
  func toProjectSessions() -> [ProjectSession] {
    map { $0.toProjectSession() }
  }
}

// ============================================================================
// MARK: - Search Types Extensions
// ============================================================================

extension SearchResult: Identifiable {
  public var id: String { sessionId.uuidString }
}

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

extension SearchSnippet: Identifiable {
  public var id: String { "\(type)-\(matchStart)-\(matchLength)-\(text)" }
}

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

extension ProjectsEncodedPathSessionsSearchGet200ResponseAllOfResultsInner: Identifiable {
  public var id: String { sessionId }
}

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
// MARK: - File/Directory Extensions
// ============================================================================

extension CLIFileEntry: Identifiable {
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

extension DirectoryListing {
  /// Parent directory path (derived from path)
  public var parent: String? {
    let nsPath = path as NSString
    guard nsPath.length > 1 else { return nil }
    let parentPath = nsPath.deletingLastPathComponent
    return parentPath.isEmpty ? "/" : parentPath
  }
}

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
// MARK: - Project/Git Extensions
// ============================================================================

extension CLIGitStatus {
  /// Remote URL (not provided by API, return nil)
  public var remoteUrl: String? {
    // The API doesn't provide remote URL, derive from tracking branch if available
    guard let _ = trackingBranch else { return nil }
    // Format: "origin/main" -> just return nil since we don't have the actual URL
    return nil
  }

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
// MARK: - Pagination Extensions
// ============================================================================

extension GetMessagesResponse {
  /// Total count of messages
  var total: Int { pagination.total }

  /// Whether more messages are available
  var hasMore: Bool { pagination.hasMore }

  /// Convert paginated messages to ChatMessages (1:1 mapping)
  func toChatMessages() -> [ChatMessage] {
    messages.compactMap { $0.toChatMessage() }
  }
}

extension PaginatedMessage {
  /// Convert to a single ChatMessage using typed StreamMessage content
  /// Returns nil for ephemeral messages (deltas, progress, state changes)
  func toChatMessage() -> ChatMessage? {
    let date = CLIDateFormatter.parseDate(timestamp) ?? Date()

    switch message {
    case .typeUserStreamMessage(let user):
      guard !user.content.isEmpty else { return nil }
      return ChatMessage(id: UUID(), role: .user, content: user.content, timestamp: date)

    case .typeAssistantStreamMessage(let assistant):
      // Skip streaming deltas - only render complete messages
      if assistant.delta == true { return nil }
      guard !assistant.content.isEmpty else { return nil }
      return ChatMessage(id: UUID(), role: .assistant, content: assistant.content, timestamp: date)

    case .typeSystemStreamMessage(let system):
      // Skip non-displayable system messages (init/progress/metadata)
      guard system.isDisplayable else { return nil }
      return ChatMessage(id: UUID(), role: .system, content: system.content, timestamp: date)

    case .typeToolUseStreamMessage(let toolUse):
      let inputString = formatJSONValue(.dictionary(toolUse.input))
      let displayContent = inputString == "{}" ? toolUse.name : "\(toolUse.name)(\(inputString))"
      return ChatMessage(id: UUID(), role: .toolUse, content: displayContent, timestamp: date)

    case .typeToolResultStreamMessage(let toolResult):
      guard !toolResult.output.isEmpty else { return nil }
      let role: ChatMessage.Role = toolResult.isError == true || !toolResult.success ? .error : .toolResult
      return ChatMessage(id: UUID(), role: role, content: toolResult.output, timestamp: date)

    case .typeThinkingStreamMessage(let thinking):
      let content = thinking.thinking ?? thinking.content
      guard !content.isEmpty else { return nil }
      return ChatMessage(id: UUID(), role: .thinking, content: content, timestamp: date)

    case .typeUsageStreamMessage, .typeProgressStreamMessage, .typeStateStreamMessage,
         .typeSubagentStartStreamMessage, .typeSubagentCompleteStreamMessage:
      // Ephemeral messages - don't persist to chat
      return nil

    case .typePermissionRequestMessage, .typeQuestionMessage:
      // Permission and question messages are handled separately
      return nil
    }
  }

  /// Format a JSONValue as valid JSON string using JSONEncoder
  private func formatJSONValue(_ value: JSONValue) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    guard let data = try? encoder.encode(value),
          let jsonString = String(data: data, encoding: .utf8) else {
      return "{}"
    }
    return jsonString
  }
}

// ============================================================================
// MARK: - Bulk Operations Extensions
// ============================================================================

extension BulkOperationResult {
  /// Count of successful operations
  public var successCount: Int { success.count }
  /// Count of failed operations
  public var failedCount: Int { failed.count }
}
