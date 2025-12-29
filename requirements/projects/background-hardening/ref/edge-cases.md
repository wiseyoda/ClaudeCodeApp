# Edge Cases

> Handling unusual scenarios gracefully.

## Force-Quit During Processing

When user force-quits, we lose in-memory state. On next launch:

```swift
func handleColdStart() async {
    if UserDefaults.standard.bool(forKey: "wasProcessing") {
        let sessionId = UserDefaults.standard.string(forKey: "lastSessionId")

        // Show recovery banner
        showRecoveryBanner(sessionId: sessionId)

        // Check session status via API
        if let status = try? await checkSessionStatus(sessionId: sessionId) {
            if status.isStillProcessing {
                showReattachOption(sessionId: sessionId)
            } else if status.needsApproval {
                showPendingApproval(status.approvalRequest)
            }
        }
    }
}
```

## Low Power Mode

```swift
func handleLowPowerModeChange(_ isLowPower: Bool) {
    if isLowPower && !settings.backgroundInLowPowerMode {
        BackgroundManager.shared.endBackgroundTask()

        if BackgroundManager.shared.isAppInBackground {
            Task {
                await NotificationManager.shared.sendNotification(
                    title: "Low Power Mode",
                    body: "Background processing paused to save battery."
                )
            }
        }
    }
}

// Observe
NotificationCenter.default.addObserver(
    forName: .NSProcessInfoPowerStateDidChange,
    object: nil,
    queue: .main
) { _ in
    handleLowPowerModeChange(ProcessInfo.processInfo.isLowPowerModeEnabled)
}
```

## Notification Permission Denied

```swift
func handleNotificationPermissionDenied() {
    UserDefaults.standard.set(true, forKey: "missedNotificationsWhileBackgrounded")

    // On foreground return
    if UserDefaults.standard.bool(forKey: "missedNotificationsWhileBackgrounded") {
        showMissedNotificationsBanner()
        UserDefaults.standard.set(false, forKey: "missedNotificationsWhileBackgrounded")
    }
}
```

## Live Activities Disabled

```swift
func checkLiveActivityAvailability() -> LiveActivityStatus {
    let authInfo = ActivityAuthorizationInfo()

    if !authInfo.areActivitiesEnabled {
        return .disabledByUser  // Disabled in iOS Settings
    }

    if !settings.enableLiveActivities {
        return .disabledInApp   // Disabled in app settings
    }

    return .available
}
```

## Approval Timeout (60 seconds)

```swift
// Handle timeout event from WebSocket
case "approval_timeout":
    let requestId = data["requestId"] as? String ?? ""

    await NotificationManager.shared.clearApprovalNotification(requestId: requestId)

    await LiveActivityManager.shared.updateActivity(
        status: .processing,
        operation: "Approval timed out - Claude continued",
        elapsedSeconds: currentElapsed
    )

    BackgroundManager.shared.pendingApprovals.removeAll { $0.id == requestId }
```

## Network Loss While Backgrounded

```swift
private func handleNetworkLoss() async {
    await LiveActivityManager.shared.updateActivity(
        status: .processing,
        operation: "Waiting for connection...",
        elapsedSeconds: currentElapsedSeconds
    )

    // Wait 30 seconds before notifying
    Task {
        try await Task.sleep(for: .seconds(30))
        if !NetworkMonitor.shared.isConnected {
            await NotificationManager.shared.sendNotification(
                title: "Connection Lost",
                body: "Task will resume when connected."
            )
        }
    }
}
```

## Multi-Session Handling

iOS allows only 1-2 Live Activities per app:

```swift
// Only most recently active session gets Live Activity
func switchLiveActivityToSession(_ newSessionId: String) async {
    await LiveActivityManager.shared.endCurrentActivity()
    try? await LiveActivityManager.shared.startActivity(for: newSessionId)
}

// Other sessions use notifications only
func handleApprovalRequest(_ request: ApprovalRequest, sessionId: String) async {
    if sessionId == LiveActivityManager.shared.currentSessionId {
        await LiveActivityManager.shared.updateForApproval(request)
    }

    // Always send notification
    await NotificationManager.shared.sendApprovalNotification(for: request)
}
```

## Device Restart

Same as force-quit - check `wasProcessing` on next launch.

---
**Index:** [../00-INDEX.md](../00-INDEX.md)
