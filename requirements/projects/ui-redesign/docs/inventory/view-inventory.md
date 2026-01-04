# View Inventory

## Main Views

| Current File | Lines | Redesign Issue |
|--------------|-------|----------------|
| `ContentView.swift` | ~400 | #23, #24 |
| `ChatView.swift` | ~800 | #26 |
| `TerminalView.swift` | ~300 | #30 |
| `GlobalSearchView.swift` | ~700 | #33 |

## Message Views (Replace CLIMessageView.swift ~1000 lines)

| New File | Purpose | Issue |
|----------|---------|-------|
| `MessageCardRouter.swift` | Route to card type | #03 |
| `ChatCardView.swift` | User/assistant | #04 |
| `ToolCardView.swift` | Tool use/result | #05 |
| `SystemCardView.swift` | Error/system/thinking | #06 |

## Settings Views

| Current File | Lines | Redesign Issue |
|--------------|-------|----------------|
| `QuickSettingsSheet.swift` | ~430 | #28 |
| Settings in `ContentView` | ~200 | #27 |
| `PermissionSettingsView.swift` | ~320 | #27 |

## Sheets (Target: Unified System)

| Current Sheet | Lines | Redesign Issue |
|---------------|-------|----------------|
| `SessionPickerViews.swift` | ~760 | #32 |
| `FilePickerSheet.swift` | ~320 | #31 |
| `FileBrowserView.swift` | ~400 | #31 |
| `CommandsView.swift` | ~450 | #35 |
| `CommandPickerSheet.swift` | ~170 | #35 |
| `IdeasDrawerSheet.swift` | ~400 | #36 |
| `CloneProjectSheet.swift` | ~270 | #34 |
| `NewProjectSheet.swift` | ~250 | #34 |
| `SlashCommandHelpSheet.swift` | ~50 | #37 |

## Component Views

| Current File | Lines | Redesign Issue |
|--------------|-------|----------------|
| `CLIInputView.swift` | ~400 | #26 |
| `CLIStatusBarViews.swift` | ~370 | #26 |
| `ApprovalBannerView.swift` | ~300 | #08 |
| `DiffView.swift` | ~410 | #05 |
| `MarkdownText.swift` | ~510 | #02 |
| `CodeBlockView.swift` | ~210 | #02 |
| `TodoListView.swift` | ~170 | #05 |
