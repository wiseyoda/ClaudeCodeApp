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

## Milestone 1: Copy & Share ✅

**Goal:** Make it easy to copy and share Claude's responses.

| Feature | Description | Status |
|---------|-------------|--------|
| Copy Message as Markdown | Button on assistant messages to copy full text | ✅ |
| Copy Code Block | Tap-to-copy on code blocks | ✅ |
| Long-press Context Menu | Copy, Share options on messages | ✅ |
| Share Sheet Integration | iOS share sheet for sending to other apps | ✅ |

### Implementation Notes
- Copy button (📋) added to assistant message headers
- Code blocks have working copy button with "Copied!" feedback
- Context menu on all messages with Copy and Share options
- Share sheet properly handles iPad popover presentation

---

## Milestone 2: Project Management & File Browser ✅

**Goal:** Create/manage projects and browse project files.

| Feature | Description | Status |
|---------|-------------|--------|
| Clone from GitHub URL | Paste URL → clone to workspace → init Claude | ✅ |
| Create New Project | Create folder in workspace, optionally init Claude | ✅ |
| Browse GitHub Repos | OAuth + list user's repos, select to clone | 💡 |
| Delete/Archive Project | Remove projects from list (with confirmation) | ✅ |
| **File Browser** | List/navigate project files via SSH | ✅ |
| **@ File References** | Mobile-friendly file picker to reference files in prompts | ✅ |

### Implementation Notes
- Clone via SSH: `git clone <url>` through SSHManager
- New project: `mkdir` + optional `claude init`
- GitHub OAuth would require significant work - defer to later
- Start with URL clone + new project creation
- ✅ File browser: Uses `ls -laF` via SSH with breadcrumb navigation
- ✅ @ references: Button next to input opens file picker sheet with search

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

### December 26, 2024 - Hardening Complete
- ✅ ChatView.swift refactored (2,345 → 703 lines)
- ✅ Extracted: MarkdownText, CLIInputView, CLIMessageView
- ✅ File-based MessageStore (migrates from UserDefaults)
- ✅ Logger.swift + AppError.swift for error handling
- ✅ WebSocket retry with exponential backoff
- ✅ 28 unit tests for parsers
- ✅ VoiceOver accessibility labels on all interactive elements

### December 26, 2024 - Milestone 1: Copy & Share
- ✅ Copy button on assistant messages (header icon)
- ✅ Long-press context menu on all messages
- ✅ Share sheet integration with iPad support

### December 26, 2024 - File Browser & @ References (M2 partial)
- ✅ FileEntry struct with icon and size formatting
- ✅ SSHManager.listFiles() with directory listing via SSH
- ✅ FilePickerSheet with breadcrumb navigation and search
- ✅ @ button in CLIInputView to reference project files

### December 27, 2024 - Clone from GitHub URL (M2 partial)
- ✅ CloneProjectSheet with URL input and validation
- ✅ SSHManager.executeCommandWithAutoConnect() for remote commands
- ✅ + button in toolbar to open clone sheet
- ✅ Auto-refresh project list after successful clone

### December 27, 2024 - Milestone 2 Complete
- ✅ NewProjectSheet for creating empty projects
- ✅ + button shows action sheet (Clone vs New Project)
- ✅ Delete project with swipe-to-delete and context menu
- ✅ Confirmation dialog before delete (keeps files, removes from list)
- ✅ Proper Claude project registration with cwd in session files
- ✅ /init now passes to Claude (creates CLAUDE.md)
- ✅ /new command for starting fresh sessions

---

## Technical Debt & Maintenance

| Item | Description | Priority | Status |
|------|-------------|----------|--------|
| ChatView.swift size | Split into modules (2,345 → 703 lines) | **High** | ✅ Complete |
| AppSettings injection | Fixed - uses EnvironmentObject + onAppear | **High** | ✅ Complete |
| Theme migration | All views use colorScheme-aware colors | **High** | ✅ Complete |
| MessageStore storage | File-based with auto-migration from UserDefaults | **High** | ✅ Complete |
| Code duplication | ImageUtilities.swift consolidates MIME detection | Medium | ✅ Complete |
| Error handling | AppError.swift + Logger.swift + retry logic | **High** | ✅ Complete |
| Test coverage | 28 unit tests for parsers | Medium | ✅ Complete |
| Accessibility | VoiceOver labels on all interactive elements | **High** | ✅ Complete |

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

1. ~~Copy Message as Markdown~~ ✅ Complete
2. ~~File Browser + @ References~~ ✅ Complete
3. ~~Clone from GitHub URL~~ ✅ Complete
4. ~~Create New Project + Delete~~ ✅ Complete
5. Enhanced Session Picker (M3 - improves navigation)
6. iPad Sidebar + Keyboard Shortcuts (M4)

---

*Last updated: December 27, 2024*
