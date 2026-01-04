# Issue 15: iOS 26.2 Feature Adoption

**Phase:** 8 (iOS 26 Platform)
**Priority:** High
**Status:** Not Started
**Depends On:** None
**Target:** iOS 26.2, Xcode 26.2, Swift 6.2.1

## Goal

Adopt iOS 26.2 APIs throughout the new components:
- Liquid Glass design with intensity support (see also Issue #17)
- Enhanced SF Symbol effects (`.breathe`, `.wiggle`)
- HapticManager (centralized haptics; uses `.sensoryFeedback` internally)
- `ScrollPosition` API improvements
- iOS 26.2 layout APIs (`ToolbarSpacer`, `listSectionMargins`, `scrollIndicatorsFlash`)
- Navigation enhancements (`navigationSubtitle`)

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- See **Depends On** header; add runtime or tooling dependencies here.

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
## iOS 26.1/26.2 Specific Features

### iOS 26.1 Fixes (Now Safe to Use)
- `navigationLinkIndicatorVisibility(.hidden)` - was crashing on 26.0
- Toggle appearance inside Liquid Glass - now renders correctly
- SwiftUI Instruments "Skipped Update" markers (Xcode 26.1.1)
- Async testing with `@MainActor` (Swift 6.2.1)

### iOS 26.2 New Features
| Feature | Description |
|---------|-------------|
| Liquid Glass Intensity Slider | User-controllable glass effect intensity |
| Quicker Menu Animations | Bouncier spring timing for menus/popovers |
| DeclaredAgeRange API | Age verification for regulatory compliance |

## 1. Symbol Effects (iOS 26)

iOS 26 adds new symbol animation effects beyond iOS 17's offerings:

### New Effects

| Effect | Use | Code |
|--------|-----|------|
| `.breathe.pulse` | Streaming/loading | `isActive: isStreaming` |
| `.wiggle` | Attention/notifications | `value: unreadCount` |
| `.bounce.up.byLayer` | Success confirmation | `value: successTrigger` |
| `.rotate.byLayer` | Processing | `isActive: isProcessing` |

### Streaming Indicator

```swift
struct StreamingIndicator: View {
    let isStreaming: Bool

    var body: some View {
        Image(systemName: "ellipsis")
            .symbolEffect(.variableColor.iterative.dimInactiveLayers, isActive: isStreaming)
            .font(.title3)
            .foregroundStyle(.secondary)
    }
}
```

### Status Badge with Effects

```swift
struct StatusBadge: View {
    let status: Status
    @State private var successTrigger = 0

    var body: some View {
        Image(systemName: status.icon)
            .symbolEffect(.bounce.up.byLayer, value: successTrigger)
            .foregroundStyle(status.color)
            .onChange(of: status) { oldValue, newValue in
                if newValue == .success {
                    successTrigger += 1
                }
            }
    }
}
```

### Unread Indicator with Wiggle

```swift
struct UnreadIndicator: View {
    let count: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.shared.selection()
            onTap()
        }) {
            HStack(spacing: MessageDesignSystem.Spacing.xs) {
                Image(systemName: "chevron.down.circle.fill")
                    .symbolEffect(.wiggle, value: count)
                Text("\(count) new")
            }
            .font(MessageDesignSystem.labelFont())
            .padding(.horizontal, MessageDesignSystem.Spacing.md)
            .padding(.vertical, MessageDesignSystem.Spacing.sm)
            .glassEffect()
        }
    }
}
```

## 2. HapticManager

Route all haptics through `HapticManager`; implementation should use `.sensoryFeedback` where appropriate.

### Feedback Types

| Type | Use Case | Components |
|------|----------|------------|
| `.impact(weight: .light)` | Button taps | QuickActionButton, swipe actions |
| `.impact(weight: .medium)` | Significant actions | RetryButton, send message |
| `.selection` | Toggle/selection changes | ExpandChevron, item selection |
| `.success` | Completion | Task complete, message sent |
| `.warning` | Errors/warnings | Error banner, validation failure |
| `.error` | Critical errors | Connection lost, abort |

### Implementation Pattern

```swift
struct QuickActionButton: View {
    let icon: String
    let label: String?
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.impact(.light)
            action()
        } label: {
            HStack(spacing: MessageDesignSystem.Spacing.xs) {
                Image(systemName: icon)
                if let label { Text(label) }
            }
            .font(MessageDesignSystem.labelFont())
            .foregroundStyle(.secondary)
            .padding(MessageDesignSystem.Spacing.sm)
        }
        .buttonStyle(.plain)
    }
}
```

### Component Feedback Matrix

| Component | Feedback Type | Trigger |
|-----------|---------------|---------|
| QuickActionButton | `.impact(weight: .light)` | Tap count |
| ExpandChevron | `.selection` | isExpanded toggle |
| RetryButton | `.impact(weight: .medium)` | Retry tap |
| StatusBadge | `.success` | Status → success |
| SwipeAction | `.impact(weight: .light)` | Threshold crossed |
| BookmarkToggle | `.selection` | Bookmark state |
| CopyButton | `.success` | Copy completed |
| ErrorBanner | `.warning` | Error appears |
| SendButton | `.success` | Message sent |
| AbortButton | `.error` | Agent aborted |

## 3. Content Transitions

Use `contentTransition` for smooth text changes:

```swift
// Token count with numeric transition
Text("\(tokenCount)")
    .contentTransition(.numericText())
    .animation(.default, value: tokenCount)

// Message count
Text("\(messageCount) messages")
    .contentTransition(.numericText(countsDown: false))

// Status text interpolation
Text(statusText)
    .contentTransition(.interpolate)
```

## 4. ScrollPosition Improvements

iOS 26 enhances ScrollPosition with better geometry tracking:

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
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y >= geometry.contentSize.height - geometry.containerSize.height - 50
        } action: { _, isAtBottom in
            scrollState.isAtBottom = isAtBottom
            if isAtBottom {
                scrollState.unreadCount = 0
            }
        }
    }
}
```

## 5. Animation Improvements

### Spring Animations

```swift
// Use duration-based springs (iOS 26 preferred)
withAnimation(.spring(duration: 0.3)) {
    isExpanded.toggle()
}

// Bounce effect for arrivals
withAnimation(.spring(duration: 0.4, bounce: 0.3)) {
    messages.append(newMessage)
}
```

### Phase Animator for Complex States

```swift
struct ToolProgressIndicator: View {
    let progress: Double?

    var body: some View {
        if let progress {
            ProgressView(value: progress)
                .tint(.blue)
        } else {
            PhaseAnimator([0.0, 1.0]) { phase in
                Capsule()
                    .fill(.blue.gradient)
                    .frame(width: 60, height: 4)
                    .offset(x: (phase - 0.5) * 40)
            } animation: { _ in
                .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
            }
        }
    }
}
```

## 6. iOS 26 Layout APIs

### ToolbarSpacer

Precise toolbar spacing without invisible views:

```swift
.toolbar {
    ToolbarItem(placement: .primaryAction) {
        Button("Send", systemImage: "arrow.up.circle.fill", action: send)
    }
    ToolbarSpacer(.fixed, width: 12)
    ToolbarItem(placement: .primaryAction) {
        Menu { /* options */ } label: { Image(systemName: "ellipsis.circle") }
    }
}
```

### listSectionMargins

Control list section margins directly:

```swift
Section("Messages") {
    ForEach(messages) { MessageRow(message: $0) }
}
.listSectionMargins(.horizontal, 16)
.listSectionMargins(.vertical, 8)
```

### scrollIndicatorsFlash

Flash scroll indicators when content changes:

```swift
ScrollView {
    LazyVStack { /* messages */ }
}
.scrollIndicatorsFlash(trigger: newMessageCount)
```

### navigationSubtitle

Add contextual subtitles to navigation:

```swift
.navigationTitle(project.displayName)
.navigationSubtitle("\(project.sessionCount) sessions")
```

## 7. Liquid Glass Intensity (iOS 26.2)

Respect user preference for glass effect intensity:

```swift
struct AdaptiveGlassModifier: ViewModifier {
    @Environment(\.liquidGlassIntensity) var intensity

    func body(content: Content) -> some View {
        content.glassEffect(intensity: intensity)
    }
}

extension View {
    func adaptiveGlass() -> some View {
        modifier(AdaptiveGlassModifier())
    }
}
```

**Testing**: Test UI at minimum, medium, and maximum intensity settings.

## 8. iOS 26.2 Menu Animations

Match system's quicker, bouncier menu feel:

```swift
extension Animation {
    static let menuSpring = Animation.spring(response: 0.35, dampingFraction: 0.65)
    static let contextMenuAppear = Animation.spring(response: 0.3, dampingFraction: 0.7)
}
```

## Implementation Checklist

### Symbol Effects
- [ ] StreamingIndicator - `.variableColor.iterative`
- [ ] StatusBadge - `.bounce.up.byLayer`
- [ ] UnreadIndicator - `.wiggle`
- [ ] LoadingGear - `.rotate.byLayer`
- [ ] SuccessCheckmark - `.bounce`
- [ ] ErrorIcon - `.pulse`

### Sensory Feedback
- [ ] QuickActionButton - `.impact(weight: .light)`
- [ ] ExpandChevron - `.selection`
- [ ] RetryButton - `.impact(weight: .medium)`
- [ ] Swipe actions - `.impact(weight: .light)`
- [ ] Bookmark toggle - `.selection`
- [ ] Copy action - `.success`
- [ ] Send button - `.success`
- [ ] Error banner - `.warning`

### Content Transitions
- [ ] Token count - `.numericText()`
- [ ] Message count - `.numericText()`
- [ ] Status text - `.interpolate`
- [ ] Session count - `.numericText()`

### ScrollPosition
- [ ] MessageListView scroll tracking
- [ ] Auto-scroll on new message
- [ ] Scroll-to-bottom button
- [ ] Unread indicator positioning

### Animations
- [ ] Card expand/collapse - duration-based spring
- [ ] Message arrival - bounce spring
- [ ] Status changes - phase animator
- [ ] Tool progress - phase animator

### iOS 26 Layout APIs
- [ ] ToolbarSpacer in chat toolbar
- [ ] listSectionMargins in session picker
- [ ] scrollIndicatorsFlash on new messages
- [ ] navigationSubtitle for project/session context

### iOS 26.2 Specifics
- [ ] AdaptiveGlassModifier for intensity support
- [ ] Test glass at min/med/max intensity
- [ ] iOS 26.2 menu spring animations
- [ ] Verify toggles render in glass contexts

## Acceptance Criteria

- [ ] All haptics route through HapticManager (no UIKit)
- [ ] Symbol effects on all appropriate icons
- [ ] ScrollPosition for message list
- [ ] Content transitions for numeric values
- [ ] No deprecated animation APIs
- [ ] Build passes on iOS 26.2+ (Xcode 26.2)
- [ ] Previews render correctly
- [ ] Liquid Glass respects user intensity preference
- [ ] No @FocusState inside safeAreaBar (use safeAreaInset)

## Testing

```swift
struct iOS26FeaturesTests: XCTestCase {
    func testSymbolEffectsCompile() {
        // Verify symbol effect modifiers compile
        let _ = Image(systemName: "ellipsis")
            .symbolEffect(.variableColor.iterative)
    }

    func testHapticManagerCompiles() {
        // Verify haptic helpers compile
        HapticManager.shared.impact(.light)
    }
}
```
