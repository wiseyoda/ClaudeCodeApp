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
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- Depends On: Issue #23 (Navigation Architecture).
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
