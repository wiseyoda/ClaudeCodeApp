import SwiftUI

// MARK: - Grouped Message Types

/// Represents how messages should be displayed - either individual or grouped
enum DisplayItem: Identifiable {
    case single(ChatMessage)
    case exploredFiles(ExploredGroup)
    case terminalCommand(TerminalGroup)
    case webSearch(WebSearchGroup)

    var id: String {
        switch self {
        case .single(let msg):
            return msg.id.uuidString
        case .exploredFiles(let group):
            return "explored-\(group.id.uuidString)"
        case .terminalCommand(let group):
            return "terminal-\(group.id.uuidString)"
        case .webSearch(let group):
            return "websearch-\(group.id.uuidString)"
        }
    }
}

/// Groups consecutive Read/Glob/Grep tool calls
struct ExploredGroup: Identifiable {
    let id = UUID()
    let files: [ExploredFile]
    let timestamp: Date
    let isSuccess: Bool

    struct ExploredFile {
        let path: String
        let toolType: CLITheme.ToolType
        let hasError: Bool
        let isSearchPattern: Bool  // True for Grep patterns (vs file paths)
    }
}

/// Merges a Bash toolUse with its toolResult
struct TerminalGroup: Identifiable {
    let id = UUID()
    let command: String
    let description: String?
    let result: String
    let isSuccess: Bool
    let timestamp: Date
    let duration: TimeInterval?
    let toolUseId: UUID
    let toolResultId: UUID?
}

/// Merges a WebSearch toolUse with its toolResult (search results)
struct WebSearchGroup: Identifiable {
    let id = UUID()
    let query: String
    let results: [SearchResult]
    let timestamp: Date
    let toolUseId: UUID
    let toolResultId: UUID?

    struct SearchResult {
        let title: String
        let url: String
        let snippet: String?
    }
}

// MARK: - Message Grouping Logic

/// Groups consecutive tool messages for compact display
func groupMessagesForDisplay(_ messages: [ChatMessage]) -> [DisplayItem] {
    var result: [DisplayItem] = []
    var i = 0

    while i < messages.count {
        let message = messages[i]

        // Check for consecutive Read/Glob/Grep operations
        if message.role == .toolUse && isExploreToolType(message.content) {
            let group = extractExploredGroup(from: messages, startingAt: i)
            // Only append if we successfully extracted files, otherwise fall through to single message
            if !group.group.files.isEmpty {
                result.append(.exploredFiles(group.group))
                i = group.nextIndex
                continue
            }
            // Fall through to render as regular single message if file extraction failed
        }

        // Check for Bash command with result
        if message.role == .toolUse && message.content.hasPrefix("Bash") {
            let group = extractTerminalGroup(from: messages, startingAt: i)
            result.append(.terminalCommand(group.group))
            i = group.nextIndex
            continue
        }

        // Check for WebSearch with result (show query + collapsible results)
        if message.role == .toolUse && message.content.hasPrefix("WebSearch") {
            let group = extractWebSearchGroup(from: messages, startingAt: i)
            result.append(.webSearch(group.group))
            i = group.nextIndex
            continue
        }

        // Check for tools that don't need separate result display
        // Per spec: Result is redundant or shown inline for these tools
        let skipResultTools = ["Edit", "Write", "WebFetch", "Task", "TodoWrite", "LSP"]
        let shouldSkipResult = message.role == .toolUse && (
            skipResultTools.contains(where: { message.content.hasPrefix($0) }) ||
            message.content.hasPrefix("mcp__")  // All MCP tools
        )
        if shouldSkipResult {
            result.append(.single(message))
            i += 1
            // Skip the following toolResult if present (redundant)
            if i < messages.count && messages[i].role == .toolResult {
                i += 1
            }
            continue
        }

        // Regular message - pass through
        result.append(.single(message))
        i += 1
    }

    return result
}

/// Check if a tool content represents an explore-type tool (Read, Glob, Grep)
private func isExploreToolType(_ content: String) -> Bool {
    content.hasPrefix("Read") || content.hasPrefix("Glob") || content.hasPrefix("Grep")
}

/// Extract a group of consecutive explore operations
private func extractExploredGroup(from messages: [ChatMessage], startingAt start: Int) -> (group: ExploredGroup, nextIndex: Int) {
    var files: [ExploredGroup.ExploredFile] = []
    var i = start
    let timestamp = messages[start].timestamp
    var hasErrors = false

    while i < messages.count {
        let msg = messages[i]

        // Continue grouping explore toolUse messages
        if msg.role == .toolUse && isExploreToolType(msg.content) {
            let toolType = CLITheme.ToolType.from(msg.content)
            let isPattern = msg.content.hasPrefix("Grep")  // Grep uses search patterns, not file paths
            // Use ToolParser to extract the appropriate key based on tool type
            let path: String? = {
                switch toolType {
                case .read:
                    return ToolParser.extractParam(from: msg.content, key: "file_path")
                case .grep:
                    return ToolParser.extractParam(from: msg.content, key: "pattern")
                case .glob:
                    return ToolParser.extractParam(from: msg.content, key: "pattern")
                default:
                    return ToolParser.extractParam(from: msg.content, key: "path")
                }
            }()
            if let path = path {
                files.append(ExploredGroup.ExploredFile(path: path, toolType: toolType, hasError: false, isSearchPattern: isPattern))
            }
            i += 1

            // Skip the following toolResult if present
            if i < messages.count && messages[i].role == .toolResult {
                // Check if result indicates an error
                let resultContent = messages[i].content
                let isError = resultContent.contains("error") ||
                              resultContent.contains("Error") ||
                              resultContent.contains("not found") ||
                              resultContent.contains("No such file")
                if isError {
                    hasErrors = true
                    // Mark the last file as having an error
                    if !files.isEmpty {
                        let lastFile = files.removeLast()
                        files.append(ExploredGroup.ExploredFile(
                            path: lastFile.path,
                            toolType: lastFile.toolType,
                            hasError: true,
                            isSearchPattern: lastFile.isSearchPattern
                        ))
                    }
                }
                i += 1
            }
            continue
        }

        // Stop grouping if we hit a non-explore message
        break
    }

    return (
        group: ExploredGroup(
            files: files,
            timestamp: timestamp,
            isSuccess: !hasErrors
        ),
        nextIndex: i
    )
}

/// Extract terminal command group (command + result)
private func extractTerminalGroup(from messages: [ChatMessage], startingAt start: Int) -> (group: TerminalGroup, nextIndex: Int) {
    let toolUseMsg = messages[start]
    let command = extractCommand(from: toolUseMsg.content) ?? toolUseMsg.content
    let description = extractDescription(from: toolUseMsg.content)

    var result = ""
    var isSuccess = true
    var duration: TimeInterval?
    var resultId: UUID?
    var nextIndex = start + 1

    // Look for the following toolResult
    if nextIndex < messages.count && messages[nextIndex].role == .toolResult {
        let resultMsg = messages[nextIndex]
        result = resultMsg.content
        resultId = resultMsg.id

        // Check for error indicators
        isSuccess = !result.contains("Exit code") || result.hasPrefix("Exit code 0")

        // Calculate duration if we have both timestamps
        duration = resultMsg.timestamp.timeIntervalSince(toolUseMsg.timestamp)
        if let dur = duration, dur < 0.1 {
            duration = nil // Don't show very short durations
        }

        nextIndex += 1
    }

    return (
        group: TerminalGroup(
            command: command,
            description: description,
            result: result,
            isSuccess: isSuccess,
            timestamp: toolUseMsg.timestamp,
            duration: duration,
            toolUseId: toolUseMsg.id,
            toolResultId: resultId
        ),
        nextIndex: nextIndex
    )
}

/// Extract web search group (query + results)
private func extractWebSearchGroup(from messages: [ChatMessage], startingAt start: Int) -> (group: WebSearchGroup, nextIndex: Int) {
    let toolUseMsg = messages[start]
    let query = ToolParser.extractParam(from: toolUseMsg.content, key: "query") ?? ""

    var results: [WebSearchGroup.SearchResult] = []
    var resultId: UUID?
    var nextIndex = start + 1

    // Look for the following toolResult
    if nextIndex < messages.count && messages[nextIndex].role == .toolResult {
        let resultMsg = messages[nextIndex]
        resultId = resultMsg.id
        results = parseSearchResults(from: resultMsg.content)
        nextIndex += 1
    }

    return (
        group: WebSearchGroup(
            query: query,
            results: results,
            timestamp: toolUseMsg.timestamp,
            toolUseId: toolUseMsg.id,
            toolResultId: resultId
        ),
        nextIndex: nextIndex
    )
}

/// Parse search results from WebSearch tool result content
/// Results typically come as markdown links: [Title](URL) or structured text
private func parseSearchResults(from content: String) -> [WebSearchGroup.SearchResult] {
    var results: [WebSearchGroup.SearchResult] = []

    // Pattern 1: Markdown links [Title](URL)
    let markdownPattern = #"\[([^\]]+)\]\(([^)]+)\)"#
    if let regex = try? NSRegularExpression(pattern: markdownPattern) {
        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, range: range)

        for match in matches {
            if let titleRange = Range(match.range(at: 1), in: content),
               let urlRange = Range(match.range(at: 2), in: content) {
                let title = String(content[titleRange])
                let url = String(content[urlRange])
                // Skip if it's not a web URL
                if url.hasPrefix("http") {
                    results.append(WebSearchGroup.SearchResult(title: title, url: url, snippet: nil))
                }
            }
        }
    }

    // If no markdown links found, try to extract URLs directly
    if results.isEmpty {
        let urlPattern = #"https?://[^\s<>\"\']+"#
        if let regex = try? NSRegularExpression(pattern: urlPattern) {
            let range = NSRange(content.startIndex..., in: content)
            let matches = regex.matches(in: content, range: range)

            for match in matches {
                if let urlRange = Range(match.range, in: content) {
                    let url = String(content[urlRange])
                    // Use domain as title
                    let title = ToolParser.shortenURL(url)
                    results.append(WebSearchGroup.SearchResult(title: title, url: url, snippet: nil))
                }
            }
        }
    }

    return results
}

// MARK: - Parameter Extraction Helpers

/// Extract command from Bash tool content
private func extractCommand(from content: String) -> String? {
    if let jsonStart = content.firstIndex(of: "{"),
       let jsonEnd = content.lastIndex(of: "}") {
        let jsonString = String(content[jsonStart...jsonEnd])
        if let data = jsonString.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return dict["command"] as? String
        }
    }
    return nil
}

/// Extract description from Bash tool content
private func extractDescription(from content: String) -> String? {
    if let jsonStart = content.firstIndex(of: "{"),
       let jsonEnd = content.lastIndex(of: "}") {
        let jsonString = String(content[jsonStart...jsonEnd])
        if let data = jsonString.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return dict["description"] as? String
        }
    }
    return nil
}

// MARK: - Smart Result Extraction

/// Extract a smart summary from terminal output
func extractTerminalSummary(_ result: String) -> String {
    let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)

    // Empty result
    if trimmed.isEmpty {
        return "Completed"
    }

    // Build results
    if trimmed.contains("BUILD SUCCEEDED") {
        return "BUILD SUCCEEDED"
    }
    if trimmed.contains("BUILD FAILED") {
        return "BUILD FAILED"
    }
    if trimmed.contains("build succeeded") || trimmed.contains("Build succeeded") {
        return "Build succeeded"
    }

    // Git results
    if let gitSummary = extractGitSummary(trimmed) {
        return gitSummary
    }

    // Exit code handling
    if trimmed.hasPrefix("Exit code ") {
        let lines = trimmed.components(separatedBy: "\n")
        if lines.count > 1, let secondLine = lines.dropFirst().first {
            let preview = secondLine.trimmingCharacters(in: .whitespaces)
            if !preview.isEmpty {
                return preview.prefix(60).description + (preview.count > 60 ? "..." : "")
            }
        }
        // Just show exit code
        if let code = lines.first {
            return code
        }
    }

    // File/line counts
    let lineCount = trimmed.components(separatedBy: "\n").count
    if lineCount > 5 {
        return "\(lineCount) lines"
    }

    // Short result - just show first line
    if let firstLine = trimmed.components(separatedBy: "\n").first {
        let clean = firstLine.trimmingCharacters(in: .whitespaces)
        if clean.count <= 60 {
            return clean
        }
        return clean.prefix(57).description + "..."
    }

    return "Completed"
}

/// Extract git-specific summary
private func extractGitSummary(_ result: String) -> String? {
    // "X files changed, Y insertions(+), Z deletions(-)"
    if result.contains("files changed") || result.contains("file changed") {
        if let match = result.range(of: #"\d+ files? changed"#, options: .regularExpression) {
            let summary = String(result[match])
            return summary
        }
    }

    // "X commits pushed"
    if result.contains("->") && (result.contains("main") || result.contains("master")) {
        // Git push output
        let lines = result.components(separatedBy: "\n")
        for line in lines {
            if line.contains("->") {
                return "Pushed to remote"
            }
        }
    }

    // Git status clean
    if result.contains("nothing to commit, working tree clean") {
        return "Working tree clean"
    }

    // Git status with changes
    if result.contains("Changes not staged") || result.contains("Changes to be committed") {
        return "Changes detected"
    }

    return nil
}

// MARK: - Explored Files View

/// Compact view for grouped file exploration operations
struct ExploredFilesView: View {
    let group: ExploredGroup
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    // Separate files from search patterns
    private var fileItems: [ExploredGroup.ExploredFile] {
        group.files.filter { !$0.isSearchPattern }
    }

    private var searchPatterns: [ExploredGroup.ExploredFile] {
        group.files.filter { $0.isSearchPattern }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // File exploration row (Read/Glob)
            if !fileItems.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    // Icon in fixed 20pt column for alignment
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                        .foregroundColor(mutedColor)
                        .frame(width: 20, alignment: .center)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Explored:")
                            .font(settings.scaledFont(.small))
                            .foregroundColor(mutedColor)

                        Text(fileNames(for: fileItems))
                            .font(settings.scaledFont(.small))
                            .foregroundColor(mutedColor.opacity(0.85))
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            // Search patterns row (Grep)
            if !searchPatterns.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    // Icon in fixed 20pt column for alignment
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(CLITheme.cyan(for: colorScheme))
                        .frame(width: 20, alignment: .center)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("Searched:")
                                .font(settings.scaledFont(.small))
                                .foregroundColor(mutedColor)

                            if hasSearchErrors {
                                Text("✗")
                                    .font(.system(size: 11))
                                    .foregroundColor(errorColor)
                            }
                        }

                        Text(patternList)
                            .font(settings.scaledFont(.small))
                            .foregroundColor(mutedColor.opacity(0.85))
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func fileNames(for items: [ExploredGroup.ExploredFile]) -> String {
        items.map { file in
            let filename = (file.path as NSString).lastPathComponent
            return file.hasError ? "\(filename) ✗" : filename
        }.joined(separator: ", ")
    }

    private var patternList: String {
        searchPatterns.map { file in
            file.hasError ? "\"\(file.path)\" ✗" : "\"\(file.path)\""
        }.joined(separator: ", ")
    }

    private var hasSearchErrors: Bool {
        searchPatterns.contains { $0.hasError }
    }

    private var mutedColor: Color {
        CLITheme.mutedText(for: colorScheme)
    }

    private var successColor: Color {
        colorScheme == .dark
            ? Color(red: 0.4, green: 0.75, blue: 0.45)
            : Color(red: 0.15, green: 0.5, blue: 0.2)
    }

    private var errorColor: Color {
        colorScheme == .dark
            ? Color(red: 0.9, green: 0.45, blue: 0.45)
            : Color(red: 0.7, green: 0.2, blue: 0.2)
    }
}

// MARK: - Terminal Command View

/// Compact view for terminal command with expandable result
struct TerminalCommandView: View {
    let group: TerminalGroup
    @State private var isExpanded = false
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    /// Whether there's actual content to expand
    private var hasExpandableContent: Bool {
        !group.result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        resultSummary != group.result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Command line with expand toggle
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                // $ prefix in fixed 20pt column for alignment
                Text("$")
                    .font(settings.scaledFont(.small).monospaced())
                    .foregroundColor(mutedColor)
                    .frame(width: 20, alignment: .center)

                // Command text - word wrap
                Text(group.command)
                    .font(settings.scaledFont(.small))
                    .foregroundColor(mutedColor.opacity(0.9))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 4)

                // Expand/collapse toggle (only show if there's content to expand)
                if hasExpandableContent {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Text(isExpanded ? "[▾]" : "[▸]")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(mutedColor.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Result summary line - indented under command text (after 20pt icon column + 6pt spacing)
            HStack(spacing: 4) {
                // └ character as text, smaller than command
                Text("└")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(mutedColor.opacity(0.5))

                // Result summary - italic and muted for "Completed", colored for errors
                if isGenericCompletion {
                    Text(resultSummary)
                        .font(.system(size: 11).italic())  // 2pt smaller than command
                        .foregroundColor(mutedColor.opacity(0.7))
                        .lineLimit(1)
                } else {
                    Text(resultSummary)
                        .font(.system(size: 11))  // 2pt smaller than command
                        .foregroundColor(resultColor)
                        .lineLimit(1)
                }

                Spacer()

                // Duration if significant
                if let duration = group.duration, duration >= 1.0 {
                    Text(formatDuration(duration))
                        .font(.system(size: 10))
                        .foregroundColor(mutedColor.opacity(0.6))
                }
            }
            .padding(.leading, 26)  // Indent under command text (20pt icon + 6pt spacing)

            // Expanded result (only if there's content)
            if isExpanded && hasExpandableContent {
                expandedResultView
            }
        }
    }

    private var resultSummary: String {
        extractTerminalSummary(group.result)
    }

    /// Check if this is a generic completion message (should be italic/muted)
    private var isGenericCompletion: Bool {
        let summary = resultSummary
        return summary == "Completed" ||
               summary == "Working tree clean" ||
               summary.isEmpty
    }

    @ViewBuilder
    private var expandedResultView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(group.result)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(mutedColor.opacity(0.85))
                .textSelection(.enabled)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(colorScheme == .dark
                    ? Color.white.opacity(0.05)
                    : Color.black.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(mutedColor.opacity(0.2), lineWidth: 0.5)
        )
        .padding(.leading, 26)  // Match 20pt icon + 6pt spacing
        .padding(.top, 4)
    }

    private var resultColor: Color {
        // Errors get red color
        if !group.isSuccess {
            return colorScheme == .dark
                ? Color(red: 0.9, green: 0.45, blue: 0.45)
                : Color(red: 0.7, green: 0.2, blue: 0.2)
        }
        // Success with actual content (not generic) gets muted color
        return mutedColor.opacity(0.85)
    }

    private var mutedColor: Color {
        CLITheme.mutedText(for: colorScheme)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return String(format: "%.1fs", seconds)
        } else {
            let minutes = Int(seconds / 60)
            let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(secs)s"
        }
    }
}

// MARK: - Web Search View

/// Compact view for web search with collapsible results
struct WebSearchView: View {
    let group: WebSearchGroup
    @State private var isExpanded = false
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header: Search query with expand toggle
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                // Search icon in fixed 20pt column for alignment
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(CLITheme.cyan(for: colorScheme))
                    .frame(width: 20, alignment: .center)

                // Query text
                Text("Search: \"\(shortenedQuery)\"")
                    .font(settings.scaledFont(.small))
                    .foregroundColor(mutedColor.opacity(0.9))
                    .lineLimit(1)

                Spacer(minLength: 4)

                // Result count
                if !group.results.isEmpty {
                    Text("\(group.results.count) results")
                        .font(.system(size: 10))
                        .foregroundColor(mutedColor.opacity(0.6))
                }

                // Expand/collapse toggle (only if results exist)
                if !group.results.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Text(isExpanded ? "[▾]" : "[▸]")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(mutedColor.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Expanded results list
            if isExpanded && !group.results.isEmpty {
                expandedResultsView
            }
        }
    }

    private var shortenedQuery: String {
        let query = group.query
        return query.count > 40 ? String(query.prefix(40)) + "..." : query
    }

    @ViewBuilder
    private var expandedResultsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(group.results.enumerated()), id: \.offset) { _, result in
                Button {
                    if let url = URL(string: result.url) {
                        HapticManager.light()
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "link")
                            .font(.system(size: 10))
                            .foregroundColor(mutedColor.opacity(0.5))
                            .frame(width: 12)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.title)
                                .font(settings.scaledFont(.small))
                                .foregroundColor(CLITheme.cyan(for: colorScheme))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            Text(shortenedURL(result.url))
                                .font(.system(size: 10))
                                .foregroundColor(mutedColor.opacity(0.5))
                                .lineLimit(1)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 10))
                            .foregroundColor(mutedColor.opacity(0.4))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(colorScheme == .dark
                    ? Color.white.opacity(0.05)
                    : Color.black.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(mutedColor.opacity(0.2), lineWidth: 0.5)
        )
        .padding(.leading, 12)
        .padding(.top, 4)
    }

    private func shortenedURL(_ url: String) -> String {
        ToolParser.shortenURL(url)
    }

    private var mutedColor: Color {
        CLITheme.mutedText(for: colorScheme)
    }
}

// MARK: - Display Item View

/// Main view for rendering a DisplayItem
struct DisplayItemView: View {
    let item: DisplayItem
    let projectPath: String?
    let projectTitle: String?
    var hideTodoInline: Bool = false

    var body: some View {
        switch item {
        case .single(let message):
            CLIMessageView(
                message: message,
                projectPath: projectPath,
                projectTitle: projectTitle,
                hideTodoInline: hideTodoInline
            )
        case .exploredFiles(let group):
            ExploredFilesView(group: group)
        case .terminalCommand(let group):
            TerminalCommandView(group: group)
        case .webSearch(let group):
            WebSearchView(group: group)
        }
    }
}

// MARK: - Preview

#Preview("Explored Files") {
    let group = ExploredGroup(
        files: [
            .init(path: "/path/to/Models.swift", toolType: .read, hasError: false, isSearchPattern: false),
            .init(path: "/path/to/ChatView.swift", toolType: .read, hasError: false, isSearchPattern: false),
            .init(path: "/path/to/CLIMessageView.swift", toolType: .read, hasError: false, isSearchPattern: false),
            .init(path: "func.*async", toolType: .grep, hasError: false, isSearchPattern: true),
            .init(path: "**/*.swift", toolType: .glob, hasError: false, isSearchPattern: false),
        ],
        timestamp: Date(),
        isSuccess: true
    )

    ExploredFilesView(group: group)
        .padding()
        .environmentObject(AppSettings())
        .preferredColorScheme(.dark)
}

#Preview("Terminal Command") {
    let group = TerminalGroup(
        command: "xcodebuild -project CodingBridge.xcodeproj -scheme CodingBridge -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'",
        description: "Build the project",
        result: "Build settings from command line:\n    SDKROOT = iphonesimulator17.0\n\n** BUILD SUCCEEDED **\n\nBuild completed in 134.2 seconds",
        isSuccess: true,
        timestamp: Date(),
        duration: 134.2,
        toolUseId: UUID(),
        toolResultId: UUID()
    )

    TerminalCommandView(group: group)
        .padding()
        .environmentObject(AppSettings())
        .preferredColorScheme(.dark)
}

#Preview("Web Search") {
    let group = WebSearchGroup(
        query: "react hooks tutorial 2025",
        results: [
            .init(title: "React Hooks Tutorial - Complete Guide", url: "https://react.dev/learn/hooks", snippet: nil),
            .init(title: "useState Hook - React Documentation", url: "https://react.dev/reference/react/useState", snippet: nil),
            .init(title: "useEffect Hook - Best Practices", url: "https://blog.example.com/react-useeffect", snippet: nil),
            .init(title: "Custom Hooks in React", url: "https://medium.com/custom-hooks-react", snippet: nil),
            .init(title: "React 19 Hooks Update", url: "https://react.dev/blog/hooks-update", snippet: nil),
        ],
        timestamp: Date(),
        toolUseId: UUID(),
        toolResultId: UUID()
    )

    WebSearchView(group: group)
        .padding()
        .environmentObject(AppSettings())
        .preferredColorScheme(.dark)
}
