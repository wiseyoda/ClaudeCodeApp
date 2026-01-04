# Typography


### Type Scale

| Style | Size | Weight | Line Height | Use |
|-------|------|--------|-------------|-----|
| `largeTitle` | 34pt | Bold | 41pt | Hero text |
| `title` | 28pt | Bold | 34pt | Screen titles |
| `title2` | 22pt | Bold | 28pt | Section headers |
| `title3` | 20pt | Semibold | 25pt | Subsections |
| `headline` | 17pt | Semibold | 22pt | Card headers |
| `body` | 17pt | Regular | 22pt | Main content |
| `callout` | 16pt | Regular | 21pt | Callouts |
| `subheadline` | 15pt | Regular | 20pt | Secondary content |
| `footnote` | 13pt | Regular | 18pt | Metadata |
| `caption` | 12pt | Regular | 16pt | Labels |
| `caption2` | 11pt | Regular | 13pt | Minimal labels |

### Line Height Implementation

SwiftUI does not expose explicit line height. Use `lineSpacing` as:

```
lineSpacing = lineHeight - fontSize
```

Example:

```swift
Text(content)
    .font(.system(size: 17, weight: .regular))
    .lineSpacing(22 - 17)
```

### Monospace

| Style | Size | Use |
|-------|------|-----|
| `codeBody` | 14pt | Code blocks |
| `codeSmall` | 12pt | Inline code |
| `terminal` | 14pt | Terminal output |
| `path` | 13pt | File paths |

### Implementation

```swift
extension Font {
    static let codeBody = Font.system(size: 14, design: .monospaced)
    static let codeSmall = Font.system(size: 12, design: .monospaced)
    static let terminal = Font.system(size: 14, design: .monospaced)
    static let pathFont = Font.system(size: 13, design: .monospaced)
}

// Dynamic Type support
extension View {
    func scaledFont(_ style: Font.TextStyle, design: Font.Design = .default) -> some View {
        self.font(.system(style, design: design))
    }
}
```

---
