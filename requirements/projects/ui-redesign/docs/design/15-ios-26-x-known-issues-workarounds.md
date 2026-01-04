# iOS 26.x Known Issues & Workarounds


### @FocusState in safeAreaBar (iOS 26.0-26.1)

Using `@FocusState` with controls inside `safeAreaBar` causes layout glitches.

**Workaround**: Use `.safeAreaInset(edge: .bottom)` instead:

```swift
// ❌ Problematic in iOS 26.0-26.1
.safeAreaBar(edge: .bottom) {
    TextField("Message", text: $text)
        .focused($isFocused)  // Layout glitch
}

// ✅ Use safeAreaInset instead
.safeAreaInset(edge: .bottom) {
    TextField("Message", text: $text)
        .focused($isFocused)
        .glassEffect()
}
```

### navigationLinkIndicatorVisibility Crash (Fixed in iOS 26.1)

`navigationLinkIndicatorVisibility(.hidden)` crashed on iOS 26.0.

**Status**: Fixed in iOS 26.1. Safe to use with iOS 26.2 deployment target.

### Liquid Glass Toggle/Slider Appearance

- iOS 26.1: Fixed toggle appearance in glass contexts
- iOS 26.2: Slider now respects intensity settings

Test toggles and sliders inside `.glassEffect()` containers.

---
