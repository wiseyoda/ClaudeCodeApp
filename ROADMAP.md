# CodingBridge Roadmap

> Implementation plan for the iOS Claude Code client.
>
> **Related docs**: [CHANGELOG.md](CHANGELOG.md) | [ISSUES.md](ISSUES.md) | [FUTURE-IDEAS.md](FUTURE-IDEAS.md)
>
> **Active Projects**: [requirements/projects/](requirements/projects/) - In-progress feature implementations

---

## Overview

| Phase | Focus | Priority | Status |
|-------|-------|----------|--------|
| 1 | Security Hardening | Critical | Complete |
| 2 | Data Correctness | High | Complete |
| 3 | Stability & Thread Safety | High | Complete |
| 4 | Architecture Refactoring | Medium | Complete |
| 5 | Performance & Polish | Medium | Complete |
| 6 | iOS 26 Adoption | Medium | Complete |
| 7 | Test Coverage | Ongoing | In Progress |

---

## Completed: v0.6.7 History Hardening & Codebase Audit

### History Hardening iOS Implementation
- `lastMessageId` reconnect - Resume from last known message on reconnection
- Error types - Distinct `CLIBridgeError` cases for different failure modes
- Message deduplication - Prevent duplicate messages via ID tracking
- REST API format - Proper structured content parsing from export fallback
- Rate limiting awareness - Handle 429 responses with Retry-After support
- Message validation - Validate message structure before processing
- Cursor persistence - Track session position across app restarts

### Chat Scroll Performance
- Migrated from ScrollView to List for cell recycling
- Fixed UICollectionView crash by delaying scroll after List renders
- Use stable IDs for status messages to fix collection counts mismatch
- Fixed duplicate messages in export API fallback path

### Codebase Audit Fixes
- Replaced duplicate `AnyCodable` struct with `typealias AnyCodable = AnyCodableValue`
- Created shared `CLIDateFormatter` enum replacing 9 duplicate formatter declarations
- Added explicit request timeouts to `CLIBridgeAPIClient` (30s request, 120s resource)
- Extended retry logic with exponential backoff for rate limiting and server errors
- Replaced force unwraps in multipart form data with safe `Data(string.utf8)`
- Converted SSHKeyDetection print() statements to Logger
- Fixed 4 compiler warnings (CLIBridgeTypes, ChatViewModel, LiveActivityManager, CodingBridgeApp)

---

## Completed: v0.6.5 Session Management Enhancements

- Session search with debounced full-text search and match snippets
- Session archive/unarchive with soft delete and recovery
- Session count API with user/agent/helper breakdown
- Bulk session operations (archive, unarchive, delete, update)
- Session lineage tracking (parent-child relationships)
- Extended `CLISessionMetadata` with `archivedAt` and `parentSessionId`
- `SessionRepository` protocol extended with 5 new methods

## Completed: v0.6.4 Cache-First Startup

- Extended `ProjectCache` with session counts and recent sessions caching
- UI renders from cache in <1ms, background tasks refresh data without blocking
- Fixed project card title priority, context menu animation, and settings decoder

## Completed: v0.6.3 ChatViewModel Extraction

- `ChatView.swift` reduced from 2288 to 695 lines (70% reduction)
- Comprehensive keyboard lag elimination
- Static shared formatters, optimized message onChange

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

> **Priority**: Medium | **Status**: Complete

### 4.1 ChatView Decomposition
~~ChatView has 25+ @State properties and ~1968 lines.~~

| Task | Files | Status |
|------|-------|--------|
| Extract ChatViewModel | `ChatViewModel.swift` | Complete - 2288→695 lines (70% reduction) |
| Extract ChatSearchView | `SearchFilterViews.swift` | Complete - ChatSearchBar, FilterChip, SearchResultCount |
| Extract ChatToolbar | `ChatToolbar.swift` | Complete - ChatTitleView, ChatToolbarActions |
| Extract GitStatusCoordinator | `GitStatusCoordinator.swift` | Complete - git status coordination |

### 4.2 Large File Splits

| Task | File | Lines | Extract To | Status |
|------|------|-------|------------|--------|
| Split CLIMessageView | `CLIMessageView.swift` | 1174→654 | ToolParser.swift, ToolContentView.swift | Complete (44% reduction) |
| Split ContentView | `ContentView.swift` | ~1080→591 | GitStatusCoordinator.swift, ProjectSidebarContent.swift | Complete (45% reduction) |

### 4.3 Error Handling Standardization

| Pattern | Use Case |
|---------|----------|
| `ErrorStore.shared.post()` | User-facing errors (banners) |
| `throws` | Recoverable errors for callers |
| `log.error()` | Debug/diagnostic only |

| Task | File | Status |
|------|------|--------|
| ErrorStore + ErrorBanner infrastructure | `ErrorStore.swift`, `ErrorBanner.swift` | Complete |
| AppError enum with icons/recovery | `AppError.swift` | Complete |
| ConnectionError → AppError mapping | `ChatViewModel.swift` | Complete - `mapConnectionError()` |
| Post connection errors to ErrorStore | `ChatViewModel.swift` | Complete - `onConnectionError` handler |
| SSH errors follow throws pattern | `SSHManager.swift` | Complete - Errors thrown to callers |

---

## Phase 5: Performance & Polish

> **Priority**: Medium | **Status**: Complete

### 5.1 Remaining Performance Items

| Task | File | Status |
|------|------|--------|
| Async message loading | `Models.swift` | Complete - Uses `withCheckedContinuation` on fileQueue |
| Lazy image loading | `Models.swift`, `CLIMessageView.swift` | Complete - `LazyMessageImage` loads on scroll |
| Message array pruning | `ChatViewModel.swift` | Complete - Prunes during streaming to historyLimit |
| Display cache optimization | `ChatViewModel.swift` | Complete - Cached groupedDisplayItems |
| Avoid nested ObservableObject | `ChatViewModel.swift` | Complete - WebSocket state accessors |
| Cleanup after processing complete | `ChatViewModel.swift` | Complete - Clears tasks/maps on onComplete |
| Stop health polling on disappear | `ChatViewModel.swift` | Complete - Stops HealthMonitorService |
| Clear callbacks on disconnect | `CLIBridgeManager.swift` | Complete - Breaks retain cycles |
| Cancel textFlushTask properly | `CLIBridgeManager.swift` | Complete - Cleared on clearCurrentText |
| Optimize messages onChange | `ChatView.swift` | Complete - Changed from O(n) array to O(1) count comparison |
| Isolate status indicator dot | `CLIStatusBarViews.swift` | Complete - HealthMonitorService observed in isolated subview |
| Remove CLIInputView singleton observation | `CLIInputView.swift` | Complete - Removed CommandStore @ObservedObject |
| Cache DateFormatter instances | Multiple files | Complete - Static shared formatters instead of creating on every call |
| Cache timestamp strings in init | `CLIMessageView.swift` | Complete - Cached + static format for old (>1hr) messages |

### 5.2 Input Validation

| Task | Location | Status |
|------|----------|--------|
| Validate slash commands | ChatViewModel | Complete - `/model` validates model names, `/resume` validates UUID format |
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

## Completed: v0.6.6 iOS 26 Adoption

iOS 26 SwiftUI features adopted for improved performance and modern design:

- Migrated CommandStore, IdeasStore, DebugLogStore to `@Observable` with `@IncrementalState`
- Added `.incrementalID()` to ForEach views for fine-grained list updates
- Adopted `ToolbarSpacer` for Liquid Glass toolbar design in ContentView (iPad)
- Implemented rich text input with `TextEditor` + `AttributedString` in CLIInputView
  - Syntax highlighting for @file references, inline code, and slash commands
  - Bidirectional sync between AttributedString and plain text binding

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
| `ChatView.swift` | 0 | @State sprawl addressed via ChatViewModel extraction |
| `CLIBridgeManager.swift` | 0 | Clean state management |
| `Models.swift` | 0 | @MainActor complete, lazy image loading |

### Implementation Order

```
Phase 1 (Security)          COMPLETE
Phase 2 (Data)              COMPLETE
Phase 3 (Stability)         COMPLETE
Phase 4 (Architecture)      COMPLETE
Phase 5 (Polish)            COMPLETE
Phase 6 (iOS 26)            COMPLETE
Phase 7 (Tests)        =========================================>
```

---

_Last updated: January 1, 2026 - v0.6.7 History Hardening & Codebase Audit complete_
