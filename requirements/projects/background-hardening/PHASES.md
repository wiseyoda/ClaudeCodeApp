# Implementation Phases

> Incremental implementation plan for background hardening.

## Overview

This project is divided into three phases, each building on the previous:

| Phase | Focus | Dependencies |
|-------|-------|--------------|
| **Phase 1** | Background basics + Local notifications | None |
| **Phase 2** | Live Activities | Phase 1 |
| **Phase 3** | Actionable approvals + Push notifications | Phase 1 + 2, Backend changes |

## Phase 1: Background Basics + Local Notifications

### Goal
Establish foundational background task handling and improve local notification system so users know when Claude needs attention.

### Deliverables

#### 1.1 BackgroundManager Implementation
- [ ] Create `BackgroundManager.swift`
- [ ] Register background task identifiers in `Info.plist`
- [ ] Implement `BGAppRefreshTask` scheduling
- [ ] Implement legacy `UIApplication` background task handling
- [ ] Add scene phase handling with proper state transitions
- [ ] Integrate with `CodingBridgeApp.swift`

#### 1.2 State Persistence
- [ ] Create `MessageQueuePersistence.swift` for pending messages
- [ ] Create `DraftInputPersistence.swift` for unsent input
- [ ] Persist `wasProcessing` flag reliably
- [ ] Add recovery logic to `WebSocketManager` for background recovery

#### 1.3 NotificationManager Implementation
- [ ] Create `NotificationManager.swift` with delegate
- [ ] Configure notification categories (approval, question, complete, error)
- [ ] Implement `sendApprovalNotification()` with requestId tracking
- [ ] Implement `sendQuestionNotification()`
- [ ] Implement `sendCompletionNotification()` for success/failure
- [ ] Add foreground detection to suppress notifications when visible

#### 1.4 WebSocket Integration
- [ ] Add callbacks for approval requests → notifications
- [ ] Add callbacks for AskUserQuestion → notifications
- [ ] Add callbacks for task completion → notifications
- [ ] Update `isAppInForeground` handling across all views

#### 1.5 User Settings
- [ ] Add background/notification settings to AppSettings
- [ ] Add settings UI section for background preferences
- [ ] Add permission status display
- [ ] Implement "Open Settings" button for denied permissions

#### 1.6 Network Monitoring
- [ ] Create `NetworkMonitor.swift` with NWPathMonitor
- [ ] Integrate connectivity awareness into BackgroundManager
- [ ] Handle network loss during background processing

#### 1.7 Testing
- [ ] Test background task registration
- [ ] Test notification delivery when backgrounded
- [ ] Test state persistence across app termination
- [ ] Test session reattachment after background
- [ ] Test with notification permissions denied
- [ ] Test Low Power Mode behavior
- [ ] Test network loss scenarios

### Acceptance Criteria
- App continues processing for extended time when backgrounded
- Local notification appears when Claude needs approval
- Local notification appears when Claude completes
- Pending messages survive app backgrounding
- Draft input restored on return to foreground

---

## Phase 2: Live Activities

### Goal
Add Live Activities for glanceable status updates on Lock Screen and Dynamic Island.

### Prerequisites
- Phase 1 complete
- iOS 16.1+ deployment target (already met with iOS 26.2)

### Deliverables

#### 2.1 Widget Extension Setup

**⚠️ PREREQUISITE:** Complete Apple Developer Portal setup before starting code:
1. Create App Group identifier in portal
2. Add Push Notifications capability to App ID
3. Enable Live Activities for App ID

- [ ] Create App Group in Apple Developer Portal (`group.com.codingbridge.shared`)
- [ ] Create widget extension target `CodingBridgeWidgets`
- [ ] Create shared framework for `ActivityAttributes`
- [ ] Configure build settings and entitlements (including App Group)
- [ ] Add to Xcode project properly
- [ ] Create `SharedContainer.swift` for data sharing between app and widget

#### 2.2 Activity Attributes
- [ ] Define `CodingBridgeActivityAttributes` struct
- [ ] Define `ContentState` with all display fields
- [ ] Define supporting types (`ActivityStatus`, `TodoProgress`, `ApprovalInfo`)

#### 2.3 Live Activity UI
- [ ] Create `LockScreenView` for Lock Screen presentation
- [ ] Create Dynamic Island compact views
- [ ] Create Dynamic Island expanded views
- [ ] Add `StatusIcon` with status-appropriate icons and colors
- [ ] Add `ElapsedTimeView` with formatted time display
- [ ] Add `ApprovalRequestView` for pending approvals
- [ ] Implement progress bar when TodoWrite data available

#### 2.4 LiveActivityManager Implementation
- [ ] Create `LiveActivityManager.swift`
- [ ] Implement `startActivity()` with push token request
- [ ] Implement `updateActivity()` for state changes
- [ ] Implement `endActivity()` with dismissal policy
- [ ] Add push token observation and storage
- [ ] Add elapsed time timer (15-second updates)
- [ ] Handle 1-hour timeout gracefully

#### 2.5 Integration
- [ ] Start Live Activity when backgrounding during processing
- [ ] Update Live Activity on progress changes
- [ ] Update Live Activity on status changes (approval needed, etc.)
- [ ] End Live Activity on task completion
- [ ] End Live Activity when returning to foreground (optional)

#### 2.6 Deep Link Handling
- [ ] Register URL scheme in Info.plist (`codingbridge://`)
- [ ] Implement `handleDeepLink()` for session navigation
- [ ] Connect Live Activity tap to deep link
- [ ] Handle notification tap navigation

#### 2.7 Multi-Session Handling
- [ ] Track which session has active Live Activity
- [ ] Implement session switching logic
- [ ] Handle multiple pending approvals

#### 2.8 Testing
- [ ] Test Live Activity start on background
- [ ] Test Dynamic Island compact/expanded views
- [ ] Test Lock Screen presentation
- [ ] Test status transitions (processing → approval → processing → complete)
- [ ] Test elapsed time updates
- [ ] Test TodoWrite progress display
- [ ] Test Live Activity disabled in iOS Settings
- [ ] Test deep link navigation from notification tap
- [ ] Test multi-session scenarios

### Acceptance Criteria
- Live Activity appears on Lock Screen when Claude is working
- Dynamic Island shows status indicator and elapsed time
- Status icon changes color based on state
- Progress bar shows when TodoWrite is used
- Live Activity dismisses after completion

---

## Phase 3: Actionable Approvals + Push Notifications

### Goal
Enable approving/denying Claude requests directly from notifications, with backend push notification support for when app is suspended.

### Prerequisites
- Phase 1 and 2 complete
- Backend APNs integration deployed
- APNs key configured

### Deliverables

#### 3.1 Push Token Manager
- [ ] Create `PushTokenManager.swift`
- [ ] Register for remote notifications
- [ ] Handle device token updates
- [ ] Send tokens to backend via new API
- [ ] Handle Live Activity push token registration
- [ ] Implement token invalidation

#### 3.2 Backend Integration (iOS Side)
- [ ] Create API client methods for `/api/push/*` endpoints
- [ ] Send device token on app launch
- [ ] Send Live Activity token when activity starts
- [ ] Handle token refresh events

#### 3.3 Notification Actions
- [ ] Add Approve/Deny actions to approval category
- [ ] Implement `userNotificationCenter(didReceive:)` delegate
- [ ] Handle approval action → send response via WebSocket
- [ ] Handle deny action → send response via WebSocket
- [ ] Update Live Activity status after action

#### 3.4 Push Notification Handling
- [ ] Configure `application(didReceiveRemoteNotification:)` for silent push
- [ ] Handle Live Activity update pushes
- [ ] Handle standard alert pushes when app suspended

#### 3.5 BGContinuedProcessingTask (iOS 26+)
- [ ] Add iOS 26 availability checks
- [ ] Implement `BGContinuedProcessingTask` request
- [ ] Link Progress object for system UI
- [ ] Handle task expiration gracefully

#### 3.6 Backend Implementation
- [ ] Deploy push token registration endpoints
- [ ] Configure APNs provider with p8 key
- [ ] Implement approval request push notifications
- [ ] Implement Live Activity update pushes
- [ ] Implement task completion pushes
- [ ] Add rate limiting for Live Activity updates

#### 3.7 Privacy & Content Filtering
- [ ] Implement `sanitizeForLockScreen()` for content filtering
- [ ] Add "Show Details on Lock Screen" setting
- [ ] Redact potential secrets (tokens, keys) from notifications
- [ ] Test sensitive content filtering

#### 3.8 Analytics (Optional)
- [ ] Define tracking metrics
- [ ] Implement metric logging
- [ ] Add success rate measurement

#### 3.9 Testing
- [ ] Test approval from notification (Approve button)
- [ ] Test denial from notification (Deny button)
- [ ] Test push notification delivery when app suspended
- [ ] Test Live Activity updates via push
- [ ] Test token refresh handling
- [ ] Test end-to-end flow: background → approval needed → approve from Lock Screen → continue
- [ ] Test content filtering for sensitive data
- [ ] Test force-quit recovery flow

### Acceptance Criteria
- Can approve Claude requests from Lock Screen without opening app
- Can deny Claude requests from Lock Screen
- Push notifications arrive when app fully suspended
- Live Activity updates via push when app suspended
- Seamless experience between local and push notifications

---

## Phase 4 (Future): Enhanced Features

### 4.1 Home Screen Widget
Static widget showing session status when no active Live Activity.

- [ ] Create `CodingBridgeStatusWidget` in widget extension
- [ ] Design small, medium, large widget layouts
- [ ] Show last session status (idle, completed, error)
- [ ] Show recent activity summary
- [ ] Add quick action to open specific project
- [ ] Configure timeline refresh intervals

### 4.2 Other Enhancements
- [ ] Apple Watch Live Activity customization
- [ ] Notification sounds customization in Settings
- [ ] Notification summary/grouping
- [ ] Broadcast push notifications (iOS 18+)
- [ ] Push-to-start Live Activities (iOS 17.2+)
- [ ] Rich notification previews with code snippets
- [ ] Siri Shortcuts integration

---

## Technical Dependencies Graph

```
Phase 1: Background Basics
├── BackgroundManager.swift
├── NotificationManager.swift
├── MessageQueuePersistence.swift
├── DraftInputPersistence.swift
└── WebSocketManager updates

Phase 2: Live Activities (depends on Phase 1)
├── CodingBridgeWidgets (extension)
├── CodingBridgeActivityAttributes.swift (shared)
├── LiveActivityManager.swift
├── LockScreenView.swift
├── DynamicIslandViews.swift
└── BackgroundManager integration

Phase 3: Push + Actions (depends on Phase 1 + 2)
├── PushTokenManager.swift
├── API client for push endpoints
├── NotificationManager action handling
├── Backend APNs integration
└── BGContinuedProcessingTask (iOS 26)
```

---

## Provisioning & Entitlements Checklist

Before starting implementation, ensure these are configured in Apple Developer Portal:

### App ID Capabilities
- [ ] Push Notifications (required for Phase 1)
- [ ] Background Modes (required for Phase 1)
- [ ] App Groups (required for Phase 2)

### Provisioning Profiles
- [ ] Development profile with push notification capability
- [ ] Ad Hoc profile for TestFlight (optional, for internal testing)
- [ ] App Store profile for production

### Entitlements File (`CodingBridge.entitlements`)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>aps-environment</key>
    <string>development</string>  <!-- Change to "production" for App Store -->

    <key>com.apple.developer.associated-domains</key>
    <array>
        <string>applinks:codingbridge.app</string>  <!-- If using Universal Links -->
    </array>

    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.codingbridge.shared</string>
    </array>
</dict>
</plist>
```

### Widget Extension Entitlements (`CodingBridgeWidgetsExtension.entitlements`)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.codingbridge.shared</string>
    </array>
</dict>
</plist>
```

---

## Beta Testing Path (TestFlight)

### APNs Environment Considerations

TestFlight uses **production APNs** (not sandbox), even for beta builds. Plan accordingly:

| Build Type | APNs Environment | Entitlement Value |
|------------|-----------------|-------------------|
| Debug (Xcode) | Sandbox | `development` |
| Ad Hoc | Sandbox | `development` |
| TestFlight | Production | `production` |
| App Store | Production | `production` |

### Testing Workflow

#### Phase 1: Local Notifications (No APNs needed)
- Test fully in Simulator and local device
- No backend push integration required

#### Phase 2: Live Activities (Local updates only)
- Test fully in Simulator and local device
- Push token registration can be tested, but push updates require Phase 3

#### Phase 3: Push Notifications

**Development Testing:**
1. Use Xcode with development provisioning profile
2. Backend configured for APNs sandbox (`api.sandbox.push.apple.com`)
3. Test on physical device

**TestFlight Testing:**
1. Archive with App Store / Ad Hoc profile (production entitlement)
2. Backend must switch to production APNs (`api.push.apple.com`)
3. **Recommendation:** Use environment variable to switch APNs endpoint

```javascript
// Backend APNs configuration
const apnsHost = process.env.APNS_ENVIRONMENT === 'production'
  ? 'api.push.apple.com'
  : 'api.sandbox.push.apple.com';
```

### Backend Environment Setup

| Environment | APNs Host | iOS Build |
|-------------|-----------|-----------|
| Local Dev | sandbox | Debug from Xcode |
| Staging | sandbox | Debug from Xcode |
| TestFlight | production | TestFlight build |
| Production | production | App Store build |

### Testing Checklist

- [ ] Test local notifications in Simulator
- [ ] Test Live Activity in Simulator (Lock Screen view)
- [ ] Test Live Activity on device (Dynamic Island)
- [ ] Test push notifications on device (development APNs)
- [ ] Test full flow on TestFlight (production APNs)
- [ ] Verify token refresh handling
- [ ] Verify badge count management
- [ ] Test notification actions (approve/deny)

---

## Risk Mitigation

### Phase 1 Risks
| Risk | Mitigation |
|------|------------|
| Background time insufficient | Accept limitation, focus on state preservation |
| Notification permissions denied | Graceful degradation, in-app alerts |

### Phase 2 Risks
| Risk | Mitigation |
|------|------------|
| ActivityKit not available | Check `areActivitiesEnabled`, fallback to notifications |
| Update frequency limits | Throttle updates to 15-second minimum |
| Widget extension complexity | Follow Apple's template structure |

### Phase 3 Risks
| Risk | Mitigation |
|------|------------|
| APNs integration complexity | Use proven library (@parse/node-apn) |
| Token invalidation race conditions | Proper async handling, database transactions |
| Push delivery delays | Keep local notifications as primary |

---

## Rollback Plan

Each phase can be rolled back independently:

- **Phase 3**: Disable push token registration, rely on local notifications
- **Phase 2**: Disable Live Activity start, rely on notifications only
- **Phase 1**: Revert to current behavior (minimal background)

Feature flags can be used to enable/disable each phase:

```swift
struct BackgroundFeatureFlags {
    static var enableBackgroundTasks = true
    static var enableLiveActivities = true
    static var enablePushNotifications = true
    static var enableActionableNotifications = true
}
```

---

## Success Metrics

### Phase 1
- [ ] 95%+ of pending messages survive backgrounding
- [ ] Notification delivery within 1 second of event
- [ ] Zero missed approval requests

### Phase 2
- [ ] Live Activity visible on 100% of eligible devices
- [ ] Status accurate to within 15 seconds
- [ ] Smooth animations in Dynamic Island

### Phase 3
- [ ] 95%+ of push notifications delivered within 5 seconds
- [ ] Approval actions complete within 2 seconds
- [ ] Zero false positive/negative approvals

---

## Documentation Updates

After each phase, update:
- [ ] `CHANGELOG.md` with new features
- [ ] `CLAUDE.md` with new patterns/managers
- [ ] `requirements/ARCHITECTURE.md` with component updates
- [ ] User-facing release notes
