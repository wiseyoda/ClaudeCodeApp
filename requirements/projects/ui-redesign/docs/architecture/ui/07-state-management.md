# State Management


### App-Level State (@Observable)

```swift
@MainActor @Observable
final class AppState {
    // Navigation
    var selectedProject: Project?
    var navigationPath = NavigationPath()
    var columnVisibility: NavigationSplitViewVisibility = .automatic
    var activeSheet: ActiveSheet?

    // Global UI state
    var isConnected = false
    var showingKeyboardShortcuts = false
}
```

### Feature-Level State (@Observable)

Each feature has its own @Observable view model:

```swift
@MainActor @Observable
final class ChatViewModel {
    let project: Project
    var messages: [ChatMessage] = []
    var inputText = ""
    var isProcessing = false
    // ...
}
```

### Shared State (Actors)

Thread-safe shared state uses actors:

```swift
actor CardStatusTracker {
    private var statuses: [String: StatusBannerState] = [:]
    // ...
}

actor SubagentContextTracker {
    private var contexts: [String: SubagentContext] = [:]
    // ...
}
```

---
