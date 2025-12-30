# API Endpoint Test Results

> Actual test results from cli-bridge server at 10.0.3.2:3100
> Tested: 2025-12-30

---

## Server Health

```bash
GET /health
```

**Response:**
```json
{
  "status": "ok",
  "agents": 0,
  "uptime": 16860,
  "version": "0.1.10"
}
```

---

## Project List with Session Counts

```bash
GET /projects
```

**Response:**
```json
{
  "projects": [
    {
      "path": "/home/bridge/repos/ClaudeCodeApp",
      "name": "ClaudeCodeApp",
      "git": {"branch": "main", "isClean": true, "uncommittedCount": 0},
      "sessionCount": 145,
      "lastUsed": "2025-12-30T15:27:22.021Z"
    },
    {
      "path": "/home/bridge/repos/cli-bridge",
      "name": "cli-bridge",
      "git": {"branch": "main", "isClean": true, "uncommittedCount": 0},
      "sessionCount": 33,
      "lastUsed": "2025-12-30T10:08:44.115Z"
    }
  ]
}
```

---

## Recent Sessions

```bash
GET /sessions/recent?limit=10
```

**Response (truncated):**
- Returns `SessionWithProject[]` array
- Sorted by `lastActivityAt` descending
- Includes both `user` and `agent` source sessions

**Sample Entry:**
```json
{
  "id": "979794da-5942-43c0-a7d7-469372c715ea",
  "projectPath": "/home/bridge/repos/ClaudeCodeApp",
  "source": "user",
  "createdAt": "2025-12-30T06:37:45.954Z",
  "lastActivityAt": "2025-12-30T15:27:22.021Z",
  "messageCount": 1586,
  "title": "Caveat: The messages below were generated...",
  "lastUserMessage": "[tool_result content]...",
  "lastAssistantMessage": "The codebase is in a clean state...",
  "model": "<synthetic>"
}
```

---

## Sessions by Project

### User Sessions Only (Default)

```bash
GET /projects/-home-bridge-repos-ClaudeCodeApp/sessions?limit=200
```

**Results:**
- **Returned:** 5 sessions
- **source=user** filter applied by default

### All Sessions

```bash
GET /projects/-home-bridge-repos-ClaudeCodeApp/sessions?limit=500&source=all
```

**Results:**
- **Returned:** 101 sessions
- **Breakdown by source:**
  - `agent`: 96 sessions
  - `user`: 5 sessions
- **`total` field:** null (not returned)
- **`hasMore` field:** null (not returned)

### Helper Sessions

```bash
GET /projects/-home-bridge-repos-ClaudeCodeApp/sessions?limit=50&source=helper
```

**Results:**
- **Returned:** 0 sessions

---

## Session Counts Discrepancy

### ClaudeCodeApp Project

| Source | Count |
|--------|-------|
| Project list `sessionCount` | **145** |
| API `source=all` | **101** |
| API `source=user` | 5 |
| API `source=agent` | 96 |
| API `source=helper` | 0 |
| **Missing/Unaccounted** | **44** |

### cli-bridge Project

| Source | Count |
|--------|-------|
| Project list `sessionCount` | **33** |
| API `source=all` | **23** |
| **Missing/Unaccounted** | **10** |

### Possible Causes

1. **countSessions()** counts all `.jsonl` files
2. **listSessions()** filters sessions that fail metadata extraction
3. Session directories (not just files) may be counted
4. Corrupted/malformed JSONL files skipped during listing
5. Different handling of empty sessions

**Recommendation:** File as potential bug with cli-bridge team

---

## Session ID Patterns

### Distribution

| Pattern | Count | Description |
|---------|-------|-------------|
| `agent-*` prefix | 99 | Created by subagents |
| Standard UUID | 2 | Created by user directly |
| **Total** | 101 | |

### Source vs ID Pattern Mismatch

- Some `agent-*` prefixed sessions marked as `source: "user"`
- Example: `agent-a53ac71` has `source: "user"`, 107 messages
- These appear to be subagent sessions that completed successfully

---

## Single Session Fetch

```bash
GET /projects/-home-bridge-repos-ClaudeCodeApp/sessions/979794da-5942-43c0-a7d7-469372c715ea
```

**Response:**
```json
{
  "id": "979794da-5942-43c0-a7d7-469372c715ea",
  "source": "user",
  "messageCount": 1586,
  "lastActivityAt": "2025-12-30T15:27:22.021Z"
}
```

---

## Session Export

```bash
GET /projects/{path}/sessions/{id}/export?format=json
```

**Response Structure:**
```json
{
  "session": {
    "id": "...",
    "projectPath": "...",
    "title": "...",
    "createdAt": "...",
    "lastActivityAt": "...",
    "messageCount": 1586
  },
  "messages": [
    {
      "id": "008305f0-f507-4a9a-b511-a0592f6b30b5",
      "timestamp": "2025-12-30T06:37:45.954Z",
      "type": "user",
      "content": "..."
    },
    // ... more messages
  ]
}
```

**Note:** Export returns `{session, messages}` object, not flat array

---

## Session Message Counts

### Sample Distribution

| Session ID | Source | Message Count |
|------------|--------|---------------|
| `979794da-...` | user | 1586 |
| `agent-a53ac71` | user | 107 |
| `agent-ade945e` | user | 95 |
| `agent-a31898b` | agent | 2 |
| `agent-a2f9160` | agent | 2 |
| `agent-ab46cb7` | agent | 2 |

**Pattern:** Agent-sourced sessions typically have 2 messages (request/response)

### Low Message Count Sessions

- 15 sessions have `messageCount == 1`
- 0 sessions have `messageCount == 0` (empty sessions filtered?)

---

## Pagination Behavior

### Response Fields

```bash
GET /projects/{path}/sessions?limit=50
```

**Observed:**
- `total`: null (not populated)
- `hasMore`: null (not populated)
- Only `sessions` array returned

**Expected (per documentation):**
```json
{
  "sessions": [...],
  "total": 145,
  "hasMore": true
}
```

**Issue:** Pagination metadata not returned, making infinite scroll difficult

---

## Key Findings Summary

### Critical Issues

1. **Session count mismatch** - 44 sessions unaccounted (145 vs 101)
2. **Pagination broken** - `total` and `hasMore` return null
3. **Source filtering confusion** - agent-prefixed IDs with user source

### Data Quality Issues

1. **Synthetic model value** - `"model": "<synthetic>"` on some sessions
2. **Title truncation** - Titles cut at "..." without full content
3. **Message preview truncation** - lastUserMessage truncated inconsistently

### API Gaps

1. **No session search endpoint**
2. **No session count endpoint** (separate from project list)
3. **No session archive/restore**
4. **No batch rename**

---

## Recommendations

### For cli-bridge Team

1. Fix `total` and `hasMore` in sessions response
2. Investigate session count discrepancy
3. Add session search API
4. Clarify source vs ID naming convention

### For CodingBridge

1. Don't rely on project `sessionCount` - use API response length
2. Implement client-side pagination with offset
3. Filter `agent-*` sessions more aggressively in UI
4. Add local session count caching
