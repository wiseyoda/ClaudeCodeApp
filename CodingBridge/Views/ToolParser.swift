import Foundation

/// Utility struct for parsing tool use content from Claude Code messages.
/// Extracts parameters, formats content for display, and provides helper methods.
enum ToolParser {

    /// Extract a parameter value from tool content JSON.
    /// Expects format: `Tool({"key":"value",...})`
    static func extractParam(from content: String, key: String) -> String? {
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
    static func extractQuestionsHeaders(from content: String) -> [String]? {
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
    static func formatToolContent(_ content: String) -> String {
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
            // Per spec: just show path + line count, not full content
            if let fileContent = dict["content"] as? String {
                let lineCount = fileContent.components(separatedBy: "\n").count
                lines.append("+\(lineCount) lines")
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
            // Per spec: simplified display, mini chat window shows activity
            // Just show agent type, no verbose prompt
            if let subagentType = dict["subagent_type"] as? String {
                lines.append("Agent: \(subagentType)")
            }
            if let description = dict["description"] as? String {
                lines.append(description)
            }
        case "WebFetch":
            // Per spec: Header shows "Web: domain" - no additional content needed
            // Claude summarizes in response, so content would be duplicate
            break
        case "WebSearch":
            // Per spec: Header shows "Search: query" - no additional content needed
            // Results collapsed by default
            break
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
            // Check for MCP tools - show key parameters concisely
            if toolName.hasPrefix("mcp__") {
                for (key, value) in dict.sorted(by: { $0.key < $1.key }) {
                    let strValue = String(describing: value)
                    let preview = strValue.count > 50 ? String(strValue.prefix(50)) + "..." : strValue
                    lines.append("\(key): \(preview)")
                }
                return lines.isEmpty ? "" : lines.joined(separator: "\n")
            }
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
    static func shortenPath(_ path: String) -> String {
        let components = path.split(separator: "/")
        if components.count <= 2 {
            return path
        }
        return components.suffix(2).joined(separator: "/")
    }

    /// Shorten a URL to just the domain
    static func shortenURL(_ url: String) -> String {
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

    /// Compute tool header text for display
    static func computeToolHeaderText(for content: String, toolType: CLITheme.ToolType) -> String {
        let displayName = toolType.displayName

        switch toolType {
        case .bash:
            if let command = extractParam(from: content, key: "command") {
                let shortCmd = command.count > 40 ? String(command.prefix(40)) + "..." : command
                return "\(displayName): $ \(shortCmd)"
            }
        case .read:
            if let path = extractParam(from: content, key: "file_path") {
                let langLabel = languageLabel(for: path)
                return langLabel.isEmpty
                    ? "\(displayName): \(shortenPath(path))"
                    : "\(displayName) [\(langLabel)]: \(shortenPath(path))"
            }
        case .write:
            // Per spec: just show path, icon already identifies the tool
            if let path = extractParam(from: content, key: "file_path") {
                return shortenPath(path)
            }
        case .edit:
            // Per spec: just show path, icon already identifies the tool
            if let path = extractParam(from: content, key: "file_path") {
                return shortenPath(path)
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
            // Per spec: "Web: URL" format
            if let url = extractParam(from: content, key: "url") {
                return "Web: \(shortenURL(url))"
            }
        case .webSearch:
            // Per spec: "Search: query" format
            if let query = extractParam(from: content, key: "query") {
                let shortQuery = query.count > 30 ? String(query.prefix(30)) + "..." : query
                return "Search: \"\(shortQuery)\""
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
            // Check for MCP tools: mcp__server__tool → "server - tool (MCP)"
            if let parenIndex = content.firstIndex(of: "(") {
                let toolName = String(content[..<parenIndex])
                if toolName.hasPrefix("mcp__") {
                    let parts = toolName.dropFirst(5).split(separator: "_")
                    if parts.count >= 2 {
                        // mcp__server__tool → server - tool (MCP)
                        let server = String(parts[0])
                        let tool = parts.dropFirst().joined(separator: "-")
                        return "\(server) - \(tool) (MCP)"
                    }
                }
            }
        }

        return displayName
    }

    /// Extract exit code from bash tool result content.
    /// Format: "Exit code 128\nfatal: not a git repository..."
    static func extractBashExitCode(from content: String) -> Int? {
        guard content.hasPrefix("Exit code ") else { return nil }
        let scanner = Scanner(string: content)
        _ = scanner.scanString("Exit code ")
        var exitCode: Int = 0
        if scanner.scanInt(&exitCode) {
            return exitCode
        }
        return nil
    }

    /// Compute result count badge for collapsed tool outputs
    static func computeResultCountBadge(for content: String, role: ChatMessage.Role, toolType: CLITheme.ToolType) -> String? {
        switch role {
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
}
