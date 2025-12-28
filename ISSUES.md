# Issues

User-reported bugs and feature requests to be addressed.

## How to Report

When reporting a bug, include:
- **What happened**: Brief description of the issue
- **Expected**: What should have happened
- **Steps to reproduce**: If known
- **Location**: File/view where it occurred (if applicable)

---

## Open Issues

### #16: Phantom "New Session" entries (Investigating)
- **What happened**: Empty sessions with summary "New Session" appear in session picker without user sending any message
- **Expected**: Sessions should only be created when user sends first message
- **Location**: Backend/Claude Agent SDK
- **Investigation**: Root cause appears to be Claude Agent SDK warmup mechanism, not iOS app
- **Workaround**: Filter out sessions with `summary == "New Session"` in SessionPickerViews.swift

### #20: SSH Timeout Errors (To Investigate)
- **What happened**: Session analysis found 12 occurrences of exit code 254 (SSH timeout/connection issues)
- **Expected**: SSH commands should complete or fail gracefully with clear error messaging
- **Location**: `SSHManager.swift`
- **Investigation needed**:
  - Identify which commands trigger timeouts most frequently
  - Check if Citadel SSH library has configurable timeout settings
  - Consider retry logic for transient connection failures
- **Source**: Session analysis 2025-12-28

### #21: High Git Error Rate (Informational)
- **What happened**: Session analysis found 62 exit code 128 errors (git not a repository)
- **Expected**: N/A - Claude recovers by using `-C /path` flag
- **Location**: Backend/Claude Code behavior
- **Note**: Not a bug - documenting that Claude's git error recovery is working as expected
- **Source**: Session analysis 2025-12-28

---

## Feature Requests

### #18: Multi-repo/monorepo git status support (Low Priority)
- **What**: Show aggregate git status across subrepos/workspaces
- **Scope**: Affects projects with monorepo/multi-workspace structure
- **Considerations**:
  - Detect monorepo structure (pnpm workspaces, yarn workspaces, git submodules)
  - Run git status in each subrepo directory
  - Aggregate results for display (e.g., "3/5 repos have changes")

---

## Resolved Issues

See [CHANGELOG.md](CHANGELOG.md) for details on resolved issues.

| # | Issue | Version |
|---|-------|---------|
| 19 | Bulk session management | Unreleased |
| 17 | Timeout errors not in debug logs | Unreleased |
| 15 | Per-project permissions toggle | 0.4.0 |
| 14 | Status indicator stuck red | 0.4.0 |
| 13 | Git refresh error on launch | 0.4.0 |
| 12 | Quick commit & push button | 0.4.0 |
| 11 | Auto-refresh git status | 0.4.0 |
| 8 | Restore mode/thinking toggles | 0.4.0 |
| 7 | Verbose output log | 0.4.0 |
| 4 | Message action bar | 0.4.0 |
| 10 | Token usage calculation | 0.3.3 |
| 9 | Chat scroll on rotation | 0.3.3 |
| 6 | TodoWrite parsing | 0.3.3 |
| 5 | Git refresh fails silently | 0.3.3 |
| 3 | Redundant indicators | 0.3.3 |
| 2 | Session resume broken | 0.3.3 |
| 1 | App crashes periodically | 0.3.3 |
