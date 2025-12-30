# CodingBridge Session Handling - Current State

> Comprehensive assessment of session handling throughout the iOS app

---

## 1. Session Counting

### Where Counts Are Displayed

**ProjectRow** (`Views/ProjectListViews.swift:79-87`)
- Shows `[N sessions]` badge per project
- Calculation: `sessionCount ?? project.displaySessions.count`
- Uses API count if loaded, falls back to displaySessions

**SessionPickerSheet** (`Views/SessionPickerViews.swift:382`)
- Navigation title shows "Sessions (N)"
- Uses `displaySessions.count` (filtered list)

### Count Calculation Logic

| Method | Location | Description |
|--------|----------|-------------|
| `sessionCount()` | SessionStore:253 | Unfiltered API total |
| `displaySessionCount()` | SessionStore:258 | Filtered: excludes helper, empty sessions |

**Filtering Applied:**
- Excludes helper sessions (`ClaudeHelper.isHelperSession()`)
- Excludes empty sessions (`messageCount == 0`)
- Always includes active session ID

---

## 2. Session Lists

### Primary List UI

**SessionPickerSheet** (`Views/SessionPickerViews.swift:271-523`)
- Full session manager with pagination
- Displays filtered sessions from SessionStore
- "Load More" button for pagination (lines 350-371)
- Shows: name, preview, message count, last activity

**SessionBar** (`Views/SessionPickerViews.swift:27-159`)
- Compact bar showing current session
- [+] New session button
- [≡] Session manager button

**SessionRow** (`Views/SessionPickerViews.swift:665-787`)
- Individual session display
- Custom name or auto-generated summary
- Preview text (assistant or user message)
- Message count, relative time, session ID fallback

### Data Source

**SessionStore.shared** (singleton)
- `sessionsByProject[String: [ProjectSession]]` - cached sessions
- `metaByProject[String: ProjectSessionMeta]` - pagination state
- `loadSessions(for: projectPath, forceRefresh: true)`

---

## 3. Session Creation

### New Session Flow

**ChatViewModel.startNewSession()** (line 263-287)
1. Creates ephemeral session: `"new-session-{UUID}"`
2. Clears messages and history
3. Stores as `selectedSession`
4. Real session created on first message

**Real Session Creation** (CLIBridgeManager)
1. User sends first message
2. Manager establishes connection without sessionId
3. Backend creates session, returns sessionId in Connected event
4. `onSessionCreated` callback fires (line 742-773)
5. `SessionStore.addSession()` adds to local state

---

## 4. Session Deletion

### Single Deletion

**ChatViewModel.deleteSession()** (line 421-437)
1. Calls `sessionStore.deleteSession(session, for: projectPath)`
2. SessionStore (line 132-163):
   - Updates local state immediately (optimistic UI)
   - API call: `DELETE /projects/{path}/sessions/{id}`
   - Clears active session if deleted
   - Reloads on error

### Bulk Deletion

**SessionPickerSheet** (lines 446-572)
- Delete All Sessions (with active protection)
- Delete Sessions Older Than (7/30/90 days)
- Keep Last N Sessions (5/10/20)

**API Endpoint:** `DELETE /projects/{path}/sessions?filter=older_than&days=N`

---

## 5. Session Renaming

### Local Storage

**SessionNamesStore** (`ProjectNamesStore.swift:7-25`)
- UserDefaults key: `"session_custom_names"`
- Singleton: `SessionNamesStore.shared`
- Methods: `getName()`, `setName()`
- Format: `{sessionId: customName}`

### Display Name Priority

1. Custom name from SessionNamesStore
2. Session summary from API (`title` field)
3. Last user message
4. Fallback: `"Session {id.prefix(8)}..."`

---

## 6. Active Session Tracking

### State Storage

**SessionStore.activeSessionIds** (line 31)
- Dictionary: `[projectPath: sessionId]`
- Updated via `setActiveSession()`

### Persistence

**MessageStore** (Models.swift)
- `saveSessionId()` → UserDefaults key: `"session_id_{safe_project_path}"`
- `loadSessionId()` → Restores on ChatView init
- `clearSessionId()` → On deletion or new session

### WebSocket Tracking

**CLIBridgeManager.$sessionId** (CLIBridgeAdapter:697-703)
- Published property, updates on connection
- `wsManager.sessionId` stores current connected session

---

## 7. API Endpoints Used

### Sessions API (CLIBridgeAPIClient.swift:38-150)

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/projects/{path}/sessions` | GET | List sessions (paginated) |
| `/projects/{path}/sessions/{id}` | GET | Single session |
| `/projects/{path}/sessions/{id}` | PUT | Rename session |
| `/projects/{path}/sessions/{id}` | DELETE | Delete single |
| `/projects/{path}/sessions` | DELETE | Bulk delete |
| `/sessions/recent` | GET | Recent across projects |
| `/projects/{path}/sessions/{id}/export` | GET | Export history |

### Implementation Stack

```
Views (SessionPickerSheet, ChatView)
    ↓
SessionStore (state management)
    ↓
SessionRepository (abstraction layer)
    ↓
CLIBridgeAPIClient (HTTP calls)
    ↓
cli-bridge backend
```

---

## 8. Data Models

### ProjectSession (Models.swift:190-197)

```swift
struct ProjectSession: Codable, Identifiable {
    let id: String
    let summary: String?
    let messageCount: Int?
    let lastActivity: String?
    let lastUserMessage: String?
    let lastAssistantMessage: String?
}
```

### CLISessionMetadata (CLIBridgeTypes.swift:1077-1089)

```swift
struct CLISessionMetadata: Decodable {
    let id: String
    let projectPath: String
    let messageCount: Int
    let createdAt: String
    let lastActivityAt: String
    let lastUserMessage: String?
    let lastAssistantMessage: String?
    let title: String?
    let customTitle: String?
    let model: String?
    let source: SessionSource?  // user, agent, helper
}
```

---

## 9. Real-Time Updates

### WebSocket Events

**CLISessionEvent** (CLIBridgeTypes.swift:1062-1073)
- Actions: `created`, `updated`, `deleted`
- Received via `onSessionEvent` callback

**SessionStore.handleCLISessionEvent()** (line 324-360)
- Updates local state on events
- Called from ChatViewModel.setupWebSocketCallbacks()

---

## 10. Caching & Persistence

### In-Memory Cache (SessionStore)

| Property | Type | Purpose |
|----------|------|---------|
| `sessionsByProject` | `[String: [ProjectSession]]` | Cached sessions |
| `metaByProject` | `[String: ProjectSessionMeta]` | Pagination |
| `isLoading` | `[String: Bool]` | Loading state |
| `errorByProject` | `[String: Error]` | Errors |
| `activeSessionIds` | `[String: String]` | Active per project |

### Persistent Storage (UserDefaults)

| Key | Content |
|-----|---------|
| `session_id_{safe_path}` | Last selected session ID |
| `session_custom_names` | Custom name dictionary |

### Message History (Documents Directory)

- File: `{encoded-project-path}.json`
- Limited to 50 messages (configurable)

---

## 11. Key Files Reference

| File | Lines | Purpose |
|------|-------|---------|
| `SessionStore.swift` | 482 | Central state management |
| `SessionRepository.swift` | 121 | API abstraction |
| `SessionPickerViews.swift` | 788 | Session list UI |
| `ChatViewModel.swift` | ~1000 | Session logic |
| `CLIBridgeAdapter.swift` | ~900 | WebSocket handling |
| `CLIBridgeAPIClient.swift` | ~300 | REST endpoints |
| `CLIBridgeTypes.swift` | ~1500 | Data models |
| `Models.swift` | ~700 | ProjectSession, filtering |
| `ProjectListViews.swift` | ~150 | Session count display |

---

## 12. Session Lifecycle Flow

### App Launch → Session Selection

1. **ContentView** → `sessionStore.configure(with: settings)`
2. **Project Selection** → ChatView opens
3. **ChatViewModel.onAppear()** → `sessionStore.loadSessions()`
4. **selectInitialSession()** → Check UserDefaults or auto-select
5. **CLIBridgeAdapter.connect()** → WebSocket with sessionId

### First Message → Session Creation

1. User types message in "new-session-*" ephemeral session
2. CLIBridgeManager establishes connection (no sessionId)
3. Backend creates session, returns real sessionId
4. `onSessionCreated` fires with real ID
5. SessionStore.addSession() updates cache
6. UI refreshes with real session

---

## 13. Current Issues & Pain Points

### Known Issues

1. **Session count discrepancy** - Project list shows different count than sessions API
2. **Agent sessions pollute list** - 96 agent sessions vs 5 user sessions in test
3. **No session search** - Can't search session content
4. **Ephemeral session handling** - "new-session-*" IDs need cleanup
5. **Multiple active sessions possible** - activeSessionIds allows one per project but UI can get confused

### UI/UX Issues

1. **Load More pagination** - Not ideal for 100+ sessions
2. **No session preview before selection** - Must select to see content
3. **Rename only via context menu** - Not discoverable
4. **Bulk operations limited** - Only delete, no archive/export

### Code Quality Issues

1. **Duplicate session counting logic** - ProjectRow vs SessionStore
2. **Mixed model types** - `ProjectSession` vs `CLISessionMetadata`
3. **Inconsistent filtering** - Different filters in different places
4. **No centralized session ID validation**
