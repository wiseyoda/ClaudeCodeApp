# CLI-Bridge Session System Analysis

> Analysis of session handling in the cli-bridge backend (~/dev/cli-bridge)

## Overview

CLI-Bridge manages sessions stored in `~/.claude/projects/{encoded-path}/{uuid}.jsonl` files. Sessions are the core unit of conversation persistence, enabling resume functionality with the Claude CLI.

---

## 1. Session Counting

**Implementation:** `src/sessions/manager.ts:280-298`

```typescript
// Counts .jsonl files in project session directory
export async function countSessions(projectPath: string): Promise<number>
```

- Returns 0 if directory missing/inaccessible
- Called during project discovery for each project
- Used in `GET /projects` response

**Integration:** `src/projects/discovery.ts:88-90`
- Session count included in project list response
- Caches count with project data

---

## 2. Recent Sessions API

**Endpoint:** `GET /sessions/recent`
**Handler:** `src/routes/sessions.ts:32-57`

**Parameters:**
| Param | Default | Max | Description |
|-------|---------|-----|-------------|
| `limit` | 10 | 50 | Number of sessions |
| `source` | "all" | - | Filter: user\|agent\|helper\|all |

**Implementation:** `src/sessions/manager.ts:402-432`
- Fetches sessions from ALL projects in parallel
- Sorts by `lastActivityAt` descending
- Returns `SessionWithProject[]` (session + projectPath)

**"Recent" Definition:**
- Based on `lastActivityAt` ISO timestamp
- Last message time, not file modification time
- Extracted from JSONL content

---

## 3. Sessions by Project

**Endpoint:** `GET /projects/:encodedPath/sessions`
**Handler:** `src/routes/sessions.ts:62-87`

**Parameters:**
| Param | Default | Description |
|-------|---------|-------------|
| `limit` | 50 | Max sessions per page |
| `offset` | 0 | Pagination offset |
| `source` | "user" | Filter by source |

**Implementation:** `src/sessions/manager.ts:20-78`
1. Lists all `.jsonl` files in project directory
2. Extracts metadata from each file
3. Filters by source
4. Sorts by `lastActivityAt` desc
5. Applies pagination

---

## 4. Session Creation

**Location:** `src/agents/agent.ts:73-77`

```typescript
// UUID generated if not resuming
this._sessionId = options.sessionId || crypto.randomUUID();
```

**Flow:**
1. Client sends `start` message with `projectPath`
2. If `sessionId` provided → resume existing
3. Otherwise → generate UUID v4
4. First message creates JSONL file (SDK handles this)

**Supplementary Metadata:**
- File: `~/.cli-bridge/sessions/{sessionId}.json`
- Contains: `source` (user|agent|helper), `customTitle`
- Handler: `src/sessions/metadata.ts:197-232`

---

## 5. Session File Format (.JSONL)

**Structure:** Line-delimited JSON

**Entry Example:**
```json
{
  "parentUuid": null,
  "isSidechain": true,
  "userType": "external",
  "cwd": "/Users/ppatterson/dev/project",
  "sessionId": "09851aa1-1b3c-435c-bd90-1b636ee9bd3b",
  "version": "2.0.65",
  "gitBranch": "main",
  "agentId": "a3a1c6f",
  "type": "user",
  "message": {
    "role": "user",
    "content": "Hello"
  },
  "uuid": "055ae63c-213a-4c28-bd0e-4ed1064e60d4",
  "timestamp": "2025-12-11T21:24:11.325Z"
}
```

**Key Fields:**
| Field | Purpose |
|-------|---------|
| `uuid` | Message ID |
| `timestamp` | ISO 8601 message time |
| `type` | "user" or "assistant" |
| `message.content` | Text or content blocks array |
| `model` | Model name (assistant only) |

**Metadata Extraction:** `src/sessions/metadata.ts:15-127`
- Parses all lines for first/last messages
- Extracts timestamps, model, message count

---

## 6. Session Lifecycle

### States
```
starting → ready → running → done/error
```
(Agent-level, not session-level)

### Operations

**Update:**
- Append-only to JSONL
- `lastActivityAt` updates on new message
- Custom title via `PUT /projects/:path/sessions/:id`

**Delete:**
- `DELETE /projects/:encodedPath/sessions/:id`
- Removes JSONL file
- Broadcasts `session_event` with action "deleted"
- Handler: `src/sessions/manager.ts:116-136`

**Bulk Delete:**
- `DELETE /projects/:encodedPath/sessions?filter=older_than&days=30`
- Handler: `src/sessions/manager.ts:141-158`

**No Archival:** Sessions are permanently deleted

---

## 7. Path Encoding

**Encoding:** `src/utils/paths.ts:53-55`
```typescript
// All slashes → dashes
export function encodeProjectPath(path: string): string {
  return path.replace(/\//g, "-");
}
```

**Examples:**
| Original | Encoded |
|----------|---------|
| `/Users/ppatterson/dev/project` | `-Users-ppatterson-dev-project` |
| `/home/cli-bridge/repo` | `-home-cli-bridge-repo` |

**Decoding Ambiguity:**
- Paths with dashes are ambiguous when decoded
- Resolution: `src/sessions/manager.ts:194-260`
  1. Try naive decode (all dashes → slashes)
  2. Try keeping last 1-3 components with dashes
  3. Verify path exists on filesystem
  4. Fall back to naive decode

---

## 8. Complete API Reference

### REST Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/sessions/recent` | Recent sessions across all projects |
| `GET` | `/projects/:path/sessions` | List project sessions (paginated) |
| `GET` | `/projects/:path/sessions/:id` | Get single session metadata |
| `PUT` | `/projects/:path/sessions/:id` | Update session (custom title) |
| `DELETE` | `/projects/:path/sessions/:id` | Delete single session |
| `DELETE` | `/projects/:path/sessions` | Bulk delete (older_than filter) |
| `GET` | `/projects/:path/sessions/:id/export` | Export as markdown/JSON |

### WebSocket Messages

| Type | Direction | Purpose |
|------|-----------|---------|
| `subscribe_sessions` | Client→Server | Subscribe to events |
| `session_event` | Server→Client | Broadcast changes |

**Session Event Actions:** `created`, `updated`, `deleted`

---

## 9. Session State & Source Types

### SessionMetadata Interface
```typescript
interface SessionMetadata {
  id: string;                    // UUID
  projectPath: string;
  source: SessionSource;         // "user" | "agent" | "helper"
  createdAt: string;             // ISO timestamp
  lastActivityAt: string;        // ISO timestamp
  messageCount: number;
  title?: string;                // First user msg, truncated
  customTitle?: string;          // User override
  lastUserMessage?: string;      // Truncated 200 chars
  lastAssistantMessage?: string; // Truncated 200 chars
  model?: string;
}
```

### Source Values
| Source | Description |
|--------|-------------|
| `user` | Created by user via CLI Bridge or Claude CLI |
| `agent` | Internal agent session (warmup) |
| `helper` | Helper mode session (reused per project) |

### Helper Sessions
- One per project
- Stored in `~/.cli-bridge/helpers/`
- Keyed by project path hash
- Reused across connections
- Marked `source: "helper"` in supplementary metadata

---

## 10. Error Handling

| Scenario | Response |
|----------|----------|
| Session not found | `404` + `{error: "Session not found"}` |
| Directory missing | Returns `[]` or count `0` |
| Malformed JSONL line | Skips line, continues |
| Missing timestamps | Falls back to file mtime |
| Export failure | `500` + code: "EXPORT_FAILED" |

---

## 11. Performance Characteristics

| Operation | Expected Time |
|-----------|---------------|
| Session list (100 sessions) | <100ms |
| History replay (1000 messages) | <2s |
| Export (1000 message session) | <5s |

---

## 12. Key Files Reference

| File | Purpose |
|------|---------|
| `sessions/manager.ts` | Core CRUD operations |
| `sessions/metadata.ts` | JSONL parsing |
| `sessions/events.ts` | WebSocket events |
| `routes/sessions.ts` | REST handlers |
| `websocket/handlers/sessions.ts` | WS subscriptions |
| `utils/paths.ts` | Path encoding |
| `projects/discovery.ts` | Project scanning |
| `agents/agent.ts` | Session ID generation |
| `agents/helper.ts` | Helper session management |

---

## Potential Enhancement Areas

### For Feature Requests to CLI-Bridge Team

1. **Session Search API** - Search sessions by content/title
2. **Session Tags/Labels** - Categorize sessions beyond source
3. **Session Archive** - Archive instead of delete
4. **Batch Rename** - Rename multiple sessions
5. **Session Stats** - Token counts, tool usage, duration
6. **Improved Path Encoding** - Base64 or URL encoding to avoid ambiguity
7. **Session Merge** - Combine related sessions
8. **Session Duplicate** - Clone a session for branching
