# Swift 6 Concurrency Model


### Actor Isolation

Use actors for shared mutable state that requires thread safety:

```swift
/// Thread-safe tracker for tool status banners
actor CardStatusTracker {
    private var activeStatuses: [String: StatusBannerState] = [:]

    func status(for toolUseId: String) async -> StatusBannerState {
        activeStatuses[toolUseId] ?? .none
    }

    func updateProgress(toolUseId: String, info: ProgressInfo) async {
        activeStatuses[toolUseId] = .inProgress(info)
    }

    func startSubagent(toolUseId: String, info: SubagentInfo) async {
        activeStatuses[toolUseId] = .subagent(info)
    }

    func complete(toolUseId: String) async {
        activeStatuses[toolUseId] = .completed
        // Auto-remove after delay
        Task {
            try? await Task.sleep(for: .seconds(1))
            activeStatuses.removeValue(forKey: toolUseId)
        }
    }

    func clearAll() async {
        activeStatuses.removeAll()
    }
}
```

### @MainActor for UI State

Use `@MainActor` for state that drives UI updates:

```swift
@MainActor @Observable
final class StreamInteractionHandler {
    private(set) var pendingInteractions: [InteractionType] = []

    var currentInteraction: InteractionType? {
        pendingInteractions.sorted { $0.priority < $1.priority }.first
    }

    func enqueue(_ interaction: InteractionType) {
        pendingInteractions.append(interaction)
    }

    func complete(_ interaction: InteractionType) {
        pendingInteractions.removeAll { $0.id == interaction.id }
    }

    func clearAll() {
        pendingInteractions.removeAll()
    }
}
```

### @Observable Pattern

Replace all `ObservableObject` with `@Observable`:

```swift
// BEFORE (iOS 16 pattern)
class MessageScrollState: ObservableObject {
    @Published var position: ScrollPosition = .init(idType: String.self)
    @Published var isAtBottom = true
    @Published var unreadCount = 0
}

// AFTER (iOS 26 pattern)
@Observable
final class MessageScrollState {
    var position: ScrollPosition = .init(idType: String.self)
    var isAtBottom = true
    var unreadCount = 0

    func scrollToBottom() {
        position.scrollTo(edge: .bottom)
    }

    func scrollTo(messageId: String) {
        position.scrollTo(id: messageId, anchor: .center)
    }
}
```

### @Bindable in Views

Use `@Bindable` for two-way binding with `@Observable` objects:

```swift
struct MessageListView: View {
    @Bindable var scrollState: MessageScrollState
    let messages: [ChatMessage]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: MessageDesignSystem.Spacing.cardGap) {
                ForEach(messages) { message in
                    MessageCardRouter(message: message)
                        .id(message.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition($scrollState.position)
        .defaultScrollAnchor(.bottom)
    }
}
```

---
