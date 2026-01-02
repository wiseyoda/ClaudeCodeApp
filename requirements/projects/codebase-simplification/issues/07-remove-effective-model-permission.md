# Issue #7: Remove effectiveModelId/effectivePermissionMode indirection

> **Status**: Complete (verified 2026-01-02)
> **Priority**: Tier 3
> **Depends On**: #23
> **Blocks**: None

---

## Summary

Implement roadmap task: Remove effectiveModelId/effectivePermissionMode indirection.

## Problem

Current implementation adds indirection or duplication, which slows debugging and makes behavior harder to reason about. This issue removes the extra layer without changing user-visible behavior.

## Solution

Apply the roadmap change directly, delete the legacy path, and update call sites to use the simplified flow. Keep behavior identical while reducing code paths.

---

## Scope

### In Scope

- Apply the Remove effectiveModelId/effectivePermissionMode indirection change in the listed files
- Remove or replace the legacy path

### Out of Scope

- New features or UX changes
- Unrelated refactors outside this task

---

## Implementation

### Files to Modify

| File | Change |
|---|---|
| CodingBridge/ViewModels/ChatViewModel.swift | Use direct model/permission state |
| CodingBridge/AppSettings.swift | Remove redundant effective helpers if unused |

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

- [x] Remove effectiveModelId/effectivePermissionMode indirection is implemented as described
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
rg -n "effectiveModelId" CodingBridge

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

- `effectiveModelId` retained: provides legitimate resolution logic (session model vs settings model, custom model ID handling)
- `effectivePermissionModeValue` retained: delegates to `PermissionManager.shared.resolvePermissionMode()` - proper abstraction for permission resolution
- Removed `effectivePermissionMode: String` computed property: trivial `.rawValue` wrapper now inlined at 5 call sites

---

## Assessment (from ROADMAP.md)

| Impact | Simplification | iOS Best Practices |
|--------|----------------|-------------------|
| 2/5 | 2/5 | 2/5 |

**Rationale:**
- Impact: Low per roadmap
- Simplification: reduces indirection and duplicate paths

---

## Completion Log

| Date | Action | Outcome |
|------|--------|---------|
| 2026-01-02 | Started implementation | Audited usage, found String wrapper is pure indirection |
| 2026-01-02 | Completed | Removed `effectivePermissionMode: String`, inlined at 5 call sites, build passes |
| 2026-01-02 | Verified | Confirmed no remaining String wrapper usage and call sites reference resolved values |
