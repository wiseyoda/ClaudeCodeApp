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

### #16: Phantom "New Session" entries created on app open (Investigating)
- **What happened**: Empty sessions with summary "New Session" appear in session picker without user sending any message
- **Expected**: Sessions should only be created when user sends first message
- **Location**: Backend/Claude Agent SDK
- **Investigation findings**:
  - iOS app `startNewSession()` correctly only clears local state (doesn't create backend session)
  - Session files contain only `queue-operation: dequeue` entry with no user message
  - Associated `agent-*.jsonl` files have "Warmup" messages from Claude Agent SDK
  - Agent timestamps precede main session entry, suggesting SDK internal initialization
  - Root cause appears to be in Claude Agent SDK warmup mechanism, not iOS app
- **Workaround applied**: Filter out sessions with `summary == "New Session"` in `SessionPickerViews.swift`
- **Status**: Monitoring - workaround in place, will investigate further if issues persist

---

## Feature Requests

### #18: Multi-repo/monorepo git status support (Low Priority)
- **What**: Apps like `level-agency-tools` have multiple subrepos/workspaces. Currently git status only checks the main repo.
- **Expected**: Show aggregate git status across all subrepos, or at least indicate when subrepos have uncommitted changes
- **Scope**: Low impact - only affects projects with monorepo/multi-workspace structure
- **Considerations**:
  - Detect monorepo structure (pnpm workspaces, yarn workspaces, git submodules)
  - Run git status in each subrepo directory
  - Aggregate results for display (e.g., "3/5 repos have changes")
  - May need UI changes to show per-repo breakdown

### #19: Bulk session history management ✅ RESOLVED
- **What**: Ability to manage session history in bulk - delete all, delete by age, keep only recent N sessions
- **Resolution**: Implemented "Manage" button in SessionPickerSheet with three operations:
  - Delete all sessions (protects active session)
  - Delete sessions older than 7/30/90 days
  - Keep last 5/10/20 sessions
- **Implementation**:
  - SessionManager bulk delete methods with batch SSH deletion
  - Confirmation dialogs showing count before deletion
  - Progress indicator during bulk operations
- **Status**: Completed December 27, 2025

---

## Resolved Issues

Issues that have been fixed. See CHANGELOG.md for full details.

| # | Issue | Resolution | Version |
|---|-------|------------|---------|
| 19 | Bulk session management | Added "Manage" button with delete all/by age/keep N options | Unreleased |
| 17 | Timeout errors not in debug logs | Added `debugLog.logError()` calls and `lastActiveToolName` tracking | Unreleased |
| 15 | Per-project permissions toggle | Added `ProjectSettingsStore` with tappable status bar toggle | 0.4.0 |
| 14 | Status indicator stuck red | Updated `UnifiedStatusBar` with full `ConnectionState` and colors | 0.4.0 |
| 13 | Git refresh error on launch | Modified `checkGitStatusWithAutoConnect()` to silently return `.unknown` | 0.4.0 |
| 12 | Quick commit & push button | Added button in pending changes banner | 0.4.0 |
| 11 | Auto-refresh git status | Added 30-second periodic refresh plus post-task auto-refresh | 0.4.0 |
| 8 | Restore mode/thinking toggles | Restored chips to status bar | 0.4.0 |
| 7 | Verbose output log | Added `DebugLogStore` and `DebugLogView` | 0.4.0 |
| 4 | Message action bar | Added `MessageActionBar.swift` with execution time, tokens, copy, analyze | 0.4.0 |
| 10 | Token usage calculation | Verified working correctly - comes from backend | 0.3.3 |
| 9 | Chat scroll on rotation | Preserve scroll position via orientation listener | 0.3.3 |
| 6 | TodoWrite parsing | Improved parser for spacing and escape sequences | 0.3.3 |
| 5 | Git refresh fails silently | Added git refresh error alert in ContentView | 0.3.3 |
| 3 | Redundant indicators | Replaced redundant CLIProcessingView with minimal indicator | 0.3.3 |
| 2 | Session resume broken | Use `wsManager.sessionId` fallback in sendMessage | 0.3.3 |
| 1 | App crashes periodically | Added `@MainActor` to managers, fixed race conditions | 0.3.3 |
