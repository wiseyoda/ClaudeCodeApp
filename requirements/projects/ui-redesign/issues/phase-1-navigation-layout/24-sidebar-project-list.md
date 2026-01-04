# Issue 24: Sidebar & Project List

**Phase:** 1 (Navigation & Layout)
**Priority:** High
**Status:** Not Started
**Depends On:** Issue #23 (Navigation Architecture)
**Target:** iOS 26.2, Xcode 26.2, Swift 6.2.1

## Goal

Create a Liquid Glass sidebar with project list, utility actions, and new project options.

## Decisions

- Simplify project rows for large lists; keep metadata minimal by default.
- Do not compute git status client-side. Display cli-bridge status (branch/dirty/ahead-behind/conflicts) only when reported; otherwise show an "unknown" state or omit.

## Scope
- In scope: SidebarView with searchable project list, project row metadata (session count, last activity), swipe-to-delete, context menu, utility actions section, new project menu.
- Out of scope: Dark mode theming (Phase 3), git status display (cli-bridge only, Issue #70), sorting/filtering beyond search (Phase 3).

## Non-goals
- Client-side git status computation; show cli-bridge status only when available.
- Advanced project organization (tagging, grouping) - defer to Phase 5.
- Batch operations beyond delete (rename handled in Issue #22).

## Dependencies
- Depends On: Issue #23 (Navigation Architecture).
- Add runtime or tooling dependencies here.

## Touch Set
- Files to create: SidebarView.swift, ProjectRowView.swift, ProjectListView.swift
- Files to modify: Project.swift (add displayName, sessionCount, lastActivity computed properties), CLIBridgeManager.swift (add projectMetadataCache)

## Interface Definitions

### Modified Models

**Project** - Add computed properties
```swift
extension Project {
    var displayName: String {
        name.isEmpty ? path.components(separatedBy: "/").last ?? path : name
    }

    var sessionCount: Int {
        // Fetched from API and cached locally
        metadata.sessionCount ?? 0
    }

    var lastActivity: Date? {
        // From most recent session metadata
        metadata.lastModified
    }

    var cliBridgeStatus: StatusBadge? {
        // Fetched from cli-bridge, optional
        metadata.status
    }
}
```

### New/Modified Managers

**ProjectMetadataCache** - Lightweight cache for project metadata
```swift
@MainActor
class ProjectMetadataCache {
    private var cache: [String: ProjectMetadata] = [:]
    private var lastRefresh: Date?

    func get(forPath path: String) -> ProjectMetadata? {
        cache[path]
    }

    func set(_ metadata: ProjectMetadata, forPath path: String) {
        cache[path] = metadata
        lastRefresh = Date()
    }

    func shouldRefresh() -> Bool {
        guard let lastRefresh else { return true }
        return Date().timeIntervalSince(lastRefresh) > 300 // 5 min
    }
}

struct ProjectMetadata: Codable {
    let sessionCount: Int?
    let lastModified: Date?
    let status: StatusBadge?
}
```

## Edge Cases

- **Swipe-delete selected project**: If user deletes the currently selected project, navigation resets (`selectedProject = nil`) and app shows EmptyProjectView (per Issue #23 decision).
- **Empty project list**: Show a "No projects" state with Create/Clone options in the sidebar.
- **Search with no results**: Show inline message "No projects match your search"; clear button to reset search.
- **Metadata fetch fails**: Use cached metadata if available; show "unknown" or omit session count/last activity until next successful refresh.
- **Project added externally**: Next time SidebarView refreshes (pull-to-refresh or periodic update), new project appears automatically.
- **Very long project names**: Truncate with ellipsis; full name available in context menu or project detail view.
- **Cache invalidation**: When user returns to SidebarView after other tabs/sheets, check if cache is stale (>5 min) and refresh if needed.

## Tests
- [ ] Unit tests updated or added.
- [ ] UI tests updated or added (if user flows change).
## iOS 26.2 Features Used

| Feature | Usage |
|---------|-------|
| `.listSectionMargins()` | Control section spacing |
| `HapticManager` | Haptics on selection, delete |
| `.symbolEffect(.wiggle)` | Unread session indicator |
| `.navigationLinkIndicatorVisibility()` | Hide chevrons (safe in 26.2) |
| `.adaptiveGlass()` | Respect user intensity |

## Design

```
┌─────────────────────┐
│      Projects       │  ← Header with search
├─────────────────────┤
│ 🔍 Search...        │  ← Searchable filter
├─────────────────────┤
│ □ my-project        │
│   5 sessions • 2h   │
│ ■ cli-bridge ◀──────│  ← Selected (highlighted)
│   12 sessions • 1d  │
│ □ other-project     │
│   2 sessions • 5d   │
├─────────────────────┤
│ ─────────────────── │  ← Divider
│ ⚙️ Settings          │  ← Utility actions
│ 🖥️ Terminal          │
│ 🔍 Global Search     │
├─────────────────────┤
│ [+] New Project     │  ← Primary action
└─────────────────────┘
```

## Implementation

### SidebarView

```swift
struct SidebarView: View {
    @Binding var selection: Project?
    let onShowSheet: (ActiveSheet) -> Void

    @State private var searchText = ""
    @State private var projects: [Project] = []
    @State private var isLoading = false

    @Environment(CLIBridgeManager.self) var bridgeManager

    var filteredProjects: [Project] {
        if searchText.isEmpty {
            return projects
        }
        return projects.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach(filteredProjects) { project in
                    ProjectRowView(project: project)
                        .tag(project)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteProject(project)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            } header: {
                Text("Projects")
            }

            Section {
                Button {
                    onShowSheet(.settings)
                } label: {
                    Label("Settings", systemImage: "gear")
                }

                NavigationLink(value: NavigationDestination.terminal) {
                    Label("Terminal", systemImage: "terminal")
                }

                NavigationLink(value: NavigationDestination.globalSearch) {
                    Label("Global Search", systemImage: "magnifyingglass")
                }
            } header: {
                Text("Utilities")
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search projects")
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        onShowSheet(.newProject)
                    } label: {
                        Label("New Project", systemImage: "folder.badge.plus")
                    }

                    Button {
                        onShowSheet(.cloneProject)
                    } label: {
                        Label("Clone from GitHub", systemImage: "arrow.down.circle")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .refreshable {
            await loadProjects()
        }
        .task {
            await loadProjects()
        }
    }

    private func loadProjects() async {
        isLoading = true
        defer { isLoading = false }

        do {
            projects = try await bridgeManager.fetchProjects()
        } catch {
            Logger.error("Failed to load projects: \(error)")
        }
    }

    private func deleteProject(_ project: Project) {
        // Confirm and delete
    }
}
```

### ProjectRowView

```swift
struct ProjectRowView: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(project.displayName)
                .font(.headline)

            HStack(spacing: 8) {
                Label("\(project.sessionCount)", systemImage: "bubble.left.and.bubble.right")

                if let status = project.cliBridgeStatus {
                    Text("•")
                    StatusBadge(status.badge)
                        .lineLimit(1)
                }

                if let lastActivity = project.lastActivity {
                    Text("•")
                    Text(lastActivity, style: .relative)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
```

### Project Extension

```swift
extension Project {
    var displayName: String {
        name.isEmpty ? path.components(separatedBy: "/").last ?? path : name
    }

    var sessionCount: Int {
        // Fetched from API or cached
        0
    }

    var lastActivity: Date? {
        // From most recent session
        nil
    }
}
```

## Sidebar Styling

```swift
extension View {
    func sidebarStyle() -> some View {
        self
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
```

## Project Context Menu

```swift
.contextMenu {
    Button {
        onShowSheet(.sessionPicker(project))
    } label: {
        Label("Sessions", systemImage: "clock.arrow.circlepath")
    }

    NavigationLink(value: NavigationDestination.projectDetail(project)) {
        Label("Project Info", systemImage: "info.circle")
    }

    Divider()

    Button(role: .destructive) {
        deleteProject(project)
    } label: {
        Label("Delete", systemImage: "trash")
    }
}
```

## Files to Create

```
CodingBridge/Navigation/
└── SidebarView.swift              # ~150 lines

CodingBridge/Features/Projects/
├── ProjectListView.swift          # ~80 lines (reusable list component)
├── ProjectRowView.swift           # ~40 lines
└── ProjectDetailView.swift        # ~100 lines
```

## Files to Modify

| File | Changes |
|------|---------|
| `ContentView.swift` | Extract project list logic to SidebarView |
| `Project.swift` | Add displayName, sessionCount computed properties |

## Acceptance Criteria

- [ ] SidebarView displays project list
- [ ] Projects are searchable
- [ ] Selection binding works correctly
- [ ] Swipe-to-delete on projects with haptic feedback
- [ ] Context menu with options
- [ ] Utility section with settings, terminal, search
- [ ] New project menu with options
- [ ] Pull-to-refresh loads projects
- [ ] listSectionMargins for proper spacing
- [ ] Uses HapticManager for interactions
- [ ] Build passes on iOS 26.2+ (Xcode 26.2)

## Testing

```swift
struct SidebarTests: XCTestCase {
    func testProjectFiltering() {
        let projects = [
            Project.mock(name: "alpha"),
            Project.mock(name: "beta"),
            Project.mock(name: "gamma")
        ]

        let filtered = projects.filter { $0.name.contains("alp") }

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.name, "alpha")
    }
}
```
