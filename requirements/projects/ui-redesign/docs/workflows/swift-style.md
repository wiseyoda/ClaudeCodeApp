# Swift Style Guide

## Formatting

- Indentation: 4 spaces (Xcode default).
- Line length: 100 soft limit, 120 hard limit.
- Trailing commas required in multiline literals.
- One blank line between methods; two between types.

```swift
let items = [
    "first",
    "second",
    "third",
]

func load() async {
    // ...
}

func refresh() async {
    // ...
}
```

## SwiftUI Conventions

- Use @State for view-owned @Observable instances.
- Use @Bindable for two-way bindings into @Observable types.
- Use @Environment(Type.self) for dependency injection of @Observable.
- Prefer value-based NavigationLink + .navigationDestination(for:).

```swift
struct ChatView: View {
    @Environment(SessionStore.self) var store
    @State private var scrollState = MessageScrollState()

    var body: some View {
        MessageListView(scrollState: scrollState)
    }
}
```

## Concurrency

- Use actors for shared mutable state.
- Mark cross-actor models as Sendable.
- Use Task { @MainActor in } for UI updates from async contexts.
- Avoid nonisolated(unsafe).

```swift
actor StatusTracker {
    private var statuses: [String: StatusBannerState] = [:]

    func status(for id: String) -> StatusBannerState {
        statuses[id] ?? .none
    }
}
```

## Error Handling

- Use AppError for user-facing errors and recovery options.
- Convert system errors at boundaries (network, storage, parsing).
- Log with structured context and correlation IDs.

## Comments and Documentation

- Prefer DocC comments for public and shared API.
- Keep inline comments for non-obvious logic only.
- Avoid redundant comments that restate code.

## File Organization

- One primary type per file; extensions in Type+Feature.swift.
- Group by feature under CodingBridge/Features/ or existing module folders.
- New files must be added to CodingBridge.xcodeproj.
