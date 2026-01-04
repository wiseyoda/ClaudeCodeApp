# Issue 62: Migration Helpers

**Phase:** 0 (Foundation)
**Priority:** Low
**Status:** Not Started
**Depends On:** 10 (@Observable Migration)
**Target:** iOS 26.2, Xcode 26.2, Swift 6.2.1

## Goal

Document refactor recipes and provide migration checklists for transitioning from `@ObservableObject` to `@Observable`, from legacy navigation to `NavigationSplitView`, and from UIKit patterns to SwiftUI iOS 26 APIs.

## Scope

- In scope:
  - @Observable migration recipes
  - Navigation migration patterns
  - View property wrapper migration
  - Persistence migration helpers
  - Common pitfall documentation
- Out of scope:
  - Automated migration tooling
  - Full codemod scripts
  - Third-party migration tools

## Non-goals

- Automatic code transformation (manual review required)
- Backwards compatibility layers

## Dependencies

- Issue #10 (@Observable Migration) for patterns and examples

## Touch Set

- Files to create:
  - `requirements/projects/ui-redesign/docs/workflows/migration-guide.md`
- Files to modify:
  - None (documentation only)

---

## Migration Recipes

### 1. @ObservableObject → @Observable

#### Basic Class Migration

```swift
// BEFORE
class SessionStore: ObservableObject {
    @Published var sessions: [Session] = []
    @Published var isLoading = false

    func load() async {
        isLoading = true
        sessions = await fetchSessions()
        isLoading = false
    }
}

// AFTER
@Observable
final class SessionStore {
    var sessions: [Session] = []
    var isLoading = false

    func load() async {
        isLoading = true
        sessions = await fetchSessions()
        isLoading = false
    }
}
```

#### Migration Checklist

- [ ] Change `class Name: ObservableObject` to `@Observable final class Name`
- [ ] Remove all `@Published` property wrappers
- [ ] Remove `import Combine` if no longer needed
- [ ] Add `@ObservationIgnored` for non-observed dependencies
- [ ] Update all view usages (see View Migration below)
- [ ] Remove any `objectWillChange.send()` calls
- [ ] Verify build and tests pass

#### @ObservationIgnored for Dependencies

```swift
// BEFORE
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    private let repository: MessageRepository

    init(repository: MessageRepository = .shared) {
        self.repository = repository
    }
}

// AFTER
@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []

    @ObservationIgnored
    private let repository: MessageRepository

    init(repository: MessageRepository = .shared) {
        self.repository = repository
    }
}
```

---

### 2. View Property Wrapper Migration

#### @StateObject → @State

```swift
// BEFORE
struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()

    var body: some View {
        // ...
    }
}

// AFTER
struct ChatView: View {
    @State private var viewModel = ChatViewModel()

    var body: some View {
        // ...
    }
}
```

#### @ObservedObject → Direct Reference or @Bindable

```swift
// BEFORE: Read-only access
struct MessageList: View {
    @ObservedObject var store: MessageStore

    var body: some View {
        ForEach(store.messages) { message in
            MessageRow(message: message)
        }
    }
}

// AFTER: Direct reference (no wrapper needed)
struct MessageList: View {
    var store: MessageStore

    var body: some View {
        ForEach(store.messages) { message in
            MessageRow(message: message)
        }
    }
}

// BEFORE: Two-way binding
struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        TextField("Name", text: $settings.name)
    }
}

// AFTER: @Bindable for bindings
struct SettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        TextField("Name", text: $settings.name)
    }
}
```

#### @EnvironmentObject → @Environment

```swift
// BEFORE
struct ChatView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Text(settings.userName)
    }
}

// App root
ContentView()
    .environmentObject(settings)

// AFTER
struct ChatView: View {
    @Environment(AppSettings.self) var settings

    var body: some View {
        Text(settings.userName)
    }
}

// App root
ContentView()
    .environment(settings)
```

#### View Migration Checklist

- [ ] Replace `@StateObject` with `@State`
- [ ] Replace `@ObservedObject` (read-only) with direct property
- [ ] Replace `@ObservedObject` (with bindings) with `@Bindable`
- [ ] Replace `@EnvironmentObject` with `@Environment(Type.self)`
- [ ] Update `.environmentObject()` to `.environment()`
- [ ] Verify all bindings still work
- [ ] Test view updates correctly when state changes

---

### 3. @MainActor Class → Actor

For shared state that doesn't directly drive UI:

```swift
// BEFORE
@MainActor
class CardStatusTracker: ObservableObject {
    @Published var statuses: [String: Status] = [:]

    func update(_ id: String, status: Status) {
        statuses[id] = status
    }

    func get(_ id: String) -> Status {
        statuses[id] ?? .none
    }
}

// AFTER
actor CardStatusTracker {
    private var statuses: [String: Status] = [:]

    func update(_ id: String, status: Status) {
        statuses[id] = status
    }

    func get(_ id: String) -> Status {
        statuses[id] ?? .none
    }
}

// View usage (must await)
struct ToolCardView: View {
    let statusTracker: CardStatusTracker
    @State private var status: Status = .none

    var body: some View {
        StatusBadge(status: status)
            .task {
                status = await statusTracker.get(toolId)
            }
    }
}
```

#### Actor Migration Checklist

- [ ] Change `@MainActor class` to `actor`
- [ ] Remove `@Published` (actors can't be observed directly)
- [ ] Add explicit getter methods
- [ ] Update all call sites to use `await`
- [ ] Add `@State` in views to cache actor values
- [ ] Use `.task` to load actor values
- [ ] Consider `@MainActor @Observable` if direct UI binding is needed

---

### 4. Persistence Migration

When migrating from `@AppStorage` to `@Observable`:

```swift
// BEFORE
class AppSettings: ObservableObject {
    @AppStorage("serverURL") var serverURL = "http://localhost:3100"
    @AppStorage("fontSize") var fontSize = 14.0
}

// AFTER
@Observable
final class AppSettings {
    @ObservationIgnored
    private let defaults = UserDefaults.standard

    @ObservationIgnored
    private let migrationVersion = 1

    var serverURL: String = "" {
        didSet { save("serverURL", serverURL) }
    }

    var fontSize: Double = 14.0 {
        didSet { save("fontSize", fontSize) }
    }

    init() {
        migrateIfNeeded()
        load()
    }

    private func load() {
        serverURL = defaults.string(forKey: "serverURL") ?? "http://localhost:3100"
        fontSize = defaults.double(forKey: "fontSize").nonZero ?? 14.0
    }

    private func save<T>(_ key: String, _ value: T) {
        defaults.set(value, forKey: key)
    }

    private func migrateIfNeeded() {
        let version = defaults.integer(forKey: "settingsMigrationVersion")
        guard version < migrationVersion else { return }

        // Migration logic here
        // Example: rename old keys
        if let oldValue = defaults.string(forKey: "api_server_url") {
            defaults.set(oldValue, forKey: "serverURL")
            defaults.removeObject(forKey: "api_server_url")
        }

        defaults.set(migrationVersion, forKey: "settingsMigrationVersion")
    }
}

private extension Double {
    var nonZero: Double? {
        self == 0 ? nil : self
    }
}
```

#### Persistence Migration Checklist

- [ ] Replace `@AppStorage` with manual UserDefaults access
- [ ] Add `didSet` observers to save on change
- [ ] Add migration version tracking
- [ ] Document old → new key mappings
- [ ] Test fresh install (no migration needed)
- [ ] Test upgrade from old version (migration runs)
- [ ] Verify no data loss

---

### 5. Navigation Migration

#### NavigationView → NavigationSplitView

```swift
// BEFORE
struct ContentView: View {
    @State private var selectedProject: Project?

    var body: some View {
        NavigationView {
            List(projects) { project in
                NavigationLink(destination: ChatView(project: project)) {
                    ProjectRow(project: project)
                }
            }
        }
    }
}

// AFTER
struct ContentView: View {
    @State private var selectedProject: Project?

    var body: some View {
        NavigationSplitView {
            List(projects, selection: $selectedProject) { project in
                NavigationLink(value: project) {
                    ProjectRow(project: project)
                }
            }
            .navigationDestination(for: Project.self) { project in
                ChatView(project: project)
            }
        } detail: {
            if let project = selectedProject {
                ChatView(project: project)
            } else {
                Text("Select a project")
            }
        }
    }
}
```

#### Navigation Migration Checklist

- [ ] Replace `NavigationView` with `NavigationSplitView`
- [ ] Replace destination-based `NavigationLink` with value-based
- [ ] Add `.navigationDestination(for:)` modifiers
- [ ] Add selection binding for list
- [ ] Add detail view placeholder
- [ ] Test iPhone (collapsed mode)
- [ ] Test iPad (sidebar + detail)
- [ ] Test Stage Manager resizing

---

### 6. UIKit Patterns → SwiftUI iOS 26

#### UIImpactFeedbackGenerator → .sensoryFeedback

```swift
// BEFORE
Button("Send") {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    send()
}

// AFTER
Button("Send") {
    send()
}
.sensoryFeedback(.impact(weight: .medium), trigger: sendCount)
```

#### Material → Liquid Glass

```swift
// BEFORE
.background(.ultraThinMaterial)
.background(.regularMaterial)
.background(.bar)

// AFTER
.glassEffect()
// (That's it - one unified API)
```

---

## Common Pitfalls

### 1. Forgetting @ObservationIgnored

```swift
// ❌ Wrong: Timer will cause unnecessary observation tracking
@Observable
final class ViewModel {
    var data: [Item] = []
    private var timer: Timer? // Should be ignored
}

// ✅ Correct
@Observable
final class ViewModel {
    var data: [Item] = []

    @ObservationIgnored
    private var timer: Timer?
}
```

### 2. Using @State for Shared State

```swift
// ❌ Wrong: Each view gets its own instance
struct ParentView: View {
    @State private var store = SessionStore() // Parent's instance

    var body: some View {
        ChildView(store: store)
    }
}

struct ChildView: View {
    @State var store: SessionStore // Creates NEW instance!

    var body: some View { ... }
}

// ✅ Correct: Pass as regular property
struct ChildView: View {
    var store: SessionStore // Uses parent's instance

    var body: some View { ... }
}
```

### 3. Actor Isolation Confusion

```swift
// ❌ Wrong: Trying to access actor property directly
actor StatusTracker {
    var statuses: [String: Status] = []
}

struct View: View {
    let tracker: StatusTracker

    var body: some View {
        Text("\(tracker.statuses.count)") // Compile error!
    }
}

// ✅ Correct: Use @State and .task
struct View: View {
    let tracker: StatusTracker
    @State private var count = 0

    var body: some View {
        Text("\(count)")
            .task {
                count = await tracker.getCount()
            }
    }
}
```

---

## Acceptance Criteria

- [ ] @Observable migration recipe documented
- [ ] View property wrapper migration documented
- [ ] Actor migration recipe documented
- [ ] Persistence migration pattern documented
- [ ] Navigation migration documented
- [ ] Common pitfalls documented with solutions
- [ ] Each recipe has before/after code examples
- [ ] Each recipe has migration checklist

## Testing

Manual: Apply migration recipes to 3 existing classes and verify correctness.
