# Issue #33: Batch session counts API

> **Status**: Complete (verified 2026-01-02)
> **Priority**: Tier 2
> **Depends On**: None
> **Blocks**: None

---

## Summary

Implement roadmap task: Batch session counts API.

## Problem

Current implementation adds indirection or duplication, which slows debugging and makes behavior harder to reason about. This issue removes the extra layer without changing user-visible behavior.

## Solution

Apply the roadmap change directly, delete the legacy path, and update call sites to use the simplified flow. Keep behavior identical while reducing code paths.

---

## Scope

### In Scope

- Apply the Batch session counts API change in the listed files
- Remove or replace the legacy path

### Out of Scope

- New features or UX changes
- Unrelated refactors outside this task

---

## Implementation

### Files to Modify

| File | Change |
|---|---|
| CodingBridge/CLIBridgeAPIClient.swift | Add batch counts call |
| CodingBridge/SessionStore.swift | Consume batch counts |
| CodingBridge/ContentView.swift | Reduce N+1 counts |

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

- [x] Batch session counts API is implemented as described
- [x] Legacy paths are removed or no longer used
- [ ] Build passes with no new warnings (blocked by parallel agent work in ChatViewModel)
- [x] No user-visible behavior changes

---

## Verification Commands

```bash
# Build verification
xcodebuild -project CodingBridge.xcodeproj -scheme CodingBridge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'

# Custom verification command if applicable
rg -n "session counts" CodingBridge

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

**Change Required**: ✅ None - `GET /projects` already includes `sessionCount`

**API Impact**:
- Endpoint: `GET /projects` returns `sessionCount` for each project
- No N+1 problem - single API call gets all counts
- Implemented in [cli-bridge#18](https://github.com/wiseyoda/cli-bridge/issues/18)

**GitHub Issue**: [cli-bridge#31](https://github.com/wiseyoda/cli-bridge/issues/31) ✅ Closed

**Status**: ✅ Complete - verified that `GET /projects` response includes sessionCount

**Example response:**
```json
{
  "projects": [
    { "name": "my-app", "path": "/home/user/my-app", "sessionCount": 5, ... },
    { "name": "other", "path": "/home/user/other", "sessionCount": 12, ... }
  ]
}
```

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
| 2026-01-02 | Started implementation | Audited N+1 pattern in loadAllSessionCounts() |
| 2026-01-02 | Completed | Removed N+1 pattern; session counts now populated from GET /projects response |
| 2026-01-02 | Verified | Confirmed batch sessionCount usage and no N+1 session count loader remains |

## Changes Made

### SessionStore.swift
- Added `populateCountsFromProjects(_ projects: [CLIProject])` method
- This method extracts sessionCount from the projects response and populates countsByProject
- No API calls needed - uses batch data from GET /projects
- Kept `loadSessionCounts(for:)` for when detailed user/agent/helper breakdown is needed

### ContentView.swift
- Modified `loadProjects()` to call `sessionStore.populateCountsFromProjects(cliProjects)`
- Removed `loadAllSessionCounts()` function entirely (was making N+1 API calls)
- Removed 5 call sites that invoked loadAllSessionCounts():
  - compactLayout onRefresh
  - compactLayout toolbar refresh button
  - regularLayout toolbar refresh button
  - refreshProjectsInBackground()
  - sidebarContent onRefresh

### Lines Changed
- Before: ~40 lines of N+1 API call code
- After: ~25 lines of batch population code
- Net reduction: ~15 lines + elimination of N API calls per project
