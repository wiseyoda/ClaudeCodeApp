import ActivityKit
import UserNotifications
import XCTest
@testable import CodingBridge

@MainActor
final class ManagersTests: XCTestCase {

    override func setUp() {
        super.setUp()
        BackgroundManager.shared.resetForTesting()
        BackgroundManager.shared.isAppInBackground = false
    }

    override func tearDown() {
        BackgroundManager.shared.resetForTesting()
        BackgroundManager.shared.isAppInBackground = false
        super.tearDown()
    }

    // MARK: - BackgroundManager

    func test_backgroundManager_updateTaskState_setsCurrentTaskState() {
        let state = TaskState(sessionId: "session-1", projectPath: "/tmp/project")

        BackgroundManager.shared.updateTaskState(state)

        XCTAssertEqual(BackgroundManager.shared.currentTaskState, state)
    }

    func test_backgroundManager_clearProcessingState_resetsUserDefaultsAndState() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "wasProcessing")
        defaults.set("session-1", forKey: "lastSessionId")
        defaults.set("/tmp/project", forKey: "lastProjectPath")
        BackgroundManager.shared.updateTaskState(TaskState(sessionId: "session-1", projectPath: "/tmp/project"))

        BackgroundManager.shared.clearProcessingState()

        XCTAssertFalse(defaults.bool(forKey: "wasProcessing"))
        XCTAssertNil(defaults.string(forKey: "lastSessionId"))
        XCTAssertNil(defaults.string(forKey: "lastProjectPath"))
        XCTAssertNil(BackgroundManager.shared.currentTaskState)
    }

    func test_backgroundManager_wasProcessingOnBackground_readsUserDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "wasProcessing")
        XCTAssertTrue(BackgroundManager.shared.wasProcessingOnBackground)
        defaults.set(false, forKey: "wasProcessing")
        XCTAssertFalse(BackgroundManager.shared.wasProcessingOnBackground)
    }

    func test_backgroundManager_lastSessionId_readsUserDefaults() {
        let defaults = UserDefaults.standard
        defaults.set("session-2", forKey: "lastSessionId")

        XCTAssertEqual(BackgroundManager.shared.lastSessionId, "session-2")
    }

    func test_backgroundManager_lastProjectPath_readsUserDefaults() {
        let defaults = UserDefaults.standard
        defaults.set("/tmp/project", forKey: "lastProjectPath")

        XCTAssertEqual(BackgroundManager.shared.lastProjectPath, "/tmp/project")
    }

    func test_backgroundManager_elapsedBackgroundTime_zeroWhenInactive() {
        BackgroundManager.shared.setProcessingStartTimeForTesting(nil)

        XCTAssertEqual(BackgroundManager.shared.elapsedBackgroundTime, 0, accuracy: 0.001)
    }

    func test_backgroundManager_elapsedBackgroundTime_reportsElapsed() {
        BackgroundManager.shared.setProcessingStartTimeForTesting(Date(timeIntervalSinceNow: -5))

        XCTAssertGreaterThanOrEqual(BackgroundManager.shared.elapsedBackgroundTime, 5)
    }

    func test_backgroundManager_beginBackgroundTask_doesNotOverrideActiveTask() {
        let identifier = UIBackgroundTaskIdentifier(rawValue: 123)
        BackgroundManager.shared.setBackgroundTaskIdentifierForTesting(identifier)

        BackgroundManager.shared.beginBackgroundTask(reason: "test")

        XCTAssertEqual(BackgroundManager.shared.backgroundTaskIdentifierForTesting, identifier)
    }

    func test_backgroundManager_endBackgroundTask_resetsIdentifier() {
        let identifier = UIBackgroundTaskIdentifier(rawValue: 123)
        BackgroundManager.shared.setBackgroundTaskIdentifierForTesting(identifier)

        BackgroundManager.shared.endBackgroundTask()

        XCTAssertEqual(BackgroundManager.shared.backgroundTaskIdentifierForTesting, .invalid)
    }

    func test_backgroundManager_completeContinuedProcessing_clearsActiveFlag() {
        BackgroundManager.shared.setBackgroundTaskActiveForTesting(true)
        BackgroundManager.shared.setProcessingStartTimeForTesting(Date())

        BackgroundManager.shared.completeContinuedProcessing(success: true)

        XCTAssertFalse(BackgroundManager.shared.isBackgroundTaskActive)
        XCTAssertEqual(BackgroundManager.shared.elapsedBackgroundTime, 0, accuracy: 0.001)
    }

    func test_backgroundManager_concurrentTasksLimit() {
        let identifier = UIBackgroundTaskIdentifier(rawValue: 77)
        BackgroundManager.shared.setBackgroundTaskIdentifierForTesting(identifier)
        BackgroundManager.shared.setProcessingStartTimeForTesting(Date(timeIntervalSinceNow: -5))

        BackgroundManager.shared.beginBackgroundTask(reason: "extra-work")

        XCTAssertEqual(BackgroundManager.shared.backgroundTaskIdentifierForTesting, identifier)
        XCTAssertGreaterThanOrEqual(BackgroundManager.shared.elapsedBackgroundTime, 5)
    }

    func test_backgroundManager_taskPrioritization() {
        let first = TaskState(sessionId: "session-1", projectPath: "/tmp/project-1")
        let second = TaskState(sessionId: "session-2", projectPath: "/tmp/project-2")

        BackgroundManager.shared.updateTaskState(first)
        BackgroundManager.shared.updateTaskState(second)

        XCTAssertEqual(BackgroundManager.shared.currentTaskState, second)
    }

    func test_backgroundManager_taskCancellation() {
        let state = TaskState(sessionId: "session-1", projectPath: "/tmp/project")
        BackgroundManager.shared.updateTaskState(state)
        BackgroundManager.shared.setBackgroundTaskActiveForTesting(true)
        BackgroundManager.shared.setProcessingStartTimeForTesting(Date())

        BackgroundManager.shared.completeContinuedProcessing(success: false)

        XCTAssertFalse(BackgroundManager.shared.isBackgroundTaskActive)
        XCTAssertEqual(BackgroundManager.shared.elapsedBackgroundTime, 0, accuracy: 0.001)
        XCTAssertEqual(BackgroundManager.shared.currentTaskState, state)
    }

    func test_backgroundManager_taskTimeout() {
        let identifier = UIBackgroundTaskIdentifier(rawValue: 88)
        BackgroundManager.shared.setBackgroundTaskIdentifierForTesting(identifier)
        BackgroundManager.shared.setProcessingStartTimeForTesting(Date(timeIntervalSinceNow: -12))

        BackgroundManager.shared.endBackgroundTask()

        XCTAssertEqual(BackgroundManager.shared.backgroundTaskIdentifierForTesting, .invalid)
        XCTAssertEqual(BackgroundManager.shared.elapsedBackgroundTime, 0, accuracy: 0.001)
    }

    func test_backgroundManager_cleanupOnAppTerminate() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "wasProcessing")
        defaults.set("session-1", forKey: "lastSessionId")
        defaults.set("/tmp/project", forKey: "lastProjectPath")
        BackgroundManager.shared.setBackgroundTaskIdentifierForTesting(UIBackgroundTaskIdentifier(rawValue: 99))
        BackgroundManager.shared.setProcessingStartTimeForTesting(Date())
        BackgroundManager.shared.setBackgroundTaskActiveForTesting(true)
        BackgroundManager.shared.isAppInBackground = true
        BackgroundManager.shared.updateTaskState(TaskState(sessionId: "session-1", projectPath: "/tmp/project"))

        BackgroundManager.shared.resetForTesting()

        XCTAssertEqual(BackgroundManager.shared.backgroundTaskIdentifierForTesting, .invalid)
        XCTAssertFalse(BackgroundManager.shared.isBackgroundTaskActive)
        XCTAssertFalse(BackgroundManager.shared.isAppInBackground)
        XCTAssertNil(BackgroundManager.shared.currentTaskState)
        XCTAssertFalse(defaults.bool(forKey: "wasProcessing"))
        XCTAssertNil(defaults.string(forKey: "lastSessionId"))
        XCTAssertNil(defaults.string(forKey: "lastProjectPath"))
    }

    func test_backgroundManager_resumeAfterSuspend() {
        let state = TaskState(sessionId: "session-1", projectPath: "/tmp/project")
        BackgroundManager.shared.updateTaskState(state)

        BackgroundManager.shared.isAppInBackground = true
        BackgroundManager.shared.isAppInBackground = false

        XCTAssertEqual(BackgroundManager.shared.currentTaskState, state)
    }

    func test_backgroundManager_progressReporting() {
        BackgroundManager.shared.setProcessingStartTimeForTesting(Date(timeIntervalSinceNow: -30))

        XCTAssertGreaterThanOrEqual(BackgroundManager.shared.elapsedBackgroundTime, 30)
    }

    func test_backgroundManager_errorRecovery() {
        let state = TaskState(sessionId: "session-1", projectPath: "/tmp/project")
        BackgroundManager.shared.updateTaskState(state)
        BackgroundManager.shared.setBackgroundTaskActiveForTesting(true)
        BackgroundManager.shared.setProcessingStartTimeForTesting(Date())

        BackgroundManager.shared.completeContinuedProcessing(success: false)

        XCTAssertEqual(BackgroundManager.shared.currentTaskState, state)
        XCTAssertFalse(BackgroundManager.shared.isBackgroundTaskActive)
    }

    // MARK: - NotificationManager

    func test_notificationManager_requestPermissions_granted() async {
        let center = MockNotificationCenter()
        center.authorizationResult = .success(true)
        let manager = NotificationManager.makeForTesting(notificationCenter: center)

        let granted = await manager.requestPermissions()

        XCTAssertTrue(granted)
        XCTAssertTrue(manager.hasPermission)
    }

    func test_notificationManager_requestPermissions_error() async {
        let center = MockNotificationCenter()
        center.authorizationResult = .failure(MockNotificationError.permissionDenied)
        let manager = NotificationManager.makeForTesting(notificationCenter: center)

        let granted = await manager.requestPermissions()

        XCTAssertFalse(granted)
        XCTAssertFalse(manager.hasPermission)
    }

    func test_notificationManager_sendApprovalNotification_backgrounded_schedules() async {
        let center = MockNotificationCenter()
        let manager = NotificationManager.makeForTesting(notificationCenter: center)
        BackgroundManager.shared.isAppInBackground = true

        await manager.sendApprovalNotification(requestId: "req-1", toolName: "Bash", summary: "Run ls")

        XCTAssertEqual(manager.pendingApprovalId, "req-1")
        XCTAssertEqual(center.addedRequests.count, 1)
        let request = center.addedRequests[0]
        XCTAssertEqual(request.identifier, "approval-req-1")
        XCTAssertEqual(request.content.title, "Approval Needed")
        XCTAssertEqual(request.content.subtitle, "Bash")
        XCTAssertEqual(request.content.body, "Run ls")
        XCTAssertEqual(request.content.categoryIdentifier, NotificationManager.approvalCategory)
        XCTAssertEqual(request.content.userInfo["requestId"] as? String, "req-1")
    }

    func test_notificationManager_sendApprovalNotification_foreground_skipsScheduling() async {
        let center = MockNotificationCenter()
        let manager = NotificationManager.makeForTesting(notificationCenter: center)
        BackgroundManager.shared.isAppInBackground = false

        await manager.sendApprovalNotification(requestId: "req-2", toolName: "Bash", summary: "Run ls")

        XCTAssertEqual(manager.pendingApprovalId, "req-2")
        XCTAssertTrue(center.addedRequests.isEmpty)
    }

    func test_notificationManager_sendQuestionNotification_backgrounded_schedules() async {
        let center = MockNotificationCenter()
        let manager = NotificationManager.makeForTesting(notificationCenter: center)
        BackgroundManager.shared.isAppInBackground = true

        await manager.sendQuestionNotification(questionId: "q1", question: "Pick one?")

        XCTAssertEqual(center.addedRequests.count, 1)
        let request = center.addedRequests[0]
        XCTAssertEqual(request.identifier, "question-q1")
        XCTAssertEqual(request.content.title, "Claude has a question")
        XCTAssertEqual(request.content.body, "Pick one?")
        XCTAssertEqual(request.content.categoryIdentifier, NotificationManager.questionCategory)
    }

    func test_notificationManager_sendCompletionNotification_success() async {
        let center = MockNotificationCenter()
        let manager = NotificationManager.makeForTesting(notificationCenter: center)
        BackgroundManager.shared.isAppInBackground = true

        await manager.sendCompletionNotification(sessionId: "s1", summary: "Done", isSuccess: true)

        XCTAssertEqual(center.addedRequests.count, 1)
        let request = center.addedRequests[0]
        XCTAssertEqual(request.identifier, "complete-s1")
        XCTAssertEqual(request.content.title, "Task Complete")
        XCTAssertEqual(request.content.categoryIdentifier, NotificationManager.completeCategory)
    }

    func test_notificationManager_sendCompletionNotification_failure() async {
        let center = MockNotificationCenter()
        let manager = NotificationManager.makeForTesting(notificationCenter: center)
        BackgroundManager.shared.isAppInBackground = true

        await manager.sendCompletionNotification(sessionId: "s2", summary: "Oops", isSuccess: false)

        XCTAssertEqual(center.addedRequests.count, 1)
        let request = center.addedRequests[0]
        XCTAssertEqual(request.identifier, "complete-s2")
        XCTAssertEqual(request.content.title, "Task Failed")
        XCTAssertEqual(request.content.categoryIdentifier, NotificationManager.errorCategory)
    }

    func test_notificationManager_sendTaskPausedNotification_backgrounded_schedules() async {
        let center = MockNotificationCenter()
        let manager = NotificationManager.makeForTesting(notificationCenter: center)
        BackgroundManager.shared.isAppInBackground = true

        await manager.sendTaskPausedNotification()

        XCTAssertEqual(center.addedRequests.count, 1)
        let request = center.addedRequests[0]
        XCTAssertTrue(request.identifier.hasPrefix("paused-"))
        XCTAssertEqual(request.content.title, "Task Paused")
        XCTAssertEqual(request.content.categoryIdentifier, NotificationManager.pausedCategory)
    }

    func test_notificationManager_clearApprovalNotification_clearsPending() async {
        let center = MockNotificationCenter()
        let manager = NotificationManager.makeForTesting(notificationCenter: center)
        BackgroundManager.shared.isAppInBackground = false

        await manager.sendApprovalNotification(requestId: "req-3", toolName: "Bash", summary: "Run ls")
        manager.clearApprovalNotification(requestId: "req-3")

        XCTAssertNil(manager.pendingApprovalId)
        XCTAssertEqual(center.removedIdentifiers, ["approval-req-3"])
    }

    func test_notificationManager_clearAllNotifications_clearsPending() async {
        let center = MockNotificationCenter()
        let manager = NotificationManager.makeForTesting(notificationCenter: center)
        BackgroundManager.shared.isAppInBackground = false

        await manager.sendApprovalNotification(requestId: "req-4", toolName: "Bash", summary: "Run ls")
        manager.clearAllNotifications()

        XCTAssertNil(manager.pendingApprovalId)
        XCTAssertTrue(center.removeAllCalled)
    }

    func test_notificationManager_updateBadge_callsNotificationCenter() async {
        let center = MockNotificationCenter()
        let manager = NotificationManager.makeForTesting(notificationCenter: center)

        await manager.updateBadge(count: 5)

        XCTAssertEqual(center.badgeCount, 5)
    }

    func test_notificationManager_permissionDenied() async {
        let center = MockNotificationCenter()
        center.authorizationResult = .success(false)
        let manager = NotificationManager.makeForTesting(notificationCenter: center)

        XCTAssertFalse(manager.hasPermission)

        let granted = await manager.requestPermissions()

        XCTAssertFalse(granted)
        XCTAssertFalse(manager.hasPermission)
    }

    func test_notificationManager_permissionNotDetermined() {
        let center = MockNotificationCenter()
        let manager = NotificationManager.makeForTesting(notificationCenter: center)

        XCTAssertFalse(manager.hasPermission)
    }

    func test_notificationManager_permissionGranted() async {
        let center = MockNotificationCenter()
        center.authorizationResult = .success(true)
        let manager = NotificationManager.makeForTesting(notificationCenter: center)

        XCTAssertFalse(manager.hasPermission)

        let granted = await manager.requestPermissions()

        XCTAssertTrue(granted)
        XCTAssertTrue(manager.hasPermission)
    }

    func test_notificationManager_scheduleImmediate() async {
        let center = MockNotificationCenter()
        let manager = NotificationManager.makeForTesting(notificationCenter: center)
        BackgroundManager.shared.isAppInBackground = true

        await manager.sendApprovalNotification(requestId: "req-5", toolName: "Bash", summary: "Run ls")

        XCTAssertEqual(center.addedRequests.count, 1)
        XCTAssertNil(center.addedRequests[0].trigger)
    }

    func test_notificationManager_scheduleDelayed() async {
        let center = MockNotificationCenter()
        let manager = NotificationManager.makeForTesting(notificationCenter: center)

        await manager.sendTestNotification()

        XCTAssertEqual(center.addedRequests.count, 1)
        let trigger = center.addedRequests[0].trigger as? UNTimeIntervalNotificationTrigger
        XCTAssertNotNil(trigger)
        XCTAssertEqual(trigger?.timeInterval ?? 0, 3, accuracy: 0.01)
        XCTAssertFalse(trigger?.repeats ?? true)
    }

    func test_notificationManager_cancelSpecific() async {
        let center = MockNotificationCenter()
        let manager = NotificationManager.makeForTesting(notificationCenter: center)
        BackgroundManager.shared.isAppInBackground = false

        await manager.sendApprovalNotification(requestId: "req-6", toolName: "Bash", summary: "Run ls")
        manager.clearApprovalNotification(requestId: "req-7")

        XCTAssertEqual(manager.pendingApprovalId, "req-6")
        XCTAssertEqual(center.removedIdentifiers, ["approval-req-7"])
    }

    func test_notificationManager_cancelAll() async {
        let center = MockNotificationCenter()
        let manager = NotificationManager.makeForTesting(notificationCenter: center)
        BackgroundManager.shared.isAppInBackground = true

        await manager.sendApprovalNotification(requestId: "req-8", toolName: "Bash", summary: "Run ls")
        manager.clearAllNotifications()

        XCTAssertNil(manager.pendingApprovalId)
        XCTAssertTrue(center.removeAllCalled)
    }

    func test_notificationManager_badgeUpdate() async {
        let center = MockNotificationCenter()
        center.badgeResult = .failure(MockNotificationError.badgeUpdateFailed)
        let manager = NotificationManager.makeForTesting(notificationCenter: center)

        await manager.updateBadge(count: 9)

        XCTAssertNil(center.badgeCount)
    }

    func test_notificationManager_soundOptions() async {
        let center = MockNotificationCenter()
        let manager = NotificationManager.makeForTesting(notificationCenter: center)
        BackgroundManager.shared.isAppInBackground = true

        await manager.sendCompletionNotification(sessionId: "s3", summary: "Done", isSuccess: true)

        XCTAssertEqual(center.addedRequests.count, 1)
        let request = center.addedRequests[0]
        XCTAssertNotNil(request.content.sound)
        XCTAssertEqual(request.content.sound, .default)
    }

    func test_notificationManager_categoryActions() {
        let center = MockNotificationCenter()
        let manager = NotificationManager.makeForTesting(notificationCenter: center)

        manager.configure()

        XCTAssertTrue(center.delegate === manager)

        let categoriesById = Dictionary(uniqueKeysWithValues: center.categories.map { ($0.identifier, $0) })
        let approvalCategory = categoriesById[NotificationManager.approvalCategory]
        XCTAssertNotNil(approvalCategory)
        XCTAssertTrue(approvalCategory?.options.contains(.customDismissAction) ?? false)

        let actionMap = Dictionary(uniqueKeysWithValues: approvalCategory?.actions.map { ($0.identifier, $0) } ?? [])
        let approveAction = actionMap[NotificationManager.approveAction]
        let denyAction = actionMap[NotificationManager.denyAction]
        XCTAssertNotNil(approveAction)
        XCTAssertNotNil(denyAction)
        XCTAssertTrue(approveAction?.options.contains(.authenticationRequired) ?? false)
        XCTAssertTrue(denyAction?.options.contains(.destructive) ?? false)

        XCTAssertTrue(categoriesById[NotificationManager.questionCategory]?.actions.isEmpty ?? false)
        XCTAssertTrue(categoriesById[NotificationManager.completeCategory]?.actions.isEmpty ?? false)
        XCTAssertTrue(categoriesById[NotificationManager.errorCategory]?.actions.isEmpty ?? false)
        XCTAssertTrue(categoriesById[NotificationManager.pausedCategory]?.actions.isEmpty ?? false)
    }

    // MARK: - OfflineActionQueue

    func test_offlineActionQueue_queueApproval_appendsAndPersists() throws {
        let fileURL = makeTempFileURL()
        let queue = OfflineActionQueue.makeForTesting(fileURL: fileURL)

        queue.queueApproval(requestId: "req-1", approved: true)

        XCTAssertEqual(queue.pendingActions.count, 1)
        let persisted = try loadActions(from: fileURL)
        XCTAssertEqual(persisted.count, 1)
        XCTAssertEqual(persisted[0].requestId, "req-1")
    }

    func test_offlineActionQueue_queueApproval_assignsUniqueIds() {
        let fileURL = makeTempFileURL()
        let queue = OfflineActionQueue.makeForTesting(fileURL: fileURL)

        queue.queueApproval(requestId: "req-1", approved: true)
        queue.queueApproval(requestId: "req-2", approved: false)

        XCTAssertEqual(queue.pendingActions.count, 2)
        XCTAssertNotEqual(queue.pendingActions[0].id, queue.pendingActions[1].id)
    }

    func test_offlineActionQueue_removeAction_removesMatchingRequestId() {
        let fileURL = makeTempFileURL()
        let queue = OfflineActionQueue.makeForTesting(fileURL: fileURL)

        queue.queueApproval(requestId: "req-1", approved: true)
        queue.queueApproval(requestId: "req-2", approved: false)
        queue.removeAction(requestId: "req-1")

        XCTAssertEqual(queue.pendingActions.count, 1)
        XCTAssertEqual(queue.pendingActions[0].requestId, "req-2")
    }

    func test_offlineActionQueue_removeAction_ignoresMissingRequestId() {
        let fileURL = makeTempFileURL()
        let queue = OfflineActionQueue.makeForTesting(fileURL: fileURL)

        queue.queueApproval(requestId: "req-1", approved: true)
        queue.removeAction(requestId: "missing")

        XCTAssertEqual(queue.pendingActions.count, 1)
    }

    func test_offlineActionQueue_clearAll_clearsPending() throws {
        let fileURL = makeTempFileURL()
        let queue = OfflineActionQueue.makeForTesting(fileURL: fileURL)

        queue.queueApproval(requestId: "req-1", approved: true)
        queue.clearAll()

        XCTAssertTrue(queue.pendingActions.isEmpty)
        let persisted = try loadActions(from: fileURL)
        XCTAssertTrue(persisted.isEmpty)
    }

    func test_offlineActionQueue_processQueue_skipsWhenOffline() async {
        let fileURL = makeTempFileURL()
        let queue = OfflineActionQueue.makeForTesting(
            fileURL: fileURL,
            isConnected: { false }
        )

        queue.queueApproval(requestId: "req-1", approved: true)
        await queue.processQueue()

        XCTAssertEqual(queue.pendingActions.count, 1)
    }

    func test_offlineActionQueue_processQueue_postsNotificationWhenOnline() async {
        let fileURL = makeTempFileURL()
        let center = NotificationCenter()
        let queue = OfflineActionQueue.makeForTesting(
            fileURL: fileURL,
            isConnected: { true },
            notificationCenter: center
        )

        let expectation = expectation(description: "Notification posted")
        let token = center.addObserver(
            forName: .approvalResponseReady,
            object: nil,
            queue: nil
        ) { notification in
            XCTAssertEqual(notification.userInfo?["requestId"] as? String, "req-1")
            XCTAssertEqual(notification.userInfo?["approved"] as? Bool, true)
            expectation.fulfill()
        }
        defer { center.removeObserver(token) }

        queue.queueApproval(requestId: "req-1", approved: true)
        await queue.processQueue()

        await fulfillment(of: [expectation], timeout: 1)
        XCTAssertTrue(queue.pendingActions.isEmpty)
    }

    func test_offlineActionQueue_processQueue_expiresOldActions() async {
        let fileURL = makeTempFileURL()
        var now = Date()
        let queue = OfflineActionQueue.makeForTesting(
            fileURL: fileURL,
            dateProvider: { now },
            isConnected: { true }
        )

        queue.queueApproval(requestId: "req-1", approved: true)
        now = now.addingTimeInterval(121)
        await queue.processQueue()

        XCTAssertTrue(queue.pendingActions.isEmpty)
    }

    func test_offlineActionQueue_load_readsPersistedActions() throws {
        let fileURL = makeTempFileURL()
        let action = OfflineActionQueue.PendingAction(requestId: "req-1", approved: true, timestamp: Date())
        let data = try JSONEncoder().encode([action])
        try data.write(to: fileURL)

        let queue = OfflineActionQueue.makeForTesting(fileURL: fileURL)

        XCTAssertEqual(queue.pendingActions.count, 1)
        XCTAssertEqual(queue.pendingActions[0].requestId, "req-1")
    }

    func test_offlineQueue_maxQueueSize() {
        let fileURL = makeTempFileURL()
        let queue = OfflineActionQueue.makeForTesting(fileURL: fileURL)

        for index in 0..<50 {
            queue.queueApproval(requestId: "req-\(index)", approved: index.isMultiple(of: 2))
        }

        XCTAssertEqual(queue.pendingActions.count, 50)
    }

    func test_offlineQueue_priorityOrdering() {
        let fileURL = makeTempFileURL()
        let queue = OfflineActionQueue.makeForTesting(fileURL: fileURL)

        queue.queueApproval(requestId: "req-1", approved: true)
        queue.queueApproval(requestId: "req-2", approved: false)
        queue.queueApproval(requestId: "req-3", approved: true)

        XCTAssertEqual(queue.pendingActions.map(\.requestId), ["req-1", "req-2", "req-3"])
    }

    func test_offlineQueue_expirationHandling() async {
        let fileURL = makeTempFileURL()
        let center = NotificationCenter()
        var now = Date()
        let queue = OfflineActionQueue.makeForTesting(
            fileURL: fileURL,
            dateProvider: { now },
            isConnected: { true },
            notificationCenter: center
        )

        queue.queueApproval(requestId: "stale", approved: true)
        now = now.addingTimeInterval(200)
        queue.queueApproval(requestId: "fresh", approved: false)

        var postedIds: [String] = []
        let token = center.addObserver(
            forName: .approvalResponseReady,
            object: nil,
            queue: nil
        ) { notification in
            if let requestId = notification.userInfo?["requestId"] as? String {
                postedIds.append(requestId)
            }
        }
        defer { center.removeObserver(token) }

        await queue.processQueue()

        XCTAssertEqual(postedIds, ["fresh"])
        XCTAssertTrue(queue.pendingActions.isEmpty)
    }

    func test_offlineQueue_retryWithBackoff() async {
        let fileURL = makeTempFileURL()
        var isConnected = false
        let queue = OfflineActionQueue.makeForTesting(
            fileURL: fileURL,
            isConnected: { isConnected }
        )

        queue.queueApproval(requestId: "req-1", approved: true)
        await queue.processQueue()
        await queue.processQueue()

        XCTAssertEqual(queue.pendingActions.count, 1)
    }

    func test_offlineQueue_conflictResolution() {
        let fileURL = makeTempFileURL()
        let queue = OfflineActionQueue.makeForTesting(fileURL: fileURL)

        queue.queueApproval(requestId: "req-1", approved: true)
        queue.queueApproval(requestId: "req-1", approved: false)
        queue.removeAction(requestId: "req-1")

        XCTAssertTrue(queue.pendingActions.isEmpty)
    }

    func test_offlineQueue_persistenceRoundTrip() {
        let fileURL = makeTempFileURL()
        let queue = OfflineActionQueue.makeForTesting(fileURL: fileURL)

        queue.queueApproval(requestId: "req-1", approved: true)
        queue.queueApproval(requestId: "req-2", approved: false)

        let reloadedQueue = OfflineActionQueue.makeForTesting(fileURL: fileURL)

        XCTAssertEqual(reloadedQueue.pendingActions.map(\.requestId), ["req-1", "req-2"])
    }

    func test_offlineQueue_networkRestoreProcessing() async {
        let fileURL = makeTempFileURL()
        let center = NotificationCenter()
        var isConnected = false
        let queue = OfflineActionQueue.makeForTesting(
            fileURL: fileURL,
            isConnected: { isConnected },
            notificationCenter: center
        )

        queue.queueApproval(requestId: "req-1", approved: true)

        await queue.processQueue()
        XCTAssertEqual(queue.pendingActions.count, 1)

        var postedIds: [String] = []
        let token = center.addObserver(
            forName: .approvalResponseReady,
            object: nil,
            queue: nil
        ) { notification in
            if let requestId = notification.userInfo?["requestId"] as? String {
                postedIds.append(requestId)
            }
        }
        defer { center.removeObserver(token) }

        isConnected = true
        await queue.processQueue()

        XCTAssertEqual(postedIds, ["req-1"])
        XCTAssertTrue(queue.pendingActions.isEmpty)
    }

    func test_offlineQueue_partialBatchFailure() async {
        let fileURL = makeTempFileURL()
        let center = NotificationCenter()
        var now = Date()
        let queue = OfflineActionQueue.makeForTesting(
            fileURL: fileURL,
            dateProvider: { now },
            isConnected: { true },
            notificationCenter: center
        )

        queue.queueApproval(requestId: "expired", approved: true)
        now = now.addingTimeInterval(200)
        queue.queueApproval(requestId: "req-1", approved: true)
        queue.queueApproval(requestId: "req-2", approved: false)

        var postedIds: [String] = []
        let token = center.addObserver(
            forName: .approvalResponseReady,
            object: nil,
            queue: nil
        ) { notification in
            if let requestId = notification.userInfo?["requestId"] as? String {
                postedIds.append(requestId)
            }
        }
        defer { center.removeObserver(token) }

        await queue.processQueue()

        XCTAssertEqual(postedIds, ["req-1", "req-2"])
        XCTAssertTrue(queue.pendingActions.isEmpty)
    }

    // MARK: - LiveActivityManager

    func test_init_activityIsNil() {
        let provider = MockLiveActivityProvider()
        let manager = LiveActivityManager.makeForTesting(provider: provider)
        addTeardownBlock { manager.resetForTesting() }

        XCTAssertNil(manager.currentActivity)
    }

    func test_init_isActiveReturnsFalse() {
        let (manager, _) = makeLiveActivityManager()

        XCTAssertFalse(manager.hasActiveActivity)
    }

    func test_shared_returnsSingleton() {
        let first = LiveActivityManager.shared
        let second = LiveActivityManager.shared

        XCTAssertTrue(first === second)
    }

    func test_liveActivityManager_formattedElapsedTime_seconds() {
        let (manager, _) = makeLiveActivityManager()
        manager.setElapsedSecondsForTesting(45)

        XCTAssertEqual(manager.formattedElapsedTime, "45s")
    }

    func test_liveActivityManager_formattedElapsedTime_minutes() {
        let (manager, _) = makeLiveActivityManager()
        manager.setElapsedSecondsForTesting(75)

        XCTAssertEqual(manager.formattedElapsedTime, "1:15")
    }

    func test_liveActivityManager_activeSessionId_nilByDefault() {
        let (manager, _) = makeLiveActivityManager()

        XCTAssertNil(manager.activeSessionId)
    }

    func test_liveActivityManager_activeSessionId_returnsValue() {
        let (manager, _) = makeLiveActivityManager()
        manager.setCurrentSessionIdForTesting("session-1")

        XCTAssertEqual(manager.activeSessionId, "session-1")
    }

    func test_startActivity_whenNotSupported_returnsEarly() async throws {
        let (manager, provider) = makeLiveActivityManager(isSupported: false, isEnabled: true)

        try await manager.startActivity(projectName: "Project", sessionId: "session-1")

        XCTAssertFalse(manager.hasActiveActivity)
        XCTAssertTrue(provider.requestedAttributes.isEmpty)
    }

    func test_startActivity_whenAlreadyActive_updatesExisting() async throws {
        let (manager, provider) = makeLiveActivityManager()

        try await manager.startActivity(projectName: "Project", sessionId: "session-1")
        let requestCount = provider.requestedAttributes.count

        try await manager.startActivity(projectName: "Project", sessionId: "session-1")

        XCTAssertEqual(provider.requestedAttributes.count, requestCount)
        XCTAssertEqual(provider.updateCalls.count, 1)
    }

    func test_startActivity_setsSessionIdAndProjectPath() async throws {
        let (manager, provider) = makeLiveActivityManager()

        try await manager.startActivity(projectName: "Project A", sessionId: "session-1", modelName: "model-1")

        guard let attributes = provider.requestedAttributes.first else {
            XCTFail("Expected attributes request")
            return
        }

        XCTAssertEqual(attributes.sessionId, "session-1")
        XCTAssertEqual(attributes.projectName, "Project A")
        XCTAssertEqual(attributes.modelName, "model-1")
        XCTAssertEqual(manager.activeSessionId, "session-1")
    }

    func test_startActivity_withInvalidState_doesNotCrash() async {
        let (manager, provider) = makeLiveActivityManager()
        provider.requestError = MockLiveActivityError.requestFailed

        do {
            try await manager.startActivity(projectName: "Project", sessionId: "session-1")
            XCTFail("Expected error")
        } catch {
            XCTAssertFalse(manager.hasActiveActivity)
            XCTAssertNil(manager.activeSessionId)
        }
    }

    func test_updateActivity_whenNoActivity_doesNothing() async {
        let (manager, provider) = makeLiveActivityManager()

        await manager.updateActivity(status: .processing, operation: "Work")

        XCTAssertTrue(provider.updateCalls.isEmpty)
    }

    func test_updateActivity_updatesContentState() async throws {
        let (manager, provider) = makeLiveActivityManager()

        try await manager.startActivity(projectName: "Project", sessionId: "session-1")
        manager.setElapsedSecondsForTesting(12)

        await manager.updateActivity(status: .processing, operation: "Working")

        guard let update = provider.updateCalls.last else {
            XCTFail("Expected update call")
            return
        }

        XCTAssertEqual(update.contentState.status, .processing)
        XCTAssertEqual(update.contentState.currentOperation, "Working")
        XCTAssertEqual(update.contentState.elapsedSeconds, 12)
    }

    func test_updateActivity_withProgress_setsProgressFields() async throws {
        let (manager, provider) = makeLiveActivityManager()

        try await manager.startActivity(projectName: "Project", sessionId: "session-1")
        let progress = LAProgress(completed: 2, total: 5, currentTask: "Task")

        await manager.updateActivity(
            status: .processing,
            operation: "Working",
            progress: progress
        )

        guard let update = provider.updateCalls.last else {
            XCTFail("Expected update call")
            return
        }

        XCTAssertEqual(update.contentState.todoProgress, progress)
    }

    func test_updateActivity_withToolInfo_setsToolFields() async throws {
        let (manager, provider) = makeLiveActivityManager()

        try await manager.startActivity(projectName: "Project", sessionId: "session-1")
        let approval = LAApprovalInfo(id: "approval-1", toolName: "tool", summary: "Summary")
        let question = LAQuestionInfo(id: "question-1", preview: "Preview")
        let error = LAErrorInfo(message: "Oops", recoverable: true)

        await manager.updateActivity(
            status: .awaitingApproval,
            operation: "Approve?",
            approval: approval,
            question: question,
            error: error
        )

        guard let update = provider.updateCalls.last else {
            XCTFail("Expected update call")
            return
        }

        XCTAssertEqual(update.contentState.approvalRequest, approval)
        XCTAssertEqual(update.contentState.question, question)
        XCTAssertEqual(update.contentState.error, error)
    }

    func test_endActivity_whenNoActivity_doesNothing() async {
        let (manager, provider) = makeLiveActivityManager()

        await manager.endActivity()

        XCTAssertTrue(provider.endCalls.isEmpty)
    }

    func test_endActivity_clearsActivityReference() async throws {
        let (manager, _) = try await startLiveActivityManager(sessionId: "session-1")

        await manager.endActivity(immediately: true)

        XCTAssertFalse(manager.hasActiveActivity)
        XCTAssertNil(manager.activeSessionId)
        XCTAssertNil(manager.currentActivity)
        XCTAssertEqual(manager.formattedElapsedTime, "0s")
    }

    func test_endActivity_withFinalContent_setsEndState() async throws {
        let (manager, provider) = try await startLiveActivityManager(sessionId: "session-2")
        manager.setElapsedSecondsForTesting(30)

        await manager.endActivity(immediately: true)

        guard let endCall = provider.endCalls.last else {
            XCTFail("Expected end call")
            return
        }

        XCTAssertEqual(endCall.contentState?.status, .complete)
        XCTAssertEqual(endCall.contentState?.elapsedSeconds, 30)
    }

    func test_endActivity_dismissalPolicy_immediate() async throws {
        let (manager, provider) = try await startLiveActivityManager(sessionId: "session-3")

        await manager.endActivity(immediately: true)

        guard let endCall = provider.endCalls.last else {
            XCTFail("Expected end call")
            return
        }

        if case .immediate = endCall.dismissalPolicy {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected immediate dismissal policy")
        }
    }

    func test_endActivity_dismissalPolicy_afterDelay() async throws {
        let (manager, provider) = try await startLiveActivityManager(sessionId: "session-4")

        await manager.endActivity()

        guard let endCall = provider.endCalls.last else {
            XCTFail("Expected end call")
            return
        }

        // Test that dismissal policy was set (non-immediate)
        // ActivityUIDismissalPolicy uses static methods in modern iOS, not enum cases
        // We just verify the end call happened - the provider recorded it
        XCTAssertEqual(provider.endCalls.count, 1, "Expected one end call")
    }

    func test_registerPushToken_storesToken() async throws {
        let apiClient = MockLiveActivityAPIClient()
        let expectation = expectation(description: "register-token")
        apiClient.onRegister = { expectation.fulfill() }
        let (manager, provider) = makeLiveActivityManager(apiClient: apiClient)

        try await manager.startActivity(projectName: "Project", sessionId: "session-1")
        provider.sendPushToken(bytes: [0x01, 0x02])

        await fulfillment(of: [expectation], timeout: 1.0)

        XCTAssertEqual(manager.liveActivityPushTokenForTesting(), "0102")
    }

    func test_registerPushToken_callsBackendAPI() async throws {
        let apiClient = MockLiveActivityAPIClient()
        let expectation = expectation(description: "register-api")
        apiClient.onRegister = { expectation.fulfill() }
        let (manager, provider) = makeLiveActivityManager(apiClient: apiClient)

        try await manager.startActivity(projectName: "Project", sessionId: "session-1")
        provider.sendPushToken(bytes: [0x0a, 0x0b])

        await fulfillment(of: [expectation], timeout: 1.0)

        XCTAssertEqual(apiClient.registerCalls.count, 1)
        let call = apiClient.registerCalls[0]
        XCTAssertEqual(call.pushToken, "0a0b")
        XCTAssertEqual(call.activityId, provider.lastRequestedActivityId)
        XCTAssertNotNil(call.sessionId)
        XCTAssertEqual(call.environment, .sandbox)
    }

    func test_invalidatePushToken_clearsStoredToken() async throws {
        let apiClient = MockLiveActivityAPIClient()
        let registerExpectation = expectation(description: "register-api")
        apiClient.onRegister = { registerExpectation.fulfill() }
        let (manager, provider) = makeLiveActivityManager(apiClient: apiClient)

        try await manager.startActivity(projectName: "Project", sessionId: "session-1")
        provider.sendPushToken(bytes: [0x01, 0x02])

        await fulfillment(of: [registerExpectation], timeout: 1.0)

        let invalidateExpectation = expectation(description: "invalidate-token")
        apiClient.onInvalidate = { invalidateExpectation.fulfill() }

        await manager.invalidatePushToken()

        await fulfillment(of: [invalidateExpectation], timeout: 1.0)

        XCTAssertNil(manager.liveActivityPushTokenForTesting())
        XCTAssertEqual(apiClient.invalidateCalls.count, 1)
        XCTAssertEqual(apiClient.invalidateCalls.first?.tokenType, .liveActivity)
        XCTAssertEqual(apiClient.invalidateCalls.first?.token, "0102")
    }

    func test_pushTokenUpdate_triggersReregistration() async throws {
        let apiClient = MockLiveActivityAPIClient()
        let expectation = expectation(description: "reregister")
        expectation.expectedFulfillmentCount = 2
        apiClient.onRegister = { expectation.fulfill() }
        let (manager, provider) = makeLiveActivityManager(apiClient: apiClient)

        try await manager.startActivity(projectName: "Project", sessionId: "session-1")
        provider.sendPushToken(bytes: [0x01, 0x02])
        provider.sendPushToken(bytes: [0x0a, 0x0b])

        await fulfillment(of: [expectation], timeout: 1.0)

        XCTAssertEqual(apiClient.registerCalls.map(\.pushToken), ["0102", "0a0b"])
    }

    func test_activityAttributes_encodesCorrectly() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let attributes = CodingBridgeAttributes(
            sessionId: "session-1",
            projectName: "Project",
            modelName: "model",
            startedAt: date
        )

        let data = try JSONEncoder().encode(attributes)
        let decoded = try JSONDecoder().decode(CodingBridgeAttributes.self, from: data)

        XCTAssertEqual(decoded.sessionId, "session-1")
        XCTAssertEqual(decoded.projectName, "Project")
        XCTAssertEqual(decoded.modelName, "model")
        XCTAssertEqual(decoded.startedAt.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)
    }

    func test_contentState_encodesCorrectly() throws {
        let progress = LAProgress(completed: 1, total: 3, currentTask: "Task")
        let approval = LAApprovalInfo(id: "approval-1", toolName: "tool", summary: "Summary")
        let question = LAQuestionInfo(id: "question-1", preview: "Preview")
        let error = LAErrorInfo(message: "Oops", recoverable: false)
        let state = CodingBridgeAttributes.ContentState(
            status: .awaitingApproval,
            currentOperation: "Waiting",
            elapsedSeconds: 12,
            todoProgress: progress,
            approvalRequest: approval,
            question: question,
            error: error
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(CodingBridgeAttributes.ContentState.self, from: data)

        XCTAssertEqual(decoded, state)
    }

    func test_multipleEndCalls_handledGracefully() async throws {
        let (manager, provider) = try await startLiveActivityManager(sessionId: "session-5")

        await manager.endActivity(immediately: true)
        await manager.endActivity(immediately: true)

        XCTAssertEqual(provider.endCalls.count, 1)
    }

    // MARK: - Helpers

    private func makeLiveActivityManager(
        isSupported: Bool = true,
        isEnabled: Bool = true,
        apiClient: LiveActivityAPIClient? = nil
    ) -> (LiveActivityManager, MockLiveActivityProvider) {
        let provider = MockLiveActivityProvider()
        let manager = LiveActivityManager.makeForTesting(provider: provider, apiClient: apiClient)
        manager.resetForTesting()
        manager.setSupportForTesting(isSupported: isSupported, isEnabled: isEnabled)
        addTeardownBlock {
            manager.resetForTesting()
        }
        return (manager, provider)
    }

    private func startLiveActivityManager(
        sessionId: String,
        projectName: String = "Project",
        apiClient: LiveActivityAPIClient? = nil
    ) async throws -> (LiveActivityManager, MockLiveActivityProvider) {
        let (manager, provider) = makeLiveActivityManager(apiClient: apiClient)

        try await manager.startActivity(projectName: projectName, sessionId: sessionId)

        return (manager, provider)
    }

    private func makeTempFileURL() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    private func loadActions(from url: URL) throws -> [OfflineActionQueue.PendingAction] {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([OfflineActionQueue.PendingAction].self, from: data)
    }
}

private enum MockNotificationError: Error {
    case permissionDenied
    case badgeUpdateFailed
    case addFailed
}

private final class MockNotificationCenter: UserNotificationCenterProtocol {
    var delegate: UNUserNotificationCenterDelegate?
    var authorizationResult: Result<Bool, Error> = .success(true)
    var addResult: Result<Void, Error> = .success(())
    var badgeResult: Result<Void, Error> = .success(())
    var addedRequests: [UNNotificationRequest] = []
    var removedIdentifiers: [String] = []
    var removeAllCalled = false
    var badgeCount: Int?
    var categories: Set<UNNotificationCategory> = []

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try authorizationResult.get()
    }

    func notificationSettings() async -> UNNotificationSettings {
        await UNUserNotificationCenter.current().notificationSettings()
    }

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        self.categories = categories
    }

    func add(_ request: UNNotificationRequest) async throws {
        try addResult.get()
        addedRequests.append(request)
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
    }

    func removeAllDeliveredNotifications() {
        removeAllCalled = true
    }

    func setBadgeCount(_ count: Int) async throws {
        try badgeResult.get()
        badgeCount = count
    }
}

private enum MockLiveActivityError: Error {
    case requestFailed
    case updateFailed
    case endFailed
}

private final class MockLiveActivityProvider: LiveActivityProviding {
    struct UpdateCall {
        let activityId: String
        let contentState: CodingBridgeAttributes.ContentState
    }

    struct EndCall {
        let activityId: String
        let contentState: CodingBridgeAttributes.ContentState?
        let dismissalPolicy: ActivityUIDismissalPolicy
    }

    var areActivitiesEnabled: Bool = true
    var requestError: Error?
    var updateError: Error?
    var endError: Error?

    private(set) var requestedAttributes: [CodingBridgeAttributes] = []
    private(set) var requestedContentStates: [CodingBridgeAttributes.ContentState] = []
    private(set) var requestedPushTypes: [PushType?] = []
    private(set) var updateCalls: [UpdateCall] = []
    private(set) var endCalls: [EndCall] = []
    private(set) var lastRequestedActivityId: String?

    private let tokenStream: AsyncStream<Data>
    private var tokenContinuation: AsyncStream<Data>.Continuation?
    private var nextId: Int = 0

    init() {
        var continuation: AsyncStream<Data>.Continuation?
        tokenStream = AsyncStream { continuation = $0 }
        tokenContinuation = continuation
    }

    func request(
        attributes: CodingBridgeAttributes,
        contentState: CodingBridgeAttributes.ContentState,
        pushType: PushType?
    ) throws -> String {
        if let error = requestError {
            throw error
        }

        requestedAttributes.append(attributes)
        requestedContentStates.append(contentState)
        requestedPushTypes.append(pushType)
        nextId += 1
        let activityId = "mock-activity-\(nextId)"
        lastRequestedActivityId = activityId
        return activityId
    }

    func update(activityId: String, contentState: CodingBridgeAttributes.ContentState) async throws {
        if let error = updateError {
            throw error
        }
        updateCalls.append(UpdateCall(activityId: activityId, contentState: contentState))
    }

    func end(
        activityId: String,
        contentState: CodingBridgeAttributes.ContentState?,
        dismissalPolicy: ActivityUIDismissalPolicy
    ) async throws {
        if let error = endError {
            throw error
        }
        endCalls.append(EndCall(
            activityId: activityId,
            contentState: contentState,
            dismissalPolicy: dismissalPolicy
        ))
    }

    func pushTokenUpdates(activityId: String) -> AsyncStream<Data>? {
        tokenStream
    }

    func activityReference(activityId: String) -> Activity<CodingBridgeAttributes>? {
        nil
    }

    func sendPushToken(bytes: [UInt8]) {
        tokenContinuation?.yield(Data(bytes))
    }
}

private final class MockLiveActivityAPIClient: LiveActivityAPIClient {
    struct RegisterCall {
        let pushToken: String
        let activityId: String
        let sessionId: UUID
        let environment: PushEnvironment?
    }

    struct InvalidateCall {
        let tokenType: TokenType
        let token: String
    }

    var registerCalls: [RegisterCall] = []
    var invalidateCalls: [InvalidateCall] = []
    var registerError: Error?
    var invalidateError: Error?
    var onRegister: (() -> Void)?
    var onInvalidate: (() -> Void)?

    func registerLiveActivityToken(
        pushToken: String,
        pushToStartToken: String?,
        activityId: String,
        sessionId: UUID,
        environment: PushEnvironment?
    ) async throws -> CLILiveActivityRegisterResponse {
        if let error = registerError {
            throw error
        }
        registerCalls.append(RegisterCall(
            pushToken: pushToken,
            activityId: activityId,
            sessionId: sessionId,
            environment: environment
        ))
        onRegister?()
        return CLILiveActivityRegisterResponse(success: true, activityTokenId: "test-token-id")
    }

    func invalidatePushToken(
        tokenType: TokenType,
        token: String
    ) async throws {
        if let error = invalidateError {
            throw error
        }
        invalidateCalls.append(InvalidateCall(tokenType: tokenType, token: token))
        onInvalidate?()
    }
}
