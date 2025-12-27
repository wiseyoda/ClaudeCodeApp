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
│  │  │ (SSH Shell) │  │ (Citadel)   │  │   (File-based)    │   │  │
│  │  └─────────────┘  └─────────────┘  └───────────────────┘   │  │
│  │                          │                   │              │  │
│  │         ┌────────────────┴───────────────────┘              │  │
│  │         │                                                    │  │
│  │  ┌──────┴──────┐  ┌─────────────┐  ┌───────────────────┐   │  │
│  │  │ AppSettings │  │   Logger    │  │ SessionNamesStore │   │  │
│  │  │ (Config)    │  │  (Logging)  │  │ (Custom Names)    │   │  │
│  │  └─────────────┘  └─────────────┘  └───────────────────┘   │  │
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
│  │  - File listing for FilePickerSheet                         │  │
│  │  - Git operations for CloneProjectSheet                     │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

## iOS App Components

### Core Files

#### ClaudeCodeAppApp.swift
- App entry point
- Creates shared AppSettings instance
- Injects settings into environment
- Requests notification permissions

#### AppSettings.swift
- Stores server URL using @AppStorage
- SSH credentials (host, port, username, password)
- Font size preference (XS/S/M/L/XL)
- Theme selection (System/Dark/Light)
- Claude mode setting (normal/plan/bypass)
- Skip permissions, show thinking, auto-scroll toggles
- Project sort order (name/date)
- Computed webSocketURL property
- Persists across app launches

#### Models.swift
- `Project` - Represents a Claude Code project with sessions
- `ProjectSession` - Session metadata (id, summary, message count)
- `ChatMessage` - UI message with role, content, timestamp, imageData
- `MessageStore` - File-based persistence in Documents directory
- `SessionHistoryLoader` - Parses JSONL session files via SSH
- `WSClaudeCommand` / `WSMessage` - WebSocket protocol types
- `AnyCodable` - Helper for dynamic JSON parsing

#### WebSocketManager.swift
- WebSocket connection management
- Exponential backoff reconnection (1s→2s→4s→8s + jitter)
- Message sending with session/mode support
- Streaming response parsing (text, tool_use, thinking)
- Local notification dispatch on completion
- Callbacks: onText, onToolUse, onToolResult, onThinking, onComplete, onError

#### SpeechManager.swift
- iOS Speech framework integration
- SFSpeechRecognizer for transcription
- AVAudioEngine for recording
- Real-time partial results
- Authorization status tracking

#### SSHManager.swift
- SSH connection via Citadel library
- Channel-based I/O for terminal
- File listing via `ls -laF` command
- Command execution with timeout support
- Auto-connect with saved credentials
- Special key sequences (Ctrl+C, arrows, etc.)
- Connection state management

#### Theme.swift
- `CLITheme` - CLI-inspired colors with colorScheme awareness
- Background, text, accent, success, error colors
- Diff colors (added green, removed red)
- Tool-specific colors
- Light and dark mode variants

#### Logger.swift
- Structured logging utility
- Debug, info, warning, error levels
- File and line context

#### AppError.swift
- Unified error handling
- User-friendly error messages
- Error categorization

#### ImageUtilities.swift
- MIME type detection from image data
- Supports PNG, JPEG, GIF, WebP

### Main Views

#### ContentView.swift
- Main navigation container
- Project list with session counts
- Settings sheet (SettingsView)
- New project action sheet (Clone vs Create)
- Project deletion with swipe and context menu
- Error handling and retry logic
- Toolbar with Terminal access

#### ChatView.swift
Core chat UI with many responsibilities:
- Message list with auto-scroll
- WebSocket streaming integration
- Slash command handling (/clear, /new, /init, /resume, etc.)
- Tool use/result collapsible sections
- Thinking block display (purple, collapsible)
- Session picker sheet
- Help sheet for commands
- Draft input persistence

#### TerminalView.swift
- Interactive SSH shell display
- Special keys bar (Ctrl+C, Tab, Esc, arrows)
- Auto-scroll to bottom
- CLI theme styling

### Views/ Folder

#### MarkdownText.swift
- Full markdown rendering component
- Headers, lists, tables, code blocks
- Math expressions (LaTeX)
- HTML entity decoding
- Copy button on code blocks

#### CLIInputView.swift
- Input field with placeholder
- Send button
- Voice input button (microphone)
- Image attachment button
- @ file reference button
- Image preview with remove option

#### CLIMessageView.swift
- Message bubble with role-based styling
- User, assistant, system, tool variants
- Copy and share context menu
- Timestamp display
- Image display for attachments

#### SessionPickerViews.swift
- `SessionNamesStore` - UserDefaults persistence for custom names
- `SessionPicker` - Horizontal scrolling session tabs
- `SessionPickerSheet` - Full-screen session list
- `SessionExportSheet` - Markdown export preview
- `SessionRow` - Session list row with metadata
- Swipe actions (delete, export)
- Context menu (rename, export, delete)
- Confirmation dialogs

#### FilePickerSheet.swift
- `FileEntry` - File/directory representation
- File browser with breadcrumb navigation
- Directory listing via SSH
- Search/filter functionality
- File selection for @ references

#### CloneProjectSheet.swift
- GitHub URL input and validation
- Git clone via SSH
- Progress indicator
- Claude project registration
- Error handling

#### NewProjectSheet.swift
- Project name input with validation
- Creates directory in ~/workspace/
- Optional Claude initialization
- Claude project registration

## Data Flow

### Loading Projects
```
1. App launches
2. ContentView.task calls APIClient.fetchProjects()
3. HTTP GET /api/projects
4. Response decoded to [Project]
5. Projects sorted by user preference
6. UI updates with project list
```

### Cloning a Project
```
1. User taps + → Clone from GitHub
2. CloneProjectSheet opens
3. User enters GitHub URL
4. SSHManager.executeCommandWithAutoConnect runs `git clone`
5. Claude project directory created
6. Session file with cwd written
7. Project list refreshed
8. User navigates to new project
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
8. MessageStore saves history to file
9. Local notification sent (if backgrounded)
```

### Session Management
```
1. User taps /resume or session picker
2. SessionPickerSheet shows with sessions
3. User can:
   - Select session → loads history via SSH
   - Rename → SessionNamesStore saves custom name
   - Delete → removes session file via SSH
   - Export → generates markdown, shows share sheet
4. Selected session's history loaded
5. Conversation continues with session context
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

### File Reference Flow
```
1. User taps @ button
2. FilePickerSheet opens
3. SSHManager.listFiles() fetches directory
4. User navigates/searches files
5. User selects file
6. @path/to/file inserted into input
7. User sends message with reference
```

### Message Persistence
```
1. On view appear: MessageStore.loadMessages(projectPath)
2. Messages loaded from Documents/{encoded-path}.json
3. On message change: MessageStore.saveMessages(messages, projectPath)
4. On new chat: MessageStore.clearMessages(projectPath)
5. Draft auto-saved via onChange(of: inputText)
```

## Security Model

- **No API credentials in app** - Backend handles Claude authentication
- **Network security** - Tailscale provides encrypted tunnel
- **Local persistence** - Messages stored in Documents directory (device only)
- **SSH credentials** - Stored locally via UserDefaults, never transmitted
- **HTTP allowed** - App Transport Security disabled for local/Tailscale IPs

## Testing

28+ unit tests covering:
- `StringMarkdownTests` - HTML entity decoding, markdown normalization
- `DiffViewTests` - Edit tool diff parsing
- `TodoListViewTests` - TodoWrite JSON parsing
- `ImageUtilitiesTests` - MIME type detection
- `ModelsTests` - WebSocket message handling

Run tests:
```bash
xcodebuild test -project ClaudeCodeApp.xcodeproj -scheme ClaudeCodeApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:ClaudeCodeAppTests
```
