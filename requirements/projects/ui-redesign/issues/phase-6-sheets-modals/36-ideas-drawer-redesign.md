---
number: 36
title: Ideas Drawer Redesign
phase: phase-6-sheets-modals
status: pending
completed_by: null
completed_at: null
verified_by: null
verified_at: null
commit: null
spot_checked: false
blocked_reason: null
---

# Issue 36: Ideas Drawer Redesign

**Phase:** 6 (Sheets & Modals)
**Priority:** Medium
**Status:** Not Started
**Depends On:** Issue #17 (Liquid Glass), Issue #34 (Sheet System)

## Goal

Redesign the ideas drawer with improved organization, tagging, and quick capture capabilities.

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- Depends On: Issue #17 (Liquid Glass), Issue #34 (Sheet System).
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
## Design

```
┌─────────────────────────────────────────────────────────┐
│              ═══ Ideas                       [Done]     │
├─────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────────┐ │
│ │ 🔍 Search ideas...                                  │ │
│ └─────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────────┐ │
│ │ [All] [feature] [bug] [docs] [refactor]            │ │
│ └─────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────────┐ │
│ │ 💡 Add dark mode support                           │ │
│ │    Allow users to switch between light and dark... │ │
│ │    [feature] [ui]                     2h ago       │ │
│ ├─────────────────────────────────────────────────────┤ │
│ │ 🐛 Fix memory leak in WebSocket                    │ │
│ │    The connection isn't being properly cleaned...  │ │
│ │    [bug] [critical]                   1d ago       │ │
│ ├─────────────────────────────────────────────────────┤ │
│ │ 📖 Update API documentation                        │ │
│ │    Add examples for new endpoints...               │ │
│ │    [docs]                             3d ago       │ │
│ └─────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────┤
│        [+ Quick Capture]              [📁 Archive]      │
└─────────────────────────────────────────────────────────┘
```

## Implementation

### IdeasDrawerSheet

```swift
struct IdeasDrawerSheet: View {
    let project: Project

    @Environment(\.dismiss) var dismiss
    @State private var viewModel: IdeasDrawerViewModel
    @State private var showQuickCapture = false
    @State private var showArchive = false

    init(project: Project) {
        self.project = project
        self._viewModel = State(initialValue: IdeasDrawerViewModel(project: project))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                SearchBar(text: $viewModel.searchText)

                // Tag filter
                TagFilterView(
                    selectedTag: $viewModel.selectedTag,
                    allTags: viewModel.allTags
                )

                // Ideas list
                IdeasListView(
                    ideas: viewModel.filteredIdeas,
                    onSelect: viewModel.selectIdea,
                    onArchive: viewModel.archiveIdea,
                    onDelete: viewModel.deleteIdea
                )

                // Bottom actions
                IdeasBottomBar(
                    onQuickCapture: { showQuickCapture = true },
                    onShowArchive: { showArchive = true }
                )
            }
            .navigationTitle("Ideas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }

                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        IdeaEditorView(mode: .create, project: project)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showQuickCapture) {
                QuickCaptureSheet(project: project) { idea in
                    viewModel.addIdea(idea)
                }
            }
            .sheet(isPresented: $showArchive) {
                ArchivedIdeasSheet(project: project)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.glass)
    }
}
```

### IdeasDrawerViewModel

```swift
@MainActor @Observable
final class IdeasDrawerViewModel {
    let project: Project

    private(set) var ideas: [Idea] = []
    private(set) var selectedIdea: Idea?

    var searchText = ""
    var selectedTag: String?

    var allTags: [String] {
        Array(Set(ideas.flatMap { $0.tags })).sorted()
    }

    var filteredIdeas: [Idea] {
        var result = ideas.filter { !$0.isArchived }

        // Filter by tag
        if let tag = selectedTag {
            result = result.filter { $0.tags.contains(tag) }
        }

        // Filter by search
        if !searchText.isEmpty {
            result = result.filter { idea in
                idea.title.localizedCaseInsensitiveContains(searchText) ||
                idea.content.localizedCaseInsensitiveContains(searchText) ||
                idea.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }

        // Sort by most recent
        return result.sorted { $0.createdAt > $1.createdAt }
    }

    init(project: Project) {
        self.project = project
        loadIdeas()
    }

    func loadIdeas() {
        ideas = IdeasStore.shared.ideas(for: project.path)
    }

    func addIdea(_ idea: Idea) {
        IdeasStore.shared.addIdea(idea, for: project.path)
        loadIdeas()
    }

    func selectIdea(_ idea: Idea) {
        selectedIdea = idea
    }

    func archiveIdea(_ idea: Idea) {
        IdeasStore.shared.archiveIdea(idea.id, for: project.path)
        loadIdeas()
    }

    func deleteIdea(_ idea: Idea) {
        IdeasStore.shared.deleteIdea(idea.id, for: project.path)
        loadIdeas()
    }
}
```

### TagFilterView

```swift
struct TagFilterView: View {
    @Binding var selectedTag: String?
    let allTags: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                TagChip(
                    tag: "All",
                    isSelected: selectedTag == nil,
                    action: { selectedTag = nil }
                )

                ForEach(allTags, id: \.self) { tag in
                    TagChip(
                        tag: tag,
                        isSelected: selectedTag == tag,
                        action: { selectedTag = tag }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
}

struct TagChip: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(tag)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.2))
        .foregroundStyle(isSelected ? .white : .primary)
        .clipShape(Capsule())
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}
```

### IdeasListView

```swift
struct IdeasListView: View {
    let ideas: [Idea]
    let onSelect: (Idea) -> Void
    let onArchive: (Idea) -> Void
    let onDelete: (Idea) -> Void

    var body: some View {
        if ideas.isEmpty {
            ContentUnavailableView(
                "No Ideas",
                systemImage: "lightbulb",
                description: Text("Capture ideas to work on later")
            )
        } else {
            List {
                ForEach(ideas) { idea in
                    IdeaRowView(idea: idea)
                        .contentShape(Rectangle())
                        .onTapGesture { onSelect(idea) }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                onDelete(idea)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                onArchive(idea)
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                            .tint(.orange)
                        }
                }
            }
            .listStyle(.plain)
        }
    }
}
```

### IdeaRowView

```swift
struct IdeaRowView: View {
    let idea: Idea

    var typeIcon: String {
        if idea.tags.contains("bug") { return "ladybug.fill" }
        if idea.tags.contains("feature") { return "lightbulb.fill" }
        if idea.tags.contains("docs") { return "book.fill" }
        if idea.tags.contains("refactor") { return "arrow.triangle.2.circlepath" }
        return "lightbulb"
    }

    var typeColor: Color {
        if idea.tags.contains("bug") { return .red }
        if idea.tags.contains("feature") { return .yellow }
        if idea.tags.contains("docs") { return .orange }
        if idea.tags.contains("refactor") { return .purple }
        return .secondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: typeIcon)
                    .foregroundStyle(typeColor)

                Text(idea.title)
                    .font(.headline)
                    .lineLimit(1)
            }

            Text(idea.content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                // Tags
                ForEach(idea.tags.prefix(3), id: \.self) { tag in
                    Text(tag)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(Capsule())
                }

                if idea.tags.count > 3 {
                    Text("+\(idea.tags.count - 3)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(idea.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
```

### QuickCaptureSheet

```swift
struct QuickCaptureSheet: View {
    let project: Project
    let onSave: (Idea) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var content = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextEditor(text: $content)
                    .font(.body)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .focused($isFocused)

                Text("Quick capture an idea. You can add title and tags later.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
            .navigationTitle("Quick Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let idea = Idea(
                            title: extractTitle(from: content),
                            content: content,
                            tags: extractTags(from: content)
                        )
                        onSave(idea)
                        dismiss()
                    }
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(.glass)
    }

    private func extractTitle(from content: String) -> String {
        // Use first line or first 50 chars as title
        let firstLine = content.split(separator: "\n").first.map(String.init) ?? content
        if firstLine.count > 50 {
            return String(firstLine.prefix(50)) + "..."
        }
        return firstLine
    }

    private func extractTags(from content: String) -> [String] {
        // Extract hashtags from content
        let pattern = "#(\\w+)"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(content.startIndex..., in: content)

        return regex?.matches(in: content, range: range).compactMap { match in
            if let range = Range(match.range(at: 1), in: content) {
                return String(content[range]).lowercased()
            }
            return nil
        } ?? []
    }
}
```

### IdeasBottomBar

```swift
struct IdeasBottomBar: View {
    let onQuickCapture: () -> Void
    let onShowArchive: () -> Void

    var body: some View {
        HStack {
            Button(action: onQuickCapture) {
                Label("Quick Capture", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)

            Spacer()

            Button(action: onShowArchive) {
                Label("Archive", systemImage: "archivebox")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .glassEffect()
    }
}
```

### Idea Model

```swift
struct Idea: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var content: String
    var tags: [String]
    var isArchived: Bool
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        tags: [String] = [],
        isArchived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.tags = tags
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
```

## Files to Create

```
CodingBridge/Features/Ideas/
├── IdeasDrawerSheet.swift         # ~100 lines
├── IdeasDrawerViewModel.swift     # ~80 lines
├── TagFilterView.swift            # ~50 lines
├── IdeasListView.swift            # ~60 lines
├── IdeaRowView.swift              # ~60 lines
├── QuickCaptureSheet.swift        # ~80 lines
├── IdeasBottomBar.swift           # ~30 lines
├── IdeaEditorView.swift           # ~150 lines
└── ArchivedIdeasSheet.swift       # ~80 lines
```

## Files to Modify

| File | Changes |
|------|---------|
| Current `IdeasDrawerSheet.swift` | Replace with new implementation |
| `IdeasStore.swift` | Ensure archiveIdea method exists |

## Acceptance Criteria

- [ ] Search ideas by title/content/tags
- [ ] Filter by tag
- [ ] Tag chips with selection
- [ ] Idea rows with type icons
- [ ] Swipe to archive/delete
- [ ] Quick capture sheet
- [ ] Hashtag extraction
- [ ] View archived ideas
- [ ] Create/edit ideas
- [ ] Glass effect styling
- [ ] Build passes

## Testing

```swift
struct IdeasDrawerTests: XCTestCase {
    func testTagExtraction() {
        let content = "Add #feature for #authentication"
        let tags = extractTags(from: content)

        XCTAssertEqual(tags, ["feature", "authentication"])
    }

    func testFilterByTag() {
        let viewModel = IdeasDrawerViewModel(project: .mock())
        viewModel.selectedTag = "bug"

        XCTAssertTrue(viewModel.filteredIdeas.allSatisfy { $0.tags.contains("bug") })
    }

    func testSearchFiltering() {
        let viewModel = IdeasDrawerViewModel(project: .mock())
        viewModel.searchText = "authentication"

        // Test search filtering
    }
}
```
