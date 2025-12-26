# Backend Setup Requirements

## Overview

The iOS app requires a running [claude-code-webui](https://github.com/sugyan/claude-code-webui) backend server that the app connects to via HTTP.

## Prerequisites

- Node.js 20+
- Claude CLI installed and authenticated
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

## Troubleshooting

### "Failed to connect to server"

1. Verify backend is running: `curl http://<host>:8080/api/projects`
2. Check firewall allows port 8080
3. Verify Tailscale connection if using remote access

### "No projects found"

1. Open a project with Claude CLI at least once
2. Check `~/.claude.json` exists on the backend

### Streaming not working

1. Ensure backend is using `--output-format stream-json`
2. Check for proxy/load balancer buffering issues
