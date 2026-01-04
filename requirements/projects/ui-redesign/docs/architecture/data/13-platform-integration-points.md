# Platform Integration Points


### Live Activities

```swift
// Start activity when agent begins
func startAgentActivity(projectName: String, sessionId: String) async {
    let attributes = AgentProgressActivity(projectName: projectName, sessionId: sessionId)
    let state = AgentProgressActivity.ContentState(
        currentTool: "Starting...",
        progress: nil,
        tokenUsage: (0, 200000)
    )

    activity = try? Activity.request(
        attributes: attributes,
        content: .init(state: state, staleDate: nil),
        pushType: nil
    )
}

// Update activity on events
func updateActivityProgress(tool: String, progress: Double?) async {
    guard let activity else { return }
    let state = AgentProgressActivity.ContentState(
        currentTool: tool,
        progress: progress,
        tokenUsage: tokenUsage
    )
    await activity.update(.init(state: state, staleDate: nil))
}
```

### App Intents

```swift
struct AskClaudeIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask Claude"
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Question")
    var question: String

    @Parameter(title: "Project")
    var project: ProjectEntity?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let response = try await CLIBridgeManager.shared.sendMessage(question, to: project)
        return .result(dialog: IntentDialog(response.summary))
    }
}
```

### Control Center

```swift
struct AbortAgentControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "abort-agent") {
            ControlWidgetButton(action: AbortAgentIntent()) {
                Label("Abort Claude", systemImage: "stop.circle.fill")
            }
        }
        .displayName("Abort Agent")
        .description("Stop the currently running Claude agent")
    }
}
```
