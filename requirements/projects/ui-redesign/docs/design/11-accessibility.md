# Accessibility


### VoiceOver

```swift
// Combine elements
HStack { icon; text }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Project: \(name)")

// Actions
.accessibilityAction(named: "Delete") { delete() }

// Hints
.accessibilityHint("Double tap to expand")
```

### Dynamic Type

```swift
// Use system text styles
Text("Title")
    .font(.headline)

// Custom scaled fonts
Text("Code")
    .font(.system(.body, design: .monospaced))
```

### Reduce Motion

```swift
Image(systemName: "sparkles")
    .modifier(AccessibleSymbolEffect(isActive: isProcessing))

struct AccessibleSymbolEffect: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let isActive: Bool

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.symbolEffect(.breathe, isActive: isActive)
        }
    }
}
```

### High Contrast

```swift
// Use semantic colors
.foregroundStyle(.primary)
.foregroundStyle(.secondary)

// Glass with contrast fallback
.modifier(AccessibleGlassModifier())

struct AccessibleGlassModifier: ViewModifier {
    @Environment(\.accessibilityContrast) var contrast

    func body(content: Content) -> some View {
        if contrast == .increased {
            content
                .background(Color(.systemBackground))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary, lineWidth: 1))
        } else {
            content.glassEffect()
        }
    }
}
```

---
