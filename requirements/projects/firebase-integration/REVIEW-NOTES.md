# Plan Review Notes

Documentation of assumptions, decisions, and corrections made during planning.

## Review Date: January 2026

---

## Confirmed Configuration

| Setting | Value |
|---------|-------|
| **Bundle ID** | `com.level.CodingBridge` |
| **Privacy Consent** | Not required (always enabled) |
| **Architecture** | Extend existing managers |
| **CI/CD** | Manual Xcode builds (no automation yet) |

---

## Assumptions Made

### Correct Assumptions

1. **Existing Push Infrastructure Ready**
   - `PushNotificationManager.swift` has `didReceiveFCMToken()` method
   - Backend registration via `CLIBridgeAPIClient.registerPushToken()` implemented
   - Keychain storage for FCM tokens exists
   - Graceful degradation when Firebase missing

2. **AppDelegate Structure**
   - Uses `@UIApplicationDelegateAdaptor` for SwiftUI
   - Has `didRegisterForRemoteNotificationsWithDeviceToken` forwarding
   - Background push handling implemented

3. **Settings Integration**
   - `enablePushNotifications` toggle exists in AppSettings
   - Server URL configurable

### Corrected Assumptions

| Original Assumption | Correction |
|---------------------|------------|
| Create new `FirebaseManager` class | Extend existing `PushNotificationManager` instead |
| Method name `handleFCMToken()` | Use existing `didReceiveFCMToken()` |
| Centralized notification delegate | Keep in AppDelegate, extend as needed |
| Privacy consent flow needed | User confirmed: not required |

---

## Architectural Decisions

### Decision: Extend Existing Managers vs New Class

**Chosen: Extend existing managers**

**Rationale:**
- `PushNotificationManager` already has FCM token handling
- Avoids duplicate code and parallel systems
- Smaller code changes = lower risk
- Existing patterns already tested

**Changes to Plan:**
1. Add Firebase imports to `PushNotificationManager.swift`
2. Add Firebase initialization to `AppDelegate`
3. Create small helper classes for Analytics and Crashlytics
4. Don't create monolithic `FirebaseManager`

### Decision: Privacy Consent Flow

**Chosen: Always enabled (no consent UI)**

**Implications:**
- Simpler implementation
- Must disclose data collection in App Store privacy labels
- Consider adding opt-out later if privacy requirements change
- Crashlytics and Analytics enabled for all users

### Decision: CI/CD

**Chosen: Manual Xcode builds for now**

**Implications:**
- dSYM upload via Xcode run script is sufficient
- No Fastlane/GitHub Actions config needed
- Can add CI/CD later when TestFlight workflow established

---

## Files to Modify (Revised)

### Existing Files to Update

| File | Changes |
|------|---------|
| `PushNotificationManager.swift` | Add Firebase Messaging delegate integration |
| `CodingBridgeApp.swift` / `AppDelegate` | Add `FirebaseApp.configure()` |
| `Info.plist` | Add `FirebaseAppDelegateProxyEnabled = NO` |
| `.gitignore` | Add `GoogleService-Info.plist` (already done) |

### New Files to Create

| File | Purpose |
|------|---------|
| `CrashlyticsHelper.swift` | Thin wrapper for Crashlytics logging |
| `AnalyticsEvents.swift` | Analytics event definitions |
| `RemoteConfigManager.swift` | Remote Config access (singleton) |
| `RemoteConfigDefaults.plist` | Default config values |

### Files NOT Creating (Changed from Original Plan)

| Original | Reason Removed |
|----------|----------------|
| `FirebaseManager.swift` | Functionality split into existing managers + helpers |

---

## Potential Issues Identified

### Low Risk

1. **Firebase SDK Size** - Adds ~10-15MB to app binary
   - Acceptable for the functionality provided

2. **Build Time** - Initial Firebase build takes 5-10 minutes
   - Subsequent builds use cache

### Medium Risk

1. **dSYM Upload Sandboxing**
   - Xcode 15+ may block script with `ENABLE_USER_SCRIPT_SANDBOXING=YES`
   - Plan includes workaround (disable sandboxing)

2. **SwiftUI Swizzling**
   - Must disable `FirebaseAppDelegateProxyEnabled` for SwiftUI
   - APNs token must be manually forwarded to Messaging

### Mitigations

1. **Rollback Plan**: If Firebase causes issues:
   - Comment out `FirebaseApp.configure()`
   - Remove Firebase SPM dependency
   - Existing code gracefully handles missing Firebase

2. **Testing Strategy**:
   - Test on simulator first (limited - no push)
   - Test on physical device for full validation
   - Verify Crashlytics reports in Firebase Console

---

## App Store Considerations

### Privacy Labels Required

When submitting to App Store, declare:
- **Analytics**: Firebase Analytics collects usage data
- **Crash Data**: Crashlytics collects crash logs
- **Diagnostics**: Performance data collection

### App Tracking Transparency

**Not Required** - Firebase Analytics doesn't use IDFA by default.
If you later add AdMob or other ad services, ATT prompt would be needed.

---

## Future Enhancements (Not in Current Scope)

1. **Privacy Consent Flow** - Add opt-out UI if needed later
2. **CI/CD Integration** - Fastlane + GitHub Actions for automated builds
3. **TestFlight** - Distribution setup
4. **App Check** - Firebase security feature for production
5. **A/B Testing** - Using Remote Config for experiments

---

## Questions Resolved

| Question | Answer |
|----------|--------|
| Bundle ID? | `com.level.CodingBridge` |
| Privacy consent needed? | No - always enabled |
| Create new FirebaseManager? | No - extend existing managers |
| CI/CD needed? | No - manual Xcode builds |
| Physical device available? | Yes - iPhone for FCM testing |
| Remote Config parameters? | Keep feature flags + add version control |
| Rollout strategy? | All services at once |
| Analytics depth? | Comprehensive - all categories |

---

## Analytics Events Defined

### Categories Tracked

| Category | Events | Purpose |
|----------|--------|---------|
| **Session Patterns** | `session_start`, `session_end`, `session_gap` | Duration, engagement, retention |
| **Feature Adoption** | `feature_used`, `feature_discovered` | Usage, first-time discovery |
| **Performance** | `api_performance`, `connection_issue`, `app_startup` | Slow loads, failures, timeouts |
| **User Journey** | `screen_view`, `navigation`, `drop_off` | Flows, patterns, abandonment |
| **Errors** | `app_error` | Categorized error tracking |
| **SSH** | `ssh_connection`, `ssh_command` | Terminal usage |

### Bucketing Strategy

Events use bucketed values for better dashboard filtering:
- Duration: 0-30s, 30s-2m, 2-5m, 5-15m, 15-30m, 30m+
- Session gap: within_hour, same_day, 1-3_days, 3-7_days, week+
- Character count: short, medium, long, very_long

---

## Remote Config Parameters

| Parameter | Type | Default | Purpose |
|-----------|------|---------|---------|
| `feature_ssh_enabled` | Boolean | true | Kill switch |
| `feature_ideas_enabled` | Boolean | true | Kill switch |
| `feature_bookmarks_enabled` | Boolean | true | Kill switch |
| `min_supported_version` | String | 1.0.0 | Soft deprecation |
| `force_update_version` | String | (empty) | Hard force update |
| `update_message` | String | ... | Update prompt text |
| `max_message_history` | Number | 50 | Config |
| `session_timeout_minutes` | Number | 30 | Config |
| `api_timeout_seconds` | Number | 30 | Config |
| `websocket_reconnect_delay_ms` | Number | 1000 | Config |

---

## Remaining Considerations

### App Store Privacy Labels

When submitting to App Store, must declare:
- **Analytics**: Usage data, app interactions
- **Crash Data**: Crash logs
- **Diagnostics**: Performance data

### Not Included (Future)

- Privacy consent flow (if needed later)
- CI/CD dSYM upload (when TestFlight is set up)
- A/B testing via Remote Config
- App Check (Firebase security)

---

## Third Review - Additional Items

### Issues Fixed in Review 3

| Issue | Resolution |
|-------|------------|
| Unit tests referenced non-existent `FirebaseManager` | Updated to test `RemoteConfigManager` |
| CLAUDE.md referenced wrong file | Fixed to list actual files |
| No guidance on analytics integration points | Added Phase 10 with examples per view |
| Version control UI missing | Added `VersionCheckView.swift` in Phase 9 |
| First-time feature detection not implemented | Added `FeatureUsageTracker.swift` |

### New Files Added in Review 3

| File | Purpose |
|------|---------|
| `VersionCheckView.swift` | Update prompts (soft + forced) |
| `ForceUpdateView.swift` | Full-screen forced update |
| `FeatureUsageTracker.swift` | First-time feature detection |

### Total Implementation Scope

**New files to create:** 6
**Existing files to modify:** 7+
**Estimated time:** 6-8 hours (increased from 4-5)

### Views Requiring Analytics Integration

All major views will have analytics added:
- `CodingBridgeApp.swift` - app_startup
- `ProjectListView.swift` - screen_view, project_switching
- `ChatView.swift` - session tracking, messages
- `SettingsView.swift` - screen_view
- `SSHTerminalView.swift` - ssh events
- `IdeasView.swift` - feature usage
- `BookmarksView.swift` - feature usage
- `HistoryView.swift` - feature usage
