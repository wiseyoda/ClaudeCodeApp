# PushTokenManager

> APNs device and Live Activity token registration.

## Implementation

```swift
// CodingBridge/Managers/PushTokenManager.swift

import UIKit

@MainActor
final class PushTokenManager: ObservableObject {
    static let shared = PushTokenManager()

    @Published private(set) var deviceToken: String?
    @Published private(set) var isRegistered = false

    // MARK: - Device Token

    func handleDeviceToken(_ tokenData: Data) async {
        let tokenString = tokenData.map { String(format: "%02x", $0) }.joined()
        deviceToken = tokenString

        Logger.push.info("Device push token received")

        await registerWithBackend(token: tokenString, type: .device)
    }

    func handleRegistrationError(_ error: Error) {
        Logger.push.error("Failed to register for push: \(error)")
    }

    // MARK: - Live Activity Token

    func sendLiveActivityToken(
        token: String,
        previousToken: String?,
        activityId: String
    ) async throws {
        await registerWithBackend(
            token: token,
            type: .liveActivity,
            activityId: activityId,
            previousToken: previousToken
        )
    }

    // MARK: - Backend Registration

    private enum TokenType: String {
        case device
        case liveActivity = "live_activity"
    }

    private func registerWithBackend(
        token: String,
        type: TokenType,
        activityId: String? = nil,
        previousToken: String? = nil
    ) async {
        guard let url = URL(string: "\(APIClient.shared.baseURL)/api/push/register") else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(APIClient.shared.authToken ?? "")", forHTTPHeaderField: "Authorization")

        var body: [String: Any] = [
            "token": token,
            "tokenType": type.rawValue,
            "platform": "ios",
            "environment": isProduction ? "production" : "development"
        ]

        if let activityId = activityId {
            body["activityId"] = activityId
        }
        if let previousToken = previousToken {
            body["previousToken"] = previousToken
        }
        if let sessionId = LiveActivityManager.shared.currentSessionId {
            body["sessionId"] = sessionId
        }

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                isRegistered = true
                Logger.push.info("Token registered: \(type.rawValue)")
            }
        } catch {
            Logger.push.error("Token registration failed: \(error)")
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

    func invalidateToken(_ token: String) async {
        guard let url = URL(string: "\(APIClient.shared.baseURL)/api/push/invalidate") else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(APIClient.shared.authToken ?? "")", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["token": token])

        _ = try? await URLSession.shared.data(for: request)
    }
}
```

## App Delegate Integration

```swift
// In AppDelegate

func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
) {
    Task {
        await PushTokenManager.shared.handleDeviceToken(deviceToken)
    }
}

func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
) {
    PushTokenManager.shared.handleRegistrationError(error)
}

func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any]
) async -> UIBackgroundFetchResult {
    // Handle silent push
    if let contentState = (userInfo["aps"] as? [String: Any])?["content-state"] {
        // Live Activity update handled by ActivityKit
        return .newData
    }

    // Handle clear commands
    if let clearApprovalId = userInfo["clearApprovalId"] as? String {
        await MainActor.run {
            NotificationManager.shared.clearApprovalNotification(requestId: clearApprovalId)
        }
        return .newData
    }

    return .noData
}
```

## Remote Notification Setup

Register at launch:

```swift
// In CodingBridgeApp or AppDelegate

UIApplication.shared.registerForRemoteNotifications()
```

---
**Next:** [notification-actions](./notification-actions.md) | **Index:** [../00-INDEX.md](../00-INDEX.md)
