# WebSocket Patterns

## Connection State

The app uses `ConnectionState` enum: `.disconnected`, `.connecting`, `.connected`, `.reconnecting`

## Message Flow

```
Send: WSClaudeCommand → WebSocket → Backend
Receive: Backend → WSMessage → Callbacks (onText, onToolUse, onComplete, etc.)
```

## Reconnection

- Exponential backoff: 1s → 2s → 4s → 8s max
- Random jitter added to prevent thundering herd
- 30-second processing timeout with auto-reset

## Known Race Conditions

**State Race (lines 196-230):**
- Connection state set before receive loop starts
- Can cause sends to fail silently

**Send Race (lines 283-295, 344-361):**
- Multiple sends can interleave
- Need proper queuing

**Fix Pattern:**
```swift
// Use actor for thread-safe state
actor WebSocketState {
    private var connection: WebSocketTask?

    func send(_ message: Data) async throws {
        guard let conn = connection else { throw Error.notConnected }
        try await conn.send(.data(message))
    }
}
```
