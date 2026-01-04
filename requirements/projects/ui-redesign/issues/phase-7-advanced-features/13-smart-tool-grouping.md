# Issue 13: Smart Tool Result Grouping

**Phase:** 7 (Advanced Features)
**Priority:** High
**Status:** Not Started
**Depends On:** Issue 05 (ToolCardView)

## Goal

Display tool results with smart grouping: file trees for Glob, collapsible file sections for Grep, unified diffs for Edit, plus grouped file exploration, terminal summaries, and web search results.

## Decision

This is a core requirement (not optional). Schedule alongside ToolCardView and ship in the core experience.

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- Depends On: Issue 05 (ToolCardView).
- Add runtime or tooling dependencies here.

## Touch Set
- Files to create: TBD.
- Files to modify: TBD.

## Interface Definitions
- List new or changed models, protocols, and API payloads.

## Edge Cases
- TBD.

## Tests
- [ ] Unit tests updated or added.
- [ ] UI tests updated or added (if user flows change).
## Current State

- Tool results show as plain text
- Large file lists are hard to navigate
- Search results don't group by file
- Read/Glob/Grep runs appear as separate cards without context
- Terminal output can be noisy without summary/expand
- Web search lists are verbose and not collapsible

## Tool-Specific Grouping

### 1. Glob → File Tree

```swift
struct FileTreeView: View {
    let files: [String]
    @State private var expandedFolders: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(treeNodes, id: \.path) { node in
                FileTreeRow(
                    node: node,
                    isExpanded: expandedFolders.contains(node.path),
                    onToggle: { toggleFolder(node.path) }
                )
            }
        }
    }

    private var treeNodes: [FileTreeNode] {
        FileTreeBuilder.build(from: files)
    }
}

struct FileTreeNode: Identifiable {
    let id = UUID()
    let path: String
    let name: String
    let isDirectory: Bool
    let children: [FileTreeNode]
    let depth: Int
}

struct FileTreeRow: View {
    let node: FileTreeNode
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: MessageDesignSystem.Spacing.xs) {
            // Indentation
            Spacer()
                .frame(width: CGFloat(node.depth) * 16)

            // Expand/collapse for folders
            if node.isDirectory {
                Button(action: onToggle) {
                    ExpandChevron(isExpanded: isExpanded, size: 10)
                }
                .buttonStyle(.plain)
            }

            // Icon
            Image(systemName: node.isDirectory ? "folder.fill" : fileIcon(for: node.name))
                .foregroundStyle(node.isDirectory ? .blue : .secondary)
                .frame(width: 16)

            // Name
            Text(node.name)
                .font(MessageDesignSystem.codeFont())

            Spacer()
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
```

### 2. Grep → Grouped Search Results

```swift
struct GrepResultsView: View {
    let results: [GrepMatch]
    @State private var expandedFiles: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: MessageDesignSystem.Spacing.sm) {
            ForEach(groupedResults, id: \.file) { group in
                GrepFileSection(
                    file: group.file,
                    matches: group.matches,
                    isExpanded: expandedFiles.contains(group.file),
                    onToggle: { toggleFile(group.file) }
                )
            }
        }
    }

    private var groupedResults: [GrepFileGroup] {
        Dictionary(grouping: results, by: \.file)
            .map { GrepFileGroup(file: $0.key, matches: $0.value) }
            .sorted { $0.file < $1.file }
    }
}

struct GrepFileSection: View {
    let file: String
    let matches: [GrepMatch]
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // File header
            Button(action: onToggle) {
                HStack {
                    ExpandChevron(isExpanded: isExpanded)
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                    Text(file)
                        .font(MessageDesignSystem.codeFont())
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(matches.count)")
                        .font(MessageDesignSystem.labelFont())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }
            }
            .buttonStyle(.plain)

            // Matches
            if isExpanded {
                ForEach(matches, id: \.lineNumber) { match in
                    GrepMatchRow(match: match)
                }
                .padding(.leading, MessageDesignSystem.Spacing.contentIndent)
            }
        }
    }
}

struct GrepMatchRow: View {
    let match: GrepMatch

    var body: some View {
        HStack(alignment: .top, spacing: MessageDesignSystem.Spacing.sm) {
            Text("\(match.lineNumber)")
                .font(MessageDesignSystem.labelFont())
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)

            Text(highlightedContent)
                .font(MessageDesignSystem.codeFont())
        }
        .padding(.vertical, 2)
    }

    private var highlightedContent: AttributedString {
        // Highlight matched portion
        var str = AttributedString(match.content)
        if let range = str.range(of: match.matchedText) {
            str[range].backgroundColor = .yellow.opacity(0.3)
            str[range].foregroundColor = .primary
        }
        return str
    }
}

struct GrepMatch: Identifiable {
    let id = UUID()
    let file: String
    let lineNumber: Int
    let content: String
    let matchedText: String
}
```

### 3. Edit → Unified Diff View

Already have DiffView, but enhance with:

```swift
struct EnhancedDiffView: View {
    let filePath: String
    let oldContent: String
    let newContent: String
    @State private var viewMode: DiffViewMode = .unified

    enum DiffViewMode {
        case unified    // Single column with +/-
        case sideBySide // Two columns
        case compact    // Only changed lines
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // File header
            HStack {
                Image(systemName: "doc.text")
                Text(filePath)
                    .font(MessageDesignSystem.codeFont())
                Spacer()
                Picker("View", selection: $viewMode) {
                    Image(systemName: "rectangle.split.1x2").tag(DiffViewMode.unified)
                    Image(systemName: "rectangle.split.2x1").tag(DiffViewMode.sideBySide)
                    Image(systemName: "line.3.horizontal.decrease").tag(DiffViewMode.compact)
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
            }
            .padding(MessageDesignSystem.Spacing.sm)
            .background(.quaternary)

            // Diff content based on mode
            switch viewMode {
            case .unified:
                UnifiedDiffContent(old: oldContent, new: newContent)
            case .sideBySide:
                SideBySideDiffContent(old: oldContent, new: newContent)
            case .compact:
                CompactDiffContent(old: oldContent, new: newContent)
            }
        }
    }
}
```

### 4. File Exploration Grouping (Read/Glob/Grep)

- Group consecutive Read/Glob/Grep tool runs into a single "Explored Files" card.
- Show a compact summary with error indicators; expand to reveal per-file content.

### 5. Terminal Summaries

- Collapse bash outputs into a summary line (exit code, duration, truncated output).
- Tap to expand full output.

### 6. Web Search Results

- Collapsible list with title, domain, and snippet.
- Links should be tappable with proper URL handling.

### 4. WebSearch → Source Cards

```swift
struct WebSearchResultsView: View {
    let results: [WebSearchResult]

    var body: some View {
        VStack(alignment: .leading, spacing: MessageDesignSystem.Spacing.sm) {
            ForEach(results) { result in
                WebSearchResultCard(result: result)
            }
        }
    }
}

struct WebSearchResultCard: View {
    let result: WebSearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: MessageDesignSystem.Spacing.xs) {
            // Title with link
            Link(destination: result.url) {
                Text(result.title)
                    .font(MessageDesignSystem.bodyFont())
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
            }

            // URL
            Text(result.displayUrl)
                .font(MessageDesignSystem.captionFont())
                .foregroundStyle(.secondary)

            // Snippet
            Text(result.snippet)
                .font(MessageDesignSystem.captionFont())
                .lineLimit(3)
        }
        .padding(MessageDesignSystem.Spacing.sm)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: MessageDesignSystem.CornerRadius.sm))
    }
}
```

## Tool Result Parser

```swift
enum ToolResultParser {
    static func parse(tool: String, content: String) -> ToolResultContent {
        switch tool.lowercased() {
        case "glob":
            return .fileTree(parseFileList(content))
        case "grep":
            return .searchResults(parseGrepOutput(content))
        case "edit":
            return .diff(parseDiff(content))
        case "websearch", "webfetch":
            return .webResults(parseWebResults(content))
        case "todowrite":
            return .todoList(parseTodoList(content))
        default:
            return .text(content)
        }
    }
}

enum ToolResultContent {
    case text(String)
    case fileTree([String])
    case searchResults([GrepMatch])
    case diff(DiffContent)
    case webResults([WebSearchResult])
    case todoList([TodoItem])
}
```

## Files to Create

```
CodingBridge/Views/Messages/ToolViews/
├── FileTreeView.swift
├── GrepResultsView.swift
├── EnhancedDiffView.swift
├── WebSearchResultsView.swift
└── ToolResultParser.swift
```

## Integration with ToolCardView

```swift
// In ToolCardView
@ViewBuilder
private var toolContent: some View {
    switch ToolResultParser.parse(tool: toolName, content: message.content) {
    case .fileTree(let files):
        FileTreeView(files: files)
    case .searchResults(let matches):
        GrepResultsView(results: matches)
    case .diff(let diff):
        EnhancedDiffView(filePath: diff.path, old: diff.old, new: diff.new)
    case .webResults(let results):
        WebSearchResultsView(results: results)
    case .todoList(let items):
        TodoListView(items: items)
    case .text(let text):
        Text(text)
            .font(MessageDesignSystem.codeFont())
    }
}
```

## Acceptance Criteria

- [ ] Glob shows collapsible file tree
- [ ] Grep groups results by file with match count
- [ ] Grep highlights matched text
- [ ] Edit shows diff with view mode toggle
- [ ] WebSearch shows source cards with links
- [ ] All views respect MessageDesignSystem tokens
- [ ] Build passes

## Code Examples

TBD. Add concrete Swift examples before implementation.
