# Issue 57: Export & Share

**Phase:** 5 (Secondary Views)
**Priority:** Medium
**Status:** Not Started
**Depends On:** 32 (Session Picker Redesign)
**Target:** iOS 26.2, Xcode 26.2, Swift 6.2.1

## Goal

Implement comprehensive export and share functionality for chat sessions and transcripts, supporting multiple formats and seamless iOS share sheet integration.

## Scope

- In scope:
  - Export formats: Markdown, JSON, plain text
  - iOS share sheet integration
  - Session export (single and batch)
  - Transcript formatting options
  - Copy to clipboard
  - AirDrop support
- Out of scope:
  - Cloud publishing (Google Docs, Notion, etc.)
  - PDF export (complex formatting)
  - Email composition within app

## Non-goals

- Real-time collaborative sharing
- Encrypted export
- Export scheduling

## Dependencies

- Issue #32 (Session Picker Redesign) for session selection UI

## Touch Set

- Files to create:
  - `CodingBridge/Features/Export/ExportManager.swift`
  - `CodingBridge/Features/Export/ExportSheet.swift`
  - `CodingBridge/Features/Export/ExportFormatters.swift`
- Files to modify:
  - `CodingBridge/Features/Sessions/SessionPickerSheet.swift` (add export action)
  - `CodingBridge/Features/Chat/ChatView.swift` (add share button)

## Interface Definitions

### Export Format

```swift
/// Supported export formats
enum ExportFormat: String, CaseIterable, Identifiable {
    case markdown
    case json
    case plainText

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .markdown: return "Markdown"
        case .json: return "JSON"
        case .plainText: return "Plain Text"
        }
    }

    var fileExtension: String {
        switch self {
        case .markdown: return "md"
        case .json: return "json"
        case .plainText: return "txt"
        }
    }

    var mimeType: String {
        switch self {
        case .markdown: return "text/markdown"
        case .json: return "application/json"
        case .plainText: return "text/plain"
        }
    }

    var icon: String {
        switch self {
        case .markdown: return "doc.richtext"
        case .json: return "curlybraces"
        case .plainText: return "doc.text"
        }
    }
}
```

### Export Options

```swift
/// Configuration options for export
struct ExportOptions: Sendable {
    var format: ExportFormat = .markdown
    var includeMetadata: Bool = true
    var includeTimestamps: Bool = true
    var includeToolDetails: Bool = false
    var includeThinkingBlocks: Bool = false
    var wrapCodeBlocks: Bool = true

    static let `default` = ExportOptions()

    static let minimal = ExportOptions(
        includeMetadata: false,
        includeTimestamps: false
    )

    static let full = ExportOptions(
        includeMetadata: true,
        includeTimestamps: true,
        includeToolDetails: true,
        includeThinkingBlocks: true
    )
}
```

### ExportManager

```swift
/// Handles export operations for sessions and messages
@MainActor @Observable
final class ExportManager {
    private(set) var isExporting = false
    private(set) var progress: Double = 0
    private(set) var error: AppError?

    /// Export a single session
    func export(
        session: ProjectSession,
        messages: [ChatMessage],
        options: ExportOptions
    ) async throws -> ExportResult {
        isExporting = true
        progress = 0
        defer { isExporting = false }

        let formatter = ExportFormatter.for(options.format)
        let content = formatter.format(
            session: session,
            messages: messages,
            options: options
        )

        let filename = generateFilename(session: session, format: options.format)
        let url = try await saveToTemporaryFile(content: content, filename: filename)

        return ExportResult(
            url: url,
            format: options.format,
            messageCount: messages.count,
            fileSize: content.utf8.count
        )
    }

    /// Export multiple sessions
    func exportBatch(
        sessions: [ProjectSession],
        messagesBySession: [String: [ChatMessage]],
        options: ExportOptions
    ) async throws -> [ExportResult] {
        isExporting = true
        progress = 0
        defer { isExporting = false }

        var results: [ExportResult] = []
        let total = Double(sessions.count)

        for (index, session) in sessions.enumerated() {
            let messages = messagesBySession[session.id] ?? []
            let result = try await export(
                session: session,
                messages: messages,
                options: options
            )
            results.append(result)
            progress = Double(index + 1) / total
        }

        return results
    }

    /// Copy content to clipboard
    func copyToClipboard(
        messages: [ChatMessage],
        options: ExportOptions
    ) -> Bool {
        let formatter = ExportFormatter.for(options.format)
        let content = formatter.formatMessages(messages, options: options)
        UIPasteboard.general.string = content
        return true
    }

    private func generateFilename(session: ProjectSession, format: ExportFormat) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.string(from: Date())

        let safeSummary = (session.summary ?? "session")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .prefix(50)

        return "\(date)-\(safeSummary).\(format.fileExtension)"
    }

    private func saveToTemporaryFile(content: String, filename: String) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)

        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}

struct ExportResult: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    let format: ExportFormat
    let messageCount: Int
    let fileSize: Int

    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }
}
```

### Export Formatters

```swift
protocol ExportFormatter: Sendable {
    func format(session: ProjectSession, messages: [ChatMessage], options: ExportOptions) -> String
    func formatMessages(_ messages: [ChatMessage], options: ExportOptions) -> String
}

extension ExportFormatter {
    static func `for`(_ format: ExportFormat) -> ExportFormatter {
        switch format {
        case .markdown: return MarkdownExportFormatter()
        case .json: return JSONExportFormatter()
        case .plainText: return PlainTextExportFormatter()
        }
    }
}

struct MarkdownExportFormatter: ExportFormatter {
    func format(session: ProjectSession, messages: [ChatMessage], options: ExportOptions) -> String {
        var output = ""

        // Header
        if options.includeMetadata {
            output += "# \(session.summary ?? "Chat Session")\n\n"
            output += "**Project:** \(session.projectPath ?? "Unknown")\n"
            output += "**Messages:** \(session.messageCount ?? messages.count)\n"
            if let lastActivity = session.lastActivity {
                output += "**Last Activity:** \(lastActivity)\n"
            }
            output += "\n---\n\n"
        }

        // Messages
        output += formatMessages(messages, options: options)

        return output
    }

    func formatMessages(_ messages: [ChatMessage], options: ExportOptions) -> String {
        var output = ""

        for message in messages {
            // Skip thinking blocks if not included
            if message.role == .thinking && !options.includeThinkingBlocks {
                continue
            }

            // Skip tool details if not included
            if (message.role == .toolUse || message.role == .toolResult) && !options.includeToolDetails {
                continue
            }

            // Role header
            let roleEmoji = message.role.exportEmoji
            output += "### \(roleEmoji) \(message.role.displayName)"

            if options.includeTimestamps {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                output += " (\(formatter.string(from: message.timestamp)))"
            }
            output += "\n\n"

            // Content
            if options.wrapCodeBlocks {
                output += message.content
            } else {
                // Preserve code blocks as-is
                output += message.content
            }
            output += "\n\n"
        }

        return output
    }
}

struct JSONExportFormatter: ExportFormatter {
    func format(session: ProjectSession, messages: [ChatMessage], options: ExportOptions) -> String {
        let export = SessionExport(
            session: options.includeMetadata ? session : nil,
            messages: filterMessages(messages, options: options),
            exportedAt: ISO8601DateFormatter().string(from: Date()),
            options: options
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(export),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return json
    }

    func formatMessages(_ messages: [ChatMessage], options: ExportOptions) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601

        let filtered = filterMessages(messages, options: options)
        guard let data = try? encoder.encode(filtered),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }

        return json
    }

    private func filterMessages(_ messages: [ChatMessage], options: ExportOptions) -> [ChatMessage] {
        messages.filter { message in
            if message.role == .thinking && !options.includeThinkingBlocks {
                return false
            }
            if (message.role == .toolUse || message.role == .toolResult) && !options.includeToolDetails {
                return false
            }
            return true
        }
    }
}

struct SessionExport: Codable {
    let session: ProjectSession?
    let messages: [ChatMessage]
    let exportedAt: String
    let options: ExportOptions
}

struct PlainTextExportFormatter: ExportFormatter {
    func format(session: ProjectSession, messages: [ChatMessage], options: ExportOptions) -> String {
        var output = ""

        if options.includeMetadata {
            output += "=== \(session.summary ?? "Chat Session") ===\n"
            output += "Project: \(session.projectPath ?? "Unknown")\n"
            output += "Messages: \(session.messageCount ?? messages.count)\n"
            output += String(repeating: "=", count: 50) + "\n\n"
        }

        output += formatMessages(messages, options: options)
        return output
    }

    func formatMessages(_ messages: [ChatMessage], options: ExportOptions) -> String {
        var output = ""

        for message in messages {
            if message.role == .thinking && !options.includeThinkingBlocks { continue }
            if (message.role == .toolUse || message.role == .toolResult) && !options.includeToolDetails { continue }

            output += "[\(message.role.displayName)]"
            if options.includeTimestamps {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                output += " \(formatter.string(from: message.timestamp))"
            }
            output += "\n"
            output += message.content + "\n\n"
        }

        return output
    }
}

extension ChatMessage.Role {
    var exportEmoji: String {
        switch self {
        case .user: return "👤"
        case .assistant: return "🤖"
        case .system: return "⚙️"
        case .error: return "❌"
        case .toolUse: return "🔧"
        case .toolResult: return "📄"
        case .thinking: return "💭"
        default: return "💬"
        }
    }
}
```

### ExportSheet

```swift
struct ExportSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var manager = ExportManager()
    @State private var options = ExportOptions.default
    @State private var exportResult: ExportResult?

    let session: ProjectSession
    let messages: [ChatMessage]

    var body: some View {
        NavigationStack {
            Form {
                Section("Format") {
                    Picker("Export Format", selection: $options.format) {
                        ForEach(ExportFormat.allCases) { format in
                            Label(format.displayName, systemImage: format.icon)
                                .tag(format)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section("Options") {
                    Toggle("Include Metadata", isOn: $options.includeMetadata)
                    Toggle("Include Timestamps", isOn: $options.includeTimestamps)
                    Toggle("Include Tool Details", isOn: $options.includeToolDetails)
                    Toggle("Include Thinking Blocks", isOn: $options.includeThinkingBlocks)
                }

                Section {
                    if manager.isExporting {
                        ProgressView(value: manager.progress)
                    } else {
                        Button {
                            Task { await export() }
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            copyToClipboard()
                        } label: {
                            Label("Copy to Clipboard", systemImage: "doc.on.doc")
                        }
                    }
                }

                Section("Preview") {
                    let formatter = ExportFormatter.for(options.format)
                    let preview = formatter.formatMessages(
                        Array(messages.prefix(3)),
                        options: options
                    )

                    Text(preview)
                        .font(.caption.monospaced())
                        .lineLimit(10)
                }
            }
            .navigationTitle("Export Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: $exportResult) { result in
                ShareSheet(items: [result.url])
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.glass)
    }

    private func export() async {
        do {
            exportResult = try await manager.export(
                session: session,
                messages: messages,
                options: options
            )
        } catch {
            // Handle error
        }
    }

    private func copyToClipboard() {
        _ = manager.copyToClipboard(messages: messages, options: options)
        dismiss()
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
```

## Edge Cases

- **Empty sessions**: Show appropriate message, don't export empty file
- **Very long sessions**: Stream export to file, show progress
- **Special characters in content**: Properly escape for each format
- **Code blocks with triple backticks**: Handle nested markdown correctly
- **Binary attachments**: Skip or note in export

## Acceptance Criteria

- [ ] Markdown export with proper formatting
- [ ] JSON export with full message data
- [ ] Plain text export for simple sharing
- [ ] iOS share sheet integration working
- [ ] Copy to clipboard working
- [ ] Export options respected in output
- [ ] Preview shows accurate representation
- [ ] Progress indicator for large exports
- [ ] AirDrop working
- [ ] Build passes on iOS 26.2+

## Testing

```swift
class ExportFormatterTests: XCTestCase {
    func testMarkdownFormat() {
        let messages = [
            ChatMessage(role: .user, content: "Hello"),
            ChatMessage(role: .assistant, content: "Hi there!")
        ]

        let formatter = MarkdownExportFormatter()
        let result = formatter.formatMessages(messages, options: .default)

        XCTAssertTrue(result.contains("👤"))
        XCTAssertTrue(result.contains("🤖"))
        XCTAssertTrue(result.contains("Hello"))
        XCTAssertTrue(result.contains("Hi there!"))
    }

    func testJSONFormat() {
        let messages = [
            ChatMessage(role: .user, content: "Test")
        ]

        let formatter = JSONExportFormatter()
        let result = formatter.formatMessages(messages, options: .default)

        XCTAssertTrue(result.contains("\"role\""))
        XCTAssertTrue(result.contains("\"content\""))
    }

    func testOptionsRespected() {
        let messages = [
            ChatMessage(role: .thinking, content: "Thinking...")
        ]

        let formatter = MarkdownExportFormatter()

        let withThinking = formatter.formatMessages(messages, options: .full)
        let withoutThinking = formatter.formatMessages(messages, options: .default)

        XCTAssertTrue(withThinking.contains("Thinking"))
        XCTAssertFalse(withoutThinking.contains("Thinking"))
    }
}
```
