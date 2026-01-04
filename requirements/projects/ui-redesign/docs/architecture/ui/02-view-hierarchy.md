# View Hierarchy

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        CodingBridgeApp                                   │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                    NavigationSplitView                             │  │
│  │  ┌─────────────┐  ┌─────────────────────────────────────────────┐ │  │
│  │  │   Sidebar   │  │                  Detail                      │ │  │
│  │  │             │  │  ┌─────────────────────────────────────────┐ │ │  │
│  │  │  Projects   │  │  │              ChatView                   │ │ │  │
│  │  │  ─────────  │  │  │  ┌───────────────────────────────────┐ │ │ │  │
│  │  │  □ proj-1   │──│──│  │        MessageListView            │ │ │ │  │
│  │  │  □ proj-2   │  │  │  │  ┌─────────────────────────────┐ │ │ │ │  │
│  │  │  □ proj-3   │  │  │  │  │     MessageCardRouter       │ │ │ │ │  │
│  │  │             │  │  │  │  │  ChatCard | ToolCard | etc  │ │ │ │ │  │
│  │  │  ─────────  │  │  │  │  └─────────────────────────────┘ │ │ │ │  │
│  │  │  [+] New    │  │  │  └───────────────────────────────────┘ │ │ │  │
│  │  │             │  │  │  ┌───────────────────────────────────┐ │ │ │  │
│  │  │  ─────────  │  │  │  │           InputView               │ │ │ │  │
│  │  │  Settings    │  │  │  └───────────────────────────────────┘ │ │ │  │
│  │  │  Terminal    │  │  └─────────────────────────────────────────┘ │  │
│  │  └─────────────┘  └─────────────────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  Sheets (presented modally):                                             │
│  • SessionPickerSheet    • FilePickerSheet    • CommandPickerSheet      │
│  • SettingsSheet         • NewProjectSheet    • CloneProjectSheet       │
│  • HelpSheet             • ExportSheet        • KeyboardShortcutsSheet  │
└─────────────────────────────────────────────────────────────────────────┘
```

## Detailed Tree


```
CodingBridgeApp
└── MainNavigationView (NavigationSplitView)
    ├── SidebarView (sidebar column)
    │   ├── ProjectListView
    │   │   └── ForEach projects
    │   │       └── ProjectRowView
    │   ├── Divider
    │   ├── UtilitySection
    │   │   ├── SettingsButton → SettingsSheet
    │   │   └── TerminalButton → TerminalView (push)
    │   └── NewProjectButton → NewProjectSheet / CloneProjectSheet
    │
    └── DetailContainerView (detail column)
        └── NavigationStack
            ├── ChatView (default for selected project)
            │   ├── StatusBarView
            │   ├── MessageListView
            │   │   └── MessageCardRouter
            │   │       ├── ChatCardView
            │   │       ├── ToolCardView
            │   │       └── SystemCardView
            │   ├── InteractionContainerView (overlay)
            │   └── InputView
            │
            ├── ProjectDetailView (push destination)
            ├── TerminalView (push destination)
            └── GlobalSearchView (push destination)
```

---
