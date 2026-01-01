# Message Types & UI Flow

Reference for cli-bridge message types and how CodingBridge should render them.

## Source of Truth

- **Claude Agent SDK (Python)**: https://platform.claude.com/docs/en/agent-sdk/python
- This document aligns with the official SDK message types

---

## Message Types

### High-Level Message Union

```
Message = UserMessage | AssistantMessage | SystemMessage | ResultMessage
```

### Content Block Union

```
ContentBlock = TextBlock | ThinkingBlock | ToolUseBlock | ToolResultBlock
```

---

## Content Block Schemas

### TextBlock

```json
{
  "text": "Hello! I'm Claude..."
}
```

### ThinkingBlock

```json
{
  "thinking": "Let me analyze this...",
  "signature": "..."
}
```

### ToolUseBlock

```json
{
  "id": "toolu_019gFKyx8H6EFEiv1GByCLke",
  "name": "Bash",
  "input": {
    "command": "git log -2 --oneline",
    "description": "Show the last 2 commits"
  }
}
```

### ToolResultBlock

```json
{
  "tool_use_id": "toolu_019gFKyx8H6EFEiv1GByCLke",
  "content": "41f4090 fix: inline StreamMessage...",
  "is_error": false
}
```

**Note**: Match `tool_use_id` to `ToolUseBlock.id` to correlate results with their tool calls.

---

## State Messages

State messages drive UI animations. They come as stream messages with type `state`.

### States

| State       | Tool Field | Meaning                |
| ----------- | ---------- | ---------------------- |
| `executing` | (none)     | Preparing to process   |
| `thinking`  | (none)     | Claude is thinking     |
| `executing` | `"Bash"`   | Running a Bash command |
| `executing` | `"Read"`   | Reading a file         |
| `executing` | `"Write"`  | Writing a file         |
| `executing` | `"Grep"`   | Searching code         |
| `executing` | `"Glob"`   | Finding files          |
| `executing` | `"Edit"`   | Editing a file         |
| `executing` | `"Task"`   | Running a subagent     |
| `idle`      | (none)     | Ready for input        |

### State Message Format

```json
{
  "type": "stream",
  "message": {
    "type": "state",
    "state": "executing",
    "tool": "Bash"
  }
}
```

---

## Stream Message Types

### Assistant Message (Streaming)

**Delta (partial) - SKIP THESE:**

```json
{
  "type": "assistant",
  "content": "I'll check",
  "delta": true
}
```

**Complete - RENDER THESE:**

```json
{
  "type": "assistant",
  "content": "I'll check the last 2 commits in your repository.",
  "delta": false
}
```

### System Messages

**Init:**

```json
{
  "type": "system",
  "content": "Session initialized with model claude-sonnet-4-5-20250929",
  "subtype": "init"
}
```

**Result:** Note: this should only be displayed if the assistant message content is different from the last assistant message content.

```json
{
  "type": "system",
  "content": "...(final response)...",
  "subtype": "result"
}
```

### Usage Message

```json
{
  "type": "usage",
  "inputTokens": 14,
  "outputTokens": 571,
  "totalCost": 0.01511175
}
```

---

## Complete Message Flow Example

```
User sends: "What did we do in the last 2 commits?"

1. state: executing              → Show "Preparing..." animation
2. system/init                   → (internal, don't display)
3. state: thinking               → Show "Thinking..." animation
4. assistant (delta=true) x N    → SKIP
5. assistant (delta=false)       → Render text in chat
6. state: executing (tool: Bash) → Show "Running command..." animation
7. tool_use                      → Show tool card (collapsed)
8. tool_result                   → Update tool card with result
9. state: idle                   → Ready for input
```

---

## UI State Mapping

### State Animation (Inline Chat Bubble)

Display as an inline chat bubble at the bottom of messages (like iMessage typing indicator).

| State                     | Icon (SF Symbol)               | Animation                       |
| ------------------------- | ------------------------------ | ------------------------------- |
| `executing` (no tool)     | `hourglass`                    | `.symbolEffect(.variableColor)` |
| `thinking`                | `brain.head.profile`           | `.symbolEffect(.pulse)`         |
| `executing` + `Bash`      | `terminal`                     | `.symbolEffect(.variableColor)` |
| `executing` + `Read`      | `doc.text`                     | `.symbolEffect(.pulse)`         |
| `executing` + `Write`     | `pencil`                       | `.symbolEffect(.bounce)`        |
| `executing` + `Edit`      | `pencil.line`                  | `.symbolEffect(.bounce)`        |
| `executing` + `Grep`      | `magnifyingglass`              | `.symbolEffect(.pulse)`         |
| `executing` + `Glob`      | `folder.badge.magnifyingglass` | `.symbolEffect(.pulse)`         |
| `executing` + `Task`      | `person.2`                     | `.symbolEffect(.variableColor)` |
| `idle`                    | None                           | None                            |

### Status Messages

Status messages rotate during processing to add personality. Implementation in `StatusMessageStore.swift` with:
- Rarity tiers (Common 60%, Uncommon 25%, Rare 12%, Legendary 3%)
- Time-of-day variants (morning/afternoon/evening/night/weekend)
- Seasonal variants (halloween/christmas/newYear/valentine)
- 550+ messages across all categories

---

## Tool Display Specifications

### Bash

- **Command**: Always visible
- **Result**: Collapsed by default, tap to expand
- **Progress**: Show elapsed time for long operations

### Edit

- **Diff view**: Red/green diff with line numbers
- **Summary**: Show +/- line counts

### Write

- **Header**: "Wrote X lines to **path**"
- **Preview**: First 8 lines with fade
- **Expand**: "+N lines (tap to expand)"

### Read / Grep / Glob

- **Files**: List coalesced file names
- **Content**: Hidden - do not show file contents

### Task (Subagent)

- **Mini chat window**: Show last 3 tool calls
- **Stats footer**: Total tools used + elapsed time

### WebFetch

- **URL**: Clickable link (opens in browser)
- **Status**: Show size and HTTP status

### WebSearch

- **Query**: Always visible
- **Results**: Collapsed by default, expandable list

### MCP Tools

- **Format**: `servername - toolname (MCP)`
- **Input**: Show key parameters inline
- **Result**: Collapsed by default

---

## Rendering Rules

### 1. Skip Delta Messages

- Ignore all `assistant` messages where `delta: true`
- Only render `assistant` messages where `delta: false`

### 2. State Drives Animation

- Animation starts on `state: executing` or `state: thinking`
- Animation changes when `state` includes `tool` field
- Animation stops on `state: idle`

### 3. Tool Cards

- Show `tool_use` as a collapsible card
- Update with `tool_result` content when received
- Match by ID: `tool_result.tool_use_id` === `tool_use.id`

### 4. Verify Final Result

- Compare `system/result` content with last `assistant (delta=false)` message
- Only show `system/result` if it differs (should be rare)

### 5. Handle Duplicates

- `state: idle` may be sent twice - ignore duplicates
- `system/result` duplicates `assistant` message - skip if identical

---

## CLI-Bridge Enhancements

cli-bridge transforms SDK messages for easier mobile consumption.

### Tool Result Field Mapping

| SDK           | cli-bridge | Notes                                |
| ------------- | ---------- | ------------------------------------ |
| `tool_use_id` | `id`       | Shortened                            |
| `content`     | `output`   | Renamed                              |
| `is_error`    | `isError`  | camelCase                            |
| (none)        | `tool`     | **Added** - correlated from tool_use |

### Progress Messages

For long-running tools, cli-bridge emits progress updates:

```json
{ "type": "progress", "id": "toolu_123", "tool": "Bash", "elapsed": 5 }
```

### Server-Side Filtering

cli-bridge filters messages to reduce client complexity:
- Only sends `delta: false` messages
- Dedupes `state: idle`
- Skips `system/result` if identical to last assistant message

---

## Key Implementation Files

| Component              | File                       | Purpose                          |
| ---------------------- | -------------------------- | -------------------------------- |
| Status animation       | `StatusBubbleView.swift`   | Inline chat bubble with shimmer  |
| Status messages        | `StatusMessageStore.swift` | Message pools and selection      |
| Tool grouping          | `CompactToolView.swift`    | Groups consecutive tool messages |
| File exploration       | `ExploredFilesView.swift`  | Groups Read/Glob/Grep            |
| Terminal commands      | `TerminalCommandView.swift`| Bash with collapsed result       |
| Diff display           | `DiffView.swift`           | Edit tool diff                   |
| Todo checklist         | `TodoListView.swift`       | TodoWrite rendering              |
| Tool parsing           | `ToolParser.swift`         | Extract params, format content   |
