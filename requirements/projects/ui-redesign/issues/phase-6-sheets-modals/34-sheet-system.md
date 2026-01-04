# Issue 34: Sheet System Architecture

**Phase:** 6 (Sheets & Modals)
**Priority:** High
**Status:** Not Started
**Depends On:** Issue #17 (Liquid Glass), Issue #23 (Navigation)

## Goal

Create a unified sheet presentation system with consistent Liquid Glass styling, detent configurations, and interaction patterns.

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
## Design Principles

1. **Consistent Presentation**: All sheets use glass background
2. **Smart Detents**: Content-appropriate detent configurations
3. **Drag Indicator**: Always visible for discoverability
4. **Keyboard Avoidance**: Proper handling for input sheets

## Sheet Types

| Sheet | Detents | Keyboard | Background |
|-------|---------|----------|------------|
| Settings | Large only | No | Glass |
| Quick Settings | Medium | No | Glass |
| Session Picker | Medium, Large | No | Glass |
| Command Picker | Medium | No | Glass |
| File Picker | Large | Yes (search) | Glass |
| New Project | Medium | Yes | Glass |
| Clone Project | Medium | Yes | Glass |
| Help | Medium, Large | No | Glass |
| Ideas Drawer | Medium, Large | Yes | Glass |

## Implementation

### SheetModifier

```swift
struct SheetConfiguration {
    let detents: Set<PresentationDetent>
    let dragIndicatorVisibility: Visibility
    let interactiveDismissDisabled: Bool
    let backgroundStyle: SheetBackgroundStyle

    static let settings = SheetConfiguration(
        detents: [.large],
        dragIndicatorVisibility: .visible,
        interactiveDismissDisabled: false,
        backgroundStyle: .glass
    )

    static let quickSettings = SheetConfiguration(
        detents: [.medium],
        dragIndicatorVisibility: .visible,
        interactiveDismissDisabled: false,
        backgroundStyle: .glass
    )

    static let sessionPicker = SheetConfiguration(
        detents: [.medium, .large],
        dragIndicatorVisibility: .visible,
        interactiveDismissDisabled: false,
        backgroundStyle: .glass
    )

    static let commandPicker = SheetConfiguration(
        detents: [.medium],
        dragIndicatorVisibility: .visible,
        interactiveDismissDisabled: false,
        backgroundStyle: .glass
    )

    static let filePicker = SheetConfiguration(
        detents: [.large],
        dragIndicatorVisibility: .visible,
        interactiveDismissDisabled: false,
        backgroundStyle: .glass
    )

    static let newProject = SheetConfiguration(
        detents: [.medium],
        dragIndicatorVisibility: .visible,
        interactiveDismissDisabled: true,
        backgroundStyle: .glass
    )

    static let help = SheetConfiguration(
        detents: [.medium, .large],
        dragIndicatorVisibility: .visible,
        interactiveDismissDisabled: false,
        backgroundStyle: .glass
    )
}

enum SheetBackgroundStyle {
    case glass
    case solid(Color)
    case ultraThinMaterial

    @ViewBuilder
    func apply() -> some ShapeStyle {
        switch self {
        case .glass:
            .glass
        case .solid(let color):
            color
        case .ultraThinMaterial:
            .ultraThinMaterial
        }
    }
}

extension View {
    func sheetConfiguration(_ config: SheetConfiguration) -> some View {
        self
            .presentationDetents(config.detents)
            .presentationDragIndicator(config.dragIndicatorVisibility)
            .interactiveDismissDisabled(config.interactiveDismissDisabled)
            .presentationBackground(.glass)
    }
}
```

### ActiveSheet Enum

```swift
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

    var id: String {
        switch self {
        case .settings: return "settings"
        case .quickSettings: return "quickSettings"
        case .sessionPicker(let p): return "session-\(p.path)"
        case .filePicker(let p): return "file-\(p.path)"
        case .commandPicker: return "commands"
        case .newProject: return "newProject"
        case .cloneProject: return "cloneProject"
        case .help: return "help"
        case .keyboardShortcuts: return "shortcuts"
        case .ideasDrawer(let p): return "ideas-\(p.path)"
        case .ideaEditor(let i): return "ideaEdit-\(i.id)"
        case .projectSettings(let p): return "projectSettings-\(p.path)"
        }
    }

    var configuration: SheetConfiguration {
        switch self {
        case .settings:
            return .settings
        case .quickSettings:
            return .quickSettings
        case .sessionPicker:
            return .sessionPicker
        case .filePicker:
            return .filePicker
        case .commandPicker:
            return .commandPicker
        case .newProject, .cloneProject:
            return .newProject
        case .help, .keyboardShortcuts:
            return .help
        case .ideasDrawer:
            return .sessionPicker
        case .ideaEditor:
            return .quickSettings
        case .projectSettings:
            return .settings
        }
    }
}
```

### SheetPresenter

```swift
struct SheetPresenter: ViewModifier {
    @Binding var activeSheet: ActiveSheet?

    func body(content: Content) -> some View {
        content
            .sheet(item: $activeSheet) { sheet in
                sheetContent(for: sheet)
                    .sheetConfiguration(sheet.configuration)
            }
    }

    @ViewBuilder
    private func sheetContent(for sheet: ActiveSheet) -> some View {
        switch sheet {
        case .settings:
            SettingsSheet()

        case .quickSettings:
            QuickSettingsSheet()

        case .sessionPicker(let project):
            SessionPickerSheet(project: project) { session in
                // Handle selection
            }

        case .filePicker(let project):
            FilePickerSheet(project: project) { path in
                // Handle selection
            }

        case .commandPicker:
            CommandPickerSheet { command in
                // Handle selection
            }

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

extension View {
    func sheetPresenter(_ activeSheet: Binding<ActiveSheet?>) -> some View {
        modifier(SheetPresenter(activeSheet: activeSheet))
    }
}
```

### Sheet Header Pattern

```swift
struct SheetHeader: View {
    let title: String
    let subtitle: String?
    let onDismiss: () -> Void

    init(title: String, subtitle: String? = nil, onDismiss: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.onDismiss = onDismiss
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
```

### Confirmation Sheet Pattern

```swift
struct ConfirmationSheet<Content: View>: View {
    let title: String
    let message: String
    let confirmTitle: String
    let confirmRole: ButtonRole?
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @ViewBuilder let content: () -> Content

    @Environment(\.dismiss) var dismiss

    init(
        title: String,
        message: String,
        confirmTitle: String = "Confirm",
        confirmRole: ButtonRole? = nil,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void = {},
        @ViewBuilder content: @escaping () -> Content = { EmptyView() }
    ) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.confirmRole = confirmRole
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        self.content = content
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            content()

            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                    dismiss()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button(confirmTitle, role: confirmRole) {
                    onConfirm()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .presentationDetents([.height(250)])
        .presentationBackground(.glass)
    }
}
```

## Usage Example

```swift
struct ChatView: View {
    @State private var activeSheet: ActiveSheet?

    var body: some View {
        VStack {
            // Content
        }
        .toolbar {
            ToolbarItem {
                Button {
                    activeSheet = .quickSettings
                } label: {
                    Image(systemName: "gear")
                }
            }
        }
        .sheetPresenter($activeSheet)
    }
}
```

## Files to Create

```
CodingBridge/UI/Sheets/
├── SheetConfiguration.swift       # ~80 lines
├── ActiveSheet.swift              # ~60 lines
├── SheetPresenter.swift           # ~80 lines
├── SheetHeader.swift              # ~40 lines
└── ConfirmationSheet.swift        # ~60 lines
```

## Files to Modify

| File | Changes |
|------|---------|
| All sheet files | Add `.sheetConfiguration()` modifier |
| `MainNavigationView.swift` | Use `.sheetPresenter()` |

## Acceptance Criteria

- [ ] Unified SheetConfiguration for all sheets
- [ ] ActiveSheet enum covers all sheets
- [ ] SheetPresenter modifier works correctly
- [ ] All sheets use glass background
- [ ] Detents match sheet type
- [ ] Drag indicator visible on all sheets
- [ ] Keyboard avoidance works for input sheets
- [ ] Build passes

## Testing

```swift
struct SheetSystemTests: XCTestCase {
    func testSheetIds() {
        let project = Project.mock()

        let settings = ActiveSheet.settings
        let session = ActiveSheet.sessionPicker(project)

        XCTAssertEqual(settings.id, "settings")
        XCTAssertTrue(session.id.starts(with: "session-"))
    }

    func testSheetConfigurations() {
        XCTAssertTrue(SheetConfiguration.settings.detents.contains(.large))
        XCTAssertTrue(SheetConfiguration.quickSettings.detents.contains(.medium))
        XCTAssertTrue(SheetConfiguration.sessionPicker.detents.contains(.medium))
        XCTAssertTrue(SheetConfiguration.sessionPicker.detents.contains(.large))
    }
}
```
