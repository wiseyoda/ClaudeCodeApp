# Issue 20: Live Activities

**Phase:** 8 (iOS 26 Platform)
**Priority:** High
**Status:** Not Started
**Depends On:** Issue #09 (Card Status Banners)

## Goal

Show agent progress on the lock screen and Dynamic Island while tasks are running.

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- Depends On: Issue #09 (Card Status Banners).
- See Issue #54 for APNs push updates and rich notification setup.

## Touch Set
- Files to create: TBD.
- Files to modify: TBD.

## Interface Definitions
- List new or changed models, protocols, and API payloads.

## Tests
- [ ] Unit tests updated or added.
- [ ] UI tests updated or added (if user flows change).
## Live Activity Display

### Lock Screen (Expanded)

```
┌─────────────────────────────────────────────────────────────┐
│  ✨ Claude                                    my-project    │
│  ─────────────────────────────────────────────────────────  │
│  🔧 Bash: npm install                                       │
│  ████████████░░░░░░░░░░░░░░░░░░░░░░  45%                   │
│                                                             │
│  ⏱ 2:34        📊 45k / 200k tokens        [Abort]         │
└─────────────────────────────────────────────────────────────┘
```

### Dynamic Island (Compact)

```
┌───────────────────────────────────────┐
│  ✨  ████████░░░░  Bash  2:34  ⚙️     │
└───────────────────────────────────────┘
```

### Dynamic Island (Minimal)

```
┌─────┐        ┌─────┐
│  ✨ │        │ 2:34│
└─────┘        └─────┘
```

### Push Updates (Optional)

- Live Activity push updates use APNs (see Issue #54).
- Prefer local updates for active sessions; fall back to push for background.

## Implementation

### Activity Attributes

```swift
import ActivityKit

struct AgentProgressActivity: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentTool: String
        var toolDescription: String?
        var progress: Double?  // nil = indeterminate
        var tokenUsage: TokenUsage
        var elapsedSeconds: Int
        var status: AgentStatus

        struct TokenUsage: Codable, Hashable {
            let current: Int
            let max: Int
        }

        enum AgentStatus: String, Codable {
            case running
            case awaitingApproval
            case completed
            case error
        }
    }

    // Static attributes (don't change during activity)
    let projectName: String
    let projectPath: String
    let sessionId: String
}
```

### Live Activity Manager

```swift
import ActivityKit
import SwiftUI

actor AgentLiveActivityManager {
    static let shared = AgentLiveActivityManager()

    private var currentActivity: Activity<AgentProgressActivity>?

    // MARK: - Start Activity

    func startActivity(
        projectName: String,
        projectPath: String,
        sessionId: String
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = AgentProgressActivity(
            projectName: projectName,
            projectPath: projectPath,
            sessionId: sessionId
        )

        let initialState = AgentProgressActivity.ContentState(
            currentTool: "Starting...",
            toolDescription: nil,
            progress: nil,
            tokenUsage: .init(current: 0, max: 200_000),
            elapsedSeconds: 0,
            status: .running
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
        } catch {
            Logger.error("Failed to start Live Activity: \(error)")
        }
    }

    // MARK: - Update Activity

    func updateProgress(
        tool: String,
        description: String? = nil,
        progress: Double? = nil,
        tokenUsage: (current: Int, max: Int),
        elapsedSeconds: Int
    ) async {
        guard let activity = currentActivity else { return }

        let state = AgentProgressActivity.ContentState(
            currentTool: tool,
            toolDescription: description,
            progress: progress,
            tokenUsage: .init(current: tokenUsage.current, max: tokenUsage.max),
            elapsedSeconds: elapsedSeconds,
            status: .running
        )

        await activity.update(.init(state: state, staleDate: nil))
    }

    func showAwaitingApproval(tool: String, description: String) async {
        guard let activity = currentActivity else { return }

        var state = activity.content.state
        state.currentTool = tool
        state.toolDescription = description
        state.status = .awaitingApproval

        await activity.update(.init(state: state, staleDate: nil))
    }

    // MARK: - End Activity

    func endActivity(success: Bool) async {
        guard let activity = currentActivity else { return }

        var finalState = activity.content.state
        finalState.status = success ? .completed : .error

        await activity.end(
            .init(state: finalState, staleDate: nil),
            dismissalPolicy: .after(.now + 5)  // Dismiss after 5 seconds
        )

        currentActivity = nil
    }

    func isActive() -> Bool {
        currentActivity != nil
    }

    func currentState() -> AgentProgressActivity.ContentState? {
        currentActivity?.content.state
    }
}
```

### Live Activity Views

```swift
import WidgetKit
import SwiftUI

struct AgentProgressLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AgentProgressActivity.self) { context in
            // Lock screen view
            LockScreenActivityView(context: context)
                .activityBackgroundTint(.clear)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.blue)
                        Text(context.attributes.projectName)
                            .font(.headline)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Button(intent: AbortAgentIntent()) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        HStack {
                            Image(systemName: "wrench.fill")
                                .foregroundStyle(.orange)
                            Text(context.state.currentTool)
                        }

                        if let progress = context.state.progress {
                            ProgressView(value: progress)
                                .tint(.blue)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Label(formatTime(context.state.elapsedSeconds), systemImage: "clock")
                        Spacer()
                        Text("\(context.state.tokenUsage.current / 1000)k / \(context.state.tokenUsage.max / 1000)k")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "sparkles")
                    .foregroundStyle(.blue)
            } compactTrailing: {
                Text(formatTime(context.state.elapsedSeconds))
                    .font(.caption)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "sparkles")
                    .foregroundStyle(.blue)
            }
        }
    }
}

struct LockScreenActivityView: View {
    let context: ActivityViewContext<AgentProgressActivity>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.blue)
                Text("Claude")
                    .font(.headline)
                Spacer()
                Text(context.attributes.projectName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Current tool
            HStack {
                Image(systemName: "wrench.fill")
                    .foregroundStyle(.orange)
                Text(context.state.currentTool)
                if let desc = context.state.toolDescription {
                    Text(desc)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            // Progress
            if let progress = context.state.progress {
                ProgressView(value: progress)
                    .tint(.blue)
            } else if context.state.status == .running {
                ProgressView()
                    .progressViewStyle(.linear)
            }

            // Footer
            HStack {
                Label(formatTime(context.state.elapsedSeconds), systemImage: "clock")

                Spacer()

                Label(
                    "\(context.state.tokenUsage.current / 1000)k / \(context.state.tokenUsage.max / 1000)k",
                    systemImage: "chart.bar"
                )

                Spacer()

                if context.state.status == .running {
                    Button(intent: AbortAgentIntent()) {
                        Text("Abort")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            .font(.caption)
        }
        .padding()
    }
}

// Helper
func formatTime(_ seconds: Int) -> String {
    let minutes = seconds / 60
    let secs = seconds % 60
    return String(format: "%d:%02d", minutes, secs)
}
```

## Integration with CLIBridgeManager

```swift
extension CLIBridgeManager {
    func handleStreamEventForLiveActivity(_ event: StreamEvent) async {
        switch event {
        case .toolStart(let msg):
            await AgentLiveActivityManager.shared.updateProgress(
                tool: msg.name,
                description: msg.inputDescription,
                progress: nil,
                tokenUsage: tokenUsage,
                elapsedSeconds: elapsedSeconds
            )

        case .progress(let msg):
            await AgentLiveActivityManager.shared.updateProgress(
                tool: msg.tool,
                description: msg.detail,
                progress: msg.progress,
                tokenUsage: tokenUsage,
                elapsedSeconds: elapsedSeconds
            )

        case .permissionRequest(let msg):
            if let request = ApprovalRequest.from([
                "requestId": msg.id,
                "toolName": msg.tool,
                "input": msg.input
            ]) {
                await AgentLiveActivityManager.shared.showAwaitingApproval(
                    tool: request.toolName,
                    description: request.displayDescription
                )
            }

        case .stopped:
            await AgentLiveActivityManager.shared.endActivity(success: true)

        case .error, .connectionError:
            await AgentLiveActivityManager.shared.endActivity(success: false)

        default:
            break
        }
    }
}
```

StreamEvent payloads are defined in docs/contracts/models and docs/contracts/api.

## Edge Cases

- Activities disabled: no-op and show a subtle in-app status (no errors).
- Live Activity start fails: log once and continue without retry storm.
- Push updates not available: fall back to local updates only.
- Session ends unexpectedly: end the activity with error state.

## Files to Create

```
CodingBridge/Activities/
├── AgentProgressActivity.swift         # ~50 lines
├── AgentLiveActivityManager.swift      # ~100 lines
└── AgentProgressLiveActivity.swift     # ~150 lines (widget view)
```

## Files to Modify

| File | Changes |
|------|---------|
| `CLIBridgeManager.swift` | Start/update/end Live Activity on events |
| `Info.plist` | Add `NSSupportsLiveActivities = YES` |
| Widget extension | Register Live Activity widget |

## Acceptance Criteria

- [ ] Live Activity starts when agent begins task
- [ ] Lock screen shows tool, progress, tokens
- [ ] Dynamic Island shows compact status
- [ ] Progress updates in real-time
- [ ] Abort button works from Live Activity
- [ ] Activity ends gracefully on completion/error
- [ ] Activity dismissed after 5 seconds on end
- [ ] ActivityKit disabled path handled without errors
- [ ] Build passes

## Testing

```swift
struct LiveActivityTests: XCTestCase {
    func testActivityStart() async {
        let manager = AgentLiveActivityManager.shared
        await manager.startActivity(
            projectName: "test-project",
            projectPath: "/path/to/project",
            sessionId: "test-session"
        )

        // Verify activity was created
        let isActive = await manager.isActive()
        XCTAssertTrue(isActive)
    }

    func testActivityUpdate() async {
        // Start activity first
        await manager.startActivity(...)

        // Update progress
        await manager.updateProgress(
            tool: "Bash",
            description: "npm install",
            progress: 0.5,
            tokenUsage: (50000, 200000),
            elapsedSeconds: 30
        )

        // Verify state updated
        let state = await manager.currentState()
        XCTAssertEqual(state?.currentTool, "Bash")
    }
}
```
