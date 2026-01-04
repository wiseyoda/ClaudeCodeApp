# Error Handling & Recovery


### Error Type Hierarchy

Define a shared error model for consistent handling:

```swift
enum AppError: Error, Equatable {
    case network(NetworkError)
    case websocket(WebSocketError)
    case validation(MessageValidationError)
    case persistence(PersistenceError)
    case ssh(SSHError)
    case permissions(PermissionError)
    case liveActivity(ActivityError)
}

struct UserFacingError: Equatable {
    let title: String
    let message: String
    let recoverySuggestion: String?
    let isBlocking: Bool
}
```

### User-Facing Messaging

- Map `AppError` to `UserFacingError` before presenting UI.
- Use banners for transient errors, sheets for blocking errors.
- Keep messages action-oriented (what happened, what to do next).

### Recovery & Retry

- WebSocket: exponential backoff reconnect with jitter.
- REST: retry only idempotent requests (GET/HEAD); avoid double writes.
- Offline mode: show read-only state, queue safe retries, and surface status.

### Logging & Analytics

- Use `Logger` with privacy annotations (`.private` where needed).
- Include correlation IDs (sessionId, toolUseId) for tracing.
- Never log secrets or full file contents.

---
