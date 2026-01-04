# Issue 29: Project Settings View

**Phase:** 4 (Settings & Configuration)
**Priority:** Medium
**Status:** Not Started
**Depends On:** Issue #17 (Liquid Glass), Issue #23 (Navigation)

## Goal

Create a per-project settings view accessible via push navigation, with project-specific overrides and information.

## Decisions

- Support custom project display names via `ProjectNamesStore`.
- Keep archive flow using `ArchivedProjectsStore`.

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- Depends On: Issue #17 (Liquid Glass), Issue #23 (Navigation).
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
┌─────────────────────────────────────────────┐
│ ←  my-project Settings                      │
├─────────────────────────────────────────────┤
│ PROJECT INFO                                │
│ ┌─────────────────────────────────────────┐ │
│ │ 📁 Path                                 │ │
│ │    /home/dev/workspace/my-project       │ │
│ ├─────────────────────────────────────────┤ │
│ │ ✏️ Display Name                          │ │
│ │    My Project                        ▶  │ │
│ ├─────────────────────────────────────────┤ │
│ │ 💬 Sessions                             │ │
│ │    12 total • 3 archived                │ │
│ ├─────────────────────────────────────────┤ │
│ │ 📅 Last Activity                        │ │
│ │    2 hours ago                          │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ OVERRIDES                                   │
│ ┌─────────────────────────────────────────┐ │
│ │ 🤖 Model Override                       │ │
│ │    Use Default                      ▶  │ │
│ ├─────────────────────────────────────────┤ │
│ │ 🔓 Permission Mode                      │ │
│ │    Use Default                      ▶  │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ ACTIONS                                     │
│ ┌─────────────────────────────────────────┐ │
│ │ 🗑️ Clear All Sessions                   │ │
│ ├─────────────────────────────────────────┤ │
│ │ 📤 Export Project                       │ │
│ ├─────────────────────────────────────────┤ │
│ │ 🗂️ Archive Project                      │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ DANGER ZONE                                 │
│ ┌─────────────────────────────────────────┐ │
│ │ ⚠️ Remove from App                      │ │
│ └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

## Implementation

### ProjectSettingsView

```swift
struct ProjectSettingsView: View {
    let project: Project
    @State private var settings: ProjectSettings
    @State private var displayName: String
    @State private var showDeleteConfirmation = false
    @State private var showClearSessionsConfirmation = false

    @Environment(\.dismiss) var dismiss
    @Environment(CLIBridgeManager.self) var bridgeManager

    init(project: Project) {
        self.project = project
        self._settings = State(initialValue: ProjectSettingsStore.shared.settings(for: project.path))
        self._displayName = State(initialValue: ProjectNamesStore.shared.name(for: project.path) ?? project.displayName)
    }

    var body: some View {
        Form {
            ProjectInfoSection(project: project, displayName: $displayName)
            OverridesSection(settings: $settings)
            ActionsSection(
                project: project,
                onClearSessions: { showClearSessionsConfirmation = true },
                onExport: exportProject,
                onArchive: archiveProject
            )
            DangerZoneSection(onRemove: { showDeleteConfirmation = true })
        }
        .navigationTitle("\(project.displayName) Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: settings) { _, newSettings in
            ProjectSettingsStore.shared.save(newSettings, for: project.path)
        }
        .onChange(of: displayName) { _, newValue in
            ProjectNamesStore.shared.setName(newValue, for: project.path)
        }
        .confirmationDialog("Clear All Sessions?", isPresented: $showClearSessionsConfirmation) {
            Button("Clear Sessions", role: .destructive) {
                Task { await clearSessions() }
            }
        } message: {
            Text("This will delete all \(project.sessionCount) sessions. This cannot be undone.")
        }
        .confirmationDialog("Remove Project?", isPresented: $showDeleteConfirmation) {
            Button("Remove from App", role: .destructive) {
                removeProject()
            }
        } message: {
            Text("This removes the project from the app but doesn't delete files on disk.")
        }
    }

    private func exportProject() {
        // Generate export and show share sheet
    }

    private func archiveProject() {
        // Archive all sessions
    }

    private func clearSessions() async {
        // Clear all sessions via API
    }

    private func removeProject() {
        // Remove from app
        dismiss()
    }
}
```

### ProjectInfoSection

```swift
struct ProjectInfoSection: View {
    let project: Project
    @Binding var displayName: String

    var body: some View {
        Section {
            LabeledContent {
                TextField("Display Name", text: $displayName)
            } label: {
                Label("Display Name", systemImage: "pencil")
            }

            LabeledContent {
                Text(project.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } label: {
                Label("Path", systemImage: "folder")
            }

            LabeledContent {
                Text("\(project.sessionCount) total")
            } label: {
                Label("Sessions", systemImage: "bubble.left.and.bubble.right")
            }

            if let lastActivity = project.lastActivity {
                LabeledContent {
                    Text(lastActivity, style: .relative)
                } label: {
                    Label("Last Activity", systemImage: "calendar")
                }
            }
        } header: {
            Text("Project Info")
        }
    }
}
```

### OverridesSection

```swift
struct OverridesSection: View {
    @Binding var settings: ProjectSettings

    var body: some View {
        Section {
            Picker(selection: $settings.modelOverride) {
                Text("Use Default").tag(ClaudeModel?.none)
                Divider()
                ForEach(ClaudeModel.allCases, id: \.self) { model in
                    Text(model.displayName).tag(Optional(model))
                }
            } label: {
                Label("Model Override", systemImage: "cpu")
            }

            Picker(selection: $settings.permissionModeOverride) {
                Text("Use Default").tag(PermissionMode?.none)
                Divider()
                Text("Ask Every Time").tag(Optional(PermissionMode.ask))
                Text("Auto-approve").tag(Optional(PermissionMode.auto))
            } label: {
                Label("Permission Mode", systemImage: "lock")
            }

            Toggle(isOn: $settings.showInRecents) {
                Label("Show in Recents", systemImage: "clock")
            }
        } header: {
            Text("Overrides")
        } footer: {
            Text("Project-specific settings override app defaults")
        }
    }
}
```

### ActionsSection

```swift
struct ActionsSection: View {
    let project: Project
    let onClearSessions: () -> Void
    let onExport: () -> Void
    let onArchive: () -> Void

    var body: some View {
        Section {
            Button(action: onClearSessions) {
                Label("Clear All Sessions", systemImage: "trash")
            }
            .foregroundStyle(.primary)

            Button(action: onExport) {
                Label("Export Project", systemImage: "square.and.arrow.up")
            }
            .foregroundStyle(.primary)

            Button(action: onArchive) {
                Label("Archive Project", systemImage: "archivebox")
            }
            .foregroundStyle(.primary)
        } header: {
            Text("Actions")
        }
    }
}
```

### DangerZoneSection

```swift
struct DangerZoneSection: View {
    let onRemove: () -> Void

    var body: some View {
        Section {
            Button(role: .destructive, action: onRemove) {
                Label("Remove from App", systemImage: "xmark.circle")
            }
        } header: {
            Text("Danger Zone")
        } footer: {
            Text("Removes this project from the app. Files on disk are not affected.")
        }
    }
}
```

### ProjectSettings Model

```swift
struct ProjectSettings: Codable, Equatable {
    var modelOverride: ClaudeModel?
    var permissionModeOverride: PermissionMode?
    var showInRecents: Bool = true

    static let `default` = ProjectSettings()
}

@MainActor @Observable
final class ProjectSettingsStore {
    static let shared = ProjectSettingsStore()

    private var settingsCache: [String: ProjectSettings] = [:]
    private let defaults = UserDefaults.standard

    func settings(for projectPath: String) -> ProjectSettings {
        if let cached = settingsCache[projectPath] {
            return cached
        }

        let key = "project-settings-\(projectPath.projectPathEncoded)"
        if let data = defaults.data(forKey: key),
           let settings = try? JSONDecoder().decode(ProjectSettings.self, from: data) {
            settingsCache[projectPath] = settings
            return settings
        }

        return .default
    }

    func save(_ settings: ProjectSettings, for projectPath: String) {
        settingsCache[projectPath] = settings

        let key = "project-settings-\(projectPath.projectPathEncoded)"
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: key)
        }
    }
}
```

## Files to Create

```
CodingBridge/Features/Projects/
├── ProjectSettingsView.swift      # ~150 lines
└── ProjectSettings.swift          # ~60 lines
```

## Files to Modify

| File | Changes |
|------|---------|
| `NavigationDestination.swift` | Add `.projectSettings(Project)` case |
| `MainNavigationView.swift` | Handle navigation destination |

## Security Checklist

- [ ] Project paths are escaped before SSH/file operations
- [ ] Per-project secrets stored in Keychain (if any)
- [ ] Export paths validated and user-confirmed
- [ ] Settings persistence uses versioned schema

## Acceptance Criteria

- [ ] Push navigation from project context menu
- [ ] Project info displays correctly
- [ ] Model and permission overrides work
- [ ] Clear sessions with confirmation
- [ ] Export generates shareable content
- [ ] Remove from app works
- [ ] Settings persist across launches
- [ ] Security checklist complete
- [ ] Build passes

## Testing

```swift
struct ProjectSettingsTests: XCTestCase {
    func testSettingsPersistence() {
        let store = ProjectSettingsStore.shared
        var settings = ProjectSettings()
        settings.modelOverride = .opus

        store.save(settings, for: "/test/path")

        let loaded = store.settings(for: "/test/path")
        XCTAssertEqual(loaded.modelOverride, .opus)
    }

    func testDefaultSettings() {
        let settings = ProjectSettings.default
        XCTAssertNil(settings.modelOverride)
        XCTAssertNil(settings.permissionModeOverride)
        XCTAssertTrue(settings.showInRecents)
    }
}
```
