# Issue #32: Multi-repo/monorepo git status aggregation

> **Status**: Complete (verified 2026-01-02)
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

- [x] Multi-repo/monorepo git status aggregation is implemented as described
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
| 2026-01-02 | Audit | Feature already implemented |
| 2026-01-02 | Completed | All acceptance criteria verified, build passes |
| 2026-01-02 | Verified | Confirmed subrepo discovery and aggregation are already implemented; unit tests cover MultiRepoStatus summaries |

### Implementation Details

The multi-repo/monorepo git status aggregation was found to be already fully implemented:

**API Layer** (`CLIBridgeAPIClient.swift`):
- `discoverSubRepos(projectPath:maxDepth:)` - GET /projects/{encodedPath}/subrepos
- `pullSubRepo(projectPath:relativePath:)` - POST /projects/{encodedPath}/subrepos/{relativePath}/pull

**Coordinator** (`GitStatusCoordinator.swift`):
- `multiRepoStatuses: [String: MultiRepoStatus]` - Published state for all projects
- `discoverAllSubRepos()` - Parallel discovery for all projects with subrepo discovery enabled
- `refreshAllSubRepos()` - Refresh sub-repos for a single project
- `pullSubRepo()` / `pullAllBehindSubRepos()` - Pull operations

**Data Models** (`GitModels.swift`):
- `SubRepo` - Individual nested git repository
- `MultiRepoStatus` - Aggregated status with computed properties:
  - `summary` - Human-readable summary (e.g., "2 dirty, 1 behind")
  - `worstStatus` - Most actionable status for badge coloring
  - `hasActionableItems` - Whether any sub-repo needs attention
  - `pullableCount` - Count of sub-repos that can be auto-pulled

**UI Components** (`ProjectListViews.swift`):
- `MultiRepoSummaryBadge` - Shows aggregated status when project is collapsed
- `SubRepoRow` - Individual sub-repo with status and actions
- `SubRepoActionBar` - "Pull All Behind" and "Refresh All" actions

**Settings** (`ProjectSettingsStore.swift`):
- `isSubrepoDiscoveryEnabled(for:)` - Opt-in per-project setting

Files using subrepo functionality: 12 files across the codebase.
