# Architecture Documentation

## System Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                         iOS Device                                │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                    ClaudeCodeApp                            │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │  │
│  │  │ ContentView │──│  ChatView   │──│    APIClient        │ │  │
│  │  │ (Projects)  │  │ (Messages)  │  │ (Network Layer)     │ │  │
│  │  └─────────────┘  └─────────────┘  └─────────────────────┘ │  │
│  │         │                │                   │              │  │
│  │         └────────────────┼───────────────────┘              │  │
│  │                          │                                   │  │
│  │                   ┌──────┴──────┐                           │  │
│  │                   │ AppSettings │                           │  │
│  │                   │ (Server URL)│                           │  │
│  │                   └─────────────┘                           │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
                              │
                              │ HTTP/Streaming JSON
                              │ (via Tailscale)
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                      Backend Server (NAS/Cloud)                   │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                  claude-code-webui                          │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │  │
│  │  │   HTTP      │──│   API       │──│    Claude CLI       │ │  │
│  │  │   Server    │  │   Routes    │  │    Wrapper          │ │  │
│  │  └─────────────┘  └─────────────┘  └─────────────────────┘ │  │
│  └────────────────────────────────────────────────────────────┘  │
│                              │                                    │
│                              ▼                                    │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                     Claude CLI                              │  │
│  │  - Authenticated with Anthropic                             │  │
│  │  - Access to workspace files                                │  │
│  │  - Tool execution capabilities                              │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

## iOS App Components

### ClaudeCodeAppApp.swift
- App entry point
- Creates shared AppSettings instance
- Injects settings into environment

### AppSettings.swift
- Stores server URL using @AppStorage
- Provides computed baseURL property
- Persists across app launches

### Models.swift
- `Project` - Represents a Claude Code project
- `ChatMessage` - UI representation of messages
- `ClaudeStreamEvent` - Parsed streaming JSON events
- `AnyCodable` - Helper for dynamic JSON parsing

### APIClient.swift
- `fetchProjects()` - GET /api/projects
- `sendMessage()` - POST /api/chat with streaming
- `abortRequest()` - POST /api/abort/:requestId
- Handles URLSession streaming with async/await

### ContentView.swift
- Main navigation container
- Project list display
- Settings sheet
- Error handling and retry logic

### ChatView.swift
- Message input field
- Scrolling message list
- Real-time streaming display
- Tool use/result visualization

## Data Flow

### Loading Projects
```
1. App launches
2. ContentView.task calls loadProjects()
3. APIClient.fetchProjects() makes GET request
4. Response decoded to [Project]
5. UI updates with project list
```

### Sending a Message
```
1. User types message and taps send
2. ChatView adds user message to list
3. APIClient.sendMessage() called with:
   - message text
   - project path
   - optional sessionId
4. POST request made to /api/chat
5. Response streamed line by line
6. Each line parsed as ClaudeStreamEvent
7. UI updates with streaming text
8. Tool use/results shown inline
9. Session ID saved for continuation
```

## Security Model

- **No credentials in app** - Backend handles Claude authentication
- **Network security** - Tailscale provides encrypted tunnel
- **No data persistence** - Messages not stored locally
- **HTTP allowed** - App Transport Security disabled for local/Tailscale IPs
