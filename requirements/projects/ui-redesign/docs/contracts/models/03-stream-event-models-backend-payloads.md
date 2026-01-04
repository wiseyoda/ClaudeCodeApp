# Stream Event Models (Backend Payloads)


Stream events are defined in:
- `CodingBridge/CLIBridgeAppTypes.swift` (high-level enum)
- `CodingBridge/Generated/*.swift` (exact JSON schemas)
- `../api/README.md` (canonical wire format reference)

### ServerMessage (Wire Union)

All WebSocket messages are one of 18 types in the `ServerMessage` union:

**Content delivery:**
- `stream` - Wraps StreamMessage in envelope with id/timestamp

**Control messages:**
- `connected`, `history`, `session_event`
- `queued`, `queue_cleared`
- `model_changed`, `permission_mode_changed`
- `stopped`, `interrupted`
- `permission`, `question`

**Connection management:**
- `ping`, `pong`
- `reconnect_complete`, `cursor_evicted`, `cursor_invalid`
- `error`

### StreamServerMessage (Envelope)

```
struct StreamServerMessage: Sendable, Codable {
    let type: "stream"
    let id: String        // UUID
    let timestamp: String // ISO-8601
    let message: StreamMessage
}
```

### StreamMessage (Content Union)

The `message` field contains one of 13 types:
- `assistant`, `user`, `system`, `thinking`
- `tool_use`, `tool_result`, `progress`
- `usage`, `state`
- `permission`, `question`
- `subagent_start`, `subagent_complete`

Some `StreamEvent` cases are client-local (`reconnecting`, `connectionError`, `networkStatusChanged`) and
do not correspond to wire payloads.

### StreamEvent (UI Consumption)

```
enum StreamEvent: Sendable {
    // Content messages
    case text(String, isFinal: Bool)
    case thinking(String)
    case toolStart(id: String, name: String, inputDescription: String?, input: [String: JSONValue], timestamp: Date)
    case toolResult(id: String, name: String, output: String, isError: Bool, timestamp: Date)
    case system(String, subtype: String?)
    case user(String)
    case progress(ProgressStreamMessage)
    case usage(UsageStreamMessage)
    case stateChanged(StateStreamMessage)
    case subagentStart(SubagentStartStreamMessage)
    case subagentComplete(SubagentCompleteStreamMessage)

    // Control messages
    case connected(ConnectedMessage)
    case stopped(StoppedMessage)
    case interrupted
    case modelChanged(ModelChangedMessage)
    case permissionModeChanged(PermissionModeChangedMessage)
    case sessionEvent(SessionEventMessage)
    case history(HistoryMessage)
    case permissionRequest(PermissionRequestMessage)
    case questionRequest(QuestionMessage)
    case inputQueued(position: Int)
    case queueCleared

    // Connection management
    case serverPing(serverTime: Int64)
    case pong(serverTime: Int64)
    case reconnectComplete(ReconnectCompleteMessage)
    case cursorEvicted(CursorEvictedMessage)
    case cursorInvalid(CursorInvalidMessage)
    case connectionReplaced
    case error(WsErrorMessage)

    // Client-local (not wire payloads)
    case reconnecting(attempt: Int, delay: TimeInterval)
    case connectionError(ConnectionError)
    case networkStatusChanged(isOnline: Bool)
}
```

### ProgressStreamMessage (Exact Fields)

```
struct ProgressStreamMessage: Sendable, Codable, Hashable {
    let type: "progress"
    let id: String
    let tool: String
    let elapsed: Double
    let progress: Double?
    let detail: String?
}
```

### UsageStreamMessage (Exact Fields)

```
struct UsageStreamMessage: Sendable, Codable, Hashable {
    let type: "usage"
    let inputTokens: Int
    let outputTokens: Int
    let cacheReadTokens: Int?
    let cacheCreateTokens: Int?
    let totalCost: Double?
    let contextUsed: Int?
    let contextLimit: Int?
}
```

### ToolUseStreamMessage (Exact Fields)

```
struct ToolUseStreamMessage: Sendable, Codable, Hashable {
    let type: "tool_use"
    let id: String
    let name: String
    let input: [String: JSONValue]
    let inputDescription: String?
    let result: ToolResultInline?
}

struct ToolResultInline: Sendable, Codable, Hashable {
    let output: String
    let success: Bool
    let isError: Bool?
}
```

Note: `result` is only populated in denormalized history responses, not in live streaming.

### ToolResultStreamMessage (Exact Fields)

```
struct ToolResultStreamMessage: Sendable, Codable, Hashable {
    let type: "tool_result"
    let id: String
    let tool: String
    let output: String
    let success: Bool
    let isError: Bool?
}
```

### PermissionRequestMessage (Exact Fields)

```
struct PermissionRequestMessage: Sendable, Codable, Hashable {
    let type: "permission"
    let id: String
    let tool: String
    let input: [String: JSONValue]
    let options: [Options]
}
```

### QuestionMessage (Exact Fields)

```
struct QuestionMessage: Sendable, Codable, Hashable {
    let type: "question"
    let id: String
    let questions: [QuestionItem]
}

struct QuestionItem: Sendable, Codable, Hashable {
    let question: String
    let header: String
    let options: [QuestionOption]
    let multiSelect: Bool
}

struct QuestionOption: Sendable, Codable, Hashable {
    let label: String
    let description: String?
}
```

### ConnectedMessage (Exact Fields)

```
struct ConnectedMessage: Sendable, Codable, Hashable {
    let type: "connected"
    let agentId: String
    let sessionId: String
    let model: String
    let modelAlias: String?
    let version: String
    let protocolVersion: String  // "1.0"
}
```

### StateStreamMessage (Exact Fields)

```
struct StateStreamMessage: Sendable, Codable, Hashable {
    let type: "state"
    let state: AgentState
    let tool: String?
}

enum AgentState: String, Codable {
    case thinking
    case executing
    case waitingInput = "waiting_input"
    case waitingPermission = "waiting_permission"
    case idle
    case recovering
}
```

### ModelChangedMessage (Exact Fields)

```
struct ModelChangedMessage: Sendable, Codable, Hashable {
    let type: "model_changed"
    let model: String
    let previousModel: String
}
```

### PermissionModeChangedMessage (Exact Fields)

```
struct PermissionModeChangedMessage: Sendable, Codable, Hashable {
    let type: "permission_mode_changed"
    let mode: PermissionMode
}

enum PermissionMode: String, Codable {
    case `default`
    case acceptEdits
    case bypassPermissions
}
```

### StoppedMessage (Exact Fields)

```
struct StoppedMessage: Sendable, Codable, Hashable {
    let type: "stopped"
    let reason: StopReason
}

enum StopReason: String, Codable {
    case user
    case complete
    case error
    case timeout
}
```

### InterruptedMessage (Exact Fields)

```
struct InterruptedMessage: Sendable, Codable, Hashable {
    let type: "interrupted"
}
```

### SessionEventMessage (Exact Fields)

```
struct SessionEventMessage: Sendable, Codable, Hashable {
    let type: "session_event"
    let action: SessionAction
    let projectPath: String
    let sessionId: String
    let metadata: SessionMetadata?
}

enum SessionAction: String, Codable {
    case created
    case updated
    case deleted
}

struct SessionMetadata: Sendable, Codable, Hashable {
    let id: String
    let projectPath: String
    let source: SessionSource
    let createdAt: String?
    let lastActivityAt: String
    let messageCount: Int
    let title: String?
    let summary: String?
    let customTitle: String?
    let model: String?
    let archivedAt: String?
    let parentSessionId: String?
}

enum SessionSource: String, Codable {
    case user
    case agent
    case helper
}
```

### HistoryMessage (Exact Fields)

```
struct HistoryMessage: Sendable, Codable, Hashable {
    let type: "history"
    let messages: [StreamMessage]
    let hasMore: Bool
    let cursor: String?
}
```

### SubagentStartStreamMessage (Exact Fields)

```
struct SubagentStartStreamMessage: Sendable, Codable, Hashable {
    let type: "subagent_start"
    let id: String
    let description: String
}
```

### SubagentCompleteStreamMessage (Exact Fields)

```
struct SubagentCompleteStreamMessage: Sendable, Codable, Hashable {
    let type: "subagent_complete"
    let id: String
    let summary: String?
}
```

### ThinkingStreamMessage (Exact Fields)

```
struct ThinkingStreamMessage: Sendable, Codable, Hashable {
    let type: "thinking"
    let content: String
    let thinking: String?  // Alias for content
}
```

### AssistantStreamMessage (Exact Fields)

```
struct AssistantStreamMessage: Sendable, Codable, Hashable {
    let type: "assistant"
    let content: String
    let delta: Bool?
}
```

### UserStreamMessage (Exact Fields)

```
struct UserStreamMessage: Sendable, Codable, Hashable {
    let type: "user"
    let content: String
}
```

### SystemStreamMessage (Exact Fields)

```
struct SystemStreamMessage: Sendable, Codable, Hashable {
    let type: "system"
    let content: String
    let subtype: SystemSubtype?
}

enum SystemSubtype: String, Codable {
    case `init`
    case result
    case progress
}
```

### ReconnectCompleteMessage (Exact Fields)

```
struct ReconnectCompleteMessage: Sendable, Codable, Hashable {
    let type: "reconnect_complete"
    let missedCount: Int
    let fromMessageId: String
}
```

### CursorEvictedMessage (Exact Fields)

```
struct CursorEvictedMessage: Sendable, Codable, Hashable {
    let type: "cursor_evicted"
    let lastMessageId: String
    let recommendation: String  // "fetch_from_rest"
}
```

### CursorInvalidMessage (Exact Fields)

```
struct CursorInvalidMessage: Sendable, Codable, Hashable {
    let type: "cursor_invalid"
    let lastMessageId: String
    let recommendation: String  // "full_resync"
}
```

### WsErrorMessage (Exact Fields)

```
struct WsErrorMessage: Sendable, Codable, Hashable {
    let type: "error"
    let code: String
    let message: String
    let recoverable: Bool
    let retryable: Bool?
    let retryAfter: Double?
}
```

Error codes (see ../api/README.md for full list):
- `NO_AGENT`, `AGENT_NOT_FOUND`, `AGENT_CREATE_FAILED`
- `MAX_AGENTS_REACHED`, `CONNECTION_REPLACED`, `RATE_LIMITED`
- `INVALID_MESSAGE`, `UNKNOWN_MESSAGE_TYPE`, `INPUT_FAILED`
- `QUEUE_FULL`, `TIMEOUT`, `NO_FAILED_MESSAGE`
- `MESSAGE_ID_MISMATCH`, `RETRY_EXPIRED`, `RETRY_FAILED`
- `INVALID_PERMISSION_ID`, `INVALID_QUESTION_ID`

### ServerPingMessage (Exact Fields)

```
struct ServerPingMessage: Sendable, Codable, Hashable {
    let type: "ping"
    let serverTime: Int64  // Epoch milliseconds
}
```

### PongMessage (Exact Fields)

```
struct PongMessage: Sendable, Codable, Hashable {
    let type: "pong"
    let serverTime: Int64  // Epoch milliseconds
}
```

### QueuedMessage (Exact Fields)

```
struct QueuedMessage: Sendable, Codable, Hashable {
    let type: "queued"
    let position: Int
}
```

### QueueClearedMessage (Exact Fields)

```
struct QueueClearedMessage: Sendable, Codable, Hashable {
    let type: "queue_cleared"
}
```

---
