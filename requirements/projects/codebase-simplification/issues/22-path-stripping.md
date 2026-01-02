# Issue #22: Replace hard-coded path stripping in Project.title

> **Status**: Complete (verified 2026-01-02)
> **Priority**: Tier 2
> **Depends On**: #21 (Centralize project path encode/decode)
> **Blocks**: None

---

## Summary

Remove hard-coded path prefix stripping from `Project.title` and use the `name` field directly since it already contains the basename.

## Problem

The `Project.title` computed property has a hard-coded string replacement:
```swift
return name.replacingOccurrences(of: "-home-dev-workspace-", with: "")
```

This is:
1. **Brittle** - Only works for projects in `/home/dev/workspace/`
2. **Unnecessary** - The `name` field from cli-bridge is already the directory basename
3. **Confusing** - Hard-coded paths suggest the code handles encoded paths but it doesn't

## Solution

Since the API's `name` field is already the directory basename (e.g., "ClaudeCodeApp", "cli-bridge"), simply return `name` directly when `displayName` is not set. No path manipulation needed.

---

## Scope

### In Scope

- Remove the hard-coded path stripping from `Project.title` in `Models.swift`
- Return `name` directly as the fallback (it's already the basename)

### Out of Scope

- Changing how `name` or `path` are populated from the API
- Modifying `ProjectPathEncoder` (that's for encoded paths, not display names)
- Adding a server-side `displayName` field (nice to have, but not needed for this fix)

---

## Implementation

### Files to Modify

| File | Change |
|------|--------|
| `CodingBridge/Models.swift` | Simplify `Project.title` to return `name` directly |

### Files to Delete

None.

### Steps

1. **Simplify Project.title**
   - Remove the `replacingOccurrences(of: "-home-dev-workspace-", with: "")` call
   - Return `name` directly when `displayName` is not set
   - Update the comment to reflect the actual behavior

2. **Verify**
   - Build passes: `xcodebuild -project CodingBridge.xcodeproj -scheme CodingBridge -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'`
   - No new warnings
   - Project names display correctly in the UI

---

## Acceptance Criteria

- [x] `Project.title` returns `name` directly (no path manipulation)
- [x] Hard-coded `-home-dev-workspace-` string is removed
- [x] Build passes with no new warnings
- [x] No user-visible behavior changes (project names still display correctly)

---

## Verification Commands

```bash
# Build verification
xcodebuild -project CodingBridge.xcodeproj -scheme CodingBridge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build

# Verify hard-coded string is gone
grep -r "home-dev-workspace" CodingBridge/
# Expected: no matches

# Check Project.title implementation
grep -A5 "var title: String" CodingBridge/Models.swift
# Expected: returns name directly, no replacingOccurrences
```

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Projects might have `name` as encoded path | Verified: API returns basename, not encoded path |
| Some edge case where name differs from expected | displayName fallback still works as primary |

---

## Notes

The API response from cli-bridge confirms `name` is the directory basename:
```json
{"path":"/Users/ppatterson/dev/ClaudeCodeApp","name":"ClaudeCodeApp",...}
```

The hard-coded string `-home-dev-workspace-` was likely a legacy workaround from before the API provided proper basenames.

---

## Assessment (from ROADMAP.md)

| Impact | Simplification | iOS Best Practices |
|--------|----------------|-------------------|
| Low | Medium | Low |

**Rationale:**
- Removes brittle hard-coded path assumption
- Simplifies code by trusting API to provide correct data
- Low risk since displayName fallback is unchanged

---

## Completion Log

| Date | Action | Outcome |
|------|--------|---------|
| 2026-01-02 | Started implementation | Verified API returns basename in name field |
| 2026-01-02 | Completed | Removed hard-coded path stripping, build passes |
| 2026-01-02 | Verified | Tests updated for basename-only name field |

---

_Template version: 1.1 | Last updated: January 2, 2026_
