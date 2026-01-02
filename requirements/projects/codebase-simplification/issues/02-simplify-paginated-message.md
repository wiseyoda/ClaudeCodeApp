# Issue #2: Simplify PaginatedMessage.toChatMessage()

> **Status**: Complete (verified 2026-01-02)
> **Priority**: Tier 2
> **Depends On**: #1/#35
> **Blocks**: #3

---

## Summary

Implement roadmap task: Simplify PaginatedMessage.toChatMessage().

## Problem

Current implementation adds indirection or duplication, which slows debugging and makes behavior harder to reason about. This issue removes the extra layer without changing user-visible behavior.

## Solution

Apply the roadmap change directly, delete the legacy path, and update call sites to use the simplified flow. Keep behavior identical while reducing code paths.

---

## Scope

### In Scope

- Apply the Simplify PaginatedMessage.toChatMessage() change in the listed files
- Remove or replace the legacy path

### Out of Scope

- New features or UX changes
- Unrelated refactors outside this task

---

## Implementation

### Files to Modify

| File | Change |
|---|---|
| CodingBridge/CLIBridgeExtensions.swift | Replace multi-path parsing with a single switch on StreamMessage |

> Note: Original issue referenced CLIBridgeTypesMigration.swift which was deleted in Issue #1. The code now lives in CLIBridgeExtensions.swift.

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

- [x] Simplify PaginatedMessage.toChatMessage() is implemented as described
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
rg -n "toChatMessage" CodingBridge

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

**Change Required**: Return typed StreamMessage in paginated responses

**API Impact**:
- Endpoint: `GET /projects/:encodedPath/sessions/:id/messages`
- Change: Change message field to StreamMessage

**GitHub Issue**: https://github.com/wiseyoda/cli-bridge/issues/21

**Status**: Complete - cli-bridge already returns typed StreamMessage in PaginatedMessage.message field. The `rawContent` path was a legacy fallback that is no longer needed.

---

## Notes

cli-bridge already returns typed StreamMessage (#35 is resolved). The implementation had two parsing paths:
1. `rawContent` (ContentBlock array) - legacy fallback
2. `message` (StreamMessage) - typed, complete data

The `message` path has MORE data than `rawContent` (e.g., `ToolResultStreamMessage` has `success` field that `ToolResultBlock` lacks), making the `rawContent` path not only redundant but less accurate for error detection.

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
| 2026-01-02 | Started implementation | Audited code, found rawContent path redundant |
| 2026-01-02 | Completed | Removed rawContent parsing path, 25 lines saved, build passes |
| 2026-01-02 | Verified | Confirmed PaginatedMessage.toChatMessage uses StreamMessage only |

### Changes Made
- `CLIBridgeExtensions.swift`: Removed 25 lines of redundant `rawContent` parsing in `PaginatedMessage.toChatMessage()`
- Added explicit handling for all StreamMessage cases (no `default` fallthrough)
- Added documentation comments matching `StoredMessage.toChatMessage()` style

### Before/After
- Before: 1463 lines in CLIBridgeExtensions.swift
- After: 1438 lines
- Reduction: 25 lines (1.7%)
