# LiveActivityManager

> ActivityKit lifecycle management.

## Implementation

```swift
// CodingBridge/Managers/LiveActivityManager.swift

import ActivityKit

@MainActor
final class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()

    @Published private(set) var currentActivity: Activity<CodingBridgeActivityAttributes>?
    @Published private(set) var pushToken: String?
    @Published private(set) var currentSessionId: String?

    private var pushTokenTask: Task<Void, Never>?
    private var elapsedTimer: Timer?
    private var taskStartTime: Date?

    // MARK: - Lifecycle

    func startActivity(
        projectName: String,
        projectPath: String,
        sessionId: String,
        initialOperation: String? = nil
    ) async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw LiveActivityError.notSupported
        }

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

        let activity = try Activity.request(
            attributes: attributes,
            content: .init(state: initialState, staleDate: nil),
            pushType: .token
        )

        currentActivity = activity
        currentSessionId = sessionId
        taskStartTime = Date()

        observePushTokenUpdates(for: activity)
        startElapsedTimeUpdates()

        Logger.background.info("Started Live Activity: \(activity.id)")
    }

    func updateActivity(
        status: ActivityStatus,
        operation: String? = nil,
        elapsedSeconds: Int,
        todoProgress: TodoProgress? = nil,
        approvalRequest: ApprovalInfo? = nil
    ) async {
        guard let activity = currentActivity else { return }

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
                staleDate: Date().addingTimeInterval(300)
            )
        )
    }

    func endActivity(finalStatus: ActivityStatus, message: String?) async {
        guard let activity = currentActivity else { return }

        let finalState = CodingBridgeActivityAttributes.ContentState(
            status: finalStatus,
            currentOperation: message,
            elapsedSeconds: 0
        )

        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .after(.now + 900)  // 15 min
        )

        cleanup()
        Logger.background.info("Ended Live Activity")
    }

    // MARK: - Push Token

    private func observePushTokenUpdates(for activity: Activity<CodingBridgeActivityAttributes>) {
        pushTokenTask?.cancel()

        pushTokenTask = Task {
            for await tokenData in activity.pushTokenUpdates {
                let tokenString = tokenData.map { String(format: "%02x", $0) }.joined()

                await MainActor.run {
                    let previousToken = self.pushToken
                    self.pushToken = tokenString

                    Task {
                        await self.registerPushToken(token: tokenString, previousToken: previousToken)
                    }
                }
            }
        }
    }

    private func registerPushToken(token: String, previousToken: String?) async {
        try? await PushTokenManager.shared.sendLiveActivityToken(
            token: token,
            previousToken: previousToken,
            activityId: currentActivity?.id ?? ""
        )
    }

    // MARK: - Elapsed Time

    private func startElapsedTimeUpdates() {
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.taskStartTime else { return }

            Task { @MainActor in
                let elapsed = Int(Date().timeIntervalSince(startTime))
                if self.currentActivity != nil {
                    await self.updateElapsedTime(elapsed)
                }
            }
        }
    }

    private func updateElapsedTime(_ seconds: Int) async {
        // Only update elapsed, keep other state
        await updateActivity(status: .processing, elapsedSeconds: seconds)
    }

    // MARK: - Cleanup

    private func cleanup() {
        currentActivity = nil
        currentSessionId = nil
        pushToken = nil
        taskStartTime = nil
        pushTokenTask?.cancel()
        pushTokenTask = nil
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    private func endCurrentActivity() async {
        if let activity = currentActivity {
            await activity.end(nil, dismissalPolicy: .immediate)
            cleanup()
        }
    }
}

// MARK: - Errors

enum LiveActivityError: LocalizedError {
    case notSupported
    case startFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "Live Activities are not supported or enabled"
        case .startFailed(let error):
            return "Failed to start: \(error.localizedDescription)"
        }
    }
}
```

## 1-Hour Timeout

Live Activities expire after 8 hours, but for long tasks, convert to notifications after 1 hour:

```swift
private let maxActivityDuration: TimeInterval = 3600  // 1 hour

func checkActivityTimeout() async {
    guard let startTime = taskStartTime else { return }

    if Date().timeIntervalSince(startTime) > maxActivityDuration {
        await endActivity(
            finalStatus: .processing,
            message: "Task still running - check notifications"
        )

        await NotificationManager.shared.sendNotification(
            title: "Long-Running Task",
            body: "Updates will continue via notifications."
        )
    }
}
```

---
**Prev:** [activity-attributes](./activity-attributes.md) | **Next:** [widget-extension](./widget-extension.md) | **Index:** [../00-INDEX.md](../00-INDEX.md)
