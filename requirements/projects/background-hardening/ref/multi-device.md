# Multi-Device Handling

> Coordinating notifications and approvals across iPhone + iPad.

## Problem

1. Both iPhone and iPad receive approval notification
2. User approves on iPhone
3. iPad still shows outdated notification

## Solution: Backend Coordination

### Clear on Other Devices

When approval is processed, notify backend to clear other devices:

```swift
func handleApprovalAction(requestId: String, approved: Bool) async {
    await WebSocketManager.shared.sendApprovalResponse(
        requestId: requestId,
        approved: approved
    )

    // Request backend to send clear push to other devices
    try? await APIClient.shared.clearApprovalOnOtherDevices(requestId: requestId)
}
```

### Handle Clear Push

```swift
func handleSilentPush(userInfo: [AnyHashable: Any]) {
    if let clearRequestId = userInfo["clearApprovalId"] as? String {
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: ["approval-\(clearRequestId)"]
        )

        Task {
            await LiveActivityManager.shared.clearApprovalDisplay(requestId: clearRequestId)
        }
    }
}
```

### Backend API

```
POST /api/push/clear-approval
Authorization: Bearer <jwt>

{
  "requestId": "approval-123",
  "excludeDeviceToken": "abc123..."
}

Response: { "success": true, "devicesNotified": 2 }
```

### Silent Push Payload

```json
{
  "aps": {
    "content-available": 1
  },
  "clearApprovalId": "approval-123",
  "reason": "approved_on_other_device"
}
```

## Session Handoff

When user starts task on iPhone, then opens Mac:

### Backend Tracking

```javascript
// Backend tracks active client per session
session.activeClient = {
  type: 'ios',  // or 'desktop', 'web'
  deviceId: 'device-123',
  lastActivityAt: Date.now()
};

// When different client sends message
if (session.activeClient.deviceId !== newDeviceId) {
  await sendHandoffNotification(session.activeClient.deviceId, sessionId);
  session.activeClient = { type: newType, deviceId: newDeviceId };
}
```

### iOS Handling

```swift
func handleHandoffNotification(sessionId: String) async {
    if LiveActivityManager.shared.currentSessionId == sessionId {
        await LiveActivityManager.shared.endActivity(
            finalStatus: .completed,
            message: "Session continued on another device"
        )
    }

    await NotificationManager.shared.sendNotification(
        title: "Session Handed Off",
        body: "Continued on another device"
    )
}
```

### Handoff Push Payload

```json
{
  "aps": {
    "content-available": 1
  },
  "type": "session_handoff",
  "sessionId": "session-123",
  "handedOffTo": "desktop"
}
```

## Active Client Table

```sql
CREATE TABLE session_active_clients (
    session_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    client_type TEXT NOT NULL,
    device_id TEXT NOT NULL,
    push_token TEXT,
    last_activity_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---
**Index:** [../00-INDEX.md](../00-INDEX.md)
