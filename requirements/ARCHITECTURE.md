# Architecture Documentation

## System Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                         iOS Device                                │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                    ClaudeCodeApp                            │  │
│  │                                                              │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌───────────────────┐   │  │
│  │  │ ContentView │──│  ChatView   │──│ WebSocketManager  │   │  │
│  │  │ (Projects)  │  │ (Messages)  │  │ (Streaming)       │   │  │
│  │  └─────────────┘  └─────────────┘  └───────────────────┘   │  │
│  │         │                │                                   │  │
│  │         │         ┌──────┴──────┐                           │  │
│  │         │         │SpeechManager│                           │  │
│  │         │         │(Voice Input)│                           │  │
│  │         │         └─────────────┘                           │  │
│  │         │                                                    │  │
│  │  ┌──────┴──────┐  ┌─────────────┐  ┌───────────────────┐   │  │
│  │  │TerminalView │──│ SSHManager  │  │   MessageStore    │   │  │
│  │  │ (SSH Shell) │  │ (Citadel)   │  │   (Persistence)   │   │  │
│  │  └─────────────┘  └─────────────┘  └───────────────────┘   │  │
│  │                          │                   │              │  │
│  │         ┌────────────────┴───────────────────┘              │  │
│  │         │                                                    │  │
│  │  ┌──────┴──────┐                                            │  │
│  │  │ AppSettings │ (Server URL, SSH, Font, Mode)              │  │
│  │  └─────────────┘                                            │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
                              │
                              │ WebSocket / SSH
                              │ (via Tailscale)
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                      Backend Server (NAS/Cloud)                   │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                  claude-code-webui                          │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │  │
│  │  │  WebSocket  │──│   Message   │──│    Claude CLI       │ │  │
│  │  │   Server    │  │   Handler   │  │    Wrapper          │ │  │
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
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                        sshd                                 │  │
│  │  - Standard SSH daemon                                      │  │
│  │  - Terminal access for TerminalView                         │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

## iOS App Components

### ClaudeCodeAppApp.swift
- App entry point
- Creates shared AppSettings instance
- Injects settings into environment
- Requests notification permissions

### AppSettings.swift
- Stores server URL using @AppStorage
- SSH credentials (host, port, username, password)
- Font size preference (XS/S/M/L/XL)
- Claude mode setting (normal/plan/bypass)
- Computed webSocketURL property
- Persists across app launches

### Models.swift
- `Project` - Represents a Claude Code project with sessions
- `ProjectSession` - Session metadata (id, summary, message count)
- `ChatMessage` - UI message with role, content, timestamp, imageData
- `MessageStore` - Static class for UserDefaults persistence
- `WSClaudeCommand` / `WSMessage` - WebSocket protocol types
- `AnyCodable` - Helper for dynamic JSON parsing

### WebSocketManager.swift
- WebSocket connection management
- Exponential backoff reconnection (1s→2s→4s→8s + jitter)
- Message sending with session/mode support
- Streaming response parsing (text, tool_use, thinking)
- Local notification dispatch on completion
- Callbacks: onText, onToolUse, onToolResult, onThinking, onComplete, onError

### SpeechManager.swift
- iOS Speech framework integration
- SFSpeechRecognizer for transcription
- AVAudioEngine for recording
- Real-time partial results
- Authorization status tracking

### SSHManager.swift
- SSH connection via Citadel library
- Channel-based I/O
- Special key sequences (Ctrl+C, arrows, etc.)
- Connection state management

### ContentView.swift
- Main navigation container
- Project list with session counts
- Settings sheet (SettingsView)
- Error handling and retry logic
- Tab bar with Terminal access

### ChatView.swift
Core chat UI with many sub-components:
- **CLIInputView** - Input field with send, voice, image buttons
- **CLIMessageView** - Message bubble with role-based styling
- **CodeBlockView** - Code with syntax highlighting + copy button
- **DiffView** - Edit tool visualization (red/green diff)
- **CLIStatusBar** - Token usage and status display
- Message list with auto-scroll
- Tool use/result collapsible sections
- Thinking block display (purple, collapsible)

### TerminalView.swift
- Interactive SSH shell display
- Special keys bar (Ctrl+C, Tab, Esc, arrows)
- Auto-scroll to bottom
- CLI theme styling

### Theme.swift
- `CLITheme` - CLI-inspired dark colors
- Background, text, accent, success, error colors
- Diff colors (added green, removed red)
- Tool-specific colors

## Data Flow

### Loading Projects
```
1. App launches
2. ContentView.task calls APIClient.fetchProjects()
3. HTTP GET /api/projects
4. Response decoded to [Project]
5. UI updates with project list
```

### Sending a Message
```
1. User types/speaks/attaches and taps send
2. ChatView adds user message to list
3. WebSocketManager.sendMessage() called with:
   - message text
   - project path (cwd)
   - sessionId (optional)
   - permissionMode (optional)
4. WebSocket sends claude-command message
5. Response streamed via claude-response messages
6. Callbacks update UI:
   - onText: streaming assistant text
   - onToolUse: tool invocation display
   - onToolResult: tool output display
   - onThinking: reasoning block display
7. claude-complete signals end
8. MessageStore saves history
9. Local notification sent (if backgrounded)
```

### Voice Input Flow
```
1. User taps mic button
2. SpeechManager.startRecording()
3. AVAudioEngine captures audio
4. SFSpeechRecognizer transcribes
5. Partial results update UI
6. User taps mic again to stop
7. Final transcription appended to input
```

### Message Persistence
```
1. On view appear: MessageStore.loadMessages(projectPath)
2. On message change: MessageStore.saveMessages(messages, projectPath)
3. On new chat: MessageStore.clearMessages(projectPath)
4. Draft auto-saved via onChange(of: inputText)
```

## Security Model

- **No API credentials in app** - Backend handles Claude authentication
- **Network security** - Tailscale provides encrypted tunnel
- **Local persistence** - Messages stored in UserDefaults (device only)
- **SSH credentials** - Stored locally, never transmitted
- **HTTP allowed** - App Transport Security disabled for local/Tailscale IPs
