# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Native iOS client for [claudecodeui](https://github.com/siteboon/claudecodeui), enabling Claude Code access from iPhone/iPad. The app connects to a backend server (typically running on a NAS via Tailscale) via WebSocket and provides real-time streaming chat with tool visibility. Includes a built-in SSH terminal, file browser, command library, and project management.

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
├── AppSettings.swift         # @AppStorage for server URL, SSH, font size, mode, thinking
├── Models.swift              # Project, ChatMessage, MessageStore, BookmarkStore, enums
├── APIClient.swift           # HTTP client for project listing (JWT auth)
├── WebSocketManager.swift    # WebSocket connection, message parsing, reconnection
├── SpeechManager.swift       # Voice input using iOS Speech framework
├── SSHManager.swift          # SSH connection handling via Citadel
├── CommandStore.swift        # Saved commands with categories
├── ClaudeHelper.swift        # AI suggestions via Haiku
├── Theme.swift               # CLI-inspired theme colors (light/dark aware)
├── Logger.swift              # Structured logging utility
├── AppError.swift            # Unified error handling
├── ImageUtilities.swift      # MIME type detection for images
│
├── ContentView.swift         # Project list, settings, global search
├── ChatView.swift            # Message list, streaming, slash commands, search
├── TerminalView.swift        # SSH terminal with CLI theme
│
└── Views/
    ├── MarkdownText.swift        # Full markdown rendering with math
    ├── CLIInputView.swift        # Multi-line input, [+] menu, voice, image
    ├── CLIMessageView.swift      # Message bubble with context menu
    ├── CLIStatusBarViews.swift   # Unified status bar components
    ├── DiffView.swift            # Edit tool diff with line numbers
    ├── TodoListView.swift        # TodoWrite checklist
    ├── CodeBlockView.swift       # Code display with copy
    ├── TruncatableText.swift     # Expandable truncated text
    ├── SessionPickerViews.swift  # Session list, rename, delete, export
    ├── FilePickerSheet.swift     # File browser with AI suggestions
    ├── CloneProjectSheet.swift   # Clone from GitHub URL
    ├── NewProjectSheet.swift     # Create empty project
    ├── CommandsView.swift        # Command library CRUD
    ├── CommandPickerSheet.swift  # Quick command selection
    ├── BookmarksView.swift       # Bookmarked messages
    ├── GlobalSearchView.swift    # Cross-session search
    ├── SearchFilterViews.swift   # Message filters
    ├── SuggestionChipsView.swift # AI suggestion chips
    └── QuickSettingsSheet.swift  # Fast settings access
```

### Data Flow

1. **AppSettings** stores server URL, SSH credentials, font size, mode, thinking level
2. **WebSocketManager** handles real-time communication with claudecodeui backend
3. **ContentView** fetches projects via APIClient, manages project creation/deletion
4. **ChatView** manages session state, streams responses via WebSocket callbacks
5. **MessageStore** persists last 50 messages per project to Documents directory
6. **SSHManager** provides SSH terminal, file listing, and remote command execution
7. **CommandStore** persists saved commands to Documents/commands.json
8. **BookmarkStore** persists bookmarks to Documents/bookmarks.json
9. **ClaudeHelper** generates AI suggestions via separate Haiku WebSocket

### WebSocket Communication

The app uses WebSocket for real-time chat with the backend:
- `WSClaudeCommand` - sent to server with message, cwd, sessionId, permissionMode, model
- `WSMessage` - received from server with type (claude-response, claude-complete, etc.)
- Auto-reconnection with exponential backoff (1s → 2s → 4s → 8s max + jitter)

## Features

### Claude Code Chat
- Real-time streaming responses via WebSocket
- Model selection (Opus/Sonnet/Haiku/Custom) in status bar
- Thinking modes (5 levels: Normal → Ultrathink)
- Tool use visualization (12+ tools with icons/colors)
- Diff viewer for Edit tool with line numbers
- Thinking/reasoning blocks (collapsible with purple styling)
- TodoWrite visual checklist with status colors
- AskUserQuestion interactive selection UI
- Full markdown rendering (tables, headers, code, math)
- Copy-to-clipboard button on code blocks and messages
- Long-press context menu with copy/share/bookmark options
- Message history persistence (50 messages per project)
- Draft input auto-save
- Local notifications on task completion

### Model Selection
| Model | Description |
|-------|-------------|
| Opus 4 | Most capable, complex reasoning |
| Sonnet 4 | Balanced speed and quality |
| Haiku 3.5 | Fastest, quick tasks |
| Custom | Any model ID |

### Thinking Modes
| Mode | Trigger |
|------|---------|
| Normal | Standard responses |
| Think | Appends "think" |
| Think Hard | Appends "think hard" |
| Think Harder | Appends "think harder" |
| Ultrathink | Appends "ultrathink" |

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

### Search & Bookmarks
- Message search within current session
- Filter chips (All/User/Assistant/Tools/Thinking)
- Bookmark messages via context menu
- Global search across all sessions via SSH
- Bookmarks view with search and swipe-to-delete

### Command Library
- Save frequently-used prompts
- Organize by categories (Git, Code Review, Testing, Docs)
- Quick picker in [+] menu
- Last-used tracking and sorting
- CRUD management interface

### AI Suggestions
- Haiku-powered action chips after responses
- Suggested files in file picker
- Tappable chips auto-send prompts
- 15-second timeout with fallback

### Project Management
- Clone from GitHub URL with SSH-based git clone
- Create new empty projects in ~/workspace/
- Delete projects from list (removes Claude registration)
- Git status tracking with 10 states
- Auto-pull for behind repositories

### Session Management
- Full-screen session picker with summaries
- Rename sessions with custom names
- Delete sessions with swipe-to-delete
- Export sessions as markdown
- Session rows show message count, preview, time

### File Browser & @ References
- Browse project files via SSH
- Breadcrumb navigation
- Search/filter files by name
- AI-suggested files based on context
- @ button to insert file references

### Input Methods
- Multi-line text with word wrap
- [+] menu for attachments
- Voice input via Speech framework
- Image attachments via PhotosPicker
- Saved commands quick access

### iPad Experience
- NavigationSplitView with sidebar
- Keyboard shortcuts (Cmd+Return, Cmd+K, Cmd+N, etc.)
- Split-view multitasking support

### SSH Terminal
- Native SSH client via Citadel (pure Swift)
- Special keys bar (Ctrl+C, Tab, arrows)
- Password and SSH key authentication
- Ed25519, RSA, ECDSA key support
- Keychain storage for keys
- Auto-connect with saved credentials

### Settings
- Server URL configuration
- Username/password (JWT auth)
- Font size (XS/S/M/L/XL)
- Theme (System/Dark/Light)
- Default model selection
- Permission mode (normal/plan/bypass)
- Thinking mode (5 levels)
- Show thinking blocks toggle
- Auto-scroll toggle
- Project sort order (name/date)
- SSH credentials and key import

## Key Patterns

- **@StateObject** for WebSocketManager, SpeechManager, SSHManager (owns instances)
- **@EnvironmentObject** for AppSettings (shared across views)
- **@ObservedObject** for CommandStore.shared, BookmarkStore.shared (singletons)
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
git clone https://github.com/siteboon/claudecodeui.git
cd claudecodeui && npm install && npm run build && npm start
```

SSH requires standard sshd running on the server.

## Backend API Notes

### Authentication

The claudecodeui backend uses JWT tokens for the main API:

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
   - **NOT for iOS app - leave API Key field empty!**

**iOS App Configuration:**
- Server URL: `http://10.0.3.2:8080` (your claudecodeui server)
- **Leave "API Key" field empty**
- Enter your web UI username/password
- The app authenticates via JWT automatically

**Important CORS limitation:** The backend CORS config only allows `Content-Type` header, NOT `Authorization`. This means:
- `/api/projects` works with `Authorization: Bearer <token>` header
- `/api/projects/:project/histories/:sessionId` does NOT work with Bearer auth

### Working Endpoints

| Endpoint | Auth | Notes |
|----------|------|-------|
| `GET /api/projects` | Bearer token | Returns project list with sessions |
| `WebSocket /ws` | Token param | Real-time chat |
| `POST /api/abort/:requestId` | None needed | Abort current request |
| `GET /api/projects/:project/histories` | **BROKEN** | CORS blocks Authorization |

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

## Known Issues

See ROADMAP.md Priority 1 for critical issues including:
- WebSocket state race conditions
- Missing @MainActor on APIClient, BookmarkStore
- SpeechManager missing deinit
- SSH password in UserDefaults (should use Keychain)
- Command injection vulnerabilities in SSH commands
