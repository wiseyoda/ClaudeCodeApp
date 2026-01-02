# Issue #45: Split CLIBridgeManager into connection + stream handler

> **Status**: Complete (verified 2026-01-02)
> **Priority**: Tier 2
> **Depends On**: #9/#17/#27
> **Blocks**: None

---

## Summary

Implement roadmap task: Split CLIBridgeManager into connection + stream handler.

## Problem

Current implementation adds indirection or duplication, which slows debugging and makes behavior harder to reason about. This issue removes the extra layer without changing user-visible behavior.

## Solution

Apply the roadmap change directly, delete the legacy path, and update call sites to use the simplified flow. Keep behavior identical while reducing code paths.

---

## Scope

### In Scope

- Apply the Split CLIBridgeManager into connection + stream handler change in the listed files
- Remove or replace the legacy path

### Out of Scope

- New features or UX changes
- Unrelated refactors outside this task

---

## Implementation

### Files to Modify

| File | Change |
|---|---|
| CodingBridge/CLIBridgeManager.swift | Extract connection and stream handling |

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

- [x] Split CLIBridgeManager into connection + stream handler is implemented as described
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
rg -n "CLIBridgeManager" CodingBridge

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

### Implementation Details

Split CLIBridgeManager.swift (1188 lines) into 5 files:

| File | Lines | Purpose |
|------|-------|---------|
| CLIBridgeManager.swift | 496 | Core state, initialization, internal accessors |
| CLIBridgeManager+Connection.swift | 233 | Connect, disconnect, reconnect logic |
| CLIBridgeManager+Lifecycle.swift | 125 | App lifecycle, network monitoring |
| CLIBridgeManager+Messages.swift | 85 | Message sending methods |
| CLIBridgeManager+Stream.swift | 387 | WebSocket message handling, event dispatch |
| **Total** | **1326** | (includes new accessor methods for extensions) |

### Architecture

The main file now contains:
- All `@Published` properties (state)
- Private state variables
- Internal accessor methods for extensions
- URL building and message encoding
- `emit()` helper for event dispatch

Extensions in the same module can access internal members, so the main file provides getter/setter methods for private state that extensions need to modify.

### Lines Saved

This refactor does not reduce total lines but improves organization:
- Main file reduced from 1188 to ~497 lines (59% reduction)
- Logical separation of concerns reduces cognitive load
- Easier to find and modify specific functionality

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
| 2026-01-02 | Started implementation | Split into 4 extension files |
| 2026-01-02 | Completed | All acceptance criteria verified, build passes |
| 2026-01-02 | Verified | Confirmed split files exist and are included in the Xcode project |
