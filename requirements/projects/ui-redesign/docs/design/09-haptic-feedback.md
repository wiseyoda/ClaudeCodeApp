# Haptic Feedback


Use `.sensoryFeedback` modifier for haptics:

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
    sendMessage()
}
.sensoryFeedback(.impact(weight: .medium), trigger: sendCount)

Toggle("Enable", isOn: $isEnabled)
    .sensoryFeedback(.selection, trigger: isEnabled)
```

---
