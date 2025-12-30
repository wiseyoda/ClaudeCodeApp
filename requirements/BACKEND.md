# Backend Setup Requirements

## Overview

The iOS app connects to [cli-bridge](https://github.com/anthropics/claude-code/tree/main/packages/cli-bridge) backend via REST API with SSE streaming. Optional SSH access for file operations.

## Prerequisites

- Deno runtime
- Claude Code CLI installed and authenticated (`claude --version`)
- Network connectivity from iOS device to backend

## Quick Start (Local Development)

```bash
# Start cli-bridge
cd ~/dev/cli-bridge
deno task dev  # Runs on http://localhost:3100

# Verify it's running
curl -s http://localhost:3100/health
# Returns: {"status":"ok","agents":0,...}
```

**iOS App Default:** `http://localhost:3100`

## Installation Options

### Option 1: Local Development (Recommended)

```bash
cd ~/dev/cli-bridge
deno task dev
```

### Option 2: Docker Container (Production/NAS)

Coming soon - cli-bridge Docker deployment for QNAP.

## Network Configuration

### Local Network

For iOS Simulator or device on same network:
- Use `http://localhost:3100` (Simulator)
- Use the backend's local IP (e.g., `http://192.168.1.100:3100`)

### Remote Access via Tailscale

For secure remote access:
1. Install Tailscale on the backend host
2. Advertise the backend's subnet or use the Tailscale IP
3. Install Tailscale on iOS device
4. Connect to backend via Tailscale IP

## Authentication

cli-bridge currently runs without authentication for local development.

### iOS App Configuration

| Setting | Value |
|---------|-------|
| Server URL | `http://localhost:3100` (local dev) |

Production authentication will be documented once cli-bridge is deployed to QNAP.

## API Reference

### Health Check

```
GET /health
```

Response:
```json
{
  "status": "ok",
  "agents": 0,
  "uptime": 12345
}
```

### Create Agent

```
POST /agents
Content-Type: application/json
```

Request:
```json
{
  "cwd": "/home/dev/workspace/my-project"
}
```

Response:
```json
{
  "id": "agent-uuid-here"
}
```

### Send Message (SSE Streaming)

```
POST /agents/:id/message
Content-Type: application/json
Accept: text/event-stream
```

Request:
```json
{
  "message": "Help me fix this bug",
  "sessionId": "optional-session-id",
  "options": {
    "model": "claude-sonnet-4-20250514"
  }
}
```

Response: Server-Sent Events stream

**SSE Event Types:**
| Event | Data | Purpose |
|-------|------|---------|
| `assistant` | `{"text": "..."}` | Streaming text content |
| `tool_use` | `{"name": "...", "input": {...}}` | Tool invocation |
| `tool_result` | `{"output": "..."}` | Tool output |
| `thinking` | `{"text": "..."}` | Reasoning block |
| `result` | `{"sessionId": "...", "usage": {...}}` | Task complete |
| `error` | `{"message": "..."}` | Error message |

### Abort Request

```
POST /agents/:id/abort
```

### List Projects

Projects are discovered from session files in `$HOME/.claude/projects/`.

### Session File Location

```
$HOME/.claude/projects/{encoded-project-path}/{session-id}.jsonl
```

**Path encoding:** `/home/dev/workspace/my-project` -> `-home-dev-workspace-my-project`

Note: The encoded path starts with a dash (`-`).

> **Important**: Always use `$HOME` instead of `~` in SSH commands from Swift code. Tilde expansion doesn't work reliably inside quoted strings. See `CLAUDE.md` for details.

### Registering a New Project

To register a project (done automatically by the iOS app during clone/create):

```bash
# Create the project directory (use $HOME for Swift SSH commands)
mkdir -p "$HOME/.claude/projects/-home-dev-workspace-my-project"

# Create an init session file with cwd
echo '{"type":"init","cwd":"/home/dev/workspace/my-project","timestamp":"2025-12-27T00:00:00.000Z"}' > "$HOME/.claude/projects/-home-dev-workspace-my-project/init.jsonl"
```

The `cwd` field in the session file is what determines the project path displayed in the app.

### Session File Format (JSONL)

Each line in a session file is a JSON object:

```json
{"type":"user","message":{"content":[{"type":"text","text":"user message"}]},"timestamp":"..."}
{"type":"assistant","message":{"content":[{"type":"text","text":"response"}]},"timestamp":"..."}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{...}}]},"timestamp":"..."}
```

**Message Types:**
| Type | Content Type | Description |
|------|--------------|-------------|
| `user` | `text` | User message |
| `user` | `tool_result` | Tool output (use `toolUseResult` field) |
| `assistant` | `text` | Assistant response |
| `assistant` | `tool_use` | Tool invocation |
| `assistant` | `thinking` | Reasoning block |

## SSH Requirements

The iOS app uses SSH for:
- File browser functionality
- Session history loading (optional, API preferred)
- Git clone operations
- Project creation and deletion
- Global search across sessions

### SSH Configuration

1. Ensure sshd is running on the backend
2. Configure SSH credentials in the iOS app settings
3. Recommended: Use SSH key auth (Ed25519, RSA, or ECDSA)

### SSH Key Setup (Recommended)

The app supports importing SSH keys via:
- Paste key content directly
- Import from Files app
- Keychain storage (secure)

Supported key types:
- Ed25519 (recommended)
- RSA (2048+ bits)
- ECDSA

### SSH Commands Used

> **Note**: Use `$HOME` with double quotes in Swift code. Single quotes or `~` won't expand.

| Operation | Command |
|-----------|---------|
| List files | `ls -laF /path/to/directory` |
| Read session | `cat "$HOME/.claude/projects/{path}/{session}.jsonl"` |
| Git clone | `git clone {url} ~/workspace/{name}` |
| Create directory | `mkdir -p /path/to/directory` |
| Delete session | `rm -f "$HOME/.claude/projects/{path}/{session}.jsonl"` |
| Delete project | `rm -rf "$HOME/.claude/projects/{encoded-path}"` |
| Git status | `git -C /path/to/project status --porcelain -b` |
| Git pull | `git -C /path/to/project pull` |
| Global search | `grep -l "query" $HOME/.claude/projects/*/*.jsonl` |
| Claude init | `cd /path && claude init --yes` |

## Troubleshooting

### "Failed to connect to server"

1. Verify backend is running: `curl http://<host>:3100/health`
2. Check firewall allows port 3100
3. Verify Tailscale connection if using remote access
4. Check the server URL in app settings (no trailing slash)

### "No projects found"

1. Open a project with Claude CLI at least once
2. Check `~/.claude/projects/` exists on the backend
3. Verify session files have proper `cwd` field
4. Ensure the username has read access to the projects directory

### Streaming not working

1. Ensure the response is being consumed as SSE stream
2. Check for proxy/load balancer buffering issues
3. Verify the Accept header includes `text/event-stream`

### SSH connection fails

1. Verify sshd is running: `systemctl status sshd`
2. Check credentials in iOS app settings
3. Verify firewall allows port 22
4. Check SSH logs: `tail -f /var/log/auth.log`
5. For key auth: ensure key is imported in app settings

### Project shows with wrong name

1. Check the session file has correct `cwd` field
2. The `cwd` should be the absolute path (e.g., `/home/dev/workspace/my-project`)
3. Recreate the session file if needed

### Clone hangs or times out

1. Verify git is installed on backend
2. Check SSH connectivity to GitHub/GitLab
3. For large repos, the clone may take time - wait for completion
4. The app uses a 10-second timeout for `claude init` after clone

### Git status not updating

1. Ensure the project is a git repository
2. Check SSH connectivity
3. Verify the project path is correct
4. Try pull-to-refresh on the project list

### Global search returns no results

1. Verify SSH is connected
2. Check that session files exist in `~/.claude/projects/`
3. Try a simpler search query
4. Ensure proper permissions on session files
