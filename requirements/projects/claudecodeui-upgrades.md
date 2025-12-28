# claudecodeui Backend Upgrades

Comprehensive list of workarounds in the iOS app that could be eliminated by improving the claudecodeui backend. Organized by priority/impact.

## Priority 1: Critical (Blocking Features)

### 1.1 Session API Returns Only ~5 Sessions

**Current Limitation**: The `/api/projects` endpoint only returns approximately 5 most recent sessions per project, regardless of how many exist.

**iOS Workaround**:
- Load ALL sessions via SSH by parsing JSONL files directly
- SSH becomes source of truth, API data used only as temporary fallback
- Complex shell script with `jq` to extract summaries

**Files Affected**:
- `SSHManager.swift:1988-2067` - `loadAllSessions()` function
- `SessionManager.swift:45-73` - dual-source session loading
- `ChatView.swift:~1196` - SSH loading trigger

**Backend Fix**:
```
GET /api/projects/:project/sessions
- Return ALL sessions, not just recent 5
- Add pagination: ?page=1&limit=50
- Add filters: ?exclude=agent,helper
```

---

### 1.2 CORS Blocks Session History Endpoint

**Current Limitation**: Backend CORS config only allows `Content-Type` header, not `Authorization`. The `/api/projects/:project/histories` endpoint is completely unusable.

**iOS Workaround**: Load session content via SSH instead of HTTP API.

**Files Affected**:
- `APIClient.swift:170` - commented out endpoint
- `requirements/BACKEND.md:165-175` - documented issue

**Backend Fix**:
```javascript
// Fix CORS headers
app.use(cors({
  allowedHeaders: ['Content-Type', 'Authorization'],
  // ... other config
}));
```

---

### 1.3 No Pre-Parsed Session Summaries

**Current Limitation**: Backend stores raw JSONL files. No API to get session titles/summaries without parsing entire files.

**iOS Workaround**:
- Parse JSONL via SSH using `jq`
- Extract first non-meta user message
- Filter out ClaudeHelper prompts, system errors
- Handle both array and string content formats

**Files Affected**:
- `SSHManager.swift:2000-2067` - complex jq parsing

**Backend Fix**:
```
GET /api/projects/:project/sessions
Response: [
  {
    "id": "abc123",
    "summary": "Help me refactor the auth module",
    "messageCount": 24,
    "lastModified": "2025-12-28T10:30:00Z",
    "type": "user"  // or "agent", "helper"
  }
]
```

---

## Priority 2: High (Significant Complexity)

### 2.1 No Session Type Classification

**Current Limitation**: Backend doesn't distinguish between user sessions, agent sessions, and helper sessions.

**iOS Workaround**:
- Filter agent sessions via `grep -v '^agent-'`
- Generate deterministic helper session ID from project path hash
- Track and filter helper sessions by ID match

**Files Affected**:
- `SSHManager.swift:2005-2089` - filtering logic
- `ClaudeHelper.swift:37-82` - deterministic ID generation
- `SessionManager.swift:218-230` - helper session filtering

**Backend Fix**:
- Add `type` field to session metadata: `"user"`, `"agent"`, `"helper"`
- Add query param: `GET /api/projects/:project/sessions?type=user`
- Store helper session flag when created with specific parameter

---

### 2.2 Content Schema Inconsistency

**Current Limitation**: Session files store message content in both array format AND string format inconsistently.

**iOS Workaround**:
```bash
jq -r 'if .message.content | type == "array" then .message.content[0].text
       elif .message.content | type == "string" then .message.content
       else empty end'
```

**Files Affected**:
- `SSHManager.swift:2000-2067`
- `APIClient.swift:324-402` - `SessionMessage.toChatMessage()`

**Backend Fix**:
- Normalize content format when writing session files
- Always use array format: `content: [{ type: "text", text: "..." }]`
- Or provide normalized API response regardless of storage format

---

### 2.3 Session ID Not Known Until After First Message

**Current Limitation**: Backend generates session ID server-side after user sends first message, sends it back via `session-created` WebSocket message.

**iOS Workaround**:
- App must wait for callback before knowing session ID
- Cannot pre-populate session list with new session

**Files Affected**:
- `WebSocketManager.swift:142,173-187` - `onSessionCreated` callback

**Backend Fix**:
- Option A: Let client generate UUID, send with first message
- Option B: Create session on connect, return ID in WebSocket handshake
- Option C: Return session ID in initial `/api/connect` response

---

### 2.4 Raw JSONL Instead of Parsed API Response

**Current Limitation**: Session history endpoint returns raw JSONL file content, not structured JSON.

**iOS Workaround**: Manual JSONL line-by-line parsing with type detection for each message.

**Files Affected**:
- `APIClient.swift:324-402` - extensive parsing logic

**Backend Fix**:
```
GET /api/projects/:project/sessions/:sessionId/messages
Response: {
  "messages": [
    {
      "id": "msg_001",
      "role": "user",
      "content": "Help me...",
      "timestamp": "2025-12-28T10:30:00Z"
    },
    {
      "id": "msg_002",
      "role": "assistant",
      "content": [...],
      "toolCalls": [...],
      "thinking": "...",
      "timestamp": "2025-12-28T10:30:05Z"
    }
  ]
}
```

---

### 2.5 No Session Deletion Coordination

**Current Limitation**: No backend coordination for session deletion. Race conditions possible with background processes.

**iOS Workaround**:
- Track deleted session IDs with timestamps
- Ignore stale sessions for 5 minutes after deletion
- Track which projects have been SSH-loaded

**Files Affected**:
- `SessionManager.swift:261-313` - deletion tracking

**Backend Fix**:
- Proper `DELETE /api/projects/:project/sessions/:sessionId` endpoint
- Return success/failure status
- Backend handles file deletion atomically
- WebSocket notification for session changes

---

## Priority 3: Medium (Quality of Life)

### 3.1 No Bulk Session Operations

**Current Limitation**: No API for bulk session operations (delete multiple, export, etc.)

**iOS Workaround**: Execute individual SSH `rm` commands for each session.

**Backend Fix**:
```
DELETE /api/projects/:project/sessions
Body: { "sessionIds": ["id1", "id2", "id3"] }

POST /api/projects/:project/sessions/export
Body: { "sessionIds": ["id1", "id2"], "format": "json" }
```

---

### 3.2 Streaming Updates Too Frequent

**Current Limitation**: WebSocket sends every token as it arrives, causing excessive view updates.

**iOS Workaround**: 50ms debounce buffer before rendering.

**Files Affected**:
- `WebSocketManager.swift:84-89` - text buffering

**Backend Fix**:
- Add configurable batching: `?streamBatch=50ms`
- Or batch tokens server-side before sending

---

### 3.3 No Project Metadata Caching Headers

**Current Limitation**: No cache headers on project list API.

**iOS Workaround**: Local `ProjectCache.swift` for instant startup.

**Backend Fix**:
- Add `ETag` and `Cache-Control` headers
- Support `If-None-Match` for 304 responses

---

### 3.4 JWT Token Refresh Not Automatic

**Current Limitation**: JWT expires, client gets 401, must re-login.

**iOS Workaround**: Detect 401, attempt re-login with stored credentials.

**Files Affected**:
- `APIClient.swift:133-138`

**Backend Fix**:
- Add refresh token endpoint
- Or extend JWT expiry significantly
- Or use session-based auth

---

## Priority 4: Nice to Have

### 4.1 Image Upload Response Format

**Current Limitation**: Image upload requires manual multipart form construction, returns base64 in response.

**iOS Workaround**: Manual multipart body construction, MIME type detection.

**Files Affected**:
- `APIClient.swift:239-298`

**Backend Fix**:
- Accept base64 directly in JSON body (simpler client code)
- Or return image URL/ID instead of re-encoded base64

---

### 4.2 Helper Session Support

**Current Limitation**: No built-in concept of "helper" sessions for background queries.

**iOS Workaround**:
- Generate deterministic UUID from project path
- Manually reuse same session for all helper queries

**Files Affected**:
- `ClaudeHelper.swift:37-82`

**Backend Fix**:
- Add session type parameter: `POST /api/sessions?type=helper`
- Auto-reuse helper session per project
- Exclude from session lists by default

---

## Not Backend Issues (iOS Platform Quirks)

These are iOS-specific issues, not claudecodeui problems:

| Issue | Workaround | File |
|-------|------------|------|
| TextEditor drops first character on paste | Detect truncated OpenSSH keys, prepend 'b' | `SSHManager.swift:740-797` |
| Smart punctuation converts dashes | Normalize Unicode dashes to ASCII | `SSHManager.swift:245-281` |
| Soft hyphens added to wrapped text | Strip non-base64 characters | `SSHManager.swift:339-341` |
| Citadel SSH can't run concurrent commands | Execute git commands sequentially | `SSHManager.swift:1873-1941` |

---

## Implementation Roadmap

### Phase 1: Fix Blocking Issues
1. Fix CORS headers (1.2) - **5 min fix**
2. Return all sessions in API (1.1) - **1-2 hours**
3. Add session summaries to API response (1.3) - **2-3 hours**

### Phase 2: Improve Session API
4. Add session type classification (2.1) - **2-3 hours**
5. Normalize content schema (2.2) - **1-2 hours**
6. Structured session messages endpoint (2.4) - **3-4 hours**

### Phase 3: Polish
7. Session ID on connect (2.3)
8. Bulk operations (3.1)
9. Streaming batching (3.2)
10. Cache headers (3.3)

---

## iOS Code to Remove After Backend Fixes

Once backend is improved, these can be simplified/removed:

```
SSHManager.swift:
- loadAllSessions() - 80 lines
- countSessions() - 30 lines
- countSessionsForProjects() - 60 lines
- Complex jq parsing scripts

SessionManager.swift:
- Dual-source loading logic
- Deletion tracking (~50 lines)
- Helper session filtering

ClaudeHelper.swift:
- Deterministic session ID generation

APIClient.swift:
- JSONL parsing logic (~80 lines)
- Manual multipart form construction
```

**Estimated reduction**: ~300-400 lines of workaround code.
