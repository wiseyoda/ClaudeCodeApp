# Issues

Bug tracker for CodingBridge. Issues are grouped by area for efficient batch fixing.

## How to Report

When reporting a bug, include:
- **What happened**: Brief description of the issue
- **Expected**: What should have happened
- **Steps to reproduce**: If known
- **Location**: File/view where it occurred (if applicable)

---

## Open Issues Summary

| ID | Source | Issue | Priority | Group | Status |
|----|--------|-------|----------|-------|--------|
| GH#2 | GitHub | Session picker can stay on old session when already connected | P1 | A | **FIXED** |
| L#1 | Local | System Error when sending input in history chat sessions | Critical | A | **FIXED** |
| GH#4 | GitHub | Session-invalid errors leave WS/session state ambiguous | P2 | A | **FIXED** |
| L#2 | Local | Tool cards displaying above first assistant message (regression) | High | B | **FIXED** |
| L#3 | Local | Assistant message disappears during WS stream finalization | High | B | **FIXED** |
| GH#3 | GitHub | History load clears UI before fetch completes | P2 | B | **FIXED** |
| GH#6 | GitHub | Potential duplicate assistant message on system/result + stopped | P3 | B | **FIXED** |
| GH#8 | GitHub | SessionStore load race can overwrite newer data | P2 | C | Open |
| GH#7 | GitHub | Use withRetry for core API calls | P2 | C | Open |

---

## Group A: Session & WebSocket State Management ✅ FIXED

These issues all relate to session ID handling, WebSocket connection state, and session switching. **All issues in this group have been fixed.**

**Fix Summary:**

*iOS App (CodingBridge):*
1. **Session switching support** - `connectImpl()` now detects session switches and disconnects before reconnecting
2. **Session ID preservation** - `pendingSessionId` synced on connection success for reliable reconnection
3. **Simplified resolution** - Clearer priority: explicit → selectedSession → new session
4. **Better error recovery** - Full state reset on session errors with user notification

*Backend (cli-bridge v0.4.13+):*
5. **Session ID case normalization** - Fixed uppercase/lowercase UUID handling that caused "CLI exited with code 1" errors when resuming sessions

**Files Modified (iOS):**
- `CLIBridgeManager+Connection.swift` - Session switching logic
- `CLIBridgeManager+Stream.swift` - Sync pendingSessionId on connect
- `CLIBridgeManager.swift` - Added `updatePendingSessionId()`
- `ChatViewModel+ManagerState.swift` - Simplified `resolvedResumeSessionId()` + debug logging
- `ChatViewModel+StreamEvents.swift` - Improved session error recovery

---

### GH#2: Session picker can stay on old session when already connected

**Priority:** P1 (High) | **Labels:** bug, websocket, sessions

**Context:**
- `ChatViewModel.attachToSession` calls `manager.connect`, but `connectImpl` returns early when already connected/connecting
- Selecting a different session while connected can keep the old session active, so messages go to the wrong session

**Impact:** Everyday session switching can silently send messages to the previous session.

**Proposed Fix:**
- Add a force-reconnect or reattach path (disconnect + connect with new sessionId)
- Allow `connectImpl` to switch sessions when the sessionId changes
- Ensure sessionId/active session state is updated consistently

**Files:**
- `ChatViewModel+ManagerState.swift`
- `CLIBridgeManager+Connection.swift`

---

### L#1: System Error when sending input in history chat sessions

**Priority:** Critical | **Status:** Root cause found

**What happened:** When going into a history chat and sending input, a "System Error" appears. Starting a new session works, but after idle time the error returns.

**Expected:** Should be able to resume history sessions and send messages without errors.

**Root Cause:**

The issue is in session ID resolution during message sending after WebSocket reconnection.

**Problem Flow:**
1. User enters history chat → `selectSession()` calls `attachToSession(sessionId, projectPath)`
2. WebSocket connects and `manager.sessionId` is set correctly
3. After idle time, WebSocket may disconnect/reconnect, potentially clearing `manager.sessionId`
4. User sends a message → `sendMessage()` passes `resumeSessionId: manager.sessionId`
5. If `manager.sessionId` is nil after reconnection, `resolvedResumeSessionId()` fails to find valid candidate
6. `manager.connect()` is called with `sessionId: nil`
7. Backend treats this as new session creation instead of resumption → error

**Issues Found:**
1. **Session ID not persisted after reconnection** - `reconnectWithExistingSession()` uses sessionId from pending connection which may be nil
2. **UUID validation too strict** - Line 145 in ManagerState may reject valid session IDs
3. **Session ID priority logic** - Candidates in `resolvedResumeSessionId()` may all be nil/stale after idle

**Files:**
- `ChatViewModel+ManagerState.swift:132-173` - `resolvedResumeSessionId()` and `sendToManager()`
- `CLIBridgeManager+Connection.swift:145-159` - Reconnection logic doesn't preserve session ID
- `ChatViewModel+Sessions.swift:212-221` - `attachToSession()` initial connection

**Regression:** Likely introduced in `d92628f` or `c8a183a`

---

### GH#4: Session-invalid errors leave WS/session state ambiguous

**Priority:** P2 | **Labels:** bug, websocket, sessions

**Context:**
- WS error handling clears sessionId for `session_not_found`/`session_invalid`, but does not disconnect or initiate a clean reconnect
- ChatViewModel handles these errors and returns early without forcing a reset

**Impact:** After session invalidation, the client can remain in a confusing state until the user manually recovers.

**Proposed Fix:**
- On `sessionNotFound`/`sessionInvalid`/`sessionExpired`, explicitly disconnect and reconnect without a sessionId (or force a fresh session)
- Clear pending session state and prompt user that a new session was created

**Files:**
- `CLIBridgeManager+Stream.swift`
- `ChatViewModel+StreamEvents.swift`

---

## Group B: Message Display & Streaming ✅ FIXED

These issues relate to message rendering, streaming state, and UI updates during WebSocket communication. **All issues in this group have been fixed.**

**Fix Summary:**

1. **L#2 - Tool card display order** - Added `refreshDisplayMessagesCache()` calls after tool message appends in `ChatViewModel+StreamEvents.swift`
2. **L#3 - Streaming message flash** - Updated `streamingIndicatorView` in `ChatView.swift` to check `hasFinalizedCurrentResponse` flag, preventing the race condition
3. **GH#3 - History load data loss** - Save previous messages before loading; restore on failure in `ChatViewModel+Sessions.swift`
4. **GH#6 - Duplicate messages** - Set `hasFinalizedCurrentResponse = true` in `handleSystemResultMessage()` to prevent duplicate from `handleStopped`

**Files Modified:**
- `ChatViewModel+StreamEvents.swift` - Cache refresh on tool events, finalization flag on system result
- `ChatView.swift` - Streaming indicator checks finalization flag
- `ChatViewModel+Sessions.swift` - History load preserves previous messages on failure

---

### L#2: Tool cards displaying above first assistant message (regression)

**Priority:** High | **Status:** ✅ FIXED

**What happened:** Tool cards are being displayed ABOVE the first assistant message in the chat. This was previously fixed but has regressed.

**Expected:** Tool cards should appear inline with the assistant's response, after any preceding text.

**Root Cause:**

Regression introduced in commit `eab9e67` ("Add local command parsing and display support"). The display message cache is not being refreshed when tool events are handled.

**Problem:**
1. Tool use event arrives → tool message appended to `messages` array
2. **Missing:** `refreshDisplayMessagesCache()` is NOT called
3. `displayMessages` property returns stale `cachedDisplayMessages`
4. Tool result event arrives → result appended but still no cache refresh
5. When cache IS eventually refreshed (via `finalizeStreamingMessageIfNeeded()`), tool messages appear before later assistant text due to original insertion order

**Fix Required:**
Add `refreshDisplayMessagesCache()` calls after appending tool messages:
1. After line 52 in `.toolStart` case
2. After line 84 in `.toolResult` case

**Files:**
- `ChatViewModel+StreamEvents.swift:37-84`
- `ChatViewModel.swift:498-531` - Display message caching logic
- `CompactToolView.swift:73-131` - Message grouping for tool display

---

### L#3: Assistant message disappears when final result appears during WebSocket stream

**Priority:** High | **Status:** ✅ FIXED

**What happened:** The assistant's streaming message visually disappears/flashes when the "Final message" indicator appears during WebSocket streaming completion.

**Expected:** Smooth transition from streaming message to final message without visual gap.

**Root Cause:**

Race condition in how streaming messages transition to finalized messages.

**Problem Flow:**
1. During streaming: `streamingIndicatorView` displays `CLIMessageView` using `manager.currentText`
2. `.stopped(reason:)` event received → `finalizeStreamingMessageIfNeeded()` called
3. Finalized message added/updated in `messages` array ✓
4. **Immediately after:** `cleanupAfterProcessingComplete()` calls `manager.clearCurrentText()`
5. `manager.currentText` becomes empty → `streamingIndicatorView` returns `EmptyView()`
6. SwiftUI may render a frame where both are "empty" → visual flash

**Two Display Systems:**
1. **Streaming phase:** Uses `manager.currentText` via `streamingIndicatorView` (ChatView.swift:490)
2. **Finalized phase:** Uses `messages` array via `groupedDisplayItems`

**Fix Options:**
1. Clear `currentText` BEFORE finalization (so streaming view is already gone)
2. Add brief delay before clearing to allow SwiftUI render cycle
3. Coordinate timing so streaming indicator transitions away only after finalized message is visible
4. Add flag to indicate "finalization in progress" that keeps streaming view visible until finalized message renders

**Files:**
- `ChatViewModel+StreamEvents.swift:208-244` - Finalization logic
- `ChatViewModel+ManagerState.swift:276-279` - `cleanupAfterProcessingComplete()` clears text
- `ChatView.swift:490-520` - `streamingIndicatorView` conditional rendering
- `CLIBridgeManager.swift:313-319` - `resetStreamingText()` clears `currentText`

---

### GH#3: History load clears UI before fetch completes

**Priority:** P2 | **Status:** ✅ FIXED | **Labels:** bug, history, ui

**Context:**
- `loadSessionHistoryImpl` clears messages immediately, then fetches history
- If the fetch fails, users lose their cached/local messages and only see fallback text + error

**Impact:** Regular network hiccups cause chat history to disappear until reloaded.

**Proposed Fix:**
- Keep previous messages visible until new history is successfully loaded
- Stage new history in a temp buffer and only replace on success
- Consider an inline loading overlay instead of clearing the list

**Files:**
- `ChatViewModel+Sessions.swift`

---

### GH#6: Potential duplicate assistant message on system/result + stopped

**Priority:** P3 | **Status:** ✅ FIXED | **Labels:** bug, websocket, ui

**Context:**
- `system/result` messages are appended immediately as assistant content
- `handleStopped` also appends `committedText` as an assistant message

**Impact:** If the server emits both for the same response, users can see duplicate assistant messages.

**Proposed Fix:**
- Guard against double-append by clearing `committedText` when a matching system/result is appended
- Skip `handleStopped` append if last assistant content matches

**Files:**
- `ChatViewModel+StreamEvents.swift`

---

## Group C: Data Consistency & API Reliability

These issues relate to data races, API resilience, and state consistency during network operations.

**Common Files:**
- `SessionStore.swift`
- `CLIBridgeAPIClient.swift`
- `SessionRepository.swift`

---

### GH#8: SessionStore load race can overwrite newer data

**Priority:** P2 | **Labels:** bug, sessions

**Context:**
- `loadSessions`/`loadMore` don't cancel prior in-flight requests or guard stale results
- Rapid refresh + pagination (or quick project switching) can let older responses overwrite newer state

**Impact:** Session lists can appear to "jump" or show outdated results during normal use.

**Proposed Fix:**
- Track per-project request tokens or store/cancel per-project tasks
- Only apply results if the request is still current
- Consider a separate loading flag for `loadMore` vs full refresh

**Files:**
- `SessionStore.swift`

---

### GH#7: Use withRetry for core API calls

**Priority:** P2 | **Labels:** chore, api

**Context:**
- `CLIBridgeAPIClient` has `withRetry()`, but core reads (projects/sessions/messages) call `get()` directly

**Impact:** Common transient failures (network blips, 5xx, 429) cause visible errors on normal use.

**Proposed Fix:**
- Wrap `fetchProjects`/`fetchSessions`/`fetchMessages`/session count/search with `withRetry`
- Consider a conservative retry budget (e.g., 2-3 attempts) for UI calls

**Files:**
- `CLIBridgeAPIClient.swift`
- `SessionRepository.swift`
- `SessionStore.swift`

---

## Intake Queue

Add new issues below. Triaged items get moved to appropriate groups above; resolved items belong in [CHANGELOG.md](CHANGELOG.md).
