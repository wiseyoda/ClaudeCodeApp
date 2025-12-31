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

### #24: Investigate New Token Calculation in cli-bridge
- **What happened**: Token counts displayed in the app may not reflect actual usage accurately
- **Expected**: Token usage should match what Claude Code CLI reports
- **Investigation needed**:
  - Check what token fields cli-bridge API returns in SSE events
  - Compare with Claude Code CLI token reporting
  - Determine if iOS app is parsing/displaying tokens correctly
  - Consider adding token breakdown (input/output/cache) if available
- **Location**: `CLIBridgeAdapter.swift`, token display UI
- **Priority**: Medium - affects user's ability to monitor usage

### #35: Git Refresh Error on Pull-to-Refresh
- **What happened**: Pull-to-refresh on home screen shows git status errors
- **Expected**: Git status should refresh cleanly or fail gracefully
- **Investigation needed**:
  - Check if API endpoint is returning errors
  - Verify error handling in refresh flow
- **Location**: `HomeView.swift`, `ContentView.swift`
- **Priority**: Medium - affects UX

---

## Feature Requests

### #22: Exit Plan Mode approval UI (Medium Priority)
- **What**: Implement plan mode exit approval flow matching Claude Code CLI behavior
- **Context**: Claude Code CLI shows approval options when exiting plan mode:
  1. "Yes, and bypass permissions" - proceed without further approval
  2. "Yes, and manually approve edits" - require approval for each change
  3. "Type here to tell Claude what to change" - provide feedback on the plan
- **Dependencies**: Permission Approval Banner now complete
- **Implementation notes**:
  - Detect when Claude sends `ExitPlanMode` tool call
  - Show approval sheet with similar options to CLI
  - Pass selected mode back to backend for execution
  - May need backend support for plan mode state tracking
  - Foundation in place: `ApprovalBannerView`, `ApprovalRequest/Response` models
- **Location**: `ChatView.swift`, `CLIBridgeAdapter.swift`
- **Reference**: Screenshot shows CLI approval interface

### #18: Multi-repo/monorepo git status support (Low Priority)
- **What**: Show aggregate git status across subrepos/workspaces
- **Scope**: Affects projects with monorepo/multi-workspace structure
- **Considerations**:
  - Detect monorepo structure (pnpm workspaces, yarn workspaces, git submodules)
  - Run git status in each subrepo directory
  - Aggregate results for display (e.g., "3/5 repos have changes")

### #36: [cli-bridge] Batch session counts API (Medium Priority)
- **What**: Request batch endpoint to fetch session counts for multiple projects at once
- **Why**: Currently requires N API calls for N projects, each taking 300-400ms
- **Impact**: Significant latency on HomeView load with many projects
- **Proposed Endpoint**:
  ```
  POST /projects/sessions/counts
  Body: { "paths": ["/path/to/project1", "/path/to/project2", ...] }
  Response: { "counts": { "/path/to/project1": 5, "/path/to/project2": 3, ... } }
  ```
- **Workaround**: App currently caches session counts in `ProjectCache.swift`
- **Location**: cli-bridge backend (not iOS app)
- **Status**: Feature request - awaiting cli-bridge team feedback

---

## Resolved Issues

See [CHANGELOG.md](CHANGELOG.md) for details on resolved issues.

| # | Issue | Version |
|---|-------|---------|
| 32 | ClaudeHelper AI Suggestions (feature removed - ClaudeHelper.swift deleted) | 0.6.4 |
| 29 | BGTaskScheduler simulator error (works on device, simulator limitation) | 0.6.1 |
| 28 | xcodebuild test bundle issue (run tests separately as workaround) | 0.6.1 |
| 25 | Voice transcription text contrast (fixed text color) | 0.6.1 |
| 21 | High git error rate (not a bug - Claude recovers correctly) | 0.6.1 |
| 20 | SSH timeout errors (SSH removed from iOS app) | 0.6.1 |
| 34 | Context menu missing from HomeView ProjectCards | 0.6.1 |
| 33 | Session Manager not showing all sessions (blocking) | 0.6.1 |
| 31 | PermissionMode dropdown missing from QuickSettingsSheet | 0.6.1 |
| 30 | Session Manager showing only 1 session | 0.6.1 |
| -- | cli-bridge migration (WebSocket -> REST API + SSE) | 0.6.0 |
| 24 | "Always Allow" permission not working | 0.5.0 |
| 19 | Bulk session management | 0.5.0 |
| 17 | Timeout errors not in debug logs | 0.5.0 |
| 16 | Phantom "New Session" entries (workaround) | 0.5.0 |
| 23 | "Request not found" permission errors (cosmetic) | 0.5.0 |
| 27 | Session API integration tests blocked | 0.5.0 |
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
