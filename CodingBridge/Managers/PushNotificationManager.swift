import Foundation
import UserNotifications
import UIKit

// MARK: - Push Notification Manager
// Manages FCM token registration and push notification handling
// Requires Firebase SDK to be configured - gracefully degrades if not available

@MainActor
final class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()

    // MARK: - Published State

    @Published private(set) var fcmToken: String?
    @Published private(set) var isRegistered: Bool = false
    @Published private(set) var registrationError: String?
    @Published private(set) var isEnabled: Bool = false
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - Private State

    private var apiClient: CLIBridgeAPIClient?
    private var pendingTokenRegistration: String?
    private var isFirebaseConfigured: Bool = false

    // MARK: - Initialization

    private override init() {
        super.init()
        // Load cached FCM token from Keychain
        fcmToken = KeychainHelper.shared.retrieveFCMToken()
    }

    // MARK: - Configuration

    /// Configure the push notification manager with the server URL
    /// Call this when the app starts and push notifications are enabled
    func configure(serverURL: String) {
        apiClient = CLIBridgeAPIClient(serverURL: serverURL)

        // Check if Firebase is configured (GoogleService-Info.plist exists)
        isFirebaseConfigured = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil

        if isFirebaseConfigured {
            log.info("[Push] Firebase configured, initializing...")
            // Firebase initialization would happen in AppDelegate
            // This manager will receive the FCM token via didReceiveFCMToken()
        } else {
            log.warning("[Push] Firebase not configured - push notifications unavailable")
            registrationError = "Firebase not configured"
        }

        // Check current notification authorization status
        Task {
            await checkAuthorizationStatus()
        }
    }

    /// Check and update notification authorization status
    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
        isEnabled = settings.authorizationStatus == .authorized
    }

    /// Request notification permissions
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound, .criticalAlert]
            )
            await checkAuthorizationStatus()

            if granted {
                log.info("[Push] Notification permission granted")
                // Register for remote notifications
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                log.info("[Push] Notification permission denied")
            }

            return granted
        } catch {
            log.error("[Push] Failed to request notification permission: \(error)")
            registrationError = error.localizedDescription
            return false
        }
    }

    // MARK: - APNs Token Handling

    /// Called when APNs device token is received
    /// This is called by AppDelegate's didRegisterForRemoteNotificationsWithDeviceToken
    func didRegisterForRemoteNotifications(deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        log.info("[Push] Received APNs device token: \(tokenString.prefix(20))...")

        // If Firebase is configured, it will handle converting this to FCM token
        // via the MessagingDelegate. If not, we store the APNs token directly.
        if !isFirebaseConfigured {
            // Without Firebase, store APNs token directly (limited functionality)
            fcmToken = tokenString
            KeychainHelper.shared.storeFCMToken(tokenString)
        }
    }

    /// Called when APNs registration fails
    func didFailToRegisterForRemoteNotifications(error: Error) {
        log.error("[Push] Failed to register for remote notifications: \(error)")
        registrationError = error.localizedDescription
    }

    // MARK: - FCM Token Handling

    /// Called when FCM token is received (from Firebase MessagingDelegate)
    func didReceiveFCMToken(_ token: String) {
        log.info("[Push] Received FCM token: \(token.prefix(20))...")
        fcmToken = token
        KeychainHelper.shared.storeFCMToken(token)

        // Register with backend
        Task {
            await registerWithBackend()
        }
    }

    // MARK: - Backend Registration

    /// Register the FCM token with the cli-bridge backend
    func registerWithBackend() async {
        guard let token = fcmToken, let client = apiClient else {
            log.warning("[Push] Cannot register: no token or client")
            return
        }

        do {
            let environment = isProductionEnvironment ? "production" : "sandbox"
            let response = try await client.registerPushToken(
                fcmToken: token,
                environment: environment
            )

            isRegistered = response.success
            registrationError = nil
            pendingTokenRegistration = nil

            if response.success {
                log.info("[Push] Successfully registered FCM token with backend")
            } else {
                log.warning("[Push] Backend returned success=false")
            }
        } catch let error as CLIBridgeAPIError {
            switch error {
            case .notFound:
                // Backend push endpoints not yet implemented
                log.warning("[Push] Backend push endpoints not available (404)")
                pendingTokenRegistration = token
                registrationError = "Push endpoints not available on server"
            default:
                log.error("[Push] Registration failed: \(error)")
                registrationError = error.localizedDescription
            }
        } catch {
            log.error("[Push] Registration failed: \(error)")
            registrationError = error.localizedDescription
        }
    }

    /// Retry pending token registration
    func retryPendingRegistration() async {
        guard pendingTokenRegistration != nil else { return }
        await registerWithBackend()
    }

    // MARK: - Token Invalidation

    /// Invalidate the current FCM token (e.g., on logout)
    func invalidateToken() async {
        guard let token = fcmToken, let client = apiClient else { return }

        do {
            try await client.invalidatePushToken(tokenType: .fcm, token: token)
            log.info("[Push] FCM token invalidated")
        } catch {
            log.error("[Push] Failed to invalidate token: \(error)")
        }

        // Clear local state
        fcmToken = nil
        isRegistered = false
        KeychainHelper.shared.deleteFCMToken()
    }

    // MARK: - Push Status

    /// Check push registration status from backend
    func checkStatus() async -> CLIPushStatusResponse? {
        guard let client = apiClient else { return nil }

        do {
            let status = try await client.getPushStatus()
            isRegistered = status.fcmTokenRegistered
            return status
        } catch {
            log.error("[Push] Failed to get push status: \(error)")
            return nil
        }
    }

    // MARK: - Notification Handling

    /// Handle received push notification
    func handleNotification(userInfo: [AnyHashable: Any]) {
        log.info("[Push] Received notification: \(userInfo)")

        // Parse notification type
        guard let type = userInfo["type"] as? String else { return }

        switch type {
        case "task_complete":
            handleTaskComplete(userInfo)
        case "task_error":
            handleTaskError(userInfo)
        case "approval_request":
            handleApprovalRequest(userInfo)
        case "question":
            handleQuestion(userInfo)
        case "session_warning":
            handleSessionWarning(userInfo)
        default:
            log.warning("[Push] Unknown notification type: \(type)")
        }
    }

    private func handleTaskComplete(_ userInfo: [AnyHashable: Any]) {
        // Post notification for UI to handle
        NotificationCenter.default.post(
            name: .pushTaskComplete,
            object: nil,
            userInfo: userInfo
        )
    }

    private func handleTaskError(_ userInfo: [AnyHashable: Any]) {
        NotificationCenter.default.post(
            name: .pushTaskError,
            object: nil,
            userInfo: userInfo
        )
    }

    private func handleApprovalRequest(_ userInfo: [AnyHashable: Any]) {
        NotificationCenter.default.post(
            name: .pushApprovalRequest,
            object: nil,
            userInfo: userInfo
        )
    }

    private func handleQuestion(_ userInfo: [AnyHashable: Any]) {
        NotificationCenter.default.post(
            name: .pushQuestion,
            object: nil,
            userInfo: userInfo
        )
    }

    private func handleSessionWarning(_ userInfo: [AnyHashable: Any]) {
        NotificationCenter.default.post(
            name: .pushSessionWarning,
            object: nil,
            userInfo: userInfo
        )
    }

    // MARK: - Helpers

    /// Determine if we're in production or sandbox environment
    private var isProductionEnvironment: Bool {
        #if DEBUG
        return false
        #else
        // Check for TestFlight
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            return false
        }
        return true
        #endif
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let pushTaskComplete = Notification.Name("pushTaskComplete")
    static let pushTaskError = Notification.Name("pushTaskError")
    static let pushApprovalRequest = Notification.Name("pushApprovalRequest")
    static let pushQuestion = Notification.Name("pushQuestion")
    static let pushSessionWarning = Notification.Name("pushSessionWarning")
}
