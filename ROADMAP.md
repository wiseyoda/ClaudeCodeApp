# ClaudeCodeApp Roadmap

> Feature roadmap for the iOS Claude Code client. Organized by priority with clear milestones.

---

## Status Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Completed |
| 🚧 | In Progress |
| 📋 | Planned (Next) |
| 💡 | Future Idea |

---

## Completed Milestones

| Milestone | Description | Date |
|-----------|-------------|------|
| **v1.0 Core** | WebSocket chat, markdown, tool viz, SSH terminal, voice input | Dec 2025 |
| **Copy & Share** | Copy buttons, context menus, share sheet | Dec 26 |
| **Project Mgmt** | Clone GitHub, create projects, file browser, @ references | Dec 27 |
| **Auto-Sync** | Git status indicators, auto-pull, sync banners | Dec 27 |
| **Sessions** | Session picker, rename, delete, export markdown | Dec 27 |
| **Tool Viz** | Tool colors/icons, rich headers, truncation, diff viewer | Dec 27 |
| **Models** | Opus/Sonnet/Haiku picker, per-session model switching | Dec 27 |
| **Connection** | Status indicator, pull-to-refresh, message queuing | Dec 27 |
| **iPad** | NavigationSplitView, keyboard shortcuts, sidebar, split view | Dec 27 |
| **SSH Keys** | Keychain storage, paste/import, Ed25519/RSA support | Dec 27 |
| **Thinking** | 5-level thinking mode (Normal → Ultrathink) | Dec 27 |
| **Search** | Message search, filters, bookmarks, cross-session search | Dec 27 |
| **AI Suggest** | Suggestion chips, AI file recommendations (POC) | Dec 27 |
| **Commands** | Command library, [+] menu picker, categories | Dec 27 |
| **UI Redesign** | Unified status bar, multi-line input, QuickSettings sheet | Dec 27 |

---

## Priority 1: Critical Bug Fixes 📋

Critical issues identified from codebase analysis that need immediate attention.

### Thread Safety & Race Conditions

| Issue | Location | Severity | Effort |
|-------|----------|----------|--------|
| **WebSocket state race** | `WebSocketManager.swift:196-230` | Critical | Medium |
| **WebSocket send race** | `WebSocketManager.swift:283-295, 344-361` | Critical | Medium |
| **APIClient missing @MainActor** | `APIClient.swift:3-104` | Critical | Low |
| **BookmarkStore thread safety** | `Models.swift:487-559` | High | Low |
| **MessageStore file race** | `Models.swift:360-396` | High | Medium |
| **ChatView state interleaving** | `ChatView.swift:140-192` | High | Medium |
| **Message queue overwrite** | `WebSocketManager.swift:104` | High | Medium |
| **Timeout logic bug** | `WebSocketManager.swift:134-169` | High | Low |

### Resource Management

| Issue | Location | Severity | Effort |
|-------|----------|----------|--------|
| **SpeechManager no deinit** | `SpeechManager.swift:5-126` | Critical | Low |
| **SSHManager dangling task** | `SSHManager.swift:536-543` | Critical | Low |

### Security

| Issue | Location | Severity | Effort |
|-------|----------|----------|--------|
| **SSH password in UserDefaults** | `AppSettings.swift:179-189` | High | Medium |
| **Hardcoded default password** | `AppSettings.swift:180` | High | Low |
| **Command injection** | `SSHManager.swift:700,747,856,879,946` | High | Medium |

### Fixes Required

1. **Add `@MainActor`** to `APIClient`, `BookmarkStore`, and other ObservableObjects
2. **Add `deinit`** to `SpeechManager` to clean up audio resources
3. **Synchronize MessageStore** - Add actor or DispatchQueue for file operations
4. **Escape shell commands** - Use proper quoting for SSH commands
5. **Migrate SSH password to Keychain** - Replace `@AppStorage` password storage
6. **Fix WebSocket state** - Set `.connected` after receive loop starts
7. **Replace `pendingMessage`** with a queue to prevent message loss

---

## Priority 2: Code Quality 📋

Developer experience and code health improvements.

| Feature | Description | Effort |
|---------|-------------|--------|
| **Syntax Highlighting** | Language-aware code coloring in code blocks | High |
| **Configurable History** | Make 50-message limit configurable | Low |
| **Error UI Component** | Centralized error display component | Medium |
| **Structured Logging** | Consistent Logger usage across all managers | Low |
| **Unit Test Coverage** | Expand tests for managers (WebSocket, SSH, Speech) | Medium |

---

## Priority 3: Power User Features 💡

Advanced features for power users.

| Feature | Description | Effort |
|---------|-------------|--------|
| **Multiple Servers** | Save/switch between server configs (work/home) | Medium |
| **Hybrid Model Mode** | Auto-select model based on task complexity | High |
| **Session Templates** | Saved prompts/contexts for common workflows | Medium |
| **Export All Sessions** | Bulk export project history | Low |

### Multiple Servers Concept

```
┌─ Servers ─────────────────────────┐
│ ● Home NAS (connected)            │
│   10.0.1.50:8080                  │
│                                   │
│ ○ Work Server                     │
│   work.example.com:8080           │
│                                   │
│ ○ Dev Container                   │
│   claude-dev:8080                 │
│                                   │
│ [+ Add Server]                    │
└───────────────────────────────────┘
```

---

## Priority 4: Platform Integration 💡

iOS platform features that enhance the experience.

| Feature | Description | Effort |
|---------|-------------|--------|
| **Home Screen Widget** | Quick-launch recent projects, show active sessions | High |
| **Shortcuts Integration** | Siri Shortcuts for common actions | Medium |
| **Share Extension** | Share text/code from other apps to Claude | Medium |
| **Handoff Support** | Continue conversations between devices | High |

---

## Not Planned

These have been considered but are not on the roadmap:

| Feature | Reason |
|---------|--------|
| **Haptic Feedback** | Keep it simple, not essential |
| **Sound Effects** | Not needed for the use case |
| **Custom Themes** | System/Dark/Light is sufficient |
| **Offline Mode** | Complexity outweighs benefit |
| **Apple Watch App** | Limited use case |
| **Message Virtualization** | Premature optimization (50-message limit handles this) |
| **Lazy Image Loading** | Premature optimization for current scale |

---

## Technical Notes

### Known Backend Issues

1. **CORS Limitation**: History API endpoints don't accept Authorization headers
   - Workaround: Load history via SSH from `~/.claude/projects/`
   - Proper fix requires backend change

2. **Session File Format**: JSONL with specific message types
   - Location: `~/.claude/projects/{encoded-path}/{session-id}.jsonl`
   - Encoded path: `/home/dev/project` → `-home-dev-project`

### Architecture Decisions

- **@StateObject** for managers (WebSocket, SSH, Speech)
- **@EnvironmentObject** for settings (shared across views)
- **File-based MessageStore** (migrated from UserDefaults)
- **ATS disabled** for local/Tailscale HTTP connections

---

## Implementation Order

```
Phase 1: Critical Fixes (P1)
├── Add @MainActor to APIClient, BookmarkStore      [Low effort]
├── Add deinit to SpeechManager                     [Low effort]
├── Fix WebSocket connection state                  [Medium effort]
├── Migrate SSH password to Keychain                [Medium effort]
├── Add message queue (replace pendingMessage)      [Medium effort]
└── Escape SSH commands                             [Medium effort]

Phase 2: Code Quality (P2)
├── Syntax highlighting                             [High effort]
├── Configurable history limit                      [Low effort]
└── Error UI component                              [Medium effort]

Phase 3: Power User (P3)
├── Multiple servers                                [Medium effort]
└── Export all sessions                             [Low effort]

Phase 4: Platform (P4)
├── Shortcuts integration                           [Medium effort]
└── Share extension                                 [Medium effort]
```

---

## Completed Features Log

<details>
<summary>December 2025 - Full Details</summary>

### v1.0 Core Features
- WebSocket real-time streaming chat
- Full markdown rendering (headers, code, tables, lists, math)
- Tool visualization with collapsible messages
- Diff viewer for Edit tool
- TodoWrite visual checklist
- AskUserQuestion interactive UI
- Image attachments via PhotosPicker
- Voice input with Speech framework
- SSH terminal with Citadel
- Message persistence (50 per project)
- Draft auto-save per project
- Local notifications on task completion
- Slash commands (/clear, /init, /resume, /help, etc.)

### Copy & Share
- Copy button on assistant messages
- Long-press context menu
- Share sheet with iPad support

### Project Management
- Clone from GitHub URL via SSH
- Create new empty projects
- Delete projects with confirmation
- File browser with breadcrumb navigation
- @ button for file references

### Auto-Sync
- GitStatus enum with 10 states
- Background status checking
- GitStatusIndicator icons
- Auto-pull for clean projects
- GitSyncBanner with "Ask Claude" action

### Session Management
- SessionNamesStore for custom names
- Full-screen session picker
- Rename, delete, export sessions
- Message count and preview in rows

### Tool Visualization
- ToolType enum with 12 tools
- Distinct colors and SF Symbol icons
- Rich headers with key params
- Result count badges
- TruncatableText with fade + expand
- Enhanced DiffView with line numbers
- Context collapsing in diffs
- Quick action copy buttons

### Model Selection
- ClaudeModel enum (Opus/Sonnet/Haiku/Custom)
- Model selector pill in nav bar
- Model passed via WebSocket options
- Default model in settings

### Connection Health
- ConnectionState enum
- ConnectionStatusIndicator with animated pulsing dot
- Color-coded status (green/yellow/red)
- Pull-to-refresh on project list
- Message queuing with retry logic

### iPad Experience
- Keyboard shortcuts (Cmd+Return, Cmd+K, Cmd+N, Cmd+., Cmd+/, Esc)
- NavigationSplitView with sidebar
- ProjectRow with selection indicator
- Split view multitasking support

### SSH Key Import
- KeychainHelper for secure storage
- SSHKeyType enum (Ed25519, RSA, ECDSA)
- SSHKeyImportSheet with paste/file import
- Passphrase support for encrypted keys
- Auto-connect priority: SSH Config → Keychain → Filesystem → Password

### Thinking Mode
- ThinkingMode enum with 5 levels
- ThinkingModeIndicator in status bar
- Silently appends trigger words to messages
- Distinct icons and purple gradient colors

### Search & Discovery
- Message search with filter chips
- MessageFilter enum (All/User/Assistant/Tools/Thinking)
- BookmarkStore with Documents persistence
- BookmarksView with swipe-to-delete
- GlobalSearchView for cross-session SSH search

### AI Suggestions (POC)
- ClaudeHelper meta-AI service using Haiku
- Suggestion chips after responses
- File context suggestions in picker
- Separate WebSocket with 15-second timeout

### Command Library
- SavedCommand model with categories
- CommandStore singleton with JSON persistence
- CommandsView for CRUD management
- CommandPickerSheet for quick selection
- Integration in [+] attachment menu
- Last-used tracking and sorting

### UI Redesign
- UnifiedStatusBar (model, connection, thinking mode, tokens)
- QuickSettingsSheet for fast setting changes
- Multi-line text input with word wrap
- [+] button menu (commands, files, images, voice)
- Removed redundant header icons

</details>

---

*Last updated: December 27, 2025*
