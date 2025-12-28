import SwiftUI
import UserNotifications

// MARK: - App Delegate for Orientation Control

class AppDelegate: NSObject, UIApplicationDelegate {
    /// Controls which orientations are allowed. Updated by AppSettings.lockToPortrait
    static var orientationLock: UIInterfaceOrientationMask = .portrait

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
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
        if !isUITestMode {
            // Request notification permissions on launch
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if granted {
                    print("[App] Notification permission granted")
                }
            }
        }

        // Initialize debug logging state from settings
        let debugEnabled = UserDefaults.standard.bool(forKey: "debugLoggingEnabled")
        Task { @MainActor in
            DebugLogStore.shared.isEnabled = debugEnabled
        }

        // Initialize orientation lock from settings
        let lockToPortrait = UserDefaults.standard.object(forKey: "lockToPortrait") as? Bool ?? true
        AppDelegate.orientationLock = lockToPortrait ? .portrait : .all
    }

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .top) {
                #if DEBUG
                if isUITestMode {
                    PermissionApprovalTestHarnessView()
                        .environmentObject(settings)
                } else {
                    ContentView()
                        .environmentObject(settings)
                }
                #else
                ContentView()
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
        }
    }
}
