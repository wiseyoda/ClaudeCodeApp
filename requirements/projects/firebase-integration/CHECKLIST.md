# Firebase Integration Checklist

Track your progress through the integration. Check off items as completed.

---

## Phase 1: Prerequisites (User Actions)

### Firebase Console Setup
- [ ] Created Firebase project
- [ ] Enabled Google Analytics for project
- [ ] Registered iOS app with bundle ID
- [ ] Downloaded `GoogleService-Info.plist`
- [ ] Created Remote Config parameters

### Apple Developer Setup
- [ ] Created APNs Authentication Key (.p8)
- [ ] Noted Key ID: `__________`
- [ ] Noted Team ID: `__________`
- [ ] Uploaded APNs key to Firebase Console

### Local Setup
- [ ] Placed `GoogleService-Info.plist` in `CodingBridge/` folder
- [ ] Added `GoogleService-Info.plist` to `.gitignore`

---

## Phase 2: Swift Package Manager

- [ ] Added Firebase SDK via File → Add Packages
- [ ] Repository: `https://github.com/firebase/firebase-ios-sdk.git`
- [ ] Version: 12.7.0 (Up to Next Major)
- [ ] Selected packages:
  - [ ] FirebaseAnalytics
  - [ ] FirebaseCrashlytics
  - [ ] FirebaseMessaging
  - [ ] FirebaseRemoteConfig
  - [ ] FirebasePerformance
- [ ] Added `-ObjC` to Other Linker Flags
- [ ] Project builds successfully with Firebase

---

## Phase 3: Xcode Configuration

### Info.plist
- [ ] Added `FirebaseAppDelegateProxyEnabled` = NO

### Capabilities
- [ ] Push Notifications capability enabled
- [ ] Background Modes → Remote notifications checked

### Build Settings
- [ ] Debug Information Format = DWARF with dSYM File (all configs)
- [ ] User Script Sandboxing = No (if needed for Crashlytics)

---

## Phase 4: Code Implementation

### New Files Created
- [ ] `Managers/FirebaseManager.swift`
- [ ] `Utilities/AnalyticsEvents.swift`
- [ ] `RemoteConfigDefaults.plist`

### Updated Files
- [ ] `CodingBridgeApp.swift` - AppDelegate updates
- [ ] `PushNotificationManager.swift` - FCM token handling

### File Added to Project
- [ ] `GoogleService-Info.plist` in Xcode project navigator

---

## Phase 5: Crashlytics Build Phase

- [ ] Added "Upload Crashlytics Symbols" run script phase
- [ ] Script phase is LAST in build phases
- [ ] Script content:
  ```
  "${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
  ```
- [ ] Input files added:
  - [ ] `${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}`
  - [ ] `${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${PRODUCT_NAME}`
  - [ ] `${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Info.plist`
  - [ ] `$(TARGET_BUILD_DIR)/$(INFOPLIST_PATH)`

---

## Phase 6: Testing

### Build Verification
- [ ] Project builds without errors
- [ ] Project builds without warnings (Firebase-related)
- [ ] App launches successfully

### Firebase Console Verification
- [ ] App appears in Firebase Console → Project Overview
- [ ] Analytics → Dashboard shows data (may take hours)

### Push Notifications
- [ ] Running on physical device
- [ ] FCM token appears in Xcode console
- [ ] Test message from Firebase Console received
- [ ] Notification appears when app is in foreground
- [ ] Notification appears when app is in background

### Crashlytics
- [ ] Test crash triggered (DEBUG build)
- [ ] Crash appears in Firebase Console → Crashlytics
- [ ] dSYM uploaded (readable stack traces)

### Remote Config
- [ ] Config fetched successfully (check logs)
- [ ] Default values work when offline
- [ ] Firebase Console changes reflected in app

### Performance
- [ ] Performance data appears in Firebase Console
- [ ] App start time tracked
- [ ] Network requests tracked

---

## Phase 7: Documentation

- [ ] Updated `CLAUDE.md` with Firebase section
- [ ] Updated `.gitignore` with Firebase exclusions
- [ ] Removed any test crash code (DEBUG only)
- [ ] Verified no credentials in git history

---

## Phase 8: Production Readiness

### Security Audit
- [ ] `GoogleService-Info.plist` not in git
- [ ] No API keys hardcoded in source
- [ ] No test crash code in release builds

### Analytics Review
- [ ] Analytics events meaningful and not excessive
- [ ] No PII logged in analytics
- [ ] User ID hashed if used

### Performance Review
- [ ] App startup time acceptable with Firebase
- [ ] No obvious performance regression
- [ ] Remote Config fetch doesn't block UI

---

## Completion Status

| Phase | Status | Notes |
|-------|--------|-------|
| Prerequisites | [ ] | |
| SPM Integration | [ ] | |
| Xcode Config | [ ] | |
| Code Implementation | [ ] | |
| Crashlytics Build | [ ] | |
| Testing | [ ] | |
| Documentation | [ ] | |
| Production Ready | [ ] | |

**Integration Complete:** [ ]

**Date Completed:** _______________

---

## Issues Encountered

Use this space to track any issues:

| Issue | Resolution | Date |
|-------|------------|------|
| | | |
| | | |
| | | |
