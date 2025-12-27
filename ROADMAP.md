# ClaudeCodeApp Roadmap

> Active development priorities for the iOS Claude Code client. This document covers committed, near-term work only.
>
> For completed work, see [CHANGELOG.md](CHANGELOG.md).
> For open issues, see [ISSUES.md](ISSUES.md).
> For future ideas and strategic vision, see [FUTURE-IDEAS.md](FUTURE-IDEAS.md).

---

## Status Legend

| Symbol | Meaning |
|--------|---------|
| Critical | Must fix immediately |
| High | Next sprint |
| Medium | Planned |
| Low | Backlog |

---

## Priority 1: Open Issues

Active bugs and feature requests from ISSUES.md.

### Bugs (High Priority)

| # | Issue | Description | Status |
|---|-------|-------------|--------|
| 13 | Git refresh error on launch | Alert shows SSHClient.CommandFailed error on iOS Simulator launch | **Fixed** |

### Bugs (Medium Priority)

| # | Issue | Description | Status |
|---|-------|-------------|--------|
| 14 | Status indicator stuck red | Claude indicator doesn't update with model changes | **Fixed** |

### Feature Requests (Medium Priority)

| # | Feature | Description | Effort | Status |
|---|---------|-------------|--------|--------|
| 7 | Verbose output log | Debug mode for raw WebSocket messages | Medium | Done |
| 15 | Per-project permissions toggle | Override dangerously-skip-permissions per project | Low | **Done** |

---

## Priority 1.5: Code Review Findings

Issues identified during comprehensive code review (December 27, 2025).

### Critical - Must Fix Immediately

| Issue | File | Lines | Description | Status |
|-------|------|-------|-------------|--------|
| Force unwrap URLComponents | `APIClient.swift` | 151, 188, 214 | Crashes on malformed URLs | **Fixed** |
| Force unwrap Data encoding | `APIClient.swift` | 230-238 | Force unwrap .utf8 encoding | **Fixed** |
| WebSocket state race | `WebSocketManager.swift` | 214-251 | State set before receive loop starts | **Fixed** (wait for first receive) |
| WebSocket send queue race | `WebSocketManager.swift` | 375-391 | Force unwrap self in completion handler | **Fixed** |
| Timer leak in ProcessingIndicator | `CLIStatusBarViews.swift` | 147 | Timer.publish never cancelled after view destroyed | **Fixed** |
| Uncancelled SSH tasks | `GlobalSearchView.swift` | 248, 256 | SSH commands can hang indefinitely | **Fixed** |

### High - Next Sprint

| Issue | File | Lines | Description | Status |
|-------|------|-------|-------------|--------|
| ClaudeHelper timeout race | `ClaudeHelper.swift` | 427-435 | Timeout task not stored/cancelled | To Do |
| **SSH command injection** | `SSHManager.swift` | 784, 793, 797 | Unescaped paths in uploadImage() | **Fixed** |
| SSHManager disconnect race | `SSHManager.swift` | 614-627 | Task not awaited, client deallocated | **Fixed** (singleton + deinit) |
| messageQueue not thread-safe | `WebSocketManager.swift` | 111, 316, 390 | Concurrent access corrupts queue | **Fixed** (MainActor) |
| processingTimeout logic error | `WebSocketManager.swift` | 146-175 | Timeout may never trigger | To Do |
| DispatchQueue retain cycle | `MessageActionBar.swift` | 52 | asyncAfter captures self without [weak self] | To Do |
| Git timer cancellation | `ChatView.swift` | 208, 220 | gitRefreshTimer may fire during deallocation | To Do |
| receiveMessage() uncancellable | `WebSocketManager.swift` | 646-657 | Recursive loop doesn't check Task.isCancelled | To Do |

### Medium - Planned

| Issue | File | Lines | Description | Status |
|-------|------|-------|-------------|--------|
| Missing @MainActor | `Models.swift` | 539 | ArchivedProjectsStore not thread-safe | **Fixed** |
| No periodic save | `Models.swift` | 590-666 | BookmarkStore may lose data on exit | To Do |
| Non-atomic image save | `Models.swift` | 392-413 | Orphaned images if JSON save fails | To Do |
| Cleanup validation | `IdeasStore.swift` | 455-466 | Silent failures in image cleanup | To Do |
| Orphaned suggestion task | `ChatView.swift` | 762-767 | Task not stored/cancelled when view disappears | To Do |
| EnvironmentObject assumption | `CLIStatusBarViews.swift` | 96 | StatLabel assumes settings in environment | To Do |
| fileQueue race condition | `Models.swift` | 392, 417 | Concurrent load/save can corrupt data | To Do |
| Task.isCancelled not checked | `WebSocketManager.swift` | 657 | Recursive receiveMessage ignores cancellation | To Do |

### Low - Backlog

| Issue | File | Lines | Description | Fix |
|-------|------|-------|-------------|-----|
| Uses print() not Logger | `SpeechManager.swift` | 107, 127 | Inconsistent logging | Replace with log.debug() |
| Missing @MainActor | `DebugLogStore.swift` | 169 | copyToClipboard() UI operation | Add @MainActor annotation |
| Excessive @State | `ChatView.swift` | 16-60 | 40+ scattered state variables | Group into ChatViewState struct |
| Not @Published | `WebSocketManager.swift` | 80 | isAppInForeground not observable | Add @Published |
| DateFormatter per-call | `DebugLogStore.swift` | 56-61 | Performance issue in lists | Use static instance |
| Silent search failures | `GlobalSearchView.swift` | 248 | try? silences SSH errors, no user feedback | Log errors, show failure state |

---

## Priority 2: Code Quality

Developer experience and code health improvements.

| Feature | Description | Effort | Priority |
|---------|-------------|--------|----------|
| Configurable History | Make 50-message limit configurable (25, 50, 100, 200) | Low | Medium |
| Error UI Component | Centralized error display component | Medium | Medium |
| Structured Logging | Consistent Logger usage across all managers | Low | Low |
| Unit Test Coverage | Expand tests for managers (WebSocket, SSH, Speech) | Medium | Low |

---

## Implementation Order

```
Phase 1: Critical Code Review Fixes (6 items) - COMPLETE
[x] Force unwrap URLComponents (APIClient)     [Low effort] DONE
[x] Force unwrap Data encoding (APIClient)     [Low effort] DONE
[x] WebSocket state race                       [Medium effort] DONE
[x] WebSocket send queue race                  [Medium effort] DONE
[x] Timer leak in ProcessingIndicator          [Low effort] DONE
[x] Uncancelled SSH tasks (GlobalSearchView)   [Medium effort] DONE

Phase 2: High Priority Fixes (8 items) - 3/8 DONE
[x] SSH command injection (SECURITY)           [Low effort] DONE
+-- ClaudeHelper timeout race                  [Low effort]
+-- SSHManager disconnect race                 [Low effort]
[x] messageQueue thread safety                 [Medium effort] DONE (MainActor)
+-- processingTimeout logic error              [Low effort]
+-- DispatchQueue retain cycle                 [Low effort]
+-- Git timer cancellation                     [Low effort]
+-- receiveMessage() uncancellable             [Low effort]

Phase 3: Open Issues (3 items) - COMPLETE
[x] #13 Git refresh error on launch            [Investigation needed] DONE
[x] #14 Status indicator stuck red             [Low effort] DONE
[x] #15 Per-project permissions toggle         [Low effort] DONE

Phase 4: Medium Priority Fixes (8 items) - 1/8 DONE
[x] ArchivedProjectsStore @MainActor           [Low effort] DONE
+-- BookmarkStore periodic save                [Low effort]
+-- Non-atomic image save                      [Medium effort]
+-- IdeasStore cleanup validation              [Low effort]
+-- Orphaned suggestion task                   [Low effort]
+-- EnvironmentObject assumption               [Low effort]
+-- fileQueue race condition                   [Medium effort]
+-- Task.isCancelled not checked               [Low effort]

Phase 5: Code Quality & Low Priority (6 items)
+-- Configurable history limit                 [Low effort]
+-- Structured logging                         [Low effort]
+-- Error UI component                         [Medium effort]
+-- Unit test coverage                         [Medium effort]
+-- Silent search failures                     [Low effort]
+-- Other low priority code review fixes       [Low effort]
```

---

## Feature Specifications

### Feature #7: Verbose Output Log - DONE

**Implemented:** December 27, 2025

**Purpose:** Debug parsing issues by viewing raw WebSocket messages

**Added:**
- `DebugLogStore.swift` - Singleton store for debug log entries with:
  - Log types: SENT, RECV, ERROR, INFO, CONN
  - Pretty-printed JSON formatting
  - Type filtering and search
  - Clipboard export
  - 500 entry maximum to prevent memory issues
- `Views/DebugLogView.swift` - Full-featured log viewer with:
  - Searchable log entries
  - Filter chips by log type
  - Detail view with formatted JSON
  - Copy individual or all entries
  - Auto-scroll to latest
- `AppSettings.debugLoggingEnabled` - Persisted toggle
- QuickSettingsSheet - Developer section with toggle and log viewer access
- WebSocketManager integration - Logs connect, disconnect, send, receive, and errors

**Files created:**
- `DebugLogStore.swift`
- `Views/DebugLogView.swift`

**Files modified:**
- `WebSocketManager.swift` - Added debug logging calls
- `AppSettings.swift` - Added debugLoggingEnabled toggle
- `ClaudeCodeAppApp.swift` - Initialize debug state on launch
- `Views/QuickSettingsSheet.swift` - Added Developer section

---

### Bug #13: Git Refresh Error on Launch - FIXED

**Fixed:** December 27, 2025

**Problem:** SSHClient.CommandFailed error alert shown on iOS Simulator launch when git status check fails due to missing SSH credentials.

**Solution:** Modified `SSHManager.checkGitStatusWithAutoConnect()` to silently return `.unknown` for SSH connection failures (expected when SSH is not configured) and only return `.error` for actual git command failures after successful connection.

**Files modified:**
- `SSHManager.swift` - Separated connection failure handling from git command failure handling

---

### Bug #14: Status Indicator Stuck Red - FIXED

**Fixed:** December 27, 2025

**Problem:** The connection status indicator only showed red (disconnected) or green (connected), with no visual feedback for connecting/reconnecting states.

**Solution:**
- Updated `UnifiedStatusBar` to accept full `ConnectionState` instead of just `isConnected: Bool`
- Added yellow color for connecting/reconnecting states
- Added pulsing animation for connecting states to show activity
- Properly shows: red (disconnected), yellow pulsing (connecting), yellow (processing), green (connected and idle)

**Files modified:**
- `Views/CLIStatusBarViews.swift` - Added ConnectionState support and pulsing animation
- `ChatView.swift` - Pass connectionState to UnifiedStatusBar

---

### Feature #15: Per-Project Permissions Toggle - DONE

**Implemented:** December 27, 2025

**Purpose:** Override global `dangerously-skip-permissions` setting per project

**Added:**
- `ProjectSettingsStore.swift` - Singleton store for per-project settings with:
  - Skip permissions override: nil (use global), true (force on), false (force off)
  - Automatic persistence to Documents directory
  - Similar pattern to IdeasStore for consistency
- Status bar bypass indicator now tappable to toggle per-project override
- Visual indicators: "Bypass" (using global), "Bypass*" (project override on), "Safe*" (project override off)
- Cycles through: use global -> force on -> force off -> use global

**Files created:**
- `ProjectSettingsStore.swift`

**Files modified:**
- `Views/CLIStatusBarViews.swift` - Tappable bypass indicator with per-project toggle
- `ChatView.swift` - Added effectiveSkipPermissions and effectivePermissionMode computed properties

---

### Phase 1 Critical Fixes - COMPLETE

**Completed:** December 27, 2025

All critical code review fixes from Phase 1 have been implemented:

1. **Force unwrap URLComponents** (`APIClient.swift`): Changed all 3 instances from force unwrap to guard + throw APIError.invalidURL

2. **Force unwrap Data encoding** (`APIClient.swift`): Added `Data.appendString()` extension for safe UTF-8 string appending in multipart form data

3. **WebSocket state race** (`WebSocketManager.swift`): Connection state now set only after first successful message receive, not immediately after socket resume

4. **WebSocket send queue race** (`WebSocketManager.swift`): Fixed force unwrap of `self!` in completion handler, now uses `guard let self = self`

5. **Timer leak in ProcessingIndicator** (`CLIStatusBarViews.swift`): Timer now stored as `AnyCancellable` and cancelled in `.onDisappear`

6. **Uncancelled SSH tasks** (`GlobalSearchView.swift`): Search and connect tasks now stored and cancelled on view disappear, with cancellation checks between operations

**Additional fixes from Phase 2/4:**

7. **SSH command injection** (`SSHManager.swift`): Applied `shellEscape()` to all path variables in `uploadImage()`

8. **messageQueue thread safety** (`WebSocketManager.swift`): Already protected by `@MainActor`, no additional synchronization needed

9. **ArchivedProjectsStore @MainActor** (`Models.swift`): Added `@MainActor` annotation, updated tests to match

---

*Last updated: December 27, 2025 - Completed Phase 1 Critical Fixes, Bug #13, Bug #14, and Feature #15*
