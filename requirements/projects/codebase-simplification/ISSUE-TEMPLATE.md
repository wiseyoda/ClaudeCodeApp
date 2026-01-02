# Issue Template

> Copy this template to create new issue files in `issues/`.
> File naming: `{number}-{short-name}.md` (e.g., `09-callback-consolidation.md`)

---

# Issue #{NUMBER}: {TITLE}

> **Status**: Pending | In Progress | Complete | Blocked | Skipped
> **Priority**: Tier 1 | Tier 2 | Tier 3 | Tier 4
> **Depends On**: #{DEP} or "None"
> **Blocks**: #{BLOCKED} or "None"

---

## Summary

{One sentence describing what this issue accomplishes.}

## Problem

{2-3 sentences explaining why this is a problem. What pain does it cause? How does it slow down debugging or development?}

## Solution

{2-3 sentences describing the approach. Be specific about what gets deleted, changed, or consolidated.}

---

## Scope

### In Scope

- {Specific file or function to modify}
- {Specific file or function to delete}
- {Specific pattern to replace}

### Out of Scope

- {Related work that should NOT be done in this issue}
- {Tempting improvements that are NOT part of this task}

---

## Implementation

### Files to Modify

| File | Change |
|------|--------|
| `path/to/file.swift` | {Brief description of change} |
| `path/to/other.swift` | {Brief description of change} |

### Files to Delete

| File | Reason |
|------|--------|
| `path/to/delete.swift` | {Why it's no longer needed} |

### Steps

1. **{Step title}**
   - {Specific action}
   - {Specific action}

2. **{Step title}**
   - {Specific action}
   - {Specific action}

3. **Verify**
   - Build passes: `xcodebuild -project CodingBridge.xcodeproj -scheme CodingBridge -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'`
   - No new warnings
   - App launches and basic functionality works

---

## Acceptance Criteria

- [ ] {Specific, verifiable criterion}
- [ ] {Specific, verifiable criterion}
- [ ] Build passes with no new warnings
- [ ] No user-visible behavior changes

---

## Verification Commands

```bash
# Build verification
xcodebuild -project CodingBridge.xcodeproj -scheme CodingBridge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'

# {Custom verification command if applicable}
{command to verify specific change}

# Line count verification (if removing code)
wc -l CodingBridge/{file}.swift  # Expected: {number} or deleted
```

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| {What could go wrong} | {How to prevent or recover} |

---

## cli-bridge Dependency

> **Delete this section if not applicable.** Include only if this issue requires or would benefit from cli-bridge changes.

**Is a cli-bridge change the best solution?** Before implementing an iOS workaround, consider:
- Is this complexity caused by a cli-bridge API limitation?
- Would a small backend change eliminate significant iOS code?

**Change Required**: {Description of what cli-bridge needs to do, or "None - iOS-only fix"}

**API Impact**:
- Endpoint: `{method} {path}`
- Change: {Add field / New endpoint / Modify behavior}

**GitHub Issue**: {link if created, or "Not needed - small change" or "N/A"}

**Status**: Pending cli-bridge | cli-bridge Complete | N/A

---

## Notes

{Any additional context, gotchas, or references.}

---

## Assessment (from ROADMAP.md)

| Impact | Simplification | iOS Best Practices |
|--------|----------------|-------------------|
| {stars} | {stars} | {stars} |

**Rationale:**
- {Key point from ROADMAP assessment}
- {Key point from ROADMAP assessment}

---

## Completion Log

| Date | Action | Outcome |
|------|--------|---------|
| {YYYY-MM-DD} | Started implementation | {Notes} |
| {YYYY-MM-DD} | Completed | {Verification results} |

---

_Template version: 1.1 | Last updated: January 2, 2026_
