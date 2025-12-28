# ClaudeCodeApp Implementation Plan

> Comprehensive plan for fixing all identified issues in the iOS Claude Code client.
>
> **Related docs**: [CHANGELOG.md](CHANGELOG.md) | [ISSUES.md](ISSUES.md) | [FUTURE-IDEAS.md](FUTURE-IDEAS.md)

---

## Overview

| Phase | Focus | Priority | Est. Tasks |
|-------|-------|----------|------------|
| 1 | Security Hardening | Critical | 8 |
| 2 | Data Correctness | High | 6 |
| 3 | Stability & Thread Safety | High | 5 |
| 4 | Architecture Refactoring | Medium | 7 |
| 5 | Performance & Polish | Medium | 9 |
| 6 | iOS 26 Adoption | Medium | 6 |
| 7 | Test Coverage | Ongoing | 6 |

---

## Phase 1: Security Hardening

> **Priority**: Critical | **Do First**

### 1.1 Command Injection Prevention

Shell commands interpolate unescaped user inputs, enabling command injection.

| Task | File | Line | Action |
|------|------|------|--------|
| Escape git URL | `CloneProjectSheet.swift` | 167 | Wrap URL in `shellEscape()` |
| Escape grep path | `SSHManager.swift` | 1468 | Use `shellEscape()` for project path |
| Escape shell path | `ContentView.swift` | 573 | Use `shellEscape()` for path interpolation |
| Fix bash -c expansion | `SSHManager.swift` | 1024 | Refactor `executeCommandWithTimeout` to avoid bash -c wrapper |

**Implementation**:
```swift
// Ensure all SSH commands use the existing helper:
private func shellEscape(_ string: String) -> String {
    let escaped = string.replacingOccurrences(of: "'", with: "'\\''")
    return "'\(escaped)'"
}
```

### 1.2 Credential Storage Migration

Backend credentials stored in plain text UserDefaults; must migrate to Keychain.

| Task | File | Line | Action |
|------|------|------|--------|
| Migrate authPassword | `AppSettings.swift` | 223 | Move to Keychain with migration |
| Migrate authToken | `AppSettings.swift` | 224 | Move to Keychain with migration |
| Migrate apiKey | `AppSettings.swift` | 225 | Move to Keychain with migration |
| Redact JWT in logs | `APIClient.swift` | 112 | Replace token with `[REDACTED]` |

**Implementation**: Follow the existing `sshPassword` migration pattern:
```swift
var authToken: String {
    get { KeychainHelper.shared.retrieveAuthToken() ?? "" }
    set { KeychainHelper.shared.storeAuthToken(newValue) }
}

func migrateCredentialsIfNeeded() {
    // One-time migration from UserDefaults to Keychain
}
```

### 1.3 SSH Host Key Validation

Host key verification disabled with `.acceptAnything()`, enabling MITM attacks.

| Task | File | Lines | Action |
|------|------|-------|--------|
| Add host key validation | `SSHManager.swift` | 780, 821 | Implement known-hosts or trust-on-first-use |

**Implementation Options**:
1. **Trust-on-first-use (TOFU)**: Store fingerprint in Keychain on first connect, verify on subsequent
2. **Known hosts file**: Read/write `~/.ssh/known_hosts` format
3. **User prompt**: Show fingerprint dialog on first connect

---

## Phase 2: Data Correctness

> **Priority**: High

### 2.1 API URL Encoding

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

### 2.2 Session History Completeness

Session history parsing returns on first content item, dropping multi-part messages.

| Task | File | Lines | Action |
|------|------|-------|--------|
| Aggregate content parts | `APIClient.swift` | 334, 338 | Collect all text/tool_use items instead of returning on first |
| Handle tool_use in history | `APIClient.swift` | 350-354 | Emit separate ChatMessage for each tool_use |

### 2.3 Session History Fallback

When API fails, no fallback to SSH-based history loading.

| Task | File | Lines | Action |
|------|------|-------|--------|
| Add SSH fallback | `ChatView.swift` | 1196, 1228 | Try SSH history load when API returns error |
| Surface error state | `ChatView.swift` | - | Show clear error when both methods fail |

### 2.4 Auth Retry Handling

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
| Split ContentView | `ContentView.swift` | 1558 | ProjectListView, SearchCoordinator |
| Split SSHManager | `SSHManager.swift` | 1593 | FileOperations, GitOperations |
| Split WebSocketManager | `WebSocketManager.swift` | 1112 | MessageParser, ConnectionManager |

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

> **Priority**: Medium

### 5.1 Async File IO

| Task | File | Lines | Action |
|------|------|-------|--------|
| Async message loading | `Models.swift` | 546 | Move file read to background |
| Lazy image loading | `Models.swift` | 569 | Load image data on-demand |

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
xcodebuild test -project ClaudeCodeApp.xcodeproj \
  -scheme ClaudeCodeApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'
```

---

## Recently Fixed

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

| File | Issues | Primary Concerns |
|------|--------|------------------|
| `AppSettings.swift` | 4 | Credential storage, @MainActor |
| `SSHManager.swift` | 4 | Shell escaping, host validation, bash -c |
| `APIClient.swift` | 4 | URL encoding, history parsing, retry loop, log redaction |
| `ChatView.swift` | 3 | @State sprawl, size, SSH fallback |
| `WebSocketManager.swift` | 3 | State races, parsing, force unwrap |
| `Models.swift` | 2 | @MainActor, sync IO |

### Implementation Order

```
Phase 1 (Security)     ━━━━━━━━━━━━━━━━━►
Phase 2 (Data)              ━━━━━━━━━━━━━━►
Phase 3 (Stability)              ━━━━━━━━━━►
Phase 4 (Architecture)                ━━━━━━━━━━━━━━━━━━►
Phase 5 (Polish)                           ━━━━━━━━━━━━━━━━━►
Phase 6 (iOS 26)                                ━━━━━━━━━━━━━►
Phase 7 (Tests)        ════════════════════════════════════════════►
```

---

_Last updated: December 27, 2025_
