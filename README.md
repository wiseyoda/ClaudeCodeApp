# Claude Code iOS App

A native iOS client for [Claude Code WebUI](https://github.com/sugyan/claude-code-webui), enabling Claude Code access from your iPhone or iPad.

## Features

### Chat
- **Real-time Streaming** - Live response updates via WebSocket
- **Tool Visibility** - Collapsible tool use/results with expand/collapse
- **Thinking Blocks** - View Claude's reasoning process (collapsible)
- **Diff Viewer** - Color-coded visualization for Edit tool changes
- **Code Blocks** - Syntax highlighting with copy-to-clipboard
- **Markdown Rendering** - Tables, headers, lists, inline code

### Input
- **Voice Input** - Dictate messages using iOS Speech Recognition
- **Image Upload** - Attach images from photo library with preview
- **Draft Saving** - Auto-saves unsent messages per project

### Persistence
- **Message History** - Last 50 messages saved per project
- **Session Continuity** - Resume conversations across app launches
- **Reconnection** - Exponential backoff with jitter on disconnect

### SSH Terminal
- **Native SSH Client** - Built with Citadel (pure Swift)
- **Special Keys Bar** - Ctrl+C, Tab, arrows, Esc
- **Saved Credentials** - Auto-connect with stored settings

### Notifications
- **Background Alerts** - Local notifications when tasks complete

## Requirements

- iOS 17.0+
- Xcode 15.0+
- A running [claude-code-webui](https://github.com/sugyan/claude-code-webui) backend
- Network access to the backend (via Tailscale or local network)

## Setup

### Backend Setup

The app connects to a claude-code-webui backend. See [requirements/BACKEND.md](requirements/BACKEND.md) for setup instructions.

### Building the App

1. Open `ClaudeCodeApp.xcodeproj` in Xcode
2. Select your target device (simulator or physical iPhone)
3. Press Cmd+R to build and run

### Configuration

On first launch, the app defaults to `http://10.0.3.2:8080`. To change:

1. Tap the gear icon in the top right
2. Enter your backend server URL
3. Configure SSH credentials (optional)
4. Adjust font size and mode preferences
5. Tap Done

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   iOS App       │────▶│  WebUI Backend  │────▶│   Claude CLI    │
│   (SwiftUI)     │ WS  │  (Node.js)      │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │
        └───── Tailscale ───────┘
              (secure network)
```

## WebSocket Protocol

The app uses WebSocket for real-time streaming:

| Message Type | Direction | Description |
|--------------|-----------|-------------|
| `claude-command` | → Server | Send user message |
| `claude-response` | ← Server | Streaming content |
| `claude-complete` | ← Server | Task finished |
| `token-budget` | ← Server | Usage stats |
| `abort-session` | → Server | Cancel request |

## Permissions

The app requests these permissions:
- **Microphone** - Voice-to-text input
- **Speech Recognition** - Transcription
- **Photo Library** - Image attachments

## License

MIT
