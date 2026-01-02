# Issue #25: Finish or remove MessageQueuePersistence

> **Status**: Complete (verified 2026-01-02)
> **Priority**: Tier 2
> **Depends On**: #23
> **Blocks**: #5

---

## Summary

Implement roadmap task: Finish or remove MessageQueuePersistence.

## Problem

Current implementation adds indirection or duplication, which slows debugging and makes behavior harder to reason about. This issue removes the extra layer without changing user-visible behavior.

## Solution

Apply the roadmap change directly, delete the legacy path, and update call sites to use the simplified flow. Keep behavior identical while reducing code paths.

---

## Scope

### In Scope

- Apply the Finish or remove MessageQueuePersistence change in the listed files
- Remove or replace the legacy path

### Out of Scope

- New features or UX changes
- Unrelated refactors outside this task

---

## Implementation

### Files to Modify

| File | Change |
|---|---|
| CodingBridge/Managers/BackgroundManager.swift | Use queue consistently |
| CodingBridge/CodingBridgeApp.swift | Use queue on background |

### Files to Delete

| File | Reason |
|---|---|
| CodingBridge/Persistence/MessageQueuePersistence.swift | Dead code - enqueue() never called, recovery now handled by MessageStore |

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

- [x] Finish or remove MessageQueuePersistence is implemented as described
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
rg -n "MessageQueuePersistence" CodingBridge

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

**Decision**: Delete rather than wire up.

**Audit findings**:
1. `MessageQueuePersistence.save()` was called from `CodingBridgeApp.swift` and `BackgroundManager.swift`
2. `pendingMessages` array was always empty because `enqueue()` was never called anywhere
3. `load()` was never called to restore messages
4. With #23 completed, `MessageStore` now handles all recovery state via `saveGlobalRecoveryState()` and `clearGlobalRecoveryState()`
5. The file was 128 lines of dead code

**Changes made**:
- Deleted `CodingBridge/Persistence/MessageQueuePersistence.swift` (128 lines)
- Removed empty `save()` call from `CodingBridgeApp.handleEnterBackground()` (3 lines)
- Removed empty `save()` call from `BackgroundManager.saveCurrentState()` (3 lines)
- Removed `MessageQueuePersistence` tests from `PersistenceTests.swift` (108 lines)
- Removed `Persistence/` folder reference from `project.pbxproj`

**Total lines removed**: ~265 lines

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
| 2026-01-02 | Started implementation | Audited usage - found MessageQueuePersistence was dead code |
| 2026-01-02 | Completed | Deleted MessageQueuePersistence.swift, updated callers to no-op, updated tests |
| 2026-01-02 | Verified | Confirmed MessageQueuePersistence removal, no remaining references |
