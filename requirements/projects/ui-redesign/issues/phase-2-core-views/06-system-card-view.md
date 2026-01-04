# Issue 06: SystemCardView

**Phase:** 2 (Core Views)
**Priority:** High
**Status:** Not Started
**Depends On:** Issue 03 (Protocol & Router)

## Goal

Implement SystemCardView for error, system, and other non-chat/tool messages.

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- Depends On: Issue 03 (Protocol & Router).
- Add runtime or tooling dependencies here.

## Touch Set
- Files to create: TBD.
- Files to modify: TBD.

## Interface Definitions
- List new or changed models, protocols, and API payloads.

## Edge Cases
- TBD.

## Tests
- [ ] Unit tests updated or added.
- [ ] UI tests updated or added (if user flows change).
## File to Create

```
CodingBridge/Views/Messages/Cards/
└── SystemCardView.swift (~300 lines)
```

## Roles Handled

- `error` - Error messages
- `system` - System notifications
- `resultSuccess` - Task completion
- `thinking` - Claude's reasoning
- `localCommand` - Slash commands
- `localCommandStdout` - Command output

## System Message Types

System messages include subtype metadata that must map to distinct UI:

| Type | UI Treatment |
|------|--------------|
| `stop_hook_summary` | Collapsible summary card |
| `compact_boundary` | Compact divider card |
| `local_command` | Local command card (command + args) |
| `api_error` | Distinct error card with remediation |
| `unknown` | Fallback system card |

## Features

| Role | Icon | Collapsible | Background |
|------|------|-------------|------------|
| error | exclamationmark.triangle.fill | No | Red tint |
| system | info.circle.fill | No | Gray |
| resultSuccess | checkmark.circle.fill | Yes | Green tint |
| thinking | brain | Yes | Purple tint |
| localCommand | terminal.fill | Yes | Cyan tint |
| localCommandStdout | text.alignleft | Yes | Gray |
| actionBar | copy/share/bookmark as appropriate | Yes | N/A |

## Implementation

```swift
import SwiftUI

struct SystemCardView: View {
    let message: ChatMessage
    @Binding var isExpanded: Bool
    let onCopy: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var style: MessageDesignSystem.RoleStyle {
        MessageDesignSystem.style(for: message.role)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if style.isCollapsible {
                collapsibleContent
            } else {
                staticContent
            }

            MessageActions(
                onCopy: onCopy,
                onBookmark: {},
                isBookmarked: false
            )
            .padding(.top, MessageDesignSystem.Spacing.sm)
        }
        .padding(MessageDesignSystem.Spacing.cardPadding)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: MessageDesignSystem.CornerRadius.md))
        .contextMenu { contextMenuItems }
    }

    // MARK: - Collapsible Content

    private var collapsibleContent: some View {
        CollapsibleSection(isExpanded: $isExpanded) {
            header
        } content: {
            messageContent
        }
    }

    // MARK: - Static Content

    private var staticContent: some View {
        VStack(alignment: .leading, spacing: MessageDesignSystem.Spacing.sm) {
            if style.showHeader {
                header
            }
            messageContent
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: MessageDesignSystem.Spacing.sm) {
            Image(systemName: style.icon)
                .foregroundStyle(style.tintColor(for: colorScheme))
                .frame(width: MessageDesignSystem.Spacing.iconColumn)

            Text(headerText)
                .font(MessageDesignSystem.headerFont())

            Spacer()

            if !isExpanded && style.isCollapsible {
                Text(contentPreview)
                    .font(MessageDesignSystem.captionFont())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var headerText: String {
        switch message.role {
        case .error: return "Error"
        case .system: return "System"
        case .resultSuccess: return "Complete"
        case .thinking: return "Thinking"
        case .localCommand: return commandName
        case .localCommandStdout: return "Output"
        default: return ""
        }
    }

    private var commandName: String {
        // Extract command name from /command format
        if message.content.hasPrefix("/") {
            let parts = message.content.dropFirst().components(separatedBy: " ")
            return "/" + (parts.first ?? "command")
        }
        return "Command"
    }

    private var contentPreview: String {
        String(message.content.prefix(40))
    }

    // MARK: - Content

    @ViewBuilder
    private var messageContent: some View {
        switch message.role {
        case .error:
            errorContent
        case .system:
            systemContent
        case .resultSuccess:
            successContent
        case .thinking:
            thinkingContent
        case .localCommand:
            commandContent
        case .localCommandStdout:
            outputContent
        default:
            Text(message.content)
        }
    }

    // Map system message subtype metadata to UI variations.
    private var systemContent: some View {
        switch message.systemType {
        case .stopHookSummary:
            stopHookSummaryContent
        case .compactBoundary:
            compactBoundaryContent
        case .localCommand:
            commandContent
        case .apiError:
            apiErrorContent
        case .unknown, .none:
            defaultSystemContent
        }
    }

    private var errorContent: some View {
        VStack(alignment: .leading, spacing: MessageDesignSystem.Spacing.sm) {
            Text(message.content)
                .font(MessageDesignSystem.bodyFont())
                .foregroundStyle(.red)

            if let suggestion = extractSuggestion() {
                Text(suggestion)
                    .font(MessageDesignSystem.captionFont())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.leading, MessageDesignSystem.Spacing.contentIndent)
    }

    private var defaultSystemContent: some View {
        Text(message.content)
            .font(MessageDesignSystem.captionFont())
            .foregroundStyle(.secondary)
            .padding(.leading, MessageDesignSystem.Spacing.contentIndent)
    }

    private var stopHookSummaryContent: some View {
        Text(message.content)
            .font(MessageDesignSystem.bodyFont())
            .padding(.leading, MessageDesignSystem.Spacing.contentIndent)
    }

    private var compactBoundaryContent: some View {
        Divider()
            .padding(.vertical, MessageDesignSystem.Spacing.xs)
    }

    private var apiErrorContent: some View {
        VStack(alignment: .leading, spacing: MessageDesignSystem.Spacing.xs) {
            Text("API Error")
                .font(MessageDesignSystem.headerFont())
            Text(message.content)
                .font(MessageDesignSystem.captionFont())
                .foregroundStyle(.secondary)
        }
        .padding(.leading, MessageDesignSystem.Spacing.contentIndent)
    }

    private var successContent: some View {
        VStack(alignment: .leading, spacing: MessageDesignSystem.Spacing.xs) {
            HStack(spacing: MessageDesignSystem.Spacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Task completed successfully")
                    .font(MessageDesignSystem.bodyFont())
            }

            if !message.content.isEmpty {
                Text(message.content)
                    .font(MessageDesignSystem.captionFont())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.leading, MessageDesignSystem.Spacing.contentIndent)
    }

    private var thinkingContent: some View {
        VStack(alignment: .leading, spacing: MessageDesignSystem.Spacing.sm) {
            Text(message.content)
                .font(MessageDesignSystem.bodyFont())
                .italic()
                .foregroundStyle(.secondary)
        }
        .padding(.leading, MessageDesignSystem.Spacing.contentIndent)
    }

    private var commandContent: some View {
        VStack(alignment: .leading, spacing: MessageDesignSystem.Spacing.xs) {
            HStack {
                Text("$")
                    .foregroundStyle(.cyan)
                Text(message.content)
                    .font(MessageDesignSystem.codeFont())
            }
            .padding(MessageDesignSystem.Spacing.sm)
            .background(Color.black.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: MessageDesignSystem.CornerRadius.sm))
        }
        .padding(.leading, MessageDesignSystem.Spacing.contentIndent)
    }

    private var outputContent: some View {
        Text(message.content)
            .font(MessageDesignSystem.codeFont())
            .textSelection(.enabled)
            .padding(.leading, MessageDesignSystem.Spacing.contentIndent)
    }

    // MARK: - Background

    private var cardBackground: some View {
        Group {
            switch message.role {
            case .error:
                Color.red.opacity(0.1)
            case .resultSuccess:
                Color.green.opacity(0.1)
            case .thinking:
                Color.purple.opacity(0.05)
            case .localCommand:
                Color.cyan.opacity(0.05)
            default:
                Color(.secondarySystemBackground)
            }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuItems: some View {
        if style.capabilities.contains(.copyable) {
            Button {
                onCopy()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
    }

    // MARK: - Helpers

    private func extractSuggestion() -> String? {
        // Extract suggestion from error message if present
        if message.content.contains("Try:") {
            return message.content.components(separatedBy: "Try:").last?.trimmingCharacters(in: .whitespaces)
        }
        return nil
    }
}

// MARK: - Preview

#Preview("Error") {
    SystemCardView(
        message: ChatMessage(
            id: "1",
            role: .error,
            content: "Connection failed: timeout after 30s\nTry: Check your network connection",
            timestamp: Date()
        ),
        isExpanded: .constant(true),
        onCopy: {}
    )
    .padding()
}

#Preview("Thinking") {
    SystemCardView(
        message: ChatMessage(
            id: "2",
            role: .thinking,
            content: "Let me analyze the codebase structure to understand the architecture...",
            timestamp: Date()
        ),
        isExpanded: .constant(true),
        onCopy: {}
    )
    .padding()
}

#Preview("Local Command") {
    SystemCardView(
        message: ChatMessage(
            id: "3",
            role: .localCommand,
            content: "/help",
            timestamp: Date()
        ),
        isExpanded: .constant(true),
        onCopy: {}
    )
    .padding()
}
```

## Acceptance Criteria

- [ ] SystemCardView handles all 6 system roles
- [ ] Error messages show red styling
- [ ] Thinking messages show italic/purple styling
- [ ] Local commands show terminal styling
- [ ] Collapsible roles have correct default state
- [ ] Non-collapsible roles display inline
- [ ] Uses MessageDesignSystem tokens throughout
- [ ] File linked in project.pbxproj
- [ ] Build passes

## Migration Notes

Logic migrated from CLIMessageView.swift:
- `errorMessageView()` → SystemCardView with .error role
- `systemMessageView()` → SystemCardView with .system role
- `resultSuccessView()` → SystemCardView with .resultSuccess role
- `thinkingView()` → SystemCardView with .thinking role
- `localCommandView()` → SystemCardView with .localCommand role
