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
| **v1.0 Core** | WebSocket chat, markdown, tool visualization, SSH terminal | Dec 2024 |
| **M1: Copy & Share** | Copy buttons, context menus, share sheet | Dec 26 |
| **M2: Project Management** | Clone from GitHub, create projects, file browser, @ references | Dec 27 |
| **M3: Auto-Sync** | Git status indicators, auto-pull, sync banners | Dec 27 |
| **M4: Session Management** | Session picker, rename, delete, export as markdown | Dec 27 |
| **M6: Tool Visualization** | Tool colors/icons, rich headers, truncation, enhanced diff | Dec 27 |
| **Model Selection** | Opus/Sonnet/Haiku picker, per-session model switching | Dec 27 |
| **P1: Connection Health** | Connection status indicator, pull-to-refresh, message queuing | Dec 27 |
| **P1: iPad Experience** | NavigationSplitView, keyboard shortcuts, sidebar, split view | Dec 27 |
| **SSH Key Import** | Keychain storage, paste/import keys, Ed25519/RSA support | Dec 27 |
| **Thinking Mode** | 5-level thinking mode toggle (Normal/Think/Think Hard/Think Harder/Ultrathink) | Dec 27 |
| **P3: Search & Discovery** | Message search, filters, bookmarks, cross-session search | Dec 27 |
| **AI Suggestions (POC)** | Suggestion chips after responses, AI-powered file suggestions in picker | Dec 27 |

---

## ~~Priority 1: iPad Experience~~ ✅ Complete

First-class iPad support with keyboard and sidebar navigation.

### Features

| Feature | Description | Status |
|---------|-------------|--------|
| **Keyboard Shortcuts** | Cmd+Return send, Cmd+K clear, Cmd+. abort, Cmd+/ help, Cmd+R resume, Esc dismiss | ✅ Done |
| **Sidebar Navigation** | Projects list always visible in landscape | ✅ Done |
| **NavigationSplitView** | Proper iPad navigation pattern | ✅ Done |
| **Split View Support** | Multitasking alongside Safari, Notes | ✅ Done |

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘ + Return` | Send message |
| `⌘ + K` | Clear conversation |
| `⌘ + N` | New session |
| `⌘ + .` | Abort/Cancel |
| `⌘ + /` | Show help |
| `Esc` | Dismiss sheet |

---

## Priority 2: Command Library 📋

Save and reuse common prompts/commands across all projects.

### Features

| Feature | Description | Effort |
|---------|-------------|--------|
| **Command Picker** | Tap `>` button to open saved commands sheet | Medium |
| **Command Management** | Dedicated tab to add/edit/delete commands | Medium |
| **Categories** | Organize commands (Git, Code Review, Testing, etc.) | Low |
| **Multi-line Support** | Commands can be detailed multi-line prompts | Low |

### Key Design Decisions

- Access via repurposed `>` icon in input bar (with more padding to prevent accidental taps)
- Dedicated tab in main navigation for CRUD management
- Commands organized by user-defined categories (Git, Code Review, Testing, etc.)
- No variables/placeholders for v1
- App-wide storage (not project-specific), stored in Documents/commands.json
- Multi-line commands supported, sent all at once

### Access Flow

```
┌─ Chat Input ──────────────────────────┐
│ [>] Ask Claude anything...    [🎤][▶] │
└───────────────────────────────────────┘
       │
       ▼ Tap >
┌─ Saved Commands ──────────────────────┐
│ ┌─ Git ────────────────────────────┐ │
│ │ • Commit current changes          │ │
│ │ • Review staged files             │ │
│ └───────────────────────────────────┘ │
│ ┌─ Code Review ────────────────────┐ │
│ │ • Review this file                │ │
│ │ • Find potential bugs             │ │
│ └───────────────────────────────────┘ │
│ ┌─ Testing ────────────────────────┐ │
│ │ • Run tests and fix failures      │ │
│ │ • Add test coverage               │ │
│ └───────────────────────────────────┘ │
└───────────────────────────────────────┘
```

### Management UI

```
┌─ Commands ─────────────────────────────┐
│ ◀ Back                          [+ Add]│
├─────────────────────────────────────────┤
│ Git (3 commands)                    >  │
├─────────────────────────────────────────┤
│ Code Review (2 commands)            >  │
├─────────────────────────────────────────┤
│ Testing (4 commands)                >  │
├─────────────────────────────────────────┤
│ Docs (2 commands)                   >  │
└─────────────────────────────────────────┘
         │
         ▼ Tap category
┌─ Git Commands ─────────────────────────┐
│ ◀ Commands                      [+ Add]│
├─────────────────────────────────────────┤
│ Commit current changes                 │
│ Last used: 2 hours ago          [Edit] │
├─────────────────────────────────────────┤
│ Review staged files                    │
│ Last used: yesterday            [Edit] │
├─────────────────────────────────────────┤
│ Push and create PR                     │
│ Last used: 3 days ago           [Edit] │
└─────────────────────────────────────────┘
         │
         ▼ Tap Edit or swipe to delete
```

### Data Model

```swift
struct SavedCommand: Identifiable, Codable {
    let id: UUID
    var name: String
    var content: String
    var category: String
    var createdAt: Date
    var lastUsedAt: Date?
}
```

---

## ~~Priority 3: Search & Discovery~~ ✅ Complete

Find and organize important content.

### Features

| Feature | Description | Status |
|---------|-------------|--------|
| **Message Search** | Full-text search within current session with search bar and result highlighting | ✅ Done |
| **Filter by Type** | Filter chips for All/User/Assistant/Tools/Thinking messages | ✅ Done |
| **Bookmark Messages** | Long-press context menu to bookmark, persisted to Documents | ✅ Done |
| **Bookmarks View** | Dedicated sheet showing all bookmarks with search, swipe-to-delete | ✅ Done |
| **Cross-Session Search** | SSH-based search across all session JSONL files | ✅ Done |

### Implementation Details

- **Search UI**: Search button in ChatView toolbar, collapsible search bar with cancel
- **Filter Chips**: Horizontal scrolling chips below search bar (All, User, Assistant, Tools, Thinking)
- **BookmarkStore**: Singleton storing bookmarks in Documents/bookmarks.json
- **Global Search**: Accessed from ContentView toolbar, uses SSH to grep session files

---

## Priority 4: Code Quality 💡

Developer experience and code health improvements.

### Features

| Feature | Description | Effort |
|---------|-------------|--------|
| **Syntax Highlighting** | Language-aware code coloring in code blocks | High |
| **Configurable History** | Make 50-message limit configurable | Low |
| **Error UI Component** | Centralized error display component | Medium |

---

## Priority 5: Power User Features 💡

Advanced features for power users.

### Features

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

### Hybrid Model Mode Concept

| Phase | Model | Use Case |
|-------|-------|----------|
| Planning | Opus | Complex reasoning, architecture |
| Execution | Sonnet | Writing code, running commands |
| Quick answers | Haiku | Simple queries, small fixes |

---

## Priority 6: Platform Integration 💡

iOS platform features that enhance the experience.

### Features

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
1. iPad Keyboard Shortcuts              [Low effort, iPad users] ✅ Done
2. iPad Sidebar Navigation              [Medium effort, iPad UX] ✅ Done
3. Thinking Mode                        [Low effort, power users] ✅ Done
4. Message Search (current session)     [Medium effort, discovery] ✅ Done
5. Filter by Type                       [Low effort, discovery] ✅ Done
6. Bookmark Messages                    [Low effort, organization] ✅ Done
7. Bookmarks View                       [Medium effort, organization] ✅ Done
8. Cross-Session Search                 [High effort, discovery] ✅ Done
9. Command Picker                       [Medium effort, productivity] ← Next
10. Syntax Highlighting                 [High effort, polish]
11. Multiple Servers                    [Medium effort, power users]
```

---

## Completed Features Log

<details>
<summary>December 2024 - Full Details</summary>

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

### M1: Copy & Share
- Copy button on assistant messages
- Long-press context menu
- Share sheet with iPad support

### M2: Project Management
- Clone from GitHub URL via SSH
- Create new empty projects
- Delete projects with confirmation
- File browser with breadcrumb navigation
- @ button for file references

### M3: Auto-Sync
- GitStatus enum with 10 states
- Background status checking
- GitStatusIndicator icons
- Auto-pull for clean projects
- GitSyncBanner with "Ask Claude" action

### M4: Session Management
- SessionNamesStore for custom names
- Full-screen session picker
- Rename, delete, export sessions
- Message count and preview in rows

### M6: Tool Visualization
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

### P1: Connection Health
- ConnectionState enum (.connected/.connecting/.reconnecting/.disconnected)
- ConnectionStatusIndicator view with animated pulsing dot
- Color-coded status (green=connected, yellow=connecting, red=disconnected)
- Pull-to-refresh on project list with .refreshable modifier
- Message queuing with retry logic (already existed, now visible)

### iPad Keyboard Shortcuts
- Cmd+Return: Send message
- Cmd+K: Clear conversation
- Cmd+N: New session
- Cmd+.: Abort current request
- Cmd+/: Show help
- Cmd+R: Resume session picker
- Esc: Dismiss sheets (via Done button)
- Updated SlashCommandHelpSheet with keyboard shortcuts section
- KeyboardShortcutRow component with styled key badges

### iPad Sidebar Navigation
- NavigationSplitView for iPad with sidebar + detail layout
- Project list as sidebar with selection state
- ProjectRow with isSelected visual indicator (● vs >)
- noProjectSelectedView placeholder when no project selected
- Project struct conforms to Hashable for List selection
- Balanced navigation split view style
- Works on iPhone (collapses to stack) and iPad (shows sidebar)
- Split view multitasking support enabled

### SSH Key Import
- KeychainHelper class for secure key storage in iOS Keychain
- SSHKeyType enum for Ed25519, RSA, ECDSA detection
- SSHKeyDetection helper for parsing OpenSSH and PEM key formats
- SSHKeyImportSheet with paste and file import options
- Settings UI shows key status (Configured/Not configured)
- Import from Files app with document picker
- Passphrase support for encrypted keys
- Auto-connect priority: SSH Config → Keychain Key → Filesystem Key → Password
- Works on iPhone (no ~/.ssh access) via Keychain storage

### Thinking Mode
- ThinkingMode enum with 5 levels: Normal, Think, Think Hard, Think Harder, Ultrathink
- ThinkingModeIndicator in bottom status bar (CLIModeSelector)
- Silently appends trigger words to messages ("think", "think hard", etc.)
- Distinct icons and purple gradient colors per level
- Persisted via @AppStorage

### P3: Search & Discovery
- **Message Search**: Search bar in ChatView toolbar, filter chips below
- **MessageFilter enum**: All, User, Assistant, Tools, Thinking filters
- **ChatSearchBar**: Collapsible search with cancel button
- **SearchResultCount**: Shows filtered count
- **BookmarkStore**: Singleton persisting to Documents/bookmarks.json
- **BookmarkedMessage**: Stores message with project context
- **BookmarksView**: Sheet with searchable list, swipe-to-delete
- **GlobalSearchView**: SSH-based cross-session search
- **CLIMessageView**: Long-press context menu with bookmark toggle

### AI Suggestions (POC)
- **ClaudeHelper**: Meta-AI service using Haiku for fast suggestions
- **Suggestion Chips**: Tappable action suggestions after Claude completes
- **SuggestionChipsView**: Horizontal scrollable chips below input
- **File Context Suggestions**: AI-recommended files in file picker
- **SuggestedFilesSection**: "Suggested" section with sparkle icon in picker
- Uses separate WebSocket connection with 15-second timeout
- Prompts Haiku for JSON responses, parses into actionable UI

</details>

---

*Last updated: December 27, 2024*
