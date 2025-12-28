# CodingBridge Implementation Plan

> Comprehensive plan for fixing all identified issues in the iOS Claude Code client.
>
> **Related docs**: [CHANGELOG.md](CHANGELOG.md) | [ISSUES.md](ISSUES.md) | [FUTURE-IDEAS.md](FUTURE-IDEAS.md)

---

## Overview

| Phase | Focus | Priority | Status |
|-------|-------|----------|--------|
| 1 | Security Hardening | Critical | ✅ Complete |
| 2 | Data Correctness | High | Pending |
| 3 | Stability & Thread Safety | High | Pending |
| 4 | Architecture Refactoring | Medium | Pending |
| 5 | Performance & Polish | Medium | Pending |
| 6 | iOS 26 Adoption | Medium | In Progress |
| 7 | Test Coverage | Ongoing | Pending |

---

## Phase 1: Security Hardening ✅

> **Priority**: Critical | **Status**: Complete (verified December 28, 2025)

### 1.1 Command Injection Prevention ✅

All shell commands now use `shellEscape()` for user inputs.

| Task | File | Line | Status |
|------|------|------|--------|
| Escape git URL | `CloneProjectSheet.swift` | 167 | ✅ `shellEscape(gitURL)` |
| Escape grep path | `SSHManager.swift` | 1850 | ✅ `shellEscape(encodedPath)` |
| Escape shell path | `ContentView.swift` | 569 | ✅ `shellEscape(encodedPath)` |
| Fix bash -c expansion | `SSHManager.swift` | 1402 | ✅ `escapeCommandForBash(command)` |

**Implementation** (in `SSHManager.swift`):
```swift
func shellEscape(_ string: String) -> String {
    let escaped = string.replacingOccurrences(of: "'", with: "'\\''")
    return "'\(escaped)'"
}

private func escapeCommandForBash(_ command: String) -> String {
    return command.replacingOccurrences(of: "'", with: "'\\''")
}
```

### 1.2 Credential Storage Migration ✅

All credentials migrated from UserDefaults to Keychain with automatic migration.

| Task | File | Lines | Status |
|------|------|-------|--------|
| Migrate authPassword | `AppSettings.swift` | 322-335 | ✅ `KeychainHelper.shared` |
| Migrate authToken | `AppSettings.swift` | 338-351 | ✅ `KeychainHelper.shared` |
| Migrate apiKey | `AppSettings.swift` | 354-367 | ✅ `KeychainHelper.shared` |
| Redact JWT in logs | `APIClient.swift` | 116-123 | ✅ `"Bearer [REDACTED]"` |
| Migration function | `AppSettings.swift` | 370-397 | ✅ `migrateAuthCredentialsIfNeeded()` |

### 1.3 SSH Host Key Validation ✅

Implemented Trust-On-First-Use (TOFU) with Keychain storage.

| Task | File | Lines | Status |
|------|------|-------|--------|
| TOFU Validator class | `SSHManager.swift` | 507-562 | ✅ `TOFUHostKeyValidator` |
| Key auth uses TOFU | `SSHManager.swift` | 1159-1164 | ✅ Verified |
| Password auth uses TOFU | `SSHManager.swift` | 1201-1206 | ✅ Verified |
| Keychain fingerprint storage | `SSHManager.swift` | 420-486 | ✅ Store/retrieve/delete |
| Mismatch detection | `SSHManager.swift` | 530-538 | ✅ `SSHHostKeyError.mismatch` |

**Implementation**: TOFU stores SHA-256 fingerprint on first connect, verifies on subsequent connections. Mismatch throws error to prevent MITM attacks.

---

## Phase 2: Data Correctness

> **Priority**: High

### 2.1 Handle Linter Conflict Errors - DONE

Session analysis found 13 occurrences of "File has been modified since read, either by a linter" errors that confuse users.

| Task | File | Status |
|------|------|--------|
| Tool error classification | `ToolErrorClassification.swift` | **Done** - ToolErrorCategory enum with 12 error types |
| Error pattern detection | `ToolResultParser.swift` | **Done** - Pattern matching for file conflicts, timeouts, etc. |
| Error analytics tracking | `ErrorAnalyticsStore.swift` | **Done** - Tracks errors over time with trend detection |
| Error insights UI | `ErrorInsightsView.swift` | **Done** - Visual dashboard for error patterns |
| Semantic error badges | `CLIMessageView.swift` | **Done** - Category-specific icons and colors |

**New Error Categories** (in `ToolErrorClassification.swift`):
- `success`, `gitError`, `commandFailed`, `sshError`
- `invalidArgs`, `commandNotFound`, `fileConflict`, `fileNotFound`
- `approvalRequired`, `timeout`, `permissionDenied`, `unknown`

Each category has:
- Icon, color, short label, full description
- Suggested action for user
- `isTransient` flag for retry logic

### 2.2 Read Tool File Extension Labels

Session analysis shows Read dominates at 40% of tool usage. Add file extension context to headers.

| Task | File | Action |
|------|------|--------|
| Add extension labels | `CLIMessageView.swift` | Show language name in Read header (Swift, TypeScript, etc.) |

**Implementation**:
```swift
private func fileExtensionName(_ ext: String) -> String {
    switch ext {
    case "swift": return "Swift"
    case "ts", "tsx": return "TypeScript"
    case "js", "jsx": return "JavaScript"
    case "py": return "Python"
    case "md": return "Markdown"
    case "json": return "JSON"
    case "yaml", "yml": return "YAML"
    default: return ""
    }
}
```

### 2.3 API URL Encoding

API paths built with raw strings fail for project names with spaces/special characters.

| Task | File | Lines | Action |
|------|------|-------|--------|
| Encode session path | `APIClient.swift` | 165 | Use `addingPercentEncoding(withAllowedCharacters:)` |
| Encode token path | `APIClient.swift` | 208 | Use `addingPercentEncoding(withAllowedCharacters:)` |

**Implementation**:
```swift
let encodedProject = projectName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? projectName
let encodedSession = sessionId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? sessionId
components.path = "/api/projects/\(encodedProject)/sessions/\(encodedSession)/messages"
```

### 2.4 Session History Completeness

Session history parsing returns on first content item, dropping multi-part messages.

| Task | File | Lines | Action |
|------|------|-------|--------|
| Aggregate content parts | `APIClient.swift` | 334, 338 | Collect all text/tool_use items instead of returning on first |
| Handle tool_use in history | `APIClient.swift` | 350-354 | Emit separate ChatMessage for each tool_use |

### 2.5 Session History Fallback

When API fails, no fallback to SSH-based history loading.

| Task | File | Lines | Action |
|------|------|-------|--------|
| Add SSH fallback | `ChatView.swift` | 1196, 1228 | Try SSH history load when API returns error |
| Surface error state | `ChatView.swift` | - | Show clear error when both methods fail |

### 2.6 Auth Retry Handling

Recursive `fetchProjects()` after `login()` with no retry cap risks infinite loops.

| Task | File | Lines | Action |
|------|------|-------|--------|
| Add retry limit | `APIClient.swift` | 122, 126 | Add `retryCount` parameter, max 1 retry |

**Implementation**:
```swift
func fetchProjects(retryCount: Int = 0) async throws -> [Project] {
    // ...
    if httpResponse.statusCode == 401 && retryCount < 1 {
        try await login()
        return try await fetchProjects(retryCount: retryCount + 1)
    }
    // ...
}
```

---

## Phase 3: Stability & Thread Safety

> **Priority**: High

### 3.1 @MainActor Annotations

ObservableObject classes missing @MainActor can cause cross-thread crashes.

| Task | File | Line | Action |
|------|------|------|--------|
| Add @MainActor to BookmarkStore | `Models.swift` | 819 | Add annotation, audit callers |
| Add @MainActor to AppSettings | `AppSettings.swift` | 191 | Add annotation, audit callers |

### 3.2 WebSocket State Machine

Connection state transitions can race between ping/receive callbacks.

| Task | File | Lines | Action |
|------|------|-------|--------|
| Serialize state transitions | `WebSocketManager.swift` | 269-332 | Use actor or serial queue for state |
| Guard message sends | `WebSocketManager.swift` | 405-423 | Ensure connection fully established before send |

**Implementation Option**: Extract to actor
```swift
actor WebSocketState {
    private(set) var connectionState: ConnectionState = .disconnected

    func transition(to newState: ConnectionState) -> Bool {
        // Validate transition is legal
        connectionState = newState
        return true
    }
}
```

### 3.3 SSH Command Serialization

Citadel SSH library doesn't handle concurrent commands reliably.

| Task | File | Lines | Action |
|------|------|-------|--------|
| Serialize git status checks | `ContentView.swift` | 612 | Use async queue or sequential execution |
| Serialize multi-project SSH | `SSHManager.swift` | 1281 | Already fixed, verify consistency |

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
| Split SSHManager | `SSHManager.swift` | 1593 | FileOperations, GitOperations |
| Split WebSocketManager | `WebSocketManager.swift` | 1112 | MessageParser, ConnectionManager |

**Note**: Session analysis identified CLIMessageView as growing complex at 692 lines. Consider extracting specialized views for different tool types.

### 4.3 Error Handling Standardization

Multiple error patterns coexist; standardize on:

| Pattern | Use Case |
|---------|----------|
| `ErrorStore.shared.post()` | User-facing errors (banners) |
| `throws` | Recoverable errors for callers |
| `log.error()` | Debug/diagnostic only |

**Remove**: Duplicate `lastError` + `onError?()` callback patterns.

---

## Phase 5: Performance & Polish

> **Priority**: Medium | **Status**: Partially Complete

### 5.1 Async File IO

| Task | File | Lines | Status |
|------|------|-------|--------|
| Async message loading | `Models.swift` | 546 | Pending |
| Lazy image loading | `Models.swift` | 569 | Pending |
| Background bookmark I/O | `Models.swift` | BookmarkStore | **Done** - Uses fileQueue |
| Background command I/O | `CommandStore.swift` | load/save | **Done** - Uses fileQueue |
| Background ideas I/O | `IdeasStore.swift` | load/save | **Done** - Uses fileQueue |
| Background settings I/O | `ProjectSettingsStore.swift` | load/save | **Done** - Uses fileQueue |

### 5.1.1 Streaming Performance (NEW)

| Task | File | Status |
|------|------|--------|
| Debounced text buffer | `WebSocketManager.swift` | **Done** - 50ms debounce reduces view updates |
| Background JSON decoding | `WebSocketManager.swift` | **Done** - Decode on background thread |
| Cached display messages | `ChatView.swift` | **Done** - Avoids recomputation during scrolling |
| Stable streaming message ID | `ChatView.swift` | **Done** - Prevents view thrashing |
| Cached CLIMessageView values | `CLIMessageView.swift` | **Done** - Pre-compute in init |
| Cached MarkdownText blocks | `MarkdownText.swift` | **Done** - Parse only when content changes |
| Cached DiffView lines | `DiffView.swift` | **Done** - Compute once on appear |

### 5.1.2 Startup Performance (NEW)

| Task | File | Status |
|------|------|--------|
| Project cache for instant startup | `ProjectCache.swift` | **Done** - Cache-first loading |
| Skeleton loading UI | `SkeletonView.swift` | **Done** - Shimmer placeholders |
| Progressive git status loading | `ContentView.swift` | **Done** - Updates UI as each status arrives |
| Debounced scroll handling | `ScrollStateManager.swift` | **Done** - Prevents UI freeze during scrolling |

### 5.2 Timeout Handling

| Task | File | Line | Action |
|------|------|------|--------|
| Cancel stale timeouts | `ClaudeHelper.swift` | 516 | Cancel prior task before new query |
| Centralize timeout constants | Various | - | Create `Timeouts` enum |

```swift
enum Timeouts {
    static let abort: TimeInterval = 3.0
    static let modelSwitch: TimeInterval = 5.0
    static let processing: TimeInterval = 300.0
    static let claudeHelper: TimeInterval = 15.0
}
```

### 5.3 Code Quality Fixes

| Task | File | Line | Action |
|------|------|------|--------|
| Remove force unwrap | `WebSocketManager.swift` | 986 | Use guard-let binding |
| Flatten nested parsing | `WebSocketManager.swift` | 1042-1098 | Extract to typed parse functions |
| Deduplicate session validation | Multiple | - | Single `SessionIdValidator` utility |

### 5.4 Input Validation

| Task | Location | Action |
|------|----------|--------|
| Validate slash commands | ChatView | Sanitize /resume, /model input |
| Validate session IDs | WebSocket sends | Check UUID format before send |

### 5.5 Accessibility

| Task | Files | Action |
|------|-------|--------|
| Add accessibilityLabel | Toolbar items | All interactive elements |
| Add accessibilityHint | Complex controls | Describe actions |

### 5.6 Other Polish

| Task | File | Action |
|------|------|--------|
| Keyboard constraints | `ChatView.swift` | Fix input accessory layout conflicts |
| Centralized error UI | Various | Single ErrorBanner component |
| Consistent logging | Various | Use Logger across all managers |

---

## Phase 6: iOS 26 Adoption

> **Priority**: Medium | **Environment**: Xcode 26.2 / iOS 26.2

| Task | Files | Action |
|------|-------|--------|
| @IncrementalState | ChatView, CommandStore, IdeasStore, DebugLogStore | Replace @State arrays for list performance |
| .incrementalID() | List item views | Add to ForEach items |
| ToolbarSpacer | Various | Adopt new spacing API |
| TextEditor + AttributedString | CLIInputView | Rich text editing |
| @Animatable macro | Custom animations | New animation system |
| Liquid Glass styling | Navigation, toolbars | Adopt new material system |

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
| Performance tests | Message loading, large chat history |

### Run Tests
```bash
xcodebuild test -project CodingBridge.xcodeproj \
  -scheme CodingBridge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'
```

---

## Recently Fixed

### Permission Approval Banner (December 28, 2025)

| Task | File | Status |
|------|------|--------|
| ApprovalBannerView component | `Views/ApprovalBannerView.swift` | ✅ Complete |
| ApprovalRequest/Response models | `Models.swift` | ✅ Complete |
| WebSocket permission handling | `WebSocketManager.swift` | ✅ Complete |
| ChatView banner integration | `ChatView.swift` | ✅ Complete |
| Backend canUseTool callback | wiseyoda/claudecodeui fork | ✅ Complete |

**Implementation**: When bypass permissions is OFF, the backend forwards tool approval requests via WebSocket. iOS shows a banner with Approve/Always Allow/Deny buttons. Responses route through the legacy `handlePermissionResponse` handler to complete tool execution.

### UI/UX Fixes (December 27, 2025)

| Issue | File | Fix |
|-------|------|-----|
| Session scroll not working | `ChatView.swift:1285` | Added 150ms delay before scroll trigger to fix race condition |
| Status bar word wrap | `CLIStatusBarViews.swift:85-107` | Changed mode pills to icon-only display |

### Multi-Repo Support (December 27, 2025)

| Issue | File | Fix |
|-------|------|-----|
| Git submodules not detected | `SSHManager.swift:1154` | Changed `find -type d` to `find \( -type d -o -type f \)` |
| Concurrent SSH errors | `SSHManager.swift:1229-1248` | Changed to sequential execution |
| Concurrent pull errors | `SSHManager.swift:1276-1290` | Changed to sequential execution |

---

## Feature Requests

| # | Feature | Description | Priority |
|---|---------|-------------|----------|
| 18 | Multi-repo git status | Aggregate status for monorepos | Low |

---

## Quick Reference

### File Hotspots (by issue count)

| File | Issues | Primary Concerns | Security Status |
|------|--------|------------------|-----------------|
| `CLIMessageView.swift` | 3 | Linter errors, extension labels, size (692 lines) | - |
| `AppSettings.swift` | 1 | @MainActor | ✅ Credentials secured |
| `SSHManager.swift` | 0 | - | ✅ All security issues fixed |
| `APIClient.swift` | 3 | URL encoding, history parsing, retry loop | ✅ Log redaction done |
| `ChatView.swift` | 3 | @State sprawl, size, SSH fallback | - |
| `WebSocketManager.swift` | 3 | State races, parsing, force unwrap | - |
| `Models.swift` | 2 | @MainActor, sync IO | - |

### Implementation Order

```
Phase 1 (Security)     ████████████████████ COMPLETE ✅
Phase 2 (Data)              ━━━━━━━━━━━━━━►
Phase 3 (Stability)              ━━━━━━━━━━►
Phase 4 (Architecture)                ━━━━━━━━━━━━━━━━━━►
Phase 5 (Polish)                           ━━━━━━━━━━━━━━━━━►
Phase 6 (iOS 26)                                ▓▓▓▓━━━━━━━━━►
Phase 7 (Tests)        ════════════════════════════════════════════►
```

---

_Last updated: December 28, 2025 (v0.5.1 - Performance & Error Analytics)_
