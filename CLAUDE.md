# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Native iOS client for [claude-code-webui](https://github.com/sugyan/claude-code-webui), enabling Claude Code access from iPhone/iPad. The app connects to a backend server (typically running on a NAS via Tailscale) via WebSocket and provides real-time streaming chat with tool visibility. Includes a built-in SSH terminal for direct server access.

## Build & Run

Open `ClaudeCodeApp.xcodeproj` in Xcode 15+ and press Cmd+R. Target iOS 17.0+.

**Dependencies:** Citadel (via Swift Package Manager) - pure Swift SSH library for terminal functionality.

## Architecture

```
ClaudeCodeApp/
├── ClaudeCodeAppApp.swift  # App entry, notification permissions, injects AppSettings
├── AppSettings.swift       # @AppStorage for server URL, SSH, font size, mode
├── Models.swift            # Project, ChatMessage, MessageStore, WS message types
├── APIClient.swift         # HTTP client for project listing
├── WebSocketManager.swift  # WebSocket connection, message parsing, reconnection
├── SpeechManager.swift     # Voice input using iOS Speech framework
├── ContentView.swift       # Project list + Settings sheet
├── ChatView.swift          # Message list, streaming, markdown, voice, images
├── TerminalView.swift      # SSH terminal with CLI theme
├── SSHManager.swift        # SSH connection handling via Citadel
└── Theme.swift             # CLI-inspired dark theme colors
```

### Data Flow

1. **AppSettings** stores server URL, SSH credentials, font size, mode preferences
2. **WebSocketManager** handles real-time communication with claudecodeui backend
3. **ContentView** fetches projects via APIClient, navigates to ChatView or TerminalView
4. **ChatView** manages session state, streams responses via WebSocket callbacks
5. **MessageStore** persists last 50 messages per project to UserDefaults
6. **TerminalView** provides interactive SSH shell via SSHManager

### WebSocket Communication

The app uses WebSocket for real-time chat with the backend:
- `WSClaudeCommand` - sent to server with message, cwd, sessionId, permissionMode
- `WSMessage` - received from server with type (claude-response, claude-complete, etc.)
- Auto-reconnection with exponential backoff (1s → 2s → 4s → 8s max + jitter)

## Features

### Claude Code Chat
- Real-time streaming responses via WebSocket
- Tool use visualization (collapsible, Grep/Glob collapsed by default)
- Diff viewer for Edit tool with red/green highlighting
- Thinking/reasoning blocks (collapsible with purple styling)
- Markdown rendering (tables, headers, code blocks, lists)
- Copy-to-clipboard button on code blocks
- Message history persistence (50 messages per project)
- Draft input auto-save
- Local notifications on task completion (when backgrounded)

### Voice Input
- Microphone button for voice-to-text
- Uses iOS Speech framework (SFSpeechRecognizer)
- Real-time transcription with recording indicator
- Appends transcribed text to input field

### Image Attachments
- PhotosPicker for image selection
- Preview before sending with remove option
- Images displayed inline in messages

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
- Claude mode selector (normal/plan/bypass permissions)

## Key Patterns

- **@StateObject** for WebSocketManager, SpeechManager, SSHManager (owns instances)
- **@EnvironmentObject** for AppSettings (shared across views)
- **WebSocket callbacks** for streaming events (onText, onToolUse, onComplete, etc.)
- **MessageStore** for persistence using UserDefaults with JSON encoding
- **CLITheme** provides consistent dark mode styling with diff colors
- ATS disabled in Info.plist for local/Tailscale HTTP connections

## Permissions Required

In Info.plist:
- `NSMicrophoneUsageDescription` - Voice input
- `NSSpeechRecognitionUsageDescription` - Speech-to-text
- `NSPhotoLibraryUsageDescription` - Image attachments
- `NSAppTransportSecurity` - Allow HTTP for Tailscale

## Backend Setup

See `requirements/BACKEND.md`. Quick start:
```bash
npm install -g claude-code-webui
claude-code-webui --host 0.0.0.0 --port 8080
```

SSH requires standard sshd running on the server.
