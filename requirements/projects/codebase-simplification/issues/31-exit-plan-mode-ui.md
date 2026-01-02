# Issue #31: Exit Plan Mode approval UI

> **Status**: Complete (verified 2026-01-02)
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

- [x] Exit Plan Mode approval UI is implemented as described
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

### Implementation Summary

**Files Modified:**
1. `CodingBridge/Models.swift` - Added `isExitPlanMode`, `planContent` properties to ApprovalRequest
2. `CodingBridge/Views/ApprovalBannerView.swift` - Added `ExitPlanModeApprovalView` component
3. `CodingBridge/ChatView.swift` - Added sheet presentation for ExitPlanMode approval

**How it works:**
1. When a permission request arrives with `tool: "ExitPlanMode"`, `ApprovalRequest.isExitPlanMode` returns `true`
2. ChatView detects this and presents `ExitPlanModeApprovalView` as a sheet instead of the inline banner
3. The sheet displays the plan content as markdown using `MarkdownText` component
4. User can Approve or Reject the plan using toolbar or bottom buttons
5. Response is sent via `viewModel.approvePendingRequest()` or `viewModel.denyPendingRequest()`

**Build Note:** Build verification now passes; ExitPlanMode flow is fully wired.

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
| 2026-01-02 | Started implementation | In progress |
| 2026-01-02 | Completed | ExitPlanMode approval sheet and request handling implemented |
| 2026-01-02 | Verified | Build passes; ExitPlanMode approval UI works end-to-end |
