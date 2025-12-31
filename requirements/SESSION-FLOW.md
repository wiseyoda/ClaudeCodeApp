# Session Management Flow Analysis

This document traces how sessions are managed in Coding Bridge, from project selection through message sending.

## Fix Status (Updated 2025-12-31)

| Issue | Description | Status | Notes |
|-------|-------------|--------|-------|
| Issue 1 | No ephemeral session for empty projects | ✅ FIXED | `ChatViewModel.onAppear()` lines 220-240 |
| Issue 2 | Double save after clearActiveSessionId | ⏭️ SKIP | Defensive coding, not a bug |
| Issue 3 | Race condition in session loading | ⏭️ SKIP | Minor edge case, needs major refactor |
| Issue 4 | All-empty-sessions case | ✅ HANDLED | Fixed by Issue 1 - ephemeral kicks in |
| Issue 5 | WebSocket debounce safety | ✅ OK | Debounce logic correctly checks `isConnected` |
| Issue 6 | Session recovery loop (CRITICAL) | ✅ FIXED | `CLIBridgeAdapter` now calls `onSessionRecovered` |
| Issue 7 | Session deduplication | ✅ OK | `addSession()` already has dedup check |
| Issue 8 | Session switch race condition | ✅ FIXED | `loadSessionHistory` now cancels previous load |
| Issue 9 | /clear and /new commands incomplete | ✅ FIXED | Now match `startNewSession()` behavior |

**Build Status:** ✅ Builds successfully
**Test Status:** ✅ All tests passing

## Table of Contents
1. [State Storage Layers](#state-storage-layers)
2. [Flow Diagrams](#flow-diagrams)
3. [Critical Paths](#critical-paths)
4. [Identified Issues](#identified-issues)
5. [Expected vs Actual Behavior](#expected-vs-actual-behavior)

---

## State Storage Layers

Session state is stored in **multiple places**, which is a source of complexity:

| Layer | Location | Purpose | Lifetime |
|-------|----------|---------|----------|
| `MessageStore.sessionId` | UserDefaults | Persist session ID across app launches | Until cleared |
| `SessionStore.activeSessionIds` | In-memory dict | Track active session per project | App session |
| `CLIBridgeAdapter.sessionId` | Published property | Current WebSocket connection | Until disconnect |
| `CLIBridgeManager.sessionId` | Published property | Server-confirmed session ID | Until disconnect |
| `ChatViewModel.selectedSession` | @Published | UI display state | View lifetime |
| `ChatViewModel.wsManager.sessionId` | Passthrough | Mirrors adapter.sessionId | View lifetime |

### Key Persistence Methods

```
SessionStore.setSelectedSession(sessionId, for: projectPath)
  ├─→ activeSessionIds[projectPath] = sessionId     (in-memory)
  └─→ MessageStore.saveSessionId(sessionId)         (UserDefaults)

SessionStore.loadActiveSessionId(for: projectPath)
  ├─→ MessageStore.loadSessionId()                  (from UserDefaults)
  └─→ activeSessionIds[projectPath] = sessionId     (populates in-memory)

SessionStore.clearActiveSessionId(for: projectPath)
  ├─→ activeSessionIds[projectPath] = nil           (in-memory)
  └─→ MessageStore.clearSessionId()                 (UserDefaults)
```

---

## Flow Diagrams

### 1. Project Selection (No Pre-Selected Session)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ HomeView: User taps project card                                             │
└─────────────────────────────────┬────────────────────────────────────────────┘
                                  │
                                  ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ ContentView.onSelectProject: { project in                                    │
│     selectedProject = project    // Just sets project, no session ID         │
│ }                                                                            │
└─────────────────────────────────┬────────────────────────────────────────────┘
                                  │
                                  ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ NavigationDestination → ChatView(project: project)                           │
└─────────────────────────────────┬────────────────────────────────────────────┘
                                  │
                                  ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ ChatView.onAppear → ChatViewModel.onAppear()                                 │
│                                                                              │
│   1. await sessionStore.loadSessions(for: project.path, forceRefresh: true)  │
│                                                                              │
│   2. selectInitialSession()                                                  │
│      ├─→ loadActiveSessionId() returns nil (no pre-selection)                │
│      └─→ autoSelectMostRecentSession()                                       │
│          └─→ selectedSession = mostRecent (if exists and has messages)       │
│              OR returns without setting (no sessions/no messages)            │
│                                                                              │
│   3. if let session = selectedSession {                                      │
│         wsManager.sessionId = session.id                                     │
│         wsManager.connect(projectPath, sessionId: session.id)                │
│         MessageStore.saveSessionId(session.id)    // PERSISTS                │
│         loadSessionHistory(session)                                          │
│      } else {                                                                │
│         // Creates ephemeral session placeholder (Issue 1 fix)               │
│         selectedSession = ephemeral("new-session-UUID")                      │
│         wsManager.connect(projectPath)    // NO sessionId - new session      │
│      }                                                                       │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 2. Recent Session Selection (From HomeView)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ HomeView.RecentActivitySection: User taps session row                        │
│     onSelectSession(session: CLISessionMetadata)                             │
└─────────────────────────────────┬────────────────────────────────────────────┘
                                  │
                                  ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ ContentView.onSelectSession: { session in                                    │
│     sessionStore.setSelectedSession(session.id, for: project.path)           │
│     ├─→ activeSessionIds[projectPath] = sessionId                            │
│     └─→ MessageStore.saveSessionId(sessionId)     // PERSISTS TO USERDEFAULTS│
│     selectedProject = project                                                │
│ }                                                                            │
└─────────────────────────────────┬────────────────────────────────────────────┘
                                  │
                                  ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ ChatView.onAppear → ChatViewModel.onAppear()                                 │
│                                                                              │
│   1. await sessionStore.loadSessions(...)                                    │
│                                                                              │
│   2. selectInitialSession()                                                  │
│      ├─→ loadActiveSessionId() returns sessionId from step above             │
│      ├─→ Find session in list OR create ephemeral ProjectSession             │
│      ├─→ selectedSession = found/ephemeral session                           │
│      └─→ clearActiveSessionId()                                              │
│          ├─→ activeSessionIds[projectPath] = nil                             │
│          └─→ MessageStore.clearSessionId()        // CLEARS USERDEFAULTS     │
│                                                                              │
│   3. wsManager.sessionId = session.id                                        │
│      wsManager.connect(projectPath, sessionId: session.id)                   │
│      MessageStore.saveSessionId(session.id)       // RE-PERSISTS!            │
│      loadSessionHistory(session)                                             │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 3. Session Picker Selection (From ChatView Toolbar)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ SessionPickerSheet: User selects session                                     │
│     onSelect: { session in viewModel.selectSession(session) }                │
└─────────────────────────────────┬────────────────────────────────────────────┘
                                  │
                                  ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ ChatViewModel.selectSession(_ session)                                       │
│                                                                              │
│   selectedSession = session                                                  │
│   wsManager.attachToSession(sessionId: session.id, projectPath: project.path)│
│   ├─→ Disconnects current WebSocket                                          │
│   └─→ Reconnects with: manager.connect(projectPath, sessionId: session.id)   │
│   MessageStore.saveSessionId(session.id)          // PERSISTS                │
│   loadSessionHistory(session)                                                │
│   ├─→ Cancels any previous historyLoadTask (Issue 8 fix)                     │
│   └─→ Checks for staleness before applying results                           │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 4. New Session Creation (From Toolbar)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ ChatToolbar: User taps "New Chat" button                                     │
│     onNewChat: viewModel.startNewSession()                                   │
└─────────────────────────────────┬────────────────────────────────────────────┘
                                  │
                                  ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ ChatViewModel.startNewSession()                                              │
│                                                                              │
│   messages = []                                                              │
│   MessageStore.clearMessages(for: project.path)                              │
│   MessageStore.clearSessionId(for: project.path)   // CLEAR PERSISTENCE      │
│   sessionStore.clearActiveSessionId(for: project.path)                       │
│                                                                              │
│   selectedSession = ephemeral("new-session-UUID") // PLACEHOLDER             │
│                                                                              │
│   wsManager.disconnect()                                                     │
│   wsManager.sessionId = nil                        // CLEAR ADAPTER          │
│   wsManager.connect(projectPath, sessionId: nil)   // NO SESSION - NEW!      │
│                                                                              │
│   messages.append("New session started...")                                  │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 5. Message Sending (Creates Session If Needed)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ CLIInputView: User sends message                                             │
│     onSend: viewModel.sendMessage()                                          │
└─────────────────────────────────┬────────────────────────────────────────────┘
                                  │
                                  ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ ChatViewModel.sendMessage()                                                  │
│                                                                              │
│   sessionToResume = effectiveSessionToResume                                 │
│   ├─→ if wsManager.sessionId != nil: return it                               │
│   ├─→ else if selectedSession?.id not "new-session-*": return it             │
│   └─→ else: return nil (will create new session)                             │
│                                                                              │
│   wsManager.sendMessage(                                                     │
│       message,                                                               │
│       projectPath,                                                           │
│       resumeSessionId: sessionToResume    // nil = create new                │
│   )                                                                          │
└─────────────────────────────────┬────────────────────────────────────────────┘
                                  │
                                  ▼ (if resumeSessionId was nil)
┌──────────────────────────────────────────────────────────────────────────────┐
│ Server creates session, responds with session ID                             │
│                                                                              │
│ CLIBridgeManager.handleConnected(payload)                                    │
│   sessionId = payload.sessionId           // MANAGER UPDATED                 │
│   onSessionConnected?(payload.sessionId)                                     │
└─────────────────────────────────┬────────────────────────────────────────────┘
                                  │
                                  ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ ChatViewModel.wsManager.onSessionCreated callback                            │
│                                                                              │
│   if session exists in store:                                                │
│     selectedSession = existingSession                                        │
│     wsManager.sessionId = sessionId       // ADAPTER UPDATED                 │
│     MessageStore.saveSessionId(sessionId) // PERSISTED                       │
│     sessionStore.setActiveSession(sessionId)                                 │
│   else:                                                                      │
│     wsManager.sessionId = sessionId       // ADAPTER UPDATED                 │
│     MessageStore.saveSessionId(sessionId) // PERSISTED                       │
│     create newSession, add to store                                          │
│     sessionStore.setActiveSession(sessionId)                                 │
│     selectedSession = newSession                                             │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 6. Session Error Recovery

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ Server returns SESSION_NOT_FOUND or SESSION_INVALID error                    │
└─────────────────────────────────┬────────────────────────────────────────────┘
                                  │
                                  ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ CLIBridgeManager.handleError(payload)                                        │
│                                                                              │
│   connectionError = ConnectionError.from(payload)                            │
│   sessionId = nil                          // MANAGER CLEARED                │
│   pendingSessionId = nil                                                     │
│   agentState = .stopped                                                      │
│   onConnectionError?(connectionError)      // Propagate to adapter           │
└─────────────────────────────────┬────────────────────────────────────────────┘
                                  │
                                  ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ CLIBridgeAdapter.manager.onConnectionError callback (Issue 6 fix)            │
│                                                                              │
│   onConnectionError?(error)                // Forward to view model          │
│                                                                              │
│   switch error {                                                             │
│   case .sessionNotFound, .sessionInvalid:                                    │
│       onSessionRecovered?()                // TRIGGER RECOVERY!              │
│   }                                                                          │
└─────────────────────────────────┬────────────────────────────────────────────┘
                                  │
                                  ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ ChatViewModel.wsManager.onSessionRecovered callback                          │
│                                                                              │
│   messages.append("Previous session expired...")                             │
│   MessageStore.clearSessionId(for: project.path)                             │
│   wsManager.sessionId = nil                                                  │
│                                                                              │
│   // Create ephemeral to break the invalid-session-ID loop                   │
│   selectedSession = ephemeral("new-session-UUID")                            │
│   sessionStore.clearActiveSessionId(for: project.path)                       │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Critical Paths

### Path A: Normal Project Open (Has Sessions)
```
Tap Project → onAppear → loadSessions → autoSelectMostRecentSession
           → wsManager.connect(sessionId) → load history
```

### Path B: Normal Project Open (No Sessions)
```
Tap Project → onAppear → loadSessions → autoSelectMostRecentSession returns
           → create ephemeral → wsManager.connect(nil)
```

### Path C: Recent Session Selection
```
Tap Recent → setSelectedSession(saves) → onAppear → selectInitialSession(finds,clears)
          → wsManager.connect(sessionId,saves again) → load history
```

### Path D: Session Switch (Picker)
```
Select Session → selectSession() → attachToSession(reconnects) → save
             → cancel previous load → load history (with staleness check)
```

### Path E: New Session
```
New Chat → clear everything → wsManager.connect(nil) → ephemeral placeholder
        → send message → server creates session → onSessionCreated → persist
```

### Path F: Session Expired/Invalid
```
Server error → CLIBridgeManager clears sessionId → CLIBridgeAdapter calls onSessionRecovered
           → ChatViewModel resets selectedSession to ephemeral → ready for new session
```

---

## Identified Issues

### Issue 1: No Ephemeral Session When Opening Empty Project ✅ FIXED

**Location:** `ChatViewModel.onAppear()` lines 220-240

**Status:** Fixed - now creates ephemeral session placeholder.

**Original Problem:** When opening a project with NO sessions, `autoSelectMostRecentSession()` returned without setting `selectedSession`, leaving it `nil`.

**Fix Applied:** Added ephemeral session creation in `onAppear()`:
```swift
} else {
    // No sessions exist - create ephemeral placeholder and connect without sessionId
    log.debug("[ChatViewModel] No sessions found for project - creating ephemeral session")

    let ephemeralSession = ProjectSession(
        id: "new-session-\(UUID().uuidString)",
        summary: "New Session",
        ...
    )
    selectedSession = ephemeralSession

    wsManager.connect(projectPath: project.path)
}
```

### Issue 2: Double Save After clearActiveSessionId ⏭️ SKIP

**Location:** `ChatViewModel.selectInitialSession()` + `onAppear()`

**Status:** Not a bug - defensive coding pattern.

**Analysis:** The flow clears then re-saves the session ID. While seemingly wasteful, this is defensive coding that prevents stale state if a crash occurs between operations. Low priority optimization.

### Issue 3: Potential Race Condition in Session Loading ⏭️ SKIP

**Location:** `ChatViewModel.onAppear()` lines 200-228

**Status:** Minor edge case - would require significant refactoring.

**Analysis:** Sessions are loaded asynchronously and navigation could theoretically happen during load. However, SwiftUI's navigation handling and the Task cancellation in `onDisappear` provide reasonable protection. A full fix would require implementing a navigation state machine.

### Issue 4: autoSelectMostRecentSession Only Selects Sessions With Messages ✅ HANDLED

**Location:** `ChatViewModel.autoSelectMostRecentSession()` lines 382-397

**Status:** Already handled by Issue 1 fix.

**Analysis:** When `autoSelectMostRecentSession()` doesn't find a session with messages, it returns without setting `selectedSession`. The Issue 1 fix in `onAppear()` now creates an ephemeral session in this case, so the user sees a "New Session" placeholder instead of a broken state.

### Issue 5: WebSocket Connection Debounce May Skip Intended Reconnects ✅ OK

**Location:** `CLIBridgeAdapter.connect()` lines 120-128

**Status:** Not a bug - correct behavior.

**Analysis:** The debounce logic correctly checks:
1. Same session ID as last connected
2. Last connection was within 5 seconds
3. `isConnected` is true (connection is actually live)

If the connection breaks, `connectionState` updates to disconnected and `isConnected` returns false, so the debounce won't incorrectly skip. This is a valid performance optimization.

### Issue 6: CRITICAL - Session Recovery Callback Never Invoked ✅ FIXED

**Location:** `CLIBridgeAdapter.setupCallbacks()` - `manager.onConnectionError` handler

**Status:** Fixed - now calls `onSessionRecovered` for session errors.

**Original Problem:** The `onSessionRecovered` callback was defined and handled in `ChatViewModel`, but **never actually invoked** from production code. When a `sessionNotFound` or `sessionInvalid` error occurred:
1. `CLIBridgeManager` cleared its `sessionId` and called `onConnectionError`
2. `CLIBridgeAdapter` just forwarded to its own `onConnectionError`
3. `ChatViewModel` posted an error to `ErrorStore` but never reset `selectedSession`
4. `effectiveSessionToResume` kept returning the stale invalid session ID

**Fix Applied:** Added `onSessionRecovered` trigger in `CLIBridgeAdapter.setupCallbacks()`:
```swift
manager.onConnectionError = { [weak self] error in
    log.error("[CLIBridgeAdapter] Connection error: \(error.localizedDescription)")
    self?.onConnectionError?(error)

    // Trigger session recovery for session-related errors
    // This resets selectedSession to prevent invalid-session-ID loops
    switch error {
    case .sessionNotFound, .sessionInvalid:
        self?.onSessionRecovered?()
    default:
        break
    }
}
```

### Issue 7: Race Condition in Session List Loading ✅ OK

**Location:** `ChatViewModel.onAppear()` and `selectInitialSession()`

**Status:** Already has deduplication - not a bug.

**Analysis:** The `sessionStore.addSession()` method already checks for duplicates:
```swift
if !sessions.contains(where: { $0.id == session.id }) {
    sessions.insert(session, at: 0)
    ...
}
```

So even if `onSessionCreated` fires and tries to add a session that's already in the list from `loadSessions`, it will be safely ignored.

### Issue 8: Session Switch Race Condition ✅ FIXED

**Location:** `ChatViewModel.loadSessionHistory()`

**Status:** Fixed - now cancels previous load and checks for staleness.

**Original Problem:** When rapidly switching sessions via the session picker:
1. `selectSession(A)` started async history load for session A
2. User quickly selected session B
3. `selectSession(B)` started another async history load for session B
4. Both history loads completed and could overwrite each other

**Fix Applied:** Added `historyLoadTask` property to track and cancel previous loads:
```swift
func loadSessionHistory(_ session: ProjectSession) {
    // Cancel any existing history load to prevent race conditions
    historyLoadTask?.cancel()

    let targetSessionId = session.id

    historyLoadTask = Task {
        // ... fetch history ...

        // Check if task was cancelled or session changed while loading
        guard !Task.isCancelled, selectedSession?.id == targetSessionId else {
            log.debug("[ChatViewModel] History load cancelled or session changed, discarding results")
            return
        }

        // Apply results only if still relevant
        messages = historyMessages
    }
}
```

### Issue 9: /clear and /new Commands Don't Match startNewSession ✅ FIXED

**Location:** `ChatViewModel.handleClearCommand()` and `handleNewSessionCommand()`

**Status:** Fixed - now match `startNewSession()` behavior.

**Original Problem:** The slash commands `/clear` and `/new` only cleared state but didn't:
1. Create an ephemeral session placeholder
2. Disconnect and reconnect WebSocket without sessionId
3. Clear SessionStore's activeSessionId

This could leave `selectedSession = nil` which breaks the UI.

**Fix Applied:** Updated both commands to match `startNewSession()`:
```swift
func handleClearCommand() {
    // Clear UI state
    messages = []
    scrollManager.reset()
    MessageStore.clearMessages(for: project.path)
    MessageStore.clearSessionId(for: project.path)
    sessionStore.clearActiveSessionId(for: project.path)

    // Create ephemeral session placeholder
    let ephemeralSession = ProjectSession(...)
    selectedSession = ephemeralSession

    // Disconnect and reconnect WebSocket without sessionId
    wsManager.disconnect()
    wsManager.sessionId = nil
    wsManager.connect(projectPath: project.path, sessionId: nil)

    addSystemMessage("Conversation cleared. Starting fresh.")
    refreshDisplayMessagesCache()
}
```

---

## Expected vs Actual Behavior

| Scenario | Expected | Actual | Status |
|----------|----------|--------|--------|
| Click project (has sessions) | Resume latest session | Resumes latest session | ✅ |
| Click project (no sessions) | Create blank placeholder | Creates ephemeral "New Session" placeholder | ✅ FIXED |
| Send message (blank session) | Create new sessionId, persist | Works correctly | ✅ |
| Send message (existing session) | Use existing sessionId | Works correctly | ✅ |
| Pick session from picker | Switch to that session | Works correctly | ✅ |
| Pick recent session from home | Load that session | Works correctly | ✅ |
| New Chat button | Clear everything, start fresh | Works correctly | ✅ |
| Session expired/not found | Create new session | Creates ephemeral, fresh session | ✅ FIXED |
| Rapid session switching | Only load latest session | Cancels previous load, applies latest only | ✅ FIXED |
| /clear or /new command | Start fresh session | Creates ephemeral, reconnects WebSocket | ✅ FIXED |

---

## State Synchronization Table

When each state location gets updated:

| Event | MessageStore | SessionStore.activeSessionIds | wsManager.sessionId | selectedSession |
|-------|--------------|-------------------------------|---------------------|-----------------|
| setSelectedSession | ✅ saved | ✅ set | ❌ | ❌ |
| selectInitialSession | ❌ cleared | ❌ cleared | ❌ | ✅ set |
| onAppear (after select) | ✅ saved | ❌ | ✅ set | (already set) |
| selectSession | ✅ saved | ❌ | ✅ via attach | ✅ set |
| startNewSession | ✅ cleared | ✅ cleared | ✅ nil | ✅ ephemeral |
| /clear or /new | ✅ cleared | ✅ cleared | ✅ nil | ✅ ephemeral |
| onSessionCreated | ✅ saved | ✅ set | ✅ set | ✅ set |
| onSessionRecovered | ✅ cleared | ✅ cleared | ✅ nil | ✅ ephemeral |
| deleteSession | ✅ cleared (if active) | ✅ nil (if active) | ✅ nil (if active) | ✅ nil |

---

## Summary

All critical session management issues have been addressed:

| Issue | Status | Summary |
|-------|--------|---------|
| Issue 1 | ✅ FIXED | Ephemeral session created for empty projects |
| Issue 2 | ⏭️ SKIP | Defensive coding, not a bug |
| Issue 3 | ⏭️ SKIP | Minor edge case, acceptable risk |
| Issue 4 | ✅ HANDLED | Covered by Issue 1 fix |
| Issue 5 | ✅ OK | Debounce logic is correct |
| Issue 6 | ✅ FIXED | `CLIBridgeAdapter` now invokes `onSessionRecovered` callback |
| Issue 7 | ✅ OK | Deduplication already exists |
| Issue 8 | ✅ FIXED | Session switch cancels previous history load |
| Issue 9 | ✅ FIXED | `/clear` and `/new` commands now match `startNewSession()` |

### Long-term Improvements (Optional)

1. **Simplify State:** Consider consolidating session ID storage to fewer layers. The current multi-layer approach (UserDefaults + in-memory + adapter + manager + viewmodel) is complex.

2. **Add Logging:** Add more debug logging around session state changes to make debugging easier.

3. **Consider State Machine:** A formal state machine for session lifecycle would prevent invalid state transitions.
