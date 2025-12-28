# Claude Code iOS App - Requirements Overview

## Project Goal

Create a native iOS application that provides a full-featured mobile interface to Claude Code, enabling developers to interact with Claude CLI from their iPhone or iPad while away from their desk.

## Background

The [claudecodeui](https://github.com/wiseyoda/claudecodeui) project (our fork) provides a web-based interface for Claude Code. This iOS app acts as a native client for that same backend, providing a polished mobile experience with native features like voice input, keyboard shortcuts, and Keychain storage.

> **Note**: We use a fork of siteboon/claudecodeui that adds session filtering, permission callbacks, and message batching.

## Target Users

- Developers who use Claude Code for coding assistance
- Users who want to interact with Claude Code from mobile devices
- Teams running Claude Code on remote servers (NAS, cloud, etc.)
- iPad users who want a native development companion

## Key Requirements

### Functional Requirements

#### 1. Project Management
- List all available projects from the backend
- Display project name, path, and session count
- Navigate to project chat view
- Clone projects from GitHub URL
- Create new empty projects
- Delete projects from list (with confirmation)
- Project registration with Claude via session files
- Git status tracking with 10 states (clean, dirty, ahead, behind, etc.)
- Auto-pull for behind repositories

#### 2. Session Management
- Session selection for resuming conversations
- Full-screen session picker with summaries and timestamps
- Real-time session updates via WebSocket push events
- Pagination with "Load More" for large session lists
- Bulk operations: delete all, older than N days, keep last N
- Rename sessions with custom names (persisted via SessionNamesStore)
- Delete sessions with swipe-to-delete (optimistic UI with rollback)
- Export sessions as markdown with share sheet
- Session history loaded via API (with SSH fallback for messages)
- Clean Architecture: SessionStore (state) → SessionRepository (data) → APIClient (HTTP)

#### 3. Chat Interface
- Send messages to Claude (text, voice, or with images)
- Receive streaming responses in real-time via WebSocket
- Display tool usage with collapsible sections (12+ tool types)
- Display tool results (truncated with expand option)
- Show thinking/reasoning blocks (purple, collapsible)
- Diff visualization for Edit tool changes with line numbers
- TodoWrite visual checklist with status colors
- AskUserQuestion interactive selection UI
- Code blocks with copy button
- Full markdown rendering (headers, tables, lists, math)
- Copy and share messages via context menu
- Bookmark important messages

#### 4. Model Selection
- Opus 4, Sonnet 4, Haiku 3.5, Custom model support
- Model selector in unified status bar
- Model passed via WebSocket options
- Per-session model switching

#### 5. Thinking Modes
- 5 levels: Normal, Think, Think Hard, Think Harder, Ultrathink
- Visual indicator with distinct icons and colors
- Silently appends trigger words to messages
- Persisted via @AppStorage

#### 6. Slash Commands
| Command | Action |
|---------|--------|
| `/clear` | Clear conversation and start fresh |
| `/new` | Start a new session |
| `/init` | Create/modify CLAUDE.md (via Claude) |
| `/resume` | Open session picker |
| `/compact` | Compact conversation to save context |
| `/status` | Show connection and session info |
| `/exit` | Return to project list |
| `/help` | Show command reference |

#### 7. File Browser & References
- Browse project files via SSH
- Breadcrumb navigation for directories
- Search/filter files by name
- @ button to insert file references into prompts
- AI-suggested files based on conversation context

#### 8. Message Persistence
- Save last 50 messages per project (file-based storage)
- Auto-save draft input text
- Load history on view appear
- Clear history with "New Chat" button
- Image storage in Documents directory

#### 9. Voice Input
- Speech-to-text via iOS Speech Recognition
- Real-time transcription with partial results
- Recording indicator in input bar
- Microphone button for quick access

#### 10. Image Attachments
- Photo library picker integration
- Image preview before sending with remove option
- Images displayed inline in messages

#### 11. SSH Terminal
- Native SSH client via Citadel library
- Special keys bar (Ctrl+C, Tab, arrows, etc.)
- Password and SSH key authentication
- Ed25519, RSA, ECDSA key support
- Keychain storage for secure keys
- Auto-connect with stored settings

#### 12. Search & Discovery
- Message search within current session
- Filter by message type (All/User/Assistant/Tools/Thinking)
- Bookmark messages with cross-session persistence
- Global search across all sessions via SSH
- Search results with project context

#### 13. Command Library
- Save frequently-used prompts as named commands
- Organize by categories (Git, Code Review, Testing, Docs)
- Quick picker accessible from [+] menu
- Last-used tracking and sorting
- CRUD management interface

#### 14. AI Suggestions
- Context-aware action chips after responses
- Haiku-powered fast suggestions
- Suggested files in file picker
- Tappable chips that auto-send prompts

#### 15. Ideas Drawer
- Capture ideas during long-running Claude operations
- Floating action button (FAB) with count badge
- Quick capture via long-press on FAB
- Full idea editor with title, content, and tags
- Per-project idea persistence (IdeasStore)
- Archive/restore functionality
- Search and filter by tag
- AI enhancement support (expanded prompt, suggested follow-ups)

#### 16. iPad Experience
- NavigationSplitView with sidebar for projects
- Keyboard shortcuts (Cmd+Return, Cmd+K, Cmd+N, etc.)
- Split-view multitasking support
- Landscape orientation optimization

#### 17. Permission Approval
- Interactive approval banner when bypass permissions is OFF
- Approve / Always Allow / Deny buttons for each tool request
- Per-project permission mode overrides (ProjectSettingsStore)
- Real-time WebSocket protocol for permission requests/responses
- "Always Allow" remembers decisions per tool type

#### 18. Configuration
| Setting | Options |
|---------|---------|
| Server URL | Backend address |
| Auth | Username/password (JWT) |
| SSH | Host, port, username, auth method |
| Font Size | XS / S / M / L / XL |
| Theme | System / Dark / Light |
| Model | Opus / Sonnet / Haiku / Custom |
| Permission Mode | Normal / Plan / Bypass |
| Thinking Mode | 5 levels |
| Display | Show thinking, auto-scroll |
| Sort | By name / By date |

#### 19. Notifications
- Local notifications when tasks complete (background only)
- Request notification permissions on launch

### Non-Functional Requirements

#### 1. Performance
- Streaming responses must feel responsive
- App should handle long conversations without lag
- Exponential backoff reconnection (1s->2s->4s->8s + jitter)
- 30-second processing timeout with auto-reset

#### 2. Security
- JWT token-based authentication
- SSH key and password storage in iOS Keychain (via KeychainHelper)
- Shell command escaping via `shellEscape()` function
- Network-level security via Tailscale
- ATS disabled for local/Tailscale IPs only

#### 3. Usability
- CLI-inspired theme with light/dark mode support
- Support for iOS 26.2+
- Works on iPhone and iPad
- VoiceOver accessibility labels on interactive elements
- Keyboard shortcuts for iPad users

#### 4. Quality
- 300+ unit tests for parsers, utilities, stores, and models
- Structured logging via Logger utility
- Unified error handling via AppError
- Debug log viewer for WebSocket traffic troubleshooting

## Completed Features

### Core
- Real-time streaming chat via WebSocket
- Tool use visualization with 12+ tool types
- Diff viewer for Edit tool with line numbers
- TodoWrite visual checklist
- AskUserQuestion interactive UI
- Full markdown rendering
- Voice input with Speech framework
- Image attachments
- SSH terminal with key support
- File browser with @ references
- Project clone from GitHub
- Project creation and deletion
- Session rename, delete, export
- Slash commands

### Advanced
- Model selection (Opus/Sonnet/Haiku/Custom)
- Thinking modes (5 levels)
- Message search and filtering
- Bookmarks with cross-session persistence
- Global search via SSH
- Command library with categories
- AI suggestions (Haiku-powered)
- Ideas Drawer with FAB, tags, and archive
- iPad sidebar navigation
- Keyboard shortcuts
- Git status with auto-pull
- Connection status indicator
- Unified status bar
- QuickSettings sheet
- Permission approval banner with Always Allow
- Per-project settings overrides
- Debug log viewer for troubleshooting
- Bulk session operations
- Session API with pagination

### Quality
- Copy/share context menus
- Light/dark theme support
- File-based message persistence
- 300+ unit tests
- Structured logging

## Out of Scope (Current Version)

| Feature | Reason |
|---------|--------|
| Push notifications (APNs) | Using local notifications instead |
| Offline mode | Complexity outweighs benefit |
| Multiple backend servers | Future priority (see ROADMAP.md) |
| File attachments beyond images | Not essential for v1 |
| GitHub OAuth integration | Backend handles auth |
| Syntax highlighting in code blocks | Future priority |

## Known Issues

See [ROADMAP.md](../ROADMAP.md) for remaining work and [ISSUES.md](../ISSUES.md) for investigation items.

**Resolved in v0.4.0:**
- ✅ @MainActor added to APIClient and BookmarkStore
- ✅ SpeechManager resource leak fixed with proper deinit
- ✅ SSH password migrated to Keychain (via KeychainHelper)
- ✅ Command injection fixed with shell escaping
- ✅ WebSocket state race fixed (connection state timing)

**Remaining:**
- WebSocket state serialization (concurrent state access)
- @MainActor on BookmarkStore in Models.swift
