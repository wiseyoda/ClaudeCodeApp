# Dependency Injection


### Testable Architecture

```swift
// Protocol for testing
protocol StatusTracking: Actor {
    func status(for toolUseId: String) async -> StatusBannerState
    func updateProgress(toolUseId: String, info: ProgressInfo) async
    func startSubagent(toolUseId: String, info: SubagentInfo) async
    func complete(toolUseId: String) async
    func clearAll() async
}

// Production implementation
actor CardStatusTracker: StatusTracking { /* ... */ }

// Test implementation
actor MockStatusTracker: StatusTracking {
    var statuses: [String: StatusBannerState] = [:]

    func status(for toolUseId: String) async -> StatusBannerState {
        statuses[toolUseId] ?? .none
    }

    func updateProgress(toolUseId: String, info: ProgressInfo) async {
        statuses[toolUseId] = .inProgress(info)
    }

    func startSubagent(toolUseId: String, info: SubagentInfo) async {
        statuses[toolUseId] = .subagent(info)
    }

    func complete(toolUseId: String) async {
        statuses[toolUseId] = .completed
    }

    func clearAll() async {
        statuses.removeAll()
    }
}
```

### View Dependencies

```swift
struct ChatView: View {
    let interactionHandler: StreamInteractionHandler
    let statusTracker: any StatusTracking
    let scrollState: MessageScrollState

    // Inject via init for testability
    init(
        interactionHandler: StreamInteractionHandler,
        statusTracker: any StatusTracking = CardStatusTracker(),
        scrollState: MessageScrollState = MessageScrollState()
    ) {
        self.interactionHandler = interactionHandler
        self.statusTracker = statusTracker
        self.scrollState = scrollState
    }
}
```

---
