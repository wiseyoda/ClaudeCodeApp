# Migration Guide

## Purpose

Provide a practical checklist and recipes for migrating the current app to the iOS 26 redesign foundation without losing existing functionality.

## Principles

- Foundation first: data normalization, @Observable migration, and design tokens before UI changes.
- Preserve core behavior; redesign changes presentation and flow, not backend contracts.
- Firebase integration happens after redesign; use provider-agnostic interfaces only.

## Recommended Order

1. Data normalization (Issue 00)
2. @Observable + actor migration (Issue 10)
3. Design tokens + Liquid Glass (Issues 01, 17)
4. Core views (Chat, Tool, System cards)
5. Navigation (iPhone TabView, iPad NavigationSplitView)
6. Settings + Diagnostics consolidation
7. Advanced features (tool grouping, offline mode, widgets)

## Recipes

### 1) ObservableObject to @Observable

```swift
// BEFORE
class SessionStore: ObservableObject {
    @Published var sessions: [Session] = []
}

// AFTER
@Observable
final class SessionStore {
    var sessions: [Session] = []
}
```

Checklist:
- [ ] Remove @Published and Combine imports
- [ ] Add @ObservationIgnored for dependencies
- [ ] Update views to @State/@Bindable

### 2) @StateObject to @State and @ObservedObject to @Bindable

```swift
// BEFORE
@StateObject private var viewModel = ChatViewModel()

// AFTER
@State private var viewModel = ChatViewModel()
```

```swift
// BEFORE
@ObservedObject var settings: AppSettings

// AFTER
@Bindable var settings: AppSettings
```

### 3) EnvironmentObject to @Environment

```swift
// BEFORE
@EnvironmentObject var store: SessionStore

// AFTER
@Environment(SessionStore.self) var store
```

### 4) NavigationView to NavigationSplitView

```swift
NavigationSplitView {
    SidebarView(selection: $selectedProject)
} detail: {
    DetailContainerView(project: selectedProject)
}
```

### 5) Material to Liquid Glass

```swift
// BEFORE
.background(.ultraThinMaterial)

// AFTER
.glassEffect()
```

### 6) Git Status to cli-bridge

- Remove local git status queries.
- Use cli-bridge status payloads for branch/dirty/ahead/behind/conflicts.

### 7) Diagnostics Consolidation

- Merge error analytics and insights into Diagnostics.
- Keep provider-agnostic hooks only (Firebase later).

## Persistence Migration

- Version UserDefaults and key migrations.
- Keep secrets in Keychain.
- Add a migration test that loads legacy keys and verifies new state.

## Validation Checklist

- [ ] Message normalization applied to history and stream.
- [ ] No ObservableObject or @Published remains.
- [ ] Liquid Glass applied to all redesigned surfaces.
- [ ] Streaming status banner appears only while streaming.
- [ ] Command palette and autocomplete works on iPad keyboard.
- [ ] Diagnostics shows error insights and analytics (local only).
- [ ] UI tests cover primary flows.
