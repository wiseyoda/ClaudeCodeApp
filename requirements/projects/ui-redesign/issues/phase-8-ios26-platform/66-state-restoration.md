# Issue 66: State Restoration

**Phase:** 8 (iOS 26 Platform)
**Priority:** Medium
**Status:** Not Started
**Depends On:** 23 (Navigation Architecture), 43 (Handoff & Universal Links)
**Target:** iOS 26.2, Xcode 26.2, Swift 6.2.1

## Goal

Implement robust state restoration so users return to exactly where they left off, including navigation state, scroll positions, draft messages, and sheet presentations.

## Scope

- In scope:
  - Navigation stack restoration
  - Selected project/session persistence
  - Scroll position restoration
  - Draft message persistence
  - Sheet state restoration
  - NSUserActivity for Handoff
- Out of scope:
  - Cross-device state sync (Issue #56 covers iCloud)
  - Undo/redo state
  - Clipboard persistence

## Non-goals

- Perfect restoration across app updates
- State restoration for background agents

## Dependencies

- Issue #23 (Navigation Architecture) for navigation state
- Issue #43 (Handoff & Universal Links) for NSUserActivity

## Touch Set

- Files to create:
  - `CodingBridge/Core/StateRestoration/StateRestorationManager.swift`
  - `CodingBridge/Core/StateRestoration/NavigationState.swift`
  - `CodingBridge/Core/StateRestoration/SceneState.swift`
- Files to modify:
  - `CodingBridge/CodingBridgeApp.swift` (scene state)
  - `CodingBridge/Views/ContentView.swift` (navigation state)
  - `CodingBridge/Views/ChatView.swift` (scroll/draft state)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         App Launch                               │
│                              │                                   │
│                              ▼                                   │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │              StateRestorationManager                        ││
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐ ││
│  │  │NavigationState│ │  DraftState  │ │   ScrollState       │ ││
│  │  │              │ │              │ │                      │ ││
│  │  │- projectPath │ │- inputText   │ │- messageListOffset  │ ││
│  │  │- sessionId   │ │- attachments │ │- fileListOffset     │ ││
│  │  │- sheetType   │ │              │ │                      │ ││
│  │  └──────────────┘ └──────────────┘ └──────────────────────┘ ││
│  └─────────────────────────────────────────────────────────────┘│
│                              │                                   │
│                              ▼                                   │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │              Scene Storage / UserActivity                    ││
│  │  - @SceneStorage for quick access                           ││
│  │  - NSUserActivity for Handoff                               ││
│  │  - UserDefaults for cross-launch persistence                ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

---

## State Restoration Manager

### StateRestorationManager

```swift
import SwiftUI

/// Manages app state restoration across launches.
@MainActor @Observable
final class StateRestorationManager {
    static let shared = StateRestorationManager()

    // MARK: - Navigation State

    var selectedProjectPath: String? {
        didSet { persist() }
    }

    var selectedSessionId: String? {
        didSet { persist() }
    }

    var activeSheet: ActiveSheet? {
        didSet { persist() }
    }

    // MARK: - Draft State

    var draftInputsByProject: [String: DraftInput] = [:] {
        didSet { persistDrafts() }
    }

    // MARK: - Scroll State

    var scrollOffsetsByProject: [String: CGFloat] = [:]

    // MARK: - Initialization

    @ObservationIgnored
    private let defaults = UserDefaults.standard

    @ObservationIgnored
    private let stateKey = "appRestorationState"

    @ObservationIgnored
    private let draftsKey = "appDraftInputs"

    @ObservationIgnored
    private var pendingSheetState: ActiveSheetState?

    private init() {
        restore()
    }

    // MARK: - Persistence

    private func persist() {
        let state = RestorationState(
            selectedProjectPath: selectedProjectPath,
            selectedSessionId: selectedSessionId,
            activeSheet: ActiveSheetState(sheet: activeSheet)
        )

        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: stateKey)
        }
    }

    private func persistDrafts() {
        if let data = try? JSONEncoder().encode(draftInputsByProject) {
            defaults.set(data, forKey: draftsKey)
        }
    }

    private func restore() {
        // Restore navigation state
        if let data = defaults.data(forKey: stateKey),
           let state = try? JSONDecoder().decode(RestorationState.self, from: data) {
            selectedProjectPath = state.selectedProjectPath
            selectedSessionId = state.selectedSessionId
            pendingSheetState = state.activeSheet
        }

        // Restore drafts
        if let data = defaults.data(forKey: draftsKey),
           let drafts = try? JSONDecoder().decode([String: DraftInput].self, from: data) {
            draftInputsByProject = drafts
        }
    }

    // MARK: - Draft Management

    func saveDraft(for projectPath: String, text: String, attachments: [AttachmentData] = []) {
        guard !text.isEmpty || !attachments.isEmpty else {
            draftInputsByProject.removeValue(forKey: projectPath)
            return
        }

        draftInputsByProject[projectPath] = DraftInput(
            text: text,
            attachments: attachments,
            savedAt: Date()
        )
    }

    func loadDraft(for projectPath: String) -> DraftInput? {
        draftInputsByProject[projectPath]
    }

    func clearDraft(for projectPath: String) {
        draftInputsByProject.removeValue(forKey: projectPath)
    }

    // MARK: - Clear All

    func clearAllState() {
        selectedProjectPath = nil
        selectedSessionId = nil
        activeSheet = nil
        pendingSheetState = nil
        draftInputsByProject.removeAll()
        scrollOffsetsByProject.removeAll()

        defaults.removeObject(forKey: stateKey)
        defaults.removeObject(forKey: draftsKey)
    }

    // MARK: - Deferred Sheet Resolution

    func resolvePendingSheet(
        resolveProject: (String) -> Project?,
        resolveIdea: (String) -> Idea?
    ) {
        guard let pendingSheetState else { return }
        activeSheet = pendingSheetState.resolve(resolveProject: resolveProject, resolveIdea: resolveIdea)
        self.pendingSheetState = nil
    }
}

// MARK: - Supporting Types

struct RestorationState: Codable {
    let selectedProjectPath: String?
    let selectedSessionId: String?
    let activeSheet: ActiveSheetState?
}

struct DraftInput: Codable, Sendable {
    let text: String
    let attachments: [AttachmentData]
    let savedAt: Date

    struct AttachmentData: Codable, Sendable {
        let type: AttachmentType
        let data: Data?
        let filename: String?

        enum AttachmentType: String, Codable, Sendable {
            case image
            case file
        }
    }
}

struct ActiveSheetState: Codable, Sendable {
    enum Kind: String, Codable, Sendable {
        case settings
        case quickSettings
        case sessionPicker
        case filePicker
        case commandPicker
        case newProject
        case cloneProject
        case help
        case keyboardShortcuts
        case ideasDrawer
        case ideaEditor
        case projectSettings
    }

    let kind: Kind
    let projectPath: String?
    let ideaId: String?

    init?(sheet: ActiveSheet?) {
        guard let sheet else { return nil }
        switch sheet {
        case .settings:
            self.kind = .settings
            self.projectPath = nil
            self.ideaId = nil
        case .quickSettings:
            self.kind = .quickSettings
            self.projectPath = nil
            self.ideaId = nil
        case .sessionPicker(let project):
            self.kind = .sessionPicker
            self.projectPath = project.path
            self.ideaId = nil
        case .filePicker(let project):
            self.kind = .filePicker
            self.projectPath = project.path
            self.ideaId = nil
        case .commandPicker:
            self.kind = .commandPicker
            self.projectPath = nil
            self.ideaId = nil
        case .newProject:
            self.kind = .newProject
            self.projectPath = nil
            self.ideaId = nil
        case .cloneProject:
            self.kind = .cloneProject
            self.projectPath = nil
            self.ideaId = nil
        case .help:
            self.kind = .help
            self.projectPath = nil
            self.ideaId = nil
        case .keyboardShortcuts:
            self.kind = .keyboardShortcuts
            self.projectPath = nil
            self.ideaId = nil
        case .ideasDrawer(let project):
            self.kind = .ideasDrawer
            self.projectPath = project.path
            self.ideaId = nil
        case .ideaEditor(let idea):
            self.kind = .ideaEditor
            self.projectPath = nil
            self.ideaId = idea.id
        case .projectSettings(let project):
            self.kind = .projectSettings
            self.projectPath = project.path
            self.ideaId = nil
        }
    }

    func resolve(
        resolveProject: (String) -> Project?,
        resolveIdea: (String) -> Idea?
    ) -> ActiveSheet? {
        switch kind {
        case .settings:
            return .settings
        case .quickSettings:
            return .quickSettings
        case .sessionPicker:
            guard let projectPath else { return nil }
            return resolveProject(projectPath).map { .sessionPicker($0) }
        case .filePicker:
            guard let projectPath else { return nil }
            return resolveProject(projectPath).map { .filePicker($0) }
        case .commandPicker:
            return .commandPicker
        case .newProject:
            return .newProject
        case .cloneProject:
            return .cloneProject
        case .help:
            return .help
        case .keyboardShortcuts:
            return .keyboardShortcuts
        case .ideasDrawer:
            guard let projectPath else { return nil }
            return resolveProject(projectPath).map { .ideasDrawer($0) }
        case .ideaEditor:
            guard let ideaId else { return nil }
            return resolveIdea(ideaId).map { .ideaEditor($0) }
        case .projectSettings:
            guard let projectPath else { return nil }
            return resolveProject(projectPath).map { .projectSettings($0) }
        }
    }
}
```

ActiveSheet is defined in Issue 34 (Sheet System) and reused here for restoration.

---

## Navigation State Integration

### ContentView Integration

```swift
struct ContentView: View {
    @State private var restoration = StateRestorationManager.shared
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            ProjectListView(selection: $restoration.selectedProjectPath)
        } detail: {
            if let projectPath = restoration.selectedProjectPath {
                ChatView(
                    projectPath: projectPath,
                    sessionId: $restoration.selectedSessionId
                )
            } else {
                ContentUnavailableView(
                    "Select a Project",
                    systemImage: "folder",
                    description: Text("Choose a project from the sidebar to start chatting.")
                )
            }
        }
        .sheet(item: $restoration.activeSheet) { sheet in
            sheetContent(for: sheet)
        }
    }

    @ViewBuilder
    private func sheetContent(for sheet: ActiveSheet) -> some View {
        switch sheet {
        case .settings:
            SettingsView()
        case .quickSettings:
            QuickSettingsSheet()
        case .sessionPicker:
            SessionPickerSheet(projectPath: restoration.selectedProjectPath ?? "")
        case .filePicker:
            FilePickerSheet(projectPath: restoration.selectedProjectPath ?? "")
        case .commandPicker:
            CommandPickerSheet()
        case .newProject:
            NewProjectSheet()
        case .cloneProject:
            CloneProjectSheet()
        case .help:
            SlashCommandHelpSheet()
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

Call `resolvePendingSheet` after project and idea stores are hydrated so the sheet can be rebuilt with real models.

### ChatView Draft Integration

```swift
struct ChatView: View {
    let projectPath: String
    @Binding var sessionId: String?

    @State private var restoration = StateRestorationManager.shared
    @State private var inputText = ""

    var body: some View {
        VStack {
            MessageListView(projectPath: projectPath)

            InputView(text: $inputText, onSend: sendMessage)
        }
        .onAppear {
            restoreDraft()
        }
        .onChange(of: inputText) { _, newValue in
            restoration.saveDraft(for: projectPath, text: newValue)
        }
        .onDisappear {
            // Save draft when leaving
            if !inputText.isEmpty {
                restoration.saveDraft(for: projectPath, text: inputText)
            }
        }
    }

    private func restoreDraft() {
        if let draft = restoration.loadDraft(for: projectPath) {
            inputText = draft.text
        }
    }

    private func sendMessage() {
        // ... send logic
        restoration.clearDraft(for: projectPath)
        inputText = ""
    }
}
```

---

## Scene Storage

### SceneStorage Usage

```swift
struct ChatView: View {
    @SceneStorage("scrollOffset") private var scrollOffset: CGFloat = 0
    @SceneStorage("inputText") private var persistedInput: String = ""

    // SceneStorage automatically saves/restores per-scene
}
```

### Scene Phase Handling

```swift
struct CodingBridgeApp: App {
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                // Save state immediately
                StateRestorationManager.shared.persist()
            case .inactive:
                // Prepare for possible termination
                break
            case .active:
                // Refresh if needed
                break
            @unknown default:
                break
            }
        }
    }
}
```

---

## NSUserActivity for Handoff

### UserActivity Setup

```swift
extension StateRestorationManager {
    /// Create NSUserActivity for Handoff.
    func createUserActivity() -> NSUserActivity {
        let activity = NSUserActivity(activityType: "com.codingbridge.chat")
        activity.title = "Continue in CodingBridge"
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = true

        activity.userInfo = [
            "projectPath": selectedProjectPath as Any,
            "sessionId": selectedSessionId as Any,
        ]

        if let projectPath = selectedProjectPath {
            activity.webpageURL = URL(string: "codingbridge://project/\(projectPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")")
        }

        return activity
    }

    /// Restore from NSUserActivity.
    func restore(from activity: NSUserActivity) {
        guard activity.activityType == "com.codingbridge.chat" else { return }

        if let projectPath = activity.userInfo?["projectPath"] as? String {
            selectedProjectPath = projectPath
        }

        if let sessionId = activity.userInfo?["sessionId"] as? String {
            selectedSessionId = sessionId
        }
    }
}
```

### View UserActivity Integration

```swift
struct ChatView: View {
    let projectPath: String

    var body: some View {
        content
            .userActivity("com.codingbridge.chat") { activity in
                activity.title = "Chat in CodingBridge"
                activity.userInfo = ["projectPath": projectPath]
                activity.isEligibleForHandoff = true
            }
    }
}
```

---

## Scroll Position Restoration

### ScrollPositionReader

```swift
struct MessageListView: View {
    let projectPath: String

    @State private var restoration = StateRestorationManager.shared
    @State private var scrollPosition: ScrollPosition = .init()

    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(messages) { message in
                    MessageRow(message: message)
                }
            }
        }
        .scrollPosition($scrollPosition)
        .onAppear {
            restoreScrollPosition()
        }
        .onDisappear {
            saveScrollPosition()
        }
    }

    private func restoreScrollPosition() {
        if let offset = restoration.scrollOffsetsByProject[projectPath] {
            scrollPosition = ScrollPosition(y: offset)
        }
    }

    private func saveScrollPosition() {
        if let offset = scrollPosition.y {
            restoration.scrollOffsetsByProject[projectPath] = offset
        }
    }
}
```

---

## Edge Cases

- **Session deleted while suspended**: Show "session not found" on restore
- **Project removed while suspended**: Clear selection, show project list
- **Very old draft (> 7 days)**: Prompt user to discard or keep
- **App update with state format change**: Migrate or clear gracefully
- **Multiple windows (iPad)**: Each scene has independent state

## Acceptance Criteria

- [ ] Navigation state persists across launches
- [ ] Selected project/session restored
- [ ] Draft messages restored
- [ ] Sheet state restored
- [ ] Scroll positions restored
- [ ] NSUserActivity for Handoff works
- [ ] State clears gracefully on error

## Testing

```swift
class StateRestorationTests: XCTestCase {
    func testNavigationStatePersistence() {
        let manager = StateRestorationManager.shared
        manager.selectedProjectPath = "/test/project"
        manager.selectedSessionId = "session-123"

        // Simulate app restart
        let newManager = StateRestorationManager()
        newManager.restore()

        XCTAssertEqual(newManager.selectedProjectPath, "/test/project")
        XCTAssertEqual(newManager.selectedSessionId, "session-123")
    }

    func testDraftPersistence() {
        let manager = StateRestorationManager.shared
        manager.saveDraft(for: "/test", text: "Hello world")

        let draft = manager.loadDraft(for: "/test")

        XCTAssertEqual(draft?.text, "Hello world")
    }

    func testDraftClearing() {
        let manager = StateRestorationManager.shared
        manager.saveDraft(for: "/test", text: "Draft")
        manager.clearDraft(for: "/test")

        XCTAssertNil(manager.loadDraft(for: "/test"))
    }

    func testUserActivityCreation() {
        let manager = StateRestorationManager.shared
        manager.selectedProjectPath = "/my/project"

        let activity = manager.createUserActivity()

        XCTAssertEqual(activity.activityType, "com.codingbridge.chat")
        XCTAssertEqual(activity.userInfo?["projectPath"] as? String, "/my/project")
    }
}
```
