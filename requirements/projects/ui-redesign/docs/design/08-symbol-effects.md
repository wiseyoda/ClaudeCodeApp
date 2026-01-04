# Symbol Effects


iOS 26 symbol effects for dynamic icons:

| Effect | Use | Trigger |
|--------|-----|---------|
| `.breathe` | Streaming/processing | `isActive: isStreaming` |
| `.breathe.pulse` | Active indicator | `isActive: isActive` |
| `.wiggle` | Attention/unread | `value: count` |
| `.bounce.up.byLayer` | Success | `value: trigger` |
| `.variableColor.iterative` | Loading | `isActive: isLoading` |
| `.rotate` | Processing | `isActive: isProcessing` |
| `.replace` | State change | Automatic |

### Examples

```swift
// Streaming indicator
Image(systemName: "sparkles")
    .symbolEffect(.breathe, isActive: isStreaming)

// Success bounce
Image(systemName: "checkmark.circle.fill")
    .symbolEffect(.bounce.up.byLayer, value: successTrigger)

// Loading
Image(systemName: "circle.dashed")
    .symbolEffect(.variableColor.iterative, isActive: isLoading)

// Unread count
Image(systemName: "bell.badge")
    .symbolEffect(.wiggle, value: unreadCount)
```

---
