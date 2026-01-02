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

/// Stream content union (assistant, tool_use, tool_result, etc.)
public typealias CLIStreamContent = StreamMessage

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

/// Agent state enum
public typealias CLIAgentState = StateStreamMessage.State

// ============================================================================
// MARK: - Permission and Question Types
// ============================================================================

/// Permission request from agent
public typealias CLIPermissionRequest = PermissionRequestMessage

/// Question request from agent
public typealias CLIQuestionRequest = QuestionMessage

/// Question item in a question request
public typealias CLIQuestionItem = QuestionItem

/// Option for a question
public typealias CLIQuestionOption = QuestionOption

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

// ============================================================================
// MARK: - Search Types
// ============================================================================

/// Search snippet (matching text in context)
public typealias CLISearchSnippet = SearchSnippet

/// Search result (session with matches)
public typealias CLISearchResult = SearchResult

/// Search response (all results)
public typealias CLISearchResponse = SearchResponse

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
public typealias CLIFileEntry = FileEntry

/// File list response
public typealias CLIFileListResponse = DirectoryListing

/// File content response
public typealias CLIFileContentResponse = FileContent

// ============================================================================
// MARK: - Project Types
// ============================================================================

/// Project from API (uses prefix to avoid conflict with app's Project)
public typealias CLIProject = APIProject

/// Git status from API
public typealias CLIGitStatus = APIGitStatus

// ============================================================================
// MARK: - Pagination Types
// ============================================================================

/// Paginated messages response
public typealias CLIPaginatedMessagesResponse = GetMessagesResponse

/// Pagination info
public typealias CLIPaginationInfo = GetMessagesResponsePagination

/// Pagination error
public typealias CLIPaginationError = PaginationError

// ============================================================================
// MARK: - Bulk Operations
// ============================================================================

/// Bulk operation request
public typealias CLIBulkOperationRequest = BulkOperationRequest

/// Bulk operation response
public typealias CLIBulkOperationResponse = BulkOperationResult

/// Bulk operation failure details
public typealias CLIBulkOperationFailure = BulkOperationResultFailedInner

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

/// Project list response
public typealias CLIProjectsResponse = ProjectListResponse

/// Health check response
public typealias CLIHealthResponse = HealthResponse

/// Metrics response
public typealias CLIMetricsResponse = MetricsResponse

/// Models list response
public typealias CLIModelsResponse = ModelsListResponse

/// Thinking modes response
public typealias CLIThinkingModesResponse = ThinkingModesListResponse

/// Agents list response
public typealias CLIAgentsResponse = AgentListResponse

/// Agent detail
public typealias CLIAgentInfo = AgentDetail

/// Create project request
public typealias CLICreateProjectRequest = CreateProjectRequest

/// Create project response
public typealias CLICreateProjectResponse = ProjectCreateResponse

/// Clone project request
public typealias CLICloneProjectRequest = CloneProjectRequest

/// Clone project response
public typealias CLICloneProjectResponse = ProjectCreateResponse

/// Delete project response
public typealias CLIDeleteProjectResponse = ProjectDeleteResponse

/// Git pull result
public typealias CLIGitPullResponse = GitPullResult

/// Sub-repo info
public typealias CLISubRepoInfo = SubRepo

/// Sub-repos response
public typealias CLISubReposResponse = SubReposListResponse

/// Session count result
public typealias CLISessionCountResponse = SessionCountResult

/// Image upload response
public typealias CLIImageUploadResponse = ImageUploadResponse

// ============================================================================
// MARK: - StreamServerMessage Extension
// ============================================================================

/// Extension to convert StreamServerMessage to StoredMessage for processing
extension StreamServerMessage {
    /// Convert to StoredMessage format for unified message handling
    public func toStoredMessage() -> StoredMessage {
        StoredMessage(id: id, timestamp: timestamp, message: message)
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

/// Extension for ConnectedMessage with compatibility properties
extension ConnectedMessage {
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
// MARK: - WsErrorMessage Extension
// ============================================================================

/// Extension to make WsErrorMessage compatible with CLIErrorPayload usage
extension WsErrorMessage {
    /// Error message for display
    public var errorMessage: String {
        message ?? "Unknown error"
    }
}

// ============================================================================
// MARK: - Image Attachment (Compatible with adapter)
// ============================================================================

/// Extension to make ImageAttachment compatible with CLIImageAttachment usage patterns
extension ImageAttachment {
    /// Create a base64 image attachment
    public init(base64Data: String, mimeType: String) {
        self.init(type: .base64, data: base64Data, mimeType: mimeType)
    }

    /// Create a reference image attachment
    public init(referenceId: String) {
        self.init(type: .reference, id: referenceId)
    }
}

/// Typealias: CLIImageAttachment → ImageAttachment
/// Generated type has identical structure with convenience initializers
public typealias CLIImageAttachment = ImageAttachment

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
        case .thinking, .executing, .starting, .recovering:
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
        case .object(let obj):
            return obj.mapValues { $0.value }
        }
    }

    /// Get value as String if possible
    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
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
        case .array, .object:
            if let data = try? JSONEncoder().encode(self),
               let str = String(data: data, encoding: .utf8) {
                return str
            }
            return String(describing: self)
        }
    }

    /// Get value as Int if possible
    public var intValue: Int? {
        switch self {
        case .int(let i):
            return i
        case .double(let d):
            return Int(d)
        default:
            return nil
        }
    }

    /// Get value as Bool if possible
    public var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    /// Get value as Dictionary if possible
    public var dictValue: [String: Any]? {
        if case .object(let obj) = self {
            return obj.mapValues { $0.value }
        }
        return nil
    }

    /// Get value as Array if possible
    public var arrayValue: [Any]? {
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
            self = .object(dict.mapValues { JSONValue($0) })
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
        }
    }
}

// MARK: - StoredMessage Extension for ChatMessage Conversion

extension StoredMessage {
    /// Convert to ChatMessage for UI display
    /// Returns nil for ephemeral messages (deltas, progress, state changes)
    public func toChatMessage() -> ChatMessage? {
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
