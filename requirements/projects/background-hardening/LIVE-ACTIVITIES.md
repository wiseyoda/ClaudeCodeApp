# Live Activities Implementation

> Detailed implementation guide for ActivityKit-based Live Activities in CodingBridge.

## Overview

Live Activities provide glanceable status updates on the Lock Screen and Dynamic Island. For CodingBridge, they show Claude's current task state without requiring users to open the app.

## iOS 26 Updates

iOS 26 brought several improvements to Live Activities:
- Better Dynamic Island animations
- Improved Apple Watch integration (automatic Smart Stack appearance)
- `BGContinuedProcessingTask` integration for background updates
- Enhanced customization options

## Activity Attributes

The `ActivityAttributes` struct defines the static and dynamic data for the Live Activity.

### Shared Framework Approach

Create a shared framework target so both main app and widget extension can use the same types:

```swift
// CodingBridgeShared/CodingBridgeActivityAttributes.swift

import ActivityKit
import SwiftUI

public struct CodingBridgeActivityAttributes: ActivityAttributes {
    // Static content (doesn't change during activity lifetime)
    public var projectName: String
    public var projectPath: String
    public var sessionId: String

    public init(projectName: String, projectPath: String, sessionId: String) {
        self.projectName = projectName
        self.projectPath = projectPath
        self.sessionId = sessionId
    }

    // Dynamic content (changes via updates)
    public struct ContentState: Codable, Hashable {
        public var status: ActivityStatus
        public var currentOperation: String?
        public var elapsedSeconds: Int
        public var todoProgress: TodoProgress?
        public var approvalRequest: ApprovalInfo?

        public init(
            status: ActivityStatus,
            currentOperation: String? = nil,
            elapsedSeconds: Int = 0,
            todoProgress: TodoProgress? = nil,
            approvalRequest: ApprovalInfo? = nil
        ) {
            self.status = status
            self.currentOperation = currentOperation
            self.elapsedSeconds = elapsedSeconds
            self.todoProgress = todoProgress
            self.approvalRequest = approvalRequest
        }
    }
}

// MARK: - Supporting Types

public enum ActivityStatus: String, Codable, Hashable {
    case processing
    case awaitingApproval
    case awaitingAnswer
    case completed
    case error
}

public struct TodoProgress: Codable, Hashable {
    public let completed: Int
    public let total: Int
    public let currentTask: String?

    public init(completed: Int, total: Int, currentTask: String? = nil) {
        self.completed = completed
        self.total = total
        self.currentTask = currentTask
    }

    public var progressText: String {
        "\(completed) of \(total)"
    }

    public var progressFraction: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
}

public struct ApprovalInfo: Codable, Hashable {
    public let requestId: String
    public let toolName: String
    public let summary: String

    public init(requestId: String, toolName: String, summary: String) {
        self.requestId = requestId
        self.toolName = toolName
        self.summary = summary
    }
}
```

## Live Activity UI Views

### Widget Extension Implementation

```swift
// CodingBridgeWidgets/CodingBridgeLiveActivity.swift

import ActivityKit
import WidgetKit
import SwiftUI

struct CodingBridgeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CodingBridgeActivityAttributes.self) { context in
            // Lock Screen / Banner UI
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    StatusIcon(status: context.state.status)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ElapsedTimeView(seconds: context.state.elapsedSeconds)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.projectName)
                        .font(.headline)
                        .lineLimit(1)
                }
            } compactLeading: {
                StatusIcon(status: context.state.status, compact: true)
            } compactTrailing: {
                ElapsedTimeView(seconds: context.state.elapsedSeconds, compact: true)
            } minimal: {
                StatusIcon(status: context.state.status, minimal: true)
            }
        }
    }
}
```

### Lock Screen View

```swift
// CodingBridgeWidgets/Views/LockScreenView.swift

struct LockScreenView: View {
    let context: ActivityViewContext<CodingBridgeActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: Project name + status
            HStack {
                StatusIcon(status: context.state.status)
                Text(context.attributes.projectName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                ElapsedTimeView(seconds: context.state.elapsedSeconds)
            }

            // Current operation or approval request
            if let approval = context.state.approvalRequest {
                ApprovalRequestView(approval: approval)
            } else if let operation = context.state.currentOperation {
                Text(operation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Progress indicator (if TodoWrite was used)
            if let todo = context.state.todoProgress {
                ProgressView(value: todo.progressFraction) {
                    Text(todo.progressText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tint(progressColor(for: context.state.status))
            }
        }
        .padding()
        .activityBackgroundTint(backgroundColor(for: context.state.status))
    }

    private func backgroundColor(for status: ActivityStatus) -> Color {
        switch status {
        case .processing: return .blue.opacity(0.8)
        case .awaitingApproval: return .orange.opacity(0.8)
        case .awaitingAnswer: return .purple.opacity(0.8)
        case .completed: return .green.opacity(0.8)
        case .error: return .red.opacity(0.8)
        }
    }

    private func progressColor(for status: ActivityStatus) -> Color {
        switch status {
        case .awaitingApproval, .awaitingAnswer: return .white
        default: return .white
        }
    }
}
```

### Supporting Views

```swift
// CodingBridgeWidgets/Views/StatusIcon.swift

struct StatusIcon: View {
    let status: ActivityStatus
    var compact: Bool = false
    var minimal: Bool = false

    var body: some View {
        Image(systemName: iconName)
            .font(minimal ? .caption : (compact ? .caption2 : .body))
            .foregroundStyle(iconColor)
            .symbolEffect(.pulse, isActive: status == .processing)
    }

    private var iconName: String {
        switch status {
        case .processing: return "gear"
        case .awaitingApproval: return "hand.raised.fill"
        case .awaitingAnswer: return "questionmark.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        switch status {
        case .processing: return .white
        case .awaitingApproval: return .orange
        case .awaitingAnswer: return .purple
        case .completed: return .green
        case .error: return .red
        }
    }
}

// CodingBridgeWidgets/Views/ElapsedTimeView.swift

struct ElapsedTimeView: View {
    let seconds: Int
    var compact: Bool = false

    var body: some View {
        Text(formattedTime)
            .font(compact ? .caption2 : .caption)
            .monospacedDigit()
            .foregroundStyle(.secondary)
    }

    private var formattedTime: String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

// CodingBridgeWidgets/Views/ApprovalRequestView.swift

struct ApprovalRequestView: View {
    let approval: ApprovalInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(.orange)
                Text("Approval Needed")
                    .font(.subheadline.bold())
            }
            Text(approval.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
```

## LiveActivityManager Implementation

```swift
// CodingBridge/Managers/LiveActivityManager.swift

import ActivityKit
import Foundation

@MainActor
final class LiveActivityManager: ObservableObject {
    @Published private(set) var currentActivity: Activity<CodingBridgeActivityAttributes>?
    @Published private(set) var pushToken: String?

    private var pushTokenTask: Task<Void, Never>?

    // MARK: - Lifecycle

    func startActivity(
        projectName: String,
        projectPath: String,
        sessionId: String,
        initialOperation: String? = nil
    ) async throws {
        // Check if Live Activities are supported
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw LiveActivityError.notSupported
        }

        // End any existing activity
        await endCurrentActivity()

        let attributes = CodingBridgeActivityAttributes(
            projectName: projectName,
            projectPath: projectPath,
            sessionId: sessionId
        )

        let initialState = CodingBridgeActivityAttributes.ContentState(
            status: .processing,
            currentOperation: initialOperation,
            elapsedSeconds: 0
        )

        do {
            // Request push token for remote updates
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: .token  // Enable push updates
            )

            currentActivity = activity

            // Start observing push token updates
            observePushTokenUpdates(for: activity)

            Logger.background.info("Started Live Activity: \(activity.id)")
        } catch {
            Logger.background.error("Failed to start Live Activity: \(error)")
            throw LiveActivityError.startFailed(error)
        }
    }

    func updateActivity(
        status: ActivityStatus,
        operation: String? = nil,
        elapsedSeconds: Int,
        todoProgress: TodoProgress? = nil,
        approvalRequest: ApprovalInfo? = nil
    ) async {
        guard let activity = currentActivity else {
            Logger.background.warning("No active Live Activity to update")
            return
        }

        let newState = CodingBridgeActivityAttributes.ContentState(
            status: status,
            currentOperation: operation,
            elapsedSeconds: elapsedSeconds,
            todoProgress: todoProgress,
            approvalRequest: approvalRequest
        )

        await activity.update(
            ActivityContent(
                state: newState,
                staleDate: Date().addingTimeInterval(300)  // Stale after 5 min
            )
        )

        Logger.background.debug("Updated Live Activity: status=\(status.rawValue)")
    }

    func endActivity(
        finalStatus: ActivityStatus,
        message: String? = nil
    ) async {
        guard let activity = currentActivity else { return }

        let finalState = CodingBridgeActivityAttributes.ContentState(
            status: finalStatus,
            currentOperation: message,
            elapsedSeconds: 0  // Will show final message instead
        )

        // End with final content, dismiss after 15 minutes
        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .after(.now + 900)
        )

        currentActivity = nil
        pushToken = nil
        pushTokenTask?.cancel()
        pushTokenTask = nil

        Logger.background.info("Ended Live Activity")
    }

    // MARK: - Push Token Management

    private func observePushTokenUpdates(for activity: Activity<CodingBridgeActivityAttributes>) {
        pushTokenTask?.cancel()

        pushTokenTask = Task {
            for await tokenData in activity.pushTokenUpdates {
                let tokenString = tokenData.map { String(format: "%02x", $0) }.joined()

                await MainActor.run {
                    let previousToken = self.pushToken
                    self.pushToken = tokenString

                    // Notify backend of token update
                    Task {
                        await self.registerPushToken(
                            token: tokenString,
                            previousToken: previousToken,
                            activityId: activity.id
                        )
                    }
                }

                Logger.background.info("Live Activity push token updated")
            }
        }
    }

    private func registerPushToken(
        token: String,
        previousToken: String?,
        activityId: String
    ) async {
        // Send to backend for push updates
        // Implementation depends on backend API
        do {
            try await PushTokenManager.shared.sendLiveActivityToken(
                token: token,
                previousToken: previousToken,
                activityId: activityId
            )
        } catch {
            Logger.background.error("Failed to register Live Activity push token: \(error)")
        }
    }

    private func endCurrentActivity() async {
        if let activity = currentActivity {
            await activity.end(nil, dismissalPolicy: .immediate)
            currentActivity = nil
            pushToken = nil
        }
    }
}

// MARK: - Errors

enum LiveActivityError: LocalizedError {
    case notSupported
    case startFailed(Error)
    case updateFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "Live Activities are not supported or enabled on this device"
        case .startFailed(let error):
            return "Failed to start Live Activity: \(error.localizedDescription)"
        case .updateFailed(let error):
            return "Failed to update Live Activity: \(error.localizedDescription)"
        }
    }
}
```

## Widget Extension Bundle

```swift
// CodingBridgeWidgets/CodingBridgeWidgets.swift

import WidgetKit
import SwiftUI

@main
struct CodingBridgeWidgets: WidgetBundle {
    var body: some Widget {
        CodingBridgeLiveActivity()
    }
}
```

## Elapsed Time Updates

Since Live Activities have update frequency limits, use a timer-based approach for elapsed time:

```swift
// In LiveActivityManager

private var elapsedTimer: Timer?
private var taskStartTime: Date?

func startElapsedTimeUpdates() {
    taskStartTime = Date()

    // Update every 15 seconds (respects iOS limits)
    elapsedTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
        guard let self = self, let startTime = self.taskStartTime else { return }

        Task { @MainActor in
            let elapsed = Int(Date().timeIntervalSince(startTime))
            // Only update if there's a significant change and we have an activity
            if self.currentActivity != nil {
                await self.updateElapsedTime(elapsed)
            }
        }
    }
}

func stopElapsedTimeUpdates() {
    elapsedTimer?.invalidate()
    elapsedTimer = nil
    taskStartTime = nil
}
```

## Push Notification Updates

For updates when app is suspended, use APNs push notifications:

### APNs Payload Format

```json
{
  "aps": {
    "timestamp": 1234567890,
    "event": "update",
    "content-state": {
      "status": "processing",
      "currentOperation": "Running tests...",
      "elapsedSeconds": 120,
      "todoProgress": {
        "completed": 3,
        "total": 7,
        "currentTask": "Fix authentication bug"
      }
    },
    "stale-date": 1234568190,
    "dismissal-date": 1234571490
  }
}
```

### APNs Headers

```
:method: POST
:path: /3/device/<push-token>
apns-push-type: liveactivity
apns-topic: com.codingbridge.push-type.liveactivity
authorization: bearer <jwt-token>
```

## 8-Hour Timeout Handling

```swift
// In LiveActivityManager

private var activityStartTime: Date?
private let maxActivityDuration: TimeInterval = 3600  // 1 hour (conservative)

func checkActivityTimeout() async {
    guard let startTime = activityStartTime else { return }

    let elapsed = Date().timeIntervalSince(startTime)

    if elapsed > maxActivityDuration {
        Logger.background.warning("Live Activity exceeded 1 hour, converting to notifications")

        // End Live Activity
        await endActivity(
            finalStatus: .processing,
            message: "Task still running - check notifications"
        )

        // Notify user about the switch
        await NotificationManager.shared.sendNotification(
            title: "Long-Running Task",
            body: "Task has been running for over an hour. Updates will continue via notifications.",
            category: .longRunningTask
        )
    }
}
```

## Testing Live Activities

### Simulator Limitations
- Live Activities work in Simulator but with limitations
- Dynamic Island not visible in Simulator (use Lock Screen preview)
- Push token updates require device

### Testing in Xcode
1. Run on device with iOS 16.1+
2. Use Debug > Simulate Push Notification
3. Test with sample payloads

### Debug Helpers

```swift
#if DEBUG
extension LiveActivityManager {
    func debugStartTestActivity() async {
        try? await startActivity(
            projectName: "Test Project",
            projectPath: "/test/path",
            sessionId: "debug-session",
            initialOperation: "Running tests..."
        )
    }

    func debugUpdateWithProgress() async {
        await updateActivity(
            status: .processing,
            operation: "Building project...",
            elapsedSeconds: 45,
            todoProgress: TodoProgress(completed: 2, total: 5, currentTask: "Add unit tests")
        )
    }

    func debugShowApprovalNeeded() async {
        await updateActivity(
            status: .awaitingApproval,
            operation: nil,
            elapsedSeconds: 60,
            approvalRequest: ApprovalInfo(
                requestId: "test-123",
                toolName: "Bash",
                summary: "Run: npm test"
            )
        )
    }
}
#endif
```

## Accessibility

### VoiceOver Support

```swift
// Ensure VoiceOver support in Live Activity views

struct StatusIcon: View {
    // ...

    var body: some View {
        Image(systemName: iconName)
            // ...
            .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        switch status {
        case .processing: return "Processing"
        case .awaitingApproval: return "Approval needed"
        case .awaitingAnswer: return "Question pending"
        case .completed: return "Completed"
        case .error: return "Error occurred"
        }
    }
}
```

### Dynamic Type Support

Live Activity views should scale appropriately with user's preferred text size:

```swift
struct LockScreenView: View {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    let context: ActivityViewContext<CodingBridgeActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: scaledSpacing) {
            HStack {
                StatusIcon(status: context.state.status)
                Text(context.attributes.projectName)
                    .font(.headline)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                Spacer()
                if !dynamicTypeSize.isAccessibilitySize {
                    ElapsedTimeView(seconds: context.state.elapsedSeconds)
                }
            }

            // Stack vertically for accessibility sizes
            if dynamicTypeSize.isAccessibilitySize {
                ElapsedTimeView(seconds: context.state.elapsedSeconds)
            }

            // ... rest of content
        }
        .padding(scaledPadding)
    }

    private var scaledSpacing: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 12 : 8
    }

    private var scaledPadding: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 16 : 12
    }
}
```

### Reduce Motion

Respect user preference for reduced motion:

```swift
struct StatusIcon: View {
    let status: ActivityStatus
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        Image(systemName: iconName)
            .font(.body)
            .foregroundStyle(iconColor)
            // Only animate if user hasn't requested reduced motion
            .symbolEffect(
                .pulse,
                isActive: status == .processing && !reduceMotion
            )
    }
}
```

### Bold Text

Support bold text accessibility setting:

```swift
struct ElapsedTimeView: View {
    let seconds: Int
    @Environment(\.legibilityWeight) var legibilityWeight

    var body: some View {
        Text(formattedTime)
            .font(.caption)
            .fontWeight(legibilityWeight == .bold ? .semibold : .regular)
            .monospacedDigit()
    }
}
```

## Widget Extension Memory Limits

Widget extensions have strict memory limits. Follow these guidelines:

### Memory Budget

| Context | Limit |
|---------|-------|
| Widget extension | ~30 MB |
| Live Activity UI | ~16 MB |
| Shared container I/O | Minimal |

### Best Practices

```swift
// CodingBridgeWidgets/CodingBridgeLiveActivity.swift

struct CodingBridgeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CodingBridgeActivityAttributes.self) { context in
            // GOOD: Lightweight views, no heavy computation
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Keep Dynamic Island views minimal
                // ...
            } compactLeading: {
                // Single icon - very lightweight
                StatusIcon(status: context.state.status, compact: true)
            } compactTrailing: {
                // Simple text
                ElapsedTimeView(seconds: context.state.elapsedSeconds, compact: true)
            } minimal: {
                // Absolute minimum
                StatusIcon(status: context.state.status, minimal: true)
            }
        }
    }
}

// AVOID in widget extension:
// - Large images (use SF Symbols instead)
// - Complex computed properties
// - Excessive nesting
// - Loading data from network
// - Heavy string processing
```

### Shared Container Access

Keep shared container operations lightweight:

```swift
// GOOD: Read small, pre-computed data
struct SharedContainer {
    static func loadTaskState() -> TaskState? {
        guard let url = containerURL?.appendingPathComponent("taskState.json"),
              let data = try? Data(contentsOf: url),
              data.count < 10_000 else {  // Guard against large files
            return nil
        }
        return try? JSONDecoder().decode(TaskState.self, from: data)
    }
}

// BAD: Don't do heavy processing in widget extension
// - Parsing large JSON files
// - Processing message history
// - Computing aggregations
```

### Image Handling

```swift
// GOOD: Use SF Symbols
Image(systemName: "checkmark.circle.fill")
    .foregroundStyle(.green)

// AVOID: Custom images (if needed, keep very small)
// Image("custom-icon")  // May bloat memory

// If custom images are required, use asset catalogs with size variants
// and load the smallest appropriate size
```

### Memory-Safe Fallbacks

```swift
struct LockScreenView: View {
    let context: ActivityViewContext<CodingBridgeActivityAttributes>

    var body: some View {
        // Provide graceful fallback if content state is missing
        if let operation = context.state.currentOperation,
           operation.count < 500 {  // Guard against huge strings
            Text(operation)
                .lineLimit(2)
        } else {
            Text("Processing...")
        }
    }
}
```

## References

- [ActivityKit Documentation](https://developer.apple.com/documentation/activitykit)
- [Human Interface Guidelines - Live Activities](https://developer.apple.com/design/human-interface-guidelines/live-activities)
- [WWDC 2023: Update Live Activities with push notifications](https://developer.apple.com/videos/play/wwdc2023/10185/)
- [WWDC 2024: Broadcast updates to your Live Activities](https://developer.apple.com/videos/play/wwdc2024/10069/)
