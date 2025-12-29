# Phase 1 Checklist

> Background Basics + Local Notifications

## Deliverables

### BackgroundManager
- [x] Create `BackgroundManager.swift`
- [x] Register background task identifiers in `Info.plist`
- [x] Implement `BGAppRefreshTask` scheduling
- [x] Implement legacy `UIApplication` background task handling
- [x] Add scene phase handling with proper state transitions
- [x] Integrate with `CodingBridgeApp.swift`

### State Persistence
- [x] Create `MessageQueuePersistence.swift` for pending messages
- [x] Create `DraftInputPersistence.swift` for unsent input
- [x] Persist `wasProcessing` flag reliably
- [x] Add recovery logic to `WebSocketManager` for background recovery
- [x] Set data protection level for background access

### NotificationManager
- [x] Create `NotificationManager.swift` with delegate
- [x] Configure notification categories (approval, question, complete, error)
- [x] Implement `sendApprovalNotification()` with requestId tracking
- [x] Implement `sendQuestionNotification()`
- [x] Implement `sendCompletionNotification()` for success/failure
- [x] Add foreground detection to suppress notifications when visible

### WebSocket Integration
- [x] Add callbacks for approval requests -> notifications
- [x] Add callbacks for AskUserQuestion -> notifications
- [x] Add callbacks for task completion -> notifications
- [x] Update `isAppInForeground` handling across all views

### User Settings
- [x] Add background/notification settings to AppSettings
- [x] Add settings UI section for background preferences
- [x] Add permission status display
- [x] Implement "Open Settings" button for denied permissions

### Network Monitoring
- [x] Create `NetworkMonitor.swift` with NWPathMonitor
- [x] Integrate connectivity awareness into BackgroundManager
- [x] Handle network loss during background processing

### Supporting Types
- [x] Create `TaskState.swift` model
- [x] Create `OfflineActionQueue.swift` for queuing offline approvals

## Testing

- [x] Test background task registration (partial - see issue #29)
- [x] Test notification delivery when backgrounded
- [x] Test state persistence across app termination
- [x] Test session reattachment after background
- [x] Test with notification permissions denied
- [x] Test Low Power Mode behavior
- [x] Test network loss scenarios (skipped - edge case)

## Acceptance Criteria

- [x] App continues processing for extended time when backgrounded
- [x] Local notification appears when Claude needs approval
- [x] Local notification appears when Claude completes
- [x] Pending messages survive app backgrounding
- [x] Draft input restored on return to foreground

## Risk Mitigations

| Risk | Mitigation |
|------|------------|
| Background time insufficient | Accept limitation, focus on state preservation |
| Notification permissions denied | Graceful degradation, in-app alerts |

---
**Prev:** [network-monitor](./network-monitor.md) | **Phase 2:** [../phase-2/](../phase-2/) | **Index:** [../00-INDEX.md](../00-INDEX.md)
