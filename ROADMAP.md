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
| WebSocket receive loop dies | `WebSocketManager.swift` | 739 | Receive callback terminates because self/webSocket is nil ~500ms after connect | To Do |
| ClaudeHelper timeout race | `ClaudeHelper.swift` | 442-452 | Timeout task not stored/cancelled | **Fixed** |
| **SSH command injection** | `SSHManager.swift` | 784, 793, 797 | Unescaped paths in uploadImage() | **Fixed** |
| SSHManager disconnect race | `SSHManager.swift` | 614-627 | Task not awaited, client deallocated | **Fixed** (singleton + deinit) |
| messageQueue not thread-safe | `WebSocketManager.swift` | 111, 316, 390 | Concurrent access corrupts queue | **Fixed** (MainActor) |
| processingTimeout logic error | `WebSocketManager.swift` | 175-224 | Timeout may never trigger | **Fixed** (5s checks, nil handling) |
| DispatchQueue retain cycle | `MessageActionBar.swift` | 49-59 | asyncAfter not cancellable | **Fixed** (Task + onDisappear) |
| Git timer cancellation | `ChatView.swift` | 214-223 | gitRefreshTimer may fire during deallocation | **Fixed** (Task + cancellation) |
| receiveMessage() uncancellable | `WebSocketManager.swift` | 719-768 | Recursive loop doesn't check cancellation | **Fixed** (state checks) |

### Medium - Planned

| Issue | File | Lines | Description | Status |
|-------|------|-------|-------------|--------|
| Session delete race condition | `SessionManager.swift` | - | Attempts to delete sessions that don't exist on server (stale UI state) | To Do |
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
| Keyboard constraint conflicts | `ChatView.swift` | - | accessoryView.bottom vs inputView.top constraint conflicts during text input | Investigate input accessory view layout |
| Uses print() not Logger | `SpeechManager.swift` | 107, 127 | Inconsistent logging | Replace with log.debug() |
| Missing @MainActor | `DebugLogStore.swift` | 169 | copyToClipboard() UI operation | Add @MainActor annotation |
| Excessive @State | `ChatView.swift` | 16-60 | 40+ scattered state variables | Group into ChatViewState struct |
| Not @Published | `WebSocketManager.swift` | 80 | isAppInForeground not observable | Add @Published |
| DateFormatter per-call | `DebugLogStore.swift` | 56-61 | Performance issue in lists | Use static instance |
| Silent search failures | `GlobalSearchView.swift` | 248 | try? silences SSH errors, no user feedback | Log errors, show failure state |

---

## Priority 2: iOS 26 Compatibility

iOS 26 introduces Liquid Glass UI and performance APIs. Mandatory adoption by iOS 27.

### Critical - Liquid Glass (Deadline: iOS 27)

| Issue | File | Description | Status |
|-------|------|-------------|--------|
| Liquid Glass auto-adoption | All views | Apps compiled with Xcode 26 auto-adopt glass UI | To Do |
| Theme solid colors | `Theme.swift` | CLITheme colors may conflict with translucent materials | To Do |
| Message bubble backgrounds | `CLIMessageView.swift` | Solid bubbles need glass adaptation | To Do |
| Navigation/toolbar backgrounds | `ChatView.swift` | Toolbars will become translucent | To Do |
| **Temporary opt-out** | `Info.plist` | Add `UIDesignRequiresCompatibility = YES` if needed | To Do |

### High - Performance (@IncrementalState)

| Issue | File | Lines | Description | Status |
|-------|------|-------|-------------|--------|
| Message list performance | `ChatView.swift` | 16 | Migrate `@State messages` to `@IncrementalState` | To Do |
| Debug log list | `DebugLogStore.swift` | 8 | 500+ items, migrate to `@IncrementalState` | To Do |
| Command list | `CommandStore.swift` | 8 | Migrate `@Published commands` | To Do |
| Ideas list | `IdeasStore.swift` | 8 | Migrate `@Published ideas` | To Do |
| Add `.incrementalID()` | List item views | - | Required for incremental updates to work | To Do |

### Medium - New SwiftUI Features

| Feature | File | Description | Status |
|---------|------|-------------|--------|
| Native `.searchable()` | `GlobalSearchView.swift` | Replace custom search with native API | To Do |
| `.search` role for TabView | `ContentView.swift` | Dedicated search tab if applicable | To Do |
| `ToolbarSpacer` | Various | Replace manual toolbar spacers | To Do |
| `.glassEffect()` modifier | Custom views | Add frosted glass to custom components | To Do |
| `TextEditor` + `AttributedString` | `CLIInputView.swift` | Rich text support if needed | To Do |
| `@Animatable` macro | Custom animations | Simplify animation code | To Do |

### Low - Future Consideration

| Feature | Description | Notes |
|---------|-------------|-------|
| Native `WebView` | SwiftUI WebView component | Only if web content needed |
| Scene bridging | Mix UIKit/SwiftUI scenes | Already pure SwiftUI, not needed |
| `Chart3D` | 3D visualizations | Only if analytics needed |

### Deadlines

| Milestone | Date | Action |
|-----------|------|--------|
| Xcode 26 Beta | Now | Test Liquid Glass impact |
| iOS 26 Public Release | Fall 2025 | Apps auto-adopt Liquid Glass |
| App Store Xcode 26 Required | April 2026 | Must compile with Xcode 26 SDK |
| Liquid Glass Mandatory | iOS 27 (~2026) | `UIDesignRequiresCompatibility` removed |

---

## Priority 3: Code Quality

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

Phase 2: High Priority Fixes (9 items) - 8/9 DONE
+-- WebSocket receive loop dies                [Medium effort] (self/webSocket nil ~500ms after connect)
[x] SSH command injection (SECURITY)           [Low effort] DONE
[x] ClaudeHelper timeout race                  [Low effort] DONE
+-- SSHManager disconnect race                 [Low effort] (already fixed as singleton + deinit)
[x] messageQueue thread safety                 [Medium effort] DONE (MainActor)
[x] processingTimeout logic error              [Low effort] DONE
[x] DispatchQueue retain cycle                 [Low effort] DONE
[x] Git timer cancellation                     [Low effort] DONE
[x] receiveMessage() uncancellable             [Low effort] DONE

Phase 3: Open Issues (3 items) - COMPLETE
[x] #13 Git refresh error on launch            [Investigation needed] DONE
[x] #14 Status indicator stuck red             [Low effort] DONE
[x] #15 Per-project permissions toggle         [Low effort] DONE

Phase 4: Medium Priority Fixes (9 items) - 1/9 DONE
[x] ArchivedProjectsStore @MainActor           [Low effort] DONE
+-- Session delete race condition              [Medium effort] (stale UI state)
+-- BookmarkStore periodic save                [Low effort]
+-- Non-atomic image save                      [Medium effort]
+-- IdeasStore cleanup validation              [Low effort]
+-- Orphaned suggestion task                   [Low effort]
+-- EnvironmentObject assumption               [Low effort]
+-- fileQueue race condition                   [Medium effort]
+-- Task.isCancelled not checked               [Low effort]

Phase 5: iOS 26 Compatibility (Before April 2026)
+-- Test with Xcode 26 beta                    [Investigation]
+-- Add UIDesignRequiresCompatibility flag     [Low effort] (if needed)
+-- Update Theme.swift for Liquid Glass        [Medium effort]
+-- Migrate to @IncrementalState               [Medium effort]
+-- Add .incrementalID() to list items         [Low effort]
+-- Adopt .glassEffect() modifier              [Low effort]
+-- Replace custom search with .searchable()   [Low effort]

Phase 6: Code Quality & Low Priority (7 items)
+-- Keyboard constraint conflicts              [Low effort] (investigate input accessory view)
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

*Last updated: December 27, 2025 - Added console log analysis issues: WebSocket receive loop, session delete race, keyboard constraints*
