# Coding Bridge

A native iOS client for [claudecodeui](https://github.com/wiseyoda/claudecodeui), enabling full Claude Code access from your iPhone or iPad.

## Features

### Chat Interface

| Feature                 | Description                                                              |
| ----------------------- | ------------------------------------------------------------------------ |
| **Real-time Streaming** | Live response updates via WebSocket with smooth scrolling                |
| **Tool Visualization**  | 12+ tools with distinct icons, colors, and collapsible sections          |
| **Diff Viewer**         | Color-coded visualization for Edit tool with line numbers                |
| **TodoWrite Checklist** | Interactive task lists with status colors (pending/in-progress/complete) |
| **AskUserQuestion UI**  | Tappable selection interface for Claude's multi-choice questions         |
| **Thinking Blocks**     | View Claude's reasoning process (purple, collapsible)                    |
| **Code Blocks**         | Syntax-styled display with copy-to-clipboard                             |
| **Markdown Rendering**  | Headers, tables, lists, math (LaTeX), inline code                        |

### Input Methods

| Feature               | Description                                                |
| --------------------- | ---------------------------------------------------------- |
| **Multi-line Text**   | Word-wrapping input with adjustable height                 |
| **Voice Input**       | Dictate messages using iOS Speech Recognition              |
| **Image Upload**      | Attach images from photo library with preview              |
| **@ File References** | Reference project files directly in prompts                |
| **Command Library**   | Save and reuse frequent prompts with categories            |
| **AI Suggestions**    | Context-aware action chips after responses (Haiku-powered) |
| **Ideas Drawer**      | Capture ideas during long-running operations with FAB      |

### Model Selection

| Model          | Description                              |
| -------------- | ---------------------------------------- |
| **Opus 4.5**   | Most capable, best for complex reasoning |
| **Sonnet 4.5** | Balanced speed and quality               |
| **Haiku 3.5**  | Fastest, best for quick tasks            |
| **Custom**     | Specify any model ID                     |

### Thinking Modes

Control Claude's reasoning depth with 5 levels:

| Mode         | Description                             |
| ------------ | --------------------------------------- |
| Normal       | Standard responses                      |
| Think        | Light reasoning with `think` trigger    |
| Think Hard   | Deeper analysis                         |
| Think Harder | Extended reasoning                      |
| Ultrathink   | Maximum depth with `ultrathink` trigger |

### Project Management

| Feature                 | Description                                      |
| ----------------------- | ------------------------------------------------ |
| **Clone from GitHub**   | Clone repositories directly from URL             |
| **Create New Projects** | Create empty projects in workspace               |
| **Delete Projects**     | Remove projects (swipe or context menu)          |
| **File Browser**        | Navigate project files via SSH with breadcrumbs  |
| **Git Status**          | 10 status states with auto-pull for behind repos |

### Session Management

| Feature                 | Description                                        |
| ----------------------- | -------------------------------------------------- |
| **Session Picker**      | Full-screen list with summaries and timestamps     |
| **Real-time Updates**   | WebSocket push updates when sessions change        |
| **Load More**           | Pagination for large session lists                 |
| **Bulk Operations**     | Delete all, older than 7/30/90 days, keep last N   |
| **Rename Sessions**     | Custom names instead of UUIDs                      |
| **Delete Sessions**     | Swipe-to-delete with confirmation                  |
| **Export Sessions**     | Save as markdown with share sheet                  |

### Permission Approval

| Feature              | Description                                       |
| -------------------- | ------------------------------------------------- |
| **Approval Banner**  | Compact banner for tool approval requests         |
| **Quick Actions**    | Approve / Always Allow / Deny buttons             |
| **Per-Project Mode** | Override global permissions per project           |

### Search & Bookmarks

| Feature            | Description                                     |
| ------------------ | ----------------------------------------------- |
| **Message Search** | Filter current session by keyword               |
| **Filter by Type** | Filter chips: All/User/Assistant/Tools/Thinking |
| **Bookmarks**      | Star important messages across sessions         |
| **Global Search**  | Cross-session search via SSH                    |

### Slash Commands

| Command    | Description                          |
| ---------- | ------------------------------------ |
| `/clear`   | Clear conversation and start fresh   |
| `/new`     | Start a new session                  |
| `/init`    | Create/modify CLAUDE.md (via Claude) |
| `/resume`  | Resume a previous session            |
| `/compact` | Compact conversation to save context |
| `/status`  | Show connection and session info     |
| `/exit`    | Close chat and return to projects    |
| `/help`    | Show command reference               |

### iPad Support

| Feature                | Description                               |
| ---------------------- | ----------------------------------------- |
| **Sidebar Navigation** | Projects list always visible in landscape |
| **Split View**         | Multitask alongside Safari, Notes         |
| **Keyboard Shortcuts** | Full keyboard navigation                  |

#### Keyboard Shortcuts

| Shortcut       | Action             |
| -------------- | ------------------ |
| `Cmd + Return` | Send message       |
| `Cmd + K`      | Clear conversation |
| `Cmd + N`      | New session        |
| `Cmd + .`      | Abort/Cancel       |
| `Cmd + /`      | Show help          |
| `Esc`          | Dismiss sheet      |

### SSH Terminal

| Feature                | Description                      |
| ---------------------- | -------------------------------- |
| **Native SSH**         | Built with Citadel (pure Swift)  |
| **Special Keys**       | Ctrl+C, Tab, arrows, Esc toolbar |
| **Key Authentication** | Ed25519, RSA, ECDSA support      |
| **Keychain Storage**   | Secure key storage on device     |

### Persistence

| Feature                      | Description                             |
| ---------------------------- | --------------------------------------- |
| **Message History**          | Last 50 messages saved per project      |
| **Draft Auto-save**          | Unsent messages preserved               |
| **Reconnection**             | Exponential backoff (1s-8s) with jitter |
| **Background Notifications** | Local alerts when tasks complete        |

## Requirements

- iOS 26.2+
- Xcode 15.0+
- A running [claudecodeui](https://github.com/siteboon/claudecodeui) backend
- Network access to the backend (via Tailscale or local network)

## Setup

### Backend Setup

The app connects to a claudecodeui backend (our fork adds session filtering, permission callbacks, and message batching). See [requirements/BACKEND.md](requirements/BACKEND.md) for setup instructions.

Quick start:

```bash
git clone https://github.com/wiseyoda/claudecodeui.git
cd claudecodeui && npm install && npm run build && npm start
```

### Building the App

1. Open `CodingBridge.xcodeproj` in Xcode
2. Select your target device (simulator or physical iPhone/iPad)
3. Press Cmd+R to build and run

### Configuration

On first launch, configure in Settings (gear icon):

| Setting               | Description                                        |
| --------------------- | -------------------------------------------------- |
| **Server URL**        | Backend address (default: `http://localhost:3100`) |
| **SSH Host/Port**     | SSH server for file operations (optional)          |
| **SSH Auth**          | Password or SSH key (Keychain)                     |
| **Font Size**         | XS / S / M / L / XL                                |
| **Theme**             | System / Dark / Light                              |
| **Model**             | Default Claude model                               |
| **Permission Mode**   | Normal (execute) / Plan (ask first)                |

### Local Development

Start cli-bridge backend:
```bash
cd ~/dev/cli-bridge
deno task dev  # Runs on http://localhost:3100

# Verify
curl -s http://localhost:3100/health
```

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   iOS App       │────▶│   cli-bridge    │────▶│ Claude Code CLI │
│   (SwiftUI)     │ SSE │  (Node.js)      │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │
        └───── Tailscale ───────┘
              (secure network)
```

### Key Components

| Component           | Purpose                                          |
| ------------------- | ------------------------------------------------ |
| `WebSocketManager`  | Real-time streaming, reconnection, message queue |
| `SessionStore`      | Centralized session state with pagination        |
| `SessionRepository` | Session data access (API + Mock for testing)     |
| `APIClient`         | REST API communication, JWT auth                 |
| `SSHManager`        | Terminal, file browser, git operations           |
| `SpeechManager`     | Voice input with iOS Speech framework            |
| `CommandStore`      | Saved prompts with categories                    |
| `IdeasStore`        | Per-project idea capture and persistence         |
| `ClaudeHelper`      | AI suggestions via Haiku                         |
| `MessageStore`      | File-based message persistence                   |
| `BookmarkStore`     | Cross-session bookmarks                          |

### View Structure

| View                 | Purpose                            |
| -------------------- | ---------------------------------- |
| `ContentView`        | Project list, navigation, settings |
| `ChatView`           | Message list, streaming, commands  |
| `TerminalView`       | SSH terminal with special keys     |
| `CLIInputView`       | Multi-line input, attachments      |
| `QuickSettingsSheet` | Model, mode, thinking level        |
| `CommandPickerSheet` | Saved command selection            |
| `FilePickerSheet`    | File browser for @ references      |
| `BookmarksView`      | Saved bookmarks list               |
| `GlobalSearchView`   | Cross-session search               |
| `IdeasDrawerSheet`   | Ideas management with FAB          |

## WebSocket Protocol

| Message Type          | Direction    | Description                    |
| --------------------- | ------------ | ------------------------------ |
| `claude-command`      | App → Server | Send user message              |
| `claude-response`     | Server → App | Streaming content              |
| `claude-complete`     | Server → App | Task finished                  |
| `token-budget`        | Server → App | Usage stats                    |
| `abort-session`       | App → Server | Cancel request                 |
| `sessions-updated`    | Server → App | Session list changed           |
| `permission-request`  | Server → App | Tool approval request          |
| `permission-response` | App → Server | Approve/deny/always-allow tool |

## Testing

300+ unit tests covering parsers and utilities:

```bash
xcodebuild test -project CodingBridge.xcodeproj -scheme CodingBridge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'
```

### Test Coverage

| Test Suite            | Coverage                        |
| --------------------- | ------------------------------- |
| `StringMarkdownTests` | Markdown parsing, HTML entities |
| `DiffViewTests`       | Edit tool diff parsing          |
| `TodoListViewTests`   | TodoWrite JSON parsing          |
| `ImageUtilitiesTests` | MIME type detection             |
| `ModelsTests`         | WebSocket message handling      |

## Permissions

The app requests these iOS permissions:

| Permission         | Purpose             |
| ------------------ | ------------------- |
| Microphone         | Voice-to-text input |
| Speech Recognition | Transcription       |
| Photo Library      | Image attachments   |

## Documentation

| File                                                         | Description                      |
| ------------------------------------------------------------ | -------------------------------- |
| [CHANGELOG.md](CHANGELOG.md)                                 | Version history and changes      |
| [ROADMAP.md](ROADMAP.md)                                     | Remaining work and priorities    |
| [ISSUES.md](ISSUES.md)                                       | Bug tracking and investigations  |
| [FUTURE-IDEAS.md](FUTURE-IDEAS.md)                           | Long-term vision and ideas       |
| [CLAUDE.md](CLAUDE.md)                                       | Claude Code project instructions |
| [requirements/OVERVIEW.md](requirements/OVERVIEW.md)         | Functional requirements          |
| [requirements/ARCHITECTURE.md](requirements/ARCHITECTURE.md) | System architecture              |
| [requirements/BACKEND.md](requirements/BACKEND.md)           | Backend setup guide              |
| [requirements/SESSIONS.md](requirements/SESSIONS.md)         | Session system deep dive         |

## License

MIT
