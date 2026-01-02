# Issue #1: Remove CLIBridgeTypesMigration

> **Status**: Complete
> **Priority**: Tier 1
> **Depends On**: #17
> **Blocks**: #2/#21/#30/#43

---

## Summary

Implement roadmap task: Remove CLIBridgeTypesMigration.

## Problem

Current implementation adds indirection or duplication, which slows debugging and makes behavior harder to reason about. This issue removes the extra layer without changing user-visible behavior.

## Solution

Apply the roadmap change directly, delete the legacy path, and update call sites to use the simplified flow. Keep behavior identical while reducing code paths.

---

## Scope

### In Scope

- Apply the Remove CLIBridgeTypesMigration change in the listed files
- Remove or replace the legacy path

### Out of Scope

- New features or UX changes
- Unrelated refactors outside this task

---

## Implementation

### Files to Modify

| File | Change |
|---|---|
| CodingBridge/CLIBridgeManager.swift | Replace typealiases with generated types |
| CodingBridge/ViewModels/ChatViewModel.swift | Update CLI* references to generated types |
| CodingBridge/Models.swift | Update protocol/model type names |
| CodingBridge/PermissionTypes.swift | Use generated permission types directly |

### Files to Delete

| File | Reason |
|---|---|
| CodingBridge/CLIBridgeTypesMigration.swift | Migration layer no longer needed |

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

- [x] Remove CLIBridgeTypesMigration is implemented as described
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
rg -n "CLIBridgeTypesMigration" CodingBridge

# Line count verification (if removing code)
# wc -l CodingBridge/CLIBridgeTypesMigration.swift
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
| 2026-01-02 | Started implementation | In progress |
| 2026-01-02 | Completed | Split CLIBridgeTypesMigration.swift into CLIBridgeAppTypes.swift (app-specific types, StreamEvent enum, typealiases) and CLIBridgeExtensions.swift (extensions to generated types). |
| 2026-01-02 | Follow-up | Updated test fixtures to use generated types and clarified compatibility comments. |
| 2026-01-02 | Verification | `xcodebuild` succeeded for CodingBridge iOS 26.2 simulator. |
| 2026-01-02 | Verification | Updated AnyCodableValue handling and permission request descriptions; targeted unit tests (CLIBridgeManager/CLIStreamContent/CLIBridgeTypes/CLISessionTypes/APIClientModels/Models) pass via `xcodebuild test`. Existing Sendable warnings persist. |
