# Core UI Models


### ChatMessage (UI)

```
struct ChatMessage: Identifiable, Equatable, Codable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date
    var isStreaming: Bool
    var imageData: Data?
    var imagePath: String?
    var executionTime: TimeInterval?
    var tokenCount: Int?

    enum Role: String, Codable {
        case user
        case assistant
        case system
        case error
        case toolUse
        case toolResult
        case resultSuccess
        case thinking
        case localCommand
        case localCommandStdout
    }
}
```

Notes:
- `id` must remain stable across streaming updates.
- `imageData` is for newly attached images; `imagePath` for persisted images.

### ValidatedMessage (Normalization Layer)

```
struct ValidatedMessage: Identifiable, Sendable {
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
}
```

Validation rules:
- `role` must be a known `ChatMessage.Role` (no silent fallback).
- `timestamp` must parse ISO8601; if invalid, record a warning.
- `content` must be sanitized (no AnyCodable wrappers).
- `toolUseId` and `toolResultId` must be preserved for correlation.

```
enum MessageValidationError: Error, Equatable {
    case invalidRole(String)
    case invalidTimestamp(String)
    case malformedJSON(String)
    case corruptedContent(String)
}
```

### Project / Session

```
struct Project: Codable, Identifiable, Hashable {
    let name: String
    let path: String
    let displayName: String?
    let fullPath: String?
    let sessions: [ProjectSession]?
    let sessionMeta: ProjectSessionMeta?
}

struct ProjectSession: Codable, Identifiable {
    let id: String
    let projectPath: String?
    let summary: String?
    let messageCount: Int?
    let lastActivity: String?
    let lastUserMessage: String?
    let lastAssistantMessage: String?
    let archivedAt: String?
}

struct ProjectSessionMeta: Codable, Hashable {
    let hasMore: Bool
    let total: Int
}
```

### Permission Approval (Wire + UI)

Wire payloads (source of truth: `CodingBridge/Generated/*.swift`):

```
struct PermissionRequestMessage: Sendable, Codable, Identifiable {
    let type: "permission"
    let id: String
    let tool: String
    let input: [String: JSONValue]
    let options: [PermissionChoice]
}

enum PermissionChoice: String, Codable {
    case allow
    case deny
    case always
}

struct PermissionResponseMessage: Sendable, Encodable {
    let type: "permission_response"
    let id: String
    let choice: PermissionChoice
}
```

UI wrapper derived from the wire payload:

```
struct ApprovalRequest: Identifiable, Equatable {
    let id: String
    let tool: String
    let input: [String: JSONValue]
    let receivedAt: Date
}
```

### AskUserQuestion

```
struct QuestionOption: Identifiable {
    let id: UUID
    let label: String
    let description: String?
}

struct UserQuestion: Identifiable {
    let id: UUID
    let question: String
    let header: String?
    let options: [QuestionOption]
    let multiSelect: Bool
    var selectedOptions: Set<String>
    var customAnswer: String
}

struct AskUserQuestionData: Identifiable {
    let id: UUID
    let requestId: String
    var questions: [UserQuestion]
}
```

---
