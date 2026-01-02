# Issue #29: Standardize SSHManager ownership

> **Status**: Complete (verified 2026-01-02)
> **Priority**: Tier 2
> **Depends On**: None
> **Blocks**: #44

---

## Summary

Implement roadmap task: Standardize SSHManager ownership.

## Problem

Current implementation adds indirection or duplication, which slows debugging and makes behavior harder to reason about. This issue removes the extra layer without changing user-visible behavior.

## Solution

Apply the roadmap change directly, delete the legacy path, and update call sites to use the simplified flow. Keep behavior identical while reducing code paths.

---

## Scope

### In Scope

- Apply the Standardize SSHManager ownership change in the listed files
- Remove or replace the legacy path

### Out of Scope

- New features or UX changes
- Unrelated refactors outside this task

---

## Implementation

### Files to Modify

| File | Change |
|---|---|
| CodingBridge/SSHManager.swift | Clarify singleton vs instance usage |
| CodingBridge/TerminalView.swift | Use shared manager or explicit instance |

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

- [x] Standardize SSHManager ownership is implemented as described
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
rg -n "SSHManager.shared" CodingBridge

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

None.

---

## Assessment (from ROADMAP.md)

| Impact | Simplification | iOS Best Practices |
|--------|----------------|-------------------|
| 3/5 | 3/5 | 3/5 |

**Rationale:**
- Impact: Medium per roadmap
- Simplification: reduces indirection and duplicate paths

---

## Completion Log

| Date | Action | Outcome |
|------|--------|---------|
| 2026-01-02 | Started implementation | Audited SSHManager usage |
| 2026-01-02 | Completed | Removed unused singleton, clarified per-view ownership |
| 2026-01-02 | Verified | Confirmed SSHManager is instance-owned and no shared singleton remains |

### Resolution Details

**Audit findings:**
1. `SSHManager.shared` singleton was defined but never used anywhere
2. TerminalView creates its own instance via `@StateObject private var sshManager = SSHManager()`
3. All file/git operations migrated to CLIBridgeAPIClient (no other SSHManager usage)

**Decision:** Per-view instance is correct because each TerminalView needs its own:
- Connection state (isConnected, isConnecting)
- Host/username/port
- Output buffer
- Current directory

**Changes made:**
- Removed unused `static let shared = SSHManager()` singleton
- Added clarifying comment explaining the per-view ownership pattern
