# ClaudeCodeApp Roadmap

> Feature roadmap for the iOS Claude Code client. Organized by priority with iterative milestones.

---

## Status Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Completed |
| 🚧 | In Progress |
| 📋 | Planned |
| 💡 | Idea/Future |

---

## Current Release: v1.0

### Core Features ✅
- [x] WebSocket real-time streaming chat
- [x] Full markdown rendering (headers, code, tables, lists, math)
- [x] Tool visualization with collapsible messages
- [x] Diff viewer for Edit tool (red/green highlighting)
- [x] TodoWrite visual checklist rendering
- [x] AskUserQuestion interactive UI
- [x] Image attachments via PhotosPicker
- [x] Voice input with Speech framework
- [x] SSH terminal with Citadel
- [x] Message persistence (50 per project)
- [x] Draft auto-save per project
- [x] Local notifications on task completion
- [x] Slash commands (/clear, /init, /resume, /help, etc.)

### Settings ✅
- [x] iOS Form-style settings UI
- [x] Theme selection (System/Dark/Light)
- [x] Font size presets (XS/S/M/L/XL)
- [x] Skip Permissions toggle
- [x] Show Thinking Blocks toggle
- [x] Auto-scroll toggle
- [x] Project sort order (Name/Date)
- [x] API Key field for REST endpoints

---

## Milestone 1: Copy & Share 📋

**Goal:** Make it easy to copy and share Claude's responses.

| Feature | Description | Effort |
|---------|-------------|--------|
| Copy Message as Markdown | Button on assistant messages to copy full text | Low |
| Copy Code Block | Tap-to-copy on code blocks (already exists, verify working) | Low |
| Long-press Context Menu | Copy, Share, Bookmark options on messages | Medium |
| Share Sheet Integration | iOS share sheet for sending to other apps | Low |

### Implementation Notes
- Add copy button (📋) to message header for assistant messages
- Ensure code blocks have working copy button
- Context menu: `.contextMenu { }` modifier on message views

---

## Milestone 2: Project Management & File Browser 📋

**Goal:** Create/manage projects and browse project files.

| Feature | Description | Effort |
|---------|-------------|--------|
| Clone from GitHub URL | Paste URL → clone to workspace → init Claude | Medium |
| Create New Project | Create folder in workspace, optionally init Claude | Low |
| Browse GitHub Repos | OAuth + list user's repos, select to clone | High |
| Delete/Archive Project | Remove projects from list (with confirmation) | Low |
| **File Browser** | List/navigate project files via SSH or API | Medium |
| **@ File References** | Mobile-friendly file picker to reference files in prompts | Medium |

### Implementation Notes
- Clone via SSH: `git clone <url>` through SSHManager
- New project: `mkdir` + optional `claude init`
- GitHub OAuth would require significant work - defer to later
- Start with URL clone + new project creation
- File browser: `ls -la` via SSH or new API endpoint
- @ references: Button next to input that opens file picker sheet

### File Reference UI Concept
```
┌─────────────────────────────────┐
│ > Type a message...    [@] 📷 🎤│  ← @ button opens file picker
└─────────────────────────────────┘

┌─ Select File ───────────────────┐
│ 🔍 Search files...              │
├─────────────────────────────────┤
│ 📁 src/                         │
│ 📁 components/                  │
│ 📄 package.json                 │
│ 📄 README.md                    │
│ 📄 tsconfig.json                │
└─────────────────────────────────┘
        ↓ tap file
┌─────────────────────────────────┐
│ > @src/index.ts explain this   │
└─────────────────────────────────┘
```

### Project Creation UI
```
┌─────────────────────────────────┐
│ + New Project                   │
├─────────────────────────────────┤
│ 📁 Create Empty Project         │
│ 🔗 Clone from GitHub URL        │
│ ⭐ Browse My Repositories       │
└─────────────────────────────────┘
```

---

## Milestone 3: Session Management 📋

**Goal:** Better organization and navigation of chat sessions.

| Feature | Description | Effort |
|---------|-------------|--------|
| Enhanced Session Picker | Full-screen list with summaries, timestamps | Medium |
| Session Preview | Show last message or AI-generated summary | Low |
| Rename Session | Custom names instead of UUIDs | Low |
| Delete Session | Swipe or long-press to delete | Low |
| Export Session | Save as .md file to Files app | Medium |

### UI Concept
```
┌─────────────────────────────────────┐
│ Sessions                    [+ New] │
├─────────────────────────────────────┤
│ "Add authentication feature"        │
│ 12 messages • 2 min ago             │
├─────────────────────────────────────┤
│ "Fix database connection bug"       │
│ 8 messages • 1 hour ago             │
├─────────────────────────────────────┤
│ Session 5836831b...                 │
│ 3 messages • Yesterday              │
└─────────────────────────────────────┘
```

---

## Milestone 4: iPad Optimization 📋

**Goal:** First-class iPad experience with sidebar and keyboard support.

| Feature | Description | Effort |
|---------|-------------|--------|
| Sidebar Navigation | Projects list always visible on left (landscape) | Medium |
| NavigationSplitView | Proper iPad navigation pattern | Medium |
| Keyboard Shortcuts | Cmd+Return send, Cmd+K new session, Esc cancel | Low |
| Split View Support | Run alongside Safari, Notes in multitasking | Low |

### Keyboard Shortcuts
| Shortcut | Action |
|----------|--------|
| `⌘ + Return` | Send message |
| `⌘ + K` | New session |
| `⌘ + .` | Abort/Cancel |
| `⌘ + L` | Clear conversation |
| `⌘ + /` | Show help |
| `Esc` | Dismiss sheet/abort |

---

## Milestone 5: Enhanced Tool Visualization 💡

**Goal:** Richer display of tool calls and results.

| Feature | Description | Effort |
|---------|-------------|--------|
| Richer Tool Headers | Show key params: `Grep "pattern" → 12 files` | Medium |
| Result Count Badge | Show match count when collapsed | Low |
| Tool Type Colors | Different accent per tool type | Low |
| Syntax Highlighting | Language-aware code coloring | High |
| Quick Actions | Copy path, copy command, expand all | Medium |

---

## Milestone 6: Search & Bookmarks 💡

**Goal:** Find and save important messages.

| Feature | Description | Effort |
|---------|-------------|--------|
| Message Search | Full-text search across current session | Medium |
| Search Across Sessions | Find messages in any session | High |
| Bookmark Messages | Star important messages | Low |
| Filter by Type | Show only user/assistant/tool messages | Low |
| Bookmark View | Dedicated screen for saved messages | Medium |

---

## Completed Features Log

### December 2024
- ✅ Slash commands (/clear, /init, /resume, /compact, /status, /exit, /help)
- ✅ Help sheet with command reference
- ✅ Session picker sheet for /resume
- ✅ TodoWrite visual checklist rendering
- ✅ AskUserQuestion interactive selection UI
- ✅ Auto-focus input field on load
- ✅ Improved numbered list parsing (sub-items)
- ✅ REST API integration (session history, image uploads)
- ✅ Settings overhaul (iOS Form style)
- ✅ Light mode support
- ✅ Font size presets

---

## Technical Debt & Maintenance

> **See [HARDENING.md](./HARDENING.md) for detailed implementation plan.**

| Item | Description | Priority | Status |
|------|-------------|----------|--------|
| ChatView.swift size | 2,300+ lines - split into modules | **High** | 📋 Planned |
| AppSettings injection | Fix inconsistent pattern across views | **High** | 📋 Planned |
| Theme migration | Complete colorScheme-aware migration | **High** | 📋 Planned |
| MessageStore storage | Move from UserDefaults to file-based | **High** | 📋 Planned |
| Code duplication | Consolidate utilities (MIME detection) | Medium | 📋 Planned |
| Error handling | User-facing errors + retry logic | **High** | 📋 Planned |
| Test coverage | Unit tests for parsers, managers | Medium | 📋 Planned |
| Accessibility | VoiceOver support, Dynamic Type | **High** | 📋 Planned |

---

## Not Planned

These features have been considered but are not on the roadmap:

- **Haptic feedback** - Keep it simple
- **Sound effects** - Not needed
- **Custom themes** - System/Dark/Light is sufficient
- **Offline mode** - Complexity outweighs benefit
- **Apple Watch app** - Limited use case

---

## Implementation Approach

**Iterative & Mixed:** Tackle small wins across all areas rather than completing one milestone fully before starting another. Prioritize features that improve daily workflow.

**Next Actions:**

### Hardening First (see HARDENING.md)
1. Fix AppSettings injection pattern
2. Complete Theme migration to colorScheme-aware
3. Break up ChatView.swift into modules
4. Fix MessageStore (file-based storage)
5. Add unit tests for parsers

### Then Features
6. Copy Message as Markdown (quick win)
7. File Browser + @ References (core workflow feature)
8. Clone from GitHub URL (enables new workflows)
9. Enhanced Session Picker (improves navigation)
10. iPad Sidebar (larger screen optimization)

---

*Last updated: December 2024*
