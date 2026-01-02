# Issue #9: WebSocket callbacks -> StreamEvent enum

> **Status**: Complete
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

- [x] WebSocket callbacks -> StreamEvent enum is implemented as described
- [x] Legacy callbacks removed (Manager + tests migrated to StreamEvent)
- [x] Build passes with no new warnings
- [x] No user-visible behavior changes

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
| 2026-01-02 | Phase 1: StreamEvent enum and dual-emit in CLIBridgeManager | Complete |
| 2026-01-02 | Phase 2: CLIBridgeAdapter migration to onEvent | Complete |
| 2026-01-02 | Phase 3: ChatViewModel migration | Completed in #17 after CLIBridgeAdapter removal |
| 2026-01-02 | Phase 4: Legacy callback removal | Complete |
| 2026-01-02 | Verification | Added WebSocket date decoder; targeted unit tests (CLIBridgeManager/CLIStreamContent/CLIBridgeTypes/CLISessionTypes/APIClientModels/Models) pass via `xcodebuild test`. Existing Sendable warnings persist. |

### Phase 1 Details (Complete)

**Files Changed:**
- `CLIBridgeTypesMigration.swift` - Added StreamEvent enum (28 cases, ~180 lines)
- `CLIBridgeManager.swift` - Added onEvent callback and dual-emit at all event points

**StreamEvent Cases:**
- Content: text, thinking, toolStart, toolResult, system, user, progress, usage
- Agent: stateChanged, stopped, modelChanged, permissionModeChanged
- Session: connected, sessionEvent, history
- Interactive: permissionRequest, questionRequest
- Subagent: subagentStart, subagentComplete
- Queue: inputQueued, queueCleared
- Connection: connectionReplaced, reconnecting, reconnectComplete, connectionError, networkStatusChanged
- Cursor: cursorEvicted, cursorInvalid
- Error: error

**Build:** Verified passing

### Phase 2 Details (Complete)

**Files Changed:**
- `CLIBridgeAdapter.swift` - Replaced 20+ individual callback assignments with single `onEvent` handler

**Before:** ~187 lines of individual callback setup (`manager.onText = { ... }`, `manager.onThinking = { ... }`, etc.)
**After:** Single `handleStreamEvent(_ event: StreamEvent)` method with switch statement

**Build:** Verified passing

### Phase 3 Details (Complete)

ChatViewModel now handles `StreamEvent` directly via `CLIBridgeManager` after #17 removed the adapter layer. The previous adapter-specific callback surface is no longer in use.

### Phase 4 Details (Complete)

Legacy callbacks in `CLIBridgeManager.swift` were removed after migrating tests to use `onEvent`. `CLIBridgeManagerTests.swift` now emits and asserts `StreamEvent` values directly; `CLIBridgeAdapterTests.swift` was removed in #17.

### Summary

The core simplification goal (49 callbacks → 1 unified StreamEvent enum) is complete. CLIBridgeAdapter uses a single `onEvent` callback instead of 20+ individual assignments, and CLIBridgeManager no longer exposes legacy callbacks.
