# Session Management

> How Claude Code sessions work: storage, API, iOS implementation, and advanced features.

**Related:** [BACKEND.md](./BACKEND.md) (API reference), [ARCHITECTURE.md](./ARCHITECTURE.md) (data flow)

## Overview

Sessions are persistent conversation threads stored as JSONL files on the server. The cli-bridge API provides full session management including search, archive, and bulk operations.

## Server-Side Storage

### Location

```
$HOME/.claude/projects/{encoded-path}/{session-id}.jsonl
```

**Path Encoding:** `/home/dev/workspace/ClaudeCodeApp` -> `-home-dev-workspace-ClaudeCodeApp`

> Use `$HOME` instead of `~` in SSH commands. See `.claude/rules/ssh-security.md`.

### Session Types

| Type | Pattern | Source | Typical Count |
|------|---------|--------|---------------|
| User | `{uuid}.jsonl` | iOS app, Claude CLI | 50-100+ |
| Agent | `agent-{id}.jsonl` | Task tool subagents | 200+ |
| Helper | `{uuid}.jsonl` | ClaudeHelper queries | 1 per project |

**Agent Sessions:** Created by Claude CLI's Task tool. Have `isSidechain: true`. Auto-identified by `agent-*` prefix.

**Helper Sessions:** Used by ClaudeHelper for suggestions. One deterministic session per project (hashed from path).

## JSONL Message Format

Each line is a JSON object:

### User Message
```json
{
  "type": "user",
  "message": {
    "role": "user",
    "content": [{"type": "text", "text": "What suggestions do you have?"}]
  },
  "uuid": "52a0fd51-dfdb-4082-89d7-9c91bd353f9e",
  "timestamp": "2025-12-27T06:44:55.883Z"
}
```

### Assistant Message
```json
{
  "type": "assistant",
  "message": {
    "model": "claude-opus-4-5-20251101",
    "role": "assistant",
    "content": [{"type": "text", "text": "Based on my review..."}]
  },
  "uuid": "305cd830-7e3e-45ef-acd9-be48bd2681ef",
  "timestamp": "2025-12-27T06:45:11.812Z"
}
```

## iOS Clean Architecture

```
Views -> SessionStore -> SessionRepository -> CLIBridgeAPIClient -> Backend
         (state)        (data layer)         (HTTP)
```

| Layer | Component | Purpose |
|-------|-----------|---------|
| State | `SessionStore` | Single source of truth, pagination, search, archive |
| Data | `SessionRepository` | Protocol + API implementation |
| Network | `CLIBridgeAPIClient` | HTTP requests |
| View | `SessionPickerViews` | UI with search bar, swipe actions |

### SessionStore (Singleton)

Access via `SessionStore.shared`:

```swift
@Published var sessionsByProject: [String: [ProjectSession]]
@Published var metaByProject: [String: ProjectSessionMeta]
@Published var countsByProject: [String: CLISessionCountResponse]
@Published var searchResults: [String: CLISessionSearchResponse]
@Published var showArchivedSessions: Bool
```

**Core Methods:**
| Method | Purpose |
|--------|---------|
| `loadSessions(for:)` | Fetch from API |
| `loadMore(for:)` | Pagination |
| `deleteSession(_:for:)` | Optimistic delete |
| `displaySessions(for:)` | Filtered/sorted for UI |

**Search & Archive Methods:**
| Method | Purpose |
|--------|---------|
| `searchSessions(for:query:)` | Full-text search |
| `archiveSession(_:for:)` | Soft delete with optimistic update |
| `unarchiveSession(_:for:)` | Restore archived session |
| `loadSessionCounts(for:)` | Get count breakdown by source |

### Session Metadata

`CLISessionMetadata` includes:

```swift
let id: String
let projectPath: String
let source: SessionSource    // .user, .agent, .helper
let messageCount: Int
let summary: String?
let lastModified: String
let archivedAt: String?      // nil = not archived
let parentSessionId: String? // for session lineage
```

Computed properties:
- `isArchived` - true if `archivedAt` is set
- `archivedDate` - parsed Date from ISO string

## Session API Endpoints

See [BACKEND.md](./BACKEND.md) for full API reference.

| Endpoint | Purpose |
|----------|---------|
| `GET /projects/:path/sessions` | List with pagination |
| `GET /projects/:path/sessions/count` | Count by source |
| `GET /projects/:path/sessions/search?q=...` | Full-text search |
| `POST /projects/:path/sessions/:id/archive` | Soft delete |
| `POST /projects/:path/sessions/:id/unarchive` | Restore |
| `POST /projects/:path/sessions/bulk` | Bulk operations |

### Query Parameters

| Parameter | Values | Default | Description |
|-----------|--------|---------|-------------|
| `source` | user/agent/helper/all | all | Filter by source |
| `includeArchived` | true/false | false | Include archived |
| `archivedOnly` | true/false | false | Only archived |
| `limit` | 1-500 | 100 | Page size |
| `offset` | 0+ | 0 | Pagination offset |

## Session Filtering

Sessions filtered for display to exclude:
- Helper sessions (matched by `ClaudeHelper.createHelperSessionId`)
- Empty sessions (`messageCount < 1`)
- Agent sessions (by default, toggleable)
- Archived sessions (by default, toggleable)

```swift
// Models.swift
extension Array where Element == ProjectSession {
    func filterForDisplay(projectPath: String, activeSessionId: String?) -> [ProjectSession]
}
```

## UI Features

### Search Bar
- Debounced input (300ms)
- Server-side full-text search
- Results with match snippets
- Tap to navigate to session

### Archive Toggle
- Toolbar button: "Show Archived"
- Archived sessions styled differently (dimmed, archive icon)

### Swipe Actions
```swift
.swipeActions(edge: .leading) {
    Button { archiveSession(session) }
        label: { Label("Archive", systemImage: "archivebox") }
}
.swipeActions(edge: .trailing) {
    Button(role: .destructive) { deleteSession(session) }
        label: { Label("Delete", systemImage: "trash") }
}
```

## Session Persistence

| Store | Key | Purpose |
|-------|-----|---------|
| UserDefaults | `sessionId_{encoded-path}` | Last active session |
| MessageStore | `{encoded-path}.json` | Chat history (50 messages) |

## Key Files

| File | Purpose |
|------|---------|
| `SessionStore.swift` | State management, search, archive |
| `SessionRepository.swift` | Protocol + API implementation |
| `CLIBridgeAPIClient.swift` | HTTP requests |
| `CLIBridgeTypes.swift` | Session types and responses |
| `SessionPickerViews.swift` | Session picker UI |
| `Models.swift` | `ProjectSession`, filtering |

## Common Issues

### Sessions Not Appearing
1. Check `SessionStore.shared.sessionsByProject` has data
2. Verify `displaySessions(for:)` filtering
3. Ensure WebSocket `result` events are handled
4. Check `activeSessionIds[path]` is passed to filter

### Wrong Session Counts
1. Use `loadSessionCounts(for:)` for accurate counts
2. Check `metaByProject[path]?.total` for pagination total

### Search Not Working
1. Verify backend is v0.1.11+ (search endpoint added)
2. Check `searchResults[projectPath]` for results
3. Ensure query is non-empty

### Archive/Unarchive Issues
1. Check `archivedAt` field in session metadata
2. Verify `showArchivedSessions` toggle state
3. Check API response for errors

## Testing Sessions

```bash
# SSH to server
ssh claude-dev
cd $HOME/.claude/projects/-home-dev-workspace-ClaudeCodeApp

# Count all sessions
ls -1 *.jsonl | wc -l

# Count user sessions (exclude agents)
ls -1 *.jsonl | grep -v '^agent-' | wc -l

# View session content
cat {session-id}.jsonl | jq .
```
