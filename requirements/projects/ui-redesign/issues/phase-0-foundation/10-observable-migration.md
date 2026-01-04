---
number: 10
title: Observable Migration
phase: phase-0-foundation
priority: High
depends_on: null
acceptance_criteria: 10
files_to_touch: 16
status: pending
completed_by: null
completed_at: null
verified_by: null
verified_at: null
commit: null
spot_checked: false
blocked_reason: null
---

# Issue 10: @Observable + Actor Migration

**Phase:** 0 (Foundation)
**Priority:** High
**Status:** Not Started
**Depends On:** None

## Required Documentation

Before starting work on this issue, review these architecture and design documents:

### Core Architecture
- **[Swift 6 Concurrency Model](../../docs/architecture/data/02-swift-6-concurrency-model.md)** - CRITICAL: @Observable, @MainActor, actor patterns
- **[State Management](../../docs/architecture/ui/07-state-management.md)** - AppState and feature-level state patterns
- **[Environment Injection](../../docs/architecture/ui/08-environment-injection.md)** - @Environment patterns for @Observable
- **[Dependency Injection](../../docs/architecture/data/10-dependency-injection.md)** - Actor protocols, dependency injection patterns
- **[Memory Management](../../docs/architecture/data/11-memory-management.md)** - Weak references, actor cleanup

### Foundation
- **[System Overview](../../docs/architecture/data/01-system-overview.md)** - Overall architecture context
- **[Design Decisions](../../docs/overview/design-decisions.md)** - State management decisions

### Workflows
- **[Execution Guardrails](../../docs/workflows/guardrails.md)** - Development rules and constraints

## Goal

Migrate all state management to Swift 6 concurrency patterns:
- `@Observable` macro for all observable state
- Swift actors for thread-safe shared state
- `@Bindable` for two-way bindings
- Full actor isolation; use `@MainActor @Observable` only for UI-bound state

## Scope
- In scope:
  - Migrate ObservableObject-based state to `@Observable` or actors.
  - Update SwiftUI bindings to use `@State`, `@Bindable`, and `@Environment`.
  - Remove Combine usage where observation handles updates.
  - Migrate persistence off `@AppStorage` with versioned upgrades.
  - Validate with strict concurrency checks and Thread Sanitizer.
- Out of scope:
  - Feature redesigns or new UI flows.
  - Networking layer rewrites or backend contract changes.
  - New persistence formats beyond required migrations.

## Non-goals
- Eliminate every concurrency warning in untouched legacy files.
- Replace singletons or store ownership patterns used by the app.
- Change data models or protocol shapes unrelated to observation.

## Dependencies
- See **Depends On** header; add runtime or tooling dependencies here.

## Touch Set
- Files to create:
  - `CodingBridge/Utilities/ObservationHelpers.swift` (optional shared helpers)
- Files to modify:
  - `CodingBridge/ViewModels/ChatViewModel.swift`
  - `CodingBridge/ViewModels/ChatViewModel+*.swift`
  - `CodingBridge/SessionStore.swift`
  - `CodingBridge/SessionRepository.swift`
  - `CodingBridge/AppSettings.swift`
  - `CodingBridge/CommandStore.swift`
  - `CodingBridge/IdeasStore.swift`
  - `CodingBridge/Persistence/BookmarkStore.swift`
  - `CodingBridge/ProjectSettingsStore.swift`
  - `CodingBridge/Utilities/SearchHistoryStore.swift`
  - `CodingBridge/DebugLogStore.swift`
  - `CodingBridge/Persistence/MessageStore.swift`
  - `CodingBridge/Managers/StatusMessageStore.swift`
  - `CodingBridge/Views/*.swift`
  - `CodingBridge/CodingBridgeApp.swift`
  - `CodingBridgeTests/`

## Interface Definitions
- No API payload changes.

```swift
@MainActor @Observable
final class AppState {
    var selectedProject: Project?
    var navigationPath: NavigationPath
    var activeSheet: ActiveSheet?
}

@Observable
final class MessageScrollState {
    var position: ScrollPosition
}

@MainActor @Observable
final class StreamInteractionHandler {
    private(set) var pendingInteractions: [InteractionType]
}
```

```swift
protocol StatusTracking: Actor {
    func status(for toolUseId: String) async -> StatusBannerState
    func updateProgress(toolUseId: String, info: ProgressInfo) async
    func startSubagent(toolUseId: String, info: SubagentInfo) async
    func complete(toolUseId: String) async
    func clearAll() async
}

actor CardStatusTracker: StatusTracking { }
actor SubagentContextTracker { }
```

## Edge Cases
- Actors accessed from SwiftUI without `await` (stale reads).
- `@Bindable` missing for two-way bindings (edits not persisted).
- Non-Sendable types captured in async tasks or actors.
- Migration of `@AppStorage` keys without versioning (data loss).
- Preview and UI test harness environment injection gaps.

## Tests
- [ ] Unit tests updated or added.
- [ ] UI tests updated or added (if user flows change).
- [ ] Migration tests cover persisted settings and schema upgrades.
## Why Migrate?

| @ObservableObject | @Observable |
|-------------------|-------------|
| Entire view re-renders on any property change | Only views using changed property re-render |
| Requires `@Published` wrapper | Automatic tracking |
| Combine-based | Observation framework |
| More boilerplate | Less boilerplate |
| Data race prone | Actor isolation available |

## Migration Strategy

### @Observable (Replaces @ObservableObject)

| Before | After |
|--------|-------|
| `class Foo: ObservableObject` | `@Observable final class Foo` |
| `@Published var x` | `var x` (automatic) |
| `@StateObject` | `@State` |
| `@ObservedObject` | Direct reference or `@Bindable` |
| `objectWillChange.send()` | Remove (automatic) |

### Persistence Migration (UserDefaults + Keychain)

When migrating `@AppStorage` to `@Observable`, persist values manually and migrate existing data:

```swift
@Observable
final class AppSettings {
    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let migrationVersionKey = "settings-migration-version"

    var serverURL: String = ""
    var appTheme: AppTheme = .system

    init() {
        migrateIfNeeded()
        load()
    }

    func load() {
        serverURL = defaults.string(forKey: "serverURL") ?? ""
        appTheme = AppTheme(rawValue: defaults.string(forKey: "appTheme") ?? "") ?? .system
    }

    func save() {
        defaults.set(serverURL, forKey: "serverURL")
        defaults.set(appTheme.rawValue, forKey: "appTheme")
    }

    private func migrateIfNeeded() {
        let version = defaults.integer(forKey: migrationVersionKey)
        guard version < 1 else { return }

        // Map old @AppStorage keys to new model fields here.
        // Example: defaults.string(forKey: "api_server_url") -> serverURL

        defaults.set(1, forKey: migrationVersionKey)
    }
}
```

### Migration Testing

- Add tests for UserDefaults -> @Observable migration (pre- and post-upgrade).
- Validate schema version bumps and rollback safety.
- Smoke test persistence across app updates.

Guidelines:
- Use Keychain for secrets (auth tokens, SSH keys); never store secrets in UserDefaults.
- Version serialized models to allow schema changes (`schemaVersion` field in JSON).
- Document migrated keys so future changes are safe.

### Actors (For Thread-Safe Shared State)

| Before | After |
|--------|-------|
| `@MainActor class Store` | `actor Store` |
| `await store.update()` | Same (actor-isolated) |
| Shared singleton | Actor singleton |

### @MainActor @Observable (For UI-Bound State)

Use `@MainActor @Observable` only when:
- State directly drives UI updates
- Properties must be accessed synchronously from views

```swift
@MainActor @Observable
final class StreamInteractionHandler {
    // UI-bound state - needs synchronous access from views
    private(set) var pendingInteractions: [InteractionType] = []
}
```

## Files to Migrate

### ViewModels (→ @Observable)

| File | Class | Migration |
|------|-------|-----------|
| `ChatViewModel.swift` | `ChatViewModel` | `@MainActor @Observable` |
| `SessionStore.swift` | `SessionStore` | `@Observable` |
| `MessageStore.swift` | `MessageStore` | `@Observable` |
| `CommandStore.swift` | `CommandStore` | `@Observable` |
| `BookmarkStore.swift` | `BookmarkStore` | `@Observable` |
| `IdeasStore.swift` | `IdeasStore` | `@Observable` |
| `AppSettings.swift` | `AppSettings` | `@Observable` |
| `DebugLogStore.swift` | `DebugLogStore` | `@Observable` |

### New ViewModels (Create as @Observable)

| File | Class | Pattern |
|------|-------|---------|
| `StreamInteractionHandler.swift` | `StreamInteractionHandler` | `@MainActor @Observable` |
| `MessageScrollState.swift` | `MessageScrollState` | `@Observable` |

### New Actors (Create as actor)

| File | Actor | Purpose |
|------|-------|---------|
| `CardStatusTracker.swift` | `CardStatusTracker` | Thread-safe tool status |
| `SubagentContextTracker.swift` | `SubagentContextTracker` | Thread-safe subagent tracking |

## Migration Examples

### Before: @ObservableObject

```swift
@MainActor
class SessionStore: ObservableObject {
    static let shared = SessionStore()

    @Published var sessionsByProject: [String: [ProjectSession]] = [:]
    @Published var isLoading: [String: Bool] = [:]

    func loadSessions(for project: String) async {
        isLoading[project] = true
        // ... load
        sessionsByProject[project] = sessions
        isLoading[project] = false
    }
}

// In View
struct SessionPickerView: View {
    @ObservedObject var store = SessionStore.shared

    var body: some View {
        // ...
    }
}
```

### After: @Observable

```swift
@Observable
final class SessionStore {
    static let shared = SessionStore()

    var sessionsByProject: [String: [ProjectSession]] = [:]
    var isLoading: [String: Bool] = [:]

    @MainActor
    func loadSessions(for project: String) async {
        isLoading[project] = true
        // ... load
        sessionsByProject[project] = sessions
        isLoading[project] = false
    }
}

// In View
struct SessionPickerView: View {
    var store = SessionStore.shared  // Direct reference

    var body: some View {
        // ...
    }
}
```

### Before: @MainActor Class with Shared State

```swift
@MainActor
class CardStatusTracker: ObservableObject {
    @Published var activeStatuses: [String: StatusBannerState] = [:]

    func updateProgress(toolUseId: String, info: ProgressInfo) {
        activeStatuses[toolUseId] = .inProgress(info)
    }
}
```

### After: Actor

```swift
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

### Using @Bindable

```swift
// For two-way bindings with @Observable objects
struct MessageListView: View {
    @Bindable var scrollState: MessageScrollState

    var body: some View {
        ScrollView {
            // ...
        }
        .scrollPosition($scrollState.position)  // Two-way binding
    }
}

// Parent view
struct ChatView: View {
    @State private var scrollState = MessageScrollState()

    var body: some View {
        MessageListView(scrollState: scrollState)
    }
}
```

## Actor Protocol Pattern

For testability, define actor protocols:

```swift
protocol StatusTracking: Actor {
    func status(for toolUseId: String) async -> StatusBannerState
    func updateProgress(toolUseId: String, info: ProgressInfo) async
    func startSubagent(toolUseId: String, info: SubagentInfo) async
    func complete(toolUseId: String) async
    func clearAll() async
}

actor CardStatusTracker: StatusTracking {
    // Implementation
}

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

## View Property Wrapper Updates

| Old | New | Use Case |
|-----|-----|----------|
| `@StateObject` | `@State` | View owns the object |
| `@ObservedObject` | None (or `@Bindable`) | Passed from parent |
| `@EnvironmentObject` | `@Environment` | From environment |

```swift
// Before
@StateObject private var viewModel = ChatViewModel()

// After
@State private var viewModel = ChatViewModel()

// Before
@ObservedObject var settings: AppSettings
TextField("Name", text: $settings.name)

// After
@Bindable var settings: AppSettings
TextField("Name", text: $settings.name)
```

## Async Actor Access in Views

When accessing actor state from views:

```swift
struct ToolCardView: View {
    let toolUseId: String
    let statusTracker: CardStatusTracker

    @State private var status: StatusBannerState = .none

    var body: some View {
        VStack {
            StatusBannerOverlay(status: status)
        }
        .task {
            status = await statusTracker.status(for: toolUseId)
        }
    }
}
```

## Memory Management

### Weak References in Closures

```swift
Task { [weak self] in
    guard let self else { return }
    await self.handleResult()
}

manager.onEvent = { [weak self] event in
    self?.processEvent(event)
}
```

### Actor Cleanup

```swift
actor CardStatusTracker {
    private var cleanupTasks: [String: Task<Void, Never>] = [:]

    deinit {
        cleanupTasks.values.forEach { $0.cancel() }
    }

    func clearAll() {
        cleanupTasks.values.forEach { $0.cancel() }
        cleanupTasks.removeAll()
        activeStatuses.removeAll()
    }
}
```

## Implementation Checklist

### Phase 1: Core ViewModels

- [ ] `ChatViewModel` → `@MainActor @Observable`
- [ ] `SessionStore` → `@Observable`
- [ ] `MessageStore` → `@Observable`
- [ ] `AppSettings` → `@Observable`

### Phase 2: Stores

- [ ] `CommandStore` → `@Observable`
- [ ] `BookmarkStore` → `@Observable`
- [ ] `IdeasStore` → `@Observable`
- [ ] `SearchHistoryStore` → `@Observable`
- [ ] `ProjectSettingsStore` → `@Observable`
- [ ] `DebugLogStore` → `@Observable`

### Phase 3: New Components

- [ ] `StreamInteractionHandler` → `@MainActor @Observable`
- [ ] `MessageScrollState` → `@Observable`
- [ ] `CardStatusTracker` → `actor`
- [ ] `SubagentContextTracker` → `actor`

### Phase 4: View Updates

- [ ] Replace all `@StateObject` with `@State`
- [ ] Replace all `@ObservedObject` with direct ref or `@Bindable`
- [ ] Add `@Bindable` where two-way bindings needed
- [ ] Add `.task` for async actor access

### Phase 5: Cleanup

- [ ] Remove all `objectWillChange.send()` calls
- [ ] Remove all `@Published` wrappers
- [ ] Add `Sendable` conformance where needed
- [ ] Verify no data races with Thread Sanitizer

## Acceptance Criteria

- [ ] No `ObservableObject` conformances in codebase
- [ ] No `@Published` property wrappers
- [ ] No `@StateObject` or `@ObservedObject`
- [ ] All shared mutable state uses actors
- [ ] All UI state uses `@Observable`
- [ ] Existing UserDefaults values migrated with versioning
- [ ] Migration tests validate persisted data across upgrades
- [ ] Thread Sanitizer reports no data races
- [ ] Build passes with strict concurrency checking
- [ ] All tests pass

## Compiler Flags

Enable strict concurrency checking in Xcode:
- Build Settings → Swift Compiler - Upcoming Features
- Set "Strict Concurrency Checking" to "Complete"

## Testing

```swift
// Test actor isolation
class CardStatusTrackerTests: XCTestCase {
    func testConcurrentAccess() async {
        let tracker = CardStatusTracker()

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    await tracker.updateProgress(
                        toolUseId: "tool-\(i)",
                        info: ProgressInfo(toolName: "Test", detail: nil, progress: nil, startTime: .now)
                    )
                }
            }
        }

        for i in 0..<100 {
            let status = await tracker.status(for: "tool-\(i)")
            XCTAssertNotEqual(status, .none)
        }
    }
}

// Test @Observable triggers updates
class ObservableTests: XCTestCase {
    func testPropertyChangeTriggers() {
        let store = SessionStore()

        var updateCount = 0
        withObservationTracking {
            _ = store.sessionsByProject
        } onChange: {
            updateCount += 1
        }

        store.sessionsByProject["test"] = []
        XCTAssertEqual(updateCount, 1)
    }
}
```
