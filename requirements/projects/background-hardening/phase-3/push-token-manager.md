# FCMTokenManager

> Firebase Cloud Messaging + APNs token registration.

## Dependencies

Add Firebase SDK via Swift Package Manager:

```
https://github.com/firebase/firebase-ios-sdk
```

Select packages:
- FirebaseCore
- FirebaseMessaging

## Implementation

```swift
// CodingBridge/Managers/FCMTokenManager.swift

import UIKit
import FirebaseCore
import FirebaseMessaging

@MainActor
final class FCMTokenManager: NSObject, ObservableObject {
    static let shared = FCMTokenManager()

    @Published private(set) var fcmToken: String?
    @Published private(set) var apnsToken: Data?
    @Published private(set) var isRegistered = false

    // MARK: - Initialization

    override private init() {
        super.init()
    }

    func configure() {
        // Set messaging delegate
        Messaging.messaging().delegate = self

        // Request notification permissions
        Task {
            await requestNotificationPermission()
        }
    }

    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        } catch {
            log.error("[FCM] Permission request failed: \(error)")
        }
    }

    // MARK: - APNs Token (from AppDelegate)

    func handleAPNsToken(_ tokenData: Data) {
        apnsToken = tokenData
        // Pass APNs token to Firebase
        Messaging.messaging().apnsToken = tokenData
        log.info("[FCM] APNs token received and passed to Firebase")
    }

    func handleAPNsRegistrationError(_ error: Error) {
        log.error("[FCM] APNs registration failed: \(error)")
    }

    // MARK: - Backend Registration

    private func registerWithBackend(fcmToken: String) async {
        guard let url = URL(string: "\(APIClient.shared.baseURL)/api/push/register") else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(APIClient.shared.authToken ?? "")", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "fcmToken": fcmToken,
            "platform": "ios",
            "environment": isProduction ? "production" : "sandbox"
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                isRegistered = true
                log.info("[FCM] Token registered with backend")
            }
        } catch {
            log.error("[FCM] Backend registration failed: \(error)")
        }
    }

    // MARK: - Live Activity Token

    func sendLiveActivityToken(
        apnsToken: String,
        activityId: String,
        previousToken: String? = nil
    ) async throws {
        guard let url = URL(string: "\(APIClient.shared.baseURL)/api/push/live-activity") else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(APIClient.shared.authToken ?? "")", forHTTPHeaderField: "Authorization")

        var body: [String: Any] = [
            "apnsToken": apnsToken,  // Live Activities use APNs token directly
            "activityId": activityId,
            "platform": "ios",
            "environment": isProduction ? "production" : "sandbox"
        ]

        if let previousToken = previousToken {
            body["previousToken"] = previousToken
        }

        if let sessionId = LiveActivityManager.shared.currentSessionId {
            body["sessionId"] = sessionId
        }

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            log.info("[FCM] Live Activity token registered")
        }
    }

    // MARK: - Environment

    private var isProduction: Bool {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }

    // MARK: - Invalidation

    func invalidateToken() async {
        guard let token = fcmToken else { return }

        guard let url = URL(string: "\(APIClient.shared.baseURL)/api/push/invalidate") else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(APIClient.shared.authToken ?? "")", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["fcmToken": token])

        _ = try? await URLSession.shared.data(for: request)
        isRegistered = false
    }
}

// MARK: - MessagingDelegate

extension FCMTokenManager: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else { return }

        Task { @MainActor in
            self.fcmToken = fcmToken
            log.info("[FCM] Token received: \(fcmToken.prefix(20))...")

            await self.registerWithBackend(fcmToken: fcmToken)
        }
    }
}
```

## App Delegate Integration

```swift
// In AppDelegate

import FirebaseCore
import FirebaseMessaging

func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
    // Initialize Firebase
    FirebaseApp.configure()

    // Configure FCM token manager
    FCMTokenManager.shared.configure()

    // Register background tasks
    BackgroundManager.shared.registerBackgroundTasksSync()

    return true
}

func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
) {
    FCMTokenManager.shared.handleAPNsToken(deviceToken)
}

func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
) {
    FCMTokenManager.shared.handleAPNsRegistrationError(error)
}

func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any]
) async -> UIBackgroundFetchResult {
    // Handle silent push for clearing notifications
    if let clearApprovalId = userInfo["clearApprovalId"] as? String {
        await MainActor.run {
            NotificationManager.shared.clearApprovalNotification(requestId: clearApprovalId)
        }
        return .newData
    }

    // Let Firebase handle FCM messages
    Messaging.messaging().appDidReceiveMessage(userInfo)

    return .noData
}
```

## Firebase Console Setup

1. Create project at https://console.firebase.google.com
2. Add iOS app with bundle ID `com.level.CodingBridge`
3. Download `GoogleService-Info.plist`
4. Add to Xcode project (drag to project navigator)
5. Enable Cloud Messaging in Firebase Console
6. Upload APNs key (.p8) to Firebase Console → Project Settings → Cloud Messaging

## Live Activity Notes

Firebase Cloud Messaging fully supports Live Activities via the HTTP v1 API:

- **Start** Live Activity (iOS 17.2+): Use push-to-start token with `event: "start"`
- **Update** Live Activity: Use activity token with `event: "update"`
- **End** Live Activity: Use activity token with `event: "end"` + `dismissal-date`

Both regular notifications and Live Activity updates go through FCM - no direct APNs integration needed.

See: https://firebase.google.com/docs/cloud-messaging/customize-messages/live-activity

---
**Next:** [notification-actions](./notification-actions.md) | **Index:** [../00-INDEX.md](../00-INDEX.md)
