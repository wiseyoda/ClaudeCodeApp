# Issue #32: Multi-repo/monorepo git status aggregation

> **Status**: Pending
> **Priority**: Tier 3
> **Depends On**: None
> **Blocks**: None

---

## Summary

Implement roadmap task: Multi-repo/monorepo git status aggregation.

## Problem

Current implementation adds indirection or duplication, which slows debugging and makes behavior harder to reason about. This issue removes the extra layer without changing user-visible behavior.

## Solution

Apply the roadmap change directly, delete the legacy path, and update call sites to use the simplified flow. Keep behavior identical while reducing code paths.

---

## Scope

### In Scope

- Apply the Multi-repo/monorepo git status aggregation change in the listed files
- Remove or replace the legacy path

### Out of Scope

- New features or UX changes
- Unrelated refactors outside this task

---

## Implementation

### Files to Modify

| File | Change |
|---|---|
| CodingBridge/Managers/GitStatusCoordinator.swift | Aggregate per-repo statuses |
| CodingBridge/CLIBridgeAPIClient.swift | Use subrepo endpoints if needed |

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

- [ ] Multi-repo/monorepo git status aggregation is implemented as described
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
rg -n "subrepo" CodingBridge

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

**Change Required**: ✅ None - endpoint already exists

**API Impact**:
- Endpoint: `GET /projects/{encodedPath}/subrepos?maxDepth=2`
- Returns all nested git repos with their status
- Also: `POST /projects/{encodedPath}/subrepos/{relativePath}/pull`

**GitHub Issue**: [cli-bridge#30](https://github.com/wiseyoda/cli-bridge/issues/30) ✅ Closed

**Status**: ✅ Complete - documented in `specifications/reference/protocol.md`

**Example response:**
```json
{
  "subrepos": [{
    "relativePath": "packages/core",
    "git": { "branch": "main", "ahead": 0, "behind": 2, ... }
  }]
}
```

---

## Notes

None.

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
| YYYY-MM-DD | Started implementation | Pending |
| YYYY-MM-DD | Completed | Pending |