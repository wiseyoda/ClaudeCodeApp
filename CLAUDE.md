# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Native iOS client for claudecodeui (local fork at `~/dev/claudecodeui`, based on sugyan/claude-code-webui), enabling Claude Code access from iPhone/iPad. The app connects to a backend server (typically running on a NAS via Tailscale) via WebSocket and provides real-time streaming chat with tool visibility. Includes a built-in SSH terminal for direct server access, file browser, and project management.

## Build & Run

Open `ClaudeCodeApp.xcodeproj` in Xcode 15+ and press Cmd+R. Target iOS 17.0+.

**Dependencies:** Citadel (via Swift Package Manager) - pure Swift SSH library for terminal and file operations.

**Testing:**
```bash
xcodebuild test -project ClaudeCodeApp.xcodeproj -scheme ClaudeCodeApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Architecture

```
ClaudeCodeApp/
├── ClaudeCodeAppApp.swift    # App entry, notification permissions, injects AppSettings
├── AppSettings.swift         # @AppStorage for server URL, SSH, font size, mode
├── Models.swift              # Project, ChatMessage, MessageStore, WS message types
├── APIClient.swift           # HTTP client for project listing
├── WebSocketManager.swift    # WebSocket connection, message parsing, reconnection
├── SpeechManager.swift       # Voice input using iOS Speech framework
├── SSHManager.swift          # SSH connection handling via Citadel
├── Theme.swift               # CLI-inspired theme colors (light/dark aware)
├── Logger.swift              # Structured logging utility
├── AppError.swift            # Unified error handling
├── ImageUtilities.swift      # MIME type detection for images
│
├── ContentView.swift         # Project list, settings, new project actions
├── ChatView.swift            # Message list, streaming, slash commands
├── TerminalView.swift        # SSH terminal with CLI theme
│
└── Views/
    ├── MarkdownText.swift        # Full markdown rendering component
    ├── CLIInputView.swift        # Input field with send, voice, image, @ buttons
    ├── CLIMessageView.swift      # Message bubble with role-based styling
    ├── SessionPickerViews.swift  # Session list, rename, delete, export
    ├── FilePickerSheet.swift     # File browser with breadcrumb navigation
    ├── CloneProjectSheet.swift   # Clone from GitHub URL
    └── NewProjectSheet.swift     # Create empty project
```

### Data Flow

1. **AppSettings** stores server URL, SSH credentials, font size, mode preferences
2. **WebSocketManager** handles real-time communication with claudecodeui backend
3. **ContentView** fetches projects via APIClient, manages project creation/deletion
4. **ChatView** manages session state, streams responses via WebSocket callbacks
5. **MessageStore** persists last 50 messages per project to Documents directory (file-based)
6. **SSHManager** provides SSH terminal, file listing, and remote command execution
7. **SessionNamesStore** persists custom session names via UserDefaults

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
- TodoWrite visual checklist with status colors (pending/in_progress/completed)
- AskUserQuestion interactive selection UI
- Markdown rendering (tables, headers, code blocks, lists, math)
- Copy-to-clipboard button on code blocks and messages
- Long-press context menu with copy/share options
- Message history persistence (50 messages per project, file-based)
- Draft input auto-save
- Local notifications on task completion (when backgrounded)

### Slash Commands
| Command | Description |
|---------|-------------|
| `/clear` | Clear conversation and start fresh |
| `/new` | Start a new session |
| `/init` | Pass to Claude to create/modify CLAUDE.md |
| `/resume` | Open session picker to resume previous session |
| `/compact` | Compact conversation to save context |
| `/status` | Show connection and session info |
| `/exit` | Close chat and return to projects |
| `/help` | Show command reference sheet |

### Project Management
- Clone from GitHub URL with SSH-based git clone
- Create new empty projects in ~/workspace/
- Delete projects from list (removes Claude registration, keeps files)
- Project registration via session files with `cwd` field

### Session Management
- Full-screen session picker with summaries and timestamps
- Rename sessions with custom names (persisted via SessionNamesStore)
- Delete sessions with swipe-to-delete and confirmation
- Export sessions as markdown with share sheet integration
- Session rows show message count, last user message preview, relative time

### File Browser & @ References
- Browse project files via SSH with `ls -laF`
- Breadcrumb navigation for directory traversal
- Search/filter files by name
- @ button in input to insert file references into prompts

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
- Theme (System/Dark/Light)
- SSH host/port/username/password
- Claude mode selector (normal/plan/bypass permissions)
- Skip permission prompts toggle
- Show thinking blocks toggle
- Auto-scroll toggle
- Project sort order (name/date)

## Key Patterns

- **@StateObject** for WebSocketManager, SpeechManager, SSHManager (owns instances)
- **@EnvironmentObject** for AppSettings (shared across views)
- **WebSocket callbacks** for streaming events (onText, onToolUse, onComplete, etc.)
- **MessageStore** for file-based persistence in Documents directory
- **SessionNamesStore** for custom session name persistence via UserDefaults
- **CLITheme** provides colorScheme-aware styling (dark and light modes)
- **Logger** for structured debug/info/error logging
- **AppError** for unified error handling with user-friendly messages
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

## Backend API Notes

### Authentication

The claudecodeui backend (source at `~/dev/claudecodeui`) uses JWT tokens for the main API:

```
POST /api/auth/login
Body: {"username": "admin", "password": "yourpassword"}
Response: {"success": true, "token": "eyJ..."}
```

**Two Authentication Methods:**

1. **JWT (Username/Password)** - For web UI and iOS app
   - Login with username/password to get a JWT token
   - Use `Authorization: Bearer <jwt_token>` header
   - Required for `/api/projects`, `/api/settings`, etc.
   - **This is what the iOS app uses**

2. **API Keys (`ck_...`)** - For Agent API only
   - Created in Web UI: Settings > API Keys
   - Use `X-API-Key: ck_...` header
   - **Only works for `/api/agent/*` endpoints**
   - Used for external integrations (n8n, etc.)
   - **NOT for iOS app - leave API Key field empty!**

**iOS App Configuration:**
- Server URL: `http://10.0.3.2:8080` (your claudecodeui server)
- **Leave "API Key" field empty**
- Enter your web UI username/password
- The app authenticates via JWT automatically

**Important CORS limitation:** The backend CORS config only allows `Content-Type` header, NOT `Authorization`. This means:
- `/api/projects` works with `Authorization: Bearer <token>` header
- `/api/projects/:project/histories/:sessionId` does NOT work with Bearer auth (returns HTML instead of JSON)

### Working Endpoints

| Endpoint | Auth | Notes |
|----------|------|-------|
| `GET /api/projects` | Bearer token | Returns project list with sessions |
| `POST /api/chat` | WebSocket | Real-time chat |
| `POST /api/abort/:requestId` | None needed | Abort current request |
| `GET /api/projects/:project/histories` | **BROKEN** | CORS blocks Authorization |
| `GET /api/projects/:project/histories/:sessionId` | **BROKEN** | CORS blocks Authorization |

### Session History Workaround

Since the history API endpoints don't accept Authorization headers, we load session history via SSH instead:

**Session files location:** `~/.claude/projects/{encoded-project-path}/{session-id}.jsonl`

**Encoded project path format:** `/home/dev/workspace/MyProject` → `-home-dev-workspace-MyProject` (note: STARTS with dash)

**JSONL format:** Each line is a JSON object:
```json
{"type":"user","message":{"content":[{"type":"text","text":"user message"}]},"timestamp":"..."}
{"type":"assistant","message":{"content":[{"type":"text","text":"response"}]},"timestamp":"..."}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{...}}]},"timestamp":"..."}
```

Key message types:
- `type: "user"` with `content[0].text` = user message
- `type: "user"` with `content[0].type: "tool_result"` = tool output (use `toolUseResult` field)
- `type: "assistant"` with `content[0].text` = assistant response
- `type: "assistant"` with `content[0].type: "tool_use"` = tool invocation
- `type: "assistant"` with `content[0].type: "thinking"` = reasoning block

The `SessionHistoryLoader` class in `Models.swift` handles parsing this format.

### Project Registration

Projects appear in the app's list when they have session files in `~/.claude/projects/`. To register a project:

1. Create the encoded path directory: `mkdir -p ~/.claude/projects/-path-to-project`
2. Create a session file with `cwd` field: `echo '{"type":"init","cwd":"/path/to/project"}' > ~/.claude/projects/-path-to-project/init.jsonl`

The app handles this automatically when cloning or creating new projects.

## Testing

The app includes 28+ unit tests covering:
- Markdown parsing and HTML entity decoding
- Diff view parsing for Edit tool
- TodoWrite JSON parsing
- Image MIME type detection
- WebSocket message type handling

Run tests:
```bash
xcodebuild test -project ClaudeCodeApp.xcodeproj -scheme ClaudeCodeApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ClaudeCodeAppTests
```
