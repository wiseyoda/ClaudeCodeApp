# Activity Attributes

> Shared ActivityAttributes struct for Live Activities.

## Location

Shared framework target so both main app and widget extension can use:

`CodingBridgeShared/CodingBridgeActivityAttributes.swift`

## Implementation

```swift
import ActivityKit
import SwiftUI

public struct CodingBridgeActivityAttributes: ActivityAttributes {
    // Static content (doesn't change during activity lifetime)
    public var projectName: String
    public var projectPath: String
    public var sessionId: String

    public init(projectName: String, projectPath: String, sessionId: String) {
        self.projectName = projectName
        self.projectPath = projectPath
        self.sessionId = sessionId
    }

    // Dynamic content (changes via updates)
    public struct ContentState: Codable, Hashable {
        public var status: ActivityStatus
        public var currentOperation: String?
        public var elapsedSeconds: Int
        public var todoProgress: TodoProgress?
        public var approvalRequest: ApprovalInfo?

        public init(
            status: ActivityStatus,
            currentOperation: String? = nil,
            elapsedSeconds: Int = 0,
            todoProgress: TodoProgress? = nil,
            approvalRequest: ApprovalInfo? = nil
        ) {
            self.status = status
            self.currentOperation = currentOperation
            self.elapsedSeconds = elapsedSeconds
            self.todoProgress = todoProgress
            self.approvalRequest = approvalRequest
        }
    }
}

// MARK: - Supporting Types

public enum ActivityStatus: String, Codable, Hashable {
    case processing
    case awaitingApproval
    case awaitingAnswer
    case completed
    case error
}

public struct TodoProgress: Codable, Hashable {
    public let completed: Int
    public let total: Int
    public let currentTask: String?

    public init(completed: Int, total: Int, currentTask: String? = nil) {
        self.completed = completed
        self.total = total
        self.currentTask = currentTask
    }

    public var progressText: String { "\(completed) of \(total)" }
    public var progressFraction: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
}

public struct ApprovalInfo: Codable, Hashable {
    public let requestId: String
    public let toolName: String
    public let summary: String
    public let expiresAt: Date?

    public init(requestId: String, toolName: String, summary: String, expiresAt: Date? = nil) {
        self.requestId = requestId
        self.toolName = toolName
        self.summary = summary
        self.expiresAt = expiresAt
    }

    public var remainingSeconds: Int? {
        guard let expiresAt = expiresAt else { return nil }
        return max(0, Int(expiresAt.timeIntervalSinceNow))
    }
}
```

## Notes

- `ActivityAttributes` defines what's static vs dynamic
- Static: project name, path, session ID (set at start)
- Dynamic: status, operation, elapsed time, progress, approval (updated frequently)
- All types must be `Codable` and `Hashable`

---
**Next:** [live-activity-manager](./live-activity-manager.md) | **Index:** [../00-INDEX.md](../00-INDEX.md)
