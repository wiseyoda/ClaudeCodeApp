# CodingBridge Roadmap

> Implementation plan for the iOS Claude Code client.
>
> **Related docs**: [CHANGELOG.md](CHANGELOG.md) | [ISSUES.md](ISSUES.md) | [FUTURE-IDEAS.md](FUTURE-IDEAS.md)

---

## Overview

| Phase | Focus | Priority | Status |
|-------|-------|----------|--------|
| 1 | Security Hardening | Critical | ✅ Complete |
| 2 | Data Correctness | High | In Progress |
| 3 | Stability & Thread Safety | High | In Progress |
| 4 | Architecture Refactoring | Medium | Pending |
| 5 | Performance & Polish | Medium | Partial |
| 6 | iOS 26 Adoption | Medium | Pending |
| 7 | Test Coverage | Ongoing | Pending |

---

## Active Projects

### claudecodeui Fork Integration

See: [requirements/projects/claudecode-fork/implementation-plan.md](requirements/projects/claudecode-fork/implementation-plan.md)

**Remaining iOS work:**
- Use `sessionType` API field instead of local filtering
- Use `textContent` field for message rendering
- Enable `?batch=<ms>` WebSocket parameter
- Retest "Always Allow" permission

---

## Phase 2: Data Correctness

> **Priority**: High | **Status**: Mostly Complete

### 2.1 Read Tool File Extension Labels ✅

Session analysis shows Read dominates at 40% of tool usage. Add file extension context to headers.

| Task | File | Status |
|------|------|--------|
| Add extension labels | `CLIMessageView.swift` | ✅ Complete - Shows language name (Swift, TypeScript, etc.) |

### 2.2 API URL Encoding ✅

API paths built with raw strings fail for project names with spaces/special characters.

| Task | File | Status |
|------|------|--------|
| Encode session path | `APIClient.swift` | ✅ Complete - Uses `addingPercentEncoding` |
| Encode token path | `APIClient.swift` | ✅ Complete - Uses `addingPercentEncoding` |
| Encode upload path | `APIClient.swift` | ✅ Complete - Uses `addingPercentEncoding` |

### 2.3 Session History Completeness

Session history parsing returns on first content item, dropping multi-part messages.

| Task | File | Action |
|------|------|--------|
| Aggregate content parts | `APIClient.swift` | Collect all text/tool_use items instead of returning on first |

### 2.4 Auth Retry Handling ✅

Recursive `fetchProjects()` after `login()` with no retry cap risks infinite loops.

| Task | File | Status |
|------|------|--------|
| Add retry limit | `APIClient.swift` | ✅ Complete - `retryCount` parameter, max 1 retry |

---

## Phase 3: Stability & Thread Safety

> **Priority**: High

### 3.1 @MainActor Annotations ✅

ObservableObject classes missing @MainActor can cause cross-thread crashes.

| Task | File | Status |
|------|------|--------|
| Add @MainActor to BookmarkStore | `Models.swift` | ✅ Complete - Already present |
| Add @MainActor to AppSettings | `AppSettings.swift` | ✅ Complete - Added annotation |

### 3.2 WebSocket State Machine

Connection state transitions can race between ping/receive callbacks.

| Task | File | Action |
|------|------|--------|
| Serialize state transitions | `WebSocketManager.swift` | Use actor or serial queue for state |
| Guard message sends | `WebSocketManager.swift` | Ensure connection fully established before send |

### 3.3 SSH Command Serialization

Citadel SSH library doesn't handle concurrent commands reliably.

| Task | File | Action |
|------|------|--------|
| Serialize git status checks | `ContentView.swift` | Use async queue or sequential execution |

---

## Phase 4: Architecture Refactoring

> **Priority**: Medium

### 4.1 ChatView Decomposition

ChatView has 25+ @State properties and ~1968 lines.

| Task | Files | Action |
|------|-------|--------|
| Extract ChatViewModel | `ChatView.swift` | Move state to ObservableObject |
| Extract ChatSearchView | `ChatView.swift` | Separate search UI and logic |
| Extract ChatToolbar | `ChatView.swift` | Toolbar as separate component |
| Extract GitStatusCoordinator | `ChatView.swift` | Git refresh logic to coordinator |

### 4.2 Large File Splits

| Task | File | Lines | Extract To |
|------|------|-------|------------|
| Split CLIMessageView | `CLIMessageView.swift` | 692 | ToolUseView, ToolResultView, MessageActionBar |
| Split ContentView | `ContentView.swift` | 1558 | ProjectListView, SearchCoordinator |
| Split WebSocketManager | `WebSocketManager.swift` | 1112 | MessageParser, ConnectionManager |

### 4.3 Error Handling Standardization

| Pattern | Use Case |
|---------|----------|
| `ErrorStore.shared.post()` | User-facing errors (banners) |
| `throws` | Recoverable errors for callers |
| `log.error()` | Debug/diagnostic only |

---

## Phase 5: Performance & Polish

> **Priority**: Medium | **Status**: Partially Complete

### 5.1 Remaining Performance Items

| Task | File | Status |
|------|------|--------|
| Async message loading | `Models.swift` | Pending |
| Lazy image loading | `Models.swift` | Pending |

### 5.2 Code Quality Fixes

| Task | File | Status |
|------|------|--------|
| Remove force unwrap | `WebSocketManager.swift` | ✅ Complete - Uses guard-let |
| Flatten nested parsing | `WebSocketManager.swift` | Pending - Extract to typed parse functions |

### 5.3 Input Validation

| Task | Location | Status |
|------|----------|--------|
| Validate slash commands | ChatView | Pending - Sanitize /resume, /model input |
| Validate session IDs | WebSocket sends | ✅ Complete - UUID validation in attachToSession, abortSession, switchModel |

### 5.4 Accessibility ✅

| Task | Files | Status |
|------|-------|--------|
| Add accessibilityLabel | Toolbar items | ✅ Complete - Git status, search, ideas, menu |
| Add accessibilityHint | Complex controls | ✅ Complete - Describes actions |
| Add accessibilityValue | Dynamic state | ✅ Complete - Git status, ideas count |

### 5.5 Chat Scroll UX ✅

| Task | Files | Status |
|------|-------|--------|
| Scroll-to-bottom button visibility | `ChatView.swift`, `ScrollStateManager.swift` | ✅ Complete - Shows when scrolled up, hides at bottom |

---

## Phase 6: iOS 26 Adoption

> **Priority**: Medium | **Environment**: Xcode 26.2 / iOS 26.2

| Task | Files | Action |
|------|-------|--------|
| @IncrementalState | ChatView, CommandStore, IdeasStore, DebugLogStore | Replace @State arrays for list performance |
| .incrementalID() | List item views | Add to ForEach items |
| ToolbarSpacer | Various | Adopt new spacing API |
| TextEditor + AttributedString | CLIInputView | Rich text editing |

---

## Phase 7: Test Coverage

> **Priority**: Ongoing

### New Tests Required

| Test Suite | Coverage |
|------------|----------|
| Security tests | Shell escaping edge cases, command injection vectors |
| URL encoding tests | Project paths with spaces, special chars, Unicode |
| Session history tests | Multi-part content flattening, tool_use aggregation |
| Integration tests | WebSocket connection, SSH command execution |
| UI tests | SwiftUI views, accessibility |

### Run Tests
```bash
xcodebuild test -project CodingBridge.xcodeproj \
  -scheme CodingBridge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'
```

---

## Quick Reference

### File Hotspots (by issue count)

| File | Issues | Primary Concerns |
|------|--------|------------------|
| `CLIMessageView.swift` | 1 | Size (700+ lines) - extension labels ✅ |
| `APIClient.swift` | 1 | History parsing - URL encoding ✅, retry loop ✅ |
| `ChatView.swift` | 2 | @State sprawl, size - accessibility ✅ |
| `WebSocketManager.swift` | 2 | State races, parsing - force unwrap ✅, session ID validation ✅ |
| `Models.swift` | 0 | @MainActor ✅ |

### Implementation Order

```
Phase 1 (Security)     ████████████████████ COMPLETE ✅
Phase 2 (Data)              ━━━━━━━━━━━━━►
Phase 3 (Stability)              ━━━━━━━━━►
Phase 4 (Architecture)                ━━━━━━━━━━━━━━►
Phase 5 (Polish)                           ━━━━━━━━━━━━►
Phase 6 (iOS 26)                                ━━━━━━━━►
Phase 7 (Tests)        ═══════════════════════════════════►
```

---

_Last updated: December 28, 2025_
