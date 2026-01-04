# Data Flow (Messages)


```
Data Sources                    Normalization                   View Layer
─────────────────────────────────────────────────────────────────────────────
PaginatedMessage ──────┐
(REST API)             │
                       ├──→ MessageNormalizer ──→ Result<ValidatedMessage, MessageValidationError>
StreamEvent ───────────┘
(WebSocket)                   ├─ validateRole()
                              ├─ validateContent()
                              ├─ validateTimestamp()
                              └─ handleCorruption()
```

### Result-Based Error Handling

Use `Result` type for operations that can fail:

```swift
enum MessageValidationError: Error, Equatable {
    case invalidRole(String)
    case invalidTimestamp(String)
    case malformedJSON(String)
    case corruptedContent(String)
}

protocol MessageNormalizing {
    func normalize(_ paginated: PaginatedMessage) -> Result<ValidatedMessage, MessageValidationError>
    func normalize(_ streamEvent: StreamEvent) -> Result<ValidatedMessage, MessageValidationError>?
}

struct MessageNormalizer: MessageNormalizing {
    func normalize(_ paginated: PaginatedMessage) -> Result<ValidatedMessage, MessageValidationError> {
        // Validate role
        guard let role = ChatMessage.Role(rawValue: paginated.role) else {
            return .failure(.invalidRole(paginated.role))
        }

        // Validate timestamp
        guard let timestamp = parseTimestamp(paginated.timestamp) else {
            return .failure(.invalidTimestamp(paginated.timestamp))
        }

        // Return validated message
        return .success(ValidatedMessage(
            id: paginated.id,
            role: role,
            content: sanitizeContent(paginated.content),
            timestamp: timestamp,
            isStreaming: false,
            toolName: nil,
            toolUseId: nil,
            toolResultId: nil,
            toolInputDescription: nil,
            toolOutput: nil,
            tokenCount: nil,
            executionTime: nil,
            imagePath: nil,
            imageData: nil,
            warnings: []
        ))
    }
}
```

### Consuming Results

```swift
// In ChatViewModel
func processMessage(_ paginated: PaginatedMessage) {
    switch normalizer.normalize(paginated) {
    case .success(let validated):
        messages.append(validated.toChatMessage())
    case .failure(let error):
        Logger.warning("Message validation failed: \(error)")
        // Handle gracefully - don't crash
    }
}
```

---
