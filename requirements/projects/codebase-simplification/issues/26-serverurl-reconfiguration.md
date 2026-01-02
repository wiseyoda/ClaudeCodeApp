# Issue #26: Reconfigure long-lived services on serverURL change

> **Status**: Complete (verified 2026-01-02)
> **Priority**: Tier 2
> **Depends On**: #21
> **Blocks**: #24

---

## Summary

Implement roadmap task: Reconfigure long-lived services on serverURL change.

## Problem

When user changes `serverURL` in Settings, singleton services (HealthMonitorService, SessionStore, PermissionManager, PushNotificationManager, LiveActivityManager) continue using the old URL until app restart. This causes confusion when switching between localhost and production servers.

## Solution

Add a Combine publisher in AppSettings that emits when serverURL changes in UserDefaults. Each singleton service subscribes to this publisher and reconfigures itself with the new URL automatically.

---

## Scope

### In Scope

- Add `serverURLPublisher` to AppSettings for observing changes
- Add `setupServerURLObserver()` to each long-lived service
- Track `currentServerURL` to avoid redundant reconfiguration
- Expose `settings` property on CLIBridgeSessionRepository for reconfiguration

### Out of Scope

- New features or UX changes
- Unrelated refactors outside this task

---

## Implementation

### Files Modified

| File | Change |
|---|---|
| CodingBridge/AppSettings.swift | Added `serverURLPublisher` Combine publisher, added Combine import |
| CodingBridge/SessionStore.swift | Added `setupServerURLObserver()`, `reconfigure(serverURL:)`, `currentServerURL`, `cancellables` |
| CodingBridge/SessionRepository.swift | Changed `settings` from private to internal for reconfiguration access |
| CodingBridge/PermissionManager.swift | Added `setupServerURLObserver()`, `currentServerURL`, `cancellables`, added Combine import |
| CodingBridge/Utilities/HealthMonitorService.swift | Added `setupServerURLObserver()` |
| CodingBridge/Managers/PushNotificationManager.swift | Added `setupServerURLObserver()`, `currentServerURL`, `cancellables`, added Combine import |
| CodingBridge/Managers/LiveActivityManager.swift | Added `setupServerURLObserver()`, `currentServerURL`, `cancellables`, added Combine import |

### Files to Delete

| File | Reason |
|---|---|
| None | N/A |

### Implementation Details

1. **AppSettings.serverURLPublisher**
   - Uses `NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)`
   - Extracts serverURL from UserDefaults
   - Uses `removeDuplicates()` to avoid redundant emissions

2. **Service Pattern**
   Each service follows the same pattern:
   ```swift
   private var currentServerURL: String = ""
   private var cancellables = Set<AnyCancellable>()

   private func setupServerURLObserver() {
       AppSettings.serverURLPublisher
           .receive(on: DispatchQueue.main)
           .sink { [weak self] newURL in
               guard let self = self else { return }
               guard newURL != self.currentServerURL, /* service is configured */ else { return }
               log.info("[ServiceName] Server URL changed to \(newURL) - reconfiguring")
               self.configure(serverURL: newURL)
           }
           .store(in: &cancellables)
   }
   ```

---

## Acceptance Criteria

- [x] Reconfigure long-lived services on serverURL change is implemented as described
- [x] Legacy paths are removed or no longer used (no legacy paths existed; this adds new capability)
- [x] Build passes with no new warnings
- [x] No user-visible behavior changes (behavior is improved - services now react to URL changes)

---

## Verification Commands

```bash
# Build verification
xcodebuild -project CodingBridge.xcodeproj -scheme CodingBridge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'

# Verify all services have serverURL observation
grep -rn "setupServerURLObserver\|serverURLPublisher" CodingBridge/

# Expected output: 5 services (SessionStore, HealthMonitorService, PermissionManager,
# PushNotificationManager, LiveActivityManager) plus AppSettings publisher
```

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| UserDefaults notification fires too often | Use `removeDuplicates()` and check against `currentServerURL` |
| Memory leaks from Combine subscriptions | Use `[weak self]` in sink closures |
| Race conditions during reconfiguration | All services use `@MainActor`, reconfiguration is synchronous |

---

## Notes

- This implementation uses the iOS-idiomatic Combine pattern for observing UserDefaults changes
- Services only reconfigure if they were previously configured (checked via `apiClient != nil` or `isConfigured`)
- The `Notification.Name.serverURLDidChange` was added but not used; the publisher approach was chosen instead as it's more flexible
- ChatViewModel already handles serverURL changes via `manager.updateServerURL()` in `onAppear()`

---

## Assessment (from ROADMAP.md)

| Impact | Simplification | iOS Best Practices |
|--------|----------------|-------------------|
| 3/5 | 3/5 | 4/5 |

**Rationale:**
- Impact: Medium - prevents stale URL issues when switching servers
- Simplification: Removes need for manual reconfiguration or app restart
- iOS Best Practices: Uses Combine publisher pattern, proper MainActor isolation

---

## Completion Log

| Date | Action | Outcome |
|------|--------|---------|
| 2026-01-02 | Started implementation | Audited 5 services that cache serverURL |
| 2026-01-02 | Completed | All services now auto-reconfigure on serverURL change, build passes |
| 2026-01-02 | Verified | Confirmed serverURL observers in all long-lived services |
