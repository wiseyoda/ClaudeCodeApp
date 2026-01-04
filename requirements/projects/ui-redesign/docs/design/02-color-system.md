# Color System


### Semantic Colors

| Token | Light | Dark | Use |
|-------|-------|------|-----|
| `primary` | System | System | Main text |
| `secondary` | System | System | Supporting text |
| `tertiary` | System | System | Subtle text |
| `accent` | App accent | App accent | Interactive elements |
| `destructive` | `.red` | `.red` | Delete actions |
| `success` | `.green` | `.green` | Success states |
| `warning` | `.orange` | `.orange` | Warnings |

### Role Colors

| Role | Color | Use |
|------|-------|-----|
| `user` | `.primary` | User messages |
| `assistant` | `.blue` | Claude messages |
| `toolUse` | `.orange` | Tool invocations |
| `toolResult` | `.secondary` | Tool outputs |
| `error` | `.red` | Error messages |
| `thinking` | `.purple` | Reasoning blocks |
| `system` | `.secondary` | System messages |
| `success` | `.green` | Completion states |

### Tool Colors

| Tool | Color | Icon |
|------|-------|------|
| Bash | `.orange` | `terminal` |
| Read | `.blue` | `doc.text` |
| Write | `.green` | `doc.badge.plus` |
| Edit | `.yellow` | `pencil` |
| Glob | `.cyan` | `magnifyingglass` |
| Grep | `.purple` | `text.magnifyingglass` |
| Task | `.pink` | `person.2` |
| TodoWrite | `.indigo` | `checklist` |
| WebFetch | `.teal` | `globe` |

### Custom Palette (Hex)

These hex values mirror system colors for consistency across light/dark.

| Token | Light | Dark |
|-------|-------|------|
| `toolBash` | `#FF9500` | `#FF9F0A` |
| `toolRead` | `#007AFF` | `#0A84FF` |
| `toolWrite` | `#34C759` | `#30D158` |
| `toolEdit` | `#FFCC00` | `#FFD60A` |
| `toolGlob` | `#5AC8FA` | `#64D2FF` |
| `toolGrep` | `#AF52DE` | `#BF5AF2` |
| `toolTask` | `#FF2D55` | `#FF375F` |
| `toolTodoWrite` | `#5856D6` | `#5E5CE6` |
| `toolWebFetch` | `#00C7BE` | `#40C8E0` |

```swift
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
```

### File Type Colors

| Extension | Color |
|-----------|-------|
| `.swift` | `.orange` |
| `.ts`, `.js` | `.yellow` |
| `.py` | `.green` |
| `.json`, `.yaml` | `.purple` |
| `.md` | `.cyan` |
| Folder | `.blue` |
| Default | `.secondary` |

---
