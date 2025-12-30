import SwiftUI

// MARK: - CLI Message View

struct CLIMessageView: View {
    let message: ChatMessage
    let projectPath: String?
    let projectTitle: String?
    let hideTodoInline: Bool  // Hide inline todo when drawer is showing
    @State private var isExpanded: Bool
    @State private var showCopied = false
    @State private var showActionBar = false  // Track whether to show action bar
    @ObservedObject private var bookmarkStore = BookmarkStore.shared
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    // MARK: - Cached Computed Values (computed once in init to avoid recomputation during scrolling)
    private let cachedToolType: CLITheme.ToolType
    private let cachedToolHeaderText: String
    private let cachedResultCountBadge: String?
    private let cachedToolErrorInfo: ToolErrorInfo?
    private let cachedTimestamp: String

    // MARK: - Shared Formatters (expensive to create, so share across all instances)
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private static let staticFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    /// Threshold for switching from relative to static time (1 hour)
    private static let relativeTimeThreshold: TimeInterval = 3600

    init(message: ChatMessage, projectPath: String? = nil, projectTitle: String? = nil, hideTodoInline: Bool = false) {
        self.message = message
        self.projectPath = projectPath
        self.projectTitle = projectTitle
        self.hideTodoInline = hideTodoInline

        // Pre-compute expensive values once during init
        let toolType = CLITheme.ToolType.from(message.content)
        self.cachedToolType = toolType
        self.cachedToolHeaderText = Self.computeToolHeaderText(for: message, toolType: toolType)
        self.cachedResultCountBadge = Self.computeResultCountBadge(for: message, toolType: toolType)
        self.cachedToolErrorInfo = message.role == .toolResult
            ? ToolResultParser.parse(message.content, toolName: nil)
            : nil

        // Cache timestamp string - use static format for old messages, relative for recent
        // NOTE: Cached timestamps won't update dynamically (e.g., "2m ago" won't become "3m ago").
        // This is an intentional trade-off for performance - eliminates formatter allocation during scrolling.
        // Timestamps become accurate again when the view is recreated (e.g., navigation, search filter change).
        let age = Date().timeIntervalSince(message.timestamp)
        if age > Self.relativeTimeThreshold {
            // Old message: use static format (doesn't need updating)
            self.cachedTimestamp = Self.staticFormatter.string(from: message.timestamp)
        } else {
            // Recent message: use relative format (won't update, but acceptable UX trade-off)
            self.cachedTimestamp = Self.relativeFormatter.localizedString(for: message.timestamp, relativeTo: Date())
        }

        // Collapse result messages, common tool uses (Bash/Read/Grep/Glob), and thinking blocks by default
        let shouldStartCollapsed = message.role == .resultSuccess ||
            message.role == .toolResult ||
            message.role == .thinking ||
            (message.role == .toolUse && (message.content.hasPrefix("Bash") || message.content.hasPrefix("Read") || message.content.hasPrefix("Grep") || message.content.hasPrefix("Glob")))
        self._isExpanded = State(initialValue: !shouldStartCollapsed)
    }

    private var isBookmarked: Bool {
        bookmarkStore.isBookmarked(messageId: message.id)
    }

    var body: some View {
        // Hide TodoWrite messages and their results completely when drawer is showing
        let isTodoWriteToolUse = message.role == .toolUse && message.content.hasPrefix("TodoWrite")
        let isTodoWriteResult = message.role == .toolResult && message.content.contains("Todos have been modified")
        if hideTodoInline && (isTodoWriteToolUse || isTodoWriteResult) {
            EmptyView()
        } else {
        VStack(alignment: .leading, spacing: 2) {
            // Header line with bullet/icon (skip for assistant - icon is inline with content)
            if message.role != .assistant {
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

                    // Show status text when collapsed - simple italicized text
                    if !isExpanded, let badge = resultCountBadge {
                        Text(badge)
                            .font(.system(size: 12, weight: .medium).italic())
                            .foregroundColor(badgeTextColor)
                    }

                    // Show error summary when collapsed and is an error
                    if !isExpanded, let info = toolErrorInfo, info.category != .success {
                        Text(info.errorSummary)
                            .font(settings.scaledFont(.small))
                            .foregroundColor(CLITheme.mutedText(for: colorScheme))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }

                // Relative timestamp (skip for toolUse, assistant, error - they show time below content)
                if message.role != .toolUse && message.role != .assistant && message.role != .error {
                    Text(cachedTimestamp)
                        .font(.system(size: 10))
                        .foregroundColor(CLITheme.mutedText(for: colorScheme).opacity(0.7))

                    // Copy button for result content (small, right after timestamp)
                    if message.role == .toolResult && !message.content.isEmpty {
                        Button {
                            HapticManager.light()
                            UIPasteboard.general.string = message.content
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
                                .font(.system(size: 9))
                                .foregroundColor(
                                    showCopied
                                        ? CLITheme.green(for: colorScheme)
                                        : CLITheme.mutedText(for: colorScheme).opacity(0.6)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(showCopied ? "Copied" : "Copy result")
                    }
                }

                Spacer()
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
            } // end if message.role != .assistant

            // Content (assistant messages include inline sparkle icon)
            if isExpanded || !isCollapsible {
                if message.role == .assistant {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundColor(CLITheme.purple(for: colorScheme))
                            .font(.system(size: 12))
                            .padding(.top, 2)
                        contentView
                    }
                } else {
                    contentView
                        .padding(.leading, 16)
                }
            }

            // Footer for assistant messages: timestamp + copy button
            if message.role == .assistant && !message.content.isEmpty {
                HStack(spacing: 6) {
                    Text(cachedTimestamp)
                        .font(.system(size: 10))
                        .foregroundColor(CLITheme.mutedText(for: colorScheme).opacity(0.7))

                    Button {
                        HapticManager.light()
                        UIPasteboard.general.string = message.content
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
                            .font(.system(size: 9))
                            .foregroundColor(
                                showCopied
                                    ? CLITheme.green(for: colorScheme)
                                    : CLITheme.mutedText(for: colorScheme).opacity(0.6)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showCopied ? "Copied" : "Copy message")

                    Spacer()

                    // Action bar toggle
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showActionBar.toggle()
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12))
                            .foregroundColor(CLITheme.mutedText(for: colorScheme))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("More actions")
                }
                .padding(.leading, 16)
                .padding(.top, 4)
            }

            // Expanded action bar for assistant messages
            if message.role == .assistant && showActionBar && !message.content.isEmpty {
                messageActionBarView
            }

            // Footer for error messages: timestamp + copy button + ellipsis
            if message.role == .error && !message.content.isEmpty {
                HStack(spacing: 6) {
                    Text(cachedTimestamp)
                        .font(.system(size: 10))
                        .foregroundColor(CLITheme.mutedText(for: colorScheme).opacity(0.7))

                    Button {
                        HapticManager.light()
                        UIPasteboard.general.string = message.content
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
                            .font(.system(size: 9))
                            .foregroundColor(
                                showCopied
                                    ? CLITheme.green(for: colorScheme)
                                    : CLITheme.mutedText(for: colorScheme).opacity(0.6)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showCopied ? "Copied" : "Copy error")

                    Spacer()

                    // Action bar toggle
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showActionBar.toggle()
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12))
                            .foregroundColor(CLITheme.mutedText(for: colorScheme))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("More actions")
                }
                .padding(.leading, 16)
                .padding(.top, 4)
            }

            // Expanded action bar for error messages
            if message.role == .error && showActionBar && !message.content.isEmpty {
                errorActionBarView
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            // Copy button
            Button {
                HapticManager.light()
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
        } // else (not hideTodoInline)
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

    /// Tool type - uses cached value computed in init
    private var toolType: CLITheme.ToolType {
        cachedToolType
    }

    private var bulletColor: Color {
        switch message.role {
        case .user: return CLITheme.blue(for: colorScheme)
        case .assistant: return CLITheme.primaryText(for: colorScheme)
        case .system: return CLITheme.cyan(for: colorScheme)
        case .error: return CLITheme.red(for: colorScheme)
        case .toolUse: return CLITheme.toolColor(for: cachedToolType, scheme: colorScheme)
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
            return cachedToolHeaderText  // Use cached value
        case .toolResult: return "Result"
        case .resultSuccess: return "Done"
        case .thinking: return "Thinking"
        }
    }

    /// Extract tool name + key param for richer headers
    private var toolHeaderText: String {
        cachedToolHeaderText
    }

    /// Extract a parameter value from tool content JSON
    /// Expects format: `Tool({"key":"value",...})`
    private static func extractParam(from content: String, key: String) -> String? {
        guard let jsonStart = content.firstIndex(of: "{"),
              let jsonEnd = content.lastIndex(of: "}") else {
            return nil
        }

        let jsonString = String(content[jsonStart...jsonEnd])
        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = dict[key] else {
            return nil
        }

        // Handle different value types
        if let strValue = value as? String {
            return strValue
        } else if let intValue = value as? Int {
            return String(intValue)
        } else if let boolValue = value as? Bool {
            return String(boolValue)
        } else {
            return String(describing: value)
        }
    }

    /// Extract question headers from AskUserQuestion content
    private static func extractQuestionsHeaders(from content: String) -> [String]? {
        guard let jsonStart = content.firstIndex(of: "{"),
              let jsonEnd = content.lastIndex(of: "}") else {
            return nil
        }

        let jsonString = String(content[jsonStart...jsonEnd])
        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let questions = dict["questions"] as? [[String: Any]] else {
            return nil
        }

        return questions.compactMap { $0["header"] as? String }
    }

    /// Format tool use content for display (converts JSON to readable format)
    private static func formatToolContent(_ content: String) -> String {
        // Extract tool name and JSON
        guard let parenStart = content.firstIndex(of: "("),
              let jsonStart = content.firstIndex(of: "{"),
              let jsonEnd = content.lastIndex(of: "}") else {
            return content
        }

        let toolName = String(content[..<parenStart])
        let jsonString = String(content[jsonStart...jsonEnd])

        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return content
        }

        // Format based on tool type
        var lines: [String] = []

        switch toolName {
        case "Bash":
            if let command = dict["command"] as? String {
                lines.append("$ \(command)")
            }
            if let description = dict["description"] as? String {
                lines.append("# \(description)")
            }
        case "Read":
            if let path = dict["file_path"] as? String {
                lines.append("Path: \(path)")
            }
            if let offset = dict["offset"] as? Int {
                lines.append("From line: \(offset)")
            }
            if let limit = dict["limit"] as? Int {
                lines.append("Lines: \(limit)")
            }
        case "Write":
            if let path = dict["file_path"] as? String {
                lines.append("Path: \(path)")
            }
            if let fileContent = dict["content"] as? String {
                let preview = fileContent.count > 200 ? String(fileContent.prefix(200)) + "..." : fileContent
                lines.append("Content:\n\(preview)")
            }
        case "Edit":
            if let path = dict["file_path"] as? String {
                lines.append("Path: \(path)")
            }
            // old_string and new_string handled by DiffView
        case "Grep":
            if let pattern = dict["pattern"] as? String {
                lines.append("Pattern: \(pattern)")
            }
            if let path = dict["path"] as? String {
                lines.append("In: \(path)")
            }
        case "Glob":
            if let pattern = dict["pattern"] as? String {
                lines.append("Pattern: \(pattern)")
            }
            if let path = dict["path"] as? String {
                lines.append("In: \(path)")
            }
        case "Task":
            if let subagentType = dict["subagent_type"] as? String {
                lines.append("Agent: \(subagentType)")
            }
            if let description = dict["description"] as? String {
                lines.append("Task: \(description)")
            }
            if let prompt = dict["prompt"] as? String {
                let preview = prompt.count > 300 ? String(prompt.prefix(300)) + "..." : prompt
                lines.append("Prompt:\n\(preview)")
            }
        case "AskUserQuestion":
            // Format question data nicely
            if let questions = dict["questions"] as? [[String: Any]] {
                for (index, question) in questions.enumerated() {
                    let header = question["header"] as? String ?? "Question \(index + 1)"
                    let questionText = question["question"] as? String ?? ""
                    lines.append("❓ \(header)")
                    if !questionText.isEmpty {
                        let preview = questionText.count > 100 ? String(questionText.prefix(100)) + "..." : questionText
                        lines.append("   \(preview)")
                    }
                    // Show options if available
                    if let options = question["options"] as? [[String: Any]] {
                        let optionLabels = options.compactMap { $0["label"] as? String }
                        if !optionLabels.isEmpty {
                            lines.append("   Options: \(optionLabels.joined(separator: ", "))")
                        }
                    }
                }
            }
        default:
            // Generic formatting for other tools
            for (key, value) in dict.sorted(by: { $0.key < $1.key }) {
                let strValue = String(describing: value)
                let preview = strValue.count > 100 ? String(strValue.prefix(100)) + "..." : strValue
                lines.append("\(key): \(preview)")
            }
        }

        return lines.isEmpty ? content : lines.joined(separator: "\n")
    }

    /// Shorten a file path to just filename or last 2 components
    private static func shortenPath(_ path: String) -> String {
        let components = path.split(separator: "/")
        if components.count <= 2 {
            return path
        }
        return components.suffix(2).joined(separator: "/")
    }

    /// Shorten a URL to just the domain
    private static func shortenURL(_ url: String) -> String {
        if let urlObj = URL(string: url), let host = urlObj.host {
            return host
        }
        // Fallback: just show first 30 chars
        return url.count > 30 ? String(url.prefix(30)) + "..." : url
    }

    /// Get display language name from file extension
    static func languageLabel(for path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        // Common programming languages
        case "swift": return "Swift"
        case "ts", "tsx": return "TypeScript"
        case "js", "jsx", "mjs", "cjs": return "JavaScript"
        case "py", "pyw": return "Python"
        case "rs": return "Rust"
        case "go": return "Go"
        case "java": return "Java"
        case "kt", "kts": return "Kotlin"
        case "rb", "erb": return "Ruby"
        case "php": return "PHP"
        case "cs": return "C#"
        case "cpp", "cc", "cxx", "hpp", "hxx": return "C++"
        case "c", "h": return "C"
        case "m", "mm": return "Objective-C"
        case "scala": return "Scala"
        case "r": return "R"
        case "dart": return "Dart"
        case "ex", "exs": return "Elixir"
        case "clj", "cljs": return "Clojure"
        case "hs": return "Haskell"
        case "lua": return "Lua"
        case "pl", "pm": return "Perl"
        case "sh", "bash", "zsh", "fish": return "Shell"
        case "ps1", "psm1": return "PowerShell"

        // Markup and data
        case "md", "markdown": return "Markdown"
        case "json", "jsonc": return "JSON"
        case "yaml", "yml": return "YAML"
        case "xml": return "XML"
        case "html", "htm": return "HTML"
        case "css", "scss", "sass", "less": return "CSS"
        case "sql": return "SQL"
        case "graphql", "gql": return "GraphQL"
        case "toml": return "TOML"
        case "ini", "cfg": return "Config"
        case "env": return "Env"

        // Project files
        case "pbxproj": return "Xcode Project"
        case "xcscheme": return "Xcode Scheme"
        case "plist": return "Plist"
        case "podfile": return "CocoaPods"
        case "gemfile": return "Bundler"
        case "dockerfile": return "Docker"
        case "makefile": return "Make"

        // Plain text
        case "txt", "text": return "Text"
        case "log": return "Log"

        default: return ""
        }
    }

    // MARK: - Static Computation Methods (called once during init)

    /// Compute tool header text - called once during init to avoid recomputation
    private static func computeToolHeaderText(for message: ChatMessage, toolType: CLITheme.ToolType) -> String {
        guard message.role == .toolUse else { return "" }

        let content = message.content
        let displayName = toolType.displayName

        switch toolType {
        case .bash:
            if let command = extractParam(from: content, key: "command") {
                let shortCmd = command.count > 40 ? String(command.prefix(40)) + "..." : command
                return "\(displayName): $ \(shortCmd)"
            }
        case .read:
            if let path = extractParam(from: content, key: "file_path") {
                let langLabel = Self.languageLabel(for: path)
                return langLabel.isEmpty
                    ? "\(displayName): \(shortenPath(path))"
                    : "\(displayName) [\(langLabel)]: \(shortenPath(path))"
            }
        case .write:
            if let path = extractParam(from: content, key: "file_path") {
                return "\(displayName): \(shortenPath(path))"
            }
        case .edit:
            if let path = extractParam(from: content, key: "file_path") {
                return "\(displayName): \(shortenPath(path))"
            }
        case .grep:
            if let pattern = extractParam(from: content, key: "pattern") {
                let shortPattern = pattern.count > 30 ? String(pattern.prefix(30)) + "..." : pattern
                return "\(displayName): \"\(shortPattern)\""
            }
        case .glob:
            if let pattern = extractParam(from: content, key: "pattern") {
                return "\(displayName): \(pattern)"
            }
        case .task:
            var header = displayName
            if let agentType = extractParam(from: content, key: "subagent_type") {
                header += " (\(agentType))"
            }
            if let desc = extractParam(from: content, key: "description") {
                let shortDesc = desc.count > 30 ? String(desc.prefix(30)) + "..." : desc
                header += ": \(shortDesc)"
            }
            return header
        case .todoWrite:
            return displayName
        case .webFetch:
            if let url = extractParam(from: content, key: "url") {
                return "\(displayName): \(shortenURL(url))"
            }
        case .webSearch:
            if let query = extractParam(from: content, key: "query") {
                let shortQuery = query.count > 30 ? String(query.prefix(30)) + "..." : query
                return "\(displayName): \"\(shortQuery)\""
            }
        case .askUser:
            // Extract question headers from the questions array
            if let questions = extractQuestionsHeaders(from: content), !questions.isEmpty {
                let headers = questions.joined(separator: ", ")
                let shortHeaders = headers.count > 40 ? String(headers.prefix(40)) + "..." : headers
                return "\(displayName): \(shortHeaders)"
            }
            return displayName
        case .lsp:
            if let operation = extractParam(from: content, key: "operation"),
               let path = extractParam(from: content, key: "filePath") {
                return "\(displayName): \(operation) in \(shortenPath(path))"
            } else if let operation = extractParam(from: content, key: "operation") {
                return "\(displayName): \(operation)"
            }
        case .taskOutput:
            if let taskId = extractParam(from: content, key: "task_id") {
                let shortId = taskId.count > 10 ? String(taskId.prefix(10)) : taskId
                return "\(displayName): \(shortId)"
            }
        case .other:
            break
        }

        return displayName
    }

    /// Compute result count badge - called once during init to avoid recomputation
    private static func computeResultCountBadge(for message: ChatMessage, toolType: CLITheme.ToolType) -> String? {
        let content = message.content

        switch message.role {
        case .toolUse:
            switch toolType {
            case .grep, .glob:
                return nil
            case .todoWrite:
                if let todos = TodoListView.parseTodoContent(content) {
                    let completed = todos.filter { $0.status == "completed" }.count
                    return "\(completed)/\(todos.count)"
                }
                return nil
            default:
                return nil
            }
        case .toolResult:
            // Parse error info for this computation
            let info = ToolResultParser.parse(content, toolName: nil)

            // Handle errors first - show error category
            guard info.category == .success else {
                return info.category.shortLabel
            }

            // 1. Bash exit code - already success, show checkmark
            if let exitCode = extractBashExitCode(from: content), exitCode == 0 {
                return "✓"
            }

            // 2. Simple acknowledgments (short JSON, success messages) - just checkmark
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count < 50 {
                return "✓"
            }
            if trimmed.hasPrefix("{") && trimmed.hasSuffix("}") && trimmed.count < 200 {
                // Short JSON response (like TodoWrite result) - just checkmark
                return "✓"
            }

            // 3. File path lists (grep/glob results) - show file count
            let lines = content.components(separatedBy: "\n")
            let pathLines = lines.filter { line in
                let t = line.trimmingCharacters(in: .whitespaces)
                guard !t.isEmpty else { return false }
                // Absolute paths or relative paths with common extensions
                return t.hasPrefix("/") || t.hasSuffix(".swift") || t.hasSuffix(".ts") ||
                       t.hasSuffix(".js") || t.hasSuffix(".json") || t.hasSuffix(".md") ||
                       t.hasSuffix(".py") || t.hasSuffix(".go") || t.hasSuffix(".rs")
            }
            if pathLines.count >= 3 {
                return "\(pathLines.count) files"
            }

            // 4. Read-style numbered output (e.g., "   1→ import SwiftUI")
            let numberedLines = lines.filter { line in
                // Match patterns like "   1→", "  42→", "123→"
                let t = line.trimmingCharacters(in: .whitespaces)
                guard let arrowIndex = t.firstIndex(of: "→") else { return false }
                let prefix = t[..<arrowIndex]
                return prefix.allSatisfy { $0.isNumber }
            }
            if numberedLines.count >= 5 {
                return "\(numberedLines.count) lines"
            }

            // 5. Default - just checkmark for success (no useless "X chars")
            return "✓"
        case .thinking:
            let wordCount = content.split(separator: " ").count
            if wordCount > 10 {
                return "\(wordCount) words"
            }
            return nil
        default:
            return nil
        }
    }

    /// Message action bar for assistant messages
    private var messageActionBarView: some View {
        MessageActionBar(
            message: message,
            projectPath: projectPath ?? "",
            onCopy: {
                UIPasteboard.general.string = message.content
            }
        )
        .padding(.leading, 16)
        .transition(AnyTransition.opacity.combined(with: .move(edge: .top)))
    }

    /// Error action bar with copy button
    private var errorActionBarView: some View {
        HStack(spacing: 12) {
            Spacer()

            // Copy button
            Button {
                HapticManager.light()
                UIPasteboard.general.string = message.content
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

    /// Quick action buttons for tools (copy path, copy command)
    @ViewBuilder
    private var quickActionButtons: some View {
        HStack(spacing: 8) {
            switch cachedToolType {
            case .bash:
                // Copy command
                if let cmd = Self.extractParam(from: message.content, key: "command") {
                    QuickActionButton(
                        icon: "doc.on.doc",
                        label: "Copy command",
                        action: { UIPasteboard.general.string = cmd }
                    )
                }
            case .read, .write, .edit:
                // Copy file path
                if let path = Self.extractParam(from: message.content, key: "file_path") {
                    QuickActionButton(
                        icon: "doc.on.doc",
                        label: "Copy path",
                        action: { UIPasteboard.general.string = path }
                    )
                }
            case .grep:
                // Copy pattern
                if let pattern = Self.extractParam(from: message.content, key: "pattern") {
                    QuickActionButton(
                        icon: "doc.on.doc",
                        label: "Copy pattern",
                        action: { UIPasteboard.general.string = pattern }
                    )
                }
            case .glob:
                // Copy glob pattern
                if let pattern = Self.extractParam(from: message.content, key: "pattern") {
                    QuickActionButton(
                        icon: "doc.on.doc",
                        label: "Copy pattern",
                        action: { UIPasteboard.general.string = pattern }
                    )
                }
            case .webFetch:
                // Copy URL and Open in Safari
                if let url = Self.extractParam(from: message.content, key: "url") {
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
                // Copy query
                if let query = Self.extractParam(from: message.content, key: "query") {
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

    /// Extract exit code from bash tool result content
    /// Format: "Exit code 128\nfatal: not a git repository..."
    private static func extractBashExitCode(from content: String) -> Int? {
        guard content.hasPrefix("Exit code ") else { return nil }
        let scanner = Scanner(string: content)
        _ = scanner.scanString("Exit code ")
        var exitCode: Int = 0
        if scanner.scanInt(&exitCode) {
            return exitCode
        }
        return nil
    }

    /// Parse tool result content into structured error info - uses cached value
    private var toolErrorInfo: ToolErrorInfo? {
        cachedToolErrorInfo
    }

    /// Whether this tool result represents an error
    private var isErrorResult: Bool {
        guard let info = cachedToolErrorInfo else { return false }
        return info.category != .success
    }

    /// Color for the result count badge - green for success, category-specific for errors
    private var badgeColor: Color {
        if message.role == .toolResult {
            // Use cached structured error info for accurate coloring
            if let info = cachedToolErrorInfo {
                return info.category.color(for: colorScheme)
            }
            // Fallback to exit code parsing
            if let exitCode = Self.extractBashExitCode(from: message.content) {
                return exitCode == 0
                    ? CLITheme.green(for: colorScheme)
                    : CLITheme.red(for: colorScheme)
            }
        }
        // Default muted color for other badges
        return CLITheme.mutedText(for: colorScheme)
    }

    /// Text color for status labels - semantic colors optimized for readability
    private var badgeTextColor: Color {
        guard let tint = glassTintForBadge else {
            return CLITheme.mutedText(for: colorScheme)
        }

        switch tint {
        case .success:
            // Dark green in light mode, softer green in dark mode
            return colorScheme == .dark
                ? Color(red: 0.4, green: 0.75, blue: 0.45)
                : Color(red: 0.15, green: 0.5, blue: 0.2)
        case .warning:
            // Dark amber in light mode, softer amber in dark mode
            return colorScheme == .dark
                ? Color(red: 0.9, green: 0.7, blue: 0.35)
                : Color(red: 0.65, green: 0.45, blue: 0.0)
        case .error:
            // Dark red in light mode, softer red in dark mode
            return colorScheme == .dark
                ? Color(red: 0.9, green: 0.45, blue: 0.45)
                : Color(red: 0.7, green: 0.2, blue: 0.2)
        case .info:
            // Dark cyan in light mode, softer cyan in dark mode
            return colorScheme == .dark
                ? Color(red: 0.4, green: 0.75, blue: 0.85)
                : Color(red: 0.0, green: 0.45, blue: 0.55)
        case .neutral, .primary, .accent:
            return CLITheme.mutedText(for: colorScheme)
        }
    }

    /// Glass tint for the result count badge (iOS 26+ Liquid Glass)
    private var glassTintForBadge: CLITheme.GlassTint? {
        if message.role == .toolResult {
            if let info = cachedToolErrorInfo {
                switch info.category {
                case .success: return .success
                case .gitError, .commandFailed, .sshError, .permissionDenied: return .error
                case .invalidArgs, .commandNotFound, .timeout: return .warning
                case .fileConflict, .approvalRequired: return .info
                case .fileNotFound: return .neutral
                case .unknown: return .error
                }
            }
            // Fallback
            if let exitCode = Self.extractBashExitCode(from: message.content) {
                return exitCode == 0 ? .success : .error
            }
        }
        return .neutral
    }

    /// Generate a count badge for collapsed tool outputs - uses cached value
    private var resultCountBadge: String? {
        cachedResultCountBadge
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
                      let todos = TodoListView.parseTodoContent(message.content),
                      !hideTodoInline {
                TodoListView(todos: todos)
            } else {
                // Format and truncate tool use content
                TruncatableText(
                    content: Self.formatToolContent(message.content),
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

// MARK: - CLI Processing View (iOS 26+ Liquid Glass compatible)

struct CLIProcessingView: View {
    @State private var dotCount = 0
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 6) {
            Text("+")
                .foregroundColor(CLITheme.primaryText(for: colorScheme))
            Text("Thinking" + String(repeating: ".", count: dotCount))
                .foregroundColor(CLITheme.primaryText(for: colorScheme))
            Spacer()
        }
        .font(settings.scaledFont(.body))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassBackground(tint: .warning, cornerRadius: 8)
        .onReceive(timer) { _ in
            dotCount = (dotCount + 1) % 4
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Claude is thinking")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - Quick Action Button (iOS 26+ Liquid Glass compatible)

struct QuickActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    @State private var showConfirmation = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button {
            HapticManager.light()
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
                        ? CLITheme.primaryText(for: colorScheme)  // Visible against green glass
                        : CLITheme.mutedText(for: colorScheme)
                )
                .frame(width: 24, height: 24)
                .glassCapsule(tint: showConfirmation ? .success : nil, isInteractive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showConfirmation ? "Copied" : label)
        // iOS 26+: Button will automatically get glass styling via system
    }
}
