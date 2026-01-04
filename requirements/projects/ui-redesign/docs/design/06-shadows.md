# Shadows


Only use shadows for non-glass elements or elevated overlays.

| Token | Color | Opacity | Radius | Offset | Use |
|-------|-------|---------|--------|--------|-----|
| `cardShadow` | `#000000` | 0.12 | 12 | (0, 6) | Floating cards |
| `sheetShadow` | `#000000` | 0.20 | 24 | (0, 12) | Modal sheets |
| `focusShadow` | `#0A84FF` | 0.35 | 16 | (0, 0) | Focus ring |

```swift
RoundedRectangle(cornerRadius: 12)
    .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
```

---
