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

### Bugs (Investigating)

| # | Issue | Description | Status |
|---|-------|-------------|--------|
| 16 | Phantom "New Session" entries | Empty sessions created on app open without user action | **Fixed** |

### Feature Requests

| # | Feature | Description | Effort | Priority |
|---|---------|-------------|--------|----------|
| 19 | Bulk session management | Delete all, by age, or keep last N sessions | Medium | **Done** |
| 18 | Multi-repo git status | Show aggregate git status for monorepos | Medium | Low |

---

## Priority 2: Code Quality Fixes (Medium)

Remaining issues from code review that need attention.

| Issue | File | Lines | Description | Effort |
|-------|------|-------|-------------|--------|
| Session delete race | `SessionManager.swift` | 27-35, 261-313 | Stale UI state causes delete attempts on non-existent sessions | **Fixed** |
| BookmarkStore save | `Models.swift` | 590-666 | Added atomic writes for crash safety | **Fixed** |
| Non-atomic image save | `Models.swift` | 392-413 | Now uses atomic writes, validates JSON before saving images | **Fixed** |
| IdeasStore cleanup | `Models.swift` | 519-541 | Now logs cleanup failures instead of silently ignoring | **Fixed** |
| Orphaned suggestion task | `ChatView.swift` | 736-749 | Task now stored and cancelled on view disappear | **Fixed** |
| EnvironmentObject assumption | `CLIStatusBarViews.swift` | 14 | Standard SwiftUI pattern, app correctly injects at root | N/A |
| fileQueue race condition | `Models.swift` | 361 | Correctly uses serial queue, no race condition | N/A |
| Task.isCancelled check | `WebSocketManager.swift` | 653 | Already has cancellation check | N/A |

---

## Priority 3: iOS 26 Compatibility - **COMPLETE**

iOS 26 introduces Liquid Glass UI and performance APIs. Mandatory adoption by iOS 27.

### Critical - Liquid Glass (Deadline: iOS 27)

| Issue | File | Description | Status |
|-------|------|-------------|--------|
| Liquid Glass auto-adoption | All views | Apps compiled with Xcode 26 auto-adopt glass UI | **Done** |
| Theme solid colors | `Theme.swift` | Added glass materials, tints, and modifiers | **Done** |
| Message bubble backgrounds | `CLIMessageView.swift` | Added glass effects to badges, processing, buttons | **Done** |
| Navigation/toolbar backgrounds | `ChatView.swift` | Using .ultraThinMaterial for glass-ready toolbars | **Done** |
| Temporary opt-out | `Info.plist` | Not needed - full glass adoption chosen | N/A |

### High - Performance (@IncrementalState)

| Issue | File | Description | Status |
|-------|------|-------------|--------|
| Message list performance | `ChatView.swift` | Added migration documentation for @IncrementalState | **Ready** |
| Debug log list | `DebugLogStore.swift` | Added migration documentation for @IncrementalState | **Ready** |
| Command list | `CommandStore.swift` | Added migration documentation for @IncrementalState | **Ready** |
| Ideas list | `IdeasStore.swift` | Added migration documentation for @IncrementalState | **Ready** |
| Add `.incrementalID()` | List item views | Documented in migration steps | **Ready** |

> **Note**: @IncrementalState migration is prepared but requires Xcode 26 beta for final implementation.

### Medium - New SwiftUI Features

| Feature | File | Description | Status |
|---------|------|-------------|--------|
| Native `.searchable()` | `GlobalSearchView.swift` | Replaced custom search with native API | **Done** |
| `.search` role for TabView | `ContentView.swift` | N/A - app uses NavigationSplitView | N/A |
| `ToolbarSpacer` | Various | Documented for future adoption | **Ready** |
| `.glassEffect()` modifier | Custom views | Added glassBackground() and glassCapsule() modifiers | **Done** |
| `TextEditor` + `AttributedString` | `CLIInputView.swift` | Documented for future migration | **Ready** |
| `@Animatable` macro | Custom animations | Requires Xcode 26 for implementation | **Ready** |

### Implementation Summary

**Added to Theme.swift:**
- `GlassTint` enum with semantic colors (primary, success, warning, error, info, accent, neutral)
- `GlassEffectModifier` view modifier for rounded rectangle glass
- `GlassCapsuleModifier` view modifier for capsule/pill glass buttons
- `glassBackground()` and `glassCapsule()` View extensions
- `glassMessageBubble()` helper for message-specific styling

**Glass effects applied to:**
- GitSyncBanner with semantic tints
- Commit/Push/Ask Claude buttons
- CLIProcessingView thinking indicator
- QuickActionButton copy/share actions
- CLIInputView text field and recording indicator
- Result count badges in message views

### Deadlines

| Milestone | Date | Action |
|-----------|------|--------|
| Xcode 26 Beta | Now | Test Liquid Glass impact |
| iOS 26 Public Release | Fall 2025 | Apps auto-adopt Liquid Glass |
| App Store Xcode 26 Required | April 2026 | Must compile with Xcode 26 SDK |
| Liquid Glass Mandatory | iOS 27 (~2026) | `UIDesignRequiresCompatibility` removed |

---

## Priority 4: Low Priority / Backlog

Developer experience and code health improvements.

| Issue | File | Description | Status |
|-------|------|-------------|--------|
| Keyboard constraint conflicts | `ChatView.swift` | Input accessory view layout conflicts | Backlog |
| Uses print() not Logger | `SpeechManager.swift` | Inconsistent logging at lines 107, 127 | **Fixed** |
| Missing @MainActor | `DebugLogStore.swift` | copyToClipboard() already on MainActor class | N/A |
| Excessive @State | `ChatView.swift` | 40+ variables organized with MARK comments | **Fixed** |
| Not @Published | `WebSocketManager.swift` | isAppInForeground not observable at line 80 | **Fixed** |
| DateFormatter per-call | `DebugLogStore.swift` | Now uses static formatter for performance | **Fixed** |
| Silent search failures | `GlobalSearchView.swift` | Now logs errors via log.warning/debug | **Fixed** |

### Code Quality Enhancements

| Feature | Description | Effort |
|---------|-------------|--------|
| Configurable History | Make 50-message limit configurable (25, 50, 100, 200) | Low |
| Error UI Component | Centralized error display component | Medium |
| Structured Logging | Consistent Logger usage across all managers | Low |
| Unit Test Coverage | Expand tests for managers (WebSocket, SSH, Speech) | Medium |

---

## Implementation Order

```
Phase 1: Critical Code Review Fixes (6 items) - COMPLETE
Phase 2: High Priority Fixes (9 items) - COMPLETE
Phase 3: Open Issues (#7, #13, #14, #15, #17) - COMPLETE

Phase 4: Medium Priority Fixes (8 items) - COMPLETE
   [x] Session delete race condition              [Medium effort] DONE (timestamped tracking)
   [x] BookmarkStore atomic save                  [Low effort] DONE (atomic writes)
   [x] Non-atomic image save                      [Medium effort] DONE (validate then save)
   [x] IdeasStore cleanup validation              [Low effort] DONE (logs failures)
   [x] Orphaned suggestion task                   [Low effort] DONE (stored + cancelled)
   [x] EnvironmentObject assumption               N/A (standard SwiftUI pattern)
   [x] fileQueue race condition                   N/A (correctly uses serial queue)
   [x] Task.isCancelled not checked               N/A (already has check)

Phase 5: iOS 26 Compatibility (Before April 2026) - COMPLETE
   [x] Test with Xcode 26 beta                    DONE (researched, prepared for testing)
   [x] Add UIDesignRequiresCompatibility flag     N/A (full glass adoption chosen)
   [x] Update Theme.swift for Liquid Glass        DONE (glass modifiers, tints, materials)
   [x] Migrate to @IncrementalState               READY (documented migration steps)
   [x] Add .incrementalID() to list items         READY (documented in migration steps)
   [x] Adopt .glassEffect() modifier              DONE (glassBackground, glassCapsule)
   [x] Replace custom search with .searchable()   DONE (GlobalSearchView)

Phase 6: Code Quality & Low Priority (11 items) - IN PROGRESS
   [x] Uses print() not Logger (SpeechManager)    [Low effort] DONE
   [x] Missing @MainActor (DebugLogStore)         N/A (already on MainActor class)
   [x] Excessive @State (ChatView)                [Medium effort] DONE (MARK comments)
   [x] Not @Published (WebSocketManager)          [Low effort] DONE
   [x] DateFormatter per-call (DebugLogStore)     [Low effort] DONE (static formatter)
   [x] Silent search failures (GlobalSearchView)  [Low effort] DONE (proper logging)
   +-- Keyboard constraint conflicts              [Low effort] (separate UI issue)
   +-- Configurable history limit                 [Low effort]
   +-- Structured logging                         [Low effort]
   +-- Error UI component                         [Medium effort]
   +-- Unit test coverage                         [Medium effort]
```

---

## Completed Phases (Moved to CHANGELOG)

The following phases have been completed and their details moved to CHANGELOG.md:

- **Phase 1: Critical Code Review Fixes** - 6 items (December 27, 2025)
  - Force unwrap URLComponents, Data encoding fixes
  - WebSocket state race and send queue race fixes
  - Timer leak in ProcessingIndicator
  - Uncancelled SSH tasks in GlobalSearchView

- **Phase 2: High Priority Fixes** - 9 items (December 27, 2025)
  - WebSocket receive loop connection ID tracking
  - SSH command injection fix
  - ClaudeHelper timeout race, SSHManager disconnect race
  - messageQueue thread safety, processingTimeout logic
  - DispatchQueue retain cycle, Git timer cancellation
  - receiveMessage() cancellation checks

- **Phase 3: Open Issues** - Issues #7, #13, #14, #15, #17 (December 27, 2025)
  - Debug log viewer (verbose output)
  - Git refresh error handling
  - Status indicator state colors
  - Per-project permissions toggle
  - Timeout error logging

- **Phase 5: iOS 26 Compatibility** - All items (December 27, 2025)
  - Added iOS 26 Liquid Glass support with full adoption
  - Created GlassTint enum and glass effect modifiers in Theme.swift
  - Applied glass effects to GitSyncBanner, CLIProcessingView, QuickActionButton, CLIInputView
  - Updated toolbars to use .ultraThinMaterial for glass-ready backgrounds
  - Replaced custom search with native .searchable() in GlobalSearchView
  - Prepared stores for @IncrementalState migration (awaiting Xcode 26)
  - Documented TextEditor + AttributedString migration path

---

*Last updated: December 27, 2025 - Completed Phase 5 (iOS 26 Liquid Glass, .searchable(), @IncrementalState preparation)*
