# Backend Setup Requirements

## Overview

The iOS app requires a running [claude-code-webui](https://github.com/sugyan/claude-code-webui) backend server that the app connects to via HTTP/WebSocket, plus SSH access for file operations.

## Prerequisites

- Node.js 20+
- Claude CLI installed and authenticated
- SSH server (sshd) running
- Network connectivity from iOS device to backend

## Installation Options

### Option 1: Local Machine

```bash
npm install -g claude-code-webui
claude-code-webui --host 0.0.0.0 --port 8080
```

### Option 2: Docker Container (Recommended for NAS)

```dockerfile
FROM node:20-slim

RUN apt-get update && apt-get install -y openssh-server git curl sudo tmux \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code claude-code-webui

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

## API Reference

### GET /api/projects

Returns list of available projects.

**Response:**
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

### POST /api/chat

Send a message and receive streaming response.

**Request:**
```json
{
  "message": "Help me fix this bug",
  "sessionId": "optional-session-id",
  "requestId": "unique-request-id",
  "workingDirectory": "/home/dev/workspace/my-project",
  "allowedTools": null
}
```

**Response:** Streaming JSON lines (newline-delimited)

```json
{"type": "system", "session_id": "abc123"}
{"type": "assistant", "message": {"content": [{"type": "text", "text": "Let me help..."}]}}
{"type": "result", "subtype": "success"}
```

### POST /api/abort/:requestId

Cancel an ongoing request.

## Project Registration

Projects appear in the iOS app when they have session files in `~/.claude/projects/`.

### Session File Location

```
~/.claude/projects/{encoded-project-path}/{session-id}.jsonl
```

**Path encoding:** `/home/dev/workspace/my-project` → `-home-dev-workspace-my-project`

Note: The encoded path starts with a dash (`-`).

### Registering a New Project

To register a project (done automatically by the iOS app during clone/create):

```bash
# Create the project directory
mkdir -p ~/.claude/projects/-home-dev-workspace-my-project

# Create an init session file with cwd
echo '{"type":"init","cwd":"/home/dev/workspace/my-project","timestamp":"2024-12-27T00:00:00.000Z"}' > ~/.claude/projects/-home-dev-workspace-my-project/init.jsonl
```

The `cwd` field in the session file is what determines the project path displayed in the app.

### Session File Format (JSONL)

Each line in a session file is a JSON object:

```json
{"type":"user","message":{"content":[{"type":"text","text":"user message"}]},"timestamp":"..."}
{"type":"assistant","message":{"content":[{"type":"text","text":"response"}]},"timestamp":"..."}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{...}}]},"timestamp":"..."}
```

## SSH Requirements

The iOS app uses SSH for:
- File browser functionality
- Session history loading (workaround for CORS issues)
- Git clone operations
- Project creation and deletion

### SSH Configuration

1. Ensure sshd is running on the backend
2. Configure SSH credentials in the iOS app settings
3. Recommended: Use key-based auth in production (currently password-only)

### SSH Commands Used

| Operation | Command |
|-----------|---------|
| List files | `ls -laF /path/to/directory` |
| Read session | `cat ~/.claude/projects/{path}/{session}.jsonl` |
| Git clone | `git clone {url} ~/workspace/{name}` |
| Create directory | `mkdir -p /path/to/directory` |
| Delete session | `rm -f ~/.claude/projects/{path}/{session}.jsonl` |
| Delete project | `rm -rf ~/.claude/projects/{encoded-path}` |

## Troubleshooting

### "Failed to connect to server"

1. Verify backend is running: `curl http://<host>:8080/api/projects`
2. Check firewall allows port 8080
3. Verify Tailscale connection if using remote access

### "No projects found"

1. Open a project with Claude CLI at least once
2. Check `~/.claude/projects/` exists on the backend
3. Verify session files have proper `cwd` field

### Streaming not working

1. Ensure backend is using `--output-format stream-json`
2. Check for proxy/load balancer buffering issues

### SSH connection fails

1. Verify sshd is running: `systemctl status sshd`
2. Check credentials in iOS app settings
3. Verify firewall allows port 22
4. Check SSH logs: `tail -f /var/log/auth.log`

### Project shows with wrong name

1. Check the session file has correct `cwd` field
2. The `cwd` should be the absolute path (e.g., `/home/dev/workspace/my-project`)
3. Recreate the session file if needed

### Clone hangs or times out

1. Verify git is installed on backend
2. Check SSH connectivity to GitHub/GitLab
3. For large repos, the clone may take time - wait for completion
4. The app uses a 10-second timeout for `claude init` after clone
