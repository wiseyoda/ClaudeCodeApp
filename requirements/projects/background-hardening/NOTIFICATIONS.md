# Notifications Implementation

> Push and local notification design for CodingBridge.

## Overview

Notifications serve two purposes in CodingBridge:
1. **Inform**: Alert user when Claude completes or needs attention
2. **Act**: Enable approval/denial of permissions from Lock Screen

## Notification Categories

### Category Definitions

| Category | Purpose | Actions | Sound | Interruption Level |
|----------|---------|---------|-------|-------------------|
| `APPROVAL_REQUEST` | Claude needs permission to proceed | Approve, Deny | Default | Time-Sensitive |
| `QUESTION_ASKED` | Claude asked a question (AskUserQuestion tool) | Open App | Default | Time-Sensitive |
| `TASK_COMPLETE` | Task finished successfully | None | Default | Active |
| `TASK_ERROR` | Task failed or connection lost | Open App | Default | Active |
| `TASK_PAUSED` | Background time expired | Open App | None | Passive |
| `SESSION_STATUS` | Periodic status update | None | None | Passive |

### Implementation

```swift
// CodingBridge/Managers/NotificationManager.swift

import UserNotifications
import UIKit

@MainActor
final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    // Category identifiers
    static let approvalCategory = "APPROVAL_REQUEST"
    static let questionCategory = "QUESTION_ASKED"
    static let completeCategory = "TASK_COMPLETE"
    static let errorCategory = "TASK_ERROR"
    static let pausedCategory = "TASK_PAUSED"
    static let statusCategory = "SESSION_STATUS"

    // Action identifiers
    static let approveAction = "APPROVE_ACTION"
    static let denyAction = "DENY_ACTION"
    static let openAction = "OPEN_ACTION"

    @Published private(set) var hasPermission = false
    @Published private(set) var pendingApprovalId: String?

    private override init() {
        super.init()
    }

    // MARK: - Setup

    func configure() {
        UNUserNotificationCenter.current().delegate = self
        configureCategories()
    }

    func requestPermissions() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge, .providesAppNotificationSettings]
            )
            hasPermission = granted
            Logger.notifications.info("Notification permission: \(granted)")
            return granted
        } catch {
            Logger.notifications.error("Failed to request notification permission: \(error)")
            return false
        }
    }

    private func configureCategories() {
        // Approval request category with Approve/Deny actions
        let approveAction = UNNotificationAction(
            identifier: Self.approveAction,
            title: "Approve",
            options: [.authenticationRequired]  // Require unlock
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

        // Question category with Open action
        let openAction = UNNotificationAction(
            identifier: Self.openAction,
            title: "Open App",
            options: [.foreground]
        )

        let questionCategory = UNNotificationCategory(
            identifier: Self.questionCategory,
            actions: [openAction],
            intentIdentifiers: [],
            options: []
        )

        // Other categories (no actions needed)
        let completeCategory = UNNotificationCategory(
            identifier: Self.completeCategory,
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        let errorCategory = UNNotificationCategory(
            identifier: Self.errorCategory,
            actions: [openAction],
            intentIdentifiers: [],
            options: []
        )

        let pausedCategory = UNNotificationCategory(
            identifier: Self.pausedCategory,
            actions: [openAction],
            intentIdentifiers: [],
            options: []
        )

        let statusCategory = UNNotificationCategory(
            identifier: Self.statusCategory,
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            approvalCategory,
            questionCategory,
            completeCategory,
            errorCategory,
            pausedCategory,
            statusCategory
        ])

        Logger.notifications.info("Configured notification categories")
    }

    // MARK: - Sending Notifications

    func sendApprovalNotification(
        requestId: String,
        toolName: String,
        summary: String,
        details: String?
    ) async {
        let content = UNMutableNotificationContent()
        content.title = "Approval Needed"
        content.subtitle = toolName
        content.body = summary
        content.categoryIdentifier = Self.approvalCategory
        content.sound = .default
        content.userInfo = [
            "requestId": requestId,
            "toolName": toolName,
            "type": "approval"
        ]

        // Store pending approval for tracking
        pendingApprovalId = requestId

        await scheduleNotification(
            identifier: "approval-\(requestId)",
            content: content
        )
    }

    func sendQuestionNotification(
        questionId: String,
        question: String
    ) async {
        let content = UNMutableNotificationContent()
        content.title = "Claude has a question"
        content.body = question.prefix(200).description  // Truncate long questions
        content.categoryIdentifier = Self.questionCategory
        content.sound = .default
        content.userInfo = [
            "questionId": questionId,
            "type": "question"
        ]

        await scheduleNotification(
            identifier: "question-\(questionId)",
            content: content
        )
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
        content.userInfo = [
            "sessionId": sessionId,
            "type": isSuccess ? "complete" : "error"
        ]

        await scheduleNotification(
            identifier: "complete-\(sessionId)-\(Date().timeIntervalSince1970)",
            content: content
        )
    }

    func sendTaskPausedNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "Task Paused"
        content.body = "Background time expired. Open CodingBridge to continue."
        content.categoryIdentifier = Self.pausedCategory
        content.userInfo = ["type": "paused"]
        // No sound for paused notification

        await scheduleNotification(
            identifier: "paused-\(Date().timeIntervalSince1970)",
            content: content
        )
    }

    func sendStatusNotification(
        title: String,
        body: String
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = Self.statusCategory
        content.userInfo = ["type": "status"]
        // No sound for status updates

        await scheduleNotification(
            identifier: "status-\(Date().timeIntervalSince1970)",
            content: content
        )
    }

    private func scheduleNotification(
        identifier: String,
        content: UNMutableNotificationContent
    ) async {
        // Don't send if app is in foreground
        guard BackgroundManager.shared.isAppInBackground else {
            Logger.notifications.debug("Skipping notification - app in foreground")
            return
        }

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil  // Deliver immediately
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            Logger.notifications.info("Scheduled notification: \(identifier)")
        } catch {
            Logger.notifications.error("Failed to schedule notification: \(error)")
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
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Called when notification delivered while app in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Don't show notifications when app is in foreground
        // The in-app UI handles these cases
        return []
    }

    /// Called when user interacts with notification
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let actionId = response.actionIdentifier

        Logger.notifications.info("Notification action: \(actionId)")

        await MainActor.run {
            handleNotificationAction(actionId: actionId, userInfo: userInfo)
        }
    }

    private func handleNotificationAction(actionId: String, userInfo: [AnyHashable: Any]) {
        switch actionId {
        case Self.approveAction:
            guard let requestId = userInfo["requestId"] as? String else { return }
            handleApprovalAction(requestId: requestId, approved: true)

        case Self.denyAction:
            guard let requestId = userInfo["requestId"] as? String else { return }
            handleApprovalAction(requestId: requestId, approved: false)

        case Self.openAction, UNNotificationDefaultActionIdentifier:
            // App will open automatically, handle routing if needed
            handleOpenAction(userInfo: userInfo)

        case UNNotificationDismissActionIdentifier:
            // User dismissed notification
            Logger.notifications.debug("Notification dismissed")

        default:
            Logger.notifications.warning("Unknown action: \(actionId)")
        }
    }

    private func handleApprovalAction(requestId: String, approved: Bool) {
        Logger.notifications.info("Approval action: requestId=\(requestId), approved=\(approved)")

        // Clear the notification
        clearApprovalNotification(requestId: requestId)

        // Send approval response via WebSocket
        Task {
            await WebSocketManager.shared.sendApprovalResponse(
                requestId: requestId,
                approved: approved
            )

            // Update Live Activity status
            await LiveActivityManager.shared.updateActivity(
                status: approved ? .processing : .completed,
                operation: approved ? "Continuing..." : "Denied",
                elapsedSeconds: 0
            )
        }
    }

    private func handleOpenAction(userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else { return }

        // Post notification for app to handle routing
        NotificationCenter.default.post(
            name: .notificationTapped,
            object: nil,
            userInfo: ["type": type, "userInfo": userInfo]
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let notificationTapped = Notification.Name("NotificationTapped")
}
```

## App Delegate Integration

```swift
// CodingBridgeApp.swift

import SwiftUI
import UserNotifications

@main
struct CodingBridgeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Configure notification manager early
        NotificationManager.shared.configure()
        BackgroundManager.shared.registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    Task {
                        await NotificationManager.shared.requestPermissions()
                    }
                }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Register for remote notifications
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        Logger.notifications.info("Device push token: \(tokenString)")

        Task {
            await PushTokenManager.shared.handleDeviceToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Logger.notifications.error("Failed to register for remote notifications: \(error)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        // Handle silent push notifications
        Logger.notifications.info("Received remote notification")

        // Check if this is a Live Activity update
        if let aps = userInfo["aps"] as? [String: Any],
           let contentState = aps["content-state"] as? [String: Any] {
            // Live Activity update handled by ActivityKit
            return .newData
        }

        // Handle other push types
        return .noData
    }
}
```

## Push Notification Payload Formats

### Approval Request Push

```json
{
  "aps": {
    "alert": {
      "title": "Approval Needed",
      "subtitle": "Bash",
      "body": "Execute: npm test"
    },
    "sound": "default",
    "category": "APPROVAL_REQUEST",
    "mutable-content": 1
  },
  "requestId": "approval-123",
  "toolName": "Bash",
  "type": "approval"
}
```

### Question Push

```json
{
  "aps": {
    "alert": {
      "title": "Claude has a question",
      "body": "Which database should we use for this feature?"
    },
    "sound": "default",
    "category": "QUESTION_ASKED"
  },
  "questionId": "question-456",
  "type": "question"
}
```

### Task Complete Push

```json
{
  "aps": {
    "alert": {
      "title": "Task Complete",
      "body": "All tests passed successfully"
    },
    "sound": "default",
    "category": "TASK_COMPLETE"
  },
  "sessionId": "session-789",
  "type": "complete"
}
```

### Live Activity Update Push

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
        "currentTask": "Fix authentication"
      }
    },
    "stale-date": 1234568190
  }
}
```

## Handling Notifications in App

```swift
// In ContentView or coordinator

struct ContentView: View {
    @State private var navigateToSession: String?

    var body: some View {
        NavigationStack {
            // ...
        }
        .onReceive(NotificationCenter.default.publisher(for: .notificationTapped)) { notification in
            handleNotificationTap(notification)
        }
    }

    private func handleNotificationTap(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let type = userInfo["type"] as? String else { return }

        switch type {
        case "question":
            // Navigate to session with question
            if let info = userInfo["userInfo"] as? [AnyHashable: Any],
               let sessionId = info["sessionId"] as? String {
                navigateToSession = sessionId
            }

        case "error":
            // Show error details
            // ...

        default:
            break
        }
    }
}
```

## Notification Extensions (Optional Enhancement)

For rich notifications with custom UI:

```swift
// NotificationServiceExtension/NotificationService.swift

import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let bestAttemptContent = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        // Customize notification content if needed
        // e.g., add attachments, modify text

        contentHandler(bestAttemptContent)
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler,
           let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
```

## Badge Management

```swift
// In NotificationManager

func updateBadge(count: Int) async {
    do {
        try await UNUserNotificationCenter.current().setBadgeCount(count)
    } catch {
        Logger.notifications.error("Failed to update badge: \(error)")
    }
}

func clearBadge() async {
    await updateBadge(count: 0)
}
```

## Testing Notifications

### Simulator Testing
- Local notifications work in Simulator
- Push notifications require device or push testing tools

### Testing Push Notifications
1. Use Xcode's Push Notification Simulator (Debug > Simulate Push Notification)
2. Use APNs test tools (e.g., Pusher, PushNotifications)
3. Test from backend with test certificates

### Sample Test Payload File

```json
// test-approval.apns
{
  "Simulator Target Bundle": "com.codingbridge.CodingBridge",
  "aps": {
    "alert": {
      "title": "Approval Needed",
      "subtitle": "Bash",
      "body": "Execute: npm test"
    },
    "sound": "default",
    "category": "APPROVAL_REQUEST"
  },
  "requestId": "test-123",
  "toolName": "Bash",
  "type": "approval"
}
```

## Debug Helpers

```swift
#if DEBUG
extension NotificationManager {
    func debugSendTestApproval() async {
        await sendApprovalNotification(
            requestId: "debug-\(UUID().uuidString.prefix(8))",
            toolName: "Bash",
            summary: "Execute: npm test",
            details: nil
        )
    }

    func debugSendTestCompletion() async {
        await sendCompletionNotification(
            sessionId: "debug-session",
            summary: "All tests passed! 42 tests in 3.2s",
            isSuccess: true
        )
    }

    func debugListPendingNotifications() async {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        Logger.notifications.info("Pending notifications: \(pending.count)")
        for request in pending {
            Logger.notifications.debug("  - \(request.identifier)")
        }
    }
}
#endif
```

## Accessibility

- Notifications automatically support VoiceOver
- Ensure action titles are descriptive
- Consider adding notification sounds for accessibility (with user preference)

## Privacy Considerations

- Never include sensitive data (API keys, passwords) in notification content
- Truncate long messages to avoid exposing too much
- Use `authenticationRequired` for sensitive actions (like approval)

## Interruption Levels (iOS 15+)

Notifications use different interruption levels to respect Focus modes while ensuring important alerts are delivered:

```swift
// In sendApprovalNotification and sendQuestionNotification:
content.interruptionLevel = .timeSensitive  // Breaks through most Focus modes

// In sendCompletionNotification:
content.interruptionLevel = .active  // Standard - respects Focus modes

// In sendStatusNotification:
content.interruptionLevel = .passive  // Silent - never interrupts
```

### Interruption Level Behavior

| Level | Focus Mode Behavior | Use Case |
|-------|--------------------|----|
| `.timeSensitive` | Appears immediately, can be muted per-app | Approval requests, questions |
| `.active` | Respects Focus mode settings | Task completion, errors |
| `.passive` | Never interrupts, appears in Notification Center | Status updates |

**Note:** Critical alerts (`.critical`) require Apple entitlement approval and are reserved for health/safety apps. We use `.timeSensitive` which provides good visibility without requiring special approval.

## Notification Grouping

Group notifications by session to avoid clutter when multiple events occur:

```swift
// In all notification methods, add thread identifier:
content.threadIdentifier = sessionId  // Groups notifications per session

// Optional: Add summary for grouped notifications
content.summaryArgument = projectName
content.summaryArgumentCount = pendingApprovalCount
```

### Summary Text Configuration

```swift
// In configureCategories(), add summary format:
let approvalCategory = UNNotificationCategory(
    identifier: Self.approvalCategory,
    actions: [approveAction, denyAction],
    intentIdentifiers: [],
    options: [.customDismissAction],
    categorySummaryFormat: "%u approval requests for %@"  // "3 approval requests for MyProject"
)
```

## Haptic Feedback

Provide haptic feedback for important notifications when the device is on silent:

```swift
// CodingBridge/Managers/HapticManager.swift

import UIKit

@MainActor
final class HapticManager {
    static let shared = HapticManager()

    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)

    func prepareForNotification() {
        notificationGenerator.prepare()
    }

    func playApprovalNeeded() {
        notificationGenerator.notificationOccurred(.warning)
    }

    func playTaskComplete() {
        notificationGenerator.notificationOccurred(.success)
    }

    func playError() {
        notificationGenerator.notificationOccurred(.error)
    }
}

// Usage in NotificationManager when app is in foreground:
if !BackgroundManager.shared.isAppInBackground {
    HapticManager.shared.playApprovalNeeded()
}
```

## Rate Limiting User Actions

Prevent duplicate approval responses from rapid taps:

```swift
// In NotificationManager

private var recentlyProcessedRequests: Set<String> = []
private let requestProcessingLock = NSLock()

private func handleApprovalAction(requestId: String, approved: Bool) {
    // Prevent duplicate processing
    requestProcessingLock.lock()
    defer { requestProcessingLock.unlock() }

    guard !recentlyProcessedRequests.contains(requestId) else {
        Logger.notifications.warning("Ignoring duplicate approval action for \(requestId)")
        return
    }

    recentlyProcessedRequests.insert(requestId)

    // Clear after 5 seconds to allow retry if needed
    Task {
        try? await Task.sleep(for: .seconds(5))
        requestProcessingLock.lock()
        recentlyProcessedRequests.remove(requestId)
        requestProcessingLock.unlock()
    }

    // Process the approval...
    Logger.notifications.info("Approval action: requestId=\(requestId), approved=\(approved)")
    clearApprovalNotification(requestId: requestId)

    Task {
        await WebSocketManager.shared.sendApprovalResponse(
            requestId: requestId,
            approved: approved
        )
    }
}
```

## Multi-Device Handling

When user has multiple iOS devices (iPhone + iPad), both receive notifications. Handle coordination:

### Problem
1. Both devices receive approval notification
2. User approves on iPhone
3. iPad still shows outdated notification

### Solution

```swift
// When approval is processed, notify backend to clear other devices
func handleApprovalAction(requestId: String, approved: Bool) async {
    // Send approval response
    await WebSocketManager.shared.sendApprovalResponse(
        requestId: requestId,
        approved: approved
    )

    // Request backend to send "clear notification" push to other devices
    try? await APIClient.shared.clearApprovalOnOtherDevices(requestId: requestId)
}

// Handle incoming "clear" push notification
func handleSilentPush(userInfo: [AnyHashable: Any]) {
    if let clearRequestId = userInfo["clearApprovalId"] as? String {
        // Remove the notification locally
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: ["approval-\(clearRequestId)"]
        )

        // Update Live Activity if showing this approval
        Task {
            await LiveActivityManager.shared.clearApprovalDisplay(requestId: clearRequestId)
        }
    }
}
```

### Backend Silent Push Payload

```json
{
  "aps": {
    "content-available": 1
  },
  "clearApprovalId": "approval-123",
  "reason": "approved_on_other_device"
}
```

## Offline Approval Queuing

Handle approvals when network is unavailable:

```swift
// CodingBridge/Managers/OfflineActionQueue.swift

@MainActor
final class OfflineActionQueue: ObservableObject {
    static let shared = OfflineActionQueue()

    struct PendingAction: Codable {
        let id: String
        let type: ActionType
        let requestId: String
        let approved: Bool?
        let timestamp: Date
    }

    enum ActionType: String, Codable {
        case approval
        case question
    }

    @Published var pendingActions: [PendingAction] = []

    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pending-actions.json")
    }

    func queueApproval(requestId: String, approved: Bool) {
        let action = PendingAction(
            id: UUID().uuidString,
            type: .approval,
            requestId: requestId,
            approved: approved,
            timestamp: Date()
        )
        pendingActions.append(action)
        save()

        Logger.notifications.info("Queued offline approval: \(requestId)")
    }

    func processQueue() async {
        guard NetworkMonitor.shared.isConnected else { return }

        for action in pendingActions {
            do {
                switch action.type {
                case .approval:
                    guard let approved = action.approved else { continue }
                    try await WebSocketManager.shared.sendApprovalResponse(
                        requestId: action.requestId,
                        approved: approved
                    )
                case .question:
                    // Handle queued question responses
                    break
                }

                // Remove successfully processed action
                pendingActions.removeAll { $0.id == action.id }
                save()

            } catch {
                Logger.notifications.error("Failed to process queued action: \(error)")
                // Keep in queue for retry
            }
        }
    }

    private func save() { /* Codable encode to fileURL */ }
    private func load() { /* Codable decode from fileURL */ }
}

// In NotificationManager, use queue when offline:
private func handleApprovalAction(requestId: String, approved: Bool) {
    if NetworkMonitor.shared.isConnected {
        Task {
            await WebSocketManager.shared.sendApprovalResponse(
                requestId: requestId,
                approved: approved
            )
        }
    } else {
        OfflineActionQueue.shared.queueApproval(requestId: requestId, approved: approved)

        // Show confirmation that action is queued
        Task {
            await sendLocalNotification(
                title: approved ? "Approval Queued" : "Denial Queued",
                body: "Will be sent when connection is restored",
                category: Self.statusCategory
            )
        }
    }
}

// Process queue when network returns
// In NetworkMonitor.swift:
monitor.pathUpdateHandler = { path in
    if path.status == .satisfied {
        Task {
            await OfflineActionQueue.shared.processQueue()
        }
    }
}
```

## References

- [UNUserNotificationCenter Documentation](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter)
- [Handling Notifications and Notification-Related Actions](https://developer.apple.com/documentation/usernotifications/handling-notifications-and-notification-related-actions)
- [Setting Up a Remote Notification Server](https://developer.apple.com/documentation/usernotifications/setting-up-a-remote-notification-server)
