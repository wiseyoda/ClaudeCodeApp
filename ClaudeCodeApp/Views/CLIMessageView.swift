import SwiftUI

// MARK: - CLI Message View

struct CLIMessageView: View {
    let message: ChatMessage
    let projectPath: String?
    let projectTitle: String?
    @State private var isExpanded: Bool
    @State private var showCopied = false
    @ObservedObject private var bookmarkStore = BookmarkStore.shared
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    init(message: ChatMessage, projectPath: String? = nil, projectTitle: String? = nil) {
        self.message = message
        self.projectPath = projectPath
        self.projectTitle = projectTitle
        // Collapse result messages, Grep/Glob tool uses, and thinking blocks by default
        let shouldStartCollapsed = message.role == .resultSuccess ||
            message.role == .toolResult ||
            message.role == .thinking ||
            (message.role == .toolUse && (message.content.hasPrefix("Grep") || message.content.hasPrefix("Glob")))
        self._isExpanded = State(initialValue: !shouldStartCollapsed)
    }

    private var isBookmarked: Bool {
        bookmarkStore.isBookmarked(messageId: message.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Header line with bullet/icon
            HStack(spacing: 6) {
                // Use SF Symbol icons for tools, text bullets for others
                if message.role == .toolUse {
                    Image(systemName: toolType.icon)
                        .foregroundColor(bulletColor)
                        .font(.system(size: 12))
                } else {
                    Text(bulletChar)
                        .foregroundColor(bulletColor)
                        .font(settings.scaledFont(.body))
                }

                Text(headerText)
                    .foregroundColor(headerColor)
                    .font(settings.scaledFont(.body))

                if isCollapsible {
                    Text(isExpanded ? "[-]" : "[+]")
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
                        .font(settings.scaledFont(.small))

                    // Show count badge when collapsed
                    if !isExpanded, let badge = resultCountBadge {
                        Text(badge)
                            .font(settings.scaledFont(.small))
                            .foregroundColor(CLITheme.mutedText(for: colorScheme))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(CLITheme.mutedText(for: colorScheme).opacity(0.15))
                            .cornerRadius(4)
                    }
                }

                Spacer()

                // Quick action buttons for tools
                if message.role == .toolUse {
                    quickActionButtons
                }

                // Copy button for assistant messages
                if message.role == .assistant && !message.content.isEmpty {
                    Button {
                        UIPasteboard.general.string = message.content
                        showCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showCopied = false
                        }
                    } label: {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12))
                            .foregroundColor(showCopied ? CLITheme.green(for: colorScheme) : CLITheme.mutedText(for: colorScheme))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showCopied ? "Copied" : "Copy message")
                    .accessibilityHint("Copy Claude's response to clipboard")
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if isCollapsible {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(isCollapsible ? (isExpanded ? "Double tap to collapse" : "Double tap to expand") : "")
            .accessibilityAddTraits(isCollapsible ? .isButton : [])

            // Content
            if isExpanded || !isCollapsible {
                contentView
                    .padding(.leading, 16)
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            // Copy button
            Button {
                UIPasteboard.general.string = message.content
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            // Share button
            Button {
                shareContent()
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            // Bookmark button (only if project context available)
            if let path = projectPath, let title = projectTitle {
                Button {
                    bookmarkStore.toggleBookmark(
                        message: message,
                        projectPath: path,
                        projectTitle: title
                    )
                } label: {
                    Label(
                        isBookmarked ? "Remove Bookmark" : "Bookmark",
                        systemImage: isBookmarked ? "bookmark.fill" : "bookmark"
                    )
                }
            }
        }
    }

    private func shareContent() {
        let activityVC = UIActivityViewController(
            activityItems: [message.content],
            applicationActivities: nil
        )

        // Find the window scene and present
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            // Handle iPad popover
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            rootVC.present(activityVC, animated: true)
        }
    }

    private var bulletChar: String {
        switch message.role {
        case .user: return ">"
        case .assistant: return " "
        case .system: return "*"
        case .error: return "!"
        case .toolUse: return "*"
        case .toolResult: return "└"
        case .resultSuccess: return "*"
        case .thinking: return "💭"
        }
    }

    private var toolType: CLITheme.ToolType {
        CLITheme.ToolType.from(message.content)
    }

    private var bulletColor: Color {
        switch message.role {
        case .user: return CLITheme.blue(for: colorScheme)
        case .assistant: return CLITheme.primaryText(for: colorScheme)
        case .system: return CLITheme.cyan(for: colorScheme)
        case .error: return CLITheme.red(for: colorScheme)
        case .toolUse: return CLITheme.toolColor(for: toolType, scheme: colorScheme)
        case .toolResult: return CLITheme.mutedText(for: colorScheme)
        case .resultSuccess: return CLITheme.green(for: colorScheme)
        case .thinking: return CLITheme.purple(for: colorScheme)
        }
    }

    private var headerText: String {
        switch message.role {
        case .user: return message.content
        case .assistant: return ""
        case .system: return "System (init)"
        case .error: return "Error"
        case .toolUse:
            return toolHeaderText
        case .toolResult: return "Result"
        case .resultSuccess: return "Done"
        case .thinking: return "Thinking"
        }
    }

    /// Extract tool name + key param for richer headers
    private var toolHeaderText: String {
        let content = message.content

        // Get the tool name
        let toolName: String
        if let parenIndex = content.firstIndex(of: "(") {
            toolName = String(content[..<parenIndex])
        } else {
            return content
        }

        // Extract key param based on tool type
        switch toolType {
        case .bash:
            // Show command: Bash: $ ls -la
            if let command = extractParam(from: content, key: "command") {
                let shortCmd = command.count > 40 ? String(command.prefix(40)) + "..." : command
                return "\(toolName): $ \(shortCmd)"
            }
        case .read:
            // Show file path: Read: src/index.ts
            if let path = extractParam(from: content, key: "file_path") {
                return "\(toolName): \(shortenPath(path))"
            }
        case .write:
            // Show file path: Write: src/new.ts
            if let path = extractParam(from: content, key: "file_path") {
                return "\(toolName): \(shortenPath(path))"
            }
        case .edit:
            // Show file path: Edit: src/file.ts
            if let path = extractParam(from: content, key: "file_path") {
                return "\(toolName): \(shortenPath(path))"
            }
        case .grep:
            // Show pattern: Grep: "pattern"
            if let pattern = extractParam(from: content, key: "pattern") {
                let shortPattern = pattern.count > 30 ? String(pattern.prefix(30)) + "..." : pattern
                return "\(toolName): \"\(shortPattern)\""
            }
        case .glob:
            // Show pattern: Glob: **/*.ts
            if let pattern = extractParam(from: content, key: "pattern") {
                return "\(toolName): \(pattern)"
            }
        case .task:
            // Show description: Task: Explore codebase
            if let desc = extractParam(from: content, key: "description") {
                let shortDesc = desc.count > 35 ? String(desc.prefix(35)) + "..." : desc
                return "\(toolName): \(shortDesc)"
            }
        case .todoWrite:
            return "TodoWrite"
        case .webFetch:
            // Show URL: WebFetch: example.com
            if let url = extractParam(from: content, key: "url") {
                return "\(toolName): \(shortenURL(url))"
            }
        case .webSearch:
            // Show query: WebSearch: "query"
            if let query = extractParam(from: content, key: "query") {
                let shortQuery = query.count > 30 ? String(query.prefix(30)) + "..." : query
                return "\(toolName): \"\(shortQuery)\""
            }
        case .askUser:
            return "AskUserQuestion"
        case .other:
            break
        }

        return toolName
    }

    /// Extract a parameter value from tool content like "Tool(key: value, ...)"
    private func extractParam(from content: String, key: String) -> String? {
        // Look for "key: value" pattern
        let searchKey = "\(key): "
        guard let keyRange = content.range(of: searchKey) else { return nil }

        let afterKey = content[keyRange.upperBound...]

        // Find the end of the value (next ", " or ")" or end)
        var value = ""
        var depth = 0
        var inQuote = false

        for char in afterKey {
            if char == "\"" {
                inQuote.toggle()
            } else if !inQuote {
                if char == "(" || char == "[" || char == "{" {
                    depth += 1
                } else if char == ")" || char == "]" || char == "}" {
                    if depth == 0 {
                        break
                    }
                    depth -= 1
                } else if char == "," && depth == 0 {
                    break
                }
            }
            value.append(char)
        }

        return value.trimmingCharacters(in: .whitespaces)
    }

    /// Shorten a file path to just filename or last 2 components
    private func shortenPath(_ path: String) -> String {
        let components = path.split(separator: "/")
        if components.count <= 2 {
            return path
        }
        return components.suffix(2).joined(separator: "/")
    }

    /// Shorten a URL to just the domain
    private func shortenURL(_ url: String) -> String {
        if let urlObj = URL(string: url), let host = urlObj.host {
            return host
        }
        // Fallback: just show first 30 chars
        return url.count > 30 ? String(url.prefix(30)) + "..." : url
    }

    /// Quick action buttons for tools (copy path, copy command)
    @ViewBuilder
    private var quickActionButtons: some View {
        HStack(spacing: 8) {
            switch toolType {
            case .bash:
                // Copy command
                if let cmd = extractParam(from: message.content, key: "command") {
                    QuickActionButton(
                        icon: "doc.on.doc",
                        label: "Copy command",
                        action: { UIPasteboard.general.string = cmd }
                    )
                }
            case .read, .write, .edit:
                // Copy file path
                if let path = extractParam(from: message.content, key: "file_path") {
                    QuickActionButton(
                        icon: "doc.on.doc",
                        label: "Copy path",
                        action: { UIPasteboard.general.string = path }
                    )
                }
            case .grep:
                // Copy pattern
                if let pattern = extractParam(from: message.content, key: "pattern") {
                    QuickActionButton(
                        icon: "doc.on.doc",
                        label: "Copy pattern",
                        action: { UIPasteboard.general.string = pattern }
                    )
                }
            case .glob:
                // Copy glob pattern
                if let pattern = extractParam(from: message.content, key: "pattern") {
                    QuickActionButton(
                        icon: "doc.on.doc",
                        label: "Copy pattern",
                        action: { UIPasteboard.general.string = pattern }
                    )
                }
            case .webFetch:
                // Copy URL
                if let url = extractParam(from: message.content, key: "url") {
                    QuickActionButton(
                        icon: "doc.on.doc",
                        label: "Copy URL",
                        action: { UIPasteboard.general.string = url }
                    )
                }
            default:
                EmptyView()
            }
        }
    }

    /// Generate a count badge for collapsed tool outputs
    private var resultCountBadge: String? {
        let content = message.content
        let lineCount = content.components(separatedBy: "\n").count

        switch message.role {
        case .toolUse:
            switch toolType {
            case .grep, .glob:
                // Count matching files in output (look for file paths in result)
                // For tool use, we don't have the result yet, so show nothing
                return nil
            case .todoWrite:
                // Count todos
                if let todos = TodoListView.parseTodoContent(content) {
                    let completed = todos.filter { $0.status == "completed" }.count
                    return "\(completed)/\(todos.count)"
                }
                return nil
            default:
                return nil
            }
        case .toolResult:
            // Show line count for results
            if lineCount > 1 {
                return "\(lineCount) lines"
            } else if content.count > 100 {
                return "\(content.count) chars"
            }
            return nil
        case .thinking:
            // Show word count for thinking blocks
            let wordCount = content.split(separator: " ").count
            if wordCount > 10 {
                return "\(wordCount) words"
            }
            return nil
        default:
            return nil
        }
    }

    private var headerColor: Color {
        switch message.role {
        case .user: return CLITheme.blue(for: colorScheme)
        case .assistant: return CLITheme.primaryText(for: colorScheme)
        case .system: return CLITheme.cyan(for: colorScheme)
        case .error: return CLITheme.red(for: colorScheme)
        case .toolUse: return CLITheme.toolColor(for: toolType, scheme: colorScheme)
        case .toolResult: return CLITheme.mutedText(for: colorScheme)
        case .resultSuccess: return CLITheme.green(for: colorScheme)
        case .thinking: return CLITheme.purple(for: colorScheme)
        }
    }

    private var isCollapsible: Bool {
        switch message.role {
        case .system, .toolUse, .toolResult, .resultSuccess, .thinking: return true
        default: return false
        }
    }

    private var accessibilityLabel: String {
        switch message.role {
        case .user: return "You said: \(message.content)"
        case .assistant: return "Claude response"
        case .system: return "System message"
        case .error: return "Error: \(message.content)"
        case .toolUse: return "Tool: \(headerText), \(isExpanded ? "expanded" : "collapsed")"
        case .toolResult: return "Tool result, \(isExpanded ? "expanded" : "collapsed")"
        case .resultSuccess: return "Task completed"
        case .thinking: return "Thinking block, \(isExpanded ? "expanded" : "collapsed")"
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch message.role {
        case .user:
            // Show image if attached
            if let imageData = message.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 200, maxHeight: 150)
                    .cornerRadius(8)
            }
        case .assistant:
            MarkdownText(message.content)
                .textSelection(.enabled)
        case .system, .resultSuccess:
            Text(message.content)
                .font(settings.scaledFont(.small))
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                .textSelection(.enabled)
        case .error:
            Text(message.content.formattedUsageLimit)
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.red(for: colorScheme))
                .textSelection(.enabled)
        case .toolUse:
            // Show specialized views for certain tools
            if message.content.hasPrefix("Edit"),
               let parsed = DiffView.parseEditContent(message.content) {
                DiffView(oldString: parsed.old, newString: parsed.new)
            } else if message.content.hasPrefix("TodoWrite"),
                      let todos = TodoListView.parseTodoContent(message.content) {
                TodoListView(todos: todos)
            } else {
                // Truncate long tool use content
                TruncatableText(
                    content: message.content,
                    defaultLineLimit: 10,
                    isExpanded: $isExpanded
                )
            }
        case .toolResult:
            // Use truncatable text with fade and "Show more" button
            TruncatableText(
                content: message.content,
                defaultLineLimit: TruncatableText.lineLimit(for: message.content),
                isExpanded: $isExpanded
            )
        case .thinking:
            // Truncate long thinking blocks with purple styling
            ThinkingBlockText(
                content: message.content,
                isExpanded: $isExpanded
            )
        }
    }
}

// MARK: - CLI Processing View

struct CLIProcessingView: View {
    @State private var dotCount = 0
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 6) {
            Text("+")
                .foregroundColor(CLITheme.yellow(for: colorScheme))
            Text("Thinking" + String(repeating: ".", count: dotCount))
                .foregroundColor(CLITheme.yellow(for: colorScheme))
            Spacer()
        }
        .font(settings.scaledFont(.body))
        .onReceive(timer) { _ in
            dotCount = (dotCount + 1) % 4
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Claude is thinking")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    @State private var showConfirmation = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button {
            action()
            withAnimation(.easeInOut(duration: 0.2)) {
                showConfirmation = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showConfirmation = false
                }
            }
        } label: {
            Image(systemName: showConfirmation ? "checkmark" : icon)
                .font(.system(size: 11))
                .foregroundColor(
                    showConfirmation
                        ? CLITheme.green(for: colorScheme)
                        : CLITheme.mutedText(for: colorScheme)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showConfirmation ? "Copied" : label)
    }
}
