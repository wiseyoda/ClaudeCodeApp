# Phase 3 Checklist

> Push Notifications via Firebase + Actionable Approvals.

## Prerequisites

- [ ] Phase 1 + 2 complete
- [ ] Apple Developer Account (for APNs key)
- [ ] Firebase Project created at console.firebase.google.com
- [ ] APNs key (.p8) uploaded to Firebase Console
- [ ] Service Account key (.json) downloaded for backend
- [ ] `GoogleService-Info.plist` added to iOS project

## Deliverables

### iOS: FCMTokenManager
- [ ] Add Firebase SDK via SPM (FirebaseCore, FirebaseMessaging)
- [ ] Create `FCMTokenManager.swift`
- [ ] Configure Firebase in AppDelegate
- [ ] Handle FCM token registration via MessagingDelegate
- [ ] Pass APNs token to Firebase SDK
- [ ] Register FCM token with backend
- [ ] Handle Live Activity token registration (direct APNs)
- [ ] Handle token invalidation

### iOS: App Delegate
- [ ] Initialize Firebase (`FirebaseApp.configure()`)
- [ ] Configure FCMTokenManager
- [ ] Handle `didRegisterForRemoteNotificationsWithDeviceToken`
- [ ] Handle `didFailToRegisterForRemoteNotificationsWithError`
- [ ] Handle `didReceiveRemoteNotification` for silent push
- [ ] Pass messages to Firebase SDK

### iOS: Notification Actions
- [ ] Implement Approve/Deny action handlers
- [ ] Add duplicate request protection
- [ ] Add offline queueing for approvals
- [ ] Add haptic feedback
- [ ] Update Live Activity after action

### Backend: Database
- [ ] Create `push_tokens` table migration
- [ ] Add indexes for FCM token lookup

### Backend: API Endpoints
- [ ] `POST /api/push/register` - FCM token registration
- [ ] `POST /api/push/live-activity` - Live Activity APNs token
- [ ] `DELETE /api/push/invalidate` - Token invalidation
- [ ] `GET /api/push/status` - Debug status

### Backend: Firebase Admin SDK
- [ ] Install `firebase-admin` package
- [ ] Create FirebaseService with credential loading
- [ ] Implement `sendNotification()` for FCM alerts
- [ ] Implement `sendSilentPush()` for background updates
- [ ] Handle `registration-token-not-registered` error

### Backend: Live Activity Service
- [ ] Install `@parse/node-apn` package
- [ ] Create LiveActivityService with APNs key
- [ ] Implement `updateActivity()` for Live Activity updates
- [ ] Add rate limiting (15-second minimum)

### Backend: Event Triggers
- [ ] Trigger FCM push on approval request
- [ ] Trigger FCM push on question asked
- [ ] Trigger FCM push on task complete/error
- [ ] Trigger Live Activity updates on progress
- [ ] Implement 60-second approval timeout

### Backend: Multi-Device
- [ ] Clear notifications on other devices after approval
- [ ] Track active client per session
- [ ] Send session handoff notifications

## Testing

- [ ] Test FCM token registration
- [ ] Test push notification delivery on device
- [ ] Test Live Activity push updates
- [ ] Test Approve action from Lock Screen
- [ ] Test Deny action from Lock Screen
- [ ] Test 60-second approval timeout
- [ ] Test multi-device notification clearing
- [ ] Test offline approval queueing
- [ ] Test FCM token refresh
- [ ] Test with Firebase sandbox environment
- [ ] Test with Firebase production environment

## Acceptance Criteria

- [ ] Push notification appears when app is closed
- [ ] Approve/Deny buttons work from Lock Screen
- [ ] Approval timeout handled gracefully
- [ ] Live Activity updates via push
- [ ] Multi-device notifications sync properly

## Risk Mitigations

| Risk | Mitigation |
|------|------------|
| Firebase service outage | Also send WebSocket for foreground |
| FCM token invalidation | Handle gracefully, re-register |
| APNs key expiration | Rotate annually, set calendar reminder |

## Deployment Checklist

- [ ] Create Firebase project
- [ ] Generate APNs key from Apple Developer Portal
- [ ] Upload APNs key to Firebase Console
- [ ] Download Service Account key for backend
- [ ] Download `GoogleService-Info.plist` for iOS
- [ ] Set backend environment variables
- [ ] Run database migrations
- [ ] Deploy API endpoints
- [ ] Test with Firebase sandbox
- [ ] Switch to production for release

---
**Prev:** [backend-events](./backend-events.md) | **Reference:** [../ref/](../ref/) | **Index:** [../00-INDEX.md](../00-INDEX.md)
