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

*No open issues at this time.*

---

## Code Quality & Refactoring Opportunities

*Identified during codebase audit on 2026-01-01*

### File Size & Organization (Low Priority - Tech Debt)

Large files that would benefit from being split into smaller, focused modules:

| File | Lines | Suggested Split |
|------|-------|-----------------|
| `CLIBridgeTypes.swift` | ~1700 | Split into `CLIBridgeModels/`, `CLIBridgeEnums/`, `AnyCodable.swift` |
| `ChatViewModel.swift` | ~1600 | Extract: `ChatSessionLogic.swift`, `ChatMessageHandling.swift`, `ChatGitIntegration.swift` |
| `Models.swift` | ~1300 | Extract: `ChatMessage.swift`, `MessageStore.swift`, `BookmarkStore.swift`, `CommandStore.swift` |
| `SSHManager.swift` | ~1100 | Extract: `SSHKeyManagement.swift`, `SSHFileOperations.swift`, `SSHGitOperations.swift` |
| `CLIBridgeManager.swift` | ~900 | Consider splitting SSE handling into `CLIBridgeSSEHandler.swift` |

### Audit Verification Summary (2026-01-01)

| Pattern | Finding |
|---------|---------|
| `@MainActor` on ObservableObjects | All 25+ `ObservableObject` classes have `@MainActor` annotation |
| SSH path escaping | All SSH commands use `shellEscapePath()` for proper escaping |
| Keychain security | Uses `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` for all credentials |
| Force unwraps | Only safe patterns found (guarded by nil checks in same expression) |
| Force casts (`as!`) | Only in BGTaskScheduler callbacks where type is guaranteed by registration |
| `[weak self]` usage | Correct in file observers, timers, and long-running operations |
| DispatchQueue.main | Appropriate uses: UI timing delays, Combine schedulers (no threading issues) |
| TODO comments | Only one minor enhancement: image retry support in ChatViewModel:646 |

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
| 47 | UICollectionView crash on scroll (delayed scroll after List renders) | 0.6.8 |
| 46 | Duplicate messages in export API fallback path | 0.6.8 |
| 45 | Chat scroll performance (migrated to List for cell recycling) | 0.6.8 |
| 44 | Retry logic for transient errors | 0.6.8 |
| 43 | Request timeout configuration | 0.6.8 |
| 42 | Weak self in Task closures (verified correct) | 0.6.8 |
| 41 | Mixed callback and Combine patterns (verified intentional) | 0.6.8 |
| 40 | stringifyAnyValue() complexity (documented as intentional) | 0.6.8 |
| 39 | cleanAnyCodableWrappers() string manipulation (migration code) | 0.6.8 |
| 38 | DateFormatter instances (created shared CLIDateFormatter) | 0.6.8 |
| 37 | AnyCodable duplication (replaced with typealias) | 0.6.8 |
| 35 | Git refresh error on pull-to-refresh | 0.6.8 |
| 24 | Token calculation in cli-bridge (verified correct) | 0.6.8 |
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
