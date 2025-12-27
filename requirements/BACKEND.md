# Backend Setup Requirements

## Overview

The iOS app requires a running [claudecodeui](https://github.com/siteboon/claudecodeui) backend server that the app connects to via HTTP/WebSocket, plus SSH access for file operations.

## Prerequisites

- Node.js 20+
- Claude CLI installed and authenticated
- SSH server (sshd) running
- Network connectivity from iOS device to backend

## Installation Options

### Option 1: Local Machine

```bash
git clone https://github.com/siteboon/claudecodeui.git
cd claudecodeui && npm install && npm run build && npm start
```

### Option 2: Docker Container (Recommended for NAS)

```dockerfile
FROM node:20-slim

RUN apt-get update && apt-get install -y openssh-server git curl sudo tmux \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code

# ... (see full Dockerfile in deployment docs)
```

### Option 3: QNAP NAS Container

See the QNAP deployment guide for a complete Docker Compose setup with:
- Auto-starting WebUI
- Persistent Claude credentials
- Tailscale integration for secure remote access

## Network Configuration

### Local Network

If iOS device and backend are on the same network:
- Use the backend's local IP (e.g., `http://192.168.1.100:8080`)

### Remote Access via Tailscale

For secure remote access:
1. Install Tailscale on the backend host
2. Advertise the backend's subnet or use the Tailscale IP
3. Install Tailscale on iOS device
4. Connect to backend via Tailscale IP (e.g., `http://10.0.3.2:8080`)

## Authentication

The backend supports two authentication methods:

### JWT (Username/Password) - Used by iOS App

```
POST /api/auth/login
Content-Type: application/json

{"username": "admin", "password": "yourpassword"}

Response: {"success": true, "token": "eyJ..."}
```

- Use `Authorization: Bearer <jwt_token>` header for API calls
- Required for `/api/projects`, `/api/settings`, etc.
- **This is what the iOS app uses**

### API Keys (`ck_...`) - Agent API Only

- Created in Web UI: Settings > API Keys
- Use `X-API-Key: ck_...` header
- **Only works for `/api/agent/*` endpoints**
- Used for external integrations (n8n, etc.)
- **NOT for iOS app - leave API Key field empty!**

### iOS App Configuration

| Setting | Value |
|---------|-------|
| Server URL | `http://10.0.3.2:8080` (your server) |
| API Key | **Leave empty** |
| Username | Your web UI username |
| Password | Your web UI password |

The app authenticates via JWT automatically when you provide username/password.

## API Reference

### Authentication

```
POST /api/auth/login
```

Request:
```json
{"username": "admin", "password": "yourpassword"}
```

Response:
```json
{"success": true, "token": "eyJhbGciOiJIUzI1NiIs..."}
```

### Projects

```
GET /api/projects
Authorization: Bearer <token>
```

Response:
```json
{
  "projects": [
    {
      "path": "/home/dev/workspace/my-project",
      "encodedName": "-home-dev-workspace-my-project"
    }
  ]
}
```

### WebSocket Chat

Connect to: `ws://host:port/ws?token=<jwt_token>`

**Send Message:**
```json
{
  "type": "claude-command",
  "message": "Help me fix this bug",
  "cwd": "/home/dev/workspace/my-project",
  "sessionId": "optional-session-id",
  "permissionMode": "default",
  "options": {
    "model": "claude-sonnet-4-20250514"
  }
}
```

**Response Types:**
| Type | Purpose |
|------|---------|
| `claude-response` | Streaming content |
| `claude-complete` | Task finished |
| `token-budget` | Usage stats |
| `error` | Error message |

### Abort Request

```
POST /api/abort/:requestId
```

### Known API Limitations

**CORS Issue:** The backend CORS config only allows `Content-Type` header, NOT `Authorization`.

| Endpoint | Auth Status |
|----------|-------------|
| `GET /api/projects` | Works with Bearer token |
| `GET /api/projects/:project/histories` | **BROKEN** - CORS blocks Authorization |
| `GET /api/projects/:project/histories/:sessionId` | **BROKEN** - Returns HTML |

**Workaround:** The iOS app loads session history via SSH instead.

## Project Registration

Projects appear in the iOS app when they have session files in `~/.claude/projects/`.

### Session File Location

```
~/.claude/projects/{encoded-project-path}/{session-id}.jsonl
```

**Path encoding:** `/home/dev/workspace/my-project` -> `-home-dev-workspace-my-project`

Note: The encoded path starts with a dash (`-`).

### Registering a New Project

To register a project (done automatically by the iOS app during clone/create):

```bash
# Create the project directory
mkdir -p ~/.claude/projects/-home-dev-workspace-my-project

# Create an init session file with cwd
echo '{"type":"init","cwd":"/home/dev/workspace/my-project","timestamp":"2025-12-27T00:00:00.000Z"}' > ~/.claude/projects/-home-dev-workspace-my-project/init.jsonl
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
- Session history loading (workaround for CORS issues)
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

| Operation | Command |
|-----------|---------|
| List files | `ls -laF /path/to/directory` |
| Read session | `cat ~/.claude/projects/{path}/{session}.jsonl` |
| Git clone | `git clone {url} ~/workspace/{name}` |
| Create directory | `mkdir -p /path/to/directory` |
| Delete session | `rm -f ~/.claude/projects/{path}/{session}.jsonl` |
| Delete project | `rm -rf ~/.claude/projects/{encoded-path}` |
| Git status | `git -C /path/to/project status --porcelain -b` |
| Git pull | `git -C /path/to/project pull` |
| Global search | `grep -l "query" ~/.claude/projects/*/*.jsonl` |
| Claude init | `cd /path && claude init --yes` |

## Troubleshooting

### "Failed to connect to server"

1. Verify backend is running: `curl http://<host>:8080/api/projects`
2. Check firewall allows port 8080
3. Verify Tailscale connection if using remote access
4. Check the server URL in app settings (no trailing slash)

### "Authentication failed"

1. Verify username/password are correct
2. Ensure you're using username/password, NOT API key
3. Try logging in via web UI to confirm credentials
4. Check the JWT token hasn't expired

### "No projects found"

1. Open a project with Claude CLI at least once
2. Check `~/.claude/projects/` exists on the backend
3. Verify session files have proper `cwd` field
4. Ensure the username has read access to the projects directory

### Streaming not working

1. Ensure backend is using `--output-format stream-json`
2. Check for proxy/load balancer buffering issues
3. Verify WebSocket connection is established

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
