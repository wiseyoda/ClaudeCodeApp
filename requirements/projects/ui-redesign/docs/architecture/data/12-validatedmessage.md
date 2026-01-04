# ValidatedMessage


Wrapper around ChatMessage that guarantees:
- Role is valid enum case
- Timestamp is valid Date
- Content is sanitized (no AnyCodable wrappers)
- Tool metadata preserved (IDs, input description, output)

```swift
struct ValidatedMessage: Sendable, Equatable {
    let id: String
    let role: ChatMessage.Role
    let content: String
    let timestamp: Date
    let isStreaming: Bool
    let toolName: String?
    let toolUseId: String?
    let toolResultId: String?
    let toolInputDescription: String?
    let toolOutput: String?
    let tokenCount: Int?
    let executionTime: TimeInterval?
    let imagePath: String?
    let imageData: Data?
    let warnings: [MessageValidationError]

    func toChatMessage() -> ChatMessage {
        let uuid = UUID(uuidString: id) ?? UUID()
        ChatMessage(
            id: uuid,
            role: role,
            content: content,
            timestamp: timestamp,
            isStreaming: isStreaming,
            imageData: imageData,
            imagePath: imagePath,
            executionTime: executionTime,
            tokenCount: tokenCount
        )
    }
}
```

---
