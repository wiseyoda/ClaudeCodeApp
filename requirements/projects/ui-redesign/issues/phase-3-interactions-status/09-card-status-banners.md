# Issue 09: Card Status Banners

**Phase:** 3 (Interactions & Status)
**Priority:** High
**Status:** Not Started
**Depends On:** Issue 03 (Protocol & Router)

## Goal
Define and implement Card Status Banners as described in this spec.

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- Depends On: Issue 03 (Protocol & Router).
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
## Problem

Currently, status banners for long-running tools (subagent, web search, progress) are:
1. **Separate from message cards** - displayed in ChatView status section
2. **No auto-dismissal** - subagent banner never goes away (BUG)
3. **Inconsistent styling** - different from message cards
4. **Hidden by other UI** - progress hidden when approval pending

## Solution

Integrate status banners into the card system:
1. Add `StatusBannerState` to message cards
2. Track active operations by tool use ID
3. Auto-dismiss when tool result received OR final message received
4. Consistent styling with message design system

Note: The chat-level status message banner (fun messages above input while streaming) is a separate feature and should not be conflated with card status banners.

## Current Banner Types

| Banner | Trigger Event | Current Location | Bug |
|--------|---------------|------------------|-----|
| Subagent | `subagentStart` | CLIBridgeBanners | Never dismisses |
| Tool Progress | `progress` | CLIBridgeBanners | Hidden by approval |
| Input Queued | `inputQueued` | CLIBridgeBanners | OK |

## Design

### StatusBannerState

```swift
enum StatusBannerState: Equatable {
    case none
    case inProgress(ProgressInfo)
    case subagent(SubagentInfo)
    case queued(position: Int)
    case completed
    case error(String)
}

struct ProgressInfo: Equatable {
    let toolName: String
    let detail: String?
    let progress: Double?    // 0-1, nil for indeterminate
    let startTime: Date
}

struct SubagentInfo: Equatable {
    let id: String
    let displayName: String
    let description: String
    let startTime: Date
}
```

### Integration with MessageCardRouter

Status banners are rendered by the router, not by individual card views.

```swift
struct MessageCardRouter: View {
    let message: ChatMessage
    let statusBanner: StatusBannerState  // NEW

    var body: some View {
        VStack(spacing: 0) {
            if statusBanner != .none {
                StatusBannerOverlay(state: statusBanner)
            }
            routeToCard()
        }
    }
}
```

### StatusBannerOverlay

```swift
struct StatusBannerOverlay: View {
    let state: StatusBannerState

    var body: some View {
        HStack(spacing: MessageDesignSystem.Spacing.sm) {
            statusIcon
            statusText
            Spacer()
            if showProgress {
                progressIndicator
            }
        }
        .font(MessageDesignSystem.labelFont())
        .padding(.horizontal, MessageDesignSystem.Spacing.cardPadding)
        .padding(.vertical, MessageDesignSystem.Spacing.sm)
        .background(bannerBackground)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch state {
        case .inProgress:
            Image(systemName: "gear")
                .symbolEffect(.rotate)
                .foregroundStyle(.blue)
        case .subagent:
            Image(systemName: "person.2.fill")
                .symbolEffect(.variableColor.iterative.reversing)
                .foregroundStyle(.purple)
        case .queued(let position):
            Image(systemName: "clock.fill")
                .symbolEffect(.pulse)
                .foregroundStyle(.orange)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .error:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch state {
        case .inProgress(let info):
            VStack(alignment: .leading, spacing: 2) {
                Text(info.toolName)
                    .fontWeight(.medium)
                if let detail = info.detail {
                    Text(detail)
                        .foregroundStyle(.secondary)
                }
            }
        case .subagent(let info):
            VStack(alignment: .leading, spacing: 2) {
                Text(info.displayName)
                    .fontWeight(.medium)
                Text(info.description)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        case .queued(let position):
            Text("Queued #\(position)")
        case .completed:
            Text("Complete")
        case .error(let message):
            Text(message)
                .foregroundStyle(.red)
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private var progressIndicator: some View {
        switch state {
        case .inProgress(let info):
            if let progress = info.progress {
                ProgressView(value: progress)
                    .frame(width: 60)
            } else {
                Text(formatElapsed(Date().timeIntervalSince(info.startTime)))
                    .monospacedDigit()
            }
        case .subagent(let info):
            Text(formatElapsed(Date().timeIntervalSince(info.startTime)))
                .monospacedDigit()
        default:
            EmptyView()
        }
    }

    private var bannerBackground: some ShapeStyle {
        switch state {
        case .inProgress: return .blue.opacity(0.1)
        case .subagent: return .purple.opacity(0.1)
        case .queued: return .orange.opacity(0.1)
        case .completed: return .green.opacity(0.1)
        case .error: return .red.opacity(0.1)
        case .none: return .clear
        }
    }
}
```

### Tracking Active Operations

```swift
protocol StatusTracking: Actor {
    func status(for toolUseId: String) async -> StatusBannerState
    func updateProgress(toolUseId: String, info: ProgressInfo) async
    func startSubagent(toolUseId: String, info: SubagentInfo) async
    func complete(toolUseId: String) async
    func clearAll() async
}

actor CardStatusTracker: StatusTracking {
    /// Map of toolUseId -> StatusBannerState
    private var activeStatuses: [String: StatusBannerState] = [:]

    func status(for toolUseId: String) async -> StatusBannerState {
        activeStatuses[toolUseId] ?? .none
    }

    // Called on StreamEvent.progress
    func updateProgress(toolUseId: String, info: ProgressInfo) async {
        activeStatuses[toolUseId] = .inProgress(info)
    }

    // Called on StreamEvent.subagentStart
    func startSubagent(toolUseId: String, info: SubagentInfo) async {
        activeStatuses[toolUseId] = .subagent(info)
    }

    // Called on StreamEvent.subagentComplete OR toolResult
    func complete(toolUseId: String) async {
        activeStatuses[toolUseId] = .completed
        // Auto-remove after brief delay
        Task {
            try? await Task.sleep(for: .seconds(1))
            activeStatuses.removeValue(forKey: toolUseId)
        }
    }

    // Called on StreamEvent.result (final cleanup)
    func clearAll() async {
        activeStatuses.removeAll()
    }
}
```

### Integration with ChatViewModel

```swift
// In ChatViewModel
let statusTracker: any StatusTracking

// In ChatViewModel+StreamEvents
case .progress(let msg):
    let startTime = Date().addingTimeInterval(-msg.elapsed)
    let info = ProgressInfo(
        toolName: msg.tool,
        detail: msg.detail,
        progress: msg.progress.map { $0 / 100 },
        startTime: startTime
    )
    await statusTracker.updateProgress(toolUseId: msg.id, info: info)

case .subagentStart(let msg):
    let info = SubagentInfo(
        id: msg.id,
        displayName: msg.displayAgentType,
        description: msg.description,
        startTime: .now
    )
    await statusTracker.startSubagent(toolUseId: msg.id, info: info)

case .subagentComplete(let msg):
    await statusTracker.complete(toolUseId: msg.id)

case .toolResult(let msg):
    // Also complete any status for this tool
    await statusTracker.complete(toolUseId: msg.toolUseId)

case .result(let msg):
    // Final cleanup - clear ALL statuses
    await statusTracker.clearAll()
```

### Usage in MessageCardRouter

```swift
struct MessageCardRouter: View {
    let message: ChatMessage
    let statusBanner: StatusBannerState

    var body: some View {
        VStack(spacing: 0) {
            if statusBanner != .none {
                StatusBannerOverlay(state: statusBanner)
            }
            routeToCard()
        }
    }
}
```

## Files to Create

```
CodingBridge/Views/Messages/Components/
└── StatusBannerOverlay.swift

CodingBridge/ViewModels/
└── CardStatusTracker.swift
```

## Files to Modify

| File | Changes |
|------|---------|
| `MessageCardRouter.swift` | Add statusTracker, show overlay |
| `ChatViewModel.swift` | Add cardStatusTracker property |
| `ChatViewModel+StreamEvents.swift` | Update status tracker on events |
| `ChatView.swift` | Pass statusTracker to message list |

## Files to Remove (After Migration)

| File | Replacement |
|------|-------------|
| `CLIBridgeBanners.swift` | StatusBannerOverlay + CardStatusTracker |

Keep `InputQueuedBanner` separate (not per-card, it's session-level).

## Acceptance Criteria

- [ ] StatusBannerState enum created
- [ ] StatusBannerOverlay shows on toolUse cards
- [ ] CardStatusTracker manages active statuses
- [ ] Progress updates show on correct card
- [ ] Subagent status shows on Task tool card
- [ ] **Subagent banner auto-dismisses on complete** (BUG FIX)
- [ ] All statuses clear on final result
- [ ] Completed state shows briefly before removing
- [ ] Uses MessageDesignSystem tokens
- [ ] Files linked in project.pbxproj
- [ ] Build passes

## Testing

```swift
class CardStatusTrackerTests: XCTestCase {
    func testProgressUpdate() async {
        let tracker = CardStatusTracker()
        let info = ProgressInfo(
            toolName: "Bash",
            detail: "Running npm install",
            progress: 0.5,
            startTime: .now.addingTimeInterval(-10)
        )

        await tracker.updateProgress(toolUseId: "tool-123", info: info)
        let status = await tracker.status(for: "tool-123")
        XCTAssertEqual(status, .inProgress(info))
    }

    func testAutoComplete() async {
        let tracker = CardStatusTracker()
        await tracker.startSubagent(toolUseId: "task-456", info: mockSubagentInfo)

        await tracker.complete(toolUseId: "task-456")

        // Should be .completed initially
        let initialStatus = await tracker.status(for: "task-456")
        XCTAssertEqual(initialStatus, .completed)

        // After delay, should be .none
        try? await Task.sleep(for: .seconds(1.5))
        let clearedStatus = await tracker.status(for: "task-456")
        XCTAssertEqual(clearedStatus, .none)
    }

    func testClearAll() async {
        let tracker = CardStatusTracker()
        await tracker.updateProgress(toolUseId: "tool-1", info: mockProgress)
        await tracker.startSubagent(toolUseId: "tool-2", info: mockSubagent)

        await tracker.clearAll()

        let status1 = await tracker.status(for: "tool-1")
        let status2 = await tracker.status(for: "tool-2")
        XCTAssertEqual(status1, .none)
        XCTAssertEqual(status2, .none)
    }
}
```

## Test Examples

TBD. Add XCTest examples before implementation.
