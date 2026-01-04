# Issue 32: Session Picker Redesign

**Phase:** 5 (Secondary Views)
**Priority:** High
**Status:** Not Started
**Depends On:** Issue #17 (Liquid Glass), Issue #10 (@Observable)

## Goal

Redesign the session picker as a sheet with improved filtering, bulk actions, and session lineage visualization.

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- Depends On: Issue #17 (Liquid Glass), Issue #10 (@Observable).
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
│              ═══ Sessions                    [Done]     │
├─────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────────┐ │
│ │ 🔍 Search sessions...                               │ │
│ └─────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────────┐ │
│ │ [All] [User] [Agent] [Archived]                     │ │
│ └─────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────┤
│ TODAY                                                   │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ ◉ Fix authentication bug                           │ │
│ │   12 messages • 2h ago                        👤   │ │
│ ├─────────────────────────────────────────────────────┤ │
│ │ ○ Add unit tests for API                           │ │
│ │   45 messages • 4h ago                        👤   │ │
│ │   └─ 🤖 Agent: test-runner                   (3)   │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ YESTERDAY                                               │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ ○ Refactor database layer                          │ │
│ │   78 messages • 1d ago                        👤   │ │
│ └─────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────┤
│ 5 user • 140 agent • 3 archived                         │
└─────────────────────────────────────────────────────────┘
```

## Implementation

### SessionPickerSheet

```swift
struct SessionPickerSheet: View {
    let project: Project
    let onSelect: (ProjectSession) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var viewModel: SessionPickerViewModel

    init(project: Project, onSelect: @escaping (ProjectSession) -> Void) {
        self.project = project
        self.onSelect = onSelect
        self._viewModel = State(initialValue: SessionPickerViewModel(project: project))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                SearchBar(text: $viewModel.searchText)

                // Filter chips
                FilterChipsView(
                    selectedFilter: $viewModel.selectedFilter,
                    counts: viewModel.sessionCounts
                )

                // Session list
                SessionListView(
                    sections: viewModel.groupedSessions,
                    selectedSession: viewModel.selectedSession,
                    onSelect: { session in
                        viewModel.selectedSession = session
                        onSelect(session)
                        dismiss()
                    },
                    onArchive: viewModel.archiveSession,
                    onDelete: viewModel.deleteSession,
                    onRename: viewModel.renameSession
                )

                // Footer with counts
                SessionCountFooter(counts: viewModel.sessionCounts)
            }
            .navigationTitle("Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            viewModel.startNewSession()
                            dismiss()
                        } label: {
                            Label("New Session", systemImage: "plus")
                        }

                        Divider()

                        Button(role: .destructive) {
                            viewModel.showBulkArchive = true
                        } label: {
                            Label("Archive Old Sessions", systemImage: "archivebox")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .task {
                await viewModel.loadSessions()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.glass)
    }
}
```

### SessionPickerViewModel

```swift
@MainActor @Observable
final class SessionPickerViewModel {
    let project: Project

    private(set) var sessions: [ProjectSession] = []
    private(set) var sessionCounts: SessionCounts = .zero
    private(set) var isLoading = false

    var searchText = ""
    var selectedFilter: SessionFilter = .all
    var selectedSession: ProjectSession?
    var showBulkArchive = false

    init(project: Project) {
        self.project = project
    }

    var groupedSessions: [SessionSection] {
        let filtered = filteredSessions
        return SessionGrouper.group(filtered)
    }

    var filteredSessions: [ProjectSession] {
        var result = sessions

        // Apply filter
        switch selectedFilter {
        case .all:
            result = result.filter { !$0.isArchived }
        case .user:
            result = result.filter { $0.source == .user && !$0.isArchived }
        case .agent:
            result = result.filter { $0.source == .agent && !$0.isArchived }
        case .archived:
            result = result.filter { $0.isArchived }
        }

        // Apply search
        if !searchText.isEmpty {
            result = result.filter { session in
                session.displayTitle.localizedCaseInsensitiveContains(searchText) ||
                session.summary?.localizedCaseInsensitiveContains(searchText) == true
            }
        }

        return result
    }

    func loadSessions() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let store = SessionStore.shared
            await store.loadSessions(for: project.path)
            await store.loadSessionCounts(for: project.path)

            sessions = store.displaySessions(for: project.path)
            sessionCounts = SessionCounts(
                user: store.countsByProject[project.path]?.user ?? 0,
                agent: store.countsByProject[project.path]?.agent ?? 0,
                archived: store.countsByProject[project.path]?.archived ?? 0
            )
        } catch {
            Logger.error("Failed to load sessions: \(error)")
        }
    }

    func archiveSession(_ session: ProjectSession) async {
        await SessionStore.shared.archiveSession(session.id, for: project.path)
        await loadSessions()
    }

    func deleteSession(_ session: ProjectSession) async {
        await SessionStore.shared.deleteSession(session.id, for: project.path)
        await loadSessions()
    }

    func renameSession(_ session: ProjectSession, newTitle: String) async {
        await SessionStore.shared.renameSession(session.id, for: project.path, title: newTitle)
        await loadSessions()
    }

    func startNewSession() {
        selectedSession = nil
    }
}

enum SessionFilter: String, CaseIterable {
    case all, user, agent, archived

    var displayName: String {
        switch self {
        case .all: return "All"
        case .user: return "User"
        case .agent: return "Agent"
        case .archived: return "Archived"
        }
    }

    var icon: String {
        switch self {
        case .all: return "tray.full"
        case .user: return "person"
        case .agent: return "cpu"
        case .archived: return "archivebox"
        }
    }
}

struct SessionCounts: Equatable {
    let user: Int
    let agent: Int
    let archived: Int

    static let zero = SessionCounts(user: 0, agent: 0, archived: 0)

    var total: Int { user + agent }
}
```

### FilterChipsView

```swift
struct FilterChipsView: View {
    @Binding var selectedFilter: SessionFilter
    let counts: SessionCounts

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SessionFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        filter: filter,
                        count: count(for: filter),
                        isSelected: selectedFilter == filter,
                        action: { selectedFilter = filter }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }

    private func count(for filter: SessionFilter) -> Int {
        switch filter {
        case .all: return counts.total
        case .user: return counts.user
        case .agent: return counts.agent
        case .archived: return counts.archived
        }
    }
}

struct FilterChip: View {
    let filter: SessionFilter
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: filter.icon)
                    .font(.caption)
                Text(filter.displayName)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.accentColor : Color.clear)
        .foregroundStyle(isSelected ? .white : .primary)
        .clipShape(Capsule())
        .glassEffect()
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}
```

### SessionListView

```swift
struct SessionListView: View {
    let sections: [SessionSection]
    let selectedSession: ProjectSession?
    let onSelect: (ProjectSession) -> Void
    let onArchive: (ProjectSession) async -> Void
    let onDelete: (ProjectSession) async -> Void
    let onRename: (ProjectSession, String) async -> Void

    var body: some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.sessions) { session in
                        SessionRowView(
                            session: session,
                            isSelected: selectedSession?.id == session.id,
                            childCount: session.childSessionCount
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { onSelect(session) }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await onDelete(session) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                Task { await onArchive(session) }
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                            .tint(.orange)
                        }
                        .contextMenu {
                            SessionContextMenu(
                                session: session,
                                onRename: { newTitle in
                                    Task { await onRename(session, newTitle) }
                                },
                                onArchive: {
                                    Task { await onArchive(session) }
                                },
                                onDelete: {
                                    Task { await onDelete(session) }
                                }
                            )
                        }
                    }
                } header: {
                    Text(section.title)
                }
            }
        }
        .listStyle(.plain)
    }
}

struct SessionSection: Identifiable {
    let id: String
    let title: String
    let sessions: [ProjectSession]
}

struct SessionGrouper {
    static func group(_ sessions: [ProjectSession]) -> [SessionSection] {
        let calendar = Calendar.current
        let now = Date()

        var today: [ProjectSession] = []
        var yesterday: [ProjectSession] = []
        var thisWeek: [ProjectSession] = []
        var older: [ProjectSession] = []

        for session in sessions {
            guard let date = session.lastActivity else {
                older.append(session)
                continue
            }

            if calendar.isDateInToday(date) {
                today.append(session)
            } else if calendar.isDateInYesterday(date) {
                yesterday.append(session)
            } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
                thisWeek.append(session)
            } else {
                older.append(session)
            }
        }

        var sections: [SessionSection] = []
        if !today.isEmpty {
            sections.append(SessionSection(id: "today", title: "Today", sessions: today))
        }
        if !yesterday.isEmpty {
            sections.append(SessionSection(id: "yesterday", title: "Yesterday", sessions: yesterday))
        }
        if !thisWeek.isEmpty {
            sections.append(SessionSection(id: "week", title: "This Week", sessions: thisWeek))
        }
        if !older.isEmpty {
            sections.append(SessionSection(id: "older", title: "Older", sessions: older))
        }

        return sections
    }
}
```

### SessionRowView

```swift
struct SessionRowView: View {
    let session: ProjectSession
    let isSelected: Bool
    let childCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Selection indicator
                Circle()
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .stroke(Color.secondary, lineWidth: 1)
                    .frame(width: 12, height: 12)

                // Title
                Text(session.displayTitle)
                    .lineLimit(1)

                Spacer()

                // Source indicator
                Image(systemName: session.source == .user ? "person.fill" : "cpu.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("\(session.messageCount) messages")
                Text("•")
                if let lastActivity = session.lastActivity {
                    Text(lastActivity, style: .relative)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            // Child sessions indicator
            if childCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.caption2)
                    Image(systemName: "cpu.fill")
                        .font(.caption2)
                    Text("Agent sessions")
                    Text("(\(childCount))")
                        .fontWeight(.medium)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 16)
            }
        }
        .padding(.vertical, 4)
    }
}
```

### SessionCountFooter

```swift
struct SessionCountFooter: View {
    let counts: SessionCounts

    var body: some View {
        HStack(spacing: 16) {
            Label("\(counts.user) user", systemImage: "person.fill")
            Label("\(counts.agent) agent", systemImage: "cpu.fill")
            if counts.archived > 0 {
                Label("\(counts.archived) archived", systemImage: "archivebox.fill")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding()
        .frame(maxWidth: .infinity)
        .glassEffect()
    }
}
```

## Files to Create

```
CodingBridge/Features/Sessions/
├── SessionPickerSheet.swift       # ~100 lines
├── SessionPickerViewModel.swift   # ~120 lines
├── FilterChipsView.swift          # ~60 lines
├── SessionListView.swift          # ~80 lines
├── SessionRowView.swift           # ~60 lines
├── SessionGrouper.swift           # ~50 lines
├── SessionContextMenu.swift       # ~40 lines
└── SessionCountFooter.swift       # ~30 lines
```

## Files to Modify

| File | Changes |
|------|---------|
| Current `SessionPickerViews.swift` | Replace with new implementation |
| `SessionStore.swift` | Add archiveSession, renameSession methods |

## Acceptance Criteria

- [ ] Sheet with medium/large detents
- [ ] Search sessions
- [ ] Filter by source (user/agent/archived)
- [ ] Grouped by date
- [ ] Session counts in footer
- [ ] Child session indicators
- [ ] Swipe to archive/delete
- [ ] Context menu actions
- [ ] New session action
- [ ] Bulk archive option
- [ ] Glass effect styling
- [ ] Build passes

## Testing

```swift
struct SessionPickerTests: XCTestCase {
    func testSessionGrouping() {
        let today = ProjectSession.mock(lastActivity: Date())
        let yesterday = ProjectSession.mock(lastActivity: Date().addingTimeInterval(-86400))

        let sections = SessionGrouper.group([today, yesterday])

        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections[0].title, "Today")
        XCTAssertEqual(sections[1].title, "Yesterday")
    }

    func testFilteredSessions() {
        let viewModel = SessionPickerViewModel(project: .mock())
        viewModel.selectedFilter = .user

        // Test filtering logic
    }
}
```
