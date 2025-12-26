# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Native iOS client for [claude-code-webui](https://github.com/sugyan/claude-code-webui), enabling Claude Code access from iPhone/iPad. The app connects to a backend server (typically running on a NAS via Tailscale) and provides real-time streaming chat with tool visibility. Includes a built-in SSH terminal for direct server access.

## Build & Run

Open `ClaudeCodeApp.xcodeproj` in Xcode 15+ and press Cmd+R. Target iOS 17.0+.

**Dependencies:** Citadel (via Swift Package Manager) - pure Swift SSH library for terminal functionality.

## Architecture

```
ClaudeCodeApp/
├── ClaudeCodeAppApp.swift  # App entry, injects AppSettings
├── AppSettings.swift       # @AppStorage for server URL, SSH, font size, mode
├── Models.swift            # Project, ChatMessage, ClaudeStreamEvent, AnyCodable
├── APIClient.swift         # HTTP client with URLSession streaming
├── ContentView.swift       # Project list + Settings sheet
├── ChatView.swift          # Message list + streaming display + markdown rendering
├── TerminalView.swift      # SSH terminal with CLI theme
├── SSHManager.swift        # SSH connection handling via NMSSH
└── Theme.swift             # CLI-inspired dark theme colors
```

### Data Flow

1. **AppSettings** stores server URL, SSH credentials, font size, mode preferences
2. **APIClient** is injected into views, uses AppSettings for base URL
3. **ContentView** fetches projects on appear, navigates to ChatView or TerminalView
4. **ChatView** manages session state, streams responses via `URLSession.bytes`
5. **TerminalView** provides interactive SSH shell via SSHManager

### API Integration

The app expects a claude-code-webui backend with these endpoints:
- `GET /api/projects` - List projects
- `POST /api/chat` - Send message (streams newline-delimited JSON)
- `POST /api/abort/:requestId` - Cancel request

### Streaming JSON Protocol

Responses are newline-delimited JSON wrapped in `{"type":"claude_json","data":{...}}`. The `StreamLine` struct unwraps this envelope, and `ClaudeStreamEvent` handles the inner payload with types: `system`, `assistant`, `user`, `result`.

## Features

### Claude Code Chat
- Real-time streaming responses
- Tool use visualization (collapsible)
- System init info (model, session, tools)
- Result summary with cost/tokens
- Markdown rendering (tables, headers, code blocks, lists)

### SSH Terminal
- Native SSH client via Citadel (pure Swift)
- Special keys bar (Ctrl+C, Tab, arrows, etc.)
- Password authentication
- Credentials saved locally
- Auto-connect with saved credentials

### Settings
- Server URL configuration
- Font size (XS/S/M/L/XL)
- SSH host/port/username/password
- Claude mode selector (normal/plan/bypass)

## Key Patterns

- **@StateObject** for APIClient and SSHManager (owns instances)
- **@EnvironmentObject** for AppSettings (shared across views)
- **async/await** with `URLSession.bytes` for streaming
- **StreamEvent enum** bridges raw JSON to UI updates
- **CLITheme** provides consistent dark mode styling
- ATS disabled in Info.plist for local/Tailscale HTTP connections

## Backend Setup

See `requirements/BACKEND.md`. Quick start:
```bash
npm install -g claude-code-webui
claude-code-webui --host 0.0.0.0 --port 8080
```

SSH requires standard sshd running on the server.
