# NotificationManager

> Local notification handling with categories and actions.

## Categories

| Category | Purpose | Actions | Sound | Interruption |
|----------|---------|---------|-------|--------------|
| `APPROVAL_REQUEST` | Claude needs permission | Approve, Deny | Default | Time-Sensitive |
| `QUESTION_ASKED` | Claude asked a question | Open App | Default | Time-Sensitive |
| `TASK_COMPLETE` | Task finished | None | Default | Active |
| `TASK_ERROR` | Task failed | Open App | Default | Active |
| `TASK_PAUSED` | Background time expired | Open App | None | Passive |

## Implementation

```swift
// CodingBridge/Managers/NotificationManager.swift

import UserNotifications

@MainActor
final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
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

    // MARK: - Setup

    func configure() {
        UNUserNotificationCenter.current().delegate = self
        configureCategories()
    }

    func requestPermissions() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            hasPermission = granted
            return granted
        } catch {
            return false
        }
    }

    private func configureCategories() {
        let approveAction = UNNotificationAction(
            identifier: Self.approveAction,
            title: "Approve",
            options: [.authenticationRequired]
        )

        let denyAction = UNNotificationAction(
            identifier: Self.denyAction,
            title: "Deny",
            options: [.destructive]
        )

        let approvalCategory = UNNotificationCategory(
            identifier: Self.approvalCategory,
            actions: [approveAction, denyAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // Register all categories
        UNUserNotificationCenter.current().setNotificationCategories([
            approvalCategory,
            // ... other categories
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

    func sendCompletionNotification(sessionId: String, summary: String?, isSuccess: Bool) async {
        let content = UNMutableNotificationContent()
        content.title = isSuccess ? "Task Complete" : "Task Failed"
        content.body = summary ?? (isSuccess ? "Claude finished working" : "An error occurred")
        content.categoryIdentifier = isSuccess ? Self.completeCategory : Self.errorCategory
        content.sound = .default

        await scheduleNotification(id: "complete-\(sessionId)", content: content)
    }

    func sendTaskPausedNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "Task Paused"
        content.body = "Background time expired. Open CodingBridge to continue."
        content.categoryIdentifier = Self.pausedCategory

        await scheduleNotification(id: "paused-\(Date().timeIntervalSince1970)", content: content)
    }

    private func scheduleNotification(id: String, content: UNMutableNotificationContent) async {
        guard BackgroundManager.shared.isAppInBackground else { return }

        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Clear

    func clearApprovalNotification(requestId: String) {
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: ["approval-\(requestId)"]
        )
        if pendingApprovalId == requestId {
            pendingApprovalId = nil
        }
    }

    // MARK: - Delegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        []  // Don't show when app in foreground
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let actionId = response.actionIdentifier

        await MainActor.run {
            handleNotificationAction(actionId: actionId, userInfo: userInfo)
        }
    }

    private func handleNotificationAction(actionId: String, userInfo: [AnyHashable: Any]) {
        guard let requestId = userInfo["requestId"] as? String else { return }

        switch actionId {
        case Self.approveAction:
            handleApprovalAction(requestId: requestId, approved: true)
        case Self.denyAction:
            handleApprovalAction(requestId: requestId, approved: false)
        default:
            break
        }
    }

    private func handleApprovalAction(requestId: String, approved: Bool) {
        clearApprovalNotification(requestId: requestId)

        Task {
            await WebSocketManager.shared.sendApprovalResponse(
                requestId: requestId,
                approved: approved
            )
        }
    }
}
```

## Badge Management

```swift
func updateBadge(count: Int) async {
    try? await UNUserNotificationCenter.current().setBadgeCount(count)
}
```

---
**Prev:** [background-manager](./background-manager.md) | **Next:** [persistence](./persistence.md) | **Index:** [../00-INDEX.md](../00-INDEX.md)
