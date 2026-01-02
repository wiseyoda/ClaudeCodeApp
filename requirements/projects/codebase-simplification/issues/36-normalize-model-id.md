# Issue #36: Normalize model ID handling (echo alias)

> **Status**: Complete (verified 2026-01-02)
> **Priority**: Tier 2
> **Depends On**: None
> **Blocks**: None

---

## Summary

Implement roadmap task: Normalize model ID handling (echo alias).

## Problem

Current implementation adds indirection or duplication, which slows debugging and makes behavior harder to reason about. This issue removes the extra layer without changing user-visible behavior.

## Solution

Apply the roadmap change directly, delete the legacy path, and update call sites to use the simplified flow. Keep behavior identical while reducing code paths.

---

## Scope

### In Scope

- Apply the Normalize model ID handling (echo alias) change in the listed files
- Remove or replace the legacy path

### Out of Scope

- New features or UX changes
- Unrelated refactors outside this task

---

## Implementation

### Files to Modify

| File | Change |
|---|---|
| CodingBridge/CLIBridgeManager.swift | Remove heuristic model matching |
| CodingBridge/ViewModels/ChatViewModel.swift | Use alias from server |

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

- [x] Normalize model ID handling (echo alias) is implemented as described
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
rg -n "modelsMatch" CodingBridge

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

**Change Required**: Return model alias alongside full ID

**API Impact**:
- Endpoint: `WebSocket connected message`
- Change: Add modelAlias field

**GitHub Issue**: https://github.com/wiseyoda/cli-bridge/issues/17

**Status**: Unblocked (cli-bridge changes complete in feature/codebase-simplification)

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
| 2026-01-02 | Verified implementation | Implementation already complete via prior work |
| 2026-01-02 | Completed | All acceptance criteria verified, build passes |
| 2026-01-02 | Verified | Confirmed modelAlias is used and heuristic matching is absent |

## Implementation Notes

The model ID normalization was already implemented:

1. **CLIBridgeManager+Stream.swift line 274** - Uses `payload.modelAlias ?? payload.model` to prefer the server-echoed alias
2. **ClaudeModel.modelId** - Returns simple aliases ("opus", "sonnet", "haiku") that are sent to the server
3. **No heuristic matching** - No code exists to parse full model IDs (like "claude-sonnet-4-5-20250929") back to aliases

The cli-bridge server echoes back `modelAlias` in `ConnectedMessage`, which the iOS client now uses directly. This eliminates any need for heuristic pattern matching on the client side.
