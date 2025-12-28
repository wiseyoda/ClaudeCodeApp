# Architecture Design

> System architecture for background task hardening, Live Activities, and notifications.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              iOS App                                     │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐  │
│  │  ChatView       │  │ WebSocketManager│  │   BackgroundManager     │  │
│  │  (UI Layer)     │◄─┤  (Connection)   │◄─┤   (Coordination)        │  │
│  └────────┬────────┘  └────────┬────────┘  └───────────┬─────────────┘  │
│           │                    │                       │                │
│           │                    │                       │                │
│  ┌────────▼────────┐  ┌────────▼────────┐  ┌──────────▼──────────┐    │
│  │ ApprovalBanner  │  │  TaskState      │  │  LiveActivityManager │    │
│  │ (Foreground UI) │  │  (Shared State) │  │  (ActivityKit)       │    │
│  └─────────────────┘  └────────┬────────┘  └──────────┬──────────┘    │
│                                │                       │                │
│                       ┌────────▼────────┐  ┌──────────▼──────────┐    │
│                       │ NotificationMgr │  │  PushTokenManager   │    │
│                       │ (Local + Push)  │  │  (APNs Registration)│    │
│                       └─────────────────┘  └─────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ WebSocket / APNs
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           claudecodeui Backend                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐  │
│  │  WebSocket      │  │  Session API    │  │   APNs Integration      │  │
│  │  Handler        │  │  Endpoints      │  │   (New)                 │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ APNs HTTP/2
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    Apple Push Notification Service                       │
└─────────────────────────────────────────────────────────────────────────┘
```

## New Components

### 1. BackgroundManager

**Purpose:** Central coordinator for all background-related functionality.

**Responsibilities:**
- Register background task identifiers at app launch
- Coordinate between WebSocketManager, LiveActivityManager, and NotificationManager
- Handle app lifecycle transitions (foreground ↔ background)
- Manage state persistence during backgrounding
- Register/schedule background tasks as needed

**Location:** `CodingBridge/Managers/BackgroundManager.swift`

```swift
@MainActor
final class BackgroundManager: ObservableObject {
    static let shared = BackgroundManager()

    // Dependencies
    private let liveActivityManager: LiveActivityManager
    private let notificationManager: NotificationManager
    private let pushTokenManager: PushTokenManager

    // State
    @Published var isBackgrounded = false
    @Published var hasActiveLiveActivity = false

    // Background task identifiers
    static let processingTaskIdentifier = "com.codingbridge.task.processing"
    static let refreshTaskIdentifier = "com.codingbridge.task.refresh"

    func registerBackgroundTasks()
    func handleScenePhaseChange(_ phase: ScenePhase)
    func startBackgroundProcessing(for taskState: TaskState)
    func endBackgroundProcessing()
}
```

### 2. LiveActivityManager

**Purpose:** Manage Live Activity lifecycle and updates.

**Responsibilities:**
- Start Live Activities when task begins (if backgrounded)
- Update Live Activity with progress and status changes
- Handle 8-hour timeout gracefully
- Manage push token for Live Activity updates
- End Live Activity on task completion

**Location:** `CodingBridge/Managers/LiveActivityManager.swift`

```swift
@MainActor
final class LiveActivityManager: ObservableObject {
    @Published var currentActivity: Activity<CodingBridgeActivityAttributes>?
    @Published var pushToken: String?

    func startActivity(for task: TaskState) async throws
    func updateActivity(with state: TaskState) async
    func endActivity(with result: TaskResult) async
    func handlePushTokenUpdate(_ token: Data)
}
```

### 3. NotificationManager

**Purpose:** Handle all notification-related functionality.

**Responsibilities:**
- Request notification permissions
- Configure notification categories and actions
- Send local notifications
- Handle notification responses (approve/deny actions)
- Coordinate with delegate for user interactions

**Location:** `CodingBridge/Managers/NotificationManager.swift`

```swift
@MainActor
final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    // Notification categories
    static let approvalCategory = "APPROVAL_REQUEST"
    static let questionCategory = "QUESTION_ASKED"
    static let completionCategory = "TASK_COMPLETE"

    func requestPermissions() async -> Bool
    func configureCategories()
    func sendApprovalNotification(for request: ApprovalRequest)
    func sendQuestionNotification(for question: UserQuestion)
    func sendCompletionNotification(for result: TaskResult)

    // Delegate methods for handling user actions
    func userNotificationCenter(_:didReceive:) async
}
```

### 4. PushTokenManager

**Purpose:** Manage APNs push token registration and updates.

**Responsibilities:**
- Register for remote notifications
- Handle push token updates
- Send tokens to backend
- Manage Live Activity push tokens separately from device token

**Location:** `CodingBridge/Managers/PushTokenManager.swift`

```swift
@MainActor
final class PushTokenManager: ObservableObject {
    @Published var devicePushToken: String?
    @Published var liveActivityPushToken: String?

    func registerForRemoteNotifications()
    func handleDeviceToken(_ token: Data)
    func sendTokenToBackend(_ token: String, type: TokenType) async throws
    func invalidatePreviousToken(_ token: String) async throws
}
```

### 5. TaskState (Shared Model)

**Purpose:** Unified representation of current task state shared across components.

**Location:** `CodingBridge/Models/TaskState.swift`

```swift
enum TaskStatus: Codable {
    case idle
    case processing(operation: String?)
    case awaitingApproval(request: ApprovalRequest)
    case awaitingAnswer(question: UserQuestion)
    case completed(result: TaskResult)
    case error(message: String)
}

struct TaskState: Codable {
    let sessionId: String
    let projectPath: String
    let status: TaskStatus
    let startTime: Date
    let lastUpdateTime: Date
    let elapsedSeconds: Int
    let todoProgress: TodoProgress?  // If TodoWrite was used
}

struct TodoProgress: Codable {
    let completed: Int
    let total: Int
    let currentTask: String?
}

struct ApprovalRequest: Codable {
    let id: String
    let toolName: String
    let summary: String
    let details: String?
}

struct UserQuestion: Codable {
    let id: String
    let question: String
    let options: [String]?
}

enum TaskResult: Codable {
    case success(summary: String?)
    case failure(error: String)
    case cancelled
}
```

## Component Interactions

### Flow 1: User Backgrounds App During Processing

```
┌──────────┐    ┌─────────────────┐    ┌───────────────────┐    ┌─────────────────┐
│ ChatView │───▶│ BackgroundManager│───▶│ LiveActivityManager│───▶│    ActivityKit   │
└──────────┘    └─────────────────┘    └───────────────────┘    └─────────────────┘
     │                  │                        │                        │
     │ scenePhase       │ handleScenePhase       │ startActivity          │
     │ = .background    │ (.background)          │ (taskState)            │
     │                  │                        │                        │
     │                  │                        │◀───────────────────────│
     │                  │                        │  Activity<Attributes>  │
     │                  │                        │                        │
     │                  │ Register BGTask        │                        │
     │                  │────────────────────────────────────────────────▶│
     │                  │                        │                 BGTaskScheduler
     │                  │                        │                        │
     │                  │ Send pushToken         │                        │
     │                  │ to backend             │                        │
     │                  │─────────────────────────────────────────────────▶
                                                                   Backend
```

### Flow 2: Approval Request While Backgrounded

```
┌──────────┐    ┌──────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Backend  │───▶│ WebSocketManager │───▶│ BackgroundManager│───▶│NotificationManager│
└──────────┘    └──────────────────┘    └─────────────────┘    └─────────────────┘
     │                   │                       │                       │
     │ approval_request  │ onApprovalRequest     │ handleApprovalRequest │
     │ (WebSocket)       │ callback              │                       │
     │                   │                       │                       │
     │                   │                       │                       │
     │                   │                       │──────────────────────▶│
     │                   │                       │  sendApprovalNotif    │
     │                   │                       │                       │
     │                   │                       │      Also update      │
     │                   │                       │──────────────────────▶│
     │                   │                       │   LiveActivityManager │
     │                   │                       │   (status: awaiting)  │
```

### Flow 3: User Approves from Notification

```
┌──────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌──────────────────┐
│   User   │───▶│  UNNotification │───▶│NotificationManager│───▶│ WebSocketManager │
└──────────┘    └─────────────────┘    └─────────────────┘    └──────────────────┘
     │                   │                       │                       │
     │ Tap "Approve"     │ didReceive response   │ handleApprovalAction  │
     │                   │                       │                       │
     │                   │                       │                       │
     │                   │                       │──────────────────────▶│
     │                   │                       │ sendApprovalResponse  │
     │                   │                       │ (approved: true)      │
     │                   │                       │                       │
     │                   │                       │      Also update      │
     │                   │                       │──────────────────────▶│
     │                   │                       │   LiveActivityManager │
     │                   │                       │   (status: processing)│
```

### Flow 4: Push Notification Failure with Fallback

When push notification fails, the system falls back to local notification when app becomes active.

```
┌──────────┐    ┌──────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Backend  │───▶│  APNs            │───X│  iOS Device     │    │NotificationManager│
└──────────┘    └──────────────────┘    └─────────────────┘    └─────────────────┘
     │                   │                       │                       │
     │ Send push         │                       │                       │
     │ (approval needed) │                       │                       │
     │                   │                       │                       │
     │                   │ Push fails            │                       │
     │◀──────────────────│ (BadDeviceToken,      │                       │
     │                   │  network error)       │                       │
     │                   │                       │                       │
     │ Mark token        │                       │                       │
     │ invalid           │                       │                       │
     │                   │                       │                       │
     │ Store pending     │                       │                       │
     │ notification in   │                       │                       │
     │ database          │                       │                       │
     │                   │                       │                       │
     │                   │ ... time passes ...   │                       │
     │                   │                       │                       │
     │◀──────────────────────────────────────────│                       │
     │            App becomes active,            │                       │
     │            connects via WebSocket         │                       │
     │                   │                       │                       │
     │ Send pending      │                       │                       │
     │ notifications     │                       │                       │
     │ via WebSocket     │                       │                       │
     │───────────────────────────────────────────▶                       │
     │                   │        WebSocket      │                       │
     │                   │        message        │                       │
     │                   │                       │──────────────────────▶│
     │                   │                       │   Handle as local     │
     │                   │                       │   notification or     │
     │                   │                       │   in-app banner       │
```

### Push Failure Handling (Backend Logic)

```javascript
// When push fails, store for later delivery
async function handlePushFailure(userId, sessionId, payload, error) {
  // Mark token as potentially invalid
  if (error.reason === 'BadDeviceToken') {
    await db.run(
      'UPDATE push_tokens SET is_valid = FALSE WHERE token = ?',
      [payload.deviceToken]
    );
  }

  // Store pending notification for WebSocket delivery
  await db.run(`
    INSERT INTO pending_notifications (user_id, session_id, payload, created_at)
    VALUES (?, ?, ?, CURRENT_TIMESTAMP)
  `, [userId, sessionId, JSON.stringify(payload)]);
}

// On WebSocket connection, deliver pending notifications
async function handleWebSocketConnect(userId, sessionId, ws) {
  const pending = await db.all(
    'SELECT * FROM pending_notifications WHERE user_id = ? ORDER BY created_at',
    [userId]
  );

  for (const notification of pending) {
    ws.send(JSON.stringify({
      type: 'missed_notification',
      payload: JSON.parse(notification.payload)
    }));

    await db.run('DELETE FROM pending_notifications WHERE id = ?', [notification.id]);
  }
}
```

## State Machine

```
                            ┌─────────────┐
                            │    Idle     │
                            └──────┬──────┘
                                   │ User sends message
                                   ▼
                            ┌─────────────┐
                   ┌───────▶│ Processing  │◀───────┐
                   │        └──────┬──────┘        │
                   │               │               │
         Approval  │               │               │ User answers
         granted   │       ┌───────┴───────┐       │ question
                   │       │               │       │
                   │       ▼               ▼       │
            ┌──────┴──────┐         ┌──────┴──────┐
            │  Awaiting   │         │  Awaiting   │
            │  Approval   │         │   Answer    │
            └──────┬──────┘         └──────┬──────┘
                   │                       │
                   │ Approval denied       │ User cancels
                   │       │               │
                   │       ▼               ▼
                   │    ┌─────────────────────┐
                   └───▶│      Complete       │◀──── Task finishes
                        │  (success/failure)  │
                        └──────────┬──────────┘
                                   │
                                   │ New task
                                   ▼
                            ┌─────────────┐
                            │    Idle     │
                            └─────────────┘
```

## File Structure

```
CodingBridge/
├── Managers/
│   ├── BackgroundManager.swift      # NEW - Central coordinator
│   ├── LiveActivityManager.swift    # NEW - ActivityKit management
│   ├── NotificationManager.swift    # NEW - Push/local notifications
│   ├── PushTokenManager.swift       # NEW - APNs token handling
│   ├── WebSocketManager.swift       # MODIFIED - Add state callbacks
│   └── SSHManager.swift             # UNCHANGED
├── Models/
│   ├── TaskState.swift              # NEW - Shared task state model
│   ├── Models.swift                 # MODIFIED - Add persistence helpers
│   └── ...
├── Views/
│   ├── ChatView.swift               # MODIFIED - Use BackgroundManager
│   └── ...
├── LiveActivity/
│   ├── CodingBridgeActivityAttributes.swift  # NEW - Activity definition
│   ├── CodingBridgeLiveActivity.swift        # NEW - UI for Live Activity
│   └── CodingBridgeWidgetBundle.swift        # NEW - Widget extension entry
└── CodingBridgeApp.swift            # MODIFIED - Register tasks, delegate
```

## Info.plist Additions

```xml
<!-- Background task identifiers -->
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.codingbridge.task.processing</string>
    <string>com.codingbridge.task.refresh</string>
</array>

<!-- Background modes -->
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>processing</string>
    <string>remote-notification</string>
</array>

<!-- Push notification entitlement -->
<key>aps-environment</key>
<string>development</string>  <!-- or "production" -->
```

## Widget Extension Target

A new widget extension target is required for Live Activities:

```
CodingBridgeWidgets/
├── CodingBridgeWidgets.swift        # Widget bundle entry point
├── CodingBridgeActivityAttributes.swift  # Shared with main app
└── CodingBridgeLiveActivity.swift   # Live Activity UI views
```

## Thread Safety Considerations

All new managers use `@MainActor` to ensure thread safety:

```swift
@MainActor
final class BackgroundManager: ObservableObject {
    // All @Published properties safe to update from any context
    // through MainActor isolation
}
```

Background task handlers execute off main thread, so they must dispatch to MainActor:

```swift
BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.processingTaskIdentifier, using: nil) { task in
    Task { @MainActor in
        await self.handleBackgroundProcessing(task: task as! BGProcessingTask)
    }
}
```

## Error Handling Strategy

Each component has defined error types:

```swift
enum BackgroundError: Error {
    case liveActivityNotSupported
    case pushTokenRegistrationFailed
    case taskAlreadyRunning
    case sessionNotActive
}

enum NotificationError: Error {
    case permissionDenied
    case categoryNotConfigured
    case deliveryFailed
}
```

Errors are logged and, where appropriate, surfaced to the user via the existing error handling flow.
