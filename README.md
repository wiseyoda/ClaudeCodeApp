# Claude Code iOS App

A native iOS client for [Claude Code WebUI](https://github.com/sugyan/claude-code-webui), enabling Claude Code access from your iPhone or iPad.

## Features

- **Project Browser** - View and select from your Claude Code projects
- **Real-time Chat** - Stream responses from Claude with live updates
- **Tool Visibility** - See tool usage and results inline
- **Session Persistence** - Continue conversations across app launches
- **Tailscale Integration** - Secure access via private network

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

1. Tap the gear icon (⚙️) in the top right
2. Enter your backend server URL
3. Tap Done

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   iOS App       │────▶│  WebUI Backend  │────▶│   Claude CLI    │
│   (SwiftUI)     │ API │  (Node.js)      │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │
        └───── Tailscale ───────┘
              (secure network)
```

## API Endpoints Used

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/projects` | GET | List available projects |
| `/api/chat` | POST | Send message, receive streaming response |
| `/api/abort/:requestId` | POST | Cancel ongoing request |

## License

MIT
