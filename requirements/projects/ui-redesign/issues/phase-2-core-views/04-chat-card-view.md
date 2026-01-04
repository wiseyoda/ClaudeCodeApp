---
number: 04
title: ChatCardView
phase: phase-2-core-views
status: pending
completed_by: null
completed_at: null
verified_by: null
verified_at: null
commit: null
spot_checked: false
blocked_reason: null
---

# Issue 04: ChatCardView

**Phase:** 2 (Core Views)
**Priority:** High
**Status:** Not Started
**Depends On:** Issue 03 (Protocol & Router)

## Goal

Implement ChatCardView for user and assistant messages.

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
└── ChatCardView.swift (~350 lines)
```

## Roles Handled

- `user` - User input messages
- `assistant` - Claude's responses

## Features

| Feature | user | assistant |
|---------|------|-----------|
| Icon | person.fill | sparkles |
| Header | "You" | "Claude" |
| Collapsible | No | No |
| Copy | Yes | Yes |
| Bookmark | Yes | Yes |
| Action Bar | Yes | Yes |
| Context Menu | Yes | Yes |
| Markdown | No | Yes |
| Code Blocks | No | Yes |

Action Bar uses the shared MessageActionBar (see Issue #02 reusable components).

## Implementation

```swift
import SwiftUI

struct ChatCardView: View {
    let message: ChatMessage
    @Binding var isExpanded: Bool
    let isBookmarked: Bool
    let onCopy: () -> Void
    let onBookmark: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var style: MessageDesignSystem.RoleStyle {
        MessageDesignSystem.style(for: message.role)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MessageDesignSystem.Spacing.sm) {
            // Header
            header

            // Content
            content

            // Actions
            if style.capabilities.contains(.hasActionBar) {
                actions
            }
        }
        .padding(MessageDesignSystem.Spacing.cardPadding)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: MessageDesignSystem.CornerRadius.md))
        .contextMenu { contextMenuItems }
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

            MessageTimestamp(date: message.timestamp)
        }
    }

    private var headerText: String {
        switch message.role {
        case .user: return "You"
        case .assistant: return "Claude"
        default: return ""
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if message.role == .assistant {
            // Markdown rendering for assistant
            MarkdownText(message.content)
                .padding(.leading, MessageDesignSystem.Spacing.contentIndent)
        } else {
            // Plain text for user
            Text(message.content)
                .font(MessageDesignSystem.bodyFont())
                .padding(.leading, MessageDesignSystem.Spacing.contentIndent)
        }

        // Image attachment if present
        if let imageData = message.imageData,
           let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: MessageDesignSystem.CornerRadius.sm))
                .padding(.leading, MessageDesignSystem.Spacing.contentIndent)
        }
    }

    // MARK: - Actions

    private var actions: some View {
        MessageActions(
            onCopy: onCopy,
            onBookmark: onBookmark,
            isBookmarked: isBookmarked
        )
        .padding(.leading, MessageDesignSystem.Spacing.contentIndent)
    }

    // MARK: - Background

    private var cardBackground: some View {
        Group {
            if message.role == .user {
                Color.blue.opacity(0.1)
            } else {
                Color(.secondarySystemBackground)
            }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuItems: some View {
        Button {
            onCopy()
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }

        Button {
            onBookmark()
        } label: {
            Label(
                isBookmarked ? "Remove Bookmark" : "Bookmark",
                systemImage: isBookmarked ? "bookmark.fill" : "bookmark"
            )
        }

        Divider()

        Button {
            UIPasteboard.general.string = message.id
        } label: {
            Label("Copy Message ID", systemImage: "number")
        }
    }
}

// MARK: - Preview

#Preview("User Message") {
    ChatCardView(
        message: ChatMessage(
            id: "1",
            role: .user,
            content: "Can you help me fix this bug in my code?",
            timestamp: Date()
        ),
        isExpanded: .constant(true),
        isBookmarked: false,
        onCopy: {},
        onBookmark: {}
    )
    .padding()
}

#Preview("Assistant Message") {
    ChatCardView(
        message: ChatMessage(
            id: "2",
            role: .assistant,
            content: """
            Sure! Let me take a look at the code.

            ```swift
            func example() {
                print("Hello")
            }
            ```

            The issue is that you're missing a return statement.
            """,
            timestamp: Date()
        ),
        isExpanded: .constant(true),
        isBookmarked: true,
        onCopy: {},
        onBookmark: {}
    )
    .padding()
}
```

## Acceptance Criteria

- [ ] ChatCardView handles user and assistant roles
- [ ] Header shows correct icon and label
- [ ] User messages show plain text
- [ ] Assistant messages render markdown
- [ ] Image attachments display correctly
- [ ] Copy and bookmark actions work
- [ ] Context menu shows all options
- [ ] Uses MessageDesignSystem tokens throughout
- [ ] File linked in project.pbxproj
- [ ] Build passes

## Migration Notes

Logic migrated from CLIMessageView.swift:
- `userMessageView()` → ChatCardView with .user role
- `assistantMessageView()` → ChatCardView with .assistant role
- Context menu items
- Image attachment display
