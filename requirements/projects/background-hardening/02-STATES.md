# Task States

## State Definitions

| State | Description | User Action | UI Color |
|-------|-------------|-------------|----------|
| **Idle** | No active task | None | Gray |
| **Processing** | Claude actively working | None (monitoring) | Blue |
| **Awaiting Approval** | Claude needs permission | Approve or Deny | Orange |
| **Awaiting Answer** | Claude asked a question | Respond in app | Purple |
| **Complete** | Task finished successfully | None | Green |
| **Error** | Task failed or connection lost | Review in app | Red |

## State Machine

```
                        ┌─────────────┐
                        │    Idle     │
                        └──────┬──────┘
                               │ User sends message
                               ▼
                        ┌─────────────┐
               ┌───────▶│ Processing  │◀───────┐
               │        └──────┬──────┘        │
               │               │               │
     Approval  │       ┌───────┴───────┐       │ User answers
     granted   │       │               │       │ question
               │       ▼               ▼       │
        ┌──────┴──────┐         ┌──────┴──────┐
        │  Awaiting   │         │  Awaiting   │
        │  Approval   │         │   Answer    │
        └──────┬──────┘         └──────┬──────┘
               │                       │
               │ Approval denied       │ User cancels
               │       │               │
               │       ▼               ▼
               │    ┌─────────────────────┐
               └───▶│      Complete       │◀──── Task finishes
                    │  (success/failure)  │
                    └──────────┬──────────┘
                               │
                               │ New task
                               ▼
                        ┌─────────────┐
                        │    Idle     │
                        └─────────────┘
```

## TaskState Model

```swift
enum TaskStatus: Codable {
    case idle
    case processing(operation: String?)
    case awaitingApproval(request: ApprovalRequest)
    case awaitingAnswer(question: UserQuestion)
    case completed(result: TaskResult)
    case error(message: String)
}

struct TaskState: Codable {
    let sessionId: String
    let projectPath: String
    let status: TaskStatus
    let startTime: Date
    let lastUpdateTime: Date
    let elapsedSeconds: Int
    let todoProgress: TodoProgress?
}
```

## Supporting Types

```swift
struct TodoProgress: Codable {
    let completed: Int
    let total: Int
    let currentTask: String?

    var progressText: String { "\(completed) of \(total)" }
    var progressFraction: Double { Double(completed) / Double(max(total, 1)) }
}

struct ApprovalRequest: Codable {
    let id: String
    let toolName: String
    let summary: String
    let details: String?
    let expiresAt: Date?  // 60-second timeout
}

struct UserQuestion: Codable {
    let id: String
    let question: String
    let options: [String]?
}

enum TaskResult: Codable {
    case success(summary: String?)
    case failure(error: String)
    case cancelled
}
```

## Location

`CodingBridge/Models/TaskState.swift`

---
**Prev:** [Goals](./01-GOALS.md) | **Next:** [Architecture](./03-ARCHITECTURE.md) | **Index:** [00-INDEX.md](./00-INDEX.md)
