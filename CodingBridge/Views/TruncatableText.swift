import SwiftUI

// MARK: - Truncatable Text View

/// A text view that truncates long content with a fade and "Show X more lines" button
struct TruncatableText: View {
    let content: String
    let defaultLineLimit: Int
    @Binding var isExpanded: Bool
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    @State private var showCopied = false

    // Cached line data computed once at init (not on every body call)
    private let cachedLines: [String]
    private let totalLines: Int
    private let isTruncatable: Bool
    private let truncatedContent: String
    private let hiddenLineCount: Int

    init(content: String, defaultLineLimit: Int = 8, isExpanded: Binding<Bool>) {
        self.content = content
        self.defaultLineLimit = defaultLineLimit
        self._isExpanded = isExpanded

        // Pre-compute line data once
        let lines = content.components(separatedBy: "\n")
        self.cachedLines = lines
        self.totalLines = lines.count
        self.isTruncatable = lines.count > defaultLineLimit
        self.truncatedContent = lines.prefix(defaultLineLimit).joined(separator: "\n")
        self.hiddenLineCount = max(0, lines.count - defaultLineLimit)
    }

    private var visibleContent: String {
        if isExpanded || !isTruncatable {
            return content
        }
        return truncatedContent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Content with optional fade overlay
            ZStack(alignment: .bottom) {
                Text(visibleContent)
                    .font(settings.scaledFont(.small))
                    .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)  // Force word wrap
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Fade gradient when truncated
                if !isExpanded && isTruncatable {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            CLITheme.background(for: colorScheme).opacity(0),
                            CLITheme.background(for: colorScheme).opacity(0.8),
                            CLITheme.background(for: colorScheme)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 40)
                }
            }

            // "Show X more lines" button when truncated
            if !isExpanded && isTruncatable {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                        Text("Show \(hiddenLineCount) more lines")
                            .font(settings.scaledFont(.small))
                    }
                    .foregroundColor(CLITheme.blue(for: colorScheme))
                    .padding(.top, 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show \(hiddenLineCount) more lines")
            }

            // "Show less" button when expanded and content is long
            if isExpanded && isTruncatable {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10))
                        Text("Show less")
                            .font(settings.scaledFont(.small))
                    }
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
                    .padding(.top, 8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Collapse to show fewer lines")
            }
        }
        .contextMenu {
            Button {
                // Always copy FULL content, not just visible
                UIPasteboard.general.string = content
            } label: {
                Label("Copy All (\(totalLines) lines)", systemImage: "doc.on.doc")
            }
        }
    }
}

// MARK: - Content-Aware Line Limits

extension TruncatableText {
    /// Detect verbose help output that should be more aggressively collapsed
    static func isVerboseHelpOutput(_ content: String) -> Bool {
        // Git help/usage pattern
        if content.contains("usage: git") && content.contains("--") {
            return true
        }
        // npm help pattern
        if content.contains("npm help") || content.contains("Usage: npm") {
            return true
        }
        // Generic help pattern - many option lines starting with dashes
        let optionLines = content.components(separatedBy: "\n")
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return trimmed.hasPrefix("-") || trimmed.hasPrefix("--")
            }
        if optionLines.count > 10 {
            return true
        }
        // Man page style output with section headers
        if content.contains("SYNOPSIS") || content.contains("DESCRIPTION") ||
           content.contains("OPTIONS:") || content.contains("COMMANDS:") {
            return true
        }
        return false
    }

    /// Determines appropriate line limit based on content type
    static func lineLimit(for content: String, toolName: String? = nil) -> Int {
        // More aggressive collapse for verbose help text
        if isVerboseHelpOutput(content) {
            return 5
        }

        // Check for stack traces
        if content.contains("Error") || content.contains("Exception") ||
           content.contains("at line") || content.contains("Traceback") {
            return 15
        }

        // Check for JSON
        if content.hasPrefix("{") || content.hasPrefix("[") {
            return 10
        }

        // Tool-specific limits
        if let tool = toolName?.lowercased() {
            switch tool {
            case "bash":
                return 8
            case "grep":
                return 12
            case "read":
                return 20
            case "glob":
                return 15
            default:
                break
            }
        }

        // Default
        return 8
    }
}

// MARK: - Thinking Block Text

/// Special variant for thinking/reasoning blocks with purple italic styling
struct ThinkingBlockText: View {
    let content: String
    @Binding var isExpanded: Bool
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    private let defaultLineLimit = 12

    // Cached line data computed once at init (not on every body call)
    private let totalLines: Int
    private let isTruncatable: Bool
    private let truncatedContent: String
    private let hiddenLineCount: Int

    init(content: String, isExpanded: Binding<Bool>) {
        self.content = content
        self._isExpanded = isExpanded

        // Pre-compute line data once
        let lines = content.components(separatedBy: "\n")
        self.totalLines = lines.count
        self.isTruncatable = lines.count > defaultLineLimit
        self.truncatedContent = lines.prefix(defaultLineLimit).joined(separator: "\n")
        self.hiddenLineCount = max(0, lines.count - defaultLineLimit)
    }

    private var visibleContent: String {
        if isExpanded || !isTruncatable {
            return content
        }
        return truncatedContent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottom) {
                Text(visibleContent)
                    .font(settings.scaledFont(.small))
                    .foregroundColor(CLITheme.purple(for: colorScheme).opacity(0.8))
                    .italic()
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)  // Force word wrap
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !isExpanded && isTruncatable {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            CLITheme.background(for: colorScheme).opacity(0),
                            CLITheme.background(for: colorScheme).opacity(0.8),
                            CLITheme.background(for: colorScheme)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 40)
                }
            }

            if !isExpanded && isTruncatable {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                        Text("Show \(hiddenLineCount) more lines")
                            .font(settings.scaledFont(.small))
                    }
                    .foregroundColor(CLITheme.purple(for: colorScheme))
                    .padding(.top, 4)
                }
                .buttonStyle(.plain)
            }

            if isExpanded && isTruncatable {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10))
                        Text("Show less")
                            .font(settings.scaledFont(.small))
                    }
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
                    .padding(.top, 8)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Collapsible Markdown Text

/// A markdown view that collapses long content (> lineLimit lines) with "Show more" button
/// Used for long assistant messages to keep the chat scrollable
struct CollapsibleMarkdownText: View {
    let content: String
    @Binding var isExpanded: Bool
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    /// Maximum lines before collapsing (matches MESSAGE-TYPES.md spec of 50 lines)
    static let defaultLineLimit = 50

    // Cached line data computed once at init
    private let totalLines: Int
    private let isTruncatable: Bool
    private let truncatedContent: String
    private let hiddenLineCount: Int

    init(content: String, isExpanded: Binding<Bool>, lineLimit: Int = CollapsibleMarkdownText.defaultLineLimit) {
        self.content = content
        self._isExpanded = isExpanded

        // Pre-compute line data once
        let lines = content.components(separatedBy: "\n")
        self.totalLines = lines.count
        self.isTruncatable = lines.count > lineLimit
        self.truncatedContent = lines.prefix(lineLimit).joined(separator: "\n")
        self.hiddenLineCount = max(0, lines.count - lineLimit)
    }

    /// Returns true if content exceeds the default line limit
    static func isLongContent(_ content: String, lineLimit: Int = defaultLineLimit) -> Bool {
        content.components(separatedBy: "\n").count > lineLimit
    }

    private var visibleContent: String {
        if isExpanded || !isTruncatable {
            return content
        }
        return truncatedContent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottom) {
                MarkdownText(visibleContent)
                    .textSelection(.enabled)

                // Fade gradient when truncated
                if !isExpanded && isTruncatable {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            CLITheme.background(for: colorScheme).opacity(0),
                            CLITheme.background(for: colorScheme).opacity(0.8),
                            CLITheme.background(for: colorScheme)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 50)
                }
            }

            // "Show X more lines" button when truncated
            if !isExpanded && isTruncatable {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                        Text("Show \(hiddenLineCount) more lines")
                            .font(settings.scaledFont(.small))
                    }
                    .foregroundColor(CLITheme.blue(for: colorScheme))
                    .padding(.top, 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show \(hiddenLineCount) more lines")
            }

            // "Show less" button when expanded and content is long
            if isExpanded && isTruncatable {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10))
                        Text("Show less")
                            .font(settings.scaledFont(.small))
                    }
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
                    .padding(.top, 8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Collapse content")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        TruncatableText(
            content: (1...30).map { "Line \($0): Some content here" }.joined(separator: "\n"),
            defaultLineLimit: 5,
            isExpanded: .constant(false)
        )
        .padding()
        .background(Color.black.opacity(0.1))

        TruncatableText(
            content: "Short content",
            defaultLineLimit: 5,
            isExpanded: .constant(false)
        )
        .padding()
        .background(Color.black.opacity(0.1))
    }
    .environmentObject(AppSettings())
}
