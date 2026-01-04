---
number: 35
title: Command Picker Redesign
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

# Issue 35: Command Picker Redesign

**Phase:** 6 (Sheets & Modals)
**Priority:** Medium
**Status:** Not Started
**Depends On:** Issue #17 (Liquid Glass), Issue #34 (Sheet System)

## Goal

Redesign the command picker with improved categorization, search, recently used commands, and a slash-command palette with autocomplete (especially on iPad hardware keyboards).

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

### Slash Command Palette

- Triggered by typing `/` in the chat input or tapping the command button.
- Shows autocomplete suggestions for local commands with descriptions and argument hints.
- iPad (hardware keyboard): show inline palette anchored to the input field.
- iPhone: present as a compact sheet or inline list above the keyboard.
┌─────────────────────────────────────────────────────────┐
│              ═══ Commands                    [Done]     │
├─────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────────┐ │
│ │ 🔍 Search commands...                               │ │
│ └─────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────┤
│ RECENT                                                  │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ 🕐 Review this PR                                   │ │
│ │ 🕐 Write unit tests                                 │ │
│ └─────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────┤
│ CATEGORIES                                              │
│ ┌───────────┐ ┌───────────┐ ┌───────────┐              │
│ │ 📝 Code   │ │ 🧪 Test   │ │ 📖 Docs   │              │
│ └───────────┘ └───────────┘ └───────────┘              │
│ ┌───────────┐ ┌───────────┐ ┌───────────┐              │
│ │ 🔀 Git    │ │ 🐛 Debug  │ │ ⭐ Custom │              │
│ └───────────┘ └───────────┘ └───────────┘              │
├─────────────────────────────────────────────────────────┤
│ ALL COMMANDS                                            │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ 📝 Review this code                                 │ │
│ │    Code review with suggestions                     │ │
│ ├─────────────────────────────────────────────────────┤ │
│ │ 🧪 Write unit tests                                 │ │
│ │    Generate comprehensive tests                     │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## Implementation

### CommandPickerSheet

```swift
struct CommandPickerSheet: View {
    let onSelect: (SavedCommand) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var viewModel = CommandPickerViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                SearchBar(text: $viewModel.searchText)

                ScrollView {
                    LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                        // Recent commands
                        if viewModel.searchText.isEmpty && !viewModel.recentCommands.isEmpty {
                            RecentCommandsSection(
                                commands: viewModel.recentCommands,
                                onSelect: selectCommand
                            )
                        }

                        // Category grid
                        if viewModel.searchText.isEmpty {
                            CategoryGridSection(
                                selectedCategory: $viewModel.selectedCategory,
                                categories: viewModel.categories
                            )
                        }

                        // Commands list
                        CommandsListSection(
                            commands: viewModel.filteredCommands,
                            onSelect: selectCommand,
                            onEdit: viewModel.editCommand,
                            onDelete: viewModel.deleteCommand
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("Commands")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }

                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        CommandEditorView(mode: .create)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.glass)
    }

    private func selectCommand(_ command: SavedCommand) {
        viewModel.markUsed(command)
        onSelect(command)
        dismiss()
    }
}
```

### CommandPickerViewModel

```swift
@MainActor @Observable
final class CommandPickerViewModel {
    private(set) var commands: [SavedCommand] = []
    private(set) var recentCommands: [SavedCommand] = []

    var searchText = ""
    var selectedCategory: CommandCategory?

    var categories: [CommandCategory] {
        CommandCategory.allCases
    }

    var filteredCommands: [SavedCommand] {
        var result = commands

        // Filter by category
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        // Filter by search
        if !searchText.isEmpty {
            result = result.filter { command in
                command.name.localizedCaseInsensitiveContains(searchText) ||
                command.content.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    init() {
        loadCommands()
    }

    func loadCommands() {
        let store = CommandStore.shared
        commands = store.commands
        recentCommands = store.recentCommands(limit: 3)
    }

    func markUsed(_ command: SavedCommand) {
        CommandStore.shared.markUsed(command)
    }

    func editCommand(_ command: SavedCommand) {
        // Navigate to editor
    }

    func deleteCommand(_ command: SavedCommand) {
        CommandStore.shared.delete(command)
        loadCommands()
    }
}
```

### CategoryGridSection

```swift
struct CategoryGridSection: View {
    @Binding var selectedCategory: CommandCategory?
    let categories: [CommandCategory]

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        Section {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    CategoryButton(
                        category: category,
                        isSelected: selectedCategory == category,
                        action: {
                            if selectedCategory == category {
                                selectedCategory = nil
                            } else {
                                selectedCategory = category
                            }
                        }
                    )
                }
            }
        } header: {
            SectionHeader(title: "Categories")
        }
    }
}

struct CategoryButton: View {
    let category: CommandCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.title2)
                Text(category.displayName)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .glassEffect()
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}
```

### RecentCommandsSection

```swift
struct RecentCommandsSection: View {
    let commands: [SavedCommand]
    let onSelect: (SavedCommand) -> Void

    var body: some View {
        Section {
            VStack(spacing: 8) {
                ForEach(commands) { command in
                    RecentCommandRow(command: command)
                        .contentShape(Rectangle())
                        .onTapGesture { onSelect(command) }
                }
            }
            .glassEffect()
        } header: {
            SectionHeader(title: "Recent")
        }
    }
}

struct RecentCommandRow: View {
    let command: SavedCommand

    var body: some View {
        HStack {
            Image(systemName: "clock")
                .foregroundStyle(.secondary)

            Text(command.name)
                .lineLimit(1)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
```

### CommandsListSection

```swift
struct CommandsListSection: View {
    let commands: [SavedCommand]
    let onSelect: (SavedCommand) -> Void
    let onEdit: (SavedCommand) -> Void
    let onDelete: (SavedCommand) -> Void

    var body: some View {
        Section {
            VStack(spacing: 0) {
                ForEach(commands) { command in
                    CommandRowView(command: command)
                        .contentShape(Rectangle())
                        .onTapGesture { onSelect(command) }
                        .contextMenu {
                            Button {
                                onSelect(command)
                            } label: {
                                Label("Use", systemImage: "play")
                            }

                            Button {
                                onEdit(command)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }

                            Divider()

                            Button(role: .destructive) {
                                onDelete(command)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }

                    if command.id != commands.last?.id {
                        Divider()
                            .padding(.leading, 44)
                    }
                }
            }
            .glassEffect()
        } header: {
            SectionHeader(title: "All Commands")
        }
    }
}

struct CommandRowView: View {
    let command: SavedCommand

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: command.category.icon)
                .font(.title3)
                .foregroundStyle(command.category.color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(command.name)
                    .lineLimit(1)

                Text(command.content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(12)
    }
}
```

### CommandCategory

```swift
enum CommandCategory: String, CaseIterable, Codable {
    case code, test, docs, git, debug, custom

    var displayName: String {
        switch self {
        case .code: return "Code"
        case .test: return "Test"
        case .docs: return "Docs"
        case .git: return "Git"
        case .debug: return "Debug"
        case .custom: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .code: return "doc.text"
        case .test: return "testtube.2"
        case .docs: return "book"
        case .git: return "arrow.triangle.branch"
        case .debug: return "ladybug"
        case .custom: return "star"
        }
    }

    var color: Color {
        switch self {
        case .code: return .blue
        case .test: return .green
        case .docs: return .orange
        case .git: return .purple
        case .debug: return .red
        case .custom: return .yellow
        }
    }
}
```

## Files to Create

```
CodingBridge/Features/Commands/
├── CommandPickerSheet.swift       # ~100 lines
├── CommandPickerViewModel.swift   # ~80 lines
├── CategoryGridSection.swift      # ~60 lines
├── RecentCommandsSection.swift    # ~50 lines
├── CommandsListSection.swift      # ~80 lines
├── CommandRowView.swift           # ~40 lines
├── CommandCategory.swift          # ~50 lines
└── CommandEditorView.swift        # ~150 lines
```

## Files to Modify

| File | Changes |
|------|---------|
| Current `CommandPickerSheet.swift` | Replace with new implementation |
| `CommandStore.swift` | Add recentCommands method |
| `SavedCommand.swift` | Add category property |

## Acceptance Criteria

- [ ] Search commands
- [ ] Recent commands section
- [ ] Category grid
- [ ] Category filtering
- [ ] Command list with details
- [ ] Context menu actions
- [ ] Create new command
- [ ] Edit existing command
- [ ] Delete with confirmation
- [ ] Glass effect styling
- [ ] Build passes

## Testing

```swift
struct CommandPickerTests: XCTestCase {
    func testCategoryFiltering() {
        let viewModel = CommandPickerViewModel()
        viewModel.selectedCategory = .code

        // Test that only code commands are shown
        XCTAssertTrue(viewModel.filteredCommands.allSatisfy { $0.category == .code })
    }

    func testSearchFiltering() {
        let viewModel = CommandPickerViewModel()
        viewModel.searchText = "test"

        // Test search filtering
    }

    func testRecentCommands() {
        let store = CommandStore.shared
        let recent = store.recentCommands(limit: 3)

        XCTAssertLessThanOrEqual(recent.count, 3)
    }
}
```
