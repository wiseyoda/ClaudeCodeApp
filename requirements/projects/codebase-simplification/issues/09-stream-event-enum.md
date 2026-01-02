# Issue #9: WebSocket callbacks -> StreamEvent enum

> **Status**: Pending
> **Priority**: Tier 1
> **Depends On**: None
> **Blocks**: #10/#11/#15/#17/#31/#45

---

## Summary

Implement roadmap task: WebSocket callbacks -> StreamEvent enum.

## Problem

Current implementation adds indirection or duplication, which slows debugging and makes behavior harder to reason about. This issue removes the extra layer without changing user-visible behavior.

## Solution

Apply the roadmap change directly, delete the legacy path, and update call sites to use the simplified flow. Keep behavior identical while reducing code paths.

---

## Scope

### In Scope

- Apply the WebSocket callbacks -> StreamEvent enum change in the listed files
- Remove or replace the legacy path

### Out of Scope

- New features or UX changes
- Unrelated refactors outside this task

---

## Implementation

### Files to Modify

| File | Change |
|---|---|
| CodingBridge/CLIBridgeManager.swift | Emit StreamEvent enum |
| CodingBridge/CLIBridgeAdapter.swift | Map events into a single callback |
| CodingBridge/ViewModels/ChatViewModel.swift | Switch on StreamEvent |

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

- [ ] WebSocket callbacks -> StreamEvent enum is implemented as described
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
rg -n "onText" CodingBridge

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