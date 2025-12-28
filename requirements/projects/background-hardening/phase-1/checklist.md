# Phase 1 Checklist

> Background Basics + Local Notifications

## Deliverables

### BackgroundManager
- [ ] Create `BackgroundManager.swift`
- [ ] Register background task identifiers in `Info.plist`
- [ ] Implement `BGAppRefreshTask` scheduling
- [ ] Implement legacy `UIApplication` background task handling
- [ ] Add scene phase handling with proper state transitions
- [ ] Integrate with `CodingBridgeApp.swift`

### State Persistence
- [ ] Create `MessageQueuePersistence.swift` for pending messages
- [ ] Create `DraftInputPersistence.swift` for unsent input
- [ ] Persist `wasProcessing` flag reliably
- [ ] Add recovery logic to `WebSocketManager` for background recovery
- [ ] Set data protection level for background access

### NotificationManager
- [ ] Create `NotificationManager.swift` with delegate
- [ ] Configure notification categories (approval, question, complete, error)
- [ ] Implement `sendApprovalNotification()` with requestId tracking
- [ ] Implement `sendQuestionNotification()`
- [ ] Implement `sendCompletionNotification()` for success/failure
- [ ] Add foreground detection to suppress notifications when visible

### WebSocket Integration
- [ ] Add callbacks for approval requests -> notifications
- [ ] Add callbacks for AskUserQuestion -> notifications
- [ ] Add callbacks for task completion -> notifications
- [ ] Update `isAppInForeground` handling across all views

### User Settings
- [ ] Add background/notification settings to AppSettings
- [ ] Add settings UI section for background preferences
- [ ] Add permission status display
- [ ] Implement "Open Settings" button for denied permissions

### Network Monitoring
- [ ] Create `NetworkMonitor.swift` with NWPathMonitor
- [ ] Integrate connectivity awareness into BackgroundManager
- [ ] Handle network loss during background processing

## Testing

- [ ] Test background task registration
- [ ] Test notification delivery when backgrounded
- [ ] Test state persistence across app termination
- [ ] Test session reattachment after background
- [ ] Test with notification permissions denied
- [ ] Test Low Power Mode behavior
- [ ] Test network loss scenarios

## Acceptance Criteria

- [ ] App continues processing for extended time when backgrounded
- [ ] Local notification appears when Claude needs approval
- [ ] Local notification appears when Claude completes
- [ ] Pending messages survive app backgrounding
- [ ] Draft input restored on return to foreground

## Risk Mitigations

| Risk | Mitigation |
|------|------------|
| Background time insufficient | Accept limitation, focus on state preservation |
| Notification permissions denied | Graceful degradation, in-app alerts |

---
**Prev:** [network-monitor](./network-monitor.md) | **Phase 2:** [../phase-2/](../phase-2/) | **Index:** [../00-INDEX.md](../00-INDEX.md)
