import SwiftUI
import UserNotifications

@main
struct ClaudeCodeAppApp: App {
    @StateObject private var settings = AppSettings()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Request notification permissions on launch
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("[App] Notification permission granted")
            }
        }

        // Initialize debug logging state from settings
        let debugEnabled = UserDefaults.standard.bool(forKey: "debugLoggingEnabled")
        Task { @MainActor in
            DebugLogStore.shared.isEnabled = debugEnabled
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .top) {
                ContentView()
                    .environmentObject(settings)

                // Global error banner overlay
                ErrorBanner()
            }
            .preferredColorScheme(settings.appTheme.colorScheme)
        }
    }
}
