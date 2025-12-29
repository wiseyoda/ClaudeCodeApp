# FCMTokenManager

> Firebase Cloud Messaging + APNs token registration (iOS 26+ / Swift 6).

## Requirements

- **Firebase iOS SDK**: 12.7.0+ (latest as of Dec 2025)
- **Xcode**: 16.2+ (Swift 6.0 toolchain required)
- **iOS**: 16.1+ for Live Activities, 17.2+ for remote start

## Dependencies

Add Firebase SDK via Swift Package Manager:

```
https://github.com/firebase/firebase-ios-sdk
```

Select packages:
- FirebaseCore
- FirebaseMessaging

## SwiftUI Configuration

SwiftUI apps **must** disable method swizzling and manually handle APNs tokens:

```xml
<!-- Info.plist -->
<key>FirebaseAppDelegateProxyEnabled</key>
<false/>
```

## Implementation (Swift 6 / iOS 26+)

```swift
// CodingBridge/Managers/FCMTokenManager.swift

import UIKit
import FirebaseCore
import FirebaseMessaging

@MainActor
final class FCMTokenManager: NSObject, ObservableObject, @unchecked Sendable {
    static let shared = FCMTokenManager()

    @Published private(set) var fcmToken: String?
    @Published private(set) var isRegistered = false

    private var tokenTask: Task<Void, Never>?

    // MARK: - Initialization

    override private init() {
        super.init()
    }

    func configure() {
        // Start observing token updates via AsyncStream (modern approach)
        tokenTask = Task {
            for await token in Messaging.messaging().tokenUpdates {
                self.fcmToken = token
                log.info("[FCM] Token received via stream: \(token.prefix(20))...")
                await self.registerWithBackend(fcmToken: token)
            }
        }

        // Request notification permissions
        Task {
            await requestNotificationPermission()
        }
    }

    deinit {
        tokenTask?.cancel()
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
            log.info("[FCM] Notification permission: \(granted ? "granted" : "denied")")
        } catch {
            log.error("[FCM] Permission request failed: \(error)")
        }
    }

    // MARK: - APNs Token (required for SwiftUI - no swizzling)

    func handleAPNsToken(_ tokenData: Data) {
        // SwiftUI apps must manually pass APNs token to Firebase
        Messaging.messaging().apnsToken = tokenData
        log.info("[FCM] APNs token passed to Firebase")
    }

    func handleAPNsRegistrationError(_ error: Error) {
        log.error("[FCM] APNs registration failed: \(error)")
    }

    // MARK: - Get Token (async/await)

    func getToken() async throws -> String {
        // Prefer cached token, otherwise fetch
        if let token = fcmToken {
            return token
        }
        return try await Messaging.messaging().token()
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
            "apnsToken": apnsToken,
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
```

## App Delegate Integration (SwiftUI)

```swift
// In AppDelegate

import FirebaseCore
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Initialize Firebase FIRST
        FirebaseApp.configure()

        // Configure FCM token manager (starts async stream)
        Task { @MainActor in
            FCMTokenManager.shared.configure()
        }

        // Register background tasks
        BackgroundManager.shared.registerBackgroundTasksSync()

        return true
    }

    // REQUIRED for SwiftUI (no method swizzling)
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
}

// In CodingBridgeApp.swift
@main
struct CodingBridgeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    // ...
}
```

## Firebase Console Setup

1. Create project at https://console.firebase.google.com
2. Add iOS app with bundle ID `com.level.CodingBridge`
3. Download `GoogleService-Info.plist`
4. Add to Xcode project (drag to project navigator)
5. Enable Cloud Messaging in Firebase Console
6. Upload APNs key (.p8) to Firebase Console → Project Settings → Cloud Messaging

## Live Activities via FCM

Firebase fully supports Live Activities via HTTP v1 API:

- **Start** (iOS 17.2+): `event: "start"` with push-to-start token
- **Update**: `event: "update"` with activity token
- **End**: `event: "end"` + `dismissal-date`

See: https://firebase.google.com/docs/cloud-messaging/customize-messages/live-activity

## Swift 6 Notes

- Firebase SDK 12.0.0+ requires Swift 6.0 toolchain
- Most Firebase types now conform to `Sendable`
- Use `@unchecked Sendable` if needed for ObservableObject
- AsyncStream APIs are the modern alternative to delegates

## Sources

- [Firebase iOS SDK Release Notes](https://firebase.google.com/support/release-notes/ios)
- [Firebase iOS SDK GitHub](https://github.com/firebase/firebase-ios-sdk)
- [FCM Setup Guide](https://firebase.google.com/docs/cloud-messaging/ios/client)

---
**Next:** [notification-actions](./notification-actions.md) | **Index:** [../00-INDEX.md](../00-INDEX.md)
