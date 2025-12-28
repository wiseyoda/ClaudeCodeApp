# BackgroundManager

> Central coordinator for background task handling.

## Purpose

- Register background task identifiers at app launch
- Coordinate between WebSocketManager, LiveActivityManager, NotificationManager
- Handle app lifecycle transitions (foreground <-> background)
- Manage state persistence during backgrounding

## Implementation

```swift
// CodingBridge/Managers/BackgroundManager.swift

import BackgroundTasks
import UIKit

@MainActor
final class BackgroundManager: ObservableObject {
    static let shared = BackgroundManager()

    // Task identifiers (must match Info.plist)
    static let continuedProcessingTaskId = "com.codingbridge.task.continued-processing"
    static let appRefreshTaskId = "com.codingbridge.task.refresh"

    @Published private(set) var isBackgroundTaskActive = false
    @Published var isAppInBackground = false

    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var continuedProcessingTask: BGContinuedProcessingTask?

    // MARK: - Registration (call once at app launch)

    func registerBackgroundTasks() {
        // iOS 26+ Continued Processing Task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.continuedProcessingTaskId,
            using: nil
        ) { task in
            Task { @MainActor in
                await self.handleContinuedProcessingTask(task as! BGContinuedProcessingTask)
            }
        }

        // App Refresh Task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.appRefreshTaskId,
            using: nil
        ) { task in
            Task { @MainActor in
                await self.handleAppRefreshTask(task as! BGAppRefreshTask)
            }
        }

        Logger.background.info("Registered background tasks")
    }

    // MARK: - Continued Processing (iOS 26+)

    func requestContinuedProcessing(reason: String, progress: Progress) async throws {
        let request = BGContinuedProcessingTaskRequest(
            identifier: Self.continuedProcessingTaskId
        )
        request.reason = reason
        request.progress = progress

        try BGTaskScheduler.shared.submit(request)
        Logger.background.info("Submitted continued processing: \(reason)")
    }

    private func handleContinuedProcessingTask(_ task: BGContinuedProcessingTask) async {
        continuedProcessingTask = task
        isBackgroundTaskActive = true

        task.expirationHandler = { [weak self] in
            Task { @MainActor in
                await self?.handleTaskExpiration()
            }
        }
    }

    func completeContinuedProcessing(success: Bool) {
        continuedProcessingTask?.setTaskCompleted(success: success)
        continuedProcessingTask = nil
        isBackgroundTaskActive = false
    }

    // MARK: - App Refresh Task

    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.appRefreshTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleAppRefreshTask(_ task: BGAppRefreshTask) async {
        scheduleAppRefresh()  // Schedule next

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        // Check session status, send notification if needed
        task.setTaskCompleted(success: true)
    }

    // MARK: - Legacy Background Task (iOS <26 fallback)

    func beginBackgroundTask(reason: String) {
        guard backgroundTask == .invalid else { return }

        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: reason) { [weak self] in
            self?.endBackgroundTask()
        }
    }

    func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    // MARK: - Expiration

    private func handleTaskExpiration() async {
        await saveCurrentState()

        await LiveActivityManager.shared.updateActivity(
            status: .processing,
            operation: "Paused - open app to continue",
            elapsedSeconds: 0
        )

        await NotificationManager.shared.sendTaskPausedNotification()
        completeContinuedProcessing(success: false)
    }

    private func saveCurrentState() async {
        await MessageQueuePersistence.shared.save()
        await DraftInputPersistence.shared.save()

        if WebSocketManager.shared.isProcessing {
            UserDefaults.standard.set(true, forKey: "wasProcessing")
            UserDefaults.standard.set(WebSocketManager.shared.currentSessionId, forKey: "lastSessionId")
        }
    }
}
```

## Scene Phase Handling

```swift
// In ContentView or coordinator

.onChange(of: scenePhase) { oldPhase, newPhase in
    switch newPhase {
    case .active:
        BackgroundManager.shared.isAppInBackground = false
        Task { await handleReturnToForeground() }

    case .background:
        BackgroundManager.shared.isAppInBackground = true
        Task { await handleEnterBackground() }

    default: break
    }
}

private func handleEnterBackground() async {
    guard WebSocketManager.shared.isProcessing else {
        BackgroundManager.shared.scheduleAppRefresh()
        return
    }

    // Start Live Activity
    if LiveActivityManager.shared.currentActivity == nil {
        try? await LiveActivityManager.shared.startActivity(...)
    }

    // Request continued processing (iOS 26+)
    if #available(iOS 26.0, *) {
        let progress = Progress(totalUnitCount: 100)
        try? await BackgroundManager.shared.requestContinuedProcessing(
            reason: "Claude is working on your task",
            progress: progress
        )
    } else {
        BackgroundManager.shared.beginBackgroundTask(reason: "Claude task processing")
    }
}

private func handleReturnToForeground() async {
    BackgroundManager.shared.endBackgroundTask()

    if UserDefaults.standard.bool(forKey: "wasProcessing") {
        await WebSocketManager.shared.attachToSession()
    }
}
```

## Testing

Simulate task launch in debugger:

```
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.codingbridge.task.refresh"]
```

---
**Next:** [notification-manager](./notification-manager.md) | **Index:** [../00-INDEX.md](../00-INDEX.md)
