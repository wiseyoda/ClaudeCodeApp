import SwiftUI
import UserNotifications
import BackgroundTasks
@preconcurrency import UIKit

// MARK: - App Delegate for Orientation Control, Background Tasks, and Push Notifications

class AppDelegate: NSObject, UIApplicationDelegate {
    /// Controls which orientations are allowed. Updated by AppSettings.lockToPortrait
    static var orientationLock: UIInterfaceOrientationMask = .portrait

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Register background tasks synchronously - must happen before launch completes
        // Per Apple docs: "All launch handlers must be registered before application finishes launching"
        BackgroundManager.shared.registerBackgroundTasksSync()

        // Configure Firebase if available (for push notifications)
        // Note: Firebase initialization happens here when GoogleService-Info.plist is present
        // and enablePushNotifications is true. For now, we check in PushNotificationManager.configure()
        return true
    }

    // MARK: - Push Notification Registration

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in
            PushNotificationManager.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Task { @MainActor in
            PushNotificationManager.shared.didFailToRegisterForRemoteNotifications(error: error)
        }
    }

    // MARK: - Background Push Handling

    // Note: Swift 6 preview warns about [AnyHashable: Any] not being Sendable.
    // This is a known UIKit limitation - the protocol requires this type.
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        log.info("[Push] Received remote notification in background")

        // Handle push notification
        PushNotificationManager.shared.handleNotification(userInfo: userInfo)

        // Check notification type for Live Activity updates
        if let type = userInfo["type"] as? String {
            switch type {
            case "task_complete", "task_error":
                await LiveActivityManager.shared.handlePushUpdate(userInfo)
            case "approval_request":
                // Parse approval request from push payload
                if let data = userInfo["data"] as? [String: Any],
                   let requestId = data["requestId"] as? String,
                   let toolName = data["toolName"] as? String {
                    let summary = data["summary"] as? String ?? "Approve tool execution?"
                    await NotificationManager.shared.sendApprovalNotification(
                        requestId: requestId,
                        toolName: toolName,
                        summary: summary
                    )
                }
            case "live_activity_update":
                await LiveActivityManager.shared.handlePushUpdate(userInfo)
            default:
                break
            }
        }

        return .newData
    }
}

@main
struct CodingBridgeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = AppSettings()
    @Environment(\.scenePhase) private var scenePhase
    private let isUITestMode = ProcessInfo.processInfo.environment["CODINGBRIDGE_UITEST_MODE"] == "1"
        || ProcessInfo.processInfo.arguments.contains("--ui-test-mode")
        || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    init() {
        // Initialize debug logging state from settings
        let debugEnabled = UserDefaults.standard.bool(forKey: "debugLoggingEnabled")
        Task { @MainActor in
            DebugLogStore.shared.isEnabled = debugEnabled
        }

        // Initialize orientation lock from settings
        let lockToPortrait = UserDefaults.standard.object(forKey: "lockToPortrait") as? Bool ?? true
        AppDelegate.orientationLock = lockToPortrait ? .portrait : .all

        // Configure notification manager and request permissions
        if !isUITestMode {
            Task { @MainActor in
                NotificationManager.shared.configure()
                _ = await NotificationManager.shared.requestPermissions()
            }
        }

        // Configure push notification manager if enabled
        let pushEnabled = UserDefaults.standard.bool(forKey: "enablePushNotifications")
        if pushEnabled && !isUITestMode {
            Task { @MainActor in
                let serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? "http://localhost:3100"
                PushNotificationManager.shared.configure(serverURL: serverURL)
                LiveActivityManager.shared.configure(serverURL: serverURL)

                // Request push permission if not already granted
                _ = await PushNotificationManager.shared.requestPermission()

                // Clean up stale Live Activities from previous sessions
                await LiveActivityManager.shared.cleanupStaleActivities()
            }
        }

        // Start network monitoring
        Task { @MainActor in
            NetworkMonitor.shared.start()
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .top) {
                #if DEBUG
                if isUITestMode {
                    PermissionApprovalTestHarnessView()
                        .environmentObject(settings)
                } else {
                    MainTabView()
                        .environmentObject(settings)
                }
                #else
                MainTabView()
                    .environmentObject(settings)
                #endif

                // Global error banner overlay
                ErrorBanner()
            }
            .preferredColorScheme(settings.appTheme.colorScheme)
            // Update orientation lock when setting changes
            .onChange(of: settings.lockToPortrait) { _, lockToPortrait in
                AppDelegate.orientationLock = lockToPortrait ? .portrait : .all
                // If unlocking, no action needed. If locking to portrait and currently in landscape,
                // the user will need to rotate the device (iOS doesn't force rotation programmatically easily)
            }
            // Handle scene phase changes for background processing
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleScenePhaseChange(from: oldPhase, to: newPhase)
            }
        }
    }

    // MARK: - Scene Phase Handling

    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        Task { @MainActor in
            log.info("[Background] Scene phase: \(oldPhase) → \(newPhase)")
            switch newPhase {
            case .active:
                BackgroundManager.shared.isAppInBackground = false
                await handleReturnToForeground()

            case .background:
                BackgroundManager.shared.isAppInBackground = true
                await handleEnterBackground()

            case .inactive:
                break

            @unknown default:
                break
            }
        }
    }

    private func handleEnterBackground() async {
        log.info("[Background] Entering background - saving state")

        // Save draft input
        DraftInputPersistence.shared.save()

        // Save any pending messages
        await MessageQueuePersistence.shared.save()

        // Check if we have an active processing task
        let taskState = BackgroundManager.shared.currentTaskState
        let wasProcessing = taskState?.status.requiresUserAction == true || (taskState != nil)

        log.info("[Background] wasProcessing=\(wasProcessing), taskState=\(taskState?.status.displayText ?? "nil")")

        if wasProcessing {
            // Request continued background processing
            if #available(iOS 26.0, *) {
                do {
                    try await BackgroundManager.shared.requestContinuedProcessing(
                        reason: "Claude is working on your task"
                    )
                    log.info("[Background] Requested continued processing (iOS 26+)")
                } catch {
                    log.error("[Background] Failed to request continued processing: \(error)")
                }
            } else {
                BackgroundManager.shared.beginBackgroundTask(reason: "Claude task processing")
            }
        } else {
            // Schedule app refresh for status checks
            BackgroundManager.shared.scheduleAppRefresh()
            log.debug("[Background] Scheduled app refresh (no active task)")
        }
    }

    private func handleReturnToForeground() async {
        log.info("[Background] Returning to foreground")

        // End any legacy background tasks
        BackgroundManager.shared.endBackgroundTask()

        // Clear notifications since user is now in app
        await NotificationManager.shared.updateBadge(count: 0)
        NotificationManager.shared.clearAllNotifications()

        // Check if we need to recover from background processing
        let wasProcessing = BackgroundManager.shared.wasProcessingOnBackground
        let lastSessionId = BackgroundManager.shared.lastSessionId
        let lastProjectPath = BackgroundManager.shared.lastProjectPath

        log.info("[Background] Recovery check: wasProcessing=\(wasProcessing), sessionId=\(lastSessionId ?? "nil"), projectPath=\(lastProjectPath ?? "nil")")

        if wasProcessing {
            // Notify ChatView to attempt session recovery
            NotificationCenter.default.post(
                name: .backgroundRecoveryNeeded,
                object: nil,
                userInfo: [
                    "sessionId": lastSessionId as Any,
                    "projectPath": lastProjectPath as Any
                ]
            )
            log.info("[Background] Posted recovery notification")

            // Clear the flag if not actually processing
            if BackgroundManager.shared.currentTaskState == nil {
                BackgroundManager.shared.clearProcessingState()
                log.debug("[Background] Cleared stale processing state")
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when app returns to foreground and needs to recover a background session
    static let backgroundRecoveryNeeded = Notification.Name("backgroundRecoveryNeeded")
}
