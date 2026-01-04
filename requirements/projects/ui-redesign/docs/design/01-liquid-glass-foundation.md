# Liquid Glass Foundation


iOS 26 introduces Liquid Glass as the primary design language. All UI elements adopt this system.

### Glass Effects

| Token | API | Use |
|-------|-----|-----|
| `cardGlass` | `.glassEffect()` | Primary card backgrounds |
| `cardGlassUnpadded` | `.glassEffectUnpadded()` | Edge-to-edge glass |
| `sheetGlass` | `.presentationBackground(.glass)` | Sheet backgrounds |
| `widgetGlass` | `.containerBackground(.glass, for: .widget)` | Widget backgrounds |

### Glass Tints

| Token | API | Use |
|-------|-----|-----|
| `errorTint` | `.glassEffect(tint: .red)` | Error states |
| `successTint` | `.glassEffect(tint: .green)` | Success states |
| `warningTint` | `.glassEffect(tint: .orange)` | Warning states |
| `infoTint` | `.glassEffect(tint: .blue)` | Info/tool states |
| `purpleTint` | `.glassEffect(tint: .purple)` | Thinking blocks |

### Implementation

```swift
enum LiquidGlassStyle: Sendable {
    case card
    case cardUnpadded
    case sheet
    case tinted(Color)

    @ViewBuilder
    func apply<Content: View>(to content: Content) -> some View {
        switch self {
        case .card:
            content.glassEffect()
        case .cardUnpadded:
            content.glassEffectUnpadded()
        case .sheet:
            content.presentationBackground(.glass)
        case .tinted(let color):
            content.glassEffect(tint: color)
        }
    }
}

extension View {
    func glassCard() -> some View {
        self.glassEffect()
    }

    func glassCardTinted(_ color: Color) -> some View {
        self.glassEffect(tint: color)
    }
}
```

### Liquid Glass Intensity (iOS 26.2)

iOS 26.2 introduces a user-controllable intensity slider for Liquid Glass. Respect user preference; do not add an in-app override.

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

**Testing**: Test your UI at minimum, medium, and maximum intensity settings.

### Automatic Glass Elements

iOS 26 automatically applies Liquid Glass to:
- `NavigationStack` / `NavigationSplitView` bars
- `TabView` tab bars
- `searchable` overlays
- Standard controls

**Do not apply custom backgrounds** to these - let the system handle glass effects.

---
