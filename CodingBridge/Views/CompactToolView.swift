import SwiftUI

// MARK: - Grouped Message Types

/// Represents how messages should be displayed - either individual or grouped
enum DisplayItem: Identifiable {
    case single(ChatMessage)
    case exploredFiles(ExploredGroup)
    case terminalCommand(TerminalGroup)

    var id: String {
        switch self {
        case .single(let msg):
            return msg.id.uuidString
        case .exploredFiles(let group):
            return "explored-\(group.id.uuidString)"
        case .terminalCommand(let group):
            return "terminal-\(group.id.uuidString)"
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
            result.append(.exploredFiles(group.group))
            i = group.nextIndex
            continue
        }

        // Check for Bash command with result
        if message.role == .toolUse && message.content.hasPrefix("Bash") {
            let group = extractTerminalGroup(from: messages, startingAt: i)
            result.append(.terminalCommand(group.group))
            i = group.nextIndex
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
    var timestamp = messages[start].timestamp
    var hasErrors = false

    while i < messages.count {
        let msg = messages[i]

        // Continue grouping explore toolUse messages
        if msg.role == .toolUse && isExploreToolType(msg.content) {
            if let path = extractFilePath(from: msg.content) {
                let toolType = CLITheme.ToolType.from(msg.content)
                files.append(ExploredGroup.ExploredFile(path: path, toolType: toolType, hasError: false))
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
                            hasError: true
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

// MARK: - Parameter Extraction Helpers

/// Extract file path from tool content
private func extractFilePath(from content: String) -> String? {
    // Try JSON format first: Read({"file_path": "..."})
    if let jsonStart = content.firstIndex(of: "{"),
       let jsonEnd = content.lastIndex(of: "}") {
        let jsonString = String(content[jsonStart...jsonEnd])
        if let data = jsonString.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Read uses file_path, Glob/Grep use path or pattern
            if let path = dict["file_path"] as? String {
                return path
            }
            if let pattern = dict["pattern"] as? String {
                return pattern
            }
            if let path = dict["path"] as? String {
                return path
            }
        }
    }
    return nil
}

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

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            // Folder icon
            Text("📁")
                .font(.system(size: 12))

            // "Explored:" label and file list
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("Explored:")
                        .font(settings.scaledFont(.small))
                        .foregroundColor(mutedColor)

                    Spacer()

                    // Success/error indicator
                    Text(group.isSuccess ? "✓" : "✗")
                        .font(.system(size: 11))
                        .foregroundColor(group.isSuccess ? successColor : errorColor)
                }

                // File names - wrap naturally
                Text(fileNames)
                    .font(settings.scaledFont(.small))
                    .foregroundColor(mutedColor.opacity(0.85))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }

    private var fileNames: String {
        group.files.map { file in
            // Just show filename, not full path
            let filename = (file.path as NSString).lastPathComponent
            return file.hasError ? "\(filename) ✗" : filename
        }.joined(separator: ", ")
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Command line with expand toggle
            HStack(alignment: .top, spacing: 6) {
                // $ prefix
                Text("$")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(mutedColor)

                // Command text - word wrap
                Text(group.command)
                    .font(settings.scaledFont(.small))
                    .foregroundColor(mutedColor.opacity(0.9))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 4)

                // Expand/collapse toggle
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

            // Result summary line
            HStack(spacing: 4) {
                Text("└")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(mutedColor.opacity(0.5))

                Text(resultSummary)
                    .font(settings.scaledFont(.small))
                    .foregroundColor(resultColor)
                    .lineLimit(1)

                Spacer()

                // Duration if significant
                if let duration = group.duration, duration >= 1.0 {
                    Text(formatDuration(duration))
                        .font(.system(size: 10))
                        .foregroundColor(mutedColor.opacity(0.6))
                }
            }
            .padding(.leading, 12)

            // Expanded result
            if isExpanded {
                expandedResultView
            }
        }
        .padding(.vertical, 2)
    }

    private var resultSummary: String {
        extractTerminalSummary(group.result)
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
        .padding(.leading, 12)
        .padding(.top, 4)
    }

    private var resultColor: Color {
        if group.isSuccess {
            return colorScheme == .dark
                ? Color(red: 0.4, green: 0.75, blue: 0.45)
                : Color(red: 0.15, green: 0.5, blue: 0.2)
        } else {
            return colorScheme == .dark
                ? Color(red: 0.9, green: 0.45, blue: 0.45)
                : Color(red: 0.7, green: 0.2, blue: 0.2)
        }
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
        }
    }
}

// MARK: - Preview

#Preview("Explored Files") {
    let group = ExploredGroup(
        files: [
            .init(path: "/path/to/Models.swift", toolType: .read, hasError: false),
            .init(path: "/path/to/ChatView.swift", toolType: .read, hasError: false),
            .init(path: "/path/to/CLIMessageView.swift", toolType: .read, hasError: false),
            .init(path: "/path/to/TodoListView.swift", toolType: .read, hasError: false),
            .init(path: "/path/to/SessionStore.swift", toolType: .read, hasError: false),
        ],
        timestamp: Date(),
        isSuccess: true
    )

    return ExploredFilesView(group: group)
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

    return TerminalCommandView(group: group)
        .padding()
        .environmentObject(AppSettings())
        .preferredColorScheme(.dark)
}
