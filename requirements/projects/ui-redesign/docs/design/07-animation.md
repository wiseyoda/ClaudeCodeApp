# Animation


### Duration Tokens

| Token | Duration | Curve | Use |
|-------|----------|-------|-----|
| `fast` | 0.15s | easeOut | Micro-interactions |
| `normal` | 0.25s | easeInOut | Standard transitions |
| `slow` | 0.35s | easeInOut | Complex transitions |
| `spring` | - | spring(0.5, 0.7, 0.0) | Bouncy feedback |
| `snappy` | - | spring(0.28, 0.85, 0.0) | Quick responses |

### Implementation

```swift
extension Animation {
    static let appFast = Animation.easeOut(duration: 0.15)
    static let appNormal = Animation.easeInOut(duration: 0.25)
    static let appSlow = Animation.easeInOut(duration: 0.35)
    static let appSpring = Animation.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.0)
    static let appSnappy = Animation.spring(response: 0.28, dampingFraction: 0.85, blendDuration: 0.0)
    static let appBounce = Animation.spring(response: 0.6, dampingFraction: 0.55, blendDuration: 0.0)
}
```

### Spring Parameters

| Token | Response | Damping | Blend |
|-------|----------|---------|-------|
| `appSpring` | 0.50 | 0.70 | 0.0 |
| `appSnappy` | 0.28 | 0.85 | 0.0 |
| `appBounce` | 0.60 | 0.55 | 0.0 |

### iOS 26.2 Menu Animations

iOS 26.2 introduces quicker, bouncier menu animations. Match system feel with:

```swift
extension Animation {
    /// iOS 26.2-style menu spring (quicker, bouncier)
    static let menuSpring = Animation.spring(response: 0.35, dampingFraction: 0.65)

    /// iOS 26.2-style context menu appear
    static let contextMenuAppear = Animation.spring(response: 0.3, dampingFraction: 0.7)
}
```

Use for custom menus, popovers, and context menu-like interactions to match iOS 26.2 system behavior.

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
}
```

---
