# Issues

User-reported bugs and issues to be addressed during bug squashing sessions.

## How to Report

When reporting a bug, include:
- **What happened**: Brief description of the issue
- **Expected**: What should have happened
- **Steps to reproduce**: If known
- **Location**: File/view where it occurred (if applicable)

---

## Open Issues

### 1. App crashes periodically during use
- **Platform**: iPhone, iOS 26.2
- **What happened**: App crashes and requires hard close/reopen
- **When it occurs**:
  - While typing a command
  - During task execution
- **Possible causes**: Memory pressure, threading issues, or WebSocket state race conditions (see `ROADMAP.md` Priority 1)
- **Related files**: `WebSocketManager.swift`, `ChatView.swift`

### 2. Session resume doesn't restore in-progress tasks
- **What happened**: After app crash/restart, opening a project defaults to a new session instead of the last active one
- **Current behavior**:
  - Clicking on the in-progress session shows history but no live streaming
  - Must repeatedly click session to get updates until task finishes
- **Expected behavior**:
  - Opening a project should auto-select the last used session
  - If a task is in progress, should reconnect and show live streaming
- **Related files**: `ChatView.swift`, `WebSocketManager.swift`, `SessionNamesStore`

### 3. Redundant thinking/status indicators
- **What happened**: During task execution, two separate thinking indicators are shown
- **Current behavior**:
  - "Thinking" indicator appears in the chat window
  - Rotating status text (thinking/analyzing/etc) appears in the status bar
- **Suggestion**: Consolidate into a single, cleaner indicator
- **Related files**: `ChatView.swift`, status bar view

### 4. [Feature] Message action bar at bottom of messages
- **Type**: Feature request
- **Current behavior**: Copy button is at the top of the message
- **Requested behavior**: Add an action bar at the bottom of each message with:
  - Copy all button (moved from top)
  - Execution time for the task
  - Token usage for that task
  - "Analyze" button - uses Haiku to generate a follow-up prompt with output context
- **Related files**: Message view components in `Views/`

### 5. Git refresh fails silently on projects list
- **Platform**: iPhone, iOS 26.2
- **What happened**: GitHub refresh on projects screen failed with no error message - all icons turned red
- **Workaround**: Entering a single project and refreshing worked; returning to project list and refreshing then worked
- **Expected**: Should show error message on failure, or handle refresh more gracefully
- **Related files**: Projects list view, git sync components

### 6. TodoWrite tool output not parsed correctly
- **What happened**: When the agent adds todos, the app only displays "ToDo" with no task details
- **Expected**: Should show the full list of todo items with their status and content
- **Possible cause**: TodoWrite tool output parsing not implemented or broken
- **Related files**: `Models.swift` (ToolType), message parsing, `CLIMessageView.swift`

### 7. [Feature] Verbose output log for debugging
- **Type**: Feature request
- **What**: Access to raw/verbose session logs for debugging issues
- **Details**:
  - Server likely has raw output vs parsed output
  - Would help debug parsing issues (like #6) and other problems
  - Could be a developer/debug mode toggle or separate log viewer
- **Related files**: `WebSocketManager.swift`, backend API

### 8. [Feature] Restore quick-access mode and thinking toggles
- **Type**: Feature request / UX regression
- **What happened**: New UI hides mode and thinking settings under status bar settings menu
- **Problem**: Adds extra click, harder to quickly cycle through options
- **Requested changes**:
  - Bring back chips in status bar for mode (normal/plan/bypass permissions)
  - Bring back chips for thinking level toggle
  - Add "dangerously bypass permissions" option in settings (Claude CLI feature)
- **Note**: Need to research how bypass permissions is implemented in Claude CLI
- **Related files**: Status bar view, `AppSettings.swift`

### 9. Chat scroll position jumps on orientation change
- **Platform**: iPhone
- **What happened**: Rotating from vertical to horizontal (or vice versa) causes chat to scroll to the top
- **Expected**: Should maintain scroll position relative to current content when rotating
- **Related files**: `ChatView.swift`, ScrollView handling

### 10. Token usage calculation may be inaccurate
- **What happened**: Token usage display may not be realistic or using correct context window size
- **Concern**: May not reflect latest Claude Code context window limits
- **To investigate**:
  - Verify context window size matches current Claude Code specs
  - Check if token counting method is accurate
  - Confirm usage percentage calculation is correct
- **Related files**: Token usage display components, `Models.swift`

### 11. [Feature] Auto-refresh git status in active project
- **Type**: Feature request
- **Current behavior**: Git status only updates manually or when reloading the project
- **Requested behavior**: Automatically refresh git status:
  - Periodically on a time interval while in a project
  - After task completion (when Claude makes changes)
- **Related files**: Git sync components, `SSHManager.swift`, `ChatView.swift`

### 12. [Feature] Quick commit & push button in pending changes banner
- **Type**: Feature request
- **Context**: Git banner already shows when there are pending changes (similar to pull request banner)
- **Requested behavior**: Add a button that sends a command to Claude to commit and push all changes to GitHub
- **Similar to**: The existing "Pull" button in the pull request banner
- **Related files**: Git sync banner components, `ChatView.swift`, `WebSocketManager.swift`

---

## Resolved Issues

*Issues that have been fixed will be moved here.*
