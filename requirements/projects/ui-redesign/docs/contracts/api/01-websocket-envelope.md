# WebSocket Envelope


Server emits `ServerMessage` (union). Two primary shapes:

- `StreamServerMessage`: `{ type: "stream", id: UUID, timestamp: ISO-8601, message: StreamMessage }`
- Control messages: `connected`, `history`, `session_event`, `queued`, `queue_cleared`, `reconnect_complete`,
  `cursor_evicted`, `cursor_invalid`, `error`, `model_changed`, `permission_mode_changed`, `stopped`, `ping`, `pong`, `interrupted`
