# Issue #27: Consolidate network/lifecycle/reconnect logic

> **Status**: Complete
> **Priority**: Tier 1
> **Depends On**: #17
> **Blocks**: #23/#45

---

## Summary

Implement roadmap task: Consolidate network/lifecycle/reconnect logic.

## Problem

Current implementation adds indirection or duplication, which slows debugging and makes behavior harder to reason about. This issue removes the extra layer without changing user-visible behavior.

## Solution

Apply the roadmap change directly, delete the legacy path, and update call sites to use the simplified flow. Keep behavior identical while reducing code paths.

---

## Scope

### In Scope

- Apply the Consolidate network/lifecycle/reconnect logic change in the listed files
- Remove or replace the legacy path

### Out of Scope

- New features or UX changes
- Unrelated refactors outside this task

---

## Implementation

### Files to Modify

| File | Change |
|---|---|
| CodingBridge/CLIBridgeManager.swift | Centralize lifecycle handling |
| CodingBridge/Utilities/NetworkMonitor.swift | Remove duplicate reconnect triggers |
| CodingBridge/ChatView.swift | Avoid redundant reconnects |

### Files to Delete

| File | Reason |
|---|---|
| None | N/A |

### Steps

1. **Audit**
   - Review current implementation and usage
   - Confirm dependent call sites

2. **Implement**
   - Apply the simplification change
   - Update references and remove old code paths

3. **Verify**
   - Build passes: `xcodebuild -project CodingBridge.xcodeproj -scheme CodingBridge -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'`
   - No new warnings
   - App launches and basic functionality works

---

## Acceptance Criteria

- [x] Consolidate network/lifecycle/reconnect logic is implemented as described
- [x] Legacy paths are removed or no longer used
- [x] Build passes with no new warnings
- [x] No user-visible behavior changes

---

## Verification Commands

```bash
# Build verification
xcodebuild -project CodingBridge.xcodeproj -scheme CodingBridge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'

# Custom verification command if applicable
rg -n "Task.sleep" CodingBridge

# Line count verification (if removing code)
# wc -l path/to/file.swift
```

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Behavior regression from deleted paths | Keep behavior tests/manual checks and verify builds |
| Missed references after cleanup | Use `rg` to confirm symbol removal and update all call sites |

---

## Notes

**Analysis Summary:**

The audit identified two network monitors with distinct purposes:
1. **CLIBridgeManager** (internal NWPathMonitor): Handles WebSocket reconnection via lifecycle observers (didBecomeActiveNotification, network path changes)
2. **NetworkMonitor.swift** (singleton): Provides network status for UI display and offline action queuing - NOT for reconnects

The duplicate reconnect trigger was in **ChatView.swift**:
- `onChange(of: scenePhase)` handler that called `manager.connect()` on `.active`
- This duplicated CLIBridgeManager's `didBecomeActiveNotification` observer

**Changes Made:**
- Removed scenePhase reconnect handler from ChatView.swift (19 lines deleted)
- CLIBridgeManager remains the single source of truth for connection lifecycle

**Not Changed (by design):**
- NetworkMonitor.swift notifications: Used for offline queue processing, not reconnection
- attemptSessionReattachment polling: Different purpose (session recovery on app startup)
- backgroundRecoveryNeeded handler: Explicit recovery path for push notification scenarios

---

## Assessment (from ROADMAP.md)

| Impact | Simplification | iOS Best Practices |
|--------|----------------|-------------------|
| 5/5 | 5/5 | 5/5 |

**Rationale:**
- Impact: High per roadmap
- Simplification: reduces indirection and duplicate paths

---

## Completion Log

| Date | Action | Outcome |
|------|--------|---------|
| 2026-01-02 | Started implementation | Auditing reconnect patterns |
| 2026-01-02 | Completed | Removed duplicate scenePhase reconnect from ChatView; CLIBridgeManager is single source of truth |
