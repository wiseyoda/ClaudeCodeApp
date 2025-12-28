# Background Tasks Implementation

> BGTaskScheduler patterns and background execution strategies for CodingBridge.

## Overview

iOS strictly limits background execution to preserve battery and privacy. CodingBridge needs to work within these constraints while keeping Claude's task running and the user informed.

## iOS Background Execution Model

### Default Behavior (Without Background Tasks)
- App has ~30 seconds after backgrounding before suspension
- All timers, network requests, and tasks are paused
- WebSocket connections are closed

### With Background Tasks
- Can request extended execution time
- System decides when/if to grant runtime
- Must complete work efficiently and handle expiration

## iOS 26: BGContinuedProcessingTask

iOS 26 introduces `BGContinuedProcessingTask` - perfect for CodingBridge's use case:

> "Best suited for exports, uploads, and complex processing initiated by explicit user action."

### Key Characteristics
- User-initiated: Triggered by explicit user action (sending a message to Claude)
- Progress UI: System shows progress indicator
- Extended runtime: More generous than standard background tasks
- Interruptible: Must handle expiration gracefully

### Implementation

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

    // MARK: - Registration

    /// Call once at app launch (in CodingBridgeApp.init or didFinishLaunching)
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

        // App Refresh Task (for checking session status)
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

    func requestContinuedProcessing(
        reason: String,
        progress: Progress
    ) async throws {
        let request = BGContinuedProcessingTaskRequest(
            identifier: Self.continuedProcessingTaskId
        )

        // Provide user-visible reason
        request.reason = reason

        // Link progress for system UI
        request.progress = progress

        do {
            try BGTaskScheduler.shared.submit(request)
            Logger.background.info("Submitted continued processing request: \(reason)")
        } catch {
            Logger.background.error("Failed to submit continued processing: \(error)")
            throw BackgroundError.taskSubmissionFailed(error)
        }
    }

    private func handleContinuedProcessingTask(_ task: BGContinuedProcessingTask) async {
        continuedProcessingTask = task
        isBackgroundTaskActive = true

        // Set expiration handler
        task.expirationHandler = { [weak self] in
            Task { @MainActor in
                await self?.handleTaskExpiration()
            }
        }

        Logger.background.info("Started continued processing task")

        // Keep task alive until Claude completes or task expires
        // The actual work continues via WebSocket
        // We just need to keep the task open
    }

    func completeContinuedProcessing(success: Bool) {
        guard let task = continuedProcessingTask else { return }

        task.setTaskCompleted(success: success)
        continuedProcessingTask = nil
        isBackgroundTaskActive = false

        Logger.background.info("Completed continued processing: success=\(success)")
    }

    // MARK: - App Refresh Task

    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.appRefreshTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)  // 15 min minimum

        do {
            try BGTaskScheduler.shared.submit(request)
            Logger.background.debug("Scheduled app refresh")
        } catch {
            Logger.background.error("Failed to schedule app refresh: \(error)")
        }
    }

    private func handleAppRefreshTask(_ task: BGAppRefreshTask) async {
        // Schedule next refresh
        scheduleAppRefresh()

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        // Check if we have an active session that needs attention
        do {
            let sessionStatus = try await checkSessionStatus()

            if sessionStatus.needsUserAction {
                await NotificationManager.shared.sendNotification(
                    title: "Claude needs your attention",
                    body: sessionStatus.message,
                    category: .sessionStatus
                )
            }

            task.setTaskCompleted(success: true)
        } catch {
            Logger.background.error("App refresh failed: \(error)")
            task.setTaskCompleted(success: false)
        }
    }

    // MARK: - Legacy Background Task (iOS <26 fallback)

    func beginBackgroundTask(reason: String) {
        guard backgroundTask == .invalid else { return }

        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: reason) { [weak self] in
            self?.endBackgroundTask()
        }

        Logger.background.info("Started legacy background task: \(reason)")
    }

    func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }

        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid

        Logger.background.info("Ended legacy background task")
    }

    // MARK: - Task Expiration

    private func handleTaskExpiration() async {
        Logger.background.warning("Background task expiring")

        // Save current state
        await saveCurrentState()

        // Update Live Activity to show we're paused
        await LiveActivityManager.shared.updateActivity(
            status: .processing,
            operation: "Paused - open app to continue",
            elapsedSeconds: 0
        )

        // Send notification
        await NotificationManager.shared.sendNotification(
            title: "Task Paused",
            body: "Background time expired. Open CodingBridge to continue.",
            category: .taskPaused
        )

        completeContinuedProcessing(success: false)
    }

    // MARK: - State Management

    private func saveCurrentState() async {
        // Persist message queue
        await MessageQueuePersistence.shared.save()

        // Save draft input
        await DraftInputPersistence.shared.save()

        // Save processing state
        if WebSocketManager.shared.isProcessing {
            UserDefaults.standard.set(true, forKey: "wasProcessing")
            UserDefaults.standard.set(WebSocketManager.shared.currentSessionId, forKey: "lastSessionId")
        }
    }

    private func checkSessionStatus() async throws -> SessionStatus {
        // Call backend API to check if session needs attention
        // Implementation depends on backend
        return SessionStatus(needsUserAction: false, message: "")
    }
}

// MARK: - Supporting Types

enum BackgroundError: LocalizedError {
    case taskSubmissionFailed(Error)
    case sessionCheckFailed(Error)

    var errorDescription: String? {
        switch self {
        case .taskSubmissionFailed(let error):
            return "Failed to submit background task: \(error.localizedDescription)"
        case .sessionCheckFailed(let error):
            return "Failed to check session status: \(error.localizedDescription)"
        }
    }
}

struct SessionStatus {
    let needsUserAction: Bool
    let message: String
}
```

## Scene Phase Handling

```swift
// In CodingBridgeApp.swift or a coordinator view

struct ContentView: View {
    @Environment(\.scenePhase) var scenePhase
    @StateObject private var backgroundManager = BackgroundManager.shared

    var body: some View {
        NavigationStack {
            // ...
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }

    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            backgroundManager.isAppInBackground = false
            // Resume any paused work
            Task {
                await handleReturnToForeground()
            }

        case .inactive:
            // Transitioning - prepare for potential background
            break

        case .background:
            backgroundManager.isAppInBackground = true
            Task {
                await handleEnterBackground()
            }

        @unknown default:
            break
        }
    }

    private func handleEnterBackground() async {
        // Only request extended processing if Claude is actively working
        guard WebSocketManager.shared.isProcessing else {
            backgroundManager.scheduleAppRefresh()
            return
        }

        // Start Live Activity if not already showing
        if LiveActivityManager.shared.currentActivity == nil {
            try? await LiveActivityManager.shared.startActivity(
                projectName: currentProjectName,
                projectPath: currentProjectPath,
                sessionId: currentSessionId
            )
        }

        // Request continued processing (iOS 26+)
        if #available(iOS 26.0, *) {
            let progress = Progress(totalUnitCount: 100)
            progress.completedUnitCount = 0  // Will be updated

            try? await backgroundManager.requestContinuedProcessing(
                reason: "Claude is working on your task",
                progress: progress
            )
        } else {
            // Fallback for iOS <26
            backgroundManager.beginBackgroundTask(reason: "Claude task processing")
        }
    }

    private func handleReturnToForeground() async {
        // End background task if active
        backgroundManager.endBackgroundTask()

        // Check if we need to reattach to session
        if UserDefaults.standard.bool(forKey: "wasProcessing") {
            await WebSocketManager.shared.attachToSession()
        }

        // Update Live Activity or end it
        if !WebSocketManager.shared.isProcessing {
            await LiveActivityManager.shared.endActivity(
                finalStatus: .completed,
                message: nil
            )
        }
    }
}
```

## Progress Tracking for BGContinuedProcessingTask

```swift
// In BackgroundManager

final class TaskProgressTracker {
    let progress: Progress

    init() {
        progress = Progress(totalUnitCount: 100)
    }

    func updateForTodoProgress(_ todoProgress: TodoProgress) {
        let fraction = Double(todoProgress.completed) / Double(todoProgress.total)
        progress.completedUnitCount = Int64(fraction * 100)
    }

    func updateForToolCount(_ count: Int, estimated: Int = 10) {
        let fraction = min(Double(count) / Double(estimated), 0.95)
        progress.completedUnitCount = Int64(fraction * 100)
    }

    func markIndeterminate() {
        progress.totalUnitCount = -1  // Indeterminate
    }

    func markComplete() {
        progress.completedUnitCount = progress.totalUnitCount
    }
}
```

## Info.plist Configuration

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Background Task Identifiers -->
    <key>BGTaskSchedulerPermittedIdentifiers</key>
    <array>
        <string>com.codingbridge.task.continued-processing</string>
        <string>com.codingbridge.task.refresh</string>
    </array>

    <!-- Background Modes -->
    <key>UIBackgroundModes</key>
    <array>
        <string>fetch</string>
        <string>processing</string>
        <string>remote-notification</string>
    </array>
</dict>
</plist>
```

## Testing Background Tasks

### Simulating Task Launch in Debugger

```
# In LLDB while app is running
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.codingbridge.task.refresh"]
```

### Testing Continued Processing

1. Start a Claude task
2. Background the app
3. Verify Live Activity appears
4. Check Console.app for background task logs
5. Verify task completion/expiration handling

### Debug Helpers

```swift
#if DEBUG
extension BackgroundManager {
    func debugSimulateExpiration() async {
        await handleTaskExpiration()
    }

    func debugLogBackgroundTimeRemaining() {
        let remaining = UIApplication.shared.backgroundTimeRemaining
        Logger.background.debug("Background time remaining: \(remaining)s")
    }

    func debugForceScheduleRefresh() {
        scheduleAppRefresh()
        Logger.background.info("Force scheduled app refresh")
    }
}
#endif
```

## Message Queue Persistence

Ensure pending messages survive backgrounding:

```swift
// CodingBridge/Persistence/MessageQueuePersistence.swift

@MainActor
final class MessageQueuePersistence {
    static let shared = MessageQueuePersistence()

    private let fileURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pending-messages.json")
    }()

    func save() async {
        let queue = WebSocketManager.shared.pendingMessages

        guard !queue.isEmpty else {
            // Delete file if queue is empty
            try? FileManager.default.removeItem(at: fileURL)
            return
        }

        do {
            let data = try JSONEncoder().encode(queue)
            try data.write(to: fileURL)
            Logger.background.debug("Saved \(queue.count) pending messages")
        } catch {
            Logger.background.error("Failed to save message queue: \(error)")
        }
    }

    func load() async -> [PendingMessage] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let queue = try JSONDecoder().decode([PendingMessage].self, from: data)
            Logger.background.debug("Loaded \(queue.count) pending messages")
            return queue
        } catch {
            Logger.background.error("Failed to load message queue: \(error)")
            return []
        }
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
```

## Draft Input Persistence

```swift
// CodingBridge/Persistence/DraftInputPersistence.swift

@MainActor
final class DraftInputPersistence {
    static let shared = DraftInputPersistence()

    private let key = "draftInput"
    private let sessionKey = "draftInputSessionId"

    var currentDraft: String {
        get { UserDefaults.standard.string(forKey: key) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    var draftSessionId: String? {
        get { UserDefaults.standard.string(forKey: sessionKey) }
        set { UserDefaults.standard.set(newValue, forKey: sessionKey) }
    }

    func save() async {
        // Already using UserDefaults which persists automatically
        // This method exists for explicit save points
        Logger.background.debug("Draft saved: \(currentDraft.count) chars")
    }

    func loadForSession(_ sessionId: String) -> String? {
        guard draftSessionId == sessionId else {
            return nil
        }
        return currentDraft
    }

    func clear() {
        currentDraft = ""
        draftSessionId = nil
    }
}
```

## Connection Recovery

```swift
// In WebSocketManager - add recovery logic

extension WebSocketManager {
    func handleBackgroundRecovery() async {
        // Load persisted message queue
        let pendingMessages = await MessageQueuePersistence.shared.load()

        if !pendingMessages.isEmpty {
            Logger.background.info("Recovering \(pendingMessages.count) pending messages")

            // Re-queue messages for retry
            for message in pendingMessages {
                messageQueue.append(message)
            }
        }

        // Attempt to reconnect if we were processing
        if UserDefaults.standard.bool(forKey: "wasProcessing") {
            await reconnect()
        }
    }

    func markProcessingComplete() {
        UserDefaults.standard.set(false, forKey: "wasProcessing")
        MessageQueuePersistence.shared.clear()
    }
}
```

## Best Practices

1. **Be Efficient**: Complete work as quickly as possible
2. **Handle Expiration**: Always set an expiration handler
3. **Save State**: Persist important state before suspension
4. **Graceful Degradation**: Work correctly even if background time denied
5. **Test Thoroughly**: Background behavior varies by device state
6. **Respect Battery**: Don't abuse background time for non-essential work

## References

- [WWDC 2025: Finish tasks in the background](https://developer.apple.com/videos/play/wwdc2025/227/)
- [BGTaskScheduler Documentation](https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler)
- [Choosing Background Strategies](https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app)
- [Using background tasks to update your app](https://developer.apple.com/documentation/uikit/using-background-tasks-to-update-your-app)
