# ClaudeCodeApp Roadmap

Feature roadmap and improvements based on comparison with claudecodeui web frontend.

---

## Bugs to Fix

### B1. Settings Propagation Bug ✅ FIXED
- **Location**: `ChatView.swift` lines 20-21
- **Problem**: Creates new `AppSettings()` instead of using injected `@EnvironmentObject`
- **Impact**: Settings changes won't propagate to WebSocket
- **Fix**: Added `updateSettings()` method to WebSocketManager, called in ChatView's onAppear

### B2. Parse Error Handling ✅ FIXED
- **Location**: `WebSocketManager.swift` line 249
- **Problem**: On parse error, continues listening but doesn't notify UI
- **Fix**: Set `lastError` on parse failures so user knows something went wrong

### B3. Fake Token Count Display ✅ FIXED
- **Location**: `ChatView.swift` lines 487-495
- **Problem**: Falls back to fake token count if `tokenUsage` is nil
- **Fix**: Removed unused `tokenCount` fallback - only show token info if actually received from server

---

## High Priority

### H1. Message History Persistence ✅ FIXED
- **Status**: Implemented
- **Implementation**:
  - Added `MessageStore` class using UserDefaults with JSON encoding
  - Stores last 50 messages per project (keyed by project path)
  - Loads on view appear, saves on each message change
  - "New Chat" button clears persisted history
- **Location**: `Models.swift` (MessageStore), `ChatView.swift`

### H2. Draft Message Saving ✅ FIXED
- **Status**: Implemented
- **Implementation**:
  - Auto-saves draft via `onChange(of: inputText)`
  - Uses UserDefaults with project path key
  - Loads on view appear, clears on send (via empty string save)
- **Location**: `Models.swift` (MessageStore), `ChatView.swift`

### H3. Exponential Backoff Reconnection ✅ FIXED
- **Status**: Implemented
- **Implementation**:
  - Backoff: 1s -> 2s -> 4s -> 8s (max) with random jitter (0-500ms)
  - `isReconnecting` flag prevents duplicate reconnection attempts
  - Clears `currentText` on disconnect to prevent stale data
  - Auto-reconnects on receive errors and send failures
- **Location**: `WebSocketManager.swift`

### H4. Voice Input / Voice-to-Text ✅ FIXED
- **Status**: Implemented
- **Implementation**:
  - Added `SpeechManager` using iOS Speech framework (SFSpeechRecognizer)
  - Microphone button in input bar with recording indicator
  - Real-time transcription with partial results
  - Appends transcribed text to input on stop
- **Location**: `SpeechManager.swift`, `ChatView.swift` (CLIInputView), `Info.plist`

### H5. Image/File Upload & Display ✅ FIXED
- **Status**: Implemented (UI complete, backend integration may need work)
- **Implementation**:
  - Added PhotosPicker in input bar
  - Image preview before sending with remove button
  - Images stored in ChatMessage.imageData
  - Images displayed inline in user messages
- **Location**: `ChatView.swift` (CLIInputView, CLIMessageView), `Models.swift`, `Info.plist`
- **Note**: Backend integration for sending images TBD

### H6. Copy-to-Clipboard for Code Blocks ✅ FIXED
- **Status**: Implemented
- **Implementation**:
  - Added `CodeBlockView` component with copy button
  - Uses `UIPasteboard.general.string`
  - Shows "Copied!" feedback for 1.5 seconds with checkmark icon
- **Location**: `ChatView.swift` (CodeBlockView)

### H7. Collapsible Tool Results ✅ FIXED
- **Status**: Implemented
- **Implementation**:
  - Grep/Glob tool uses start collapsed by default
  - Tool header shows just tool name (e.g., "Grep" not full invocation)
  - `[+]/[-]` toggle with animation
  - Expanded view shows full tool invocation details
- **Location**: `ChatView.swift` (CLIMessageView)

---

## Medium Priority

### M1. Extended Status Messages
- **Status**: Basic "Thinking..." only
- **Web App**: Shows animated action words (Thinking, Processing, Analyzing, etc.)
- **Implementation**:
  - Cycle through action words based on elapsed time
  - Show token count and elapsed time
- **Effort**: 2 hours

### M2. Usage Limit Time Formatting
- **Status**: Not implemented
- **Web App**: Parses usage limit messages and shows local timezone
- **Implementation**:
  - Parse "Claude AI usage limit reached|<epoch>" format
  - Format with user's local timezone
- **Effort**: 2 hours

### M3. HTML Entity Decoding
- **Status**: Not implemented
- **Web App**: Decodes `&lt;`, `&gt;`, etc.
- **Implementation**:
  - Add `decodeHtmlEntities` in message processing
- **Location**: `WebSocketManager.swift` - `parseMessage()`
- **Effort**: 1 hour

### M4. Token Truncation with Expandable View
- **Status**: Truncates at 500 chars
- **Web App**: Smart truncation with expand option
- **Implementation**:
  - Keep truncation at 500 for display
  - Store full result internally
  - Add "Show more" button for truncated results
- **Effort**: 3 hours

### M5. Thinking/Reasoning Blocks ✅ FIXED
- **Status**: Implemented
- **Implementation**:
  - Added `.thinking` role to ChatMessage
  - WebSocketManager parses `thinking` content type
  - Collapsible display with 💭 icon and purple styling
  - Starts collapsed by default
- **Location**: `Models.swift`, `WebSocketManager.swift`, `ChatView.swift`

### M6. Diff Viewer for Edit Tool ✅ FIXED
- **Status**: Implemented
- **Implementation**:
  - Added `DiffView` component with red/green highlighting
  - Parses old_string/new_string from Edit tool content
  - Uses CLITheme.diffAdded/diffRemoved colors
  - Shows "- Removed:" and "+ Added:" sections
- **Location**: `ChatView.swift` (DiffView)

### M7. Inline Code Fence Normalization
- **Status**: Not implemented
- **Web App**: Fixes triple backticks around inline code
- **Implementation**:
  - Add regex replacement in markdown parser
  - Convert ```code``` to `code` for inline
- **Effort**: 1 hour

### M8. Multi-Provider Support
- **Status**: Claude-only
- **Web App**: Toggles between Claude/Cursor provider
- **Implementation**:
  - Add `@AppStorage("selected-provider")` to AppSettings
  - Pass provider in message send
  - Show provider icon in chat
- **Effort**: 4 hours

---

## Low Priority (Polish)

### L1. Token Usage Pie/Progress Chart
- **Status**: Text-only display
- **Web App**: Visual `TokenUsagePie` component
- **Implementation**:
  - Add circular progress or bar indicator
- **Effort**: 2 hours

### L2. LaTeX Math Rendering
- **Status**: Not implemented
- **Web App**: Uses remark-math + rehype-katex
- **Implementation**:
  - Render math blocks (may need server-side PNG)
- **Effort**: 1 day

### L3. Keyboard Shortcuts (iPad)
- **Status**: Not implemented
- **Implementation**:
  - Cmd+Return to send
  - Escape to abort
- **Effort**: 2 hours

### L4. Escape Sequence Protection
- **Status**: Not implemented
- **Web App**: `unescapeWithMathProtection()` for safe processing
- **Implementation**:
  - Apply similar logic when parsing message content
- **Effort**: 2 hours

---

## Quick Wins (< 4 hours each)

1. ~~[B1] Fix Settings propagation bug - 1 hour~~ ✅
2. ~~[B2] Fix parse error handling - 30 min~~ ✅
3. ~~[B3] Fix fake token count - 30 min~~ ✅
4. ~~[H2] Draft message saving - 2 hours~~ ✅
5. ~~[H6] Copy button for code - 3 hours~~ ✅
6. [M1] Extended status messages - 2 hours
7. [M3] HTML entity decoding - 1 hour
8. [L3] Keyboard shortcuts - 2 hours

---

## Suggested Implementation Order

### Phase 1: Bug Fixes & Stability
- [x] B1. Settings propagation bug
- [x] B2. Parse error handling
- [x] B3. Fake token count
- [x] H3. Exponential backoff reconnection

### Phase 2: Core UX
- [x] H1. Message history persistence
- [x] H2. Draft message saving
- [x] H6. Copy-to-clipboard for code
- [x] H7. Collapsible tool results

### Phase 3: Enhanced Features
- [x] H4. Voice input
- [x] H5. Image upload
- [x] M5. Thinking/reasoning blocks
- [x] M6. Diff viewer

### Phase 4: Polish
- [ ] M1. Extended status messages
- [ ] M2. Usage limit formatting
- [ ] L1. Token usage visualization
- [ ] L3. Keyboard shortcuts

---

## Notes

- Web frontend source: `~/dev/claudecodeui`
- iOS app: `~/dev/ClaudeCodeApp`
- Server API: claudecodeui backend on QNAP container (10.0.3.2:8080)
