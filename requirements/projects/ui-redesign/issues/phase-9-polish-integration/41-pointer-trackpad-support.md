# Issue 41: Pointer & Trackpad Support

**Phase:** 9 (Polish & Integration)
**Priority:** Medium
**Status:** Not Started
**Depends On:** Issue #26 (Chat View), Issue #02 (Reusable Components)

## Goal

Make the iPad pointer and trackpad experience feel native across the app.

## Non-goals
- TBD.

## Dependencies
- Depends On: Issue #26 (Chat View), Issue #02 (Reusable Components).
- Add runtime or tooling dependencies here.

## Touch Set
- Files to create: TBD.
- Files to modify: TBD.

## Interface Definitions
- List new or changed models, protocols, and API payloads.

## Edge Cases
- TBD.

## Tests
- [ ] Unit tests updated or added.
- [ ] UI tests updated or added (if user flows change).
## Scope

- Hover states for interactive elements
- Pointer shape/highlight feedback
- Right-click context menus
- Trackpad gestures for common actions

## Implementation

### Hover + Highlight

```swift
struct HoverHighlight: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .background(isHovering ? Color.primary.opacity(0.06) : .clear)
            .onHover { isHovering = $0 }
            .hoverEffect(.highlight)
    }
}

extension View {
    func hoverHighlight() -> some View {
        modifier(HoverHighlight())
    }
}
```

### Pointer Shapes

```swift
Button(action: openSettings) {
    Label("Settings", systemImage: "gear")
}
.pointerStyle(.lift)
.hoverEffect(.highlight)
```

### Context Menus

```swift
MessageCardRouter(message: message)
    .contextMenu {
        Button("Copy") { copyMessage(message) }
        Button("Bookmark") { BookmarkStore.shared.toggle(message) }
        Button("Retry") { retryMessage(message) }
    }
```

### Trackpad Gestures

```swift
MessageCardRouter(message: message)
    .swipeActions(edge: .trailing) {
        Button("Retry") { retryMessage(message) }
            .tint(.orange)
    }
```

## Files to Modify

- `SidebarView.swift` (hover states)
- `ChatCardView.swift`, `ToolCardView.swift`, `SystemCardView.swift` (context menus)
- `MessageListView.swift` (gesture affordances)
- `CommandsView.swift` (hover + context menus)

## Acceptance Criteria

- [ ] Hover states on primary interactive elements
- [ ] Pointer highlight/shape feedback applied
- [ ] Right-click context menus on message cards
- [ ] Trackpad swipe actions supported
- [ ] No regressions on touch-only devices

## Testing

- Manual: iPad with trackpad/mouse
- Verify hover, context menu, and swipe actions
