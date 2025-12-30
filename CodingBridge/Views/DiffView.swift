import SwiftUI

// MARK: - Diff Line Type

enum DiffLineType {
    case context    // Unchanged line
    case removed    // Deleted line
    case added      // Inserted line
    case collapsed  // Placeholder for collapsed context
}

// MARK: - Diff Line

struct DiffLine: Identifiable {
    let id = UUID()
    let type: DiffLineType
    let oldLineNumber: Int?
    let newLineNumber: Int?
    let content: String
    let collapsedCount: Int  // For collapsed lines
}

// MARK: - Enhanced Diff View

struct DiffView: View {
    let oldString: String
    let newString: String
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme
    @State private var expandedSections: Set<UUID> = []

    /// Cached diff lines - computed once on appear/input change to avoid recalculation on every render
    @State private var cachedDiffLines: [DiffLine] = []
    /// Track input hash to detect when diff needs recomputation
    @State private var inputHash: Int = 0

    private let contextLines = 2  // Lines of context around changes

    /// Compute stable hash of inputs to detect changes
    private var currentInputHash: Int {
        var hasher = Hasher()
        hasher.combine(oldString)
        hasher.combine(newString)
        return hasher.finalize()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(cachedDiffLines) { line in
                DiffLineView(
                    line: line,
                    isExpanded: expandedSections.contains(line.id),
                    onToggleExpand: {
                        if expandedSections.contains(line.id) {
                            expandedSections.remove(line.id)
                        } else {
                            expandedSections.insert(line.id)
                        }
                    }
                )
                .environmentObject(settings)
            }
        }
        .background(CLITheme.secondaryBackground(for: colorScheme))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(CLITheme.mutedText(for: colorScheme).opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            // Compute diff once on appear
            if inputHash != currentInputHash {
                cachedDiffLines = computeDiff()
                inputHash = currentInputHash
            }
        }
        .onChange(of: oldString) { _, _ in
            // Recompute if inputs change (rare case)
            cachedDiffLines = computeDiff()
            inputHash = currentInputHash
        }
        .onChange(of: newString) { _, _ in
            cachedDiffLines = computeDiff()
            inputHash = currentInputHash
        }
    }

    /// Compute line-by-line diff using simple LCS-based approach
    private func computeDiff() -> [DiffLine] {
        // Normalize indentation for mobile readability (normalize together for consistent indent)
        let rawOldLines = oldString.components(separatedBy: "\n")
        let rawNewLines = newString.components(separatedBy: "\n")
        let (oldLines, newLines) = normalizeIndentationTogether(rawOldLines, rawNewLines)

        // Simple diff: find common prefix and suffix, treat middle as changed
        // For MVP, use a simpler approach since full LCS is complex

        var result: [DiffLine] = []
        var oldIdx = 0
        var newIdx = 0

        // Find common prefix
        while oldIdx < oldLines.count && newIdx < newLines.count &&
              oldLines[oldIdx] == newLines[newIdx] {
            result.append(DiffLine(
                type: .context,
                oldLineNumber: oldIdx + 1,
                newLineNumber: newIdx + 1,
                content: oldLines[oldIdx],
                collapsedCount: 0
            ))
            oldIdx += 1
            newIdx += 1
        }

        // Find common suffix
        var oldEnd = oldLines.count - 1
        var newEnd = newLines.count - 1
        var suffixLines: [DiffLine] = []

        while oldEnd >= oldIdx && newEnd >= newIdx &&
              oldLines[oldEnd] == newLines[newEnd] {
            suffixLines.insert(DiffLine(
                type: .context,
                oldLineNumber: oldEnd + 1,
                newLineNumber: newEnd + 1,
                content: oldLines[oldEnd],
                collapsedCount: 0
            ), at: 0)
            oldEnd -= 1
            newEnd -= 1
        }

        // Middle section: all removed from old, then all added from new
        while oldIdx <= oldEnd {
            result.append(DiffLine(
                type: .removed,
                oldLineNumber: oldIdx + 1,
                newLineNumber: nil,
                content: oldLines[oldIdx],
                collapsedCount: 0
            ))
            oldIdx += 1
        }

        while newIdx <= newEnd {
            result.append(DiffLine(
                type: .added,
                oldLineNumber: nil,
                newLineNumber: newIdx + 1,
                content: newLines[newIdx],
                collapsedCount: 0
            ))
            newIdx += 1
        }

        // Add suffix
        result.append(contentsOf: suffixLines)

        // Collapse long unchanged sections
        return collapseContext(result)
    }

    /// Collapse long runs of unchanged context lines
    private func collapseContext(_ lines: [DiffLine]) -> [DiffLine] {
        guard lines.count > 10 else { return lines }

        var result: [DiffLine] = []
        var contextRun: [DiffLine] = []

        for line in lines {
            if line.type == .context {
                contextRun.append(line)
            } else {
                // Flush context run with possible collapse
                result.append(contentsOf: flushContextRun(contextRun))
                contextRun = []
                result.append(line)
            }
        }

        // Final context flush
        result.append(contentsOf: flushContextRun(contextRun))

        return result
    }

    /// Convert a run of context lines, collapsing if too long
    private func flushContextRun(_ run: [DiffLine]) -> [DiffLine] {
        if run.count <= contextLines * 2 + 1 {
            return run
        }

        var result: [DiffLine] = []

        // Keep first N context lines
        result.append(contentsOf: run.prefix(contextLines))

        // Add collapsed placeholder
        let collapsedCount = run.count - contextLines * 2
        result.append(DiffLine(
            type: .collapsed,
            oldLineNumber: nil,
            newLineNumber: nil,
            content: "",
            collapsedCount: collapsedCount
        ))

        // Keep last N context lines
        result.append(contentsOf: run.suffix(contextLines))

        return result
    }

    /// Normalize indentation for mobile readability:
    /// 1. Convert tabs to 2 spaces
    /// 2. Strip common leading whitespace
    /// 3. Compress remaining indentation (4 spaces → 2 spaces per level)
    private func normalizeIndentationTogether(_ oldLines: [String], _ newLines: [String]) -> ([String], [String]) {
        // Convert tabs to 2 spaces
        let oldTabNorm = oldLines.map { $0.replacingOccurrences(of: "\t", with: "  ") }
        let newTabNorm = newLines.map { $0.replacingOccurrences(of: "\t", with: "  ") }

        // Find minimum leading whitespace across ALL lines (both old and new)
        var minIndent = Int.max
        for line in oldTabNorm + newTabNorm {
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            let leadingSpaces = line.prefix(while: { $0 == " " }).count
            minIndent = min(minIndent, leadingSpaces)
        }

        if minIndent == Int.max { minIndent = 0 }

        // Compress indentation: strip common prefix, then halve remaining indent
        let compressIndent: (String) -> String = { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return "" }

            let currentIndent = line.prefix(while: { $0 == " " }).count
            let relativeIndent = currentIndent - minIndent
            // Compress: 4 spaces → 2 spaces (halve the indent)
            let newIndent = max(0, relativeIndent / 2)
            return String(repeating: " ", count: newIndent) + trimmed
        }

        return (oldTabNorm.map(compressIndent), newTabNorm.map(compressIndent))
    }

    /// Parse old_string and new_string from Edit tool content
    static func parseEditContent(_ content: String) -> (old: String, new: String)? {
        guard content.hasPrefix("Edit") else { return nil }

        // Try JSON format first: Edit({"file_path":"...","old_string":"...","new_string":"..."})
        if let jsonStart = content.firstIndex(of: "{"),
           let jsonEnd = content.lastIndex(of: "}") {
            let jsonString = String(content[jsonStart...jsonEnd])
            if let data = jsonString.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let oldString = dict["old_string"] as? String,
               let newString = dict["new_string"] as? String {
                return (cleanAnyCodableWrapper(oldString), cleanAnyCodableWrapper(newString))
            }
        }

        // Fallback to legacy text format: Edit(old_string: ..., new_string: ...)
        var oldString = ""
        var newString = ""

        if let oldRange = content.range(of: "old_string: ") {
            let afterOld = content[oldRange.upperBound...]
            if let endRange = afterOld.range(of: ", new_string: ") {
                oldString = String(afterOld[..<endRange.lowerBound])
            }
        }

        if let newRange = content.range(of: "new_string: ") {
            let afterNew = content[newRange.upperBound...]
            if let endRange = afterNew.range(of: ", replace_all:") {
                newString = String(afterNew[..<endRange.lowerBound])
            } else if let endRange = afterNew.range(of: ")") {
                newString = String(afterNew[..<endRange.lowerBound])
            } else {
                newString = String(afterNew)
            }
        }

        if oldString.isEmpty && newString.isEmpty {
            return nil
        }

        return (cleanAnyCodableWrapper(oldString), cleanAnyCodableWrapper(newString))
    }

    /// Remove AnyCodableValue(value: "...") wrapper if present
    private static func cleanAnyCodableWrapper(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespaces)

        // Check for AnyCodableValue(value: "...") pattern
        if result.hasPrefix("AnyCodableValue(value: ") && result.hasSuffix(")") {
            // Remove prefix
            result = String(result.dropFirst("AnyCodableValue(value: ".count))
            // Remove trailing )
            result = String(result.dropLast())
            // Remove surrounding quotes if present
            if result.hasPrefix("\"") && result.hasSuffix("\"") && result.count >= 2 {
                result = String(result.dropFirst().dropLast())
            }
        }

        return result
    }
}

// MARK: - Diff Line View

struct DiffLineView: View {
    let line: DiffLine
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if line.type == .collapsed && !isExpanded {
            collapsedView
        } else {
            regularLineView
        }
    }

    private var collapsedView: some View {
        Button(action: onToggleExpand) {
            HStack(spacing: 0) {
                // Placeholder for line number column
                Text("┈┈")
                    .font(.system(size: 10, design: .monospaced))
                    .frame(width: 36, alignment: .trailing)
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
                    .padding(.trailing, 6)

                // Collapsed indicator
                HStack(spacing: 4) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                    Text("\(line.collapsedCount) unchanged lines")
                }
                .font(settings.scaledFont(.small))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))
                .padding(.horizontal, 4)
                .padding(.vertical, 4)

                Spacer()
            }
        }
        .buttonStyle(.plain)
        .background(CLITheme.background(for: colorScheme).opacity(0.5))
    }

    private var regularLineView: some View {
        HStack(spacing: 0) {
            // Combined line number + indicator (e.g., "5 -", "6 +", "7")
            Text(lineNumberText)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(indicatorColor)
                .frame(width: 36, alignment: .trailing)
                .padding(.trailing, 6)

            // Content
            Text(line.content.isEmpty ? " " : line.content)
                .font(settings.scaledFont(.small))
                .foregroundColor(contentColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
        }
        .background(backgroundColor)
    }

    /// Combined line number with indicator: "5 -" for removed, "6 +" for added, "7" for context
    private var lineNumberText: String {
        switch line.type {
        case .removed:
            return line.oldLineNumber.map { "\($0) -" } ?? "-"
        case .added:
            return line.newLineNumber.map { "\($0) +" } ?? "+"
        case .context:
            return line.oldLineNumber.map { String($0) } ?? ""
        case .collapsed:
            return ""
        }
    }

    private var indicatorColor: Color {
        switch line.type {
        case .removed: return CLITheme.red(for: colorScheme)
        case .added: return CLITheme.green(for: colorScheme)
        case .context, .collapsed: return CLITheme.mutedText(for: colorScheme)
        }
    }

    private var contentColor: Color {
        switch line.type {
        case .removed: return CLITheme.diffRemovedText(for: colorScheme)
        case .added: return CLITheme.diffAddedText(for: colorScheme)
        case .context, .collapsed: return CLITheme.secondaryText(for: colorScheme)
        }
    }

    private var backgroundColor: Color {
        switch line.type {
        case .removed: return CLITheme.diffRemoved(for: colorScheme)
        case .added: return CLITheme.diffAdded(for: colorScheme)
        case .context, .collapsed: return .clear
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        DiffView(
            oldString: """
                function hello() {
                    console.log("Hello");
                    return true;
                }
                """,
            newString: """
                function hello() {
                    console.log("Hello, World!");
                    console.log("More output");
                    return true;
                }
                """
        )
        .environmentObject(AppSettings())
        .padding()
    }
    .background(Color.black)
}
