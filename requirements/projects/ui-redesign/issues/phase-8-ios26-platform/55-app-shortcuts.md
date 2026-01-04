---
number: 55
title: App Shortcuts
phase: phase-8-ios26-platform
status: pending
completed_by: null
completed_at: null
verified_by: null
verified_at: null
commit: null
spot_checked: false
blocked_reason: null
---

# Issue 55: App Shortcuts

**Phase:** 8 (iOS 26 Platform)
**Priority:** Medium
**Status:** Not Started
**Depends On:** 21 (App Intents & Siri)
**Target:** iOS 26.2, Xcode 26.2, Swift 6.2.1

## Goal

Implement App Shortcuts that surface key CodingBridge actions in Spotlight, Siri Suggestions, and the Shortcuts app without requiring user configuration.

## Scope

- In scope:
  - Predefined App Shortcuts
  - Spotlight integration
  - Siri Suggestions
  - Shortcuts app visibility
  - Parameterized shortcuts
  - Shortcut phrases
- Out of scope:
  - Full Shortcuts automation actions (Issue #21 covers base App Intents)
  - Shortcut widgets
  - Focus mode integration

## Non-goals

- Custom shortcut builder UI within app
- Shortcut sharing/import
- Cross-device shortcut sync (handled by system)

## Dependencies

- Issue #21 (App Intents & Siri) for base intent infrastructure

## Touch Set

- Files to create:
  - `CodingBridge/Intents/Shortcuts/AppShortcuts.swift`
  - `CodingBridge/Intents/Shortcuts/ShortcutPhrases.swift`
- Files to modify:
  - `CodingBridge/Intents/CodingBridgeShortcuts.swift` (add shortcuts provider)

---

## App Shortcuts Provider

### AppShortcuts Definition

```swift
import AppIntents

/// Provides predefined shortcuts for CodingBridge.
///
/// These shortcuts appear automatically in:
/// - Spotlight search
/// - Siri Suggestions
/// - Shortcuts app (App Shortcuts section)
struct CodingBridgeShortcuts: AppShortcutsProvider {
    /// The app's predefined shortcuts.
    static var appShortcuts: [AppShortcut] {
        // Quick chat in current project
        AppShortcut(
            intent: QuickChatIntent(),
            phrases: [
                "Ask \(.applicationName) about my code",
                "Chat with \(.applicationName)",
                "Start coding with \(.applicationName)",
            ],
            shortTitle: "Quick Chat",
            systemImageName: "message.fill"
        )

        // Open specific project
        AppShortcut(
            intent: OpenProjectIntent(),
            phrases: [
                "Open \(\.$project) in \(.applicationName)",
                "Work on \(\.$project)",
                "Show \(\.$project) project",
            ],
            shortTitle: "Open Project",
            systemImageName: "folder.fill"
        )

        // Resume last session
        AppShortcut(
            intent: ResumeSessionIntent(),
            phrases: [
                "Resume last \(.applicationName) chat",
                "Continue my \(.applicationName) session",
                "Pick up where I left off in \(.applicationName)",
            ],
            shortTitle: "Resume Session",
            systemImageName: "arrow.uturn.backward"
        )

        // Run saved command
        AppShortcut(
            intent: RunCommandIntent(),
            phrases: [
                "Run \(\.$command) in \(.applicationName)",
                "Execute \(\.$command) command",
            ],
            shortTitle: "Run Command",
            systemImageName: "terminal.fill"
        )

        // Project status check (cli-bridge)
        AppShortcut(
            intent: GitStatusIntent(),
            phrases: [
                "Check git status in \(.applicationName)",
                "Show git changes",
                "What's changed in my code",
            ],
            shortTitle: "Git Status",
            systemImageName: "arrow.triangle.branch"
        )

        // Search sessions
        AppShortcut(
            intent: SearchSessionsIntent(),
            phrases: [
                "Search \(.applicationName) for \(\.$query)",
                "Find \(\.$query) in my chats",
            ],
            shortTitle: "Search",
            systemImageName: "magnifyingglass"
        )

        // Capture idea
        AppShortcut(
            intent: CaptureIdeaIntent(),
            phrases: [
                "Save idea to \(.applicationName)",
                "Capture coding idea",
                "Note this for \(.applicationName)",
            ],
            shortTitle: "Capture Idea",
            systemImageName: "lightbulb.fill"
        )
    }
}
```

---

## Intent Implementations

### QuickChatIntent

```swift
/// Start a quick chat session.
struct QuickChatIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Chat"
    static var description = IntentDescription("Start a chat with Claude about your code.")

    static var openAppWhenRun: Bool = true

    @Parameter(title: "Message", requestValueDialog: "What do you want to ask?")
    var message: String?

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        // Store message for app to pick up
        if let message {
            QuickChatStore.shared.pendingMessage = message
        }

        return .result(opensIntent: OpenProjectIntent())
    }
}
```

### OpenProjectIntent

```swift
/// Open a specific project.
struct OpenProjectIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Project"
    static var description = IntentDescription("Open a CodingBridge project.")

    static var openAppWhenRun: Bool = true

    @Parameter(title: "Project")
    var project: ProjectEntity?

    @MainActor
    func perform() async throws -> some IntentResult {
        if let project {
            NavigationState.shared.selectedProjectPath = project.path
        }

        return .result()
    }
}
```

### ResumeSessionIntent

```swift
/// Resume the most recent session.
struct ResumeSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Resume Session"
    static var description = IntentDescription("Continue your last chat session.")

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Find most recent session across all projects
        let recentSession = await SessionStore.shared.mostRecentSession()

        if let session = recentSession {
            NavigationState.shared.selectedProjectPath = session.projectPath
            NavigationState.shared.selectedSessionId = session.id
        }

        return .result()
    }
}
```

### RunCommandIntent

```swift
/// Run a saved command.
struct RunCommandIntent: AppIntent {
    static var title: LocalizedStringResource = "Run Command"
    static var description = IntentDescription("Execute a saved command in CodingBridge.")

    static var openAppWhenRun: Bool = true

    @Parameter(title: "Command")
    var command: CommandEntity

    @Parameter(title: "Project")
    var project: ProjectEntity?

    @MainActor
    func perform() async throws -> some IntentResult {
        // Set up command execution
        QuickChatStore.shared.pendingMessage = command.content

        if let project {
            NavigationState.shared.selectedProjectPath = project.path
        }

        return .result()
    }
}
```

### GitStatusIntent

```swift
/// Check git status via cli-bridge for current or specified project.
struct GitStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Git Status"
    static var description = IntentDescription("Check project status via cli-bridge.")

    static var openAppWhenRun: Bool = true

    @Parameter(title: "Project")
    var project: ProjectEntity?

    @MainActor
    func perform() async throws -> some IntentResult {
        // Request status via cli-bridge (no local git integration)
        await CLIBridgeManager.shared.requestProjectStatus(project?.path)

        if let project {
            NavigationState.shared.selectedProjectPath = project.path
        }

        return .result()
    }
}
```

### SearchSessionsIntent

```swift
/// Search across all sessions.
struct SearchSessionsIntent: AppIntent {
    static var title: LocalizedStringResource = "Search Sessions"
    static var description = IntentDescription("Search your CodingBridge chat history.")

    static var openAppWhenRun: Bool = true

    @Parameter(title: "Query", requestValueDialog: "What are you looking for?")
    var query: String

    @MainActor
    func perform() async throws -> some IntentResult {
        NavigationState.shared.showGlobalSearch = true
        NavigationState.shared.searchQuery = query

        return .result()
    }
}
```

### CaptureIdeaIntent

```swift
/// Capture a quick idea.
struct CaptureIdeaIntent: AppIntent {
    static var title: LocalizedStringResource = "Capture Idea"
    static var description = IntentDescription("Save a coding idea for later.")

    @Parameter(title: "Idea", requestValueDialog: "What's your idea?")
    var idea: String

    @Parameter(title: "Project")
    var project: ProjectEntity?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let projectPath = project?.path ?? NavigationState.shared.selectedProjectPath

        guard let path = projectPath else {
            throw AppError.projectNotFound(path: "No project selected")
        }

        let store = IdeasStore(projectPath: path)
        store.addIdea(Idea(text: idea))

        return .result(dialog: "Idea saved!")
    }
}
```

---

## Entity Definitions

### ProjectEntity

```swift
/// Entity representing a project for App Intents.
struct ProjectEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Project")

    static var defaultQuery = ProjectQuery()

    var id: String { path }
    let path: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(path)",
            image: .init(systemName: "folder.fill")
        )
    }
}

struct ProjectQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ProjectEntity] {
        let projects = await ProjectStore.shared.projects
        return projects
            .filter { identifiers.contains($0.path) }
            .map { ProjectEntity(path: $0.path, name: $0.name) }
    }

    func suggestedEntities() async throws -> [ProjectEntity] {
        let projects = await ProjectStore.shared.recentProjects(limit: 5)
        return projects.map { ProjectEntity(path: $0.path, name: $0.name) }
    }
}
```

### CommandEntity

```swift
/// Entity representing a saved command.
struct CommandEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Command")

    static var defaultQuery = CommandQuery()

    var id: String { name }
    let name: String
    let content: String
    let category: String?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: category.map { "\($0)" },
            image: .init(systemName: "terminal.fill")
        )
    }
}

struct CommandQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [CommandEntity] {
        let commands = CommandStore.shared.commands
        return commands
            .filter { identifiers.contains($0.name) }
            .map { CommandEntity(name: $0.name, content: $0.content, category: $0.category) }
    }

    func suggestedEntities() async throws -> [CommandEntity] {
        let commands = CommandStore.shared.recentCommands(limit: 10)
        return commands.map { CommandEntity(name: $0.name, content: $0.content, category: $0.category) }
    }
}
```

---

## Shortcut Phrases

### Phrase Guidelines

| Phrase Type | Example | Notes |
|-------------|---------|-------|
| Action-first | "Open project X" | Start with verb |
| Natural | "Work on my iOS app" | Conversational |
| App-prefixed | "Ask CodingBridge about..." | Clear app targeting |
| Parameter | "Run \(\.$command) command" | Dynamic substitution |

### Phrase Localization

```swift
// Localizable.strings
"shortcut.quickchat.phrase1" = "Ask %@ about my code";
"shortcut.quickchat.phrase2" = "Chat with %@";
"shortcut.openproject.phrase1" = "Open %@ in %@";
"shortcut.resume.phrase1" = "Resume last %@ chat";
```

---

## Spotlight Integration

### Searchable Actions

App Shortcuts automatically appear in Spotlight when:
1. User types action name ("Quick Chat")
2. User types partial phrase ("coding bridge chat")
3. User types parameter value ("my-project")

### Siri Suggestions

Actions appear in Siri Suggestions based on:
1. Frequency of use
2. Time of day patterns
3. Location patterns
4. Recently used parameters

### Donation for Suggestions

```swift
extension SessionStore {
    /// Donate session interaction for Siri learning.
    func donateInteraction(project: Project, session: Session) {
        let intent = ResumeSessionIntent()
        intent.suggestedInvocationPhrase = "Continue \(project.name)"

        let interaction = INInteraction(intent: intent, response: nil)
        interaction.donate { error in
            if let error {
                Logger.intents.error("Donation failed: \(error.localizedDescription)")
            }
        }
    }
}
```

---

## Edge Cases

- **No projects available**: Show error dialog, suggest creating project
- **Command not found**: Fall back to free-form input
- **Session deleted since shortcut created**: Show "session not found" and offer alternatives
- **Offline mode**: Queue shortcut action for when connected
- **Multiple projects with same name**: Use path disambiguation

## Acceptance Criteria

- [ ] AppShortcutsProvider with 7 shortcuts defined
- [ ] All shortcuts appear in Shortcuts app
- [ ] Spotlight finds shortcuts by phrase
- [ ] Parameter entities (Project, Command) work
- [ ] Phrase variations recognized by Siri
- [ ] Shortcut execution opens correct app state
- [ ] Donation enables Siri Suggestions

## Testing

```swift
class AppShortcutsTests: XCTestCase {
    func testShortcutsProvider() {
        let shortcuts = CodingBridgeShortcuts.appShortcuts

        XCTAssertEqual(shortcuts.count, 7)
        XCTAssertTrue(shortcuts.contains { $0.shortTitle == "Quick Chat" })
    }

    func testProjectEntityQuery() async throws {
        let query = ProjectQuery()
        let suggestions = try await query.suggestedEntities()

        XCTAssertLessThanOrEqual(suggestions.count, 5)
    }

    func testOpenProjectIntent() async throws {
        let intent = OpenProjectIntent()
        intent.project = ProjectEntity(path: "/test", name: "Test")

        _ = try await intent.perform()

        XCTAssertEqual(NavigationState.shared.selectedProjectPath, "/test")
    }
}
```
