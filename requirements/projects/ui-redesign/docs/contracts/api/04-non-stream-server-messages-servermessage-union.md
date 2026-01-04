# Non-Stream Server Messages (ServerMessage union)


| type | Model | Key fields |
|---|---|---|
| `connected` | `ConnectedMessage` | `agentId`, `sessionId`, `model`, `modelAlias?`, `version`, `protocolVersion` |
| `history` | `HistoryMessage` | `messages`, `hasMore`, `cursor?` |
| `session_event` | `SessionEventMessage` | `action`, `projectPath`, `sessionId`, `metadata?` (see SessionMetadata) |
| `queued` | `QueuedMessage` | `position` |
| `queue_cleared` | `QueueClearedMessage` | No extra fields |
| `reconnect_complete` | `ReconnectCompleteMessage` | `missedCount`, `fromMessageId` |
| `cursor_evicted` | `CursorEvictedMessage` | `lastMessageId`, `recommendation: "fetch_from_rest"` |
| `cursor_invalid` | `CursorInvalidMessage` | `lastMessageId`, `recommendation: "full_resync"` |
| `error` | `ErrorMessage` | `code`, `message`, `recoverable`, `retryable?`, `retryAfter?` |
| `model_changed` | `ModelChangedMessage` | `model`, `previousModel` |
| `permission_mode_changed` | `PermissionModeChangedMessage` | `mode` |
| `stopped` | `StoppedMessage` | `reason` |
| `pong` | `PongMessage` | `serverTime` |
| `ping` | `ServerPingMessage` | `serverTime` (server-initiated ping) |
| `interrupted` | `InterruptedMessage` | No extra fields |

### Permission Mode Values

The `mode` field in `PermissionModeChangedMessage` can be:
- `default` - Normal permission prompts
- `acceptEdits` - Auto-accept edit operations
- `bypassPermissions` - Skip all permission prompts

### Stopped Reason Values

The `reason` field in `StoppedMessage` can be:
- `user` - User requested stop
- `complete` - Task completed normally
- `error` - Stopped due to error
- `timeout` - Stopped due to timeout

### Session Event Action Values

The `action` field in `SessionEventMessage` can be:
- `created` - New session was created
- `updated` - Session was modified (new messages, title change, etc.)
- `deleted` - Session was deleted

### SessionMetadata Fields

The `metadata` object in `SessionEventMessage` contains:

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | UUID | Yes | Session UUID |
| `projectPath` | string | Yes | Absolute project path |
| `source` | enum | Yes | `user`, `agent`, or `helper` |
| `createdAt` | ISO-8601 | No | When session was created |
| `lastActivityAt` | ISO-8601 | Yes | Last message timestamp |
| `messageCount` | int | Yes | Number of messages |
| `title` | string | No | First user message or AI-generated title |
| `summary` | string | No | AI-generated summary of the session |
| `customTitle` | string | No | User-assigned custom title (overrides title) |
| `model` | string | No | Claude model used |
| `archivedAt` | ISO-8601 | No | When archived (soft delete) |
| `parentSessionId` | UUID | No | Parent session for lineage tracking |

### Error Codes

The `code` field in `ErrorMessage` uses these values:

| Code | Recoverable | Description |
|---|---|---|
| `NO_AGENT` | No | No active agent - send `start` first |
| `AGENT_NOT_FOUND` | No | Agent no longer exists - start new session |
| `AGENT_CREATE_FAILED` | No | Failed to create agent |
| `MAX_AGENTS_REACHED` | Yes | Maximum concurrent agents reached |
| `CONNECTION_REPLACED` | Yes | Another client connected to this agent |
| `RATE_LIMITED` | Yes | Too many requests - has `retryAfter` |
| `INVALID_MESSAGE` | No | JSON parse failed or schema validation failed |
| `UNKNOWN_MESSAGE_TYPE` | No | Unrecognized message type |
| `INPUT_FAILED` | No | Failed to process input |
| `QUEUE_FULL` | Yes | Input queue is full - has `retryable: true` |
| `TIMEOUT` | Yes | Operation timed out - has `retryable: true` |
| `NO_FAILED_MESSAGE` | No | No failed message to retry |
| `MESSAGE_ID_MISMATCH` | No | Retry message ID doesn't match last failed |
| `RETRY_EXPIRED` | No | Failed message is too old to retry (>5 min) |
| `RETRY_FAILED` | No | Retry attempt failed |
| `INVALID_PERMISSION_ID` | No | No pending permission with that ID |
| `INVALID_QUESTION_ID` | No | No pending question with that ID |

### Error Message Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `type` | `"error"` | Yes | Message type |
| `code` | string | Yes | Error code (see table above) |
| `message` | string | Yes | Human-readable description |
| `recoverable` | boolean | Yes | Whether client can continue |
| `retryable` | boolean | No | Whether operation can be retried |
| `retryAfter` | number | No | Seconds to wait before retry |
