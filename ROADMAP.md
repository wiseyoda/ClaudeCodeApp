# CodingBridge Roadmap

> Implementation plan for the iOS Claude Code client.
>
> **Related docs**: [CHANGELOG.md](CHANGELOG.md) | [ISSUES.md](ISSUES.md) | [FUTURE-IDEAS.md](FUTURE-IDEAS.md)

---

## Overview

| Phase | Focus | Priority | Status |
|-------|-------|----------|--------|
| 1 | Security Hardening | Critical | Complete |
| 2 | Data Correctness | High | Complete |
| 3 | Stability & Thread Safety | High | Complete |
| 4 | Architecture Refactoring | Medium | In Progress |
| 5 | Performance & Polish | Medium | Partial |
| 6 | iOS 26 Adoption | Medium | Pending |
| 7 | Test Coverage | Ongoing | Pending |

---

## Completed: v0.6.0 cli-bridge Migration

Full migration from WebSocket to cli-bridge REST API with SSE streaming:

- New architecture: `CLIBridgeManager`, `CLIBridgeAdapter`, `CLIBridgeAPIClient`, `CLIBridgeTypes`
- Removed: `WebSocketManager.swift` (1,363 lines), `APIClient.swift` (608 lines)
- Net reduction of ~9,000 lines through consolidation
- Simplified connection state management
- All requirements docs updated

---

## Phase 2: Data Correctness

> **Priority**: High | **Status**: Complete

### 2.1 Read Tool File Extension Labels
Session analysis shows Read dominates at 40% of tool usage. Add file extension context to headers.

| Task | File | Status |
|------|------|--------|
| Add extension labels | `CLIMessageView.swift` | Complete - Shows language name (Swift, TypeScript, etc.) |

### 2.2 API URL Encoding
API paths built with raw strings fail for project names with spaces/special characters.

| Task | File | Status |
|------|------|--------|
| Encode session path | `CLIBridgeAPIClient.swift` | Complete - Uses `addingPercentEncoding` |
| Encode token path | `CLIBridgeAPIClient.swift` | Complete - Uses `addingPercentEncoding` |

### 2.3 Auth Retry Handling
Recursive `fetchProjects()` after `login()` with no retry cap risks infinite loops.

| Task | File | Status |
|------|------|--------|
| Add retry limit | `CLIBridgeAPIClient.swift` | Complete - `retryCount` parameter, max 1 retry |

---

## Phase 3: Stability & Thread Safety

> **Priority**: High | **Status**: Complete

### 3.1 @MainActor Annotations
ObservableObject classes missing @MainActor can cause cross-thread crashes.

| Task | File | Status |
|------|------|--------|
| Add @MainActor to BookmarkStore | `Models.swift` | Complete - Already present |
| Add @MainActor to AppSettings | `AppSettings.swift` | Complete - Added annotation |

### 3.2 CLI Bridge State Management
Connection state handled via `ConnectionState` enum with clear transitions.

| Task | File | Status |
|------|------|--------|
| State management | `CLIBridgeManager.swift` | Complete - Uses enum with clear states |
| Guard message sends | `CLIBridgeAdapter.swift` | Complete - Validates before send |

### 3.3 SSH Command Serialization
~~Citadel SSH library doesn't handle concurrent commands reliably.~~

| Task | File | Status |
|------|------|--------|
| Serialize git status checks | `ContentView.swift` | N/A - SSH removed, git status via cli-bridge API |

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
| Split ContentView | `ContentView.swift` | ~1000 | ProjectListView, SearchCoordinator |

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

### 5.2 Input Validation

| Task | Location | Status |
|------|----------|--------|
| Validate slash commands | ChatView | Pending - Sanitize /resume, /model input |
| Validate session IDs | API sends | Complete - UUID validation |

### 5.3 Accessibility

| Task | Files | Status |
|------|-------|--------|
| Add accessibilityLabel | Toolbar items | Complete - Git status, search, ideas, menu |
| Add accessibilityHint | Complex controls | Complete - Describes actions |
| Add accessibilityValue | Dynamic state | Complete - Git status, ideas count |

### 5.4 Chat Scroll UX

| Task | Files | Status |
|------|-------|--------|
| Scroll-to-bottom button visibility | `ChatView.swift`, `ScrollStateManager.swift` | Complete - Shows when scrolled up, hides at bottom |

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
| CLI Bridge tests | SSE parsing, connection state, error handling |
| Integration tests | API endpoints, cli-bridge REST calls |
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
| `CLIMessageView.swift` | 0 | Size (700+ lines) - extension labels complete |
| `CLIBridgeAPIClient.swift` | 0 | URL encoding complete, retry loop complete |
| `ChatView.swift` | 1 | @State sprawl, size - accessibility complete |
| `CLIBridgeManager.swift` | 0 | Clean state management |
| `Models.swift` | 0 | @MainActor complete |

### Implementation Order

```
Phase 1 (Security)          COMPLETE
Phase 2 (Data)              COMPLETE
Phase 3 (Stability)         COMPLETE
Phase 4 (Architecture)           --------->
Phase 5 (Polish)                      --------->
Phase 6 (iOS 26)                           --------->
Phase 7 (Tests)        =========================================>
```

---

_Last updated: December 30, 2025_
