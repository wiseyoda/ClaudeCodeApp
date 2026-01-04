# Issue 39: Animations & Transitions

**Phase:** 9 (Polish & Integration)
**Priority:** Medium
**Status:** Not Started
**Depends On:** All feature issues, Issue #38 (Accessibility)
**Target:** iOS 26.2, Xcode 26.2, Swift 6.2.1

## Goal

Implement consistent, performant animations that enhance UX while respecting accessibility preferences.

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- Depends On: All feature issues, Issue #38 (Accessibility).
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
## iOS 26.2 Animation Features

| Feature | Usage |
|---------|-------|
| Quicker menu springs | iOS 26.2 has bouncier menu animations |
| `.sensoryFeedback()` | Replace UIKit haptics |
| `.symbolEffect()` | Animated SF Symbols |
| `.contentTransition(.numericText())` | Animated counters |
| SwiftUI Instruments | "Skipped Update" markers (Xcode 26.1.1) |

### iOS 26.2 Menu Spring

iOS 26.2 uses quicker, bouncier springs for menus. Match this feel:

```swift
extension Animation {
    /// iOS 26.2-style menu spring (quicker, bouncier)
    static let menuSpring = Animation.spring(response: 0.35, dampingFraction: 0.65)

    /// iOS 26.2-style context menu appear
    static let contextMenuAppear = Animation.spring(response: 0.3, dampingFraction: 0.7)
}
```

## Animation Principles

1. **Purpose**: Every animation should serve a purpose
2. **Performance**: 60fps on all supported devices
3. **Consistency**: Same animation for same action type
4. **Accessibility**: Respect Reduce Motion preference
5. **Subtlety**: Animations enhance, not distract

## Animation Tokens

| Token | Duration | Curve | Use Case |
|-------|----------|-------|----------|
| `fast` | 0.15s | easeOut | Micro-interactions |
| `normal` | 0.25s | easeInOut | Standard transitions |
| `slow` | 0.35s | easeInOut | Complex transitions |
| `spring` | - | spring(0.5, 0.7) | Bouncy feedback |
| `snappy` | - | snappy | Quick responses |

## Implementation

### Animation Tokens

```swift
extension Animation {
    static let appFast = Animation.easeOut(duration: 0.15)
    static let appNormal = Animation.easeInOut(duration: 0.25)
    static let appSlow = Animation.easeInOut(duration: 0.35)
    static let appSpring = Animation.spring(response: 0.5, dampingFraction: 0.7)
    static let appSnappy = Animation.snappy
}
```

### Motion-Safe Wrapper

```swift
struct MotionSafe: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let animation: Animation

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation)
    }
}

extension View {
    func motionSafe(_ animation: Animation = .appNormal) -> some View {
        modifier(MotionSafe(animation: animation))
    }

    func withMotionSafe<V: Equatable>(_ animation: Animation = .appNormal, value: V) -> some View {
        modifier(MotionSafeValue(animation: animation, value: value))
    }
}

struct MotionSafeValue<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}
```

### Message Animations

```swift
struct MessageAppearAnimation: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let delay: Double

    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .onAppear {
                if reduceMotion {
                    appeared = true
                } else {
                    withAnimation(.appSpring.delay(delay)) {
                        appeared = true
                    }
                }
            }
    }
}

extension View {
    func messageAppearAnimation(delay: Double = 0) -> some View {
        modifier(MessageAppearAnimation(delay: delay))
    }
}

// Usage in MessageListView
ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
    MessageView(message: message)
        .messageAppearAnimation(delay: Double(index) * 0.05)
}
```

### Streaming Text Animation

```swift
struct StreamingTextView: View {
    let text: String
    @State private var displayedText = ""
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        Text(displayedText)
            .onChange(of: text) { oldValue, newValue in
                if reduceMotion {
                    displayedText = newValue
                } else {
                    animateText(from: oldValue, to: newValue)
                }
            }
    }

    private func animateText(from oldValue: String, to newValue: String) {
        // Append new characters with slight delay
        let newChars = String(newValue.dropFirst(oldValue.count))

        for (index, char) in newChars.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.01) {
                displayedText.append(char)
            }
        }
    }
}
```

### Tool Card Animations

```swift
struct ToolCardExpandAnimation: ViewModifier {
    let isExpanded: Bool
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .animation(reduceMotion ? nil : .appSpring, value: isExpanded)
    }
}

struct ToolProgressAnimation: View {
    let progress: Double
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accentColor)
                .frame(width: geo.size.width * progress)
                .animation(reduceMotion ? nil : .appNormal, value: progress)
        }
        .frame(height: 4)
    }
}
```

### Navigation Transitions

```swift
struct SlideTransition: ViewModifier {
    let edge: Edge
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .transition(.asymmetric(
                insertion: .move(edge: edge).combined(with: .opacity),
                removal: .move(edge: edge.opposite).combined(with: .opacity)
            ))
    }
}

extension Edge {
    var opposite: Edge {
        switch self {
        case .top: return .bottom
        case .bottom: return .top
        case .leading: return .trailing
        case .trailing: return .leading
        }
    }
}

// Custom navigation transition
extension AnyTransition {
    static var slideUp: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        )
    }

    static var slideFromTrailing: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
}
```

### Sheet Animations

```swift
struct SheetAppearModifier: ViewModifier {
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(appeared ? 1 : 0.95)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                if reduceMotion {
                    appeared = true
                } else {
                    withAnimation(.appSpring) {
                        appeared = true
                    }
                }
            }
    }
}
```

### Loading States

```swift
struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.5 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

struct ShimmerAnimation: ViewModifier {
    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .white.opacity(0.3), .clear]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 200
                }
            }
    }
}
```

### Button Feedback

```swift
struct ButtonPressModifier: ViewModifier {
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1)
            .animation(reduceMotion ? nil : .appFast, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

extension View {
    func buttonPressEffect() -> some View {
        modifier(ButtonPressModifier())
    }
}
```

### List Animations

```swift
struct ListItemAnimation: ViewModifier {
    let index: Int
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(x: appeared ? 0 : -20)
            .onAppear {
                if reduceMotion {
                    appeared = true
                } else {
                    withAnimation(.appSpring.delay(Double(index) * 0.03)) {
                        appeared = true
                    }
                }
            }
    }
}

extension View {
    func listItemAnimation(index: Int) -> some View {
        modifier(ListItemAnimation(index: index))
    }
}
```

### Content Transitions

```swift
struct AnimatedCounter: View {
    let value: Int

    var body: some View {
        Text("\(value)")
            .contentTransition(.numericText())
            .animation(.appNormal, value: value)
    }
}

struct AnimatedProgress: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .contentTransition(.numericText())
        }
        .animation(.appNormal, value: value)
    }
}
```

### Haptic Feedback Integration (iOS 26 - Use HapticManager)

**IMPORTANT**: Centralize haptics in `HapticManager` (global toggle). Internally use `.sensoryFeedback()` where appropriate:

```swift
// ✅ iOS 26.2 - Centralized haptics
struct FeedbackButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title) {
            HapticManager.shared.impact(.soft)
            action()
        }
    }
}
```

**DO NOT use UIKit haptics** - they're deprecated for SwiftUI on iOS 26:

```swift
// ❌ DEPRECATED on iOS 26
let generator = UIImpactFeedbackGenerator(style: .medium)
generator.impactOccurred()
```

### Matched Geometry Transitions

```swift
struct ExpandableCard: View {
    let id: String
    @Binding var expandedId: String?
    @Namespace private var animation

    var isExpanded: Bool {
        expandedId == id
    }

    var body: some View {
        Group {
            if isExpanded {
                ExpandedCardView()
                    .matchedGeometryEffect(id: id, in: animation)
            } else {
                CollapsedCardView()
                    .matchedGeometryEffect(id: id, in: animation)
                    .onTapGesture {
                        withAnimation(.appSpring) {
                            expandedId = id
                        }
                    }
            }
        }
    }
}
```

## Files to Create

```
CodingBridge/Animation/
├── AnimationTokens.swift          # ~30 lines
├── MotionSafe.swift               # ~40 lines
├── MessageAnimations.swift        # ~60 lines
├── TransitionStyles.swift         # ~50 lines
├── LoadingAnimations.swift        # ~60 lines
├── FeedbackModifiers.swift        # ~40 lines
└── InteractiveAnimations.swift    # ~80 lines
```

## Usage Guidelines

### When to Animate

| Action | Animation | Duration |
|--------|-----------|----------|
| Button press | Scale + haptic | Fast |
| Message appear | Fade + slide | Spring |
| Tool expand | Height change | Spring |
| Sheet present | Scale + fade | Normal |
| Error appear | Shake | Fast |
| Success | Bounce | Spring |
| Loading | Pulse/shimmer | Continuous |

### When NOT to Animate

- User typing
- Scrolling (use native scroll physics)
- Frequent updates (token counts)
- Background operations
- When Reduce Motion is enabled

## Acceptance Criteria

- [ ] Animation tokens defined (including iOS 26.2 menu springs)
- [ ] Motion-safe wrappers implemented
- [ ] Message animations smooth
- [ ] Tool card expand/collapse animated
- [ ] Navigation transitions polished
- [ ] Loading states animated
- [ ] Button feedback uses `.sensoryFeedback()` (no UIKit)
- [ ] Reduce Motion fully supported
- [ ] 60fps on all devices
- [ ] Use Xcode 26.1.1 SwiftUI Instruments for "Skipped Update" analysis
- [ ] Build passes on iOS 26.2+ (Xcode 26.2)

## Testing

```swift
struct AnimationTests: XCTestCase {
    func testMotionSafeWithReduceMotion() {
        // Test that animations are disabled when reduce motion is on
    }

    func testAnimationTokenValues() {
        // Verify animation durations
        let fast = Animation.appFast
        let normal = Animation.appNormal

        // These are opaque types, so we test behavior instead
    }
}
```

## Performance Profiling

Use Instruments to verify:
- [ ] Animations run at 60fps
- [ ] No dropped frames during transitions
- [ ] Memory stable during animations
- [ ] CPU usage reasonable
- [ ] No animation stacking/conflicts
