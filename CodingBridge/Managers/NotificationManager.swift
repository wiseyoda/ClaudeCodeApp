import UserNotifications

/// Manages local notifications for background task updates
/// Uses @preconcurrency for UNUserNotificationCenterDelegate to handle Swift 6 concurrency
@MainActor
final class NotificationManager: NSObject, ObservableObject, @preconcurrency UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    // Category identifiers
    static let approvalCategory = "APPROVAL_REQUEST"
    static let questionCategory = "QUESTION_ASKED"
    static let completeCategory = "TASK_COMPLETE"
    static let errorCategory = "TASK_ERROR"
    static let pausedCategory = "TASK_PAUSED"

    // Action identifiers
    static let approveAction = "APPROVE_ACTION"
    static let denyAction = "DENY_ACTION"

    @Published private(set) var hasPermission = false
    @Published private(set) var pendingApprovalId: String?

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - Setup

    func configure() {
        UNUserNotificationCenter.current().delegate = self
        configureCategories()
        log.info("[Notification] Configured notification manager with delegate")
        Task {
            await checkPermissionStatus()
        }
    }

    func requestPermissions() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            hasPermission = granted
            log.info("[Notification] Permission \(granted ? "granted" : "denied")")
            return granted
        } catch {
            log.error("[Notification] Permission request failed: \(error)")
            return false
        }
    }

    private func checkPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        hasPermission = settings.authorizationStatus == .authorized
    }

    private func configureCategories() {
        // Approve action - requires authentication for security
        let approveAction = UNNotificationAction(
            identifier: Self.approveAction,
            title: "Approve",
            options: [.authenticationRequired]
        )

        // Deny action - marked as destructive
        let denyAction = UNNotificationAction(
            identifier: Self.denyAction,
            title: "Deny",
            options: [.destructive]
        )

        // Approval request category with both actions
        let approvalCategory = UNNotificationCategory(
            identifier: Self.approvalCategory,
            actions: [approveAction, denyAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // Question category (just opens app)
        let questionCategory = UNNotificationCategory(
            identifier: Self.questionCategory,
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        // Complete category
        let completeCategory = UNNotificationCategory(
            identifier: Self.completeCategory,
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        // Error category
        let errorCategory = UNNotificationCategory(
            identifier: Self.errorCategory,
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        // Paused category
        let pausedCategory = UNNotificationCategory(
            identifier: Self.pausedCategory,
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            approvalCategory,
            questionCategory,
            completeCategory,
            errorCategory,
            pausedCategory
        ])

    }

    // MARK: - Send Notifications

    func sendApprovalNotification(
        requestId: String,
        toolName: String,
        summary: String
    ) async {
        let content = UNMutableNotificationContent()
        content.title = "Approval Needed"
        content.subtitle = toolName
        content.body = summary
        content.categoryIdentifier = Self.approvalCategory
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.userInfo = ["requestId": requestId, "type": "approval"]

        pendingApprovalId = requestId
        await scheduleNotification(id: "approval-\(requestId)", content: content)
    }

    func sendQuestionNotification(
        questionId: String,
        question: String
    ) async {
        let content = UNMutableNotificationContent()
        content.title = "Claude has a question"
        content.body = question
        content.categoryIdentifier = Self.questionCategory
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.userInfo = ["questionId": questionId, "type": "question"]

        await scheduleNotification(id: "question-\(questionId)", content: content)
    }

    func sendCompletionNotification(
        sessionId: String,
        summary: String?,
        isSuccess: Bool
    ) async {
        let content = UNMutableNotificationContent()
        content.title = isSuccess ? "Task Complete" : "Task Failed"
        content.body = summary ?? (isSuccess ? "Claude finished working" : "An error occurred")
        content.categoryIdentifier = isSuccess ? Self.completeCategory : Self.errorCategory
        content.sound = .default
        content.userInfo = ["sessionId": sessionId, "type": isSuccess ? "complete" : "error"]

        await scheduleNotification(id: "complete-\(sessionId)", content: content)
    }

    func sendTaskPausedNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "Task Paused"
        content.body = "Background time expired. Open CodingBridge to continue."
        content.categoryIdentifier = Self.pausedCategory
        content.userInfo = ["type": "paused"]

        await scheduleNotification(id: "paused-\(Date().timeIntervalSince1970)", content: content)
    }

    /// Test notification - bypasses background check, triggers after 3 seconds
    func sendTestNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "If you see this, notifications are working!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            log.info("[Notification] Test notification scheduled for 3 seconds")
        } catch {
            log.error("[Notification] Test notification failed: \(error)")
        }
    }

    private func scheduleNotification(id: String, content: UNMutableNotificationContent) async {
        // Only show notifications when app is backgrounded
        guard BackgroundManager.shared.isAppInBackground else {
            log.debug("[Notification] Skipped (app in foreground): \(content.title)")
            return
        }

        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)

        do {
            try await UNUserNotificationCenter.current().add(request)
            log.info("[Notification] Scheduled: \(content.title) - \(content.body)")
        } catch {
            log.error("[Notification] Failed to schedule: \(error)")
        }
    }

    // MARK: - Clear Notifications

    func clearApprovalNotification(requestId: String) {
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: ["approval-\(requestId)"]
        )
        if pendingApprovalId == requestId {
            pendingApprovalId = nil
        }
    }

    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        pendingApprovalId = nil
        log.debug("[Notification] Cleared all delivered notifications")
    }

    // MARK: - Badge Management

    func updateBadge(count: Int) async {
        do {
            try await UNUserNotificationCenter.current().setBadgeCount(count)
        } catch {
            log.error("[Notification] Failed to update badge: \(error)")
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Check if app is actually in background (process can be alive but UI backgrounded)
        let isBackground = BackgroundManager.shared.isAppInBackground

        log.info("[Notification] willPresent called, isBackground=\(isBackground), title=\(notification.request.content.title)")

        if isBackground {
            // App is backgrounded but process is alive - show the notification
            return [.banner, .sound, .badge]
        }

        // App is in foreground - suppress notification (user can see the UI)
        return []
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionId = response.actionIdentifier
        let notificationId = response.notification.request.identifier

        log.info("[Notification] didReceive: id=\(notificationId), action=\(actionId)")
        handleNotificationAction(actionId: actionId, userInfo: userInfo)
        completionHandler()
    }

    private func handleNotificationAction(actionId: String, userInfo: [AnyHashable: Any]) {
        guard let requestId = userInfo["requestId"] as? String else { return }

        switch actionId {
        case Self.approveAction:
            log.info("[Notification] Approve: \(requestId.prefix(8))...")
            handleApprovalAction(requestId: requestId, approved: true)
        case Self.denyAction:
            log.info("[Notification] Deny: \(requestId.prefix(8))...")
            handleApprovalAction(requestId: requestId, approved: false)
        default:
            break  // User tapped or dismissed - no action needed
        }
    }

    private func handleApprovalAction(requestId: String, approved: Bool) {
        clearApprovalNotification(requestId: requestId)

        // Queue the approval for when we reconnect
        // This handles the case where the app was terminated
        if !NetworkMonitor.shared.isConnected {
            OfflineActionQueue.shared.queueApproval(requestId: requestId, approved: approved)
            return
        }

        // Send approval response via notification pattern
        // CLIBridgeAdapter (owned by ChatView) observes this notification and handles the response
        Task {
            NotificationCenter.default.post(
                name: .approvalResponseReady,
                object: nil,
                userInfo: ["requestId": requestId, "approved": approved]
            )
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let approvalResponseReady = Notification.Name("approvalResponseReady")
}
