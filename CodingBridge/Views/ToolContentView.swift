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
        } else if content.hasPrefix("Write"),
                  let parsed = WritePreviewView.parseWriteContent(content) {
            WritePreviewView(filePath: parsed.filePath, content: parsed.content)
        } else if content.hasPrefix("TodoWrite"),
                  let todos = TodoListView.parseTodoContent(content),
                  !hideTodoInline {
            TodoListView(todos: todos)
        } else if content.hasPrefix("WebFetch") {
            WebFetchView(content: content)
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

// MARK: - WebFetch View

/// Compact view for WebFetch tool showing URL with clickable link
/// Per spec: Content hidden - Claude summarizes in response
struct WebFetchView: View {
    let content: String
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var settings: AppSettings
    @State private var showCopied = false

    private var url: String? {
        ToolParser.extractParam(from: content, key: "url")
    }

    private var domain: String {
        guard let urlString = url else { return "Unknown" }
        return ToolParser.shortenURL(urlString)
    }

    var body: some View {
        if let urlString = url {
            HStack(spacing: 8) {
                // URL text (tappable to open)
                Button {
                    if let urlObj = URL(string: urlString) {
                        HapticManager.light()
                        UIApplication.shared.open(urlObj)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(domain)
                            .font(settings.scaledFont(.small))
                            .foregroundColor(CLITheme.cyan(for: colorScheme))
                            .lineLimit(1)

                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 10))
                            .foregroundColor(CLITheme.cyan(for: colorScheme).opacity(0.7))
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Copy URL button
                Button {
                    HapticManager.light()
                    UIPasteboard.general.string = urlString
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showCopied = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCopied = false
                        }
                    }
                } label: {
                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundColor(
                            showCopied
                                ? CLITheme.green(for: colorScheme)
                                : CLITheme.mutedText(for: colorScheme).opacity(0.6)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 2)
        } else {
            Text("No URL")
                .font(settings.scaledFont(.small))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))
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
