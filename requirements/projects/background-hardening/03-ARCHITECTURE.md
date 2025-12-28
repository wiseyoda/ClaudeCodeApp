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
│  │  Handler        │  │  Endpoints      │  │   (Phase 3)             │  │
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

| Component | Purpose | Location |
|-----------|---------|----------|
| BackgroundManager | Central coordinator for background tasks | `Managers/BackgroundManager.swift` |
| LiveActivityManager | ActivityKit lifecycle management | `Managers/LiveActivityManager.swift` |
| NotificationManager | Push/local notifications | `Managers/NotificationManager.swift` |
| PushTokenManager | APNs token handling | `Managers/PushTokenManager.swift` |
| TaskState | Shared task state model | `Models/TaskState.swift` |

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
│   └── Models.swift                 # MODIFIED - Add persistence helpers
├── Persistence/
│   ├── MessageQueuePersistence.swift    # NEW
│   ├── DraftInputPersistence.swift      # NEW
│   └── SharedContainer.swift            # NEW - App Group access
├── Utilities/
│   └── NetworkMonitor.swift         # NEW
└── CodingBridgeApp.swift            # MODIFIED - Register tasks

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
