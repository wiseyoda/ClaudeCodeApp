# StreamEvent Mapping


| StreamEvent case | Wire source (Generated model) | Notes |
|---|---|---|
| `.text` | `AssistantStreamMessage` | `delta` true means streaming chunk (isFinal = false). |
| `.thinking` | `ThinkingStreamMessage` | `content` (alias `thinking` optional). |
| `.toolStart` | `ToolUseStreamMessage` | `id`, `name`, `input`, `inputDescription`. |
| `.toolResult` | `ToolResultStreamMessage` | `id`, `tool`, `output`, `success`, `isError`. |
| `.system` | `SystemStreamMessage` | `content`, `subtype` (`init`, `result`, `progress`). |
| `.user` | `UserStreamMessage` | `content`. |
| `.progress` | `ProgressStreamMessage` | `id`, `tool`, `elapsed`, `progress` (0-100), `detail`. |
| `.usage` | `UsageStreamMessage` | Token fields and optional cost/context. |
| `.stateChanged` | `StateStreamMessage` | `state`, optional `tool`. States: `thinking`, `executing`, `waiting_input`, `waiting_permission`, `idle`, `recovering`. |
| `.connected` | `ConnectedMessage` | `sessionId`, `agentId`, `model`, `modelAlias`, `version`, `protocolVersion`. |
| `.sessionEvent` | `SessionEventMessage` | `action`, `projectPath`, `sessionId`, `metadata?` (see SessionMetadata). |
| `.history` | `HistoryMessage` | `messages` = `[StreamMessage]`, `hasMore`, `cursor`. |
| `.permissionRequest` | `PermissionRequestMessage` | `id`, `tool`, `input`, `options`. |
| `.questionRequest` | `QuestionMessage` | `id`, `questions`. |
| `.subagentStart` | `SubagentStartStreamMessage` | `id`, `description`. |
| `.subagentComplete` | `SubagentCompleteStreamMessage` | `id`, `summary`. |
| `.inputQueued` | `QueuedMessage` | `position`. |
| `.queueCleared` | `QueueClearedMessage` | No extra fields. |
| `.connectionReplaced` | `CursorEvictedMessage` | Treat as replacement/eviction event. `lastMessageId`, `recommendation`. |
| `.reconnectComplete` | `ReconnectCompleteMessage` | `missedCount`, `fromMessageId`. |
| `.cursorEvicted` | `CursorEvictedMessage` | `lastMessageId`, `recommendation: "fetch_from_rest"`. |
| `.cursorInvalid` | `CursorInvalidMessage` | `lastMessageId`, `recommendation: "full_resync"`. |
| `.error` | `ErrorMessage` | `code`, `message`, `recoverable`, `retryable?`, `retryAfter?`. |
| `.modelChanged` | `ModelChangedMessage` | `model`, `previousModel`. |
| `.permissionModeChanged` | `PermissionModeChangedMessage` | `mode`. |
| `.stopped` | `StoppedMessage` | `reason`: `user`, `complete`, `error`, `timeout`. |
| `.interrupted` | `InterruptedMessage` | No extra fields. |
| `.serverPing` | `ServerPingMessage` | Wire type is `ping`. Has `serverTime`. |
| `.pong` | `PongMessage` | `serverTime`. |
| `.reconnecting` | Client-local | Emitted by reconnect logic, not a wire payload. |
| `.connectionError` | Client-local | Derived from WebSocket failure state. |
| `.networkStatusChanged` | Client-local | Derived from reachability. |
