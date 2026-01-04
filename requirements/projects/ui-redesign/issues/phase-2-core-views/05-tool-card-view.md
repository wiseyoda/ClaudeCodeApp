---
number: 05
title: ToolCardView
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

# Issue 05: ToolCardView

**Phase:** 2 (Core Views)
**Priority:** High
**Status:** Not Started
**Depends On:** Issue 03 (Protocol & Router)

## Goal

Implement ToolCardView for toolUse and toolResult messages.

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
└── ToolCardView.swift (~500 lines)
```

## Roles Handled

- `toolUse` - Tool invocation (name, input)
- `toolResult` - Tool output

## Features

| Feature | toolUse | toolResult |
|---------|---------|------------|
| Icon | Tool-specific or wrench.fill | doc.text.fill |
| Header | Tool name | "Result" |
| Collapsible | Yes | Yes |
| Default Expanded | No | No |
| Copy | Yes | Yes |
| Bookmark | No | Yes |
| Action Bar | Yes | Yes |
| Diff View | For Edit tool | No |
| Code Syntax | For Read/Write | Yes |

## Tool-Specific Rendering

| Tool | Special Rendering |
|------|-------------------|
| Edit | DiffView with old/new |
| Read | Code block with syntax highlighting |
| Write | WritePreviewView: line numbers, indentation normalization, 8-line preview, expand to full-screen viewer |
| Bash | Terminal-style output |
| Glob | File list |
| Grep | Search results |
| WebFetch | Extracted content |
| TodoWrite | Checklist UI + TodoProgressDrawer (see Issue: Todo Progress Drawer) |

## Implementation

```swift
import SwiftUI

struct ToolCardView: View {
    let message: ChatMessage
    @Binding var isExpanded: Bool
    let onCopy: () -> Void
    let onBookmark: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var style: MessageDesignSystem.RoleStyle {
        MessageDesignSystem.style(for: message.role)
    }

    private var toolType: ToolType? {
        message.toolName.flatMap { ToolType(rawValue: $0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsible header
            CollapsibleSection(isExpanded: $isExpanded) {
                header
            } content: {
                toolContent
            }

            MessageActions(
                onCopy: onCopy,
                onBookmark: onBookmark,
                isBookmarked: message.isBookmarked
            )
            .padding(.top, MessageDesignSystem.Spacing.sm)
        }
        .padding(MessageDesignSystem.Spacing.cardPadding)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: MessageDesignSystem.CornerRadius.md))
        .contextMenu { contextMenuItems }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: MessageDesignSystem.Spacing.sm) {
            Image(systemName: toolIcon)
                .foregroundStyle(toolColor)
                .frame(width: MessageDesignSystem.Spacing.iconColumn)

            Text(headerText)
                .font(MessageDesignSystem.headerFont())

            if let toolType {
                StatusBadge(statusForTool)
            }

            Spacer()

            if !isExpanded {
                Text(contentPreview)
                    .font(MessageDesignSystem.captionFont())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var toolIcon: String {
        if let toolType {
            return toolType.icon
        }
        return message.role == .toolUse ? "wrench.fill" : "doc.text.fill"
    }

    private var toolColor: Color {
        if let toolType {
            return toolType.color
        }
        return style.tintColor(for: colorScheme)
    }

    private var headerText: String {
        if message.role == .toolUse {
            return message.toolName ?? "Tool"
        }
        return "Result"
    }

    private var statusForTool: StatusBadge.Status {
        if message.role == .toolResult {
            // Check if result indicates error
            if message.content.contains("error") || message.content.contains("Error") {
                return .error
            }
            return .success
        }
        return .pending
    }

    private var contentPreview: String {
        String(message.content.prefix(50))
    }

    // MARK: - Tool Content

    @ViewBuilder
    private var toolContent: some View {
        switch toolType {
        case .edit:
            editToolContent
        case .read:
            codeToolContent
        case .write:
            writePreviewContent
        case .bash:
            bashToolContent
        case .todoWrite:
            todoToolContent
        case .glob:
            fileListContent
        case .grep:
            grepResultsContent
        default:
            defaultContent
        }
    }

    private var editToolContent: some View {
        // Parse edit tool input for DiffView
        VStack(alignment: .leading, spacing: MessageDesignSystem.Spacing.sm) {
            if let diff = parseEditDiff() {
                DiffView(
                    oldContent: diff.old,
                    newContent: diff.new,
                    filePath: diff.path
                )
            } else {
                defaultContent
            }
        }
    }

    private var codeToolContent: some View {
        CodeBlockView(
            code: message.content,
            language: detectLanguage(),
            showLineNumbers: true
        )
    }

    private var writePreviewContent: some View {
        WritePreviewView(
            content: message.content,
            onExpand: { presentFullScreenCodeViewer() }
        )
    }

    private var bashToolContent: some View {
        VStack(alignment: .leading, spacing: MessageDesignSystem.Spacing.xs) {
            if let command = message.toolInput?["command"] as? String {
                HStack {
                    Text("$")
                        .foregroundStyle(.green)
                    Text(command)
                        .font(MessageDesignSystem.codeFont())
                }
                .padding(MessageDesignSystem.Spacing.sm)
                .background(Color.black.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: MessageDesignSystem.CornerRadius.sm))
            }

            if message.role == .toolResult {
                Text(message.content)
                    .font(MessageDesignSystem.codeFont())
                    .foregroundStyle(.primary)
            }
        }
    }

    private var todoToolContent: some View {
        TodoListView(content: message.content)
    }

    private var fileListContent: some View {
        // Parse glob results as file list
        VStack(alignment: .leading, spacing: MessageDesignSystem.Spacing.xxs) {
            ForEach(message.content.components(separatedBy: "\n"), id: \.self) { file in
                HStack(spacing: MessageDesignSystem.Spacing.xs) {
                    Image(systemName: "doc")
                        .foregroundStyle(.secondary)
                    Text(file)
                        .font(MessageDesignSystem.codeFont())
                }
            }
        }
    }

    private var grepResultsContent: some View {
        // Parse grep results with file:line:content format
        VStack(alignment: .leading, spacing: MessageDesignSystem.Spacing.xs) {
            ForEach(parseGrepResults(), id: \.self) { result in
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.file)
                        .font(MessageDesignSystem.labelFont())
                        .foregroundStyle(.secondary)
                    Text(result.content)
                        .font(MessageDesignSystem.codeFont())
                }
            }
        }
    }

    private var defaultContent: some View {
        Text(message.content)
            .font(MessageDesignSystem.bodyFont())
            .textSelection(.enabled)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuItems: some View {
        Button {
            onCopy()
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }

        if let toolName = message.toolName {
            Button {
                UIPasteboard.general.string = toolName
            } label: {
                Label("Copy Tool Name", systemImage: "wrench")
            }
        }
    }

    // MARK: - Helpers

    private func parseEditDiff() -> (old: String, new: String, path: String)? {
        // Parse Edit tool input
        guard let input = message.toolInput,
              let oldString = input["old_string"] as? String,
              let newString = input["new_string"] as? String,
              let filePath = input["file_path"] as? String else {
            return nil
        }
        return (oldString, newString, filePath)
    }

    private func detectLanguage() -> String? {
        // Detect language from file extension in tool input
        guard let input = message.toolInput,
              let path = input["file_path"] as? String else {
            return nil
        }
        let ext = (path as NSString).pathExtension
        return ext.isEmpty ? nil : ext
    }

    private func parseGrepResults() -> [GrepResult] {
        // Parse grep output
        message.content.components(separatedBy: "\n").compactMap { line in
            let parts = line.components(separatedBy: ":")
            guard parts.count >= 2 else { return nil }
            return GrepResult(file: parts[0], content: parts.dropFirst().joined(separator: ":"))
        }
    }
}

struct GrepResult: Hashable {
    let file: String
    let content: String
}

// MARK: - Preview

#Preview("Tool Use") {
    ToolCardView(
        message: ChatMessage(
            id: "1",
            role: .toolUse,
            content: "",
            timestamp: Date(),
            toolName: "Read",
            toolInput: ["file_path": "/src/main.swift"]
        ),
        isExpanded: .constant(true),
        onCopy: {}
    )
    .padding()
}

#Preview("Tool Result") {
    ToolCardView(
        message: ChatMessage(
            id: "2",
            role: .toolResult,
            content: "func hello() {\n    print(\"Hello\")\n}",
            timestamp: Date()
        ),
        isExpanded: .constant(true),
        onCopy: {}
    )
    .padding()
}
```

## Acceptance Criteria

- [ ] ToolCardView handles toolUse and toolResult roles
- [ ] Collapsible with correct default state
- [ ] Tool-specific icons and colors
- [ ] Edit tool shows DiffView
- [ ] Read/Write tools show code blocks
- [ ] Bash shows terminal-style output
- [ ] TodoWrite shows checklist UI
- [ ] Content preview when collapsed
- [ ] Uses MessageDesignSystem tokens throughout
- [ ] File linked in project.pbxproj
- [ ] Build passes

## Migration Notes

Logic migrated from:
- CLIMessageView.swift: `toolUseView()`, `toolResultView()`
- CompactToolView.swift: Tool grouping logic
- ToolContentView.swift: Tool-specific rendering
