# Issue 67: Rich Notifications

**Phase:** 8 (iOS 26 Platform)
**Priority:** Medium
**Status:** Not Started
**Depends On:** 54 (Push Notifications)
**Target:** iOS 26.2, Xcode 26.2, Swift 6.2.1

## Goal

Enhance notifications with rich content including images, expandable details, interactive actions, and notification categories for agent completions, errors, and session updates.

## Scope

- In scope:
  - Notification categories with actions
  - Rich notification content (images, expanded text)
  - Notification Service Extension for content modification
  - Notification Content Extension for custom UI
  - Action handling (reply, retry, dismiss)
  - Grouping and threading
- Out of scope:
  - Push notification server (Issue #54)
  - Critical alerts (too intrusive)
  - Time-sensitive notifications (developer tool context)

## Non-goals

- Sound customization
- Notification scheduling beyond immediate
- Live Activity updates (Issue #20)

## Dependencies

- Issue #54 (Push Notifications) for base notification infrastructure

## Touch Set

- Files to create:
  - `NotificationServiceExtension/NotificationService.swift`
  - `NotificationContentExtension/NotificationViewController.swift`
  - `CodingBridge/Services/NotificationCategoryManager.swift`
- Files to modify:
  - `CodingBridge/Managers/NotificationManager.swift`
  - Add extension targets to project

---

## Notification Categories

### Category Definitions

```swift
import UserNotifications

/// Manages notification categories and actions.
struct NotificationCategoryManager {
    /// All notification categories used by the app.
    static let categories: Set<UNNotificationCategory> = [
        agentCompleteCategory,
        agentErrorCategory,
        permissionRequestCategory,
        sessionUpdateCategory,
    ]

    // MARK: - Agent Complete

    static let agentCompleteCategory: UNNotificationCategory = {
        let viewAction = UNNotificationAction(
            identifier: "VIEW_RESULT",
            title: "View Result",
            options: [.foreground]
        )

        let continueAction = UNNotificationAction(
            identifier: "CONTINUE_CHAT",
            title: "Continue Chat",
            options: [.foreground]
        )

        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: [.destructive]
        )

        return UNNotificationCategory(
            identifier: "AGENT_COMPLETE",
            actions: [viewAction, continueAction, dismissAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Agent completed a task",
            categorySummaryFormat: "%u tasks completed",
            options: [.customDismissAction]
        )
    }()

    // MARK: - Agent Error

    static let agentErrorCategory: UNNotificationCategory = {
        let retryAction = UNNotificationAction(
            identifier: "RETRY",
            title: "Retry",
            options: [.foreground]
        )

        let viewErrorAction = UNNotificationAction(
            identifier: "VIEW_ERROR",
            title: "View Details",
            options: [.foreground]
        )

        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: []
        )

        return UNNotificationCategory(
            identifier: "AGENT_ERROR",
            actions: [retryAction, viewErrorAction, dismissAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Agent encountered an error",
            options: []
        )
    }()

    // MARK: - Permission Request

    static let permissionRequestCategory: UNNotificationCategory = {
        let approveAction = UNNotificationAction(
            identifier: "APPROVE",
            title: "Approve",
            options: [.foreground]
        )

        let denyAction = UNNotificationAction(
            identifier: "DENY",
            title: "Deny",
            options: [.destructive]
        )

        let viewAction = UNNotificationAction(
            identifier: "VIEW_DETAILS",
            title: "View Details",
            options: [.foreground]
        )

        return UNNotificationCategory(
            identifier: "PERMISSION_REQUEST",
            actions: [approveAction, denyAction, viewAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Permission required",
            options: [.customDismissAction]
        )
    }()

    // MARK: - Session Update

    static let sessionUpdateCategory: UNNotificationCategory = {
        let openAction = UNNotificationAction(
            identifier: "OPEN_SESSION",
            title: "Open",
            options: [.foreground]
        )

        return UNNotificationCategory(
            identifier: "SESSION_UPDATE",
            actions: [openAction],
            intentIdentifiers: [],
            options: []
        )
    }()

    // MARK: - Registration

    static func registerCategories() {
        UNUserNotificationCenter.current().setNotificationCategories(categories)
    }
}
```

---

## Notification Service Extension

### NotificationService.swift

```swift
import UserNotifications

/// Modifies notification content before display.
class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        // Modify content based on category
        switch request.content.categoryIdentifier {
        case "AGENT_COMPLETE":
            enrichAgentComplete(bestAttemptContent, userInfo: request.content.userInfo)

        case "AGENT_ERROR":
            enrichAgentError(bestAttemptContent, userInfo: request.content.userInfo)

        case "PERMISSION_REQUEST":
            enrichPermissionRequest(bestAttemptContent, userInfo: request.content.userInfo)

        default:
            break
        }

        contentHandler(bestAttemptContent)
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler, let bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    // MARK: - Content Enrichment

    private func enrichAgentComplete(
        _ content: UNMutableNotificationContent,
        userInfo: [AnyHashable: Any]
    ) {
        // Add summary of work done
        if let filesChanged = userInfo["filesChanged"] as? Int {
            content.subtitle = "\(filesChanged) files modified"
        }

        // Add project icon if available
        if let projectName = userInfo["projectName"] as? String {
            content.threadIdentifier = projectName
        }

        // Add code preview attachment
        if let codePreview = userInfo["codePreview"] as? String {
            addCodePreviewAttachment(to: content, code: codePreview)
        }
    }

    private func enrichAgentError(
        _ content: UNMutableNotificationContent,
        userInfo: [AnyHashable: Any]
    ) {
        // Show error type in subtitle
        if let errorType = userInfo["errorType"] as? String {
            content.subtitle = errorType
        }

        // Add error icon
        content.badge = 1
    }

    private func enrichPermissionRequest(
        _ content: UNMutableNotificationContent,
        userInfo: [AnyHashable: Any]
    ) {
        // Show tool name prominently
        if let toolName = userInfo["toolName"] as? String {
            content.title = "Permission: \(toolName)"
        }

        // Add urgency
        content.interruptionLevel = .timeSensitive
    }

    private func addCodePreviewAttachment(
        to content: UNMutableNotificationContent,
        code: String
    ) {
        // Create a thumbnail image of the code
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 100))
        let image = renderer.image { context in
            // Render code preview
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byTruncatingTail

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraphStyle,
            ]

            code.draw(in: CGRect(x: 8, y: 8, width: 284, height: 84), withAttributes: attributes)
        }

        // Save and attach
        if let data = image.pngData(),
           let url = saveAttachment(data: data, filename: "preview.png") {
            if let attachment = try? UNNotificationAttachment(identifier: "code-preview", url: url) {
                content.attachments = [attachment]
            }
        }
    }

    private func saveAttachment(data: Data, filename: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }
}
```

---

## Notification Content Extension

### NotificationViewController.swift

```swift
import UIKit
import UserNotifications
import UserNotificationsUI

/// Custom UI for expanded notifications.
class NotificationViewController: UIViewController, UNNotificationContentExtension {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var contentTextView: UITextView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var actionButton: UIButton!

    var notificationCategory: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    func didReceive(_ notification: UNNotification) {
        let content = notification.request.content
        notificationCategory = content.categoryIdentifier

        titleLabel.text = content.title
        contentTextView.text = content.body

        // Customize based on category
        switch content.categoryIdentifier {
        case "AGENT_COMPLETE":
            setupAgentCompleteUI(userInfo: content.userInfo)

        case "AGENT_ERROR":
            setupAgentErrorUI(userInfo: content.userInfo)

        case "PERMISSION_REQUEST":
            setupPermissionRequestUI(userInfo: content.userInfo)

        default:
            break
        }
    }

    func didReceive(
        _ response: UNNotificationResponse,
        completionHandler completion: @escaping (UNNotificationContentExtensionResponseOption) -> Void
    ) {
        switch response.actionIdentifier {
        case "APPROVE":
            handleApprove(completion: completion)
        case "DENY":
            handleDeny(completion: completion)
        case "RETRY":
            handleRetry(completion: completion)
        default:
            completion(.dismissAndForwardAction)
        }
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground

        contentTextView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        contentTextView.backgroundColor = .secondarySystemBackground
        contentTextView.layer.cornerRadius = 8
    }

    private func setupAgentCompleteUI(userInfo: [AnyHashable: Any]) {
        iconImageView.image = UIImage(systemName: "checkmark.circle.fill")
        iconImageView.tintColor = .systemGreen

        if let summary = userInfo["summary"] as? String {
            contentTextView.text = summary
        }

        actionButton.setTitle("View Result", for: .normal)
    }

    private func setupAgentErrorUI(userInfo: [AnyHashable: Any]) {
        iconImageView.image = UIImage(systemName: "exclamationmark.triangle.fill")
        iconImageView.tintColor = .systemRed

        if let errorMessage = userInfo["errorMessage"] as? String {
            contentTextView.text = errorMessage
        }

        actionButton.setTitle("Retry", for: .normal)
    }

    private func setupPermissionRequestUI(userInfo: [AnyHashable: Any]) {
        iconImageView.image = UIImage(systemName: "lock.shield")
        iconImageView.tintColor = .systemOrange

        if let toolInput = userInfo["toolInput"] as? String {
            contentTextView.text = toolInput
        }

        actionButton.setTitle("Approve", for: .normal)
    }

    // MARK: - Action Handlers

    private func handleApprove(completion: @escaping (UNNotificationContentExtensionResponseOption) -> Void) {
        // Post approval to app
        NotificationCenter.default.post(
            name: .notificationActionApprove,
            object: nil
        )
        completion(.dismiss)
    }

    private func handleDeny(completion: @escaping (UNNotificationContentExtensionResponseOption) -> Void) {
        NotificationCenter.default.post(
            name: .notificationActionDeny,
            object: nil
        )
        completion(.dismiss)
    }

    private func handleRetry(completion: @escaping (UNNotificationContentExtensionResponseOption) -> Void) {
        // Open app to retry
        completion(.dismissAndForwardAction)
    }
}

extension Notification.Name {
    static let notificationActionApprove = Notification.Name("notificationActionApprove")
    static let notificationActionDeny = Notification.Name("notificationActionDeny")
}
```

---

## Notification Manager Updates

### Sending Rich Notifications

```swift
extension NotificationManager {
    /// Send agent completion notification with rich content.
    func sendAgentCompleteNotification(
        projectName: String,
        summary: String,
        filesChanged: Int,
        codePreview: String?
    ) {
        let content = UNMutableNotificationContent()
        content.title = "Task Complete"
        content.body = summary
        content.categoryIdentifier = "AGENT_COMPLETE"
        content.threadIdentifier = projectName
        content.sound = .default

        content.userInfo = [
            "projectName": projectName,
            "summary": summary,
            "filesChanged": filesChanged,
            "codePreview": codePreview as Any,
        ]

        scheduleNotification(content: content, identifier: "agent-complete-\(UUID().uuidString)")
    }

    /// Send agent error notification.
    func sendAgentErrorNotification(
        projectName: String,
        errorType: String,
        errorMessage: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = "Agent Error"
        content.body = errorMessage
        content.categoryIdentifier = "AGENT_ERROR"
        content.threadIdentifier = projectName
        content.sound = .default
        content.badge = 1

        content.userInfo = [
            "projectName": projectName,
            "errorType": errorType,
            "errorMessage": errorMessage,
        ]

        scheduleNotification(content: content, identifier: "agent-error-\(UUID().uuidString)")
    }

    /// Send permission request notification.
    func sendPermissionRequestNotification(
        toolName: String,
        toolInput: String,
        requestId: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = "Permission Required"
        content.body = "Claude wants to use \(toolName)"
        content.categoryIdentifier = "PERMISSION_REQUEST"
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        content.userInfo = [
            "toolName": toolName,
            "toolInput": toolInput,
            "requestId": requestId,
        ]

        scheduleNotification(content: content, identifier: "permission-\(requestId)")
    }

    private func scheduleNotification(content: UNNotificationContent, identifier: String) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Logger.notifications.error("Failed to schedule notification: \(error)")
            }
        }
    }
}
```

---

## Notification Grouping

### Thread Identifiers

```swift
extension NotificationManager {
    /// Group notifications by project.
    func groupByProject(_ projectPath: String) -> String {
        // Use project name as thread identifier
        return URL(fileURLWithPath: projectPath).lastPathComponent
    }

    /// Summary format for grouped notifications.
    static let groupSummaryFormats: [String: String] = [
        "AGENT_COMPLETE": "%u completed tasks",
        "AGENT_ERROR": "%u errors",
        "SESSION_UPDATE": "%u session updates",
    ]
}
```

---

## Edge Cases

- **Notification tapped after session deleted**: Show "session not found" message
- **Permission request expires**: Auto-dismiss notification
- **App in foreground**: Don't show banner, handle in-app
- **Many rapid notifications**: Group and summarize
- **Notification action fails**: Show error in-app on next launch

## Acceptance Criteria

- [ ] Four notification categories defined
- [ ] Notification Service Extension modifies content
- [ ] Notification Content Extension shows custom UI
- [ ] Action buttons work (Approve, Deny, Retry, View)
- [ ] Notifications grouped by project
- [ ] Rich content (images, expanded text) works
- [ ] Builds pass for all extension targets

## Testing

```swift
class NotificationCategoryTests: XCTestCase {
    func testCategoriesRegistered() {
        NotificationCategoryManager.registerCategories()

        let expectation = expectation(description: "categories")

        UNUserNotificationCenter.current().getNotificationCategories { categories in
            XCTAssertEqual(categories.count, 4)
            XCTAssertTrue(categories.contains { $0.identifier == "AGENT_COMPLETE" })
            XCTAssertTrue(categories.contains { $0.identifier == "AGENT_ERROR" })
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
    }

    func testAgentCompleteActions() {
        let category = NotificationCategoryManager.agentCompleteCategory

        XCTAssertEqual(category.actions.count, 3)
        XCTAssertTrue(category.actions.contains { $0.identifier == "VIEW_RESULT" })
        XCTAssertTrue(category.actions.contains { $0.identifier == "CONTINUE_CHAT" })
    }

    func testPermissionRequestUrgency() {
        let category = NotificationCategoryManager.permissionRequestCategory

        // Permission requests should be actionable
        XCTAssertEqual(category.actions.count, 3)
        XCTAssertTrue(category.actions.contains { $0.identifier == "APPROVE" })
        XCTAssertTrue(category.actions.contains { $0.identifier == "DENY" })
    }
}
```
