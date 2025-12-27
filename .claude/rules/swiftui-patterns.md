# SwiftUI Patterns

## State Management

```swift
// View owns manager - use @StateObject
@StateObject private var manager = SomeManager()

// Shared from parent - use @EnvironmentObject
@EnvironmentObject var settings: AppSettings

// Singleton stores - use @ObservedObject
@ObservedObject var commands = CommandStore.shared
```

## Adding New Views

1. Create file in `Views/` directory
2. Follow naming: `{Feature}View.swift` or `{Feature}Sheet.swift`
3. Accept dependencies via init or environment
4. Use `CLITheme` for consistent styling

## Adding New Managers

1. Create `@MainActor class` that conforms to `ObservableObject`
2. Use `@Published` for observable state
3. Add `deinit` to clean up resources (timers, observers, audio sessions)
4. Create as `@StateObject` in owning view

## Common Mistakes to Avoid

```swift
// WRONG: Creating manager in body
var body: some View {
    let manager = Manager() // Recreated every render!
}

// WRONG: Missing MainActor
class Manager: ObservableObject { // Race conditions!
    @Published var state = ""
}

// WRONG: Force unwrap
let value = optional! // Crash waiting to happen
```
