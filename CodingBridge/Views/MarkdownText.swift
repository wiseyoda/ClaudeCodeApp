import SwiftUI

// MARK: - Markdown Text View

struct MarkdownText: View {
    let content: String
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    // MARK: - Block Cache (prevents expensive reparsing on every render during streaming)
    @State private var cachedBlocks: [Block] = []
    @State private var contentHash: Int = 0
    @State private var parseTask: Task<Void, Never>?
    @State private var lastParseTime: Date = .distantPast

    /// Minimum interval between block parsing during streaming (prevents UI freeze)
    private static let parseThrottleInterval: TimeInterval = 0.15  // 150ms

    init(_ content: String) {
        // Apply HTML entity decoding on initialization
        self.content = content.processedForDisplay
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(cachedBlocks.enumerated()), id: \.offset) { _, block in
                blockView(for: block)
            }
        }
        .onAppear {
            refreshBlocksIfNeeded(immediate: true)
        }
        .onChange(of: content) { _, _ in
            refreshBlocksIfNeeded(immediate: false)
        }
        .onDisappear {
            parseTask?.cancel()
        }
    }

    /// Only reparse blocks when content actually changes (prevents UI freeze during streaming)
    /// Uses throttling to avoid expensive parsing during rapid streaming
    private func refreshBlocksIfNeeded(immediate: Bool) {
        let newHash = content.hashValue
        guard newHash != contentHash else { return }

        // For immediate requests (onAppear), parse synchronously
        if immediate {
            contentHash = newHash
            cachedBlocks = parseBlocks()
            lastParseTime = Date()
            return
        }

        // During streaming, throttle parsing to avoid blocking keyboard input
        let now = Date()
        let timeSinceLastParse = now.timeIntervalSince(lastParseTime)

        if timeSinceLastParse >= Self.parseThrottleInterval {
            // Enough time has passed, parse immediately
            contentHash = newHash
            cachedBlocks = parseBlocks()
            lastParseTime = now
        } else {
            // Schedule deferred parse if not already scheduled
            if parseTask == nil {
                parseTask = Task { @MainActor in
                    // Wait for throttle interval
                    let delay = Self.parseThrottleInterval - timeSinceLastParse
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    guard !Task.isCancelled else { return }

                    // Re-check hash in case content changed again
                    let currentHash = content.hashValue
                    guard currentHash != contentHash else {
                        parseTask = nil
                        return
                    }

                    contentHash = currentHash
                    cachedBlocks = parseBlocks()
                    lastParseTime = Date()
                    parseTask = nil
                }
            }
        }
    }

    private enum Block {
        case paragraph(String)
        case header(String, Int) // content, level (1-6)
        case codeBlock(String, String?) // content, language
        case mathBlock(String) // LaTeX display math ($$...$$)
        case bulletList([String])
        case numberedList([String])
        case table([[String]]) // rows of cells
        case horizontalRule
    }

    private func parseBlocks() -> [Block] {
        var blocks: [Block] = []
        let lines = content.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // Code block
            if line.hasPrefix("```") {
                let language = String(line.dropFirst(3))
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                blocks.append(.codeBlock(codeLines.joined(separator: "\n"), language.isEmpty ? nil : language))
                i += 1
                continue
            }

            // Display math block ($$...$$)
            if line.hasPrefix("$$") {
                var mathLines: [String] = []
                let firstLine = String(line.dropFirst(2))
                if firstLine.hasSuffix("$$") {
                    // Single-line math: $$...$$ on same line
                    let mathContent = String(firstLine.dropLast(2))
                    blocks.append(.mathBlock(mathContent))
                    i += 1
                } else {
                    // Multi-line math block
                    if !firstLine.isEmpty {
                        mathLines.append(firstLine)
                    }
                    i += 1
                    while i < lines.count && !lines[i].hasSuffix("$$") && !lines[i].hasPrefix("$$") {
                        mathLines.append(lines[i])
                        i += 1
                    }
                    if i < lines.count {
                        let lastLine = lines[i].replacingOccurrences(of: "$$", with: "")
                        if !lastLine.isEmpty {
                            mathLines.append(lastLine)
                        }
                        i += 1
                    }
                    blocks.append(.mathBlock(mathLines.joined(separator: "\n")))
                }
                continue
            }

            // Horizontal rule (---, ***, ___)
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine == "---" || trimmedLine == "***" || trimmedLine == "___" {
                blocks.append(.horizontalRule)
                i += 1
                continue
            }

            // Headers
            if line.hasPrefix("#") {
                let headerMatch = line.prefix(while: { $0 == "#" })
                let level = min(headerMatch.count, 6)
                let headerText = String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                if !headerText.isEmpty {
                    blocks.append(.header(headerText, level))
                }
                i += 1
                continue
            }

            // Table (detect by | at start and |---)
            if line.contains("|") && !line.trimmingCharacters(in: .whitespaces).isEmpty {
                var tableLines: [String] = []
                while i < lines.count && lines[i].contains("|") {
                    let tableLine = lines[i].trimmingCharacters(in: .whitespaces)
                    // Skip separator lines like |---|---|
                    if !tableLine.contains("---") {
                        tableLines.append(tableLine)
                    }
                    i += 1
                }
                if !tableLines.isEmpty {
                    let rows = tableLines.map { row -> [String] in
                        row.split(separator: "|", omittingEmptySubsequences: false)
                            .map { String($0).trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                    }
                    blocks.append(.table(rows))
                }
                continue
            }

            // Numbered list (including sub-items)
            if line.range(of: #"^\d+\.\s+"#, options: .regularExpression) != nil {
                var items: [String] = []
                var currentItem = ""

                while i < lines.count {
                    let currentLine = lines[i]

                    // Check if this is a new numbered item
                    if currentLine.range(of: #"^\d+\.\s+"#, options: .regularExpression) != nil {
                        // Save previous item if exists
                        if !currentItem.isEmpty {
                            items.append(currentItem.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                        // Start new item (strip the number prefix)
                        currentItem = currentLine.replacingOccurrences(of: #"^\d+\.\s+"#, with: "", options: .regularExpression)
                        i += 1
                    }
                    // Check if this is a sub-item or continuation (indented or starts with -)
                    else if currentLine.hasPrefix("   ") || currentLine.hasPrefix("\t") ||
                            currentLine.hasPrefix("  - ") || currentLine.hasPrefix("   - ") {
                        // Append to current item
                        currentItem += "\n" + currentLine
                        i += 1
                    }
                    // Empty line might be part of the list (check if next line continues)
                    else if currentLine.trimmingCharacters(in: .whitespaces).isEmpty {
                        // Peek ahead - if next line is numbered or indented, continue
                        if i + 1 < lines.count {
                            let nextLine = lines[i + 1]
                            if nextLine.range(of: #"^\d+\.\s+"#, options: .regularExpression) != nil ||
                               nextLine.hasPrefix("   ") || nextLine.hasPrefix("  - ") {
                                i += 1
                                continue
                            }
                        }
                        break
                    }
                    else {
                        // Not part of the list anymore
                        break
                    }
                }

                // Don't forget the last item
                if !currentItem.isEmpty {
                    items.append(currentItem.trimmingCharacters(in: .whitespacesAndNewlines))
                }

                if !items.isEmpty {
                    blocks.append(.numberedList(items))
                }
                continue
            }

            // Bullet list
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                var items: [String] = []
                while i < lines.count && (lines[i].hasPrefix("- ") || lines[i].hasPrefix("* ")) {
                    items.append(String(lines[i].dropFirst(2)))
                    i += 1
                }
                blocks.append(.bulletList(items))
                continue
            }

            // Regular paragraph
            if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                blocks.append(.paragraph(line))
            }
            i += 1
        }

        return blocks
    }

    @ViewBuilder
    private func blockView(for block: Block) -> some View {
        switch block {
        case .paragraph(let text):
            renderInlineMarkdown(text)
        case .header(let text, let level):
            headerView(text: text, level: level)
        case .codeBlock(let code, let language):
            CodeBlockView(code: code, language: language, settings: settings)
        case .mathBlock(let math):
            MathBlockView(content: math, settings: settings)
        case .bulletList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(settings.scaledFont(.body))
                            .foregroundColor(CLITheme.green(for: colorScheme))
                        renderInlineMarkdown(item)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        case .numberedList(let items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    numberedListItem(index: index + 1, content: item)
                }
            }
        case .table(let rows):
            tableView(rows: rows)
        case .horizontalRule:
            Rectangle()
                .fill(CLITheme.mutedText(for: colorScheme).opacity(0.4))
                .frame(height: 1)
                .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func headerView(text: String, level: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            renderStyledText(text, style: headerStyle(for: level))

            // Underline for H1 and H2
            if level <= 2 {
                Rectangle()
                    .fill(level == 1 ? CLITheme.cyan(for: colorScheme) : CLITheme.cyan(for: colorScheme).opacity(0.5))
                    .frame(height: level == 1 ? 2 : 1)
            }
        }
        .padding(.top, headerTopPadding(for: level))
        .padding(.bottom, 4)
    }

    private func headerStyle(for level: Int) -> TextStyle {
        switch level {
        case 1: return TextStyle(font: .title2, color: CLITheme.cyan(for: colorScheme), weight: .bold)
        case 2: return TextStyle(font: .title3, color: CLITheme.cyan(for: colorScheme), weight: .semibold)
        case 3: return TextStyle(font: .headline, color: CLITheme.primaryText(for: colorScheme), weight: .semibold)
        default: return TextStyle(font: .subheadline, color: CLITheme.primaryText(for: colorScheme), weight: .medium)
        }
    }

    private func headerTopPadding(for level: Int) -> CGFloat {
        switch level {
        case 1: return 16
        case 2: return 12
        case 3: return 8
        default: return 4
        }
    }

    private struct TextStyle {
        let font: Font.TextStyle
        let color: Color
        let weight: Font.Weight
    }

    @ViewBuilder
    private func renderStyledText(_ text: String, style: TextStyle) -> some View {
        // Parse bold and inline code within the text
        let attributed = parseInlineFormatting(text)
        Text(attributed)
            .font(.system(style.font, design: .default, weight: style.weight))
            .foregroundColor(style.color)
    }

    /// Parse inline markdown (bold, italic, code) into AttributedString
    private func parseInlineFormatting(_ text: String) -> AttributedString {
        var result = AttributedString()
        var remaining = text[...]
        // Use settings font size to match scaledFont(.body) - NOT system preferred font
        let fontSize = CGFloat(settings.fontSize)

        while !remaining.isEmpty {
            // Find the earliest formatting marker
            var earliestRange: Range<Substring.Index>?
            var markerType: String?

            // Check for bold **
            if let boldRange = remaining.range(of: "**") {
                if earliestRange == nil || boldRange.lowerBound < earliestRange!.lowerBound {
                    earliestRange = boldRange
                    markerType = "bold"
                }
            }

            // Check for inline code `
            if let codeRange = remaining.range(of: "`") {
                if earliestRange == nil || codeRange.lowerBound < earliestRange!.lowerBound {
                    earliestRange = codeRange
                    markerType = "code"
                }
            }

            // Check for inline math $ (but not $$ which is display math)
            if let mathRange = remaining.range(of: "$") {
                // Make sure it's not $$
                let afterDollar = remaining[mathRange.upperBound...]
                let isDisplayMath = afterDollar.hasPrefix("$")
                if !isDisplayMath && (earliestRange == nil || mathRange.lowerBound < earliestRange!.lowerBound) {
                    earliestRange = mathRange
                    markerType = "math"
                }
            }

            guard let range = earliestRange, let type = markerType else {
                // No more formatting, add the rest
                result.append(AttributedString(String(remaining)))
                break
            }

            // Add text before the marker
            let beforeMarker = String(remaining[..<range.lowerBound])
            if !beforeMarker.isEmpty {
                result.append(AttributedString(beforeMarker))
            }

            // Process the formatted text
            let afterMarker = remaining[range.upperBound...]

            switch type {
            case "bold":
                // Find closing **
                if let closeRange = afterMarker.range(of: "**") {
                    let boldText = String(afterMarker[..<closeRange.lowerBound])
                    var boldAttr = AttributedString(boldText)
                    boldAttr.font = .boldSystemFont(ofSize: fontSize)
                    result.append(boldAttr)
                    remaining = afterMarker[closeRange.upperBound...]
                } else {
                    // No closing marker, treat as literal
                    result.append(AttributedString("**"))
                    remaining = afterMarker
                }

            case "code":
                // Find closing `
                if let closeRange = afterMarker.range(of: "`") {
                    let codeText = String(afterMarker[..<closeRange.lowerBound])
                    var codeAttr = AttributedString(codeText)
                    codeAttr.font = .monospacedSystemFont(ofSize: fontSize - 1, weight: .regular)
                    codeAttr.foregroundColor = CLITheme.cyan(for: colorScheme)
                    result.append(codeAttr)
                    remaining = afterMarker[closeRange.upperBound...]
                } else {
                    // No closing marker, treat as literal
                    result.append(AttributedString("`"))
                    remaining = afterMarker
                }

            case "math":
                // Find closing $ (but not $$)
                if let closeRange = afterMarker.range(of: "$") {
                    // Make sure it's a single $ not $$
                    let beforeClose = afterMarker[..<closeRange.lowerBound]
                    let afterClose = afterMarker[closeRange.upperBound...]
                    let isValidClose = !afterClose.hasPrefix("$")
                    if isValidClose && !beforeClose.isEmpty {
                        let mathText = String(beforeClose)
                        var mathAttr = AttributedString(mathText)
                        mathAttr.font = .italicSystemFont(ofSize: fontSize)
                        mathAttr.foregroundColor = CLITheme.purple(for: colorScheme)
                        mathAttr.backgroundColor = CLITheme.purple(for: colorScheme).opacity(0.1)
                        result.append(mathAttr)
                        remaining = afterClose
                    } else {
                        // Not valid inline math, treat as literal
                        result.append(AttributedString("$"))
                        remaining = afterMarker
                    }
                } else {
                    // No closing marker, treat as literal
                    result.append(AttributedString("$"))
                    remaining = afterMarker
                }

            default:
                remaining = afterMarker
            }
        }

        return result
    }

    /// Render a numbered list item that may contain sub-items
    @ViewBuilder
    private func numberedListItem(index: Int, content: String) -> some View {
        let lines = content.components(separatedBy: "\n")
        let mainLine = lines.first ?? content
        let subLines = lines.dropFirst()

        HStack(alignment: .top, spacing: 8) {
            Text("\(index).")
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.yellow(for: colorScheme))
                .frame(minWidth: 24, alignment: .trailing)

            VStack(alignment: .leading, spacing: 4) {
                // Main item text - allow word wrap
                renderInlineMarkdown(mainLine)
                    .fixedSize(horizontal: false, vertical: true)

                // Sub-items (indented bullets)
                if !subLines.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(subLines.enumerated()), id: \.offset) { _, subLine in
                            let trimmed = subLine.trimmingCharacters(in: .whitespaces)
                            if trimmed.hasPrefix("- ") {
                                // Sub-bullet
                                HStack(alignment: .top, spacing: 6) {
                                    Text("−")
                                        .font(settings.scaledFont(.small))
                                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
                                    renderInlineMarkdown(String(trimmed.dropFirst(2)))
                                        .font(settings.scaledFont(.small))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            } else if !trimmed.isEmpty {
                                // Continuation text
                                renderInlineMarkdown(trimmed)
                                    .font(settings.scaledFont(.small))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.leading, 4)
                }
            }
        }
    }

    private func tableView(rows: [[String]]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        // Parse inline markdown (bold, code, etc.) within table cells
                        Text(parseInlineFormatting(cell))
                            .font(settings.scaledFont(.small))
                            .foregroundColor(rowIndex == 0 ? CLITheme.cyan(for: colorScheme) : CLITheme.primaryText(for: colorScheme))
                            .fontWeight(rowIndex == 0 ? .semibold : .regular)
                            .fixedSize(horizontal: false, vertical: true)  // Force word wrap
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(rowIndex == 0 ? CLITheme.secondaryBackground(for: colorScheme) : Color.clear)
                    }
                }
                if rowIndex == 0 {
                    Rectangle()
                        .fill(CLITheme.mutedText(for: colorScheme).opacity(0.3))
                        .frame(height: 1)
                }
            }
        }
        .background(CLITheme.background(for: colorScheme))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(CLITheme.mutedText(for: colorScheme).opacity(0.3), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func renderInlineMarkdown(_ text: String) -> some View {
        let attributed = parseInlineFormatting(text)
        Text(attributed)
            .font(settings.scaledFont(.body))
            .foregroundColor(CLITheme.primaryText(for: colorScheme))
            .fixedSize(horizontal: false, vertical: true)  // Force word wrap
    }
}
