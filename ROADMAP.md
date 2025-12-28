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
| 3 | Stability & Thread Safety | High | Pending |
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

> **Priority**: High

### 2.1 Read Tool File Extension Labels

Session analysis shows Read dominates at 40% of tool usage. Add file extension context to headers.

| Task | File | Action |
|------|------|--------|
| Add extension labels | `CLIMessageView.swift` | Show language name in Read header (Swift, TypeScript, etc.) |

### 2.2 API URL Encoding

API paths built with raw strings fail for project names with spaces/special characters.

| Task | File | Action |
|------|------|--------|
| Encode session path | `APIClient.swift` | Use `addingPercentEncoding(withAllowedCharacters:)` |
| Encode token path | `APIClient.swift` | Use `addingPercentEncoding(withAllowedCharacters:)` |

### 2.3 Session History Completeness

Session history parsing returns on first content item, dropping multi-part messages.

| Task | File | Action |
|------|------|--------|
| Aggregate content parts | `APIClient.swift` | Collect all text/tool_use items instead of returning on first |

### 2.4 Auth Retry Handling

Recursive `fetchProjects()` after `login()` with no retry cap risks infinite loops.

| Task | File | Action |
|------|------|--------|
| Add retry limit | `APIClient.swift` | Add `retryCount` parameter, max 1 retry |

---

## Phase 3: Stability & Thread Safety

> **Priority**: High

### 3.1 @MainActor Annotations

ObservableObject classes missing @MainActor can cause cross-thread crashes.

| Task | File | Action |
|------|------|--------|
| Add @MainActor to BookmarkStore | `Models.swift` | Add annotation, audit callers |
| Add @MainActor to AppSettings | `AppSettings.swift` | Add annotation, audit callers |

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

| Task | File | Action |
|------|------|--------|
| Remove force unwrap | `WebSocketManager.swift` | Use guard-let binding |
| Flatten nested parsing | `WebSocketManager.swift` | Extract to typed parse functions |

### 5.3 Input Validation

| Task | Location | Action |
|------|----------|--------|
| Validate slash commands | ChatView | Sanitize /resume, /model input |
| Validate session IDs | WebSocket sends | Check UUID format before send |

### 5.4 Accessibility

| Task | Files | Action |
|------|-------|--------|
| Add accessibilityLabel | Toolbar items | All interactive elements |
| Add accessibilityHint | Complex controls | Describe actions |

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
| `CLIMessageView.swift` | 2 | Extension labels, size (692 lines) |
| `APIClient.swift` | 3 | URL encoding, history parsing, retry loop |
| `ChatView.swift` | 3 | @State sprawl, size |
| `WebSocketManager.swift` | 3 | State races, parsing, force unwrap |
| `Models.swift` | 1 | @MainActor |

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
