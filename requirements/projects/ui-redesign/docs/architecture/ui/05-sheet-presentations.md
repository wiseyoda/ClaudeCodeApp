# Sheet Presentations


Sheets are presented modally from the root navigation:

```swift
struct MainNavigationView: View {
    @State private var activeSheet: ActiveSheet?

    enum ActiveSheet: Identifiable {
        case settings
        case quickSettings
        case sessionPicker(Project)
        case filePicker(Project)
        case commandPicker
        case newProject
        case cloneProject
        case help
        case keyboardShortcuts
        case ideasDrawer(Project)
        case ideaEditor(Idea)
        case projectSettings(Project)

        var id: String { /* unique id */ }
    }

    var body: some View {
        NavigationSplitView { /* ... */ }
        .sheet(item: $activeSheet) { sheet in
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
}
```

### Sheet Sizes

| Sheet | Detents | iPad Presentation |
|-------|---------|-------------------|
| Settings | `.large` | Form sheet |
| Session Picker | `.medium`, `.large` | Popover from toolbar |
| File Picker | `.large` | Form sheet |
| Command Picker | `.medium` | Popover |
| New/Clone Project | `.medium` | Form sheet |
| Help | `.medium`, `.large` | Form sheet |
| Quick Settings | `.medium` | Popover from status bar |
| Ideas Drawer | `.medium`, `.large` | Form sheet |
| Idea Editor | `.medium` | Form sheet |
| Project Settings | `.large` | Form sheet |

---
