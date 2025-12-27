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

---

## Priority 1: Foundation & Reliability 📋

These improvements affect the core experience and should be addressed first.

### Connection Health & Recovery

| Feature | Description | Effort |
|---------|-------------|--------|
| **Connection Status Indicator** | Persistent subtle indicator showing WebSocket health (connected/reconnecting/offline) | Low |
| **Request Queuing** | Queue messages during disconnect, replay on reconnect | Medium |
| **Pull-to-Refresh** | Refresh project list and reconnect WebSocket with pull gesture | Low |

**Implementation Notes:**
- Add `ConnectionState` enum: `.connected`, `.connecting`, `.reconnecting`, `.disconnected`
- Show colored dot in nav bar (green/yellow/red)
- Store pending messages in array, flush on reconnect
- Standard `refreshable` modifier for project list

---

## Priority 2: iPad Experience 📋

First-class iPad support with keyboard and sidebar navigation.

### Features

| Feature | Description | Effort |
|---------|-------------|--------|
| **Sidebar Navigation** | Projects list always visible in landscape | Medium |
| **NavigationSplitView** | Proper iPad navigation pattern | Medium |
| **Keyboard Shortcuts** | Cmd+Return send, Cmd+K clear, Cmd+. abort | Low |
| **Split View Support** | Multitasking alongside Safari, Notes | Low |

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

## Priority 3: Search & Discovery 📋

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
1. Connection Status + Pull-to-Refresh  [Low effort, high impact]
2. Request Queuing                      [Medium effort, reliability]
3. iPad Keyboard Shortcuts              [Low effort, iPad users]
4. iPad Sidebar Navigation              [Medium effort, iPad UX]
5. Message Search (current session)     [Medium effort, productivity]
6. Bookmark Messages                    [Low effort, organization]
7. Syntax Highlighting                  [High effort, polish]
8. Multiple Servers                     [Medium effort, power users]
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

</details>

---

*Last updated: December 27, 2024*
