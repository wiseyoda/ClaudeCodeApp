# Issue #42: Split ChatViewModel into focused modules

> **Status**: Complete (verified 2026-01-02)
> **Priority**: Tier 3
> **Depends On**: #17
> **Blocks**: None

---

## Summary

Implement roadmap task: Split ChatViewModel into focused modules.

## Problem

Current implementation adds indirection or duplication, which slows debugging and makes behavior harder to reason about. This issue removes the extra layer without changing user-visible behavior.

## Solution

Apply the roadmap change directly, delete the legacy path, and update call sites to use the simplified flow. Keep behavior identical while reducing code paths.

---

## Scope

### In Scope

- Apply the Split ChatViewModel into focused modules change in the listed files
- Remove or replace the legacy path

### Out of Scope

- New features or UX changes
- Unrelated refactors outside this task

---

## Implementation

### Files to Modify

| File | Change |
|---|---|
| CodingBridge/ViewModels/ChatViewModel.swift | Core state, initialization, lifecycle, message sending (534 lines) |

### Files Created

| File | Purpose | Lines |
|---|---|---|
| CodingBridge/ViewModels/ChatViewModel+Sessions.swift | Session management, selection, history loading | 231 |
| CodingBridge/ViewModels/ChatViewModel+SlashCommands.swift | Slash command registry and handlers | 237 |
| CodingBridge/ViewModels/ChatViewModel+StreamEvents.swift | WebSocket event handling | 358 |
| CodingBridge/ViewModels/ChatViewModel+Git.swift | Git status monitoring and Claude prompts | 228 |
| CodingBridge/ViewModels/ChatViewModel+ManagerState.swift | Manager state accessors, actions, change handlers | 321 |

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

- [x] Split ChatViewModel into focused modules is implemented as described
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
rg -n "ChatViewModel" CodingBridge

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

Split ChatViewModel.swift (1852 lines) into focused extension files:
- Main file reduced to 534 lines (core state, initialization, lifecycle, message sending)
- 5 extension files for logical groupings
- Total: 1909 lines (slight increase due to import statements and extension declarations)
- All behavior preserved - no functional changes

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
| 2026-01-02 | Started implementation | Split ChatViewModel into 5 extension files |
| 2026-01-02 | Completed | All acceptance criteria verified, build passes |
| 2026-01-02 | Verified | Confirmed new ChatViewModel extension files are in project and referenced |
