# Issue 03: Protocol & Router

**Phase:** 2 (Core Views)
**Priority:** High
**Status:** Not Started
**Depends On:** Issue 01 (Design Tokens), Issue 02 (Reusable Components)

## Goal

Create the MessageCardProtocol and MessageCardRouter that routes messages to the appropriate category view.

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- Depends On: Issue 01 (Design Tokens), Issue 02 (Reusable Components).
- Add runtime or tooling dependencies here.

## Touch Set
- Files to create: TBD.
- Files to modify: TBD.

## Edge Cases
- TBD.

## Tests
- [ ] Unit tests updated or added.
- [ ] UI tests updated or added (if user flows change).
## Files to Create

```
CodingBridge/Views/Messages/
├── MessageCardProtocol.swift    # Protocol + cache
└── MessageCardRouter.swift      # Routes to category views
```

## Interface Definitions

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
```

## Implementation

### MessageCardProtocol.swift

```swift
import SwiftUI

/// Protocol for all message card views
protocol MessageCardProtocol: View {
    var message: ChatMessage { get }
    var actions: MessageCardActions { get }
    var capabilities: MessageCardCapability { get }
    var isExpanded: Bool { get set }

    // Computed from MessageDesignSystem.style(for:)
    var style: MessageDesignSystem.RoleStyle { get }

    // Convenience accessors
    var iconName: String { get }
    func iconColor(for scheme: ColorScheme) -> Color
    var headerText: String { get }
    var glassStyle: LiquidGlassStyle { get }

    // For accessibility
    var accessibilityLabel: String { get }
}

// MARK: - Default Implementations

extension MessageCardProtocol {
    var style: MessageDesignSystem.RoleStyle {
        MessageDesignSystem.style(for: message.role)
    }

    var iconName: String {
        style.icon
    }

    func iconColor(for scheme: ColorScheme) -> Color {
        style.tintColor(for: scheme)
    }

    var capabilities: MessageCardCapability {
        style.capabilities
    }

    var glassStyle: LiquidGlassStyle {
        message.role.glassStyle
    }

    var headerText: String {
        MessageCardCache.computeHeader(for: message)
    }
}

// MARK: - Cache for Performance

/// Pre-computed values to avoid recalculation during scroll
struct MessageCardCache {
    let iconName: String
    let tintColor: Color
    let isCollapsible: Bool
    let capabilities: MessageCardCapability
    let headerText: String
    let contentPreview: String?

    init(message: ChatMessage, colorScheme: ColorScheme) {
        let style = MessageDesignSystem.style(for: message.role)
        self.iconName = style.icon
        self.tintColor = style.tintColor(for: colorScheme)
        self.isCollapsible = style.isCollapsible
        self.capabilities = style.capabilities
        self.headerText = Self.computeHeader(for: message)
        self.contentPreview = Self.computePreview(for: message)
    }

    static func computeHeader(for message: ChatMessage) -> String {
        switch message.role {
        case .user: return "You"
        case .assistant: return "Claude"
        case .toolUse: return message.toolName ?? "Tool"
        case .toolResult: return "Result"
        case .error: return "Error"
        case .system: return "System"
        case .resultSuccess: return "Success"
        case .thinking: return "Thinking"
        case .localCommand: return "Command"
        case .localCommandStdout: return "Output"
        }
    }

    private static func computePreview(for message: ChatMessage) -> String? {
        guard message.content.count > 100 else { return nil }
        return String(message.content.prefix(100)) + "..."
    }
}
```

### MessageCardRouter.swift

```swift
import SwiftUI

/// Routes messages to the appropriate category card view
struct MessageCardRouter: View {
    let message: ChatMessage
    let isBookmarked: Bool
    let actions: MessageCardActions

    @State private var isExpanded: Bool
    @Environment(\.colorScheme) private var colorScheme

    // Pre-computed cache
    private let cache: MessageCardCache

    init(
        message: ChatMessage,
        isBookmarked: Bool = false,
        actions: MessageCardActions = MessageCardActions(
            onCopy: { _ in },
            onBookmark: { _ in },
            onRetry: { _ in }
        )
    ) {
        self.message = message
        self.isBookmarked = isBookmarked
        self.actions = actions

        // Initialize expanded state from style
        let style = MessageDesignSystem.style(for: message.role)
        self._isExpanded = State(initialValue: style.defaultExpanded)

        // Pre-compute cache (colorScheme not available yet, use .light as default)
        self.cache = MessageCardCache(message: message, colorScheme: .light)
    }

    var body: some View {
        routeToCard()
    }

    @ViewBuilder
    private func routeToCard() -> some View {
        switch message.role {
        // Chat messages
        case .user, .assistant:
            ChatCardView(
                message: message,
                isExpanded: $isExpanded,
                isBookmarked: isBookmarked,
                actions: actions
            )

        // Tool messages
        case .toolUse, .toolResult:
            ToolCardView(
                message: message,
                isExpanded: $isExpanded,
                actions: actions
            )

        // System messages
        case .error, .system, .resultSuccess, .thinking, .localCommand, .localCommandStdout:
            SystemCardView(
                message: message,
                isExpanded: $isExpanded,
                actions: actions
            )
        }
    }
}

// MARK: - Compatibility Alias

/// Alias for backwards compatibility during migration
typealias CLIMessageView = MessageCardRouter

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 12) {
            MessageCardRouter(message: .preview(.user, "Hello!"))
            MessageCardRouter(message: .preview(.assistant, "Hi there!"))
            MessageCardRouter(message: .preview(.toolUse, "Reading file..."))
            MessageCardRouter(message: .preview(.error, "Something went wrong"))
        }
        .padding()
    }
}

// MARK: - Preview Helpers

extension ChatMessage {
    static func preview(_ role: Role, _ content: String) -> ChatMessage {
        ChatMessage(
            id: UUID().uuidString,
            role: role,
            content: content,
            timestamp: Date()
        )
    }
}
```

## Routing Logic

| Role | Routes To |
|------|-----------|
| user | ChatCardView |
| assistant | ChatCardView |
| toolUse | ToolCardView |
| toolResult | ToolCardView |
| error | SystemCardView |
| system | SystemCardView |
| resultSuccess | SystemCardView |
| thinking | SystemCardView |
| localCommand | SystemCardView |
| localCommandStdout | SystemCardView |

## Acceptance Criteria

- [ ] MessageCardProtocol defined with default implementations
- [ ] MessageCardCache for performance optimization
- [ ] MessageCardRouter routes all 10 roles correctly
- [ ] `typealias CLIMessageView = MessageCardRouter` for compatibility
- [ ] Preview shows all message types
- [ ] Files linked in project.pbxproj
- [ ] Build passes

## Notes

The router creates placeholder views initially (ChatCardView, ToolCardView, SystemCardView). These will be implemented in Phase 4.

For the initial build to pass, create stub implementations:

```swift
struct ChatCardView: View {
    let message: ChatMessage
    @Binding var isExpanded: Bool
    let isBookmarked: Bool
    let onCopy: () -> Void
    let onBookmark: () -> Void

    var body: some View {
        Text("ChatCardView placeholder")
    }
}

// Similar stubs for ToolCardView and SystemCardView
```

## Test Examples

TBD. Add XCTest examples before implementation.
