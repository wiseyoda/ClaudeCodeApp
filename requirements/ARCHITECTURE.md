# Architecture Documentation

## System Architecture

```
+------------------------------------------------------------------------------+
|                              iOS Device                                       |
|  +------------------------------------------------------------------------+  |
|  |                         CodingBridge                                    |  |
|  |                                                                         |  |
|  |  +------------------+  +------------------+  +------------------------+ |  |
|  |  |   ContentView    |--|    ChatView      |--|   CLIBridgeAdapter     | |  |
|  |  |   (Projects)     |  |   (Messages)     |  |   (SSE Streaming)      | |  |
|  |  +------------------+  +------------------+  +------------------------+ |  |
|  |         |                     |                      |                  |  |
|  |         |              +------+------+        +------+------+          |  |
|  |         |              |SpeechManager|        |ClaudeHelper |          |  |
|  |         |              |(Voice Input)|        |(AI Suggest) |          |  |
|  |         |              +-------------+        +-------------+          |  |
|  |         |                                                               |  |
|  |  +------+------+  +-------------+  +-------------+  +--------------+   |  |
|  |  |TerminalView |--|  SSHManager |  |MessageStore |  | BookmarkStore|   |  |
|  |  | (SSH Shell) |  |  (Citadel)  |  | (File-based)|  | (Bookmarks)  |   |  |
|  |  +-------------+  +-------------+  +-------------+  +--------------+   |  |
|  |                          |                                              |  |
|  |  +-------------+  +------+------+  +-------------+  +--------------+   |  |
|  |  | AppSettings |  |CommandStore |  |   Logger    |  |SessionNames  |   |  |
|  |  | (Config)    |  | (Prompts)   |  |  (Logging)  |  |Store (Names) |   |  |
|  |  +-------------+  +-------------+  +-------------+  +--------------+   |  |
|  |                          |                                              |  |
|  |                   +------+------+                                       |  |
|  |                   | IdeasStore  |                                       |  |
|  |                   | (Ideas)     |                                       |  |
|  |                   +-------------+                                       |  |
|  +------------------------------------------------------------------------+  |
+------------------------------------------------------------------------------+
                              |
                              | REST API + SSE / SSH
                              | (via Tailscale)
                              v
+------------------------------------------------------------------------------+
|                        Backend Server (NAS/Cloud)                             |
|  +------------------------------------------------------------------------+  |
|  |                          cli-bridge                                     |  |
|  |  +-------------+  +-------------+  +-----------------------------+     |  |
|  |  |  REST API   |--|   Agent     |--|        Claude Code CLI      |     |  |
|  |  |  SSE Stream |  |   Manager   |  |        (Subprocess)         |     |  |
|  |  +-------------+  +-------------+  +-----------------------------+     |  |
|  +------------------------------------------------------------------------+  |
|                              |                                                |
|                              v                                                |
|  +------------------------------------------------------------------------+  |
|  |                          Claude CLI                                     |  |
|  |  - Authenticated with Anthropic                                         |  |
|  |  - Access to workspace files                                            |  |
|  |  - Tool execution capabilities                                          |  |
|  +------------------------------------------------------------------------+  |
|                                                                               |
|  +------------------------------------------------------------------------+  |
|  |                            sshd                                         |  |
|  |  - Standard SSH daemon                                                  |  |
|  |  - Terminal access for TerminalView                                     |  |
|  |  - File listing for FilePickerSheet                                     |  |
|  |  - Git operations for CloneProjectSheet                                 |  |
|  |  - Session history for GlobalSearchView                                 |  |
|  +------------------------------------------------------------------------+  |
+------------------------------------------------------------------------------+
```

## Clean Architecture: Session Management

The session management system uses a Clean Architecture pattern separating concerns into distinct layers:

```
+------------------+     +-------------------+     +--------------------+
|     Views        |---->|   SessionStore    |<--->| SessionRepository  |
|                  |     |  (State Mgmt)     |     |   (Data Layer)     |
+------------------+     +-------------------+     +--------------------+
                               ^                          |
                               |                          v
                       +-------+--------+        +-------------------+
                       | CLIBridgeAdapter|        |  CLIBridgeAPI     |
                       | (SSE Events)   |        |   Client (HTTP)   |
                       +----------------+        +-------------------+
                               ^                          |
                               |                          v
                       +-------+--------------------------+-------+
                       |          cli-bridge Backend              |
                       +------------------------------------------+
```

### Layers

| Layer | File | Responsibility |
|-------|------|----------------|
| **State** | `SessionStore.swift` | Single source of truth for session state. Published properties for reactive UI. Pagination, active session tracking, bulk operations. |
| **Repository** | `SessionRepository.swift` | Protocol abstraction + API implementation. Handles HTTP requests and response decoding. MockSessionRepository for testing. |
| **Views** | `SessionPickerViews.swift`, `ChatView.swift`, `ContentView.swift` | Observe SessionStore.shared for reactive updates. Trigger loads and deletions via store methods. |

### SessionStore (State Layer)

Singleton source of truth accessed via `SessionStore.shared`.

**Published State:**
| Property | Type | Purpose |
|----------|------|---------|
| `sessionsByProject` | `[String: [ProjectSession]]` | Raw sessions per project path |
| `metaByProject` | `[String: ProjectSessionMeta]` | Pagination metadata (hasMore, total) |
| `countsByProject` | `[String: CLISessionCountResponse]` | Session counts by source |
| `searchResults` | `[String: CLISessionSearchResponse]` | Search results by project |
| `isLoading` | `[String: Bool]` | Loading state per project |
| `activeSessionIds` | `[String: String]` | Active session per project |
| `showArchivedSessions` | `Bool` | Toggle archived visibility |

**Core Methods:**
| Method | Purpose |
|--------|---------|
| `loadSessions(for:)` | Fetch sessions from API |
| `loadMore(for:)` | Pagination - fetch next page |
| `deleteSession(_:for:)` | Optimistic delete with rollback |
| `displaySessions(for:)` | Filtered/sorted sessions for UI |

**Search & Archive Methods:**
| Method | Purpose |
|--------|---------|
| `searchSessions(for:query:)` | Full-text search |
| `archiveSession(_:for:)` | Soft delete with optimistic update |
| `unarchiveSession(_:for:)` | Restore archived session |
| `loadSessionCounts(for:)` | Get count breakdown by source |

### SessionRepository (Data Layer)

Protocol-based abstraction for testability:

```swift
protocol SessionRepository {
    func fetchSessions(projectName: String, limit: Int, offset: Int) async throws -> SessionsResponse
    func deleteSession(projectName: String, sessionId: String) async throws
    func getSessionCount(projectName: String, source: SessionSource?) async throws -> CLISessionCountResponse
    func searchSessions(projectName: String, query: String, limit: Int, offset: Int) async throws -> CLISessionSearchResponse
    func archiveSession(projectName: String, sessionId: String) async throws -> CLISessionMetadata
    func unarchiveSession(projectName: String, sessionId: String) async throws -> CLISessionMetadata
    func bulkOperation(projectName: String, sessionIds: [String], action: String, customTitle: String?) async throws -> CLIBulkOperationResponse
}
```

**Implementations:**
- `CLIBridgeSessionRepository` - Production HTTP client
- `MockSessionRepository` - Unit testing (DEBUG only)

### Data Flow

1. **Initial Load**: View -> `SessionStore.loadSessions()` -> Repository -> CLIBridgeAPIClient -> Backend
2. **Pagination**: View (Load More) -> `SessionStore.loadMore()` -> Repository -> CLIBridgeAPIClient
3. **SSE Update**: Backend -> SSE Stream -> `CLIBridgeAdapter` -> `SessionStore` -> Views
4. **Delete**: View -> `SessionStore.deleteSession()` -> (optimistic update) -> Repository -> Backend

---

## CLI Bridge Architecture

The app connects to [cli-bridge](https://github.com/anthropics/claude-code/tree/main/packages/cli-bridge) backend via REST API with Server-Sent Events (SSE) for streaming.

### Core Components

| Component | File | Purpose |
|-----------|------|---------|
| `CLIBridgeManager` | `CLIBridgeManager.swift` | Core REST API client, SSE stream handling |
| `CLIBridgeAdapter` | `CLIBridgeAdapter.swift` | Adapts CLIBridgeManager to callback-style interface |
| `CLIBridgeAPIClient` | `CLIBridgeAPIClient.swift` | HTTP client for health checks, project/session listing |
| `CLIBridgeTypes` | `CLIBridgeTypes.swift` | All message types and protocol models |

### Message Flow

```
Send:    ChatView -> CLIBridgeAdapter.sendMessage() -> POST /agents/:id/message
Receive: SSE Stream -> CLIBridgeManager.handleSSEEvent() -> Callbacks -> ChatView
```

### SSE Event Types

| Event | Purpose |
|-------|---------|
| `assistant` | Streaming text content |
| `tool_use` | Tool invocation (name, input) |
| `tool_result` | Tool output |
| `thinking` | Reasoning blocks |
| `result` | Task complete (includes session info) |
| `error` | Error message |

### CLIBridgeAdapter Callbacks

| Callback | Purpose |
|----------|---------|
| `onText()` | Streaming assistant text |
| `onTextCommit()` | Text segment complete |
| `onToolUse(name, input)` | Tool invocation |
| `onToolResult()` | Tool output |
| `onThinking()` | Reasoning blocks |
| `onComplete(sessionId)` | Task finished |
| `onAskUserQuestion()` | Interactive questions |
| `onError()` | Error handling |
| `onModelChanged()` | Model switch |
| `onPermissionRequest()` | Tool approval request |

---

## Permission Approval System

When bypass permissions is OFF, tool executions require user approval:

```
+------------------+     +-------------------+     +--------------------+
|  Claude CLI      |---->|  cli-bridge       |---->|   iOS App          |
|  (canUseTool)    |     |  (SSE Stream)     |     |  (Approval UI)     |
+------------------+     +-------------------+     +--------------------+
                               |                         |
                               <-------------------------+
                            permission-response (POST)
```

### Components

| Component | File | Purpose |
|-----------|------|---------|
| `ApprovalBannerView` | `Views/ApprovalBannerView.swift` | Compact banner with Approve/Always Allow/Deny |
| `ApprovalRequest` | `CLIBridgeTypes.swift` | Request model (tool, requestId, input) |
| `ApprovalResponse` | `CLIBridgeTypes.swift` | Response model (approved, alwaysAllow) |
| `ProjectSettingsStore` | `ProjectSettingsStore.swift` | Per-project permission overrides |
| `PermissionManager` | `PermissionManager.swift` | Permission state and history tracking |

### Flow

1. Backend receives tool call from Claude CLI
2. `canUseTool` callback triggers SSE permission request event
3. iOS shows `ApprovalBannerView` with tool details
4. User taps Approve/Always Allow/Deny
5. iOS sends POST to backend with approval response
6. Backend allows/denies tool execution

---

## iOS App Components

### Core Files

#### CodingBridgeApp.swift
- App entry point
- Creates shared AppSettings instance
- Injects settings into environment
- Requests notification permissions
- Registers background tasks

#### AppSettings.swift
Stores all user configuration using @AppStorage:

| Category | Settings |
|----------|----------|
| Server | URL (defaults to localhost:3100) |
| Claude | Mode (normal/plan), thinking mode (5 levels), skipPermissions |
| Model | defaultModel, customModelId |
| Display | fontSize, appTheme, showThinkingBlocks, autoScrollEnabled |
| Project | projectSortOrder (name/date) |
| SSH | host, port, username, authMethod, password |

Key computed properties:
- `effectivePermissionMode` - Resolves bypass vs mode setting
- `effectiveSSHHost` - Falls back to server URL host
- `scaledFont()` - Font scaling for accessibility

#### Models.swift

**Enums:**
| Enum | Values |
|------|--------|
| `ClaudeModel` | opus, sonnet, haiku, custom |
| `ThinkingMode` | normal, think, thinkHard, thinkHarder, ultrathink |
| `ClaudeMode` | normal, plan |
| `AppTheme` | system, dark, light |
| `ProjectSortOrder` | name, date |
| `FontSizePreset` | XS, S, M, L, XL (10-18pt) |
| `GitStatus` | 10 states with icons and colors |

**Data Models:**
| Model | Purpose |
|-------|---------|
| `Project` | name, path, sessions, displayName |
| `ProjectSession` | id, summary, messageCount, lastActivity |
| `ChatMessage` | role, content, timestamp, imageData, isStreaming |
| `BookmarkedMessage` | messageId, role, content, project context |
| `SavedCommand` | name, content, category, timestamps |

**Storage Classes:**
| Class | Storage | Purpose |
|-------|---------|---------|
| `MessageStore` | Documents/{path}.json | Message persistence |
| `BookmarkStore` | Documents/bookmarks.json | Cross-session bookmarks |
| `SessionNamesStore` | UserDefaults | Custom session names |
| `SessionHistoryLoader` | SSH/JSONL | Load session from server |
| `IdeasStore` | Documents/ideas-{path}.json | Per-project idea persistence |

#### CLIBridgeManager.swift

**Connection Management:**
- `ConnectionState` enum (disconnected/connecting/connected/error)
- REST API with SSE streaming for responses
- Agent lifecycle management (create, message, abort)
- Health check endpoint monitoring

**Published State:**
| Property | Type | Purpose |
|----------|------|---------|
| `connectionState` | ConnectionState | Current connection status |
| `isProcessing` | Bool | Request in flight |
| `currentText` | String | Streaming response text |
| `lastError` | String? | Most recent error |
| `sessionId` | String? | Active session |
| `tokenUsage` | (current, max) | Token budget |
| `currentModel` | ClaudeModel | Active model |

#### SpeechManager.swift
- iOS Speech framework integration (SFSpeechRecognizer)
- AVAudioEngine for recording
- Real-time partial results
- Authorization status tracking

#### SSHManager.swift

**Capabilities:**
| Feature | Implementation |
|---------|---------------|
| SSH Client | Citadel (pure Swift) |
| Auth | Password, SSH keys (Ed25519, RSA, ECDSA) |
| Key Storage | iOS Keychain |
| Operations | Terminal I/O, file listing, command execution |
| Auto-connect | Saved credentials priority |

#### CommandStore.swift
- Singleton with JSON persistence (Documents/commands.json)
- CRUD operations for SavedCommand
- Category management
- Last-used tracking and sorting
- Default commands for Git, Code Review, Testing, Docs

#### IdeasStore.swift
- Per-project persistence (Documents/ideas-{encoded-path}.json)
- `Idea` struct with text, title, tags, timestamps
- AI enhancement fields (expandedPrompt, suggestedFollowups)
- Archive/restore functionality
- Search and filter by tag

#### ClaudeHelper.swift
- Haiku-powered meta-AI service
- `SuggestedAction` model (label, prompt, icon)
- Generate 3 suggestions based on conversation
- Suggested files in file picker
- Separate API call with 15-second timeout

#### Theme.swift
- `CLITheme` with colorScheme-aware colors
- Light and dark mode variants
- Tool-specific colors
- Diff colors (added/removed)
- iOS 26 Liquid Glass support

#### Utilities
| File | Purpose |
|------|---------|
| `Logger.swift` | Structured logging (debug/info/warning/error) |
| `AppError.swift` | Unified error handling |
| `ImageUtilities.swift` | MIME type detection (PNG, JPEG, GIF, WebP) |
| `KeychainHelper.swift` | Secure credential storage |
| `HealthMonitorService.swift` | Backend connectivity monitoring |
| `SearchHistoryStore.swift` | Search query persistence |
| `SSHKeyDetection.swift` | SSH key type detection and validation |

### Managers
| File | Purpose |
|------|---------|
| `BackgroundManager.swift` | Background task scheduling |
| `LiveActivityManager.swift` | Live Activity updates |
| `NotificationManager.swift` | Local notifications |
| `PushNotificationManager.swift` | Push notification handling |
| `OfflineActionQueue.swift` | Queued actions for offline |

### Main Views

#### ContentView.swift
- Main navigation container (NavigationSplitView for iPad)
- Project list with session counts
- Settings sheet
- New project action sheet (Clone vs Create)
- Project deletion with swipe and context menu
- Global search access
- Terminal access

#### ChatView.swift
Core chat UI with responsibilities:
- Message list with auto-scroll
- SSE streaming integration via CLIBridgeAdapter
- Slash command handling
- Tool use/result collapsible sections
- Thinking block display
- Session picker sheet
- Help sheet
- Unified status bar
- Quick settings sheet
- Search and filtering
- Bookmark context menu

#### TerminalView.swift
- Interactive SSH shell display
- Special keys bar (Ctrl+C, Tab, Esc, arrows)
- Auto-scroll to bottom
- CLI theme styling

### Views/ Folder (48 files)

| File | Lines | Purpose |
|------|-------|---------|
| `CLIMessageView.swift` | 977 | Message bubble with role styling, context menu |
| `SessionPickerViews.swift` | 758 | Session picker, rename, export |
| `GlobalSearchView.swift` | 687 | Cross-session search |
| `MarkdownText.swift` | 508 | Full markdown rendering with math, tables, code |
| `CommandsView.swift` | 447 | Command library CRUD |
| `QuickSettingsSheet.swift` | 433 | Fast settings access |
| `DiagnosticsView.swift` | 411 | Debug diagnostics |
| `DiffView.swift` | 408 | Edit tool diff with line numbers, context collapse |
| `ProjectDetailView.swift` | 406 | Project details view |
| `CLIInputView.swift` | 404 | Multi-line input, attachments, voice, [+] menu |
| `IdeasDrawerSheet.swift` | 401 | Ideas drawer management |
| `FileBrowserView.swift` | 396 | File system navigation |
| `DebugLogView.swift` | 396 | Debug log viewer |
| `MetricsDashboardView.swift` | 387 | Metrics display |
| `CLIStatusBarViews.swift` | 367 | Unified status bar components |
| `ServerHealthView.swift` | 345 | Backend health display |
| `ErrorInsightsView.swift` | 326 | Error analytics |
| `FileContentViewer.swift` | 325 | File content display |
| `FilePickerSheet.swift` | 324 | File browser with AI suggestions |
| `PermissionSettingsView.swift` | 323 | Permission configuration |
| `ApprovalBannerView.swift` | 297 | Permission approval UI |
| `IdeaRowView.swift` | 285 | Idea list item display |
| `TruncatableText.swift` | 275 | Truncated text with expand button |
| `IdeaEditorSheet.swift` | 233 | Individual idea editing |
| `CloneProjectSheet.swift` | 274 | Git clone with progress |
| `NewProjectSheet.swift` | 246 | Create empty project |
| `CodeBlockView.swift` | 213 | Code display with copy button |
| `ProjectListViews.swift` | 238 | Project list components |
| `SSHKeyImportSheet.swift` | 200 | SSH key import UI |
| `GitSyncBanner.swift` | 188 | Git sync notifications |
| `CLIBridgeBanners.swift` | 212 | Status banners |
| `CommandPickerSheet.swift` | 171 | Quick command selection |
| `SuggestionChipsView.swift` | 202 | AI suggestion chips |
| `TodoListView.swift` | 173 | TodoWrite checklist with status colors |
| `BookmarksView.swift` | 144 | Bookmark list with search |
| `SearchFilterViews.swift` | 145 | Message filters and search bar |
| `QuickCaptureSheet.swift` | 88 | Quick idea capture |
| `TagsFlowView.swift` | 113 | Tag flow layout for ideas |
| `IdeasFAB.swift` | 95 | Floating action button for ideas |
| `ErrorBanner.swift` | 135 | Error display banner |
| `GitStatusIndicator.swift` | 38 | Git status icons |
| `CustomModelPickerSheet.swift` | 52 | Custom model selection |
| `SlashCommandHelpSheet.swift` | 47 | Slash command reference |
| `ChatViewExtensions.swift` | 23 | Chat view extensions |
| `SkeletonView.swift` | 80 | Loading placeholder |
| `MessageActionBar.swift` | 128 | Message action buttons |
| `PermissionApprovalTestHarnessView.swift` | 58 | Test harness for approvals |

## Data Flow

### Loading Projects
```
1. App launches
2. ContentView.task calls CLIBridgeAPIClient.fetchProjects()
3. HTTP GET /projects
4. Response decoded to [Project]
5. Projects sorted by user preference
6. UI updates with project list
```

### Cloning a Project
```
1. User taps + -> Clone from GitHub
2. CloneProjectSheet opens
3. User enters GitHub URL
4. SSHManager.executeCommandWithAutoConnect runs `git clone`
5. Claude project directory created
6. Session file with cwd written
7. Project list refreshed
8. User navigates to new project
```

### Sending a Message
```
1. User types/speaks/attaches and taps send
2. ThinkingMode trigger appended if active
3. ChatView adds user message to list
4. CLIBridgeAdapter.sendMessage() called with:
   - message text
   - project path (cwd)
   - sessionId (optional)
   - permissionMode
   - model options
5. POST /agents/:id/message initiates SSE stream
6. Response streamed via SSE events
7. Callbacks update UI:
   - onText: streaming assistant text
   - onToolUse: tool invocation display
   - onToolResult: tool output display
   - onThinking: reasoning block display
8. result event signals end
9. MessageStore saves history to file
10. AI suggestions generated via ClaudeHelper
11. Local notification sent (if backgrounded)
```

### Session Management
```
1. User taps /resume or session picker
2. SessionPickerSheet shows with sessions
3. User can:
   - Select session -> loads history via API/SSH
   - Rename -> SessionNamesStore saves custom name
   - Delete -> removes session file via API
   - Export -> generates markdown, shows share sheet
4. Selected session's history loaded
5. Conversation continues with session context
```

### Voice Input Flow
```
1. User taps mic button (in [+] menu or when input empty)
2. SpeechManager.startRecording()
3. AVAudioEngine captures audio
4. SFSpeechRecognizer transcribes
5. Partial results update recording indicator
6. User taps Done to stop
7. Final transcription appended to input
```

### File Reference Flow
```
1. User taps @ button (in [+] menu)
2. FilePickerSheet opens
3. ClaudeHelper suggests relevant files (AI-powered)
4. SSHManager.listFiles() fetches directory
5. User navigates/searches files
6. User selects file
7. @path/to/file inserted into input
8. User sends message with reference
```

### Command Library Flow
```
1. User taps [+] -> Saved Commands
2. CommandPickerSheet opens with categories
3. User searches or browses commands
4. User taps command
5. Command content replaces input text
6. CommandStore.markUsed() updates last-used
7. User sends the command
```

### Search Flow
```
Current Session:
1. User taps search icon
2. Search bar appears with filter chips
3. User types query
4. Messages filtered by query and type
5. Results highlighted

Global Search:
1. User taps global search in ContentView
2. GlobalSearchView opens
3. SSHManager searches session files via grep
4. Results show with project context
5. User can navigate to session
```

### Message Persistence
```
1. On view appear: MessageStore.loadMessages(projectPath)
2. Messages loaded from Documents/{encoded-path}.json
3. On message change: MessageStore.saveMessages(messages, projectPath)
4. On new chat: MessageStore.clearMessages(projectPath)
5. Draft auto-saved via onChange(of: inputText)
```

### Ideas Flow
```
1. User long-presses IdeasFAB -> QuickCaptureSheet opens
2. User enters idea text and taps Save
3. IdeasStore.addIdea() creates new Idea
4. Ideas saved to Documents/ideas-{encoded-path}.json
5. User taps FAB to open IdeasDrawerSheet
6. User can search, filter by tag, archive ideas
7. User taps idea -> IdeaEditorSheet opens
8. User edits title, content, tags
9. Changes saved via IdeasStore.updateIdea()
```

## Security Model

| Layer | Implementation |
|-------|---------------|
| Network | Tailscale encrypted tunnel (recommended) |
| Storage | Messages in Documents (device only) |
| SSH Keys | iOS Keychain storage via `KeychainHelper` |
| SSH Password | iOS Keychain storage |
| Command Escaping | `shellEscape()` function for SSH paths |
| HTTP | ATS disabled for local/Tailscale IPs |

See `.claude/rules/ssh-security.md` for SSH security patterns and shell escaping requirements.

## Testing

300+ unit tests covering parsers, utilities, stores, and models:

| Test Suite | Coverage |
|------------|----------|
| `StringMarkdownTests` | HTML entity decoding, markdown normalization |
| `DiffViewTests` | Edit tool diff parsing |
| `TodoListViewTests` | TodoWrite JSON parsing |
| `ImageUtilitiesTests` | MIME type detection |
| `ModelsTests` | Message handling |
| `MessageStoreTests` | Message persistence |
| `DebugLogStoreTests` | Debug logging |
| `ProjectSettingsStoreTests` | Project settings |
| `ScrollStateManagerTests` | Scroll behavior |
| `SessionStoreTests` | Session state management |

Run tests:
```bash
xcodebuild test -project CodingBridge.xcodeproj -scheme CodingBridge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'
```

## Known Issues

See [ROADMAP.md](../ROADMAP.md) for remaining work and [ISSUES.md](../ISSUES.md) for investigation items.

**Resolved in v0.6.0:**
- Full migration from WebSocket to cli-bridge REST API with SSE
- Removed WebSocketManager.swift (1,363 lines)
- Removed APIClient.swift (608 lines)
- New CLIBridgeManager, CLIBridgeAdapter, CLIBridgeAPIClient, CLIBridgeTypes

**Remaining Issues:**
| Issue | Location | Priority |
|-------|----------|----------|
| SSH timeout handling | SSHManager.swift | Medium |
