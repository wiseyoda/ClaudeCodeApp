# Notification Actions

> Approve/Deny from Lock Screen without opening app.

## Action Flow

```
Lock Screen
    ↓ User taps Approve
NotificationManager.userNotificationCenter(didReceive:)
    ↓
handleApprovalAction(requestId, approved: true)
    ↓
WebSocketManager.sendApprovalResponse(requestId, approved)
    ↓
Backend resumes Claude processing
```

## Implementation

```swift
// In NotificationManager

private var recentlyProcessedRequests: Set<String> = []
private let requestProcessingLock = NSLock()

private func handleNotificationAction(actionId: String, userInfo: [AnyHashable: Any]) {
    guard let requestId = userInfo["requestId"] as? String else { return }

    switch actionId {
    case Self.approveAction:
        handleApprovalAction(requestId: requestId, approved: true)

    case Self.denyAction:
        handleApprovalAction(requestId: requestId, approved: false)

    case UNNotificationDefaultActionIdentifier:
        // User tapped notification body - open app
        handleOpenAction(userInfo: userInfo)

    case UNNotificationDismissActionIdentifier:
        // User swiped away
        Logger.notifications.debug("Notification dismissed: \(requestId)")

    default:
        break
    }
}

private func handleApprovalAction(requestId: String, approved: Bool) {
    // Prevent duplicate processing (rapid taps)
    requestProcessingLock.lock()
    defer { requestProcessingLock.unlock() }

    guard !recentlyProcessedRequests.contains(requestId) else {
        Logger.notifications.warning("Ignoring duplicate: \(requestId)")
        return
    }

    recentlyProcessedRequests.insert(requestId)

    // Clear after 5 seconds
    Task {
        try? await Task.sleep(for: .seconds(5))
        requestProcessingLock.lock()
        recentlyProcessedRequests.remove(requestId)
        requestProcessingLock.unlock()
    }

    // Clear notification
    clearApprovalNotification(requestId: requestId)

    // Send response
    if NetworkMonitor.shared.isConnected {
        Task {
            await WebSocketManager.shared.sendApprovalResponse(
                requestId: requestId,
                approved: approved
            )

            // Update Live Activity
            await LiveActivityManager.shared.updateActivity(
                status: approved ? .processing : .completed,
                operation: approved ? "Continuing..." : "Denied",
                elapsedSeconds: 0
            )
        }
    } else {
        // Queue for later
        OfflineActionQueue.shared.queueApproval(requestId: requestId, approved: approved)
    }

    // Haptic feedback
    HapticManager.shared.playApprovalNeeded()
}

private func handleOpenAction(userInfo: [AnyHashable: Any]) {
    NotificationCenter.default.post(
        name: .notificationTapped,
        object: nil,
        userInfo: ["userInfo": userInfo]
    )
}
```

## WebSocket Approval Response

Add to `WebSocketManager`:

```swift
func sendApprovalResponse(requestId: String, approved: Bool) async throws {
    let response = ApprovalResponse(
        requestId: requestId,
        approved: approved
    )

    let data = try JSONEncoder().encode(response)
    try await send(data)
}

struct ApprovalResponse: Codable {
    let type = "approval_response"
    let requestId: String
    let approved: Bool
}
```

## Haptic Feedback

```swift
// CodingBridge/Managers/HapticManager.swift

@MainActor
final class HapticManager {
    static let shared = HapticManager()

    private let notificationGenerator = UINotificationFeedbackGenerator()

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
```

## Authentication Required

Approval requires device unlock:

```swift
let approveAction = UNNotificationAction(
    identifier: Self.approveAction,
    title: "Approve",
    options: [.authenticationRequired]  // <-- Requires Face ID/Touch ID
)
```

---
**Prev:** [push-token-manager](./push-token-manager.md) | **Next:** [backend-api](./backend-api.md) | **Index:** [../00-INDEX.md](../00-INDEX.md)
