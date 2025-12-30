import BackgroundTasks
import UIKit

/// Central coordinator for background task handling
@MainActor
final class BackgroundManager: ObservableObject {
    static let shared = BackgroundManager()

    // Task identifiers (must match Info.plist and use bundle ID prefix)
    nonisolated static let continuedProcessingTaskId = "com.level.CodingBridge.task.continued-processing"
    nonisolated static let appRefreshTaskId = "com.level.CodingBridge.task.refresh"

    @Published private(set) var isBackgroundTaskActive = false
    @Published var isAppInBackground = false
    @Published private(set) var currentTaskState: TaskState?

    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var processingStartTime: Date?

    // MARK: - Initialization

    private init() {}

    // MARK: - Registration (call once at app launch)

    /// Synchronous registration - must be called from didFinishLaunchingWithOptions
    /// before the app finishes launching. Cannot use async/await here.
    nonisolated func registerBackgroundTasksSync() {
        // App Refresh Task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.appRefreshTaskId,
            using: nil
        ) { [self] task in
            Task { @MainActor in
                await self.handleAppRefreshTask(task as! BGAppRefreshTask)
            }
        }

        // Continued Processing Task (iOS 26+)
        if #available(iOS 26.0, *) {
            BGTaskScheduler.shared.register(
                forTaskWithIdentifier: Self.continuedProcessingTaskId,
                using: nil
            ) { [self] task in
                Task { @MainActor in
                    await self.handleContinuedProcessingTask(task as! BGContinuedProcessingTask)
                }
            }
        }

        // Log on main actor
        Task { @MainActor in
            log.info("[Background] Registered background tasks")
        }
    }

    /// Async version for other contexts (deprecated, use registerBackgroundTasksSync)
    func registerBackgroundTasks() {
        registerBackgroundTasksSync()
    }

    // MARK: - Continued Processing (iOS 26+)

    @available(iOS 26.0, *)
    func requestContinuedProcessing(reason: String) async throws {
        let request = BGContinuedProcessingTaskRequest(
            identifier: Self.continuedProcessingTaskId,
            title: "Claude Task",
            subtitle: reason
        )

        try BGTaskScheduler.shared.submit(request)
        log.info("[Background] Submitted continued processing: \(reason)")
    }

    @available(iOS 26.0, *)
    private func handleContinuedProcessingTask(_ task: BGContinuedProcessingTask) async {
        isBackgroundTaskActive = true
        processingStartTime = Date()

        task.expirationHandler = { [weak self] in
            Task { @MainActor in
                await self?.handleTaskExpiration()
            }
        }

        log.info("[Background] Continued processing task started")
    }

    func completeContinuedProcessing(success: Bool) {
        isBackgroundTaskActive = false
        processingStartTime = nil
        log.info("[Background] Continued processing completed: \(success ? "success" : "failure")")
    }

    // MARK: - App Refresh Task

    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.appRefreshTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes

        do {
            try BGTaskScheduler.shared.submit(request)
            log.debug("[Background] Scheduled app refresh")
        } catch {
            log.error("[Background] Failed to schedule app refresh: \(error)")
        }
    }

    private func handleAppRefreshTask(_ task: BGAppRefreshTask) async {
        // Schedule next refresh
        scheduleAppRefresh()

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        // Check if we have a saved processing state that needs recovery
        if UserDefaults.standard.bool(forKey: "wasProcessing") {
            log.info("[Background] App refresh detected pending processing state")
            // Notify user that task may need attention
            await NotificationManager.shared.sendTaskPausedNotification()
        }

        task.setTaskCompleted(success: true)
    }

    // MARK: - Legacy Background Task (iOS <26 fallback)

    func beginBackgroundTask(reason: String) {
        guard backgroundTask == .invalid else {
            log.debug("[Background] Background task already active")
            return
        }

        processingStartTime = Date()
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: reason) { [weak self] in
            Task { @MainActor in
                await self?.handleTaskExpiration()
            }
        }

        if backgroundTask != .invalid {
            log.info("[Background] Started legacy background task: \(reason)")
        } else {
            log.warning("[Background] Failed to start legacy background task")
        }
    }

    func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }

        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
        processingStartTime = nil
        log.debug("[Background] Ended legacy background task")
    }

    // MARK: - Expiration Handling

    private func handleTaskExpiration() async {
        log.warning("[Background] Background task expiring, saving state")

        // Save current state
        await saveCurrentState()

        // Send notification that task was paused
        await NotificationManager.shared.sendTaskPausedNotification()

        // Clean up
        if #available(iOS 26.0, *) {
            completeContinuedProcessing(success: false)
        }
        endBackgroundTask()
    }

    // MARK: - State Management

    func updateTaskState(_ state: TaskState) {
        currentTaskState = state
    }

    private func saveCurrentState() async {
        // Save pending messages
        await MessageQueuePersistence.shared.save()

        // Save draft input
        DraftInputPersistence.shared.save()

        // Mark that we were processing
        UserDefaults.standard.set(true, forKey: "wasProcessing")

        if let sessionId = currentTaskState?.sessionId {
            UserDefaults.standard.set(sessionId, forKey: "lastSessionId")
        }

        if let projectPath = currentTaskState?.projectPath {
            UserDefaults.standard.set(projectPath, forKey: "lastProjectPath")
        }

        log.info("[Background] Saved current state for recovery")
    }

    func clearProcessingState() {
        UserDefaults.standard.set(false, forKey: "wasProcessing")
        UserDefaults.standard.removeObject(forKey: "lastSessionId")
        UserDefaults.standard.removeObject(forKey: "lastProjectPath")
        currentTaskState = nil
    }

    // MARK: - Recovery

    var wasProcessingOnBackground: Bool {
        UserDefaults.standard.bool(forKey: "wasProcessing")
    }

    var lastSessionId: String? {
        UserDefaults.standard.string(forKey: "lastSessionId")
    }

    var lastProjectPath: String? {
        UserDefaults.standard.string(forKey: "lastProjectPath")
    }

    // MARK: - Elapsed Time

    var elapsedBackgroundTime: TimeInterval {
        guard let start = processingStartTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    var remainingBackgroundTime: TimeInterval {
        UIApplication.shared.backgroundTimeRemaining
    }
}
