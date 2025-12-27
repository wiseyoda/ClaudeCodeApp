# ClaudeCodeApp Roadmap

> Feature roadmap for the iOS Claude Code client. Organized by priority with implementation details.

---

## Status Legend

| Status | Meaning |
|--------|---------|
| Done | Implemented and tested |
| In Progress | Currently being worked on |
| Planned | Approved for implementation |
| Idea | Under consideration |

---

## 1. Enhanced Tool Visualization

**Priority:** High | **Status:** In Progress

Improve how tool calls are displayed in the chat interface.

### Completed

- [x] Diff viewer for Edit tool with red/green highlighting
- [x] Collapsible tool messages (Grep/Glob collapsed by default)
- [x] Tool result truncation with expandable content
- [x] TodoWrite visual checklist rendering
- [x] AskUserQuestion interactive UI

### Planned

- [ ] **Richer Tool Headers**
  - Extract key parameters and show in header
  - Example: `* Grep pattern: "fetchProjects" | 12 files [+]`
  - Show result count when collapsed
  - Add file/folder icons using SF Symbols

- [ ] **Better Collapsed Previews**
  - Show first meaningful line of result
  - For file operations: show filename and line number
  - For Bash commands: show exit code and first output line

- [ ] **Syntax Highlighting**
  - Language-aware coloring in code blocks
  - Distinguish between file types in tool results

- [ ] **Quick Actions**
  - Copy button for paths, commands, code snippets
  - "Jump to file" for Edit/Read tools
  - Expand/collapse all tools button

- [ ] **Color-Coded Tool Types**
  - Different accent colors per tool (Read/Write/Edit/Bash/Grep)

---

## 2. Message Actions

**Priority:** High | **Status:** Planned

Add context menus and gestures for message interaction.

### Long-Press Context Menu

**User Messages:**
- Edit & Resend
- Copy Text
- Delete Message
- Retry (resend)

**Assistant Messages:**
- Copy Text
- Bookmark/Favorite
- Share (export as text/markdown)

**Tool Messages:**
- Copy Content
- Copy File Path (if applicable)
- Bookmark

### Swipe Actions

- Swipe left: Bookmark
- Swipe right: Delete (with confirmation)

---

## 3. Bookmarks/Favorites System

**Priority:** Medium | **Status:** Planned

Save and organize important messages across sessions.

### Implementation

```swift
// Extend ChatMessage model
var isBookmarked: Bool = false

// New storage class
class BookmarkStore {
    static func toggleBookmark(messageId: UUID, projectPath: String)
    static func getBookmarkedMessages(projectPath: String) -> [ChatMessage]
}
```

### Features

- [ ] Star icon in message header (tap to toggle)
- [ ] Toolbar button to filter bookmarked messages only
- [ ] Visual indicator (gold star) on bookmarked messages
- [ ] Bookmarks persist across sessions
- [ ] Export bookmarked conversations

---

## 4. Search & Filter

**Priority:** Medium | **Status:** Planned

Find messages across conversation history.

### Search Features

- [ ] Pull-down search bar (iOS native style)
- [ ] Full-text search within message content
- [ ] Highlight matching text in results
- [ ] Jump to message in conversation

### Filter Options

- [ ] By message role (user/assistant/tool/error)
- [ ] By tool type (Grep, Bash, Edit, etc.)
- [ ] By date range
- [ ] Bookmarked only

---

## 5. Session Management

**Priority:** Medium | **Status:** Planned

Better organization and navigation of chat sessions.

### Enhanced Session Picker

```
┌─────────────────────────────────────┐
│ [New] Session 1: "Add auth feature" │
│       12 messages • 2m ago          │
├─────────────────────────────────────┤
│ Session 2: "Fix database bug"       │
│       8 messages • 1h ago           │
└─────────────────────────────────────┘
```

### Features

- [ ] Grid or list view (replace horizontal scroll)
- [ ] Message count and last activity time
- [ ] Preview last message or session summary
- [ ] Swipe to delete old sessions
- [ ] Long-press for options (rename, duplicate, export)

---

## 6. Extended Data Model

**Priority:** Low | **Status:** Idea

Support advanced features with richer message metadata.

### Proposed ChatMessage Extensions

```swift
struct ChatMessage {
    // Existing fields...

    // Organization
    var isBookmarked: Bool = false
    var tags: [String] = []
    var parentMessageId: UUID?  // For threading

    // Tool metadata
    var toolMetadata: ToolMetadata?
}

struct ToolMetadata: Codable {
    let toolName: String
    let parameters: [String: String]
    let resultSummary: String?
    let affectedFiles: [String]?
}
```

---

## Recently Completed

### Settings Overhaul
- [x] iOS Form-style settings UI
- [x] Theme selection (System/Dark/Light)
- [x] Font size presets (XS/S/M/L/XL)
- [x] Skip Permissions toggle
- [x] Show Thinking Blocks toggle
- [x] Auto-scroll toggle
- [x] Project sort order (Name/Date)
- [x] API Key field for REST endpoints

### Core Features
- [x] WebSocket real-time chat
- [x] Markdown rendering (headers, code, tables, lists)
- [x] Image attachments via PhotosPicker
- [x] Voice input with Speech framework
- [x] SSH terminal with Citadel
- [x] Message persistence (50 messages per project)
- [x] Draft auto-save
- [x] Local notifications on task completion

---

## Implementation Priority

| Phase | Features | Effort |
|-------|----------|--------|
| 1 | Message Actions (foundation for bookmarks) | Medium |
| 2 | Bookmarks System | Low |
| 3 | Enhanced Tool Visualization | High |
| 4 | Search/Filter | High |
| 5 | Session Management | Medium |

---

*Last updated: December 2024*
