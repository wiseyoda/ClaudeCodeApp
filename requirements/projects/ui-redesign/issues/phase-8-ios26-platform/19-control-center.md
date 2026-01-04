# Issue 19: Control Center Controls

**Phase:** 8 (iOS 26 Platform)
**Priority:** Medium
**Status:** Not Started
**Depends On:** Issue #21 (App Intents)

## Goal

Add Control Center controls for quick agent actions without opening the app.

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- Depends On: Issue #21 (App Intents).
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
## Control Types

### 1. Abort Agent Control

Stop the currently running agent:

```
┌─────────────────────┐
│  ⛔ Abort Claude    │
│  Stop current agent │
└─────────────────────┘
```

### 2. New Chat Control

Start a new chat session:

```
┌─────────────────────┐
│  💬 New Chat        │
│  Start conversation │
└─────────────────────┘
```

### 3. Agent Status Control (Toggle)

Shows status and allows abort:

```
┌─────────────────────┐
│  ✨ Claude Active   │
│  Tap to abort       │
└─────────────────────┘
```

## Implementation

### Control Widget Bundle

```swift
import WidgetKit
import SwiftUI
import AppIntents

struct CodingBridgeControls: ControlWidgetBundle {
    var body: some ControlWidget {
        AbortAgentControl()
        NewChatControl()
        AgentStatusControl()
    }
}
```

### Abort Agent Control

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

struct AbortAgentIntent: ControlConfigurationIntent {
    static var title: LocalizedStringResource = "Abort Agent"
    static var description = IntentDescription("Stops the currently running Claude agent")

    func perform() async throws -> some IntentResult {
        try await CLIBridgeManager.shared.abortAgent()
        return .result()
    }
}
```

### New Chat Control

```swift
struct NewChatControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: "new-chat",
            intent: NewChatControlIntent.self
        ) { configuration in
            ControlWidgetButton(action: configuration) {
                Label {
                    Text("New Chat")
                    if let project = configuration.project {
                        Text(project.name)
                    }
                } icon: {
                    Image(systemName: "message.badge.plus")
                }
            }
        }
        .displayName("New Chat")
        .description("Start a new chat with Claude")
    }
}

struct NewChatControlIntent: ControlConfigurationIntent {
    static var title: LocalizedStringResource = "New Chat"
    static var description = IntentDescription("Start a new chat session")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Project")
    var project: ProjectEntity?

    func perform() async throws -> some IntentResult {
        // App will open to the chat view for the selected project
        return .result()
    }
}
```

### Agent Status Control (Toggle Style)

```swift
struct AgentStatusControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "agent-status",
            provider: AgentStatusValueProvider()
        ) { value in
            ControlWidgetToggle(
                "Claude",
                isOn: value.isRunning,
                action: ToggleAgentIntent(shouldRun: !value.isRunning)
            ) { isRunning in
                Label {
                    Text(isRunning ? "Running" : "Idle")
                } icon: {
                    Image(systemName: isRunning ? "sparkles" : "sparkle")
                }
            }
            .tint(value.isRunning ? .blue : .secondary)
        }
        .displayName("Agent Status")
        .description("Shows Claude agent status")
    }
}

struct AgentStatusValue {
    let isRunning: Bool
    let currentTool: String?
}

struct AgentStatusValueProvider: ControlValueProvider {
    var previewValue: AgentStatusValue {
        AgentStatusValue(isRunning: true, currentTool: "Bash")
    }

    func currentValue() async throws -> AgentStatusValue {
        let status = await CLIBridgeManager.shared.currentStatus
        return AgentStatusValue(
            isRunning: status.isProcessing,
            currentTool: status.currentTool
        )
    }
}

struct ToggleAgentIntent: SetValueIntent {
    static var title: LocalizedStringResource = "Toggle Agent"

    @Parameter(title: "Should Run")
    var shouldRun: Bool

    init() { }

    init(shouldRun: Bool) {
        self.shouldRun = shouldRun
    }

    func perform() async throws -> some IntentResult {
        if !shouldRun {
            try await CLIBridgeManager.shared.abortAgent()
        }
        // Note: Can't start agent from control - that requires user input
        return .result()
    }
}
```

## App Integration

### Refreshing Controls

```swift
// In CLIBridgeManager
import WidgetKit

extension CLIBridgeManager {
    func updateControlCenterStatus() {
        ControlCenter.shared.reloadControls(ofKind: "agent-status")
    }
}

// Call on state changes
func handleAgentStateChange(_ state: AgentState) {
    // ... handle state
    updateControlCenterStatus()
}
```

### Control Center Appearance

Controls automatically use system styling. The only customization is:
- Icon (SF Symbol)
- Tint color
- Label text

## Files to Create

```
CodingBridge/Controls/
├── CodingBridgeControls.swift      # ~20 lines
├── AbortAgentControl.swift         # ~40 lines
├── NewChatControl.swift            # ~50 lines
└── AgentStatusControl.swift        # ~80 lines
```

## Files to Modify

| File | Changes |
|------|---------|
| `CodingBridgeApp.swift` | Register control widget bundle |
| `CLIBridgeManager.swift` | Call `ControlCenter.shared.reloadControls()` on state changes |
| App entitlements | Ensure proper capabilities |

## Acceptance Criteria

- [ ] Abort Agent control appears in Control Center
- [ ] New Chat control opens app to chat
- [ ] Agent Status shows running/idle state
- [ ] Tapping controls executes correct action
- [ ] Controls refresh when agent state changes
- [ ] Controls appear in Control Center customization
- [ ] Build passes

## Testing

### Manual Testing

1. Add controls to Control Center via Settings
2. Start an agent task in app
3. Verify Agent Status shows "Running"
4. Tap Abort control
5. Verify agent stops
6. Verify status updates to "Idle"

### Automated Testing

```swift
struct ControlIntentTests: XCTestCase {
    func testAbortAgentIntent() async throws {
        let intent = AbortAgentIntent()
        _ = try await intent.perform()
        // Verify agent was aborted
    }

    func testAgentStatusProvider() async throws {
        let provider = AgentStatusValueProvider()
        let value = try await provider.currentValue()
        // Verify value matches manager state
    }
}
```
