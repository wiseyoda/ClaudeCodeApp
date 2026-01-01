import SwiftUI

/// View for displaying Write tool content with line numbers and expandable preview.
/// Shows first N lines with a fade effect and expand button.
struct WritePreviewView: View {
    let filePath: String
    let content: String

    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme
    @State private var isExpanded = false

    /// Number of lines to show in collapsed state
    private let previewLineCount = 8

    /// Parsed and normalized lines
    private var lines: [String] {
        let rawLines = content.components(separatedBy: "\n")
        return normalizeIndentation(rawLines)
    }

    /// Lines to display (preview or all)
    private var displayLines: [String] {
        if isExpanded {
            return lines
        }
        return Array(lines.prefix(previewLineCount))
    }

    /// Number of hidden lines
    private var hiddenLineCount: Int {
        max(0, lines.count - previewLineCount)
    }

    /// Whether we need the expand button
    private var needsExpand: Bool {
        lines.count > previewLineCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: line count summary
            headerView

            // Code lines
            ZStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(displayLines.enumerated()), id: \.offset) { index, line in
                        WriteLineView(
                            lineNumber: index + 1,
                            content: line
                        )
                        .environmentObject(settings)
                    }
                }

                // Gradient fade overlay (only when collapsed and has more)
                if !isExpanded && needsExpand {
                    LinearGradient(
                        colors: [
                            CLITheme.secondaryBackground(for: colorScheme).opacity(0),
                            CLITheme.secondaryBackground(for: colorScheme).opacity(0.5),
                            CLITheme.secondaryBackground(for: colorScheme).opacity(0.95)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 40)
                    .allowsHitTesting(false)
                }
            }

            // Expand button
            if needsExpand {
                expandButton
            }
        }
        .background(CLITheme.secondaryBackground(for: colorScheme))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(CLITheme.mutedText(for: colorScheme).opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 6) {
            Text("Wrote \(lines.count) lines to")
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))

            Text(ToolParser.shortenPath(filePath))
                .foregroundColor(CLITheme.primaryText(for: colorScheme))
                .bold()
        }
        .font(settings.scaledFont(.small))
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CLITheme.background(for: colorScheme).opacity(0.5))
    }

    // MARK: - Expand Button

    private var expandButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10))
                Text(isExpanded ? "Show less" : "+\(hiddenLineCount) lines (tap to expand)")
            }
            .font(settings.scaledFont(.small))
            .foregroundColor(CLITheme.mutedText(for: colorScheme))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .background(CLITheme.background(for: colorScheme).opacity(0.3))
    }

    // MARK: - Indentation Normalization

    /// Normalize indentation for mobile readability
    private func normalizeIndentation(_ rawLines: [String]) -> [String] {
        // Convert tabs to 2 spaces
        let tabNorm = rawLines.map { $0.replacingOccurrences(of: "\t", with: "  ") }

        // Find minimum leading whitespace
        var minIndent = Int.max
        for line in tabNorm {
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            let leadingSpaces = line.prefix(while: { $0 == " " }).count
            minIndent = min(minIndent, leadingSpaces)
        }

        if minIndent == Int.max { minIndent = 0 }

        // Compress indentation: strip common prefix, then halve remaining indent
        return tabNorm.map { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return "" }

            let currentIndent = line.prefix(while: { $0 == " " }).count
            let relativeIndent = currentIndent - minIndent
            let newIndent = max(0, relativeIndent / 2)
            return String(repeating: " ", count: newIndent) + trimmed
        }
    }

    // MARK: - Parse Write Content

    /// Parse file_path and content from Write tool JSON
    static func parseWriteContent(_ toolContent: String) -> (filePath: String, content: String)? {
        guard toolContent.hasPrefix("Write") else { return nil }

        guard let jsonStart = toolContent.firstIndex(of: "{"),
              let jsonEnd = toolContent.lastIndex(of: "}") else {
            return nil
        }

        let jsonString = String(toolContent[jsonStart...jsonEnd])
        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let filePath = dict["file_path"] as? String,
              let content = dict["content"] as? String else {
            return nil
        }

        return (filePath, content)
    }
}

// MARK: - Write Line View

struct WriteLineView: View {
    let lineNumber: Int
    let content: String

    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            // Line number
            Text(String(lineNumber))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))
                .frame(width: 28, alignment: .trailing)
                .padding(.trailing, 6)

            // Content
            Text(content.isEmpty ? " " : content)
                .font(settings.scaledFont(.small))
                .foregroundColor(CLITheme.primaryText(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)  // Force word wrap
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
        }
    }
}

// MARK: - Preview

#Preview("Write Preview - Short") {
    WritePreviewView(
        filePath: "/Users/test/project/src/main.swift",
        content: """
        import SwiftUI

        struct ContentView: View {
            var body: some View {
                Text("Hello, World!")
            }
        }
        """
    )
    .environmentObject(AppSettings())
    .padding()
    .background(Color.black)
}

#Preview("Write Preview - Long") {
    WritePreviewView(
        filePath: "/Users/test/project/tests/integration/git-status-debug.ts",
        content: """
        /**
         * Git Status Debug Script
         *
         * Tests the git status API endpoints and verifies correct parsing
         *
         * Run with: deno run --allow-net tests/integration/git-status-debug.ts
         */
        const SERVER_URL = "http://172.20.0.2:3100";

        interface GitStatus {
            branch: string;
            ahead: number;
            behind: number;
            dirty: boolean;
        }

        async function main() {
            console.log("Starting git status debug...");
            // More code here...
        }

        main();
        """
    )
    .environmentObject(AppSettings())
    .padding()
    .background(Color.black)
}
