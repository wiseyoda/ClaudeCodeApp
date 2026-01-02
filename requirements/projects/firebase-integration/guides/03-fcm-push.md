# FCM Push Notifications Setup

Complete guide for Firebase Cloud Messaging integration.

## Overview

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│   Your Backend   │────▶│  Firebase FCM    │────▶│   APNs (Apple)   │
│   (cli-bridge)   │     │                  │     │                  │
└──────────────────┘     └──────────────────┘     └──────────────────┘
                                                           │
                                                           ▼
                                                  ┌──────────────────┐
                                                  │  CodingBridge    │
                                                  │      App         │
                                                  └──────────────────┘
```

---

## Prerequisites

Before proceeding:
- [ ] Firebase SDK installed via SPM
- [ ] `GoogleService-Info.plist` added to project
- [ ] APNs Authentication Key uploaded to Firebase Console
- [ ] Push Notifications capability added in Xcode

---

## APNs Key Setup (Apple Developer)

### Create APNs Authentication Key

1. Go to [Apple Developer Keys](https://developer.apple.com/account/resources/authkeys/list)
2. Click **+** to create new key
3. Enter name: `CodingBridge FCM`
4. Check **Apple Push Notifications service (APNs)**
5. Click **Continue** → **Register**
6. **Download** the `.p8` file (only available once!)
7. Note the **Key ID** (10-character code)

### Get Team ID

1. Go to [Membership Details](https://developer.apple.com/account/#/membership)
2. Find **Team ID** (10-character code)

### Upload to Firebase

1. Firebase Console → Project Settings → Cloud Messaging
2. Under Apple app configuration, click **Upload** for APNs Authentication Key
3. Upload `.p8` file
4. Enter Key ID and Team ID
5. Click **Upload**

---

## Code Implementation

### FirebaseManager FCM Setup

The `FirebaseManager` class handles FCM configuration:

```swift
// In FirebaseManager.swift

private func configureMessaging() {
    // Set delegate to receive FCM token updates
    Messaging.messaging().delegate = self

    // Set notification center delegate
    UNUserNotificationCenter.current().delegate = self

    // Request notification permissions
    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
    UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
        if let error = error {
            Logger.shared.error("Notification auth error: \(error.localizedDescription)")
            return
        }
        Logger.shared.info("Notification permission: \(granted)")
    }
}

func registerForRemoteNotifications() {
    DispatchQueue.main.async {
        UIApplication.shared.registerForRemoteNotifications()
    }
}
```

### Handling APNs Token

Since swizzling is disabled for SwiftUI, manually forward APNs token:

```swift
// In AppDelegate

func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
) {
    // Forward to Firebase
    Messaging.messaging().apnsToken = deviceToken

    // Also forward to existing PushNotificationManager
    PushNotificationManager.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
}
```

### Receiving FCM Token

```swift
// MessagingDelegate extension

extension FirebaseManager: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else {
            Logger.shared.warning("FCM token is nil")
            return
        }

        Logger.shared.info("FCM token: \(token.prefix(20))...")

        // Store locally
        self.fcmToken = token

        // Forward to PushNotificationManager for backend registration
        Task {
            await PushNotificationManager.shared.handleFCMToken(token)
        }
    }
}
```

### Handling Notifications

```swift
// UNUserNotificationCenterDelegate extension

extension FirebaseManager: UNUserNotificationCenterDelegate {
    // Called when notification received while app in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo

        // Log for debugging
        Logger.shared.debug("Foreground notification: \(userInfo)")

        // Forward to handler
        PushNotificationManager.shared.handleNotification(userInfo: userInfo)

        // Show banner even in foreground
        return [.banner, .badge, .sound]
    }

    // Called when user taps notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo

        Logger.shared.debug("Notification tapped: \(userInfo)")

        // Handle tap action
        PushNotificationManager.shared.handleNotificationTap(userInfo: userInfo)
    }
}
```

---

## Backend Integration

### Register FCM Token with cli-bridge

Update `PushNotificationManager.swift`:

```swift
func handleFCMToken(_ token: String) async {
    // Store in Keychain
    KeychainHelper.storeFCMToken(token)

    // Register with backend
    do {
        let apiClient = CLIBridgeAPIClient.shared
        try await apiClient.registerPushToken(
            fcmToken: token,
            environment: getEnvironment()
        )
        Logger.shared.info("FCM token registered with backend")
    } catch {
        Logger.shared.error("Failed to register FCM token: \(error)")
    }
}

private func getEnvironment() -> String {
    #if DEBUG
    return "development"
    #else
    return "production"
    #endif
}
```

### Invalidate on Logout

```swift
func invalidateToken() async {
    guard let token = KeychainHelper.retrieveFCMToken() else { return }

    do {
        try await CLIBridgeAPIClient.shared.invalidatePushToken(
            tokenType: "fcm",
            token: token
        )
        KeychainHelper.deleteFCMToken()
        Logger.shared.info("FCM token invalidated")
    } catch {
        Logger.shared.error("Failed to invalidate token: \(error)")
    }
}
```

---

## Notification Payload Structure

### Standard FCM Payload

```json
{
  "message": {
    "token": "FCM_DEVICE_TOKEN",
    "notification": {
      "title": "Session Update",
      "body": "Your Claude session has a new response"
    },
    "data": {
      "type": "session_update",
      "sessionId": "abc123",
      "projectPath": "/Users/dev/project"
    },
    "apns": {
      "payload": {
        "aps": {
          "badge": 1,
          "sound": "default",
          "content-available": 1
        }
      }
    }
  }
}
```

### Handling Custom Data

```swift
func handleNotification(userInfo: [AnyHashable: Any]) {
    guard let type = userInfo["type"] as? String else { return }

    switch type {
    case "session_update":
        if let sessionId = userInfo["sessionId"] as? String {
            navigateToSession(sessionId)
        }
    case "error":
        if let message = userInfo["message"] as? String {
            showErrorAlert(message)
        }
    default:
        Logger.shared.warning("Unknown notification type: \(type)")
    }
}
```

---

## Testing Push Notifications

### Enable Debug Logging

Add to scheme arguments:
```
-FIRDebugEnabled
```

### Send Test from Firebase Console

1. Firebase Console → Cloud Messaging
2. Click **Send your first message**
3. Enter:
   - Title: "Test Notification"
   - Body: "Testing push notifications"
4. Click **Send test message**
5. Enter FCM token from Xcode console
6. Click **Test**

### Send Test via cURL

```bash
# Get server key from Firebase Console → Project Settings → Cloud Messaging

curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Authorization: key=YOUR_SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "DEVICE_FCM_TOKEN",
    "notification": {
      "title": "Test",
      "body": "Test message"
    }
  }'
```

---

## Troubleshooting

### No FCM Token Received

1. **Verify physical device**: Simulator doesn't receive push tokens
2. **Check APNs key**: Verify uploaded to Firebase Console
3. **Check entitlements**: Push Notifications capability enabled
4. **Check swizzling**: `FirebaseAppDelegateProxyEnabled` = NO
5. **Check APNs forwarding**: `Messaging.messaging().apnsToken = deviceToken`

### Token Received but No Notifications

1. **Check Firebase Console**: Token should appear in Cloud Messaging
2. **Check backend**: Verify cli-bridge receives and stores token
3. **Check notification permissions**: User must grant permission
4. **Check payload format**: Ensure valid APNs payload structure

### Notifications Not Appearing

1. **Foreground**: Check delegate returns `.banner`
2. **Background**: Check `content-available: 1` in payload
3. **Do Not Disturb**: Check device settings
4. **Focus mode**: Check if app is allowed

### Badge Not Updating

```swift
// Clear badge on app open
UIApplication.shared.applicationIconBadgeNumber = 0
```

---

## Best Practices

1. **Request permissions at right time**: Don't ask on first launch
2. **Handle token refresh**: FCM tokens can change
3. **Store token securely**: Use Keychain, not UserDefaults
4. **Handle errors gracefully**: App should work without push
5. **Test all scenarios**: Foreground, background, terminated
6. **Respect user preferences**: Honor notification settings
