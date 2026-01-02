# Issue #40: Standardize ISO8601 with fractional seconds

> **Status**: Complete (verified 2026-01-02)
> **Priority**: Tier 3
> **Depends On**: None
> **Blocks**: None

---

## Summary

Implement roadmap task: Standardize ISO8601 with fractional seconds.

## Problem

Current implementation adds indirection or duplication, which slows debugging and makes behavior harder to reason about. This issue removes the extra layer without changing user-visible behavior.

## Solution

Apply the roadmap change directly, delete the legacy path, and update call sites to use the simplified flow. Keep behavior identical while reducing code paths.

---

## Scope

### In Scope

- Apply the Standardize ISO8601 with fractional seconds change in the listed files
- Remove or replace the legacy path

### Out of Scope

- New features or UX changes
- Unrelated refactors outside this task

---

## Implementation

### Files to Modify

| File | Change |
|---|---|
| CodingBridge/CLIBridgeAppTypes.swift | Remove fallback `iso8601` formatter; simplify `parseDate()` to single formatter |
| CodingBridge/SessionStore.swift | Replace local dual formatters with `CLIDateFormatter.parseDate()` |
| CodingBridge/CLIBridgeExtensions.swift | Replace local formatter with `CLIDateFormatter.string(from:)` |

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

- [x] Standardize ISO8601 with fractional seconds is implemented as described
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
rg -n "CLIDateFormatter" CodingBridge

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

**Change Required**: Always emit fractional seconds in date fields

**API Impact**:
- Endpoint: `All date fields`
- Change: Standardize on ISO8601 with fractional seconds

**GitHub Issue**: https://github.com/wiseyoda/cli-bridge/issues/13

**Status**: Unblocked (cli-bridge changes complete in feature/codebase-simplification)

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
| 2026-01-02 | Started implementation | Identified dual formatter in CLIBridgeAppTypes.swift and duplicates in SessionStore, CLIBridgeExtensions |
| 2026-01-02 | Completed | Simplified to single fractional seconds formatter; removed 19 lines; build passes |
| 2026-01-02 | Verified | Replaced remaining ISO8601DateFormatter usage in ChatViewModel with CLIDateFormatter |
