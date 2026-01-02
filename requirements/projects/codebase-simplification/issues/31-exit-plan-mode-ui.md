# Issue #31: Exit Plan Mode approval UI

> **Status**: Pending
> **Priority**: Tier 2
> **Depends On**: #9/#24
> **Blocks**: None

---

## Summary

Implement roadmap task: Exit Plan Mode approval UI.

## Problem

Current implementation adds indirection or duplication, which slows debugging and makes behavior harder to reason about. This issue removes the extra layer without changing user-visible behavior.

## Solution

Apply the roadmap change directly, delete the legacy path, and update call sites to use the simplified flow. Keep behavior identical while reducing code paths.

---

## Scope

### In Scope

- Apply the Exit Plan Mode approval UI change in the listed files
- Remove or replace the legacy path

### Out of Scope

- New features or UX changes
- Unrelated refactors outside this task

---

## Implementation

### Files to Modify

| File | Change |
|---|---|
| CodingBridge/ViewModels/ChatViewModel.swift | Handle ExitPlanMode tool call |
| CodingBridge/Views/ApprovalBannerView.swift | Add plan exit options |
| CodingBridge/ChatView.swift | Present approval UI |

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

- [ ] Exit Plan Mode approval UI is implemented as described
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
rg -n "ExitPlanMode" CodingBridge

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

## cli-bridge Dependency

**Change Required**: ✅ None - already works via permission system

**API Impact**:
- Endpoint: `WebSocket/streaming tool events`
- ExitPlanMode comes through as `permission_request` with `tool: "ExitPlanMode"` and `input: { plan: "..." }`

**GitHub Issue**: [cli-bridge#29](https://github.com/wiseyoda/cli-bridge/issues/29) ✅ Closed

**Status**: ✅ Complete - documented in `specifications/reference/protocol.md`

**iOS Implementation**:
1. Detect `tool === "ExitPlanMode"` in permission request handler
2. Render `input.plan` as markdown
3. Show Approve/Reject buttons
4. Send `permission_response` with `choice: "allow"` or `"deny"`

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
| YYYY-MM-DD | Started implementation | Pending |
| YYYY-MM-DD | Completed | Pending |