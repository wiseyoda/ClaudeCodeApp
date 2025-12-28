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

### #23: "Request not found" permission errors (Informational)
- **What happened**: Backend sends `permission-error: "Request not found in your pending queue"` even when iOS successfully sends approval response
- **Expected**: No error when approval is successfully processed
- **Root cause**: Backend has two parallel permission systems:
  1. Legacy system (`handlePermissionResponse()` + `pendingPermissions` Map) - handles actual permission
  2. New system (`permissionWebSocketHandler`) - sends error if request not in its queue
- **Note**: This is a backend architecture issue. The permission IS being handled correctly by the legacy system - the error is cosmetic from the new system
- **Impact**: None functional - commands execute correctly. Error message in logs can be ignored.
- **Location**: `server/index.js` in claudecodeui backend
- **Source**: Session analysis 2025-12-28

### #24: Token Usage Calculation Wildly Inaccurate (To Investigate)
- **What happened**: Token counts displayed in the app are significantly wrong compared to actual usage
- **Expected**: Token usage should reflect actual consumption accurately
- **Location**: Token display UI, API response parsing
- **Investigation needed**:
  - Audit what the backend/API is actually sending for token counts
  - Compare API-reported tokens vs actual message content size
  - Determine if issue is API-side or client-side parsing
  - Consider client-side token estimation as fallback/validation
  - Check if streaming messages have different token reporting than complete messages
- **Priority**: Medium - affects user's ability to monitor usage

### #25: Voice Transcription Bar Text Unreadable in Dark Mode
- **What happened**: Gray text on red background during voice-to-text makes transcription text very hard to read, especially in dark mode
- **Expected**: Text should have sufficient contrast against the red recording indicator background
- **Location**: Voice transcription status bar UI (likely `SpeechManager` related views)
- **Fix needed**:
  - Change text color to white or light color when on red background
  - Ensure WCAG AA contrast ratio (4.5:1 minimum) for accessibility
- **Priority**: Medium - affects usability of voice input feature

---

## Feature Requests

### #22: Exit Plan Mode approval UI (Medium Priority)
- **What**: Implement plan mode exit approval flow matching Claude Code CLI behavior
- **Context**: Claude Code CLI shows approval options when exiting plan mode:
  1. "Yes, and bypass permissions" - proceed without further approval
  2. "Yes, and manually approve edits" - require approval for each change
  3. "Type here to tell Claude what to change" - provide feedback on the plan
- **Dependencies**: ✅ Non-bypass mode approval functionality now complete (Permission Approval Banner)
- **Implementation notes**:
  - Detect when Claude sends `ExitPlanMode` tool call
  - Show approval sheet with similar options to CLI
  - Pass selected mode back to backend for execution
  - May need backend support for plan mode state tracking
  - Foundation in place: `ApprovalBannerView`, `ApprovalRequest/Response` models, WebSocket handling
- **Location**: `ChatView.swift`, `WebSocketManager.swift`
- **Reference**: Screenshot shows CLI approval interface

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
| 24 | "Always Allow" permission not working | Unreleased |
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
