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

## Priority 2: Search & Discovery 📋

Find and organize important content.

### Features

| Feature | Description | Effort |
|---------|-------------|--------|
| **Message Search** | Full-text search within current session | Medium |
| **Cross-Session Search** | Find messages across all sessions | High |
| **Bookmark Messages** | Star important messages for quick access | Low |
| **Filter by Type** | Show only user/assistant/tool messages | Low |
| **Bookmarks View** | Dedicated screen for saved messages | Medium |

---

## Priority 3: Code Quality 💡

Developer experience and code health improvements.

### Features

| Feature | Description | Effort |
|---------|-------------|--------|
| **Syntax Highlighting** | Language-aware code coloring in code blocks | High |
| **Configurable History** | Make 50-message limit configurable | Low |
| **Error UI Component** | Centralized error display component | Medium |

---

## Priority 4: Power User Features 💡

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

## Priority 5: Platform Integration 💡

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
3. Message Search (current session)     [Medium effort, productivity] ✅ Next
4. Bookmark Messages                    [Low effort, organization]
5. Syntax Highlighting                  [High effort, polish]
6. Multiple Servers                     [Medium effort, power users]
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

</details>

---

*Last updated: December 27, 2024*
