# Issue 18: Interactive Widgets

**Phase:** 8 (iOS 26 Platform)
**Priority:** Medium
**Status:** Not Started
**Depends On:** Issue #21 (App Intents)

## Goal

Add home screen widgets showing agent status with interactive controls for tool approval and quick actions.

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
## Widget Types

### 1. Agent Status Widget (Small)

Shows current agent state with basic info:

```
┌─────────────────────┐
│  ✨ Claude          │
│  ───────────────    │
│  Running: Bash      │
│  45s • 12k tokens   │
└─────────────────────┘
```

### 2. Agent Status Widget (Medium)

Shows more detail with interactive approve button:

```
┌─────────────────────────────────────────┐
│  ✨ Claude                    [Abort]   │
│  ─────────────────────────────────────  │
│  🔧 Bash: npm install                   │
│                                         │
│  ⏳ Awaiting approval                   │
│  ┌─────────┐  ┌─────────────────────┐  │
│  │ Deny    │  │ Approve             │  │
│  └─────────┘  └─────────────────────┘  │
└─────────────────────────────────────────┘
```

### 3. Quick Chat Widget (Small)

Quick access to start a chat:

```
┌─────────────────────┐
│  💬 Ask Claude      │
│  ─────────────────  │
│  Tap to chat        │
│  📁 my-project      │
└─────────────────────┘
```

## Implementation

### Widget Target Setup

Create a new Widget Extension target:

```
CodingBridgeWidgets/
├── CodingBridgeWidgets.swift      # Widget bundle
├── AgentStatusWidget.swift        # Status widget
├── QuickChatWidget.swift          # Quick chat widget
├── WidgetEntries.swift            # Timeline entries
└── Assets.xcassets                # Widget assets
```

### Widget Bundle

```swift
import WidgetKit
import SwiftUI

@main
struct CodingBridgeWidgets: WidgetBundle {
    var body: some Widget {
        AgentStatusWidget()
        QuickChatWidget()
    }
}
```

### Agent Status Widget

```swift
import WidgetKit
import SwiftUI
import AppIntents

struct AgentStatusWidget: Widget {
    let kind = "agent-status"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectProjectIntent.self,
            provider: AgentStatusProvider()
        ) { entry in
            AgentStatusWidgetView(entry: entry)
                .containerBackground(.glass, for: .widget)
        }
        .configurationDisplayName("Agent Status")
        .description("Shows current Claude agent status")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct AgentStatusEntry: TimelineEntry {
    let date: Date
    let projectName: String
    let agentState: AgentState
    let currentTool: String?
    let pendingApproval: ApprovalRequest?
    let tokenUsage: (current: Int, max: Int)
    let elapsedTime: TimeInterval

    enum AgentState {
        case idle
        case running
        case awaitingApproval
        case completed
        case error(String)
    }
}

struct AgentStatusProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> AgentStatusEntry {
        AgentStatusEntry(
            date: .now,
            projectName: "my-project",
            agentState: .running,
            currentTool: "Bash",
            pendingApproval: nil,
            tokenUsage: (12000, 200000),
            elapsedTime: 45
        )
    }

    func snapshot(for configuration: SelectProjectIntent, in context: Context) async -> AgentStatusEntry {
        await fetchCurrentStatus(for: configuration.project)
    }

    func timeline(for configuration: SelectProjectIntent, in context: Context) async -> Timeline<AgentStatusEntry> {
        let entry = await fetchCurrentStatus(for: configuration.project)
        // Refresh every 5 seconds when agent is running
        let refreshDate = entry.agentState == .running
            ? Date().addingTimeInterval(5)
            : Date().addingTimeInterval(60)
        return Timeline(entries: [entry], policy: .after(refreshDate))
    }

    private func fetchCurrentStatus(for project: ProjectEntity?) async -> AgentStatusEntry {
        // Fetch from shared app group container or API
        // ...
    }
}
```

### Widget View

```swift
struct AgentStatusWidgetView: View {
    let entry: AgentStatusEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallAgentStatusView(entry: entry)
        case .systemMedium:
            MediumAgentStatusView(entry: entry)
        default:
            SmallAgentStatusView(entry: entry)
        }
    }
}

struct SmallAgentStatusView: View {
    let entry: AgentStatusEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                Text("Claude")
                    .font(.headline)
            }

            Divider()

            if let tool = entry.currentTool {
                Text("Running: \(tool)")
                    .font(.caption)
            } else {
                Text("Idle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack {
                Text(formatTime(entry.elapsedTime))
                Spacer()
                Text("\(entry.tokenUsage.current / 1000)k")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}

struct MediumAgentStatusView: View {
    let entry: AgentStatusEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                Text("Claude")
                    .font(.headline)
                Spacer()
                if entry.agentState == .running {
                    Button(intent: AbortAgentIntent()) {
                        Text("Abort")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }

            Divider()

            // Current tool
            if let tool = entry.currentTool {
                HStack {
                    Image(systemName: "wrench.fill")
                        .foregroundStyle(.orange)
                    Text("\(tool)")
                }
                .font(.subheadline)
            }

            // Pending approval
            if let approval = entry.pendingApproval {
                VStack(spacing: 8) {
                    Text("Awaiting approval")
                        .font(.caption)
                        .foregroundStyle(.orange)

                    HStack(spacing: 12) {
                        Button(intent: DenyToolIntent(requestId: approval.requestId)) {
                            Text("Deny")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button(intent: ApproveToolIntent(requestId: approval.requestId)) {
                            Text("Approve")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            Spacer()
        }
    }
}
```

### Quick Chat Widget

```swift
struct QuickChatWidget: Widget {
    let kind = "quick-chat"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectProjectIntent.self,
            provider: QuickChatProvider()
        ) { entry in
            QuickChatWidgetView(entry: entry)
                .containerBackground(.glass, for: .widget)
        }
        .configurationDisplayName("Quick Chat")
        .description("Quickly start a chat with Claude")
        .supportedFamilies([.systemSmall])
    }
}

struct QuickChatWidgetView: View {
    let entry: QuickChatEntry

    var body: some View {
        Link(destination: URL(string: "codingbridge://chat/\(entry.projectPath)")!) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "message.badge.plus")
                    Text("Ask Claude")
                        .font(.headline)
                }

                Divider()

                Text("Tap to chat")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.secondary)
                    Text(entry.projectName)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
        }
    }
}
```

## App Group for Data Sharing

### Setup

1. Create App Group: `group.com.yourcompany.codingbridge`
2. Add to both main app and widget extension capabilities

### Shared Data

```swift
// In main app
actor WidgetDataManager {
    static let shared = WidgetDataManager()

    private let containerURL = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: "group.com.yourcompany.codingbridge")!

    func updateAgentStatus(_ status: AgentStatusData) async {
        let data = try? JSONEncoder().encode(status)
        try? data?.write(to: containerURL.appendingPathComponent("agent-status.json"))
        WidgetCenter.shared.reloadTimelines(ofKind: "agent-status")
    }
}

// Update on stream events
func handleStreamEvent(_ event: StreamEvent) async {
    // ... handle event
    await WidgetDataManager.shared.updateAgentStatus(currentStatus)
}
```

## Files to Create

```
CodingBridgeWidgets/
├── CodingBridgeWidgets.swift           # ~20 lines
├── AgentStatusWidget.swift             # ~200 lines
├── QuickChatWidget.swift               # ~80 lines
├── WidgetEntries.swift                 # ~50 lines
├── Providers/
│   ├── AgentStatusProvider.swift       # ~60 lines
│   └── QuickChatProvider.swift         # ~40 lines
└── Views/
    ├── SmallAgentStatusView.swift      # ~40 lines
    └── MediumAgentStatusView.swift     # ~80 lines
```

## Files to Modify

| File | Changes |
|------|---------|
| `CodingBridge.xcodeproj` | Add widget extension target |
| `CLIBridgeManager.swift` | Call `WidgetDataManager.updateAgentStatus()` on state changes |
| App entitlements | Add App Group capability |

## Acceptance Criteria

- [ ] Widget extension target created
- [ ] Small agent status widget displays current state
- [ ] Medium agent status widget shows approval buttons
- [ ] Quick chat widget opens app to correct project
- [ ] Widgets refresh when agent state changes
- [ ] Approve/Deny buttons work from widget
- [ ] App Group sharing works correctly
- [ ] Glass background applied to all widgets
- [ ] Build passes

## Testing

```swift
struct WidgetPreviewTests: PreviewProvider {
    static var previews: some View {
        Group {
            AgentStatusWidgetView(entry: .running)
                .previewContext(WidgetPreviewContext(family: .systemSmall))

            AgentStatusWidgetView(entry: .awaitingApproval)
                .previewContext(WidgetPreviewContext(family: .systemMedium))

            QuickChatWidgetView(entry: .sample)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
        }
    }
}
```
