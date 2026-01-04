# Issue 17: Liquid Glass Design System

**Phase:** 0 (Foundation)
**Priority:** High
**Status:** Not Started
**Depends On:** Issue #01 (Design Tokens)
**Target:** iOS 26.2, Xcode 26.2, Swift 6.2.1

## Goal

Implement iOS 26.2's Liquid Glass design language throughout the app, replacing all legacy material effects.

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- Depends On: Issue #01 (Design Tokens).
- Add runtime or tooling dependencies here.

## Touch Set
- Files to create: TBD.
- Files to modify: TBD.

## Interface Definitions
- List new or changed models, protocols, and API payloads.

## Tests
- [ ] Unit tests updated or added.
- [ ] UI tests updated or added (if user flows change).
## Background

iOS 26 introduces Liquid Glass as the primary design language. It provides:
- Adaptive glass effects that respond to background content
- Built-in depth and layering
- Automatic dark/light mode adaptation
- Consistent corner radii and shadows

### iOS 26.1/26.2 Updates

| Version | Change |
|---------|--------|
| iOS 26.1 | Fixed toggle appearance inside glass contexts |
| iOS 26.2 | User-controllable intensity slider in Settings |
| iOS 26.2 | Slider respects intensity settings |

## API Reference

### Core Modifiers

| Modifier | Use |
|----------|-----|
| `.glassEffect()` | Standard glass background for cards |
| `.glassEffectUnpadded()` | Edge-to-edge glass without internal padding |
| `.glassEffect(tint: Color)` | Tinted glass for semantic meaning |
| `.containerBackground(.glass, for: .widget)` | Glass for widgets |
| `.containerBackground(.glass, for: .sheet)` | Glass for sheets |

### Tint Colors

| Semantic | Color | Use |
|----------|-------|-----|
| Error | `.red` | Error cards, failed operations |
| Success | `.green` | Success states, completed tasks |
| Warning | `.orange` | Warnings, attention needed |
| Tool | `.blue` | Tool use cards |
| Thinking | `.purple` | Thinking/reasoning blocks |
| Info | `.cyan` | Informational cards |

## Implementation

### LiquidGlassStyles.swift

```swift
import SwiftUI

/// Liquid Glass style configurations for iOS 26
enum LiquidGlassStyle: Sendable {
    case card
    case cardUnpadded
    case tinted(Color)

    @ViewBuilder
    func apply<Content: View>(to content: Content) -> some View {
        switch self {
        case .card:
            content.glassEffect()
        case .cardUnpadded:
            content.glassEffectUnpadded()
        case .tinted(let color):
            content.glassEffect(tint: color)
        }
    }
}

// MARK: - Semantic Styles

extension LiquidGlassStyle {
    static let error = LiquidGlassStyle.tinted(.red)
    static let success = LiquidGlassStyle.tinted(.green)
    static let warning = LiquidGlassStyle.tinted(.orange)
    static let tool = LiquidGlassStyle.tinted(.blue)
    static let thinking = LiquidGlassStyle.tinted(.purple)
    static let info = LiquidGlassStyle.tinted(.cyan)
}

// MARK: - View Extension

extension View {
    /// Apply Liquid Glass styling with optional tint
    func liquidGlass(_ style: LiquidGlassStyle = .card) -> some View {
        style.apply(to: self)
    }

    /// Apply message card styling with glass and padding
    func messageCardStyle(_ style: LiquidGlassStyle = .card) -> some View {
        self
            .padding(MessageDesignSystem.Spacing.cardPadding)
            .liquidGlass(style)
    }
}
```

### Role-to-Glass Mapping

```swift
extension ChatMessage.Role {
    var glassStyle: LiquidGlassStyle {
        switch self {
        case .user, .assistant:
            return .card
        case .toolUse:
            return .tool
        case .toolResult:
            return .card
        case .error:
            return .error
        case .system:
            return .card
        case .resultSuccess:
            return .success
        case .thinking:
            return .thinking
        case .localCommand, .localCommandStdout:
            return .card
        }
    }
}
```

### Card Implementation

```swift
struct ChatCardView: View, MessageCardProtocol {
    let message: ChatMessage

    var body: some View {
        VStack(alignment: .leading, spacing: MessageDesignSystem.Spacing.sm) {
            CardHeaderView(message: message)
            Text(message.content)
                .font(MessageDesignSystem.bodyFont())
            CardFooterView(message: message)
        }
        .messageCardStyle(message.role.glassStyle)
    }
}

struct ToolCardView: View, MessageCardProtocol {
    let message: ChatMessage
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: MessageDesignSystem.Spacing.sm) {
            CardHeaderView(message: message, isExpanded: $isExpanded)
            if isExpanded {
                ToolContentView(message: message)
            }
        }
        .messageCardStyle(.tool)
    }
}

struct ErrorCardView: View {
    let message: ChatMessage

    var body: some View {
        HStack(spacing: MessageDesignSystem.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message.content)
                .font(MessageDesignSystem.bodyFont())
        }
        .messageCardStyle(.error)
    }
}
```

## Navigation & System Components

iOS 26 automatically applies Liquid Glass to system components. **Do not apply custom backgrounds**:

```swift
// CORRECT: Let system handle glass
NavigationStack {
    ContentView()
}

// WRONG: Interferes with system glass
NavigationStack {
    ContentView()
}
.background(.ultraThinMaterial)  // Remove this
```

### Components That Get Automatic Glass

- `NavigationStack` / `NavigationSplitView` bars
- `TabView` tab bars
- `searchable` overlays
- Standard buttons and controls
- `ToolbarItem` contents

## Sheet Styling

```swift
struct SettingsSheet: View {
    var body: some View {
        NavigationStack {
            Form {
                // Settings content
            }
        }
        .presentationBackground(.glass)  // iOS 26 glass sheet
    }
}

// Or for custom sheets
struct CustomSheet: View {
    var body: some View {
        VStack {
            // Content
        }
        .containerBackground(.glass, for: .sheet)
    }
}
```

## Migration Guide

### Replace Materials

| Before (iOS 17) | After (iOS 26) |
|-----------------|----------------|
| `.background(.ultraThinMaterial)` | `.glassEffect()` |
| `.background(.thinMaterial)` | `.glassEffect()` |
| `.background(.regularMaterial)` | `.glassEffect()` |
| `.background(.thickMaterial)` | `.glassEffect()` |
| `.background(.bar)` | Remove (automatic) |
| Custom blur + color | `.glassEffect(tint: color)` |

### Remove Custom Backgrounds from System Components

```swift
// Before
NavigationStack {
    content
}
.toolbarBackground(.visible, for: .navigationBar)
.toolbarBackground(.ultraThinMaterial, for: .navigationBar)

// After - just remove the modifiers
NavigationStack {
    content
}
```

## Files to Create

```
CodingBridge/Design/
└── LiquidGlassStyles.swift    # ~100 lines
```

## Files to Modify

| File | Changes |
|------|---------|
| `Theme.swift` | Remove material references, add glass compatibility |
| `MessageDesignSystem.swift` | Add glass style mappings |
| All card views | Replace `.background(.material)` with `.glassEffect()` |
| All sheets | Add `.presentationBackground(.glass)` |
| Navigation views | Remove custom toolbar backgrounds |

## iOS 26.2 Intensity Support

iOS 26.2 introduces a user-controllable intensity slider for Liquid Glass. Apps should respect this preference:

### AdaptiveGlassModifier

```swift
struct AdaptiveGlassModifier: ViewModifier {
    @Environment(\.liquidGlassIntensity) var intensity

    func body(content: Content) -> some View {
        content.glassEffect(intensity: intensity)
    }
}

extension View {
    /// Apply glass effect that respects user's intensity preference
    func adaptiveGlass() -> some View {
        modifier(AdaptiveGlassModifier())
    }
}
```

### Updated LiquidGlassStyle

```swift
enum LiquidGlassStyle: Sendable {
    case card
    case cardUnpadded
    case tinted(Color)
    case adaptive  // NEW: Respects user intensity

    @ViewBuilder
    func apply<Content: View>(to content: Content) -> some View {
        switch self {
        case .card:
            content.glassEffect()
        case .cardUnpadded:
            content.glassEffectUnpadded()
        case .tinted(let color):
            content.glassEffect(tint: color)
        case .adaptive:
            content.adaptiveGlass()
        }
    }
}
```

### Testing Intensity

Test your UI at all three intensity levels:
1. **Minimum**: Glass nearly invisible, text must remain readable
2. **Medium**: Default system setting
3. **Maximum**: Full glass effect

```swift
#Preview("Glass Intensity Levels") {
    ForEach([0.3, 0.6, 1.0], id: \.self) { intensity in
        Text("Intensity: \(intensity, specifier: "%.1f")")
            .padding()
            .glassEffect(intensity: intensity)
    }
}
```

## Edge Cases

- Increase Contrast enabled: fall back to opaque backgrounds with stroke (see Issue #38).
- Reduce Transparency enabled: reduce blur intensity and avoid tinted glass.
- High-contrast wallpapers: ensure text contrast meets WCAG AA.
- **iOS 26.2 Intensity at minimum**: Ensure content remains visible and readable.

## Acceptance Criteria

- [ ] `LiquidGlassStyles.swift` created with all style variants
- [ ] Role-to-glass mapping implemented
- [ ] All message cards use `.glassEffect()` or tinted variants
- [ ] All sheets use glass presentation background
- [ ] No `.ultraThinMaterial` or similar in codebase
- [ ] Navigation bars use system glass (no custom backgrounds)
- [ ] Dark mode renders correctly
- [ ] Build passes on iOS 26.2+ (Xcode 26.2)
- [ ] AdaptiveGlassModifier respects user intensity preference
- [ ] UI tested at min/med/max intensity settings
- [ ] Toggles and sliders render correctly in glass contexts (iOS 26.1+ fix)

## Testing

### Visual Testing

```swift
#Preview("Liquid Glass Cards") {
    VStack(spacing: 16) {
        Text("User message")
            .messageCardStyle(.card)

        Text("Tool use")
            .messageCardStyle(.tool)

        Text("Error message")
            .messageCardStyle(.error)

        Text("Success message")
            .messageCardStyle(.success)

        Text("Thinking")
            .messageCardStyle(.thinking)
    }
    .padding()
    .background(Color.blue.gradient)  // Test glass over colored background
}
```

### Automated Testing

```swift
struct LiquidGlassTests: XCTestCase {
    func testGlassStyleMapping() {
        XCTAssertEqual(ChatMessage.Role.error.glassStyle, .error)
        XCTAssertEqual(ChatMessage.Role.toolUse.glassStyle, .tool)
        XCTAssertEqual(ChatMessage.Role.thinking.glassStyle, .thinking)
    }
}
```
