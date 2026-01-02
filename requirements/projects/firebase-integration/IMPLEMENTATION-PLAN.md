# Firebase Implementation Plan

Complete technical implementation guide for integrating Firebase into CodingBridge.

> **IMPORTANT**: See `REVIEW-NOTES.md` for assumptions and architectural decisions.

## Overview

### Services Being Integrated

1. **FirebaseCore** - Required foundation for all Firebase services
2. **FirebaseMessaging** - Push notifications via FCM
3. **FirebaseCrashlytics** - Crash reporting
4. **FirebaseAnalytics** - Usage analytics (also required by Crashlytics)
5. **FirebaseRemoteConfig** - Feature flags
6. **FirebasePerformance** - Performance monitoring

### Architecture Approach (REVISED)

**Decision**: Extend existing managers rather than create new `FirebaseManager` class.

```
┌─────────────────────────────────────────────────────────────┐
│                    CodingBridgeApp                          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ AppDelegate                                          │   │
│  │  • FirebaseApp.configure()  ← NEW                   │   │
│  │  • APNs token → Messaging.apnsToken  ← NEW          │   │
│  │  • Existing push handling preserved                  │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
    ┌─────────────────────────┼─────────────────────────┐
    │                         │                         │
    ▼                         ▼                         ▼
┌──────────────────┐   ┌────────────────┐   ┌─────────────────┐
│ PushNotification │   │ CrashlyticsHelper │ │ RemoteConfigMgr │
│    Manager       │   │   (NEW helper)    │ │  (NEW singleton) │
│  + MessagingDel  │   └─────────────────┘   └─────────────────┘
│    ← EXTEND      │
└──────────────────┘            │                    │
         │                      ▼                    ▼
         │               ┌─────────────────────────────────┐
         └──────────────▶│   AnalyticsEvents (NEW helper)   │
                         └─────────────────────────────────┘
```

### Files Modified vs Created

| Action | File | Changes |
|--------|------|---------|
| **MODIFY** | `AppDelegate` in `CodingBridgeApp.swift` | Add Firebase init, APNs forwarding |
| **MODIFY** | `PushNotificationManager.swift` | Add MessagingDelegate conformance |
| **MODIFY** | `Info.plist` | Add `FirebaseAppDelegateProxyEnabled` |
| **CREATE** | `CrashlyticsHelper.swift` | Thin wrapper for crash logging |
| **CREATE** | `AnalyticsEvents.swift` | Analytics event definitions |
| **CREATE** | `RemoteConfigManager.swift` | Remote Config singleton |
| **CREATE** | `RemoteConfigDefaults.plist` | Default config values |

---

## Phase 1: Prerequisites (User Actions Required)

> **See `USER-STEPS.md` for detailed instructions**

### 1.1 Firebase Console Setup
- [ ] Create Firebase project
- [ ] Register iOS app with bundle ID: **`com.level.CodingBridge`**
- [ ] Download `GoogleService-Info.plist`

### 1.2 Apple Developer Setup
- [ ] Create APNs Authentication Key (p8 file)
- [ ] Upload APNs key to Firebase Console
- [ ] Note Key ID and Team ID

---

## Phase 2: Swift Package Manager Integration

### 2.1 Add Firebase SDK

**In Xcode:**
1. File → Add Packages...
2. Enter: `https://github.com/firebase/firebase-ios-sdk.git`
3. Set "Dependency Rule" to "Up to Next Major Version"
4. Set version to `12.7.0`
5. Select packages:
   - FirebaseAnalytics
   - FirebaseCrashlytics
   - FirebaseMessaging
   - FirebaseRemoteConfig
   - FirebasePerformance

### 2.2 Build Settings

Add to "Other Linker Flags" in Build Settings:
```
-ObjC
```

This is **required** for FirebaseAnalytics.

### 2.3 Add GoogleService-Info.plist

1. Drag `GoogleService-Info.plist` to Xcode project navigator
2. Ensure "Copy items if needed" is checked
3. Ensure target "CodingBridge" is selected
4. Verify file is in project root (same level as `Info.plist`)

---

## Phase 3: App Configuration

### 3.1 Info.plist Additions

Add to `Info.plist`:

```xml
<!-- Disable swizzling for SwiftUI compatibility -->
<key>FirebaseAppDelegateProxyEnabled</key>
<false/>

<!-- Background modes (already present, verify) -->
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

### 3.2 Capabilities (Xcode)

Verify in Signing & Capabilities:
- [x] Push Notifications (should already exist)
- [ ] Background Modes → Remote notifications (verify checked)

---

## Phase 4: Code Implementation (REVISED)

> **Architecture Decision**: Extend existing managers instead of creating new FirebaseManager class.
> See `REVIEW-NOTES.md` for rationale.

### 4.1 Update AppDelegate in CodingBridgeApp.swift

**File:** `CodingBridge/CodingBridgeApp.swift`

Add Firebase imports and initialization to existing AppDelegate:

```swift
// ADD these imports at the top of file
import FirebaseCore
import FirebaseMessaging
import FirebaseCrashlytics
import FirebasePerformance

// UPDATE the existing AppDelegate class
class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock: UIInterfaceOrientationMask = .portrait

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Register background tasks (existing)
        BackgroundManager.shared.registerBackgroundTasksSync()

        // NEW: Configure Firebase if GoogleService-Info.plist exists
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
            configureCrashlytics()
            configurePerformance()
            log.info("[Firebase] Configured successfully")
        } else {
            log.warning("[Firebase] GoogleService-Info.plist not found - Firebase disabled")
        }

        return true
    }

    // NEW: Crashlytics configuration
    private func configureCrashlytics() {
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
    }

    // NEW: Performance monitoring configuration
    private func configurePerformance() {
        Performance.sharedInstance().isDataCollectionEnabled = true
    }

    // MARK: - Push Notification Registration

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // NEW: Forward APNs token to Firebase Messaging (required when swizzling disabled)
        Messaging.messaging().apnsToken = deviceToken

        // Existing: Forward to PushNotificationManager
        Task { @MainActor in
            PushNotificationManager.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Task { @MainActor in
            PushNotificationManager.shared.didFailToRegisterForRemoteNotifications(error: error)
        }
    }

    // Existing background push handling unchanged...
    @preconcurrency
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        // ... existing implementation preserved
    }
}
```

### 4.2 Update PushNotificationManager.swift

**File:** `CodingBridge/Managers/PushNotificationManager.swift`

Add Firebase MessagingDelegate conformance to existing manager:

```swift
// ADD import at top
import FirebaseMessaging

// ADD MessagingDelegate conformance to class declaration
@MainActor
final class PushNotificationManager: NSObject, ObservableObject, MessagingDelegate {
    // ... existing code ...

    // UPDATE configure() method - add Messaging delegate setup
    func configure(serverURL: String) {
        apiClient = CLIBridgeAPIClient(serverURL: serverURL)

        isFirebaseConfigured = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil

        if isFirebaseConfigured {
            log.info("[Push] Firebase configured, setting up MessagingDelegate...")
            // NEW: Set self as MessagingDelegate to receive FCM tokens
            Messaging.messaging().delegate = self
        } else {
            log.warning("[Push] Firebase not configured - push notifications unavailable")
            registrationError = "Firebase not configured"
        }

        Task {
            await checkAuthorizationStatus()
        }
    }

    // NEW: MessagingDelegate method - called when FCM token is received/refreshed
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else {
            log.warning("[Push] FCM token is nil")
            return
        }

        log.info("[Push] FCM token received: \(token.prefix(20))...")

        // Use existing method to handle the token
        didReceiveFCMToken(token)
    }

    // ... rest of existing implementation unchanged ...
}
```

### 4.3 Create CrashlyticsHelper.swift (NEW)

**File:** `CodingBridge/Utilities/CrashlyticsHelper.swift`

Thin wrapper for Crashlytics logging:

```swift
import Foundation
import FirebaseCrashlytics

/// Helper for Crashlytics error and event logging
enum CrashlyticsHelper {

    /// Check if Crashlytics is available
    static var isAvailable: Bool {
        return Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
    }

    /// Log a non-fatal error to Crashlytics
    static func logError(_ error: Error, userInfo: [String: Any]? = nil) {
        guard isAvailable else { return }

        var info = userInfo ?? [:]
        info["timestamp"] = Date().ISO8601Format()
        Crashlytics.crashlytics().record(error: error, userInfo: info)
    }

    /// Log a breadcrumb message (appears in crash reports)
    static func log(_ message: String) {
        guard isAvailable else { return }
        Crashlytics.crashlytics().log(message)
    }

    /// Set a custom key-value pair for crash context
    static func setCustomKey(_ key: String, value: Any) {
        guard isAvailable else { return }
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    }

    /// Set user identifier for crash reports
    static func setUserId(_ userId: String?) {
        guard isAvailable else { return }
        Crashlytics.crashlytics().setUserID(userId ?? "")
    }

    /// Log current screen for crash context
    static func setCurrentScreen(_ screenName: String) {
        setCustomKey("current_screen", value: screenName)
    }
}
```

### 4.4 Create RemoteConfigManager.swift (NEW)

**File:** `CodingBridge/Managers/RemoteConfigManager.swift`

```swift
import Foundation
import FirebaseRemoteConfig

/// Manages Firebase Remote Config for feature flags and configuration
@MainActor
class RemoteConfigManager: ObservableObject {
    static let shared = RemoteConfigManager()

    @Published private(set) var isConfigured = false
    @Published private(set) var lastFetchTime: Date?

    private var remoteConfig: RemoteConfig?

    private init() {
        configure()
    }

    private func configure() {
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            log.warning("[RemoteConfig] Firebase not configured")
            return
        }

        remoteConfig = RemoteConfig.remoteConfig()

        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0 // No cache in debug
        #else
        settings.minimumFetchInterval = 3600 // 1 hour in production
        #endif
        remoteConfig?.configSettings = settings

        // Load defaults
        remoteConfig?.setDefaults(fromPlist: "RemoteConfigDefaults")

        isConfigured = true

        // Initial fetch
        Task {
            await fetchAndActivate()
        }
    }

    /// Fetch and activate remote config
    func fetchAndActivate() async {
        guard let config = remoteConfig else { return }

        do {
            let status = try await config.fetchAndActivate()
            lastFetchTime = Date()
            log.info("[RemoteConfig] Fetch status: \(status.rawValue)")
        } catch {
            log.error("[RemoteConfig] Fetch error: \(error.localizedDescription)")
        }
    }

    // MARK: - Feature Flags (Kill Switches)

    var isSSHEnabled: Bool {
        remoteConfig?["feature_ssh_enabled"].boolValue ?? true
    }

    var isIdeasEnabled: Bool {
        remoteConfig?["feature_ideas_enabled"].boolValue ?? true
    }

    var isBookmarksEnabled: Bool {
        remoteConfig?["feature_bookmarks_enabled"].boolValue ?? true
    }

    // MARK: - Version Control

    var minSupportedVersion: String {
        remoteConfig?["min_supported_version"].stringValue ?? "1.0.0"
    }

    var forceUpdateVersion: String? {
        let version = remoteConfig?["force_update_version"].stringValue ?? ""
        return version.isEmpty ? nil : version
    }

    var updateMessage: String {
        remoteConfig?["update_message"].stringValue ?? "A new version is available."
    }

    /// Check if current app version is supported
    var isCurrentVersionSupported: Bool {
        let current = AppVersion.version
        return current.compare(minSupportedVersion, options: .numeric) != .orderedAscending
    }

    /// Check if current version requires forced update
    var requiresForceUpdate: Bool {
        guard let forceVersion = forceUpdateVersion else { return false }
        let current = AppVersion.version
        return current.compare(forceVersion, options: .numeric) == .orderedAscending
    }

    // MARK: - Configuration Values

    var maxMessageHistory: Int {
        remoteConfig?["max_message_history"].numberValue.intValue ?? 50
    }

    var sessionTimeoutMinutes: Int {
        remoteConfig?["session_timeout_minutes"].numberValue.intValue ?? 30
    }

    var apiTimeoutSeconds: TimeInterval {
        TimeInterval(remoteConfig?["api_timeout_seconds"].numberValue.intValue ?? 30)
    }

    // MARK: - Generic Access

    func boolValue(forKey key: String, default defaultValue: Bool = false) -> Bool {
        remoteConfig?[key].boolValue ?? defaultValue
    }

    func stringValue(forKey key: String, default defaultValue: String = "") -> String {
        remoteConfig?[key].stringValue ?? defaultValue
    }

    func intValue(forKey key: String, default defaultValue: Int = 0) -> Int {
        remoteConfig?[key].numberValue.intValue ?? defaultValue
    }
}
```

---

## Phase 5: Crashlytics Build Phase

### 5.1 Add dSYM Upload Script

In Xcode:
1. Select project → CodingBridge target
2. Build Phases tab
3. Click "+" → "New Run Script Phase"
4. Name it "Upload Crashlytics Symbols"
5. **Move to LAST position** (critical!)
6. Add script:

```bash
# Upload dSYM files to Crashlytics
"${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
```

7. Add Input Files:
```
${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}
${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${PRODUCT_NAME}
${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Info.plist
$(TARGET_BUILD_DIR)/$(INFOPLIST_PATH)
```

### 5.2 Build Settings

Ensure Debug Information Format is set:
1. Build Settings → Search "debug information"
2. Set "Debug Information Format" to **DWARF with dSYM File** for all configurations

### 5.3 Disable User Script Sandboxing (if needed)

If dSYM uploads fail:
1. Build Settings → Search "user script sandboxing"
2. Set "User Script Sandboxing" to **No**

---

## Phase 6: Remote Config Defaults

### 6.1 Create RemoteConfigDefaults.plist

**File:** `CodingBridge/RemoteConfigDefaults.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Feature Flags (kill switches) -->
    <key>feature_ssh_enabled</key>
    <true/>
    <key>feature_ideas_enabled</key>
    <true/>
    <key>feature_bookmarks_enabled</key>
    <true/>

    <!-- Version Control -->
    <key>min_supported_version</key>
    <string>1.0.0</string>
    <key>force_update_version</key>
    <string></string>
    <key>update_message</key>
    <string>A new version is available. Please update for the best experience.</string>

    <!-- UI Configuration -->
    <key>max_message_history</key>
    <integer>50</integer>
    <key>session_timeout_minutes</key>
    <integer>30</integer>

    <!-- Backend Configuration -->
    <key>api_timeout_seconds</key>
    <integer>30</integer>
    <key>websocket_reconnect_delay_ms</key>
    <integer>1000</integer>
</dict>
</plist>
```

---

## Phase 7: Analytics Events (Comprehensive)

> Tracking: Session patterns, Feature adoption, Performance issues, User journey

### 7.1 Create AnalyticsEvents.swift

**File:** `CodingBridge/Utilities/AnalyticsEvents.swift`

```swift
import FirebaseAnalytics

/// Comprehensive analytics event logging
/// Categories: Session, Feature, Performance, Navigation, Error
enum AnalyticsEvents {

    // MARK: - Session Patterns

    /// Log when a chat session starts
    static func logSessionStart(projectPath: String, isNewSession: Bool) {
        Analytics.logEvent("session_start", parameters: [
            "project_hash": String(projectPath.hashValue),
            "is_new_session": isNewSession
        ])
    }

    /// Log when a session ends with engagement metrics
    static func logSessionEnd(
        duration: TimeInterval,
        messageCount: Int,
        toolsUsed: Int
    ) {
        Analytics.logEvent("session_end", parameters: [
            "duration_seconds": Int(duration),
            "message_count": messageCount,
            "tools_used": toolsUsed,
            "duration_bucket": durationBucket(duration)
        ])
    }

    /// Log time between sessions (engagement tracking)
    static func logSessionGap(hoursSinceLastSession: Int) {
        Analytics.logEvent("session_gap", parameters: [
            "hours_since_last": min(hoursSinceLastSession, 720), // Cap at 30 days
            "gap_bucket": gapBucket(hoursSinceLastSession)
        ])
    }

    // MARK: - Feature Adoption

    /// Log feature usage with first-time detection
    static func logFeatureUsed(
        _ feature: Feature,
        isFirstTime: Bool = false
    ) {
        Analytics.logEvent("feature_used", parameters: [
            "feature_name": feature.rawValue,
            "is_first_time": isFirstTime
        ])

        // Log discovery event separately for first-time usage
        if isFirstTime {
            Analytics.logEvent("feature_discovered", parameters: [
                "feature_name": feature.rawValue
            ])
        }
    }

    enum Feature: String {
        case ssh = "ssh_terminal"
        case ideas = "ideas"
        case bookmarks = "bookmarks"
        case commands = "saved_commands"
        case history = "session_history"
        case imageAttachment = "image_attachment"
        case voiceInput = "voice_input"
        case slashCommand = "slash_command"
        case projectSwitching = "project_switching"
        case gitStatus = "git_status"
        case export = "export_session"
    }

    /// Log message sent with context
    static func logMessageSent(
        hasAttachments: Bool,
        attachmentCount: Int = 0,
        isVoice: Bool = false,
        characterCount: Int
    ) {
        Analytics.logEvent("message_sent", parameters: [
            "has_attachments": hasAttachments,
            "attachment_count": attachmentCount,
            "is_voice": isVoice,
            "char_count_bucket": charCountBucket(characterCount)
        ])
    }

    // MARK: - Performance Issues

    /// Log API response times and issues
    static func logAPIPerformance(
        endpoint: String,
        durationMs: Int,
        success: Bool,
        statusCode: Int? = nil
    ) {
        Analytics.logEvent("api_performance", parameters: [
            "endpoint": endpoint,
            "duration_ms": durationMs,
            "success": success,
            "status_code": statusCode ?? 0,
            "is_slow": durationMs > 3000
        ])
    }

    /// Log connection issues
    static func logConnectionIssue(
        type: ConnectionIssueType,
        retryCount: Int = 0
    ) {
        Analytics.logEvent("connection_issue", parameters: [
            "issue_type": type.rawValue,
            "retry_count": retryCount
        ])
    }

    enum ConnectionIssueType: String {
        case timeout = "timeout"
        case sseDisconnect = "sse_disconnect"
        case sshFailure = "ssh_failure"
        case networkUnavailable = "network_unavailable"
        case serverError = "server_error"
    }

    /// Log app startup performance
    static func logAppStartup(durationMs: Int, isFirstLaunch: Bool) {
        Analytics.logEvent("app_startup", parameters: [
            "duration_ms": durationMs,
            "is_first_launch": isFirstLaunch,
            "is_slow": durationMs > 2000
        ])
    }

    // MARK: - User Journey / Navigation

    /// Log screen views with context
    static func logScreenView(
        _ screen: Screen,
        fromScreen: Screen? = nil
    ) {
        var params: [String: Any] = [
            AnalyticsParameterScreenName: screen.rawValue,
            AnalyticsParameterScreenClass: screen.rawValue
        ]
        if let from = fromScreen {
            params["from_screen"] = from.rawValue
        }
        Analytics.logEvent(AnalyticsEventScreenView, parameters: params)
    }

    enum Screen: String {
        case projectList = "project_list"
        case chat = "chat"
        case settings = "settings"
        case sshTerminal = "ssh_terminal"
        case ideas = "ideas"
        case bookmarks = "bookmarks"
        case commands = "commands"
        case history = "history"
        case projectDetail = "project_detail"
    }

    /// Log navigation patterns
    static func logNavigation(from: Screen, to: Screen, trigger: NavigationTrigger) {
        Analytics.logEvent("navigation", parameters: [
            "from_screen": from.rawValue,
            "to_screen": to.rawValue,
            "trigger": trigger.rawValue
        ])
    }

    enum NavigationTrigger: String {
        case tap = "tap"
        case swipe = "swipe"
        case deepLink = "deep_link"
        case notification = "notification"
        case backButton = "back_button"
    }

    /// Log potential drop-off points
    static func logDropOff(
        screen: Screen,
        action: String,
        reason: String? = nil
    ) {
        Analytics.logEvent("drop_off", parameters: [
            "screen": screen.rawValue,
            "action": action,
            "reason": reason ?? "unknown"
        ])
    }

    // MARK: - Errors

    /// Log errors with context
    static func logError(
        type: ErrorType,
        message: String,
        screen: Screen? = nil,
        isFatal: Bool = false
    ) {
        Analytics.logEvent("app_error", parameters: [
            "error_type": type.rawValue,
            "error_message": String(message.prefix(100)),
            "screen": screen?.rawValue ?? "unknown",
            "is_fatal": isFatal
        ])
    }

    enum ErrorType: String {
        case network = "network"
        case parsing = "parsing"
        case ssh = "ssh"
        case storage = "storage"
        case permission = "permission"
        case unknown = "unknown"
    }

    // MARK: - SSH Specific

    static func logSSHConnection(success: Bool, durationMs: Int? = nil) {
        var params: [String: Any] = ["success": success]
        if let duration = durationMs {
            params["duration_ms"] = duration
        }
        Analytics.logEvent("ssh_connection", parameters: params)
    }

    static func logSSHCommand(commandType: String, durationMs: Int) {
        Analytics.logEvent("ssh_command", parameters: [
            "command_type": commandType,
            "duration_ms": durationMs
        ])
    }

    // MARK: - Helper Functions (Bucketing for better analytics)

    private static func durationBucket(_ seconds: TimeInterval) -> String {
        switch Int(seconds) {
        case 0..<30: return "0-30s"
        case 30..<120: return "30s-2m"
        case 120..<300: return "2-5m"
        case 300..<900: return "5-15m"
        case 900..<1800: return "15-30m"
        default: return "30m+"
        }
    }

    private static func gapBucket(_ hours: Int) -> String {
        switch hours {
        case 0..<1: return "within_hour"
        case 1..<24: return "same_day"
        case 24..<72: return "1-3_days"
        case 72..<168: return "3-7_days"
        default: return "week+"
        }
    }

    private static func charCountBucket(_ count: Int) -> String {
        switch count {
        case 0..<50: return "short"
        case 50..<200: return "medium"
        case 200..<500: return "long"
        default: return "very_long"
        }
    }
}
```

---

## Phase 8: Testing

### 8.1 Test Crashlytics

Add temporary test crash button (remove before release):

```swift
// In SettingsView.swift (DEBUG only)
#if DEBUG
Button("Test Crash") {
    fatalError("Test crash for Crashlytics")
}
#endif
```

### 8.2 Test FCM

1. Build and run on physical device
2. Check Xcode console for FCM token
3. Send test message from Firebase Console → Cloud Messaging

### 8.3 Test Analytics

1. Enable DebugView: Edit Scheme → Run → Arguments
2. Add: `-FIRAnalyticsDebugEnabled`
3. View events in Firebase Console → Analytics → DebugView

### 8.4 Unit Tests

**File:** `CodingBridgeTests/RemoteConfigManagerTests.swift`

```swift
import XCTest
@testable import CodingBridge

class RemoteConfigManagerTests: XCTestCase {
    func testRemoteConfigManagerSingleton() {
        let manager1 = RemoteConfigManager.shared
        let manager2 = RemoteConfigManager.shared
        XCTAssertTrue(manager1 === manager2)
    }

    func testRemoteConfigDefaults() {
        // Test that defaults plist exists
        let path = Bundle.main.path(forResource: "RemoteConfigDefaults", ofType: "plist")
        XCTAssertNotNil(path)
    }

    func testVersionComparison() {
        // Test version string comparison logic
        XCTAssertTrue("1.0.0".compare("0.9.0", options: .numeric) == .orderedDescending)
        XCTAssertTrue("1.0.0".compare("1.0.0", options: .numeric) == .orderedSame)
        XCTAssertTrue("1.0.0".compare("1.0.1", options: .numeric) == .orderedAscending)
    }
}

class AnalyticsEventsTests: XCTestCase {
    func testDurationBuckets() {
        // These would need to be exposed for testing, or test via integration
    }
}
```

---

## Phase 9: Version Update UI

### 9.1 Create VersionCheckView.swift

**File:** `CodingBridge/Views/VersionCheckView.swift`

```swift
import SwiftUI

/// Overlay view that checks app version against Remote Config
/// Shows update prompts when version is outdated
struct VersionCheckView<Content: View>: View {
    @ObservedObject var config = RemoteConfigManager.shared
    @State private var showUpdateAlert = false
    @State private var showForceUpdateSheet = false

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .onAppear {
                checkVersion()
            }
            .onChange(of: config.lastFetchTime) { _, _ in
                checkVersion()
            }
            .alert("Update Available", isPresented: $showUpdateAlert) {
                Button("Update Now") {
                    openAppStore()
                }
                Button("Later", role: .cancel) {}
            } message: {
                Text(config.updateMessage)
            }
            .sheet(isPresented: $showForceUpdateSheet) {
                ForceUpdateView(message: config.updateMessage)
                    .interactiveDismissDisabled() // Can't dismiss
            }
    }

    private func checkVersion() {
        if config.requiresForceUpdate {
            showForceUpdateSheet = true
        } else if !config.isCurrentVersionSupported {
            showUpdateAlert = true
        }
    }

    private func openAppStore() {
        // Replace with your App Store URL when published
        if let url = URL(string: "https://apps.apple.com/app/idXXXXXXXXXX") {
            UIApplication.shared.open(url)
        }
    }
}

/// Full-screen view for forced updates (cannot be dismissed)
struct ForceUpdateView: View {
    let message: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "arrow.down.app.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            Text("Update Required")
                .font(.largeTitle.bold())

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                openAppStore()
            } label: {
                Text("Update Now")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .padding()
    }

    private func openAppStore() {
        if let url = URL(string: "https://apps.apple.com/app/idXXXXXXXXXX") {
            UIApplication.shared.open(url)
        }
    }
}
```

### 9.2 Integrate Version Check in App

**Update `CodingBridgeApp.swift`:**

```swift
// Wrap MainTabView with version check
var body: some Scene {
    WindowGroup {
        VersionCheckView {
            ZStack(alignment: .top) {
                MainTabView()
                    .environmentObject(settings)
                ErrorBanner()
            }
        }
        .preferredColorScheme(settings.appTheme.colorScheme)
        // ... rest of modifiers
    }
}
```

---

## Phase 10: Analytics Instrumentation (Comprehensive)

### 10.1 First-Time Feature Tracking

**File:** `CodingBridge/Utilities/FeatureUsageTracker.swift`

```swift
import Foundation

/// Tracks first-time feature usage for analytics
class FeatureUsageTracker {
    static let shared = FeatureUsageTracker()

    private let defaults = UserDefaults.standard
    private let prefix = "feature_used_"

    private init() {}

    /// Check if this is the first time using a feature
    func isFirstTime(_ feature: AnalyticsEvents.Feature) -> Bool {
        let key = prefix + feature.rawValue
        return !defaults.bool(forKey: key)
    }

    /// Mark a feature as used
    func markUsed(_ feature: AnalyticsEvents.Feature) {
        let key = prefix + feature.rawValue
        defaults.set(true, forKey: key)
    }

    /// Log feature usage with automatic first-time detection
    func logFeatureUsage(_ feature: AnalyticsEvents.Feature) {
        let isFirst = isFirstTime(feature)
        AnalyticsEvents.logFeatureUsed(feature, isFirstTime: isFirst)
        if isFirst {
            markUsed(feature)
        }
    }
}
```

### 10.2 Integration Points by View

Add analytics calls to these views:

| View | Events to Add |
|------|---------------|
| `CodingBridgeApp.swift` | `app_startup` on launch |
| `ProjectListView.swift` | `screen_view`, `project_switching` |
| `ChatView.swift` | `session_start`, `session_end`, `message_sent` |
| `SettingsView.swift` | `screen_view`, feature toggles |
| `SSHTerminalView.swift` | `ssh_connection`, `ssh_command` |
| `IdeasView.swift` | `screen_view`, `feature_used` |
| `BookmarksView.swift` | `screen_view`, `feature_used` |
| `HistoryView.swift` | `screen_view`, `feature_used` |

### 10.3 Example: ChatView Instrumentation

```swift
// In ChatView.swift

struct ChatView: View {
    @State private var sessionStartTime = Date()
    @State private var messageCount = 0
    @State private var toolsUsedCount = 0

    var body: some View {
        content
            .onAppear {
                sessionStartTime = Date()
                AnalyticsEvents.logScreenView(.chat)
                AnalyticsEvents.logSessionStart(
                    projectPath: project.path,
                    isNewSession: session == nil
                )
            }
            .onDisappear {
                let duration = Date().timeIntervalSince(sessionStartTime)
                AnalyticsEvents.logSessionEnd(
                    duration: duration,
                    messageCount: messageCount,
                    toolsUsed: toolsUsedCount
                )
            }
    }

    func sendMessage() {
        messageCount += 1
        AnalyticsEvents.logMessageSent(
            hasAttachments: !attachments.isEmpty,
            attachmentCount: attachments.count,
            isVoice: isVoiceMessage,
            characterCount: messageText.count
        )
        // ... rest of send logic
    }

    func handleToolResult(_ tool: ToolType) {
        toolsUsedCount += 1
    }
}
```

### 10.4 Example: SSHTerminalView Instrumentation

```swift
// In SSHTerminalView.swift

.onAppear {
    AnalyticsEvents.logScreenView(.sshTerminal)
    FeatureUsageTracker.shared.logFeatureUsage(.ssh)
}

func connect() async {
    let startTime = Date()
    do {
        try await sshManager.connect()
        let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
        AnalyticsEvents.logSSHConnection(success: true, durationMs: durationMs)
    } catch {
        AnalyticsEvents.logSSHConnection(success: false)
        AnalyticsEvents.logError(
            type: .ssh,
            message: error.localizedDescription,
            screen: .sshTerminal
        )
    }
}
```

### 10.5 API Performance Tracking

**In `CLIBridgeAPIClient.swift`:**

```swift
// Wrap API calls with performance tracking
private func performRequest<T: Decodable>(
    endpoint: String,
    method: HTTPMethod
) async throws -> T {
    let startTime = Date()

    do {
        let result: T = try await actualRequest(endpoint: endpoint, method: method)
        let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)

        AnalyticsEvents.logAPIPerformance(
            endpoint: endpoint,
            durationMs: durationMs,
            success: true
        )

        return result
    } catch {
        let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)

        AnalyticsEvents.logAPIPerformance(
            endpoint: endpoint,
            durationMs: durationMs,
            success: false,
            statusCode: (error as? CLIBridgeAPIError)?.statusCode
        )

        throw error
    }
}
```

---

## Phase 11: Documentation Updates

### 11.1 Update CLAUDE.md

Add Firebase section:

```markdown
## Firebase

- **GoogleService-Info.plist**: Firebase configuration (DO NOT commit to git)
- **Remote Config**: Feature flags in `RemoteConfigDefaults.plist`
- **Analytics**: Events defined in `AnalyticsEvents.swift`

### Firebase Services
| Service | Purpose |
|---------|---------|
| FCM | Push notifications |
| Crashlytics | Crash reporting |
| Analytics | Usage analytics |
| Remote Config | Feature flags |
| Performance | App metrics |

### Key Files
| File | Purpose |
|------|---------|
| `PushNotificationManager.swift` | FCM token handling (extended) |
| `RemoteConfigManager.swift` | Feature flags singleton |
| `CrashlyticsHelper.swift` | Crash/error logging |
| `AnalyticsEvents.swift` | Event definitions |
| `FeatureUsageTracker.swift` | First-time detection |
| `VersionCheckView.swift` | Update prompt UI |
```

### 11.2 Update .gitignore

```gitignore
# Firebase
GoogleService-Info.plist
```

---

## Estimated Implementation Order

1. **User Steps** (Phase 1) - ~30 minutes (YOU do this)
2. **SPM Integration** (Phase 2) - ~15 minutes
3. **App Configuration** (Phase 3) - ~10 minutes
4. **Code Implementation** (Phase 4) - ~1-2 hours
5. **Crashlytics Build Phase** (Phase 5) - ~15 minutes
6. **Remote Config Defaults** (Phase 6) - ~10 minutes
7. **Analytics Events** (Phase 7) - ~30 minutes
8. **Testing** (Phase 8) - ~1 hour
9. **Version Update UI** (Phase 9) - ~20 minutes
10. **Analytics Instrumentation** (Phase 10) - ~1-2 hours
11. **Documentation** (Phase 11) - ~15 minutes

**Total: ~6-8 hours**

### New Files Created

| File | Purpose |
|------|---------|
| `CrashlyticsHelper.swift` | Error logging wrapper |
| `RemoteConfigManager.swift` | Feature flags singleton |
| `AnalyticsEvents.swift` | Event definitions |
| `FeatureUsageTracker.swift` | First-time tracking |
| `VersionCheckView.swift` | Update prompt UI |
| `RemoteConfigDefaults.plist` | Default config values |

### Existing Files Modified

| File | Changes |
|------|---------|
| `CodingBridgeApp.swift` | Firebase init, version check wrapper |
| `PushNotificationManager.swift` | MessagingDelegate conformance |
| `Info.plist` | FirebaseAppDelegateProxyEnabled |
| `CLIBridgeAPIClient.swift` | API performance tracking |
| `ChatView.swift` | Session/message analytics |
| `SSHTerminalView.swift` | SSH analytics |
| Multiple views | Screen view tracking |

---

## Troubleshooting

### FCM Token Not Received
1. Verify `GoogleService-Info.plist` is in bundle
2. Verify APNs key uploaded to Firebase Console
3. Check swizzling is disabled in Info.plist
4. Ensure running on physical device (simulator won't receive tokens)

### Crashlytics Not Reporting
1. Verify dSYM upload script is last build phase
2. Check Debug Information Format is "DWARF with dSYM"
3. Disable User Script Sandboxing if uploads fail
4. Wait up to 5 minutes for first crash to appear

### Remote Config Not Fetching
1. Verify internet connectivity
2. Check Firebase Console for config values
3. Reduce minimumFetchInterval for testing

### Build Errors
1. Clean build folder (Cmd+Shift+K)
2. Reset package caches (File → Packages → Reset Package Caches)
3. Verify Xcode 16.2 or later
