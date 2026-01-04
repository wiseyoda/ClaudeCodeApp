# Issue 16: Card Swipe Actions

**Phase:** 7 (Advanced Features)
**Priority:** Medium
**Status:** Not Started
**Depends On:** Issue 04, 05, 06 (Card Views)

## Goal

Add swipe actions to message cards for quick operations (like Mail app).

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- Depends On: Issue 04, 05, 06 (Card Views).
- Add runtime or tooling dependencies here.

## Touch Set
- Files to create: TBD.
- Files to modify: TBD.

## Interface Definitions
- List new or changed models, protocols, and API payloads.

## Tests
- [ ] Unit tests updated or added.
- [ ] UI tests updated or added (if user flows change).
## Design

### Left Swipe → Destructive/Secondary Actions

| Role | Action 1 | Action 2 |
|------|----------|----------|
| user | - | - |
| assistant | Share | - |
| toolUse | Collapse | - |
| toolResult | Collapse | - |
| error | Dismiss | - |

### Right Swipe → Primary Actions

| Role | Action 1 | Action 2 |
|------|----------|----------|
| user | Copy | Bookmark |
| assistant | Copy | Bookmark |
| toolUse | Copy | - |
| toolResult | Copy | Bookmark |

## Implementation

### SwipeActionModifier

```swift
struct SwipeActionModifier: ViewModifier {
    let leadingActions: [SwipeAction]
    let trailingActions: [SwipeAction]

    @State private var offset: CGFloat = 0
    @State private var activeAction: SwipeAction?

    func body(content: Content) -> some View {
        ZStack {
            // Leading actions (right swipe)
            HStack(spacing: 0) {
                ForEach(leadingActions) { action in
                    SwipeActionButton(action: action, isActive: activeAction?.id == action.id)
                }
                Spacer()
            }

            // Trailing actions (left swipe)
            HStack(spacing: 0) {
                Spacer()
                ForEach(trailingActions.reversed()) { action in
                    SwipeActionButton(action: action, isActive: activeAction?.id == action.id)
                }
            }

            // Content
            content
                .offset(x: offset)
                .gesture(swipeGesture)
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let translation = value.translation.width

                // Limit swipe distance
                if translation > 0 && !leadingActions.isEmpty {
                    offset = min(translation, CGFloat(leadingActions.count) * 80)
                } else if translation < 0 && !trailingActions.isEmpty {
                    offset = max(translation, -CGFloat(trailingActions.count) * 80)
                }

                // Determine active action based on offset
                updateActiveAction()
            }
            .onEnded { value in
                if let action = activeAction {
                    // Haptic feedback
                    executeAction(action)
                }

                // Animate back
                withAnimation(MessageDesignSystem.Animation.smooth) {
                    offset = 0
                    activeAction = nil
                }
            }
    }
}
```

### SwipeAction Model

```swift
struct SwipeAction: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
}

struct SwipeActionButton: View {
    let action: SwipeAction
    let isActive: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: action.icon)
                .font(.system(size: 20))
            Text(action.label)
                .font(MessageDesignSystem.labelFont())
        }
        .foregroundStyle(.white)
        .frame(width: 80)
        .frame(maxHeight: .infinity)
        .background(isActive ? action.color.opacity(0.8) : action.color)
        .scaleEffect(isActive ? 1.1 : 1.0)
        .animation(MessageDesignSystem.Animation.quick, value: isActive)
    }
}
```

### Extension for Cards

```swift
extension View {
    func cardSwipeActions(
        leading: [SwipeAction] = [],
        trailing: [SwipeAction] = []
    ) -> some View {
        modifier(SwipeActionModifier(
            leadingActions: leading,
            trailingActions: trailing
        ))
    }
}
```

### Usage in ChatCardView

```swift
struct ChatCardView: View {
    let message: ChatMessage
    let onCopy: () -> Void
    let onBookmark: () -> Void
    let onShare: () -> Void

    var body: some View {
        cardContent
            .cardSwipeActions(
                leading: [
                    SwipeAction(
                        icon: "doc.on.doc",
                        label: "Copy",
                        color: .blue,
                        action: onCopy
                    ),
                    SwipeAction(
                        icon: "bookmark",
                        label: "Bookmark",
                        color: .orange,
                        action: onBookmark
                    )
                ],
                trailing: message.role == .assistant ? [
                    SwipeAction(
                        icon: "square.and.arrow.up",
                        label: "Share",
                        color: .green,
                        action: onShare
                    )
                ] : []
            )
    }
}
```

### Usage in ToolCardView

```swift
struct ToolCardView: View {
    @Binding var isExpanded: Bool
    let onCopy: () -> Void

    var body: some View {
        cardContent
            .cardSwipeActions(
                leading: [
                    SwipeAction(
                        icon: "doc.on.doc",
                        label: "Copy",
                        color: .blue,
                        action: onCopy
                    )
                ],
                trailing: [
                    SwipeAction(
                        icon: isExpanded ? "chevron.up" : "chevron.down",
                        label: isExpanded ? "Collapse" : "Expand",
                        color: .gray,
                        action: { isExpanded.toggle() }
                    )
                ]
            )
    }
}
```

## Accessibility

```swift
struct SwipeActionModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .accessibilityActions {
                ForEach(leadingActions + trailingActions) { action in
                    Button(action.label, action: action.action)
                }
            }
    }
}
```

## Haptic Feedback

```swift
private func executeAction(_ action: SwipeAction) {
    // Trigger haptic when action executes
    // Using sensoryFeedback via state change
    action.action()
}

// In view
.sensoryFeedback(.impact(weight: .medium), trigger: actionExecutedTrigger)
```

## Edge Cases

| Case | Behavior |
|------|----------|
| Scroll conflict | Require 10pt horizontal movement before swipe activates |
| Multiple cards swiped | Only one card can be swiped at a time |
| Swipe during streaming | Disable swipe on streaming messages |
| Small screen | Actions stack vertically if needed |

## Files to Create

```
CodingBridge/Views/Components/
├── SwipeActionModifier.swift
└── SwipeActionButton.swift
```

## Files to Modify

| File | Changes |
|------|---------|
| `ChatCardView.swift` | Add `.cardSwipeActions()` |
| `ToolCardView.swift` | Add `.cardSwipeActions()` |
| `SystemCardView.swift` | Add `.cardSwipeActions()` for error cards |

## Acceptance Criteria

- [ ] Right swipe reveals Copy/Bookmark actions
- [ ] Left swipe reveals secondary actions
- [ ] Active action scales up on threshold
- [ ] Haptic feedback on action execution
- [ ] Smooth return animation
- [ ] Accessibility actions available
- [ ] No conflict with scroll gesture
- [ ] Build passes

## Code Examples

TBD. Add concrete Swift examples before implementation.
