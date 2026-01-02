# Issue #17: Remove CLIBridgeAdapter layer

> **Status**: Pending
> **Priority**: Tier 1
> **Depends On**: #9
> **Blocks**: #1/#15/#27/#30/#42/#45

---

## Summary

Implement roadmap task: Remove CLIBridgeAdapter layer.

## Problem

Current implementation adds indirection or duplication, which slows debugging and makes behavior harder to reason about. This issue removes the extra layer without changing user-visible behavior.

## Solution

Apply the roadmap change directly, delete the legacy path, and update call sites to use the simplified flow. Keep behavior identical while reducing code paths.

---

## Scope

### In Scope

- Apply the Remove CLIBridgeAdapter layer change in the listed files
- Remove or replace the legacy path

### Out of Scope

- New features or UX changes
- Unrelated refactors outside this task

---

## Implementation

### Files to Modify

| File | Change |
|---|---|
| CodingBridge/ViewModels/ChatViewModel.swift | Use CLIBridgeManager directly |
| CodingBridge/ChatView.swift | Update bindings to manager state |

### Files to Delete

| File | Reason |
|---|---|
| CodingBridge/CLIBridgeAdapter.swift | Adapter layer removed |

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

- [ ] Remove CLIBridgeAdapter layer is implemented as described
- [ ] Legacy paths are removed or no longer used
- [ ] Build passes with no new warnings
- [ ] No user-visible behavior changes

---

## Verification Commands

```bash
# Build verification
xcodebuild -project CodingBridge.xcodeproj -scheme CodingBridge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'

# Custom verification command if applicable
rg -n "CLIBridgeAdapter" CodingBridge

# Line count verification (if removing code)
# wc -l CodingBridge/CLIBridgeAdapter.swift
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
| 5/5 | 5/5 | 5/5 |

**Rationale:**
- Impact: High per roadmap
- Simplification: reduces indirection and duplicate paths

---

## Completion Log

| Date | Action | Outcome |
|------|--------|---------|
| YYYY-MM-DD | Started implementation | Pending |
| YYYY-MM-DD | Completed | Pending |