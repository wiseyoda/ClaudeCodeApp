# Issue 23: Navigation Architecture

**Phase:** 1 (Navigation & Layout)
**Priority:** High
**Status:** Not Started
**Depends On:** Issue #10 (@Observable Migration)

## Goal

Implement adaptive navigation: TabView on iPhone (compact width) and NavigationSplitView on iPad, replacing the current mixed navigation pattern.

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- Depends On: Issue #10 (@Observable Migration).
- Add runtime or tooling dependencies here.

## Touch Set
- Files to create: TBD.
- Files to modify: TBD.

## Interface Definitions
- List new or changed models, protocols, and API payloads.

## Tests
- [ ] Unit tests updated or added.
- [ ] UI tests updated or added (if user flows change).
## Current State

- `ContentView.swift` uses `NavigationStack` with sheet-based navigation
- No consistent sidebar/detail pattern
- iPad support is limited

## Target Architecture

```swift
if sizeClass == .compact {
    TabView(selection: $selectedTab) {
        ProjectsHomeView(onShowSheet: { activeSheet = $0 })
            .tabItem { Label("Projects", systemImage: "square.grid.2x2") }
            .tag(Tab.projects)

        TerminalView()
            .tabItem { Label("Terminal", systemImage: "terminal") }
            .tag(Tab.terminal)

        CommandsHomeView(onSelect: { activeSheet = .commandPicker })
            .tabItem { Label("Commands", systemImage: "bolt.fill") }
            .tag(Tab.commands)

        SettingsHomeView(onShowSheet: { activeSheet = .settings })
            .tabItem { Label("Settings", systemImage: "gear") }
            .tag(Tab.settings)
    }
} else {
    NavigationSplitView(columnVisibility: $columnVisibility) {
        SidebarView(selection: $selectedProject)
    } detail: {
        NavigationStack(path: $navigationPath) {
            DetailContainerView(project: selectedProject)
        }
    }
}
```

## Implementation

### AppState

```swift
@MainActor @Observable
final class AppState {
    // Navigation
    var selectedProject: Project?
    var navigationPath = NavigationPath()
    var columnVisibility: NavigationSplitViewVisibility = .automatic
    var selectedTab: Tab = .projects

    // Sheets
    var activeSheet: ActiveSheet?

    // Global state
    var isConnected = false

    enum Tab: Hashable {
        case projects
        case terminal
        case commands
        case settings
    }
}
```

ActiveSheet is shared across the app; see Issue 34 (Sheet System) for the enum and configuration.

### MainNavigationView

```swift
struct MainNavigationView: View {
    @Bindable var appState: AppState
    @Environment(\.horizontalSizeClass) var sizeClass

    var body: some View {
        Group {
            if sizeClass == .compact {
                TabView(selection: $appState.selectedTab) {
                    ProjectsHomeView(onShowSheet: { appState.activeSheet = $0 })
                        .tabItem { Label("Projects", systemImage: "square.grid.2x2") }
                        .tag(AppState.Tab.projects)

                    TerminalView()
                        .tabItem { Label("Terminal", systemImage: "terminal") }
                        .tag(AppState.Tab.terminal)

                    CommandsHomeView(onSelect: { appState.activeSheet = .commandPicker })
                        .tabItem { Label("Commands", systemImage: "bolt.fill") }
                        .tag(AppState.Tab.commands)

                    SettingsHomeView(onShowSheet: { appState.activeSheet = .settings })
                        .tabItem { Label("Settings", systemImage: "gear") }
                        .tag(AppState.Tab.settings)
                }
            } else {
                NavigationSplitView(columnVisibility: $appState.columnVisibility) {
                    SidebarView(
                        selection: $appState.selectedProject,
                        onShowSheet: { appState.activeSheet = $0 }
                    )
                    .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
                } detail: {
                    NavigationStack(path: $appState.navigationPath) {
                        DetailContainerView(
                            project: appState.selectedProject,
                            onShowSheet: { appState.activeSheet = $0 }
                        )
                        .navigationDestination(for: NavigationDestination.self) { destination in
                            destinationView(for: destination)
                        }
                    }
                }
                .navigationSplitViewStyle(.balanced)
            }
        }
        .sheet(item: $appState.activeSheet) { sheet in
            sheetView(for: sheet)
                .sheetConfiguration(sheet.configuration)
        }
    }

    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .projectDetail(let project):
            ProjectDetailView(project: project)
        case .terminal:
            TerminalView()
        case .globalSearch:
            GlobalSearchView()
        case .sessionHistory(let session):
            SessionHistoryView(session: session)
        }
    }

    @ViewBuilder
    private func sheetView(for sheet: ActiveSheet) -> some View {
        switch sheet {
        case .settings:
            SettingsSheet()
        case .quickSettings:
            QuickSettingsSheet()
        case .sessionPicker(let project):
            SessionPickerSheet(project: project)
        case .filePicker(let project):
            FilePickerSheet(project: project)
        case .commandPicker:
            CommandPickerSheet()
        case .newProject:
            NewProjectSheet()
        case .cloneProject:
            CloneProjectSheet()
        case .help:
            HelpSheet()
        case .keyboardShortcuts:
            KeyboardShortcutsSheet()
        case .ideasDrawer(let project):
            IdeasDrawerSheet(project: project)
        case .ideaEditor(let idea):
            IdeaEditorSheet(idea: idea)
        case .projectSettings(let project):
            ProjectSettingsView(project: project)
        }
    }
}
```

### iPhone Tab Structure

- Projects tab uses a simplified project list with a prominent primary action for "New Project" (not a tab).
- Commands tab presents the command palette view; Chat input still offers inline command autocomplete.
- Settings tab launches the Settings sheet to preserve iPad parity.

### NavigationDestination

```swift
enum NavigationDestination: Hashable {
    case projectDetail(Project)
    case terminal
    case globalSearch
    case sessionHistory(Session)
}
```

### DetailContainerView

```swift
struct DetailContainerView: View {
    let project: Project?
    let onShowSheet: (ActiveSheet) -> Void

    var body: some View {
        Group {
            if let project {
                ChatView(
                    project: project,
                    onShowSheet: onShowSheet
                )
            } else {
                EmptyProjectView()
            }
        }
    }
}

struct EmptyProjectView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No Project Selected", systemImage: "folder")
        } description: {
            Text("Select a project from the sidebar to start chatting with Claude.")
        }
        .glassEffect()
    }
}
```

## Edge Cases

- Selected project deleted: reset selection and show EmptyProjectView.
- Session expires while on detail: show a banner and route to Session Picker.
- Deep link without project: show EmptyProjectView with helpful action.

## CodingBridgeApp Entry Point

```swift
@main
struct CodingBridgeApp: App {
    @State private var appState = AppState()
    @State private var bridgeManager = CLIBridgeManager()

    var body: some Scene {
        WindowGroup {
            MainNavigationView(appState: appState)
                .environment(bridgeManager)
        }
        .commands {
            CodingBridgeCommands(appState: appState)
        }
    }

    init() {
        CodingBridgeShortcuts.updateAppShortcutParameters()
    }
}
```

## Files to Create

```
CodingBridge/App/
├── AppState.swift                 # ~80 lines
└── NavigationDestination.swift    # ~20 lines

CodingBridge/Navigation/
├── MainNavigationView.swift       # ~120 lines
├── DetailContainerView.swift      # ~40 lines
└── EmptyProjectView.swift         # ~20 lines
```

## Files to Modify

| File | Changes |
|------|---------|
| `CodingBridgeApp.swift` | Replace ContentView with MainNavigationView |
| `ContentView.swift` | Refactor to SidebarView (Issue #24) |

## Acceptance Criteria

- [ ] NavigationSplitView as root navigation
- [ ] AppState @Observable with navigation state
- [ ] Sidebar shows on iPad, hidden on iPhone
- [ ] Column visibility persists across launches
- [ ] Sheet presentation works correctly
- [ ] Navigation destinations work
- [ ] Keyboard shortcuts for sidebar toggle
- [ ] Build passes

## Testing

```swift
struct NavigationArchitectureTests: XCTestCase {
    func testProjectSelection() {
        let appState = AppState()
        let project = Project.mock()

        appState.selectedProject = project

        XCTAssertEqual(appState.selectedProject?.id, project.id)
    }

    func testSheetPresentation() {
        let appState = AppState()

        appState.activeSheet = .settings

        XCTAssertEqual(appState.activeSheet?.id, "settings")
    }

    func testNavigationPath() {
        let appState = AppState()

        appState.navigationPath.append(NavigationDestination.terminal)

        XCTAssertEqual(appState.navigationPath.count, 1)
    }
}
```
