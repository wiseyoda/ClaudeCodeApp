# Issue #4: Eliminate extractFilePath() parsing

> **Status**: Complete
> **Priority**: Tier 2
> **Depends On**: None
> **Blocks**: None

---

## Summary

Implement roadmap task: Eliminate extractFilePath() parsing.

## Problem

Current implementation adds indirection or duplication, which slows debugging and makes behavior harder to reason about. This issue removes the extra layer without changing user-visible behavior.

## Solution

Apply the roadmap change directly, delete the legacy path, and update call sites to use the simplified flow. Keep behavior identical while reducing code paths.

---

## Scope

### In Scope

- Apply the Eliminate extractFilePath() parsing change in the listed files
- Remove or replace the legacy path

### Out of Scope

- New features or UX changes
- Unrelated refactors outside this task

---

## Implementation

### Files to Modify

| File | Change |
|---|---|
| CodingBridge/Views/CompactToolView.swift | Use structured data instead of string parsing |

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

- [x] Eliminate extractFilePath() parsing is implemented as described
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
rg -n "extractFilePath" CodingBridge

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
| 2026-01-02 | Started implementation | Replaced extractFilePath() with ToolParser.extractParam() calls |
| 2026-01-02 | Completed | All acceptance criteria verified, build passes, 10 lines net reduction |
| 2026-01-02 | Verified | Confirmed no extractFilePath() references remain in the repo |
