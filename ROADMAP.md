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

## Milestone 3: Auto-Sync from GitHub 📋

**Goal:** Keep projects up-to-date automatically when loading, with smart handling of local changes.

| Feature | Description | Effort |
|---------|-------------|--------|
| Background Git Status | Check repo status while browsing project list | Medium |
| Git Status Indicator | Show sync status icon on each project (✓ clean, ⚠ changes, ↓ behind) | Low |
| Auto-Pull on Clean | When project has no local changes, auto-pull latest on load | Medium |
| Local Changes Detection | Detect uncommitted changes AND unpushed commits | Medium |
| Unclean Warning Banner | Show warning when local changes exist | Low |
| Auto-Suggest Cleanup | Auto-send message to Claude to review/handle local changes | Medium |

### User Flow

**Clean Project (no local changes):**
```
1. User taps project
2. Background check shows project is clean
3. Auto-pull latest from origin (non-blocking)
4. User enters chat with fresh codebase
```

**Unclean Project (local changes detected):**
```
1. User taps project
2. Background check detects local changes
3. Show banner: "⚠ Local changes detected"
4. Auto-send to Claude: "There are uncommitted changes in this project.
   Please review and help me decide how to handle them before I start working."
5. Claude analyzes git status/diff and suggests: stash, commit, discard, etc.
```

### Implementation Notes
- Use `git status --porcelain` for uncommitted changes
- Use `git rev-list HEAD...@{upstream}` for unpushed commits
- Cache git status per project to avoid repeated SSH calls
- Status check runs in background via SSHManager
- Show spinner/indicator while checking
- Pull uses `git pull --ff-only` to avoid merge conflicts

### Status Indicators
| Icon | Meaning |
|------|---------|
| ✓ | Clean, up to date |
| ↓ | Behind remote (will auto-pull) |
| ⚠ | Local uncommitted changes |
| ↑ | Unpushed commits |
| ⚠↑ | Both uncommitted + unpushed |
| — | Not a git repo |

---

## Milestone 4: Session Management ✅

**Goal:** Better organization and navigation of chat sessions.

| Feature | Description | Status |
|---------|-------------|--------|
| Enhanced Session Picker | Full-screen list with summaries, timestamps | ✅ |
| Session Preview | Show last message or AI-generated summary | ✅ |
| Rename Session | Custom names instead of UUIDs | ✅ |
| Delete Session | Swipe or long-press to delete | ✅ |
| Export Session | Save as .md file to Files app | ✅ |

### Implementation Notes
- SessionNamesStore class for custom session name persistence (UserDefaults)
- Swipe-to-delete with confirmation dialog
- Swipe-to-export and context menu export option
- Rename via context menu with alert dialog
- Markdown export with share sheet integration
- Session rows show custom name, message count, last activity, preview

---

## Milestone 5: iPad Optimization 📋

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

## Milestone 6: Enhanced Tool Visualization 💡

**Goal:** Richer display of tool calls and results.

| Feature | Description | Effort |
|---------|-------------|--------|
| **Truncate Long Output** | Show first N lines with fade + "Show X more lines" | Medium |
| **Enhanced Diff View** | Line-by-line unified diff with line numbers | High |
| Richer Tool Headers | Show key params: `Grep "pattern" → 12 files` | Medium |
| Result Count Badge | Show match count when collapsed | Low |
| Tool Type Colors | Different accent per tool type | Low |
| Syntax Highlighting | Language-aware code coloring | High |
| Quick Actions | Copy path, copy command, expand all | Medium |

### Truncate Long Output - Details

**Goal:** Prevent long tool outputs from dominating the chat while keeping full content accessible.

**Content-Aware Limits:**
| Content Type | Default Lines | Detection |
|--------------|---------------|-----------|
| Bash output | 5 lines | Default for shell results |
| Stack traces | 15 lines | Detect "Error", "Exception", "at line" |
| Grep results | 10 matches | Count file matches |
| Read file | 20 lines | File content preview |
| JSON/logs | 8 lines | Detect structured data |

**UI Design:**
```
┌─────────────────────────────────────┐
│ $ ls -la                            │
├─────────────────────────────────────┤
│ total 128                           │
│ drwxr-xr-x  12 user  staff   384    │
│ -rw-r--r--   1 user  staff  1420    │
│ -rw-r--r--   1 user  staff   892    │
│ -rw-r--r--   1 user  staff  2341    │
│ ┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈ │  ← Fade gradient
│      ▼ Show 47 more lines           │  ← Tap to expand
└─────────────────────────────────────┘
```

**Behavior:**
- Fade gradient at bottom of truncated content
- "Show X more lines" with chevron, tappable
- Smooth spring animation on expand/collapse
- Copy button always copies FULL output (not just visible)
- Collapsed by default, remembers expand state per message

**Implementation Notes:**
- Detect content type from tool name + output patterns
- Use `withAnimation(.spring())` for expand
- Gradient overlay with `LinearGradient` + mask
- Store expand state in view, not persisted
- Line count calculated on render, cached

### Enhanced Diff View - Details

**Goal:** Replace the basic "Removed/Added" blocks with a professional unified diff display like GitHub/VS Code.

**Current State:** Basic view showing "- Removed:" and "+ Added:" text blocks with colored backgrounds.

**Target State:**
```
┌─ Edit: src/Components/SessionRow.swift ─────┐
│     │     │                                  │
│ 347 │     │ -    if let summary = session... │  ← Red bg
│ 348 │     │ -        Text(summary)           │
│ 349 │     │ -            .font(.subheadline) │
│     │ 362 │ +    // Show last user message   │  ← Green bg
│     │ 363 │ +    if let lastMsg = session... │
│ 364 │ 364 │      Text(lastMsg)               │  ← Context (gray)
│ 365 │ 365 │          .font(.subheadline)     │
│     │     │                                  │
│     │     │  ┈┈┈ 12 unchanged lines ┈┈┈     │  ← Collapsed
│     │     │                                  │
│ 370 │     │ -    HStack {                    │
│     │ 378 │ +    VStack {                    │
└─────────────────────────────────────────────┘
```

**Features:**
| Feature | Description |
|---------|-------------|
| Dual line numbers | Old line # (left), New line # (right) |
| Unified diff format | +/- prefixes with colored backgrounds |
| Collapsible context | "12 unchanged lines" collapses to single row |
| Proper diff algorithm | Compute LCS (Longest Common Subsequence) diff |
| Word-level highlights | Optional: highlight changed words within lines |
| File path header | Show which file is being edited |
| Monospace font | Proper code alignment |

**Color Scheme:**
| Element | Light Mode | Dark Mode |
|---------|------------|-----------|
| Removed line bg | `#FFEEF0` | `#3D1E20` |
| Removed line text | `#B31D28` | `#F97583` |
| Added line bg | `#E6FFEC` | `#1E3D23` |
| Added line text | `#22863A` | `#85E89D` |
| Context line | Default | Default |
| Line numbers | Gray | Gray |

**Implementation Notes:**
- Use Myers diff algorithm (or simple LCS for MVP)
- Swift package option: `swift-diff` or implement basic LCS
- Parse `old_string` and `new_string` from Edit tool content
- Split into lines, compute diff, render unified view
- Context lines: show 3 before/after changes by default
- Collapse runs of >5 unchanged lines
- Tap collapsed section to expand

**Accessibility:**
- VoiceOver: "Line 347 removed: if let summary equals..."
- VoiceOver: "Line 362 added: Show last user message comment"

---

## Milestone 7: Search & Bookmarks 💡

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

### December 27, 2024 - Milestone 4: Session Management
- ✅ SessionNamesStore for custom session name persistence
- ✅ Enhanced SessionPickerSheet with full-screen list
- ✅ Session preview (last message, message count, relative time)
- ✅ Rename session via context menu and alert dialog
- ✅ Delete session with swipe and confirmation
- ✅ Export session as markdown with share sheet
- ✅ SessionRow shows custom names with monospace fallback

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
5. ~~Session Management (M4)~~ ✅ Complete
6. **Auto-Sync from GitHub (M3)** - Background git status + auto-pull
7. iPad Sidebar + Keyboard Shortcuts (M5)

---

*Last updated: December 27, 2024*
