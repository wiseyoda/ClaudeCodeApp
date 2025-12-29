# TestFlight & Testing

> APNs environments and testing workflow.

## APNs Environments

| Environment | When Used | Server |
|-------------|-----------|--------|
| Development | Xcode builds, Simulator | api.sandbox.push.apple.com |
| Production | TestFlight, App Store | api.push.apple.com |

**Important:** TestFlight uses **production** APNs, not sandbox!

## Backend Environment Configuration

```bash
# Development (local testing)
APNS_ENVIRONMENT=development

# Production (TestFlight, App Store)
APNS_ENVIRONMENT=production
```

## Testing Push Notifications

### Simulator

- Local notifications work
- Push notifications require device or test tools
- Live Activities work with limitations (no Dynamic Island preview)

### Xcode Push Simulation

1. Device connected, app running
2. Debug → Simulate Push Notification
3. Use sample payload file:

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
  "type": "approval"
}
```

### curl APNs Testing

```bash
# Generate JWT token (requires script or tool)

# Test sandbox push
curl -v \
  --http2 \
  --header "authorization: bearer $JWT_TOKEN" \
  --header "apns-topic: com.codingbridge.CodingBridge" \
  --header "apns-push-type: alert" \
  --data '{"aps":{"alert":{"title":"Test","body":"Hello"}}}' \
  https://api.sandbox.push.apple.com/3/device/$DEVICE_TOKEN

# Test Live Activity update
curl -v \
  --http2 \
  --header "authorization: bearer $JWT_TOKEN" \
  --header "apns-topic: com.codingbridge.CodingBridge.push-type.liveactivity" \
  --header "apns-push-type: liveactivity" \
  --data '{"aps":{"timestamp":1234567890,"event":"update","content-state":{"status":"processing"}}}' \
  https://api.sandbox.push.apple.com/3/device/$ACTIVITY_TOKEN
```

## Background Task Testing

Simulate in debugger:

```
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.codingbridge.task.refresh"]
```

## Debug Helpers

```swift
#if DEBUG
extension LiveActivityManager {
    func debugStartTestActivity() async {
        try? await startActivity(
            projectName: "Test Project",
            projectPath: "/test/path",
            sessionId: "debug-session",
            initialOperation: "Running tests..."
        )
    }

    func debugShowApprovalNeeded() async {
        await updateActivity(
            status: .awaitingApproval,
            operation: nil,
            elapsedSeconds: 60,
            approvalRequest: ApprovalInfo(
                requestId: "test-123",
                toolName: "Bash",
                summary: "Run: npm test"
            )
        )
    }
}

extension NotificationManager {
    func debugSendTestApproval() async {
        await sendApprovalNotification(
            requestId: "debug-\(UUID().uuidString.prefix(8))",
            toolName: "Bash",
            summary: "Execute: npm test"
        )
    }

    func debugListPendingNotifications() async {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        Logger.notifications.info("Pending: \(pending.count)")
        for request in pending {
            Logger.notifications.debug("  - \(request.identifier)")
        }
    }
}
#endif
```

## TestFlight Testing Checklist

- [ ] Build with Release configuration
- [ ] Backend using production APNs environment
- [ ] Test push notification delivery
- [ ] Test Live Activity updates via push
- [ ] Test notification actions (Approve/Deny)
- [ ] Test background task execution
- [ ] Test after device restart
- [ ] Test in Low Power Mode
- [ ] Test with Focus modes enabled

## Common Issues

| Issue | Solution |
|-------|----------|
| Push not received | Check APNs environment matches build |
| Invalid token | Re-register, check sandbox vs production |
| Live Activity not updating | Check throttling (15s minimum) |
| Background task not running | Check Info.plist identifiers |

---
**Index:** [../00-INDEX.md](../00-INDEX.md)
