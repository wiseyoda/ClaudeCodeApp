# Issue 64: Rich Text Editing

**Phase:** 2 (Core Views)
**Priority:** Low
**Status:** Not Started
**Depends On:** 26 (Chat View Redesign)
**Target:** iOS 26.2, Xcode 26.2, Swift 6.2.1

## Goal

Enhance the chat input with rich text editing capabilities using iOS 26's AttributedString TextEditor, supporting inline code formatting, markdown preview, and smart formatting.

## Scope

- In scope:
  - Inline code formatting (`backticks`)
  - Bold/italic markdown shortcuts
  - Code block syntax highlighting preview
  - Smart quotes and dashes
  - Paste handling for code
  - Keyboard shortcuts for formatting
- Out of scope:
  - Full WYSIWYG editor
  - Image embedding in editor
  - Table insertion
  - Custom fonts beyond system

## Non-goals

- Replace markdown with rich text output
- Collaborative editing
- Spell check for code

## Dependencies

- Issue #26 (Chat View Redesign) for input integration

## Touch Set

- Files to create:
  - `CodingBridge/Views/Input/RichTextEditor.swift`
  - `CodingBridge/Views/Input/TextFormatting.swift`
  - `CodingBridge/Views/Input/MarkdownPreview.swift`
- Files to modify:
  - `CodingBridge/Views/CLIInputView.swift` (use new editor)

---

## Rich Text Editor

### RichTextEditor View

```swift
import SwiftUI

/// Rich text editor with markdown formatting support.
///
/// Provides inline code formatting, keyboard shortcuts,
/// and live markdown preview.
struct RichTextEditor: View {
    @Binding var text: String
    @State private var attributedText: AttributedString = ""
    @State private var showPreview = false
    @FocusState private var isFocused: Bool

    let placeholder: String
    let onSubmit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            editor

            if showPreview && !text.isEmpty {
                Divider()
                previewPane
            }

            formattingToolbar
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFocused ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var editor: some View {
        TextEditor(text: $text)
            .focused($isFocused)
            .font(.body)
            .frame(minHeight: 44, maxHeight: 200)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .onChange(of: text) { oldValue, newValue in
                applyFormatting(newValue)
            }
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
            }
    }

    @ViewBuilder
    private var previewPane: some View {
        ScrollView {
            MarkdownPreview(text: text)
                .padding()
        }
        .frame(maxHeight: 150)
        .background(Color(.secondarySystemBackground))
    }

    @ViewBuilder
    private var formattingToolbar: some View {
        HStack(spacing: 16) {
            FormatButton(icon: "textformat.alt", label: "Bold") {
                wrapSelection(with: "**")
            }

            FormatButton(icon: "italic", label: "Italic") {
                wrapSelection(with: "_")
            }

            FormatButton(icon: "chevron.left.forwardslash.chevron.right", label: "Code") {
                wrapSelection(with: "`")
            }

            FormatButton(icon: "text.alignleft", label: "Code Block") {
                insertCodeBlock()
            }

            Spacer()

            Button(action: { showPreview.toggle() }) {
                Image(systemName: showPreview ? "eye.fill" : "eye")
            }
            .buttonStyle(.borderless)
            .help("Toggle Preview")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Formatting Actions

    private func applyFormatting(_ text: String) {
        // Apply inline code highlighting
        attributedText = formatAttributedString(text)
    }

    private func wrapSelection(with wrapper: String) {
        // In a real implementation, this would wrap the selected text
        // For now, insert at cursor
        text += "\(wrapper)text\(wrapper)"
    }

    private func insertCodeBlock() {
        text += "\n```\n\n```"
    }

    private func formatAttributedString(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)

        // Find inline code spans
        let codePattern = /`([^`]+)`/
        for match in text.matches(of: codePattern) {
            if let range = Range(match.range, in: attributed) {
                attributed[range].font = .system(.body, design: .monospaced)
                attributed[range].backgroundColor = .secondary.opacity(0.1)
            }
        }

        return attributed
    }
}

struct FormatButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
        }
        .buttonStyle(.borderless)
        .help(label)
        .keyboardShortcut(keyboardShortcut, modifiers: .command)
    }

    private var keyboardShortcut: KeyEquivalent {
        switch label {
        case "Bold": return "b"
        case "Italic": return "i"
        case "Code": return "k"
        default: return "k"
        }
    }
}
```

---

## Text Formatting Utilities

### TextFormatting

```swift
import Foundation

/// Text formatting utilities for markdown input.
enum TextFormatting {
    /// Wrap text with markdown formatting.
    static func wrap(_ text: String, with wrapper: String) -> String {
        "\(wrapper)\(text)\(wrapper)"
    }

    /// Check if text contains unbalanced code blocks.
    static func hasUnbalancedCodeBlocks(_ text: String) -> Bool {
        let codeBlockCount = text.components(separatedBy: "```").count - 1
        return codeBlockCount % 2 != 0
    }

    /// Extract code blocks from text.
    static func extractCodeBlocks(_ text: String) -> [CodeBlock] {
        var blocks: [CodeBlock] = []
        let pattern = /```(\w*)\n([\s\S]*?)```/

        for match in text.matches(of: pattern) {
            let language = String(match.1)
            let code = String(match.2)
            blocks.append(CodeBlock(language: language, code: code))
        }

        return blocks
    }

    /// Normalize smart quotes to ASCII.
    static func normalizeQuotes(_ text: String) -> String {
        text
            .replacingOccurrences(of: """, with: "\"")
            .replacingOccurrences(of: """, with: "\"")
            .replacingOccurrences(of: "'", with: "'")
            .replacingOccurrences(of: "'", with: "'")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "--")
    }

    /// Detect if pasted text is code.
    static func isPastedCode(_ text: String) -> Bool {
        // Check for common code indicators
        let codeIndicators = [
            "func ",
            "class ",
            "struct ",
            "import ",
            "let ",
            "var ",
            "if ",
            "for ",
            "while ",
            "return ",
            "->",
            "=>",
            "(){",
            "() {",
        ]

        let lines = text.components(separatedBy: .newlines)

        // Multi-line with indentation suggests code
        if lines.count > 2 {
            let indentedLines = lines.filter { $0.hasPrefix("    ") || $0.hasPrefix("\t") }
            if indentedLines.count > lines.count / 2 {
                return true
            }
        }

        // Contains code-like syntax
        for indicator in codeIndicators {
            if text.contains(indicator) {
                return true
            }
        }

        return false
    }

    struct CodeBlock: Identifiable {
        let id = UUID()
        let language: String
        let code: String
    }
}
```

---

## Markdown Preview

### MarkdownPreview

```swift
import SwiftUI

/// Live preview of markdown text.
struct MarkdownPreview: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(parseBlocks(), id: \.id) { block in
                blockView(for: block)
            }
        }
    }

    @ViewBuilder
    private func blockView(for block: MarkdownBlock) -> some View {
        switch block.type {
        case .paragraph:
            Text(parseInline(block.content))
                .textSelection(.enabled)

        case .code(let language):
            VStack(alignment: .leading, spacing: 4) {
                if !language.isEmpty {
                    Text(language)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(block.content)
                    .font(.system(.body, design: .monospaced))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

        case .heading(let level):
            Text(block.content)
                .font(headingFont(for: level))
                .fontWeight(.bold)

        case .list:
            VStack(alignment: .leading, spacing: 4) {
                ForEach(block.content.components(separatedBy: .newlines), id: \.self) { item in
                    HStack(alignment: .top) {
                        Text("•")
                        Text(parseInline(item))
                    }
                }
            }
        }
    }

    private func parseBlocks() -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var currentBlock = ""
        var inCodeBlock = false
        var codeLanguage = ""

        for line in text.components(separatedBy: .newlines) {
            if line.hasPrefix("```") {
                if inCodeBlock {
                    // End code block
                    blocks.append(MarkdownBlock(type: .code(codeLanguage), content: currentBlock))
                    currentBlock = ""
                    inCodeBlock = false
                    codeLanguage = ""
                } else {
                    // Start code block
                    if !currentBlock.isEmpty {
                        blocks.append(MarkdownBlock(type: .paragraph, content: currentBlock))
                        currentBlock = ""
                    }
                    inCodeBlock = true
                    codeLanguage = String(line.dropFirst(3))
                }
            } else if inCodeBlock {
                currentBlock += (currentBlock.isEmpty ? "" : "\n") + line
            } else if line.hasPrefix("# ") {
                if !currentBlock.isEmpty {
                    blocks.append(MarkdownBlock(type: .paragraph, content: currentBlock))
                    currentBlock = ""
                }
                blocks.append(MarkdownBlock(type: .heading(1), content: String(line.dropFirst(2))))
            } else if line.hasPrefix("## ") {
                if !currentBlock.isEmpty {
                    blocks.append(MarkdownBlock(type: .paragraph, content: currentBlock))
                    currentBlock = ""
                }
                blocks.append(MarkdownBlock(type: .heading(2), content: String(line.dropFirst(3))))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                currentBlock += (currentBlock.isEmpty ? "" : "\n") + String(line.dropFirst(2))
            } else {
                currentBlock += (currentBlock.isEmpty ? "" : "\n") + line
            }
        }

        if !currentBlock.isEmpty {
            blocks.append(MarkdownBlock(type: .paragraph, content: currentBlock))
        }

        return blocks
    }

    private func parseInline(_ text: String) -> AttributedString {
        var result = AttributedString(text)

        // Bold
        let boldPattern = /\*\*([^*]+)\*\*/
        for match in text.matches(of: boldPattern) {
            if let range = Range(match.range, in: result) {
                result[range].font = .body.bold()
            }
        }

        // Italic
        let italicPattern = /_([^_]+)_/
        for match in text.matches(of: italicPattern) {
            if let range = Range(match.range, in: result) {
                result[range].font = .body.italic()
            }
        }

        // Inline code
        let codePattern = /`([^`]+)`/
        for match in text.matches(of: codePattern) {
            if let range = Range(match.range, in: result) {
                result[range].font = .system(.body, design: .monospaced)
                result[range].backgroundColor = .secondary.opacity(0.1)
            }
        }

        return result
    }

    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1: return .title
        case 2: return .title2
        case 3: return .title3
        default: return .headline
        }
    }

    struct MarkdownBlock: Identifiable {
        let id = UUID()
        let type: BlockType
        let content: String

        enum BlockType: Equatable {
            case paragraph
            case code(String)  // language
            case heading(Int)  // level
            case list
        }
    }
}
```

---

## Paste Handling

### Smart Paste

```swift
extension RichTextEditor {
    /// Handle paste with code detection.
    func handlePaste() {
        guard let pastedText = UIPasteboard.general.string else { return }

        if TextFormatting.isPastedCode(pastedText) {
            // Wrap in code block
            let language = detectLanguage(pastedText)
            let wrappedCode = "```\(language)\n\(pastedText)\n```"
            text += wrappedCode
        } else {
            // Normalize and insert
            let normalized = TextFormatting.normalizeQuotes(pastedText)
            text += normalized
        }
    }

    private func detectLanguage(_ code: String) -> String {
        if code.contains("import SwiftUI") || code.contains("func ") && code.contains("->") {
            return "swift"
        }
        if code.contains("function ") || code.contains("const ") || code.contains("=>") {
            return "javascript"
        }
        if code.contains("def ") || code.contains("import ") && !code.contains("import SwiftUI") {
            return "python"
        }
        return ""
    }
}
```

---

## Keyboard Shortcuts

### Formatting Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘B | Bold selection |
| ⌘I | Italic selection |
| ⌘K | Inline code selection |
| ⌘⇧K | Code block |
| ⌘P | Toggle preview |
| ⌘↩ | Submit message |

```swift
extension RichTextEditor {
    var keyboardShortcuts: some View {
        self
            .keyboardShortcut("b", modifiers: .command) { wrapSelection(with: "**") }
            .keyboardShortcut("i", modifiers: .command) { wrapSelection(with: "_") }
            .keyboardShortcut("k", modifiers: .command) { wrapSelection(with: "`") }
            .keyboardShortcut("k", modifiers: [.command, .shift]) { insertCodeBlock() }
            .keyboardShortcut("p", modifiers: .command) { showPreview.toggle() }
            .keyboardShortcut(.return, modifiers: .command) { onSubmit() }
    }
}
```

---

## Edge Cases

- **Empty selection**: Insert placeholder text with formatting
- **Multi-line selection for inline code**: Convert to code block
- **Pasted text with smart quotes**: Normalize to ASCII
- **Unbalanced code blocks**: Show warning indicator
- **Very long code blocks**: Truncate preview with "Show more"

## Acceptance Criteria

- [ ] RichTextEditor with formatting toolbar
- [ ] Bold, italic, code keyboard shortcuts
- [ ] Inline code highlighting in editor
- [ ] Live markdown preview toggle
- [ ] Smart paste detection for code
- [ ] Code block insertion with language detection
- [ ] Quote normalization for pasted text

## Testing

```swift
class TextFormattingTests: XCTestCase {
    func testWrapText() {
        let result = TextFormatting.wrap("hello", with: "**")
        XCTAssertEqual(result, "**hello**")
    }

    func testCodeDetection() {
        let swiftCode = "func test() -> Bool { return true }"
        XCTAssertTrue(TextFormatting.isPastedCode(swiftCode))

        let plainText = "Hello, this is a message."
        XCTAssertFalse(TextFormatting.isPastedCode(plainText))
    }

    func testQuoteNormalization() {
        let smartQuotes = ""Hello" and 'World'"
        let normalized = TextFormatting.normalizeQuotes(smartQuotes)
        XCTAssertEqual(normalized, "\"Hello\" and 'World'")
    }

    func testCodeBlockExtraction() {
        let text = "```swift\nlet x = 1\n```"
        let blocks = TextFormatting.extractCodeBlocks(text)

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].language, "swift")
    }
}
```
