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

### #24: Token Usage Calculation Wildly Inaccurate (To Investigate)
- **What happened**: Token counts displayed in the app are significantly wrong compared to actual usage
- **Expected**: Token usage should reflect actual consumption accurately
- **Location**: Token display UI, SSE response parsing
- **Investigation needed**:
  - Audit what the backend/API is actually sending for token counts
  - Compare API-reported tokens vs actual message content size
  - Determine if issue is API-side or client-side parsing
  - Consider client-side token estimation as fallback/validation
  - Check if SSE events have different token reporting than complete messages
- **Priority**: Medium - affects user's ability to monitor usage

### #25: Voice Transcription Bar Text Unreadable in Dark Mode
- **What happened**: Gray text on red background during voice-to-text makes transcription text very hard to read, especially in dark mode
- **Expected**: Text should have sufficient contrast against the red recording indicator background
- **Location**: Voice transcription status bar UI (likely `SpeechManager` related views)
- **Fix needed**:
  - Change text color to white or light color when on red background
  - Ensure WCAG AA contrast ratio (4.5:1 minimum) for accessibility
- **Priority**: Medium - affects usability of voice input feature

### #28: `xcodebuild test` (all targets) fails to load CodingBridgeTests bundle
- **What happened**: Running the default scheme test command fails with `Failed to create a bundle instance representing .../CodingBridgeTests.xctest`.
- **Expected**: `xcodebuild test -project CodingBridge.xcodeproj -scheme CodingBridge ...` runs unit + UI tests without bundle load errors.
- **Steps to reproduce**: Run `xcodebuild test -project CodingBridge.xcodeproj -scheme CodingBridge -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'`.
- **Notes**: `-only-testing:CodingBridgeTests` and `-only-testing:CodingBridgeUITests` succeed independently.
- **Investigation needed**:
  - Inspect scheme/test plan configuration for mixed unit/UI targets.
  - Verify test host/bundle loader settings and derived data staging.
- **Location**: `CodingBridge.xcodeproj/xcshareddata/xcschemes/CodingBridge.xcscheme`, `CodingBridge.xcodeproj/project.pbxproj`

### #29: BGTaskScheduler "Unrecognized Identifier" on Simulator (Low Priority)
- **What happened**: BGTaskScheduler reports "Unrecognized Identifier" error even with correct bundle ID prefix and synchronous registration
- **Expected**: Background tasks should register without errors
- **Error**: `BGTaskSchedulerErrorDomain Code=3 "Unrecognized Identifier=com.level.CodingBridge.task.refresh"`
- **Location**: `BackgroundManager.swift:106`
- **Investigation done**:
  - Task IDs use bundle ID prefix (com.level.CodingBridge.task.*)
  - Info.plist BGTaskSchedulerPermittedIdentifiers match
  - Registration is synchronous in didFinishLaunchingWithOptions
  - UIBackgroundModes includes "fetch" and "processing"
- **Notes**:
  - May be simulator-specific limitation
  - Core background notification flow works regardless (tested on device)
  - iOS 26+ BGContinuedProcessingTask is the primary mechanism anyway
- **Priority**: Low - doesn't block functionality

### #30: Session Manager Not Showing All Sessions
- **What happened**: Home screen shows 38 sessions for a project, but Session Manager only shows 1
- **Expected**: Session Manager should display the same sessions as home screen
- **Investigation needed**:
  - Compare endpoints used: home screen uses `/sessions/recent`, session manager uses `/projects/{path}/sessions`
  - Verify both endpoints return consistent data
  - Check if source filter or pagination is causing mismatch
  - Ensure SessionStore properly loads and displays all sessions
- **Location**: `SessionPickerViews.swift`, `SessionStore.swift`, `HomeView.swift`
- **Priority**: High - affects session navigation and resume functionality

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

---

## Resolved Issues

See [CHANGELOG.md](CHANGELOG.md) for details on resolved issues.

| # | Issue | Version |
|---|-------|---------|
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
