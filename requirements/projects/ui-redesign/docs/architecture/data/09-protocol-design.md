# Protocol Design


```swift
typealias MessageActionHandler = (ChatMessage) -> Void

struct MessageCardActions {
    let onCopy: MessageActionHandler
    let onBookmark: MessageActionHandler
    let onRetry: MessageActionHandler
}

protocol MessageCardProtocol: View {
    var message: ChatMessage { get }
    var actions: MessageCardActions { get }
    var capabilities: MessageCardCapability { get }
    var isExpanded: Bool { get set }
    var iconName: String { get }
    func iconColor(for scheme: ColorScheme) -> Color
    var headerText: String { get }
    var accessibilityLabel: String { get }
    var glassStyle: LiquidGlassStyle { get }
}

struct MessageCardCapability: OptionSet, Sendable {
    let rawValue: Int

    static let collapsible = MessageCardCapability(rawValue: 1 << 0)
    static let copyable = MessageCardCapability(rawValue: 1 << 1)
    static let bookmarkable = MessageCardCapability(rawValue: 1 << 2)
    static let hasActionBar = MessageCardCapability(rawValue: 1 << 3)
    static let hasContextMenu = MessageCardCapability(rawValue: 1 << 4)
    static let hasStatusBanner = MessageCardCapability(rawValue: 1 << 5)
}
```

### Capability Matrix

| Role | Collapsible | Copyable | Bookmarkable | ActionBar | StatusBanner | Glass Style |
|------|-------------|----------|--------------|-----------|--------------|-------------|
| user | No | Yes | Yes | Yes | No | `.card` |
| assistant | No | Yes | Yes | Yes | No | `.card` |
| toolUse | Yes | Yes | No | Minimal | **Yes** | `.tinted(.blue)` |
| toolResult | Yes | Yes | Yes | Minimal | **Yes** | `.card` |
| error | No | Yes | No | No | No | `.tinted(.red)` |
| system | No | No | No | No | No | `.card` |
| resultSuccess | Yes | No | No | No | No | `.tinted(.green)` |
| thinking | Yes | Yes | No | No | No | `.tinted(.purple)` |
| localCommand | Yes | Yes | No | Minimal | No | `.card` |
| localCommandStdout | Yes | Yes | No | Minimal | No | `.card` |

---
