# Card Status Banners


### Status States

```swift
enum StatusBannerState: Equatable {
    case none
    case inProgress(ProgressInfo)
    case subagent(SubagentInfo)
    case queued(position: Int)
    case completed
    case error(String)
}

struct ProgressInfo: Equatable {
    let toolName: String
    let detail: String?
    let progress: Double?  // 0-1, nil = indeterminate
    let startTime: Date
}

struct SubagentInfo: Equatable {
    let id: String
    let displayName: String
    let description: String
    let startTime: Date
}
```

### Event Flow

```swift
// In ChatViewModel+StreamEvents
func handleStreamEvent(_ event: StreamEvent) async {
    switch event {
    case .progress(let msg):
        let startTime = Date().addingTimeInterval(-msg.elapsed)
        await cardStatusTracker.updateProgress(
            toolUseId: msg.id,
            info: ProgressInfo(
                toolName: msg.tool,
                detail: msg.detail,
                progress: msg.progress.map { $0 / 100 },
                startTime: startTime
            )
        )

    case .subagentStart(let msg):
        await cardStatusTracker.startSubagent(
            toolUseId: msg.id,
            info: SubagentInfo(
                id: msg.id,
                displayName: msg.displayAgentType,
                description: msg.description,
                startTime: .now
            )
        )

    case .subagentComplete(let msg):
        await cardStatusTracker.complete(toolUseId: msg.id)  // BUG FIX

    case .toolResult(let msg):
        await cardStatusTracker.complete(toolUseId: msg.toolUseId)

    case .result(let msg):
        await cardStatusTracker.clearAll()  // Final cleanup
    }
}
```

---
