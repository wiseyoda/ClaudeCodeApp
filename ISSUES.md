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

### Feature Requests

#### #4: Message action bar at bottom of messages
- **Type**: Feature request
- **Priority**: Medium
- **Current behavior**: Copy button is at the top of the message
- **Requested behavior**: Add an action bar at the bottom of each message with:
  - Copy all button (moved from top)
  - Execution time for the task
  - Token usage for that task
  - "Analyze" button - uses Haiku to generate a follow-up prompt with output context
- **Related files**: Message view components in `Views/`

#### #7: Verbose output log for debugging
- **Type**: Feature request
- **Priority**: Medium
- **What**: Access to raw/verbose session logs for debugging issues
- **Details**:
  - Server likely has raw output vs parsed output
  - Would help debug parsing issues and other problems
  - Could be a developer/debug mode toggle or separate log viewer
- **Related files**: `WebSocketManager.swift`, backend API

#### #8: Restore quick-access mode and thinking toggles
- **Type**: Feature request / UX regression
- **Priority**: Low
- **What happened**: New UI hides mode and thinking settings under status bar settings menu
- **Problem**: Adds extra click, harder to quickly cycle through options
- **Requested changes**:
  - Bring back chips in status bar for mode (normal/plan/bypass permissions)
  - Bring back chips for thinking level toggle
  - Add "dangerously bypass permissions" option in settings (Claude CLI feature)
- **Note**: Need to research how bypass permissions is implemented in Claude CLI
- **Related files**: Status bar view, `AppSettings.swift`

#### #11: Auto-refresh git status in active project
- **Type**: Feature request
- **Priority**: Low
- **Current behavior**: Git status only updates manually or when reloading the project
- **Requested behavior**: Automatically refresh git status:
  - Periodically on a time interval while in a project
  - After task completion (when Claude makes changes)
- **Related files**: Git sync components, `SSHManager.swift`, `ChatView.swift`

#### #12: Quick commit & push button in pending changes banner
- **Type**: Feature request
- **Priority**: Low
- **Context**: Git banner already shows when there are pending changes
- **Requested behavior**: Add a button that sends a command to Claude to commit and push all changes
- **Similar to**: The existing "Pull" button in the pull request banner
- **Related files**: Git sync banner components, `ChatView.swift`, `WebSocketManager.swift`

---

## Resolved Issues

Issues that have been fixed are listed below. See CHANGELOG.md for full details.

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
