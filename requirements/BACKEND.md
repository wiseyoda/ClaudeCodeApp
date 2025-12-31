# Backend Setup Requirements

> cli-bridge REST API with SSE streaming for Claude Code iOS client.

**Related:** [SESSIONS.md](./SESSIONS.md) (session details), [ARCHITECTURE.md](./ARCHITECTURE.md) (data flow)

## Overview

The iOS app connects to [cli-bridge](https://github.com/anthropics/claude-code/tree/main/packages/cli-bridge) via REST API with SSE streaming. Optional SSH for file operations.

## Prerequisites

- Deno runtime
- Claude Code CLI installed and authenticated (`claude --version`)
- Network connectivity from iOS device to backend

## Quick Start

```bash
# Start cli-bridge
cd ~/dev/cli-bridge
deno task dev  # Runs on http://localhost:3100

# Verify
curl -s http://localhost:3100/health
```

**iOS App Default:** `http://localhost:3100`

## API Reference

**OpenAPI Spec:** `http://localhost:3100/openapi.json`
**Interactive Docs:** `http://localhost:3100/docs`

### Health Check

```
GET /health
```

```json
{"status": "ok", "agents": 0, "uptime": 12345}
```

### Create Agent

```
POST /agents
Content-Type: application/json

{"cwd": "/home/dev/workspace/my-project"}
```

Response: `{"id": "agent-uuid-here"}`

### Send Message (SSE Streaming)

```
POST /agents/:id/message
Content-Type: application/json
Accept: text/event-stream

{
  "message": "Help me fix this bug",
  "sessionId": "optional-session-id",
  "options": {"model": "claude-sonnet-4-20250514"}
}
```

**SSE Event Types:**
| Event | Data | Purpose |
|-------|------|---------|
| `assistant` | `{"text": "..."}` | Streaming text |
| `tool_use` | `{"name": "...", "input": {...}}` | Tool invocation |
| `tool_result` | `{"output": "..."}` | Tool output |
| `thinking` | `{"text": "..."}` | Reasoning block |
| `result` | `{"sessionId": "...", "usage": {...}}` | Task complete |
| `error` | `{"message": "..."}` | Error |

### Abort Request

```
POST /agents/:id/abort
```

---

## Session API

### List Sessions

```
GET /projects/:path/sessions
```

**Query Parameters:**
| Parameter | Values | Default | Description |
|-----------|--------|---------|-------------|
| `source` | user/agent/helper/all | all | Filter by source |
| `limit` | 1-500 | 100 | Page size |
| `offset` | 0+ | 0 | Pagination offset |
| `includeArchived` | true/false | false | Include archived |
| `archivedOnly` | true/false | false | Only archived |
| `parentSessionId` | uuid | - | Filter by parent |

**Response:**
```json
{
  "sessions": [...],
  "total": 145,
  "hasMore": true
}
```

### Get Session Count

```
GET /projects/:path/sessions/count
GET /projects/:path/sessions/count?source=user
```

**Response:**
```json
{
  "total": 145,
  "user": 5,
  "agent": 140,
  "helper": 0
}
```

### Search Sessions

```
GET /projects/:path/sessions/search?q=authentication&limit=20
```

**Response:**
```json
{
  "query": "authentication",
  "total": 3,
  "hasMore": false,
  "results": [
    {
      "sessionId": "uuid",
      "projectPath": "/home/dev/project",
      "score": 0.95,
      "matches": [
        {
          "messageId": "msg-uuid",
          "role": "user",
          "snippet": "...implement authentication...",
          "timestamp": "2025-12-30T10:00:00Z"
        }
      ]
    }
  ]
}
```

### Archive Session

```
POST /projects/:path/sessions/:id/archive
```

**Response:** Updated `SessionMetadata` with `archivedAt` timestamp.

### Unarchive Session

```
POST /projects/:path/sessions/:id/unarchive
```

**Response:** Updated `SessionMetadata` with `archivedAt` cleared.

### Get Session Children (Lineage)

```
GET /projects/:path/sessions/:id/children
```

Returns sessions with `parentSessionId` matching the given session.

### Bulk Operations

```
POST /projects/:path/sessions/bulk
Content-Type: application/json

{
  "sessionIds": ["uuid1", "uuid2", "uuid3"],
  "operation": {
    "action": "archive"
  }
}
```

**Actions:** `archive`, `unarchive`, `delete`, `update` (with `customTitle`)

**Response:**
```json
{
  "success": ["uuid1", "uuid2"],
  "failed": [{"sessionId": "uuid3", "error": "Not found"}]
}
```

### Export Session

```
GET /projects/:path/sessions/:id/export
GET /projects/:path/sessions/:id/export?includeStructuredContent=true
```

Returns full session history as JSON.

### Update Session

```
PUT /projects/:path/sessions/:id
Content-Type: application/json

{"customTitle": "My Session Name"}
```

### Delete Session

```
DELETE /projects/:path/sessions/:id
```

### Bulk Delete (Legacy)

```
DELETE /projects/:path/sessions?filter=older_than&days=30
```

---

## Session Metadata Schema

```typescript
interface SessionMetadata {
  id: string;
  projectPath: string;
  source: "user" | "agent" | "helper";
  messageCount: number;
  summary?: string;
  lastModified: string;          // ISO timestamp
  archivedAt?: string;           // ISO timestamp, null if not archived
  parentSessionId?: string;      // For session lineage
}
```

**Source Field Logic:**
1. Sessions with `agent-*` ID prefix → `source: "agent"`
2. Supplementary metadata file has explicit source → use it
3. Helper session detection → `source: "helper"`
4. Default → `source: "user"`

---

## Session File Location

```
$HOME/.claude/projects/{encoded-project-path}/{session-id}.jsonl
```

**Path encoding:** `/home/dev/workspace/my-project` → `-home-dev-workspace-my-project`

> Use `$HOME` instead of `~` in SSH commands. See `.claude/rules/ssh-security.md`.

---

## SSH Requirements

SSH used for file browser, git operations, and global search.

### Configuration

1. Ensure sshd is running on backend
2. Configure SSH credentials in iOS app settings
3. Recommended: SSH key auth (Ed25519, RSA, ECDSA)

### Common SSH Commands

| Operation | Command |
|-----------|---------|
| List files | `ls -laF /path/to/directory` |
| Read session | `cat "$HOME/.claude/projects/{path}/{session}.jsonl"` |
| Git clone | `git clone {url} ~/workspace/{name}` |
| Delete session | `rm -f "$HOME/.claude/projects/{path}/{session}.jsonl"` |
| Git status | `git -C /path/to/project status --porcelain -b` |
| Global search | `grep -l "query" $HOME/.claude/projects/*/*.jsonl` |

---

## Network Configuration

### Local Network

- Simulator: `http://localhost:3100`
- Device on same network: `http://192.168.1.x:3100`

### Remote Access via Tailscale

1. Install Tailscale on backend host
2. Install Tailscale on iOS device
3. Connect via Tailscale IP

---

## Troubleshooting

### "Failed to connect to server"

1. Verify backend: `curl http://<host>:3100/health`
2. Check firewall allows port 3100
3. Check server URL in app settings (no trailing slash)

### "No projects found"

1. Open a project with Claude CLI at least once
2. Check `~/.claude/projects/` exists on backend
3. Verify session files have proper `cwd` field

### Streaming not working

1. Ensure response consumed as SSE stream
2. Check for proxy/load balancer buffering
3. Verify Accept header includes `text/event-stream`

### SSH connection fails

1. Verify sshd: `systemctl status sshd`
2. Check credentials in iOS app settings
3. Verify firewall allows port 22
4. For key auth: ensure key is imported in app settings

### Session counts don't match

1. Use `/sessions/count` endpoint for accurate counts
2. Old issue with path resolution fixed in cli-bridge v0.1.11+
