# Phase 2 Checklist

> Live Activities for Lock Screen and Dynamic Island.

## Prerequisites

- [ ] Phase 1 complete
- [ ] App Group created in Apple Developer Portal
- [ ] Push Notifications capability enabled
- [ ] Live Activities enabled for App ID

## Deliverables

### Widget Extension Setup
- [ ] Create App Group: `group.com.codingbridge.shared`
- [ ] Create widget extension target `CodingBridgeWidgets`
- [ ] Create shared framework for `ActivityAttributes`
- [ ] Configure build settings and entitlements
- [ ] Create `SharedContainer.swift` for data sharing

### Activity Attributes
- [ ] Define `CodingBridgeActivityAttributes` struct
- [ ] Define `ContentState` with all display fields
- [ ] Define supporting types (`ActivityStatus`, `TodoProgress`, `ApprovalInfo`)

### Live Activity UI
- [ ] Create `LockScreenView` for Lock Screen
- [ ] Create Dynamic Island compact views
- [ ] Create Dynamic Island expanded views
- [ ] Add `StatusIcon` with status-appropriate icons and colors
- [ ] Add `ElapsedTimeView` with formatted time
- [ ] Add `ApprovalRequestView` for pending approvals
- [ ] Implement progress bar when TodoWrite data available
- [ ] Add accessibility support (VoiceOver, Dynamic Type, Reduce Motion)

### LiveActivityManager
- [ ] Create `LiveActivityManager.swift`
- [ ] Implement `startActivity()` with push token request
- [ ] Implement `updateActivity()` for state changes
- [ ] Implement `endActivity()` with dismissal policy
- [ ] Add push token observation and storage
- [ ] Add elapsed time timer (15-second updates)
- [ ] Handle 1-hour timeout gracefully

### Integration
- [ ] Start Live Activity when backgrounding during processing
- [ ] Update Live Activity on progress changes
- [ ] Update Live Activity on status changes
- [ ] End Live Activity on task completion
- [ ] End Live Activity when returning to foreground (optional)

### Deep Link Handling
- [ ] Register URL scheme: `codingbridge://`
- [ ] Implement `handleDeepLink()` for session navigation
- [ ] Connect Live Activity tap to deep link
- [ ] Handle notification tap navigation

### Multi-Session
- [ ] Track which session has active Live Activity
- [ ] Implement session switching logic
- [ ] Handle multiple pending approvals

## Testing

- [ ] Test Live Activity start on background
- [ ] Test Dynamic Island compact/expanded views
- [ ] Test Lock Screen presentation
- [ ] Test status transitions (processing -> approval -> processing -> complete)
- [ ] Test elapsed time updates
- [ ] Test TodoWrite progress display
- [ ] Test Live Activity disabled in iOS Settings
- [ ] Test deep link navigation
- [ ] Test multi-session scenarios
- [ ] Test memory pressure handling

## Acceptance Criteria

- [ ] Live Activity appears on Lock Screen when Claude is working
- [ ] Dynamic Island shows status indicator and elapsed time
- [ ] Status icon changes color based on state
- [ ] Progress bar shows when TodoWrite is used
- [ ] Live Activity dismisses after completion

## Risk Mitigations

| Risk | Mitigation |
|------|------------|
| ActivityKit not available | Check `areActivitiesEnabled`, fallback to notifications |
| Update frequency limits | Throttle updates to 15-second minimum |
| Widget extension complexity | Follow Apple's template structure |

---
**Prev:** [ui-views](./ui-views.md) | **Phase 3:** [../phase-3/](../phase-3/) | **Index:** [../00-INDEX.md](../00-INDEX.md)
