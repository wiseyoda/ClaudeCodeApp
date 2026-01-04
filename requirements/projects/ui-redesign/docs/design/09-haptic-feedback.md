# Haptic Feedback


Route all haptics through `HapticManager` (respects global toggle). Internally use `.sensoryFeedback` where appropriate:

| Feedback | Use | Example |
|----------|-----|---------|
| `.impact(weight: .light)` | Light taps | Chip selection |
| `.impact(weight: .medium)` | Standard taps | Button press |
| `.impact(weight: .heavy)` | Important actions | Delete confirm |
| `.impact(flexibility: .soft)` | Soft feedback | Scroll snap |
| `.selection` | Toggle/selection | Picker change |
| `.success` | Completion | Task done |
| `.warning` | Caution | Error shown |
| `.error` | Failure | Action failed |

### Implementation

```swift
Button("Send") {
    HapticManager.shared.impact(.medium)
    sendMessage()
}

Toggle("Enable", isOn: $isEnabled)
    .onChange(of: isEnabled) { _, _ in
        HapticManager.shared.selection()
    }
```

---
