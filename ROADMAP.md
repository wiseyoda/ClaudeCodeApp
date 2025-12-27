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

---

## Recently Completed (v1.4.0)

Critical bug fixes from CLAUDE.md "Known Issues" table:

| Issue | Location | Fix |
|-------|----------|-----|
| WebSocket state race | `WebSocketManager.swift` | Connection state set only after first successful receive |
| Missing @MainActor | `APIClient.swift`, `BookmarkStore` | Added `@MainActor` to class declarations |
| SpeechManager no deinit | `SpeechManager.swift` | Added proper `deinit` with resource cleanup |
| SSH password in UserDefaults | `AppSettings.swift` | Migrated to Keychain via `KeychainHelper` |
| Command injection | `SSHManager.swift` | Added `shellEscape()` function, used in all path-handling functions |

---

## Priority 1: User-Requested Features

Features requested by users (from ISSUES.md).

### High Priority

| # | Feature | Description | Effort | Status |
|---|---------|-------------|--------|--------|
| 4 | **Message action bar** | Bottom bar with copy, time, tokens, analyze button | Medium | |
| 7 | **Verbose output log** | Debug mode for raw WebSocket messages | Medium | |

### Medium Priority

| # | Feature | Description | Effort | Status |
|---|---------|-------------|--------|--------|
| 8 | **Quick-access mode toggles** | Restore chips for mode/thinking in status bar | Low | Done |
| 11 | **Auto-refresh git status** | Periodic + post-task git status refresh | Low | |
| 12 | **Quick commit & push button** | Button in pending changes banner to commit+push | Low | Done |

---

### Feature #4: Message Action Bar

**Requested behavior:** Bottom bar on assistant messages with:
- Copy all button (moved from top)
- Execution time for the task
- Token usage for that message
- "Analyze" button (sends to Haiku for follow-up suggestion)

```swift
// Views/MessageActionBar.swift
struct MessageActionBar: View {
    let message: ChatMessage
    let executionTime: TimeInterval?
    let tokenCount: Int?
    let onCopy: () -> Void
    let onAnalyze: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            if let time = executionTime {
                Label(time.formatted, systemImage: "clock")
            }
            if let tokens = tokenCount {
                Label("\(tokens) tokens", systemImage: "number")
            }
            Spacer()
            Button { onAnalyze() } label: {
                Label("Analyze", systemImage: "sparkles")
            }
            Button { onCopy() } label: {
                Image(systemName: "doc.on.doc")
            }
        }
    }
}
```

**Requirements:**
- Track message start/end times in `WebSocketManager`
- Parse token usage per message from backend response
- Integrate with `ClaudeHelper` for analyze feature

**Files to modify:** Create `Views/MessageActionBar.swift`, modify `CLIMessageView.swift`, `WebSocketManager.swift`

---

### Feature #7: Verbose Output Log

**Purpose:** Debug parsing issues by viewing raw WebSocket messages

```swift
// DebugLogStore.swift
@MainActor
class DebugLogStore: ObservableObject {
    static let shared = DebugLogStore()
    @Published var logs: [DebugLogEntry] = []
    var isEnabled: Bool = false

    func log(_ message: String, type: LogType) {
        guard isEnabled else { return }
        logs.append(DebugLogEntry(timestamp: Date(), message: message, type: type))
    }
}

// Views/DebugLogView.swift
struct DebugLogView: View {
    @ObservedObject var store = DebugLogStore.shared
    // Filterable, searchable log viewer
}
```

**Integration points:**
- `WebSocketManager.swift` - Log all incoming/outgoing messages
- Settings - Add "Enable Debug Logging" toggle
- Add "View Debug Log" option in settings or dev menu

**Files to create:** `DebugLogStore.swift`, `Views/DebugLogView.swift`
**Files to modify:** `WebSocketManager.swift`, `AppSettings.swift`, settings UI

---

### Feature #11: Auto-Refresh Git Status

```swift
// ChatView.swift - Add periodic refresh
@State private var gitRefreshTimer: Timer?

.onAppear {
    gitRefreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
        refreshGitStatus()
    }
}

.onDisappear {
    gitRefreshTimer?.invalidate()
}

// Also refresh after task completion
wsManager.onComplete = { _ in
    refreshGitStatus()
}
```

**Files to modify:** `ChatView.swift`

---

## Priority 2: Code Quality

Developer experience and code health improvements.

| Feature | Description | Effort | Status |
|---------|-------------|--------|--------|
| **Configurable History** | Make 50-message limit configurable (25, 50, 100, 200) | Low | |
| **Error UI Component** | Centralized error display component | Medium | |
| **Structured Logging** | Consistent Logger usage across all managers | Low | |
| **Unit Test Coverage** | Expand tests for managers (WebSocket, SSH, Speech) | Medium | |

---

## Implementation Order

```
Phase 1: User-Requested Features (P1) - Current
[x] #8 Quick-access mode toggles in status bar      [Low effort] DONE
[x] #12 Quick commit & push button                  [Low effort] DONE
+-- #11 Auto-refresh git status                     [Low effort]
+-- #4 Message action bar (time, tokens, analyze)   [Medium effort]
+-- #7 Verbose output log for debugging             [Medium effort]

Phase 2: Code Quality (P2) - Next
+-- Configurable history limit                      [Low effort]
+-- Structured logging                              [Low effort]
+-- Error UI component                              [Medium effort]
+-- Unit test coverage                              [Medium effort]
```

---

*Last updated: December 27, 2025 - Reorganized to focus on committed work*
