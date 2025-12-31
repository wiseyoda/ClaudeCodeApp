import SwiftUI

/// View that renders the content area for tool use messages.
/// Handles specialized views (Edit → DiffView, TodoWrite → TodoListView) and generic formatting.
struct ToolUseContentView: View {
    let content: String
    let hideTodoInline: Bool
    @Binding var isExpanded: Bool
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if content.hasPrefix("Edit"),
           let parsed = DiffView.parseEditContent(content) {
            DiffView(oldString: parsed.old, newString: parsed.new)
        } else if content.hasPrefix("TodoWrite"),
                  let todos = TodoListView.parseTodoContent(content),
                  !hideTodoInline {
            TodoListView(todos: todos)
        } else {
            // Format and truncate tool use content
            TruncatableText(
                content: ToolParser.formatToolContent(content),
                defaultLineLimit: 10,
                isExpanded: $isExpanded
            )
        }
    }
}

/// View that renders the content area for tool result messages.
/// Uses truncatable text with configurable line limits.
struct ToolResultContentView: View {
    let content: String
    @Binding var isExpanded: Bool
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        TruncatableText(
            content: content,
            defaultLineLimit: TruncatableText.lineLimit(for: content),
            isExpanded: $isExpanded
        )
    }
}

/// Quick action buttons for tool use messages (copy path, copy command, etc.)
struct ToolQuickActions: View {
    let content: String
    let toolType: CLITheme.ToolType
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            switch toolType {
            case .bash:
                if let cmd = ToolParser.extractParam(from: content, key: "command") {
                    QuickActionButton(
                        icon: "doc.on.doc",
                        label: "Copy command",
                        action: { UIPasteboard.general.string = cmd }
                    )
                }
            case .read, .write, .edit:
                if let path = ToolParser.extractParam(from: content, key: "file_path") {
                    QuickActionButton(
                        icon: "doc.on.doc",
                        label: "Copy path",
                        action: { UIPasteboard.general.string = path }
                    )
                }
            case .grep:
                if let pattern = ToolParser.extractParam(from: content, key: "pattern") {
                    QuickActionButton(
                        icon: "doc.on.doc",
                        label: "Copy pattern",
                        action: { UIPasteboard.general.string = pattern }
                    )
                }
            case .glob:
                if let pattern = ToolParser.extractParam(from: content, key: "pattern") {
                    QuickActionButton(
                        icon: "doc.on.doc",
                        label: "Copy pattern",
                        action: { UIPasteboard.general.string = pattern }
                    )
                }
            case .webFetch:
                if let url = ToolParser.extractParam(from: content, key: "url") {
                    QuickActionButton(
                        icon: "doc.on.doc",
                        label: "Copy URL",
                        action: { UIPasteboard.general.string = url }
                    )
                    QuickActionButton(
                        icon: "safari",
                        label: "Open in Safari",
                        action: {
                            if let urlObj = URL(string: url) {
                                UIApplication.shared.open(urlObj)
                            }
                        }
                    )
                }
            case .webSearch:
                if let query = ToolParser.extractParam(from: content, key: "query") {
                    QuickActionButton(
                        icon: "doc.on.doc",
                        label: "Copy query",
                        action: { UIPasteboard.general.string = query }
                    )
                }
            default:
                EmptyView()
            }
        }
    }
}

/// Error action bar with copy button for error messages
struct ErrorActionBar: View {
    let content: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Spacer()

            Button {
                HapticManager.light()
                UIPasteboard.general.string = content
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 14))
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copy error")
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .padding(.leading, 16)
        .transition(AnyTransition.opacity.combined(with: .move(edge: .top)))
    }
}

#Preview {
    VStack(spacing: 20) {
        // Tool use with bash command
        ToolQuickActions(
            content: "Bash({\"command\":\"ls -la\",\"description\":\"List files\"})",
            toolType: .bash
        )

        // Tool use with file path
        ToolQuickActions(
            content: "Read({\"file_path\":\"/Users/test/project/src/main.swift\"})",
            toolType: .read
        )

        // Error action bar
        ErrorActionBar(content: "Something went wrong")
    }
    .padding()
    .background(Color.black)
    .environmentObject(AppSettings())
}
