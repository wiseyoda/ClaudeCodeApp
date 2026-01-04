# Issue 21: App Intents & Siri

**Phase:** 8 (iOS 26 Platform)
**Priority:** Medium
**Status:** Not Started
**Depends On:** None

## Goal

Enable voice control and Shortcuts automation via App Intents framework.

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- See **Depends On** header; add runtime or tooling dependencies here.

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
## Intents Overview

| Intent | Siri Phrase | Action |
|--------|-------------|--------|
| `AskClaudeIntent` | "Ask Claude to..." | Send message to Claude |
| `AbortAgentIntent` | "Stop Claude" | Abort current agent |
| `ApproveToolIntent` | - | Approve pending tool (widgets only) |
| `DenyToolIntent` | - | Deny pending tool (widgets only) |
| `NewChatIntent` | "Start Claude chat" | Open new chat session |
| `SelectProjectIntent` | - | Configuration for other intents |

## Implementation

### Project Entity

```swift
import AppIntents

struct ProjectEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Project")

    static var defaultQuery = ProjectEntityQuery()

    var id: String
    var name: String
    var path: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(path)")
    }
}

struct ProjectEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ProjectEntity] {
        let projects = try await CLIBridgeAPIClient.shared.fetchProjects()
        return projects
            .filter { identifiers.contains($0.path) }
            .map { ProjectEntity(id: $0.path, name: $0.name, path: $0.path) }
    }

    func suggestedEntities() async throws -> [ProjectEntity] {
        let projects = try await CLIBridgeAPIClient.shared.fetchProjects()
        return projects.prefix(5).map {
            ProjectEntity(id: $0.path, name: $0.name, path: $0.path)
        }
    }

    func defaultResult() async -> ProjectEntity? {
        // Return most recently used project
        guard let lastPath = UserDefaults.standard.string(forKey: "lastProjectPath"),
              let project = try? await CLIBridgeAPIClient.shared.fetchProject(path: lastPath) else {
            return nil
        }
        return ProjectEntity(id: project.path, name: project.name, path: project.path)
    }
}
```

### Ask Claude Intent

```swift
import AppIntents

struct AskClaudeIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask Claude"
    static var description = IntentDescription("Send a message to Claude Code")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Question", requestValueDialog: "What would you like to ask Claude?")
    var question: String

    @Parameter(title: "Project")
    var project: ProjectEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Ask Claude \(\.$question)") {
            \.$project
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        // Get project or use default
        let targetProject = project ?? (try await ProjectEntityQuery().defaultResult())
        guard let targetProject else {
            throw IntentError.noProject
        }

        // Send message
        let response = try await CLIBridgeManager.shared.sendMessage(
            question,
            projectPath: targetProject.path
        )

        // Return result
        return .result(
            dialog: IntentDialog("Claude responded"),
            view: ClaudeResponseSnippet(response: response.summary)
        )
    }
}

struct ClaudeResponseSnippet: View {
    let response: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.blue)
                Text("Claude")
                    .font(.headline)
            }
            Text(response)
                .font(.body)
                .lineLimit(5)
        }
        .padding()
    }
}

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case noProject
    case agentBusy
    case connectionFailed

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noProject:
            return "No project selected"
        case .agentBusy:
            return "Claude is busy with another task"
        case .connectionFailed:
            return "Could not connect to Claude"
        }
    }
}
```

### Abort Agent Intent

```swift
struct AbortAgentIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Claude"
    static var description = IntentDescription("Stop the currently running Claude agent")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard CLIBridgeManager.shared.isProcessing else {
            return .result(dialog: "Claude isn't running anything right now")
        }

        try await CLIBridgeManager.shared.abortAgent()
        return .result(dialog: "Claude has been stopped")
    }
}
```

### Approve/Deny Tool Intents

```swift
struct ApproveToolIntent: AppIntent {
    static var title: LocalizedStringResource = "Approve Tool"
    static var description = IntentDescription("Approve a pending tool request")

    @Parameter(title: "Request ID")
    var requestId: String

    init() { }

    init(requestId: String) {
        self.requestId = requestId
    }

    func perform() async throws -> some IntentResult {
        try await CLIBridgeManager.shared.approveRequest(requestId: requestId)
        return .result()
    }
}

struct DenyToolIntent: AppIntent {
    static var title: LocalizedStringResource = "Deny Tool"
    static var description = IntentDescription("Deny a pending tool request")

    @Parameter(title: "Request ID")
    var requestId: String

    init() { }

    init(requestId: String) {
        self.requestId = requestId
    }

    func perform() async throws -> some IntentResult {
        try await CLIBridgeManager.shared.denyRequest(requestId: requestId)
        return .result()
    }
}
```

### New Chat Intent

```swift
struct NewChatIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Claude Chat"
    static var description = IntentDescription("Open a new chat with Claude")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Project")
    var project: ProjectEntity?

    func perform() async throws -> some IntentResult {
        // App will open - navigation handled by URL scheme or app state
        if let project {
            // Store selected project for app to pick up
            UserDefaults.standard.set(project.path, forKey: "pendingChatProject")
        }
        return .result()
    }
}
```

### App Shortcuts

```swift
struct CodingBridgeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskClaudeIntent(),
            phrases: [
                "Ask Claude \(\.$question)",
                "Hey Claude \(\.$question)",
                "Tell Claude \(\.$question)"
            ],
            shortTitle: "Ask Claude",
            systemImageName: "sparkles"
        )

        AppShortcut(
            intent: AbortAgentIntent(),
            phrases: [
                "Stop Claude",
                "Abort Claude",
                "Cancel Claude"
            ],
            shortTitle: "Stop Claude",
            systemImageName: "stop.circle"
        )

        AppShortcut(
            intent: NewChatIntent(),
            phrases: [
                "Start Claude chat",
                "New Claude chat",
                "Open Claude"
            ],
            shortTitle: "New Chat",
            systemImageName: "message.badge.plus"
        )
    }
}
```

### App Registration

```swift
// In CodingBridgeApp.swift
@main
struct CodingBridgeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    init() {
        // Register shortcuts
        CodingBridgeShortcuts.updateAppShortcutParameters()
    }
}
```

## Files to Create

```
CodingBridge/Intents/
├── ProjectEntity.swift             # ~60 lines
├── AskClaudeIntent.swift           # ~80 lines
├── AbortAgentIntent.swift          # ~30 lines
├── ApproveToolIntent.swift         # ~30 lines
├── DenyToolIntent.swift            # ~30 lines
├── NewChatIntent.swift             # ~30 lines
├── CodingBridgeShortcuts.swift     # ~50 lines
└── IntentError.swift               # ~20 lines
```

## Files to Modify

| File | Changes |
|------|---------|
| `CodingBridgeApp.swift` | Register `CodingBridgeShortcuts` |
| `CLIBridgeManager.swift` | Add `sendMessage(_, projectPath:)` for intents |
| `Info.plist` | Add `NSUserActivityTypes` for Siri |

## Siri Phrases

| Intent | Phrases |
|--------|---------|
| Ask Claude | "Ask Claude [question]", "Hey Claude [question]" |
| Stop Claude | "Stop Claude", "Abort Claude" |
| New Chat | "Start Claude chat", "Open Claude" |

## Acceptance Criteria

- [ ] "Ask Claude" works via Siri
- [ ] "Stop Claude" aborts running agent
- [ ] "Start Claude chat" opens app
- [ ] Shortcuts appear in Shortcuts app
- [ ] Intents work from widgets
- [ ] Project entity query returns correct projects
- [ ] Error handling provides clear feedback
- [ ] Build passes

## Testing

```swift
struct AppIntentTests: XCTestCase {
    func testAskClaudeIntent() async throws {
        let intent = AskClaudeIntent()
        intent.question = "What time is it?"

        let result = try await intent.perform()
        // Verify dialog is returned
    }

    func testProjectEntityQuery() async throws {
        let query = ProjectEntityQuery()
        let suggestions = try await query.suggestedEntities()

        XCTAssertFalse(suggestions.isEmpty)
    }

    func testAbortWhenNotRunning() async throws {
        let intent = AbortAgentIntent()
        let result = try await intent.perform()

        // Should return "not running" dialog
    }
}
```
