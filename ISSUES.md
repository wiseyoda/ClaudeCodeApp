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

### #32: ClaudeHelper AI Suggestions Not Working
- **What happened**: Auto-suggestions feature not triggering after Claude responses
- **Expected**: AI should suggest next actions based on response context
- **Investigation needed**:
  - Verify ClaudeHelper is receiving response content
  - Check if suggestion prompts are being sent to API
  - Confirm UI is displaying suggestions when received
- **Location**: `ClaudeHelper.swift`, `ChatView.swift`
- **Priority**: Medium - affects usability enhancement feature

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

---

## Resolved Issues

See [CHANGELOG.md](CHANGELOG.md) for details on resolved issues.

| # | Issue | Version |
|---|-------|---------|
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
