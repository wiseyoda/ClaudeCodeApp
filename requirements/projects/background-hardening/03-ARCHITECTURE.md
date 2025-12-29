# Architecture Overview

## System Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              iOS App                                     │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐  │
│  │  ChatView       │  │ WebSocketManager│  │   BackgroundManager     │  │
│  │  (UI Layer)     │◀─┤  (Connection)   │◀─┤   (Coordination)        │  │
│  └────────┬────────┘  └────────┬────────┘  └───────────┬─────────────┘  │
│           │                    │                       │                │
│  ┌────────▼────────┐  ┌────────▼────────┐  ┌──────────▼──────────┐    │
│  │ ApprovalBanner  │  │  TaskState      │  │  LiveActivityManager │    │
│  │ (Foreground UI) │  │  (Shared State) │  │  (ActivityKit)       │    │
│  └─────────────────┘  └────────┬────────┘  └──────────┬──────────┘    │
│                                │                       │                │
│                       ┌────────▼────────┐  ┌──────────▼──────────┐    │
│                       │ NotificationMgr │  │  FCMTokenManager    │    │
│                       │ (Local + Push)  │  │  (Firebase + APNs)  │    │
│                       └─────────────────┘  └─────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ WebSocket
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           claudecodeui Backend                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐  │
│  │  WebSocket      │  │  Session API    │  │   Firebase Admin SDK    │  │
│  │  Handler        │  │  Endpoints      │  │   (Phase 3)             │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ Firebase Cloud Messaging
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    Firebase Cloud Messaging (FCM)                        │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ APNs (managed by Firebase)
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    Apple Push Notification Service                       │
└─────────────────────────────────────────────────────────────────────────┘
```

## Why Firebase?

Using Firebase Cloud Messaging instead of direct APNs integration:

| Benefit | Description |
|---------|-------------|
| Simpler backend | Firebase Admin SDK handles APNs protocol complexity |
| Token management | FCM handles token refresh/rotation automatically |
| Cross-platform ready | Same backend code works for Android if needed |
| Free tier | Generous limits for personal/small-scale apps |
| Analytics | Built-in delivery metrics and debugging |

Trade-offs:
- Adds ~100-300ms latency (extra hop through Firebase)
- Requires FCM token + APNs token (2 tokens vs 1)
- Google dependency

For this use case (approval notifications, Live Activity updates), the trade-offs are acceptable.

## New Components

| Component | Purpose | Location |
|-----------|---------|----------|
| BackgroundManager | Central coordinator for background tasks | `Managers/BackgroundManager.swift` |
| LiveActivityManager | ActivityKit lifecycle management | `Managers/LiveActivityManager.swift` |
| NotificationManager | Push/local notifications | `Managers/NotificationManager.swift` |
| FCMTokenManager | Firebase + APNs token handling | `Managers/FCMTokenManager.swift` |
| TaskState | Shared task state model | `Models/TaskState.swift` |

## File Structure

```
CodingBridge/
├── Managers/
│   ├── BackgroundManager.swift      # NEW - Central coordinator
│   ├── LiveActivityManager.swift    # NEW - ActivityKit management
│   ├── NotificationManager.swift    # NEW - Push/local notifications
│   ├── FCMTokenManager.swift        # NEW - Firebase + APNs tokens
│   ├── WebSocketManager.swift       # MODIFIED - Add state callbacks
│   └── SSHManager.swift             # UNCHANGED
├── Models/
│   ├── TaskState.swift              # NEW - Shared task state model
│   └── Models.swift                 # MODIFIED - Add persistence helpers
├── Persistence/
│   ├── MessageQueuePersistence.swift    # NEW
│   ├── DraftInputPersistence.swift      # NEW
│   └── SharedContainer.swift            # NEW - App Group access
├── Utilities/
│   └── NetworkMonitor.swift         # NEW
├── GoogleService-Info.plist         # NEW - Firebase config (from console)
└── CodingBridgeApp.swift            # MODIFIED - Register tasks, Firebase init

CodingBridgeWidgets/                 # NEW - Widget extension target
├── CodingBridgeWidgets.swift
├── CodingBridgeActivityAttributes.swift
└── Views/
    ├── LockScreenView.swift
    ├── StatusIcon.swift
    ├── ElapsedTimeView.swift
    └── ApprovalRequestView.swift
```

## Info.plist Additions

```xml
<!-- Background task identifiers -->
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.codingbridge.task.continued-processing</string>
    <string>com.codingbridge.task.refresh</string>
</array>

<!-- Background modes -->
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>processing</string>
    <string>remote-notification</string>
</array>
```

## Thread Safety

All new managers use `@MainActor`:

```swift
@MainActor
final class BackgroundManager: ObservableObject { }
```

Background task handlers dispatch to MainActor:

```swift
BGTaskScheduler.shared.register(...) { task in
    Task { @MainActor in
        await self.handleTask(task)
    }
}
```

---
**Prev:** [States](./02-STATES.md) | **Phase 1:** [phase-1/](./phase-1/) | **Index:** [00-INDEX.md](./00-INDEX.md)
