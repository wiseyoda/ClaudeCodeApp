---
number: 01
title: Design Tokens
phase: phase-0-foundation
priority: High
depends_on: null
acceptance_criteria: 9
files_to_touch: 4
status: pending
completed_by: null
completed_at: null
verified_by: null
verified_at: null
commit: null
spot_checked: false
blocked_reason: null
---

# Issue 01: Design System Foundation

**Phase:** 0 (Foundation)
**Priority:** High
**Status:** Not Started
**Depends On:** None (can be done in parallel with Phase 0)

## Required Documentation

Before starting work on this issue, review these architecture and design documents:

### Design System
- **[Design System Overview](../../docs/design/README.md)** - Complete design system structure
- **[Liquid Glass Foundation](../../docs/design/01-liquid-glass-foundation.md)** - Glass effects and styling
- **[Color System](../../docs/design/02-color-system.md)** - Semantic colors, role colors, tool colors
- **[Typography](../../docs/design/03-typography.md)** - Font system and text styles
- **[Spacing & Layout](../../docs/design/04-spacing-layout.md)** - Spacing tokens and layout grid
- **[Corner Radius](../../docs/design/05-corner-radius.md)** - Corner radius tokens
- **[Shadows](../../docs/design/06-shadows.md)** - Shadow system
- **[Animation](../../docs/design/07-animation.md)** - Animation patterns and timing

### Architecture
- **[Protocol Design](../../docs/architecture/data/09-protocol-design.md)** - MessageCardProtocol, MessageCardCapability
- **[Component Hierarchy](../../docs/architecture/data/08-component-hierarchy.md)** - Message card component structure
- **[Component Patterns](../../docs/design/10-component-patterns.md)** - Reusable component patterns

### Foundation
- **[Design Decisions](../../docs/overview/design-decisions.md)** - High-level design choices
- **[Vision](../../docs/overview/vision.md)** - Overall design vision

### Workflows
- **[Execution Guardrails](../../docs/workflows/guardrails.md)** - Development rules and constraints

## Goal

Create MessageDesignSystem.swift with centralized design tokens for all message card components.

## Scope
- In scope:
  - Define message-card tokens for spacing, typography, color, corner radius, and animation.
  - Provide role-to-style mapping and capabilities via `MessageDesignSystem`.
  - Expose token APIs for message cards, action bars, and status banners.
- Out of scope:
  - App-wide theming overhaul or asset catalog rework.
  - Final redesign for non-message surfaces (settings, terminal, project list).
  - Pre-iOS 26 compatibility shims.

## Non-goals
- Achieve final visual polish for all screens in this issue.
- Replace `Theme.swift` wholesale; only bridge where needed.
- Introduce new message roles beyond current `ChatMessage.Role`.

## Dependencies
- Depends On: None (can be done in parallel with Phase 0).
- Add runtime or tooling dependencies here.

## Touch Set
- Files to create:
  - `CodingBridge/Design/MessageDesignSystem.swift`
- Files to modify:
  - `CodingBridge/Theme.swift` (bridge or forward existing glass/color helpers)
  - `CodingBridge/Views/CLIMessageView.swift` (adopt tokens for spacing/typography)
  - `CodingBridge/Views/MessageActionBar.swift` (adopt tokens for layout)

## Interface Definitions
- No API payload changes.

```swift
enum MessageDesignSystem {
    enum Spacing {
        static let xxs: CGFloat
        static let xs: CGFloat
        static let sm: CGFloat
        static let md: CGFloat
        static let lg: CGFloat
        static let xl: CGFloat
        static let xxl: CGFloat
        static let cardPadding: CGFloat
        static let cardGap: CGFloat
        static let contentIndent: CGFloat
    }

    enum CornerRadius {
        static let sm: CGFloat
        static let md: CGFloat
        static let lg: CGFloat
        static let xl: CGFloat
        static let pill: CGFloat
    }

    enum Animation {
        static let quick: SwiftUI.Animation
        static let smooth: SwiftUI.Animation
        static let gentle: SwiftUI.Animation
    }

    struct RoleStyle {
        let icon: String
        let tint: (ColorScheme) -> Color
        let isCollapsible: Bool
        let defaultExpanded: Bool
        let showHeader: Bool
        let capabilities: MessageCardCapability
    }

    static func style(for role: ChatMessage.Role) -> RoleStyle
}
```

## Edge Cases
- Dynamic Type scaling for large accessibility sizes.
- Dark mode contrast for semantic tints.
- Fallback styling for unknown or legacy roles.
- Token reuse across iPhone and iPad density differences.

## Tests
- [ ] Unit tests updated or added.
- [ ] UI tests updated or added (if user flows change).
## Files to Create

```
CodingBridge/Design/
└── MessageDesignSystem.swift
```

## Implementation

### MessageDesignSystem.swift

```swift
import SwiftUI

/// Design tokens for message card components
/// Separate from Theme.swift - owns message-specific layout tokens
enum MessageDesignSystem {

    // MARK: - Spacing (4pt Grid)

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 24

        // Card-specific
        static let iconColumn: CGFloat = 20
        static let contentIndent: CGFloat = 26
        static let cardPadding: CGFloat = 12
        static let cardGap: CGFloat = 8
    }

    // MARK: - Corner Radius

    enum CornerRadius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 14
        static let xl: CGFloat = 18
        static let pill: CGFloat = 100
    }

    // MARK: - Animation

    enum Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let gentle = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
    }

    // MARK: - Typography

    static func labelFont(scaled: Bool = true) -> Font {
        scaled ? .caption : .system(size: 11, weight: .medium)
    }

    static func bodyFont(scaled: Bool = true) -> Font {
        scaled ? .body : .system(size: 15)
    }

    static func codeFont(scaled: Bool = true) -> Font {
        scaled ? .system(.caption, design: .monospaced) : .system(size: 13, design: .monospaced)
    }

    static func captionFont(scaled: Bool = true) -> Font {
        scaled ? .caption2 : .system(size: 12)
    }

    static func headerFont(scaled: Bool = true) -> Font {
        scaled ? .subheadline.weight(.semibold) : .system(size: 13, weight: .semibold)
    }

    // MARK: - Role Styles

    struct RoleStyle {
        let icon: String
        let tint: (ColorScheme) -> Color
        let isCollapsible: Bool
        let defaultExpanded: Bool
        let showHeader: Bool
        let capabilities: MessageCardCapability

        func tintColor(for scheme: ColorScheme) -> Color {
            tint(scheme)
        }
    }

    static func style(for role: ChatMessage.Role) -> RoleStyle {
        switch role {
        case .user:
            return RoleStyle(
                icon: "person.fill",
                tint: { _ in .primary },
                isCollapsible: false,
                defaultExpanded: true,
                showHeader: true,
                capabilities: [.copyable, .bookmarkable, .hasActionBar, .hasContextMenu]
            )
        case .assistant:
            return RoleStyle(
                icon: "sparkles",
                tint: { _ in .blue },
                isCollapsible: false,
                defaultExpanded: true,
                showHeader: true,
                capabilities: [.copyable, .bookmarkable, .hasActionBar, .hasContextMenu]
            )
        case .toolUse:
            return RoleStyle(
                icon: "wrench.fill",
                tint: { _ in .orange },
                isCollapsible: true,
                defaultExpanded: false,
                showHeader: true,
                capabilities: [.collapsible, .copyable, .hasContextMenu, .hasStatusBanner]
            )
        case .toolResult:
            return RoleStyle(
                icon: "doc.text.fill",
                tint: { _ in .secondary },
                isCollapsible: true,
                defaultExpanded: false,
                showHeader: true,
                capabilities: [.collapsible, .copyable, .bookmarkable, .hasContextMenu, .hasStatusBanner]
            )
        case .error:
            return RoleStyle(
                icon: "exclamationmark.triangle.fill",
                tint: { _ in .red },
                isCollapsible: false,
                defaultExpanded: true,
                showHeader: true,
                capabilities: [.copyable, .hasContextMenu]
            )
        case .system:
            return RoleStyle(
                icon: "info.circle.fill",
                tint: { _ in .secondary },
                isCollapsible: false,
                defaultExpanded: true,
                showHeader: false,
                capabilities: []
            )
        case .resultSuccess:
            return RoleStyle(
                icon: "checkmark.circle.fill",
                tint: { _ in .green },
                isCollapsible: true,
                defaultExpanded: false,
                showHeader: true,
                capabilities: [.collapsible]
            )
        case .thinking:
            return RoleStyle(
                icon: "brain",
                tint: { _ in .purple },
                isCollapsible: true,
                defaultExpanded: false,
                showHeader: true,
                capabilities: [.collapsible, .copyable, .hasContextMenu]
            )
        case .localCommand:
            return RoleStyle(
                icon: "terminal.fill",
                tint: { _ in .cyan },
                isCollapsible: true,
                defaultExpanded: true,
                showHeader: true,
                capabilities: [.collapsible, .copyable, .hasContextMenu]
            )
        case .localCommandStdout:
            return RoleStyle(
                icon: "text.alignleft",
                tint: { _ in .secondary },
                isCollapsible: true,
                defaultExpanded: true,
                showHeader: true,
                capabilities: [.collapsible, .copyable, .hasContextMenu]
            )
        }
    }
}

// MARK: - Capability OptionSet

struct MessageCardCapability: OptionSet, Sendable {
    let rawValue: Int

    static let collapsible = MessageCardCapability(rawValue: 1 << 0)
    static let copyable = MessageCardCapability(rawValue: 1 << 1)
    static let bookmarkable = MessageCardCapability(rawValue: 1 << 2)
    static let hasActionBar = MessageCardCapability(rawValue: 1 << 3)
    static let hasContextMenu = MessageCardCapability(rawValue: 1 << 4)
    static let hasStatusBanner = MessageCardCapability(rawValue: 1 << 5)

    static let all: MessageCardCapability = [.collapsible, .copyable, .bookmarkable, .hasActionBar, .hasContextMenu, .hasStatusBanner]
    static let minimal: MessageCardCapability = [.copyable, .hasContextMenu]
}
```

## Acceptance Criteria

- [ ] MessageDesignSystem.swift created in CodingBridge/Design/
- [ ] All spacing tokens defined (4pt grid)
- [ ] All corner radius tokens defined
- [ ] Animation presets defined
- [ ] Typography functions defined
- [ ] RoleStyle struct with all 10 roles configured
- [ ] MessageCardCapability OptionSet defined
- [ ] File linked in project.pbxproj
- [ ] Build passes

## Testing

```swift
class MessageDesignSystemTests: XCTestCase {
    func testSpacingValues() {
        XCTAssertEqual(MessageDesignSystem.Spacing.md, 8)
        XCTAssertEqual(MessageDesignSystem.Spacing.iconColumn, 20)
    }

    func testRoleStyles() {
        let assistantStyle = MessageDesignSystem.style(for: .assistant)
        XCTAssertEqual(assistantStyle.icon, "sparkles")
        XCTAssertFalse(assistantStyle.isCollapsible)
    }

    func testCapabilities() {
        let style = MessageDesignSystem.style(for: .user)
        XCTAssertTrue(style.capabilities.contains(.copyable))
        XCTAssertTrue(style.capabilities.contains(.bookmarkable))
        XCTAssertFalse(style.capabilities.contains(.collapsible))
    }
}
```
