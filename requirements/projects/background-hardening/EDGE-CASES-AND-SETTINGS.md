# Edge Cases, Settings, and Additional Considerations

> Supplemental documentation covering gaps in the main specification.

## User Settings

### New Settings Required

Add to `AppSettings.swift`:

```swift
// MARK: - Background & Notifications

/// Enable Live Activities for task progress (default: true)
@AppStorage("enableLiveActivities") var enableLiveActivities = true

/// Enable background notifications when app not in foreground (default: true)
@AppStorage("enableBackgroundNotifications") var enableBackgroundNotifications = true

/// Show detailed content in notifications visible on Lock Screen (default: false)
/// When false, shows generic "Claude needs attention" instead of command details
@AppStorage("showNotificationDetails") var showNotificationDetails = false

/// Continue background processing in Low Power Mode (default: false)
/// When false, notifications only; no extended background runtime
@AppStorage("backgroundInLowPowerMode") var backgroundInLowPowerMode = false

/// Enable time-sensitive notifications that break through Focus modes (default: true)
@AppStorage("enableTimeSensitiveNotifications") var enableTimeSensitiveNotifications = true
```

### Settings UI

Add new section to SettingsView:

```swift
Section("Background & Notifications") {
    Toggle("Live Activities", isOn: $settings.enableLiveActivities)
        .onChange(of: settings.enableLiveActivities) { _, enabled in
            if !enabled {
                Task { await LiveActivityManager.shared.endCurrentActivity() }
            }
        }

    Toggle("Background Notifications", isOn: $settings.enableBackgroundNotifications)

    Toggle("Show Details on Lock Screen", isOn: $settings.showNotificationDetails)
        .help("When enabled, shows command names and content. When disabled, shows generic messages.")

    Toggle("Background in Low Power Mode", isOn: $settings.backgroundInLowPowerMode)
        .help("May impact battery life")

    Toggle("Break Through Focus Modes", isOn: $settings.enableTimeSensitiveNotifications)
        .help("Approval requests will appear even in Do Not Disturb")
}
```

### Permission Status Display

Show current permission status:

```swift
Section("Permissions") {
    HStack {
        Text("Notifications")
        Spacer()
        PermissionStatusBadge(status: notificationStatus)
    }

    HStack {
        Text("Live Activities")
        Spacer()
        PermissionStatusBadge(status: liveActivityStatus)
    }

    if notificationStatus == .denied || liveActivityStatus == .denied {
        Button("Open Settings") {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    }
}
```

## Multi-Session Handling

### iOS Live Activity Limits

iOS allows **only 1-2 active Live Activities per app**. Design decisions:

1. **Single Active Session Priority**
   - Only the most recently active session gets a Live Activity
   - Other sessions use notifications only
   - Store `activeSessionId` to track which session has the Live Activity

2. **Session Switching**
   ```swift
   func switchLiveActivityToSession(_ newSessionId: String) async {
       // End current Live Activity
       await endCurrentActivity()

       // Start new one for the new session
       try? await startActivity(for: newSessionId)
   }
   ```

3. **Multiple Approval Requests**
   - Queue approval requests if multiple arrive
   - Show most recent in Live Activity
   - Stack notifications (iOS groups them automatically)
   - Badge count = number of pending approvals

### Implementation

```swift
// In BackgroundManager

@Published var pendingApprovals: [ApprovalRequest] = []

func handleApprovalRequest(_ request: ApprovalRequest, sessionId: String) async {
    pendingApprovals.append(request)

    // Update badge
    await NotificationManager.shared.updateBadge(count: pendingApprovals.count)

    // Live Activity shows the most recent
    if sessionId == currentLiveActivitySessionId {
        await LiveActivityManager.shared.updateForApproval(request)
    }

    // Always send notification (they stack)
    await NotificationManager.shared.sendApprovalNotification(for: request)
}
```

## Network Connectivity

### NWPathMonitor Integration

```swift
// CodingBridge/Utilities/NetworkMonitor.swift

import Network

@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isConnected = true
    @Published private(set) var connectionType: ConnectionType = .unknown

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    enum ConnectionType {
        case wifi, cellular, wired, unknown
    }

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                self?.connectionType = self?.getConnectionType(path) ?? .unknown
            }
        }
        monitor.start(queue: queue)
    }

    private func getConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        if path.usesInterfaceType(.wiredEthernet) { return .wired }
        return .unknown
    }
}
```

### Network-Aware Background Behavior

```swift
// In BackgroundManager

private func handleNetworkChange(isConnected: Bool) async {
    if !isConnected && isAppInBackground {
        // Lost network while backgrounded
        await LiveActivityManager.shared.updateActivity(
            status: .processing,
            operation: "Waiting for connection...",
            elapsedSeconds: currentElapsedSeconds
        )

        // Don't send notification immediately - wait for recovery attempt
        scheduleConnectivityNotification()
    }
}

private func scheduleConnectivityNotification() {
    // If still disconnected after 30 seconds, notify user
    Task {
        try await Task.sleep(for: .seconds(30))

        if !NetworkMonitor.shared.isConnected {
            await NotificationManager.shared.sendNotification(
                title: "Connection Lost",
                body: "CodingBridge lost connection. Task will resume when connected.",
                category: .connectionLost
            )
        }
    }
}
```

## App Group for Widget Extension

### Setup Required

1. **Create App Group** in Apple Developer Portal:
   - Identifier: `group.com.codingbridge.shared`

2. **Add to both targets** (main app + widget extension):
   - Xcode → Target → Signing & Capabilities → + App Groups

3. **Entitlements file**:
   ```xml
   <key>com.apple.security.application-groups</key>
   <array>
       <string>group.com.codingbridge.shared</string>
   </array>
   ```

### Shared Data Access

```swift
// CodingBridge/Utilities/SharedContainer.swift

struct SharedContainer {
    static let groupIdentifier = "group.com.codingbridge.shared"

    static var containerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupIdentifier
        )
    }

    static func saveTaskState(_ state: TaskState) throws {
        guard let url = containerURL?.appendingPathComponent("taskState.json") else {
            throw SharedContainerError.urlNotFound
        }
        let data = try JSONEncoder().encode(state)
        try data.write(to: url)
    }

    static func loadTaskState() -> TaskState? {
        guard let url = containerURL?.appendingPathComponent("taskState.json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(TaskState.self, from: data)
    }
}
```

## Edge Cases

### 1. Notification Permission Denied

```swift
func handleNotificationPermissionDenied() async {
    // Fallback: Use in-app alerts even when backgrounded
    // When user returns, show prominent banner

    UserDefaults.standard.set(true, forKey: "missedNotificationsWhileBackgrounded")

    // On foreground return:
    if UserDefaults.standard.bool(forKey: "missedNotificationsWhileBackgrounded") {
        showMissedNotificationsBanner()
        UserDefaults.standard.set(false, forKey: "missedNotificationsWhileBackgrounded")
    }
}
```

### 2. Live Activities Disabled

```swift
func checkLiveActivityAvailability() -> LiveActivityStatus {
    let authInfo = ActivityAuthorizationInfo()

    if !authInfo.areActivitiesEnabled {
        // User disabled in iOS Settings
        return .disabledByUser
    }

    if !settings.enableLiveActivities {
        // User disabled in app settings
        return .disabledInApp
    }

    return .available
}

enum LiveActivityStatus {
    case available
    case disabledByUser
    case disabledInApp
    case notSupported
}
```

### 3. App Force-Quit During Processing

When user force-quits, we lose everything. On next launch:

```swift
// In CodingBridgeApp.init or first view appear

func handleColdStart() async {
    // Check if we were processing before force-quit
    if UserDefaults.standard.bool(forKey: "wasProcessing") {
        let sessionId = UserDefaults.standard.string(forKey: "lastSessionId")

        // Show recovery UI
        showRecoveryBanner(sessionId: sessionId)

        // Attempt to check session status via API
        if let status = try? await checkSessionStatus(sessionId: sessionId) {
            if status.isStillProcessing {
                // Offer to reattach
                showReattachOption(sessionId: sessionId)
            } else if status.needsApproval {
                // Show pending approval
                showPendingApproval(status.approvalRequest)
            }
        }
    }
}
```

### 4. Low Power Mode

```swift
func handleLowPowerModeChange(_ isLowPower: Bool) {
    if isLowPower && !settings.backgroundInLowPowerMode {
        // End extended background processing
        BackgroundManager.shared.endBackgroundTask()

        // Notify user
        if BackgroundManager.shared.isAppInBackground {
            NotificationManager.shared.sendNotification(
                title: "Low Power Mode",
                body: "Background processing paused to save battery. Open app to continue.",
                category: .lowPowerMode
            )
        }
    }
}

// Observe:
NotificationCenter.default.addObserver(
    forName: .NSProcessInfoPowerStateDidChange,
    object: nil,
    queue: .main
) { _ in
    handleLowPowerModeChange(ProcessInfo.processInfo.isLowPowerModeEnabled)
}
```

### 5. Device Restart During Task

Same as force-quit - we lose in-memory state. The `wasProcessing` flag in UserDefaults helps recover on next launch.

## Deep Links and Navigation

### Notification Navigation

```swift
// Add to userInfo in notifications
content.userInfo = [
    "type": "approval",
    "requestId": requestId,
    "sessionId": sessionId,
    "projectPath": projectPath,
    "deepLink": "codingbridge://session/\(sessionId)/approval/\(requestId)"
]

// Handle in NotificationManager
func handleNotificationTap(userInfo: [AnyHashable: Any]) {
    guard let deepLink = userInfo["deepLink"] as? String,
          let url = URL(string: deepLink) else { return }

    // Post to app for navigation
    NotificationCenter.default.post(
        name: .navigateToDeepLink,
        object: nil,
        userInfo: ["url": url]
    )
}

// In ContentView
.onOpenURL { url in
    handleDeepLink(url)
}
.onReceive(NotificationCenter.default.publisher(for: .navigateToDeepLink)) { notification in
    if let url = notification.userInfo?["url"] as? URL {
        handleDeepLink(url)
    }
}
```

### URL Scheme

Register in Info.plist:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>codingbridge</string>
        </array>
        <key>CFBundleURLName</key>
        <string>com.codingbridge.CodingBridge</string>
    </dict>
</array>
```

### Deep Link Routes

| URL Pattern | Action |
|-------------|--------|
| `codingbridge://session/{id}` | Navigate to session |
| `codingbridge://session/{id}/approval/{requestId}` | Show approval dialog |
| `codingbridge://session/{id}/question/{questionId}` | Show question |
| `codingbridge://settings/notifications` | Open notification settings |

## Analytics & Telemetry

### Metrics to Track

```swift
enum BackgroundMetric: String {
    // Notifications
    case notificationSent
    case notificationTapped
    case notificationDismissed
    case approvalFromNotification
    case denialFromNotification

    // Live Activities
    case liveActivityStarted
    case liveActivityEnded
    case liveActivityTapped

    // Background
    case backgroundTaskStarted
    case backgroundTaskCompleted
    case backgroundTaskExpired
    case backgroundRecoveryAttempted
    case backgroundRecoverySucceeded

    // Errors
    case pushTokenRegistrationFailed
    case liveActivityStartFailed
    case notificationDeliveryFailed
}

// Logging (respecting user privacy)
func trackMetric(_ metric: BackgroundMetric, properties: [String: Any]? = nil) {
    Logger.analytics.info("Metric: \(metric.rawValue)")

    // If analytics service configured:
    // AnalyticsService.shared.track(metric.rawValue, properties: properties)
}
```

### Success Metric Measurement

From OVERVIEW.md:

```swift
// 1. Zero missed approvals
var missedApprovalCount: Int {
    // Count approvals that timed out before user responded
    // Track in backend when approval expires without response
}

// 2. <5 second notification latency
func measureNotificationLatency(sentAt: Date, deliveredAt: Date) {
    let latency = deliveredAt.timeIntervalSince(sentAt)
    trackMetric(.notificationSent, properties: ["latency_ms": latency * 1000])
}

// 3. Graceful recovery rate >95%
var recoveryRate: Double {
    let attempts = UserDefaults.standard.integer(forKey: "recoveryAttempts")
    let successes = UserDefaults.standard.integer(forKey: "recoverySuccesses")
    guard attempts > 0 else { return 1.0 }
    return Double(successes) / Double(attempts)
}

// 4. Live Activity accuracy
// Manual testing / QA verification
```

## Localization

### Notification Strings

Create `Localizable.strings`:

```
/* Notifications */
"notification.approval.title" = "Approval Needed";
"notification.approval.body.generic" = "Claude needs permission to continue";
"notification.approval.body.detailed" = "Execute: %@";

"notification.question.title" = "Claude has a question";
"notification.complete.title" = "Task Complete";
"notification.complete.body.generic" = "Claude finished working";
"notification.error.title" = "Task Failed";
"notification.paused.title" = "Task Paused";
"notification.paused.body" = "Background time expired. Open app to continue.";

/* Live Activity */
"activity.processing" = "Processing";
"activity.awaiting_approval" = "Approval needed";
"activity.awaiting_answer" = "Question pending";
"activity.completed" = "Completed";
"activity.error" = "Error occurred";
"activity.elapsed" = "Elapsed: %@";
```

### Usage

```swift
func sendApprovalNotification(toolName: String, summary: String) async {
    let content = UNMutableNotificationContent()
    content.title = NSLocalizedString("notification.approval.title", comment: "")

    if settings.showNotificationDetails {
        content.body = String(format: NSLocalizedString("notification.approval.body.detailed", comment: ""), summary)
    } else {
        content.body = NSLocalizedString("notification.approval.body.generic", comment: "")
    }
    // ...
}
```

## Privacy Considerations

### Content Filtering for Lock Screen

```swift
func sanitizeForLockScreen(_ content: String) -> String {
    guard settings.showNotificationDetails else {
        return NSLocalizedString("notification.approval.body.generic", comment: "")
    }

    // Redact potential secrets
    var sanitized = content

    // Redact anything that looks like a token/key
    let patterns = [
        "(?i)(api[_-]?key|token|secret|password|credential)\\s*[:=]\\s*[\"']?[\\w-]+",
        "(?i)bearer\\s+[\\w-]+",
        "[A-Za-z0-9+/]{40,}={0,2}"  // Long base64 strings
    ]

    for pattern in patterns {
        if let regex = try? NSRegularExpression(pattern: pattern) {
            sanitized = regex.stringByReplacingMatches(
                in: sanitized,
                range: NSRange(sanitized.startIndex..., in: sanitized),
                withTemplate: "[REDACTED]"
            )
        }
    }

    return sanitized.prefix(200).description
}
```

## Integration Points with Existing Code

### WebSocketManager Callbacks Needed

Add to `WebSocketManager.swift`:

```swift
// Around line 95, add:
var onApprovalRequest: ((ApprovalRequest) async -> Void)?
var onQuestionAsked: ((UserQuestion) async -> Void)?
var onProcessingStarted: ((String) async -> Void)?  // sessionId
var onProcessingEnded: ((TaskResult) async -> Void)?
var onProgressUpdate: ((TodoProgress?) async -> Void)?

// In handleMessage() around line 700:
case "approval_request":
    let request = parseApprovalRequest(data)
    await onApprovalRequest?(request)

case "question":
    let question = parseQuestion(data)
    await onQuestionAsked?(question)

// etc.
```

### Connecting in ChatView

```swift
// In ChatView.onAppear():
wsManager.onApprovalRequest = { request in
    await BackgroundManager.shared.handleApprovalRequest(request)
}

wsManager.onProcessingStarted = { sessionId in
    if BackgroundManager.shared.isAppInBackground {
        try? await LiveActivityManager.shared.startActivity(...)
    }
}
```

## Testing Checklist Additions

Add to PHASES.md testing:

- [ ] Test with notifications permission denied
- [ ] Test with Live Activities disabled in iOS Settings
- [ ] Test force-quit during processing
- [ ] Test Low Power Mode behavior
- [ ] Test multi-session scenarios
- [ ] Test network loss while backgrounded
- [ ] Test deep link navigation from notification
- [ ] Test localized notification content
- [ ] Test sensitive content filtering
- [ ] Test approval timeout expiry
- [ ] Test session handoff to Mac
- [ ] Test memory pressure during background task
- [ ] Test multi-device approval clearing

## Approval Request Timeout

Backend enforces a 60-second timeout for approval requests. iOS app should handle this gracefully.

### Backend Behavior

When an approval request times out:
1. Backend sends `approval_timeout` WebSocket event
2. Claude logs a skip/error and continues (or stops, depending on tool)
3. Backend sends push notification to clear the approval

### iOS Handling

```swift
// Handle timeout event from WebSocket
case "approval_timeout":
    let requestId = data["requestId"] as? String ?? ""

    // Clear the notification
    await NotificationManager.shared.clearApprovalNotification(requestId: requestId)

    // Update Live Activity
    await LiveActivityManager.shared.updateActivity(
        status: .processing,
        operation: "Approval timed out - Claude continued",
        elapsedSeconds: currentElapsed
    )

    // Clear from pending approvals
    BackgroundManager.shared.pendingApprovals.removeAll { $0.id == requestId }
```

### Countdown Display (Optional Enhancement)

Show remaining time in Live Activity:

```swift
struct ApprovalInfo: Codable, Hashable {
    public let requestId: String
    public let toolName: String
    public let summary: String
    public let expiresAt: Date?  // NEW: When approval expires

    public var remainingSeconds: Int? {
        guard let expiresAt = expiresAt else { return nil }
        return max(0, Int(expiresAt.timeIntervalSinceNow))
    }
}

// In ApprovalRequestView:
if let remaining = approval.remainingSeconds {
    Text("\(remaining)s remaining")
        .font(.caption2)
        .foregroundStyle(.secondary)
}
```

## Session Handoff / Continuity

Handle scenario where user starts task on iPhone, then opens Mac with Claude Code running.

### Problem
1. User sends message on iPhone
2. Claude starts processing
3. User opens Mac and sends another message to same session
4. iPhone Live Activity becomes stale

### Detection

Backend tracks "active client" for each session:

```javascript
// Backend tracks which client last interacted
session.activeClient = {
  type: 'ios',  // or 'desktop', 'web'
  deviceId: 'device-123',
  lastActivityAt: Date.now()
}

// When different client sends message:
if (session.activeClient.deviceId !== newDeviceId) {
  // Notify old client to release Live Activity
  await sendHandoffNotification(session.activeClient.deviceId, sessionId);
  session.activeClient = { type: newType, deviceId: newDeviceId, lastActivityAt: Date.now() };
}
```

### iOS Handling

```swift
// Handle handoff push notification
func handleHandoffNotification(sessionId: String) async {
    // End Live Activity for this session
    if LiveActivityManager.shared.currentSessionId == sessionId {
        await LiveActivityManager.shared.endActivity(
            finalStatus: .completed,
            message: "Session continued on another device"
        )
    }

    // Show subtle notification
    await NotificationManager.shared.sendNotification(
        title: "Session Handed Off",
        body: "Continued on another device",
        category: .sessionStatus
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

## Data Protection Level

Ensure persisted state is accessible during background execution.

### The Problem

iOS data protection can prevent file access when device is locked:
- `NSFileProtectionComplete`: Files inaccessible when locked
- `NSFileProtectionCompleteUntilFirstUserAuthentication`: Files accessible after first unlock

Background tasks run while device is locked, so we need the latter.

### Implementation

```swift
// In all persistence classes (MessageQueuePersistence, DraftInputPersistence, etc.)

private func setDataProtection(for url: URL) {
    do {
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
    } catch {
        Logger.background.error("Failed to set data protection: \(error)")
    }
}

// Call after creating/writing files:
func save() async {
    // ... write data ...
    setDataProtection(for: fileURL)
}
```

### Keychain for Sensitive Data

For truly sensitive data (like stored credentials), use Keychain with appropriate accessibility:

```swift
// In KeychainHelper
func save(_ data: Data, forKey key: String, accessible: CFString = kSecAttrAccessibleAfterFirstUnlock) throws {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecValueData as String: data,
        kSecAttrAccessible as String: accessible  // Allows background access
    ]
    // ...
}
```

## Memory Pressure Handling

iOS may terminate background tasks or widget extensions under memory pressure.

### Widget Extension Limits

- Widget extensions have ~30MB memory limit
- Live Activity UI should be lightweight
- Avoid loading large images or complex views

### Defensive Coding

```swift
// In LiveActivityManager

private var lastKnownState: CodingBridgeActivityAttributes.ContentState?

func updateActivity(...) async {
    // Save state before update in case of termination
    lastKnownState = newState
    saveStateToSharedContainer(newState)

    // Perform update
    await activity.update(...)
}

// In widget extension, load from shared container if needed:
struct CodingBridgeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CodingBridgeActivityAttributes.self) { context in
            // context.state comes from ActivityKit
            // If stale, we could load from shared container as fallback
            LockScreenView(context: context)
        }
    }
}
```

### Background Task Checkpointing

```swift
// In BackgroundManager

private func handleBackgroundProcessing(_ task: BGProcessingTask) async {
    // Set expiration handler immediately
    task.expirationHandler = { [weak self] in
        Task { @MainActor in
            await self?.checkpoint()
            await self?.handleTaskExpiration()
        }
    }

    // Periodic checkpointing during long tasks
    let checkpointTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
        Task { @MainActor in
            await self.checkpoint()
        }
    }

    // ... do work ...

    checkpointTimer.invalidate()
}

private func checkpoint() async {
    Logger.background.debug("Checkpointing state")
    await MessageQueuePersistence.shared.save()
    await DraftInputPersistence.shared.save()

    if let state = currentTaskState {
        SharedContainer.saveTaskState(state)
    }
}
```

### Memory Warning Handling

```swift
// In CodingBridgeApp or BackgroundManager

func setupMemoryWarningHandler() {
    NotificationCenter.default.addObserver(
        forName: UIApplication.didReceiveMemoryWarningNotification,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        Logger.background.warning("Received memory warning")
        Task { @MainActor in
            await self?.handleMemoryPressure()
        }
    }
}

private func handleMemoryPressure() async {
    // Save critical state immediately
    await checkpoint()

    // Clear non-essential caches
    // URLCache.shared.removeAllCachedResponses()

    // Log for debugging
    let memoryUsage = ProcessInfo.processInfo.physicalMemory
    Logger.background.warning("Memory pressure at \(memoryUsage) bytes")
}
