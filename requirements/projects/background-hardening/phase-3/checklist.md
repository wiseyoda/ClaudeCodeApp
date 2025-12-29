# Phase 3 Checklist

> Push Notifications + Actionable Approvals.

## Prerequisites

- [ ] Phase 1 + 2 complete
- [ ] APNs key (.p8) created in Apple Developer Portal
- [ ] Key ID and Team ID noted
- [ ] Backend environment configured

## Deliverables

### iOS: PushTokenManager
- [ ] Create `PushTokenManager.swift`
- [ ] Handle device token registration
- [ ] Handle Live Activity token registration
- [ ] Implement token rotation (previousToken)
- [ ] Handle registration errors gracefully

### iOS: App Delegate
- [ ] Register for remote notifications at launch
- [ ] Handle `didRegisterForRemoteNotificationsWithDeviceToken`
- [ ] Handle `didFailToRegisterForRemoteNotificationsWithError`
- [ ] Handle silent push for clear commands
- [ ] Handle `didReceiveRemoteNotification` for background fetch

### iOS: Notification Actions
- [ ] Implement Approve/Deny action handlers
- [ ] Add duplicate request protection
- [ ] Add offline queueing for approvals
- [ ] Add haptic feedback
- [ ] Update Live Activity after action

### Backend: Database
- [ ] Create `push_tokens` table migration
- [ ] Add indexes for performance

### Backend: API Endpoints
- [ ] `POST /api/push/register` - Token registration
- [ ] `DELETE /api/push/invalidate` - Token invalidation
- [ ] `GET /api/push/status` - Debug status

### Backend: APNs Service
- [ ] Create APNs service with .p8 key
- [ ] Implement `sendNotification()` for alerts
- [ ] Implement `sendLiveActivityUpdate()` for Live Activities
- [ ] Handle token invalidation on `BadDeviceToken`
- [ ] Add rate limiting for Live Activity updates

### Backend: Event Triggers
- [ ] Trigger push on approval request
- [ ] Trigger push on question asked
- [ ] Trigger push on task complete/error
- [ ] Trigger Live Activity updates on progress
- [ ] Implement 60-second approval timeout

### Backend: Multi-Device
- [ ] Clear notifications on other devices after approval
- [ ] Track active client per session
- [ ] Send session handoff notifications

## Testing

- [ ] Test push notification delivery on device
- [ ] Test Live Activity push updates
- [ ] Test Approve action from Lock Screen
- [ ] Test Deny action from Lock Screen
- [ ] Test 60-second approval timeout
- [ ] Test multi-device notification clearing
- [ ] Test offline approval queueing
- [ ] Test token refresh/rotation
- [ ] Test with APNs sandbox environment
- [ ] Test with APNs production environment

## Acceptance Criteria

- [ ] Push notification appears when app is closed
- [ ] Approve/Deny buttons work from Lock Screen
- [ ] Approval timeout handled gracefully
- [ ] Live Activity updates via push
- [ ] Multi-device notifications sync properly

## Risk Mitigations

| Risk | Mitigation |
|------|------------|
| APNs key security | Store securely, rotate annually |
| Push delivery delays | Also send WebSocket for foreground |
| Token invalidation | Handle gracefully, re-register |

## Deployment Checklist

- [ ] Generate APNs key from Apple Developer Portal
- [ ] Store .p8 file securely (not in repo)
- [ ] Set environment variables
- [ ] Run database migrations
- [ ] Deploy API endpoints
- [ ] Test with sandbox APNs
- [ ] Switch to production APNs for release

---
**Prev:** [backend-events](./backend-events.md) | **Reference:** [../ref/](../ref/) | **Index:** [../00-INDEX.md](../00-INDEX.md)
