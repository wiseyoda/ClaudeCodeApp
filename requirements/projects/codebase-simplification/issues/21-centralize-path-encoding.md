# Issue #21: Centralize Project Path Encode/Decode

> **Status**: Complete (verified 2026-01-02)
> **Priority**: Tier 1
> **Depends On**: #1 (Complete)
> **Blocks**: #22, #26

---

## Summary

Create a single authoritative `ProjectPathEncoder` utility to handle project path encoding/decoding, eliminating duplicate implementations and documenting the hyphen ambiguity limitation.

## Problem

Project path encoding (e.g., `/home/dev/project` -> `-home-dev-project`) is duplicated in 4+ locations:

1. `CLIBridgeAPIClient.encodeProjectPath()` - private method
2. `SessionStore.encodeProjectPath()` - private method
3. `ProjectSettingsStore.encodeProjectPath()` - private method
4. `IdeasStore` - inline in `fileURL(for:)`
5. `SessionRepository.projectPath(from:)` - decode only, lossy
6. `Models.swift` (MessageStore) - uses `_` instead of `-` (different encoding!)

**Pain points:**
- No centralized decode function (only SessionRepository has one, and it's lossy)
- MessageStore uses different encoding (`_` instead of `-`) creating inconsistency
- Hyphen ambiguity is undocumented: `/home/my-project` encodes the same as `/home/my/project`
- Tests duplicate the encoding logic inline

## Solution

1. Create a single `ProjectPathEncoder` enum with static methods
2. Consolidate all encoding calls to use the new utility
3. Document the hyphen ambiguity limitation prominently
4. Standardize MessageStore to use `-` encoding (migration required)
5. Add tests for edge cases including hyphen-containing paths

**Note:** The hyphen ambiguity is inherent in the Claude CLI's directory naming scheme. We cannot fix it without breaking compatibility. We document it and ensure consistent handling.

---

## Scope

### In Scope

- Create `CodingBridge/Utilities/ProjectPathEncoder.swift`
- Update `CLIBridgeAPIClient.swift` to use shared encoder
- Update `SessionStore.swift` to use shared encoder
- Update `ProjectSettingsStore.swift` to use shared encoder
- Update `IdeasStore.swift` to use shared encoder
- Update `SessionRepository.swift` to use shared decoder
- Migrate `MessageStore` from `_` to `-` encoding (with migration code)
- Add comprehensive tests for path encoding edge cases

### Out of Scope

- Changing the encoding scheme (would break cli-bridge compatibility)
- Fixing hyphen ambiguity (would break Claude CLI compatibility)
- Refactoring MessageStore persistence layer (#5)
- Changes to cli-bridge backend

---

## Implementation

### Files to Create

| File | Purpose |
|------|---------|
| `CodingBridge/Utilities/ProjectPathEncoder.swift` | Single source of truth for path encoding/decoding |
| `CodingBridgeTests/ProjectPathEncoderTests.swift` | Test edge cases including hyphens |

### Files to Modify

| File | Change |
|------|--------|
| `CodingBridge/CLIBridgeAPIClient.swift` | Remove private `encodeProjectPath`, use `ProjectPathEncoder` |
| `CodingBridge/SessionStore.swift` | Remove private `encodeProjectPath`, use `ProjectPathEncoder` |
| `CodingBridge/ProjectSettingsStore.swift` | Remove private `encodeProjectPath`, use `ProjectPathEncoder` |
| `CodingBridge/IdeasStore.swift` | Use `ProjectPathEncoder` instead of inline encoding |
| `CodingBridge/SessionRepository.swift` | Use `ProjectPathEncoder.decode()` instead of private method |
| `CodingBridge/Models.swift` | Migrate MessageStore to `-` encoding with backward-compatible migration |

### Steps

1. **Create ProjectPathEncoder utility**
   - Create `CodingBridge/Utilities/ProjectPathEncoder.swift`
   - Add `encode(_:)` and `decode(_:)` static methods
   - Add documentation explaining hyphen ambiguity limitation
   - Add link to xcode-linker for pbxproj registration

2. **Update CLIBridgeAPIClient**
   - Remove private `encodeProjectPath(_:)` method
   - Import and use `ProjectPathEncoder.encode(_:)`

3. **Update SessionStore**
   - Remove private `encodeProjectPath(_:)` method
   - Import and use `ProjectPathEncoder.encode(_:)`

4. **Update ProjectSettingsStore**
   - Remove private `encodeProjectPath(_:)` method
   - Import and use `ProjectPathEncoder.encode(_:)`

5. **Update IdeasStore**
   - Replace inline encoding in `fileURL(for:)` with `ProjectPathEncoder.encode(_:)`

6. **Update SessionRepository**
   - Remove private `projectPath(from:)` method
   - Use `ProjectPathEncoder.decode(_:)` instead

7. **Migrate MessageStore encoding**
   - Change `_` to `-` in `projectDirectory(for:)`
   - Add migration code to find and move existing `_` directories to `-`
   - Test migration with existing data

8. **Add tests**
   - Create `CodingBridgeTests/ProjectPathEncoderTests.swift`
   - Test basic encoding/decoding
   - Test hyphen-containing paths (document as known limitation)
   - Test empty path, root path edge cases

9. **Verify**
   - Build passes: `xcodebuild -project CodingBridge.xcodeproj -scheme CodingBridge -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'`
   - All tests pass: `xcodebuild test ...`
   - No new warnings

---

## Acceptance Criteria

- [x] Single `ProjectPathEncoder` utility exists with documented encode/decode methods
- [x] Hyphen ambiguity is documented in the utility's header comments
- [x] All 4 duplicate `encodeProjectPath` implementations are removed
- [x] `SessionRepository.projectPath(from:)` is removed
- [x] MessageStore uses `-` encoding with migration support
- [x] New tests cover edge cases including hyphen-containing paths
- [x] Build passes with no new warnings
- [x] No user-visible behavior changes

---

## Verification Commands

```bash
# Build verification
xcodebuild -project CodingBridge.xcodeproj -scheme CodingBridge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'

# Run all tests
xcodebuild test -project CodingBridge.xcodeproj -scheme CodingBridge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'

# Verify no duplicate encodeProjectPath implementations remain
grep -r "private.*func encodeProjectPath" CodingBridge/ --include="*.swift"
# Should return no results

# Verify ProjectPathEncoder is used
grep -r "ProjectPathEncoder" CodingBridge/ --include="*.swift"
# Should show usage in all modified files
```

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| MessageStore migration loses data | Test migration with real data; keep `_` directories readable as fallback |
| Encoding change breaks session lookup | Use same `-` encoding as API; validate against cli-bridge |
| Tests depend on old encoding | Update test fixtures to use new encoding |

---

## Notes

**Hyphen Ambiguity (Known Limitation):**

The encoding scheme used by Claude CLI creates ambiguity for paths containing hyphens:

```
/home/my-project   -> -home-my-project
/home/my/project   -> -home-my-project  (same!)
```

Decoding is therefore lossy - we cannot distinguish the original. This is documented but not fixable without breaking compatibility with Claude CLI's `.claude/projects/` directory structure.

**MessageStore Encoding Difference:**

Currently MessageStore uses `_` instead of `-`:
- `/home/dev/project` -> `_home_dev_project` (current)
- `/home/dev/project` -> `-home-dev-project` (target)

This will be migrated for consistency with the API and other stores.

---

## Assessment (from ROADMAP.md)

| Impact | Simplification | iOS Best Practices |
|--------|----------------|-------------------|
| High | High | High |

**Rationale:**
- Eliminates 4+ duplicate implementations
- Documents known limitation prominently
- Standardizes encoding across all stores
- Single point of maintenance for future changes

---

## Completion Log

| Date | Action | Outcome |
|------|--------|---------|
| 2026-01-02 | Started implementation | Audit complete, issue file created |
| 2026-01-02 | Completed | All criteria verified, build passes, 18 new tests |
| 2026-01-02 | Verified | Removed remaining helper wrappers and aligned docs |

---

_Issue created: January 2, 2026_
