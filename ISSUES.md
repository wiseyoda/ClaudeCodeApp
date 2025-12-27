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

### #17: Timeout errors not appearing in debug logs (Fixed December 27, 2025)
- **What happened**: "Request timed out" errors shown to user but not captured in debug log viewer
- **Expected**: All errors should appear in debug logs for troubleshooting
- **Fix applied**: Added `debugLog.logError()` calls to timeout handling and error cases in `WebSocketManager.swift`. Also added `lastActiveToolName` tracking to show which tool was running when timeout occurred.

### Feature Requests

*No open feature requests at this time.*

---

## Resolved Issues

Issues that have been fixed are listed below. See CHANGELOG.md for full details.

### #7: Verbose output log for debugging (Fixed December 27, 2025)
- **Resolution**: Added `DebugLogStore` and `DebugLogView` for viewing raw WebSocket messages. Developer section in QuickSettingsSheet with toggle and log viewer access.

### #13: Git refresh error alert on app launch (Fixed December 27, 2025)
- **Resolution**: Modified `SSHManager.checkGitStatusWithAutoConnect()` to silently return `.unknown` for SSH connection failures instead of showing an error alert.

### #14: Claude status indicator stuck red (Fixed December 27, 2025)
- **Resolution**: Updated `UnifiedStatusBar` to accept full `ConnectionState`. Added yellow color and pulsing animation for connecting/reconnecting states.

### #15: Per-project permissions toggle (Fixed December 27, 2025)
- **Resolution**: Added `ProjectSettingsStore` for per-project settings. Status bar bypass indicator is now tappable to toggle per-project override (cycles through: use global -> force on -> force off -> use global).

### #4: Message action bar at bottom of messages (Fixed in v0.4.0)
- **Resolution**: Added `MessageActionBar.swift` with execution time, token count, copy, and analyze buttons

### #8: Restore quick-access mode and thinking toggles (Fixed in v0.4.0)
- **Resolution**: Restored mode and thinking chips to status bar for faster access

### #11: Auto-refresh git status in active project (Fixed in v0.4.0)
- **Resolution**: Added 30-second periodic refresh plus auto-refresh after task completion

### #12: Quick commit & push button in pending changes banner (Fixed in v0.4.0)
- **Resolution**: Added button in pending changes banner to commit and push via Claude

### #1: App crashes periodically during use (Fixed in v1.3.0)
- **Root cause**: Thread safety issues in WebSocketManager - race conditions and message queue overwrites
- **Fix**: Added `@MainActor` to managers, replaced single `pendingMessage` with queue, fixed WebSocket state race

### #2: Session resume doesn't restore in-progress tasks (Fixed in v1.3.0)
- **Root cause**: No auto-select of last session, sendMessage used wrong session ID
- **Fix**: Use `wsManager.sessionId` fallback in sendMessage when selectedSession is nil

### #3: Redundant thinking/status indicators (Fixed in v1.3.0)
- **Root cause**: CLIProcessingView in chat duplicated status bar indicator
- **Fix**: Replaced redundant CLIProcessingView with minimal indicator; status bar is primary

### #5: Git refresh fails silently on projects list (Fixed in v1.3.0)
- **Root cause**: No error UI when git status checks failed
- **Fix**: Added git refresh error alert in ContentView

### #6: TodoWrite tool output not parsed correctly (Fixed in v1.3.0)
- **Root cause**: Parser didn't handle spacing variations and escape sequences
- **Fix**: Improved TodoWrite parser to handle edge cases

### #9: Chat scroll position jumps on rotation (Fixed in v1.3.0)
- **Root cause**: ScrollViewReader reset on orientation change
- **Fix**: Preserve scroll position via orientation change listener

### #10: Token usage calculation may be inaccurate (Verified in v1.3.0)
- **Investigation result**: Token usage comes from backend, not hardcoded
- **Status**: Verified working correctly
