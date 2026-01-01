---
allowed-tools: Bash(*), Read, Edit, Write, Task, TaskOutput, Glob, Grep
description: Bump app version [major|minor|patch] with full release workflow
---

# Version Bump Command

**Argument required:** `major`, `minor`, or `patch`

## Context

Current version configuration:

```
!`cat Config/Version.xcconfig`
```

Current git status:

```
!`git status --short`
```

Recent git history since last tag:

```
!`git log --oneline $(git describe --tags --abbrev=0 2>/dev/null || echo HEAD~20)..HEAD 2>/dev/null || git log --oneline -20`
```

Current branch:

```
!`git branch --show-current`
```

## Your Task

Execute the following release workflow based on the bump type argument ("$ARGUMENTS"):

### Step 1: Validate Arguments and State

1. Parse the bump type from "$ARGUMENTS" - must be exactly one of: `major`, `minor`, `patch`
2. If no valid argument provided, show usage and exit: `/bump [major|minor|patch]`
3. Check current branch:
   - If on a feature branch with uncommitted changes, commit them first
   - If on a feature branch, merge to main before proceeding
   - If on main with uncommitted changes, commit them as part of the release
4. Ensure you're on main branch before proceeding with version bump

### Step 2: Calculate New Version

Read `Config/Version.xcconfig` to get current `MARKETING_VERSION` (e.g., "0.6.6").

Parse as `major.minor.patch` and calculate new version:
- `major`: X.0.0 (reset minor and patch)
- `minor`: X.Y.0 (reset patch)
- `patch`: X.Y.Z

Also reset `CURRENT_PROJECT_VERSION` to 1 for any version bump.

### Step 3: Gather Changes for Changelog

1. Get all commits since last release tag: `git log --oneline <last-tag>..HEAD`
2. Get all closed PRs since last release using: `gh pr list --state merged --json number,title,mergedAt --limit 50`
3. Categorize changes into:
   - **Added**: New features, capabilities
   - **Changed**: Modifications to existing functionality
   - **Fixed**: Bug fixes
   - **Removed**: Removed features

### Step 4: Update CHANGELOG.md

1. Read current CHANGELOG.md
2. Create new version section at the top (after the header) with today's date
3. Add categorized changes under appropriate headings
4. Ensure proper formatting following Keep a Changelog format

### Step 5: Update Version.xcconfig

Edit `Config/Version.xcconfig`:
- Update `MARKETING_VERSION` to the new version
- Reset `CURRENT_PROJECT_VERSION` to 1

### Step 6: Run Project Docs Reconciler

Use the Task tool to launch the `project-docs-reconciler` agent:
- Wait for it to complete
- This will synchronize ROADMAP.md, ISSUES.md, and CHANGELOG.md

### Step 7: Run All Checks and Tests

Execute the following checks in sequence:

```bash
# Shutdown simulators to avoid parallel testing issues
xcrun simctl shutdown all

# Build
xcodebuild -project CodingBridge.xcodeproj -scheme CodingBridge -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' -quiet

# Tests (skip network-dependent integration tests that require running backend)
xcodebuild test -project CodingBridge.xcodeproj -scheme CodingBridge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' \
  -parallel-testing-enabled NO \
  -skip-testing:CodingBridgeTests/CLIBridgeAPIClientTests \
  -skip-testing:CodingBridgeTests/CLIBridgeAdapterTests \
  -skip-testing:CodingBridgeTests/HealthMonitorServiceTests \
  -skip-testing:CodingBridgeTests/PushNotificationManagerTests
```

**Note:** The skipped tests are integration tests that require a running cli-bridge backend server. They test actual network communication and will fail without the backend. Unit tests cover the same code paths with mocked responses.

If any check fails:
1. Analyze the error
2. Fix the issue
3. Re-run the failing check
4. Repeat until all checks pass

### Step 8: Create Release Commit and Push

1. Stage all changes: `git add -A`
2. Create commit with message:
   ```
   chore: bump version to X.Y.Z

   Release X.Y.Z includes:
   - [Summary of key changes]

   Generated with [Claude Code](https://claude.com/claude-code)

   Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
   ```
3. Create git tag: `git tag -a vX.Y.Z -m "Release X.Y.Z"`
4. Push to origin/main: `git push origin main --tags`

### Step 9: Summary

Print a summary of what was done:
- Old version -> New version
- Number of changes included
- Files modified
- Commit hash
- Tag created

## Important Notes

- If on a feature branch, commit any uncommitted changes and merge to main first
- If on main with uncommitted changes, commit them as part of the release
- Always verify the changelog accurately reflects the changes
- If any step fails, stop and report the issue - do not continue with partial release
- The version bump only modifies `Config/Version.xcconfig` - all other version references use $(inherited)
- Integration tests (CLIBridgeAPIClientTests, etc.) are skipped as they require a running backend
