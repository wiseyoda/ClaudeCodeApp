# Issue #43: Split Models.swift into model + persistence files

> **Status**: Complete (verified 2026-01-02)
> **Priority**: Tier 2
> **Depends On**: #1
> **Blocks**: None

---

## Summary

Implement roadmap task: Split Models.swift into model + persistence files.

## Problem

Current implementation adds indirection or duplication, which slows debugging and makes behavior harder to reason about. This issue removes the extra layer without changing user-visible behavior.

## Solution

Apply the roadmap change directly, delete the legacy path, and update call sites to use the simplified flow. Keep behavior identical while reducing code paths.

---

## Scope

### In Scope

- Apply the Split Models.swift into model + persistence files change in the listed files
- Remove or replace the legacy path

### Out of Scope

- New features or UX changes
- Unrelated refactors outside this task

---

## Implementation

### Files Created

| File | Contents |
|---|---|
| CodingBridge/Models/ClaudeModel.swift | ClaudeModel enum (88 lines) |
| CodingBridge/Models/ProjectModels.swift | Project, ProjectSession, ProjectSessionMeta (137 lines) |
| CodingBridge/Models/ChatMessage.swift | ChatMessage struct (74 lines) |
| CodingBridge/Models/QuestionTypes.swift | QuestionOption, UserQuestion, AskUserQuestionData (129 lines) |
| CodingBridge/Models/ApprovalTypes.swift | ApprovalRequest, ApprovalResponse (125 lines) |
| CodingBridge/Persistence/MessageStore.swift | MessageStore class, ChatMessageDTO (433 lines) |
| CodingBridge/Persistence/ArchivedProjectsStore.swift | ArchivedProjectsStore class (53 lines) |
| CodingBridge/Persistence/BookmarkStore.swift | BookmarkStore, BookmarkedMessage (126 lines) |
| CodingBridge/Utilities/StringifyAnyValue.swift | stringifyAnyValue() function (60 lines) |

### Files Deleted

| File | Reason |
|---|---|
| CodingBridge/Models.swift | Split into 9 focused files above (1191 lines -> 9 files totaling 1225 lines) |

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

- [x] Split Models.swift into model + persistence files is implemented as described
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
rg -n "Models.swift" CodingBridge

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
| 3/5 | 3/5 | 3/5 |

**Rationale:**
- Impact: Medium per roadmap
- Simplification: reduces indirection and duplicate paths

---

## Completion Log

| Date | Action | Outcome |
|------|--------|---------|
| 2026-01-02 | Started implementation | Split Models.swift into 9 focused files |
| 2026-01-02 | Completed | Build passes, all acceptance criteria verified |
| 2026-01-02 | Verified | Confirmed split files are in project and Models.swift is removed |
