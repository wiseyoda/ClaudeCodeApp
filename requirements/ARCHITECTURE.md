# Architecture Documentation

## Clean Architecture: Session Management

The session management system uses a Clean Architecture pattern separating concerns into distinct layers:

```
┌─────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│     Views       │────▶│   SessionStore   │◀───▶│ SessionRepository│
│                 │     │  (State Mgmt)    │     │   (Data Layer)   │
└─────────────────┘     └──────────────────┘     └──────────────────┘
                               ▲                         │
                               │                         ▼
                       ┌───────┴────────┐        ┌──────────────────┐
                       │ WebSocketMgr   │        │   APIClient      │
                       │ (Push Events)  │        │   (HTTP)         │
                       └────────────────┘        └──────────────────┘
                               ▲                         │
                               │                         ▼
                       ┌───────┴─────────────────────────┴───────┐
                       │          claudecodeui Backend           │
                       └─────────────────────────────────────────┘
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
| `isLoading` | `[String: Bool]` | Loading state per project |
| `errorByProject` | `[String: Error]` | Error state per project |
| `activeSessionIds` | `[String: String]` | Active session per project |

**Key Methods:**
| Method | Purpose |
|--------|---------|
| `configure(with:)` | Inject repository dependency |
| `loadSessions(for:forceRefresh:)` | Fetch sessions from API |
| `loadMore(for:)` | Pagination - fetch next page |
| `deleteSession(_:for:)` | Optimistic delete with rollback |
| `addSession(_:for:)` | Add newly created session |
| `handleSessionsUpdated(...)` | Process WebSocket push events |
| `displaySessions(for:)` | Filtered/sorted sessions for UI |

### SessionRepository (Data Layer)

Protocol-based abstraction for testability:

```swift
protocol SessionRepository {
    func fetchSessions(projectName: String, limit: Int, offset: Int) async throws -> SessionsResponse
    func deleteSession(projectName: String, sessionId: String) async throws
}
```

**Implementations:**
- `APISessionRepository` - Production HTTP client
- `MockSessionRepository` - Unit testing (DEBUG only)

### Data Flow

1. **Initial Load**: View → `SessionStore.loadSessions()` → Repository → APIClient → Backend
2. **Pagination**: View (Load More) → `SessionStore.loadMore()` → Repository → APIClient
3. **Push Update**: Backend → WebSocket → `WebSocketManager` → `SessionStore.handleSessionsUpdated()` → Views
4. **Delete**: View → `SessionStore.deleteSession()` → (optimistic update) → Repository → Backend

### Configuration

Configure SessionStore at app startup:

```swift
// In ContentView.onAppear or CodingBridgeApp
let repository = APISessionRepository(
    apiClient: APIClient(settings: settings),
    settings: settings
)
SessionStore.shared.configure(with: repository)
```

### Filtering & Display

Sessions are stored raw. Filtering for display happens at read time:

```swift
// filterForDisplay() excludes:
// - Helper sessions (ClaudeHelper.isHelperSession)
// - Empty sessions (messageCount == 0) unless active
// - Agent/task sessions (isAgentSession)

// filterAndSortForDisplay() additionally:
// - Sorts by lastActivity descending
// - Always includes active session
```

---

## Permission Approval System

When bypass permissions is OFF, tool executions require user approval:

```
┌─────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  Claude CLI     │────▶│  claudecodeui    │────▶│   iOS App        │
│  (canUseTool)   │     │  (WebSocket)     │     │  (Approval UI)   │
└─────────────────┘     └──────────────────┘     └──────────────────┘
                               │                         │
                               ◀─────────────────────────┘
                            permission-response
```

### Components

| Component | File | Purpose |
|-----------|------|---------|
| `ApprovalBannerView` | `Views/ApprovalBannerView.swift` | Compact banner with Approve/Always Allow/Deny |
| `ApprovalRequest` | `Models.swift` | Request model (tool, requestId, input) |
| `ApprovalResponse` | `Models.swift` | Response model (approved, alwaysAllow) |
| `ProjectSettingsStore` | `ProjectSettingsStore.swift` | Per-project permission overrides |

### Flow

1. Backend receives tool call from Claude CLI
2. `canUseTool` callback triggers `permission-request` WebSocket event
3. iOS shows `ApprovalBannerView` with tool details
4. User taps Approve/Always Allow/Deny
5. iOS sends `permission-response` back to backend
6. Backend allows/denies tool execution

---

## System Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                              iOS Device                                       │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │                         CodingBridge                                    │  │
│  │                                                                         │  │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌───────────────────────┐   │  │
│  │  │   ContentView   │──│    ChatView     │──│   WebSocketManager    │   │  │
│  │  │   (Projects)    │  │   (Messages)    │  │   (Streaming)         │   │  │
│  │  └─────────────────┘  └─────────────────┘  └───────────────────────┘   │  │
│  │         │                     │                      │                  │  │
│  │         │              ┌──────┴──────┐        ┌──────┴──────┐          │  │
│  │         │              │SpeechManager│        │ClaudeHelper │          │  │
│  │         │              │(Voice Input)│        │(AI Suggest) │          │  │
│  │         │              └─────────────┘        └─────────────┘          │  │
│  │         │                                                               │  │
│  │  ┌──────┴──────┐  ┌─────────────┐  ┌─────────────┐  ┌───────────────┐  │  │
│  │  │TerminalView │──│ SSHManager  │  │MessageStore │  │  BookmarkStore│  │  │
│  │  │ (SSH Shell) │  │ (Citadel)   │  │ (File-based)│  │  (Bookmarks)  │  │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └───────────────┘  │  │
│  │                          │                                              │  │
│  │  ┌─────────────┐  ┌──────┴──────┐  ┌─────────────┐  ┌───────────────┐  │  │
│  │  │ AppSettings │  │CommandStore │  │   Logger    │  │SessionNames   │  │  │
│  │  │ (Config)    │  │ (Prompts)   │  │  (Logging)  │  │Store (Names)  │  │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └───────────────┘  │  │
│  │                          │                                              │  │
│  │                   ┌──────┴──────┐                                       │  │
│  │                   │ IdeasStore  │                                       │  │
│  │                   │ (Ideas)     │                                       │  │
│  │                   └─────────────┘                                       │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────┘
                              │
                              │ WebSocket / SSH
                              │ (via Tailscale)
                              ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                        Backend Server (NAS/Cloud)                             │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │                          claudecodeui                                   │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌───────────────────────────────┐   │  │
│  │  │  WebSocket  │──│   Message   │──│        Claude CLI             │   │  │
│  │  │   Server    │  │   Handler   │  │        Wrapper                │   │  │
│  │  └─────────────┘  └─────────────┘  └───────────────────────────────┘   │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                              │                                                │
│                              ▼                                                │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │                          Claude CLI                                     │  │
│  │  - Authenticated with Anthropic                                         │  │
│  │  - Access to workspace files                                            │  │
│  │  - Tool execution capabilities                                          │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                                                               │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │                            sshd                                         │  │
│  │  - Standard SSH daemon                                                  │  │
│  │  - Terminal access for TerminalView                                     │  │
│  │  - File listing for FilePickerSheet                                     │  │
│  │  - Git operations for CloneProjectSheet                                 │  │
│  │  - Session history for GlobalSearchView                                 │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────┘
```

## iOS App Components

### Core Files

#### CodingBridgeApp.swift
- App entry point
- Creates shared AppSettings instance
- Injects settings into environment
- Requests notification permissions

#### AppSettings.swift
Stores all user configuration using @AppStorage:

| Category | Settings |
|----------|----------|
| Server | URL, username, password, JWT token |
| Claude | Mode (normal/plan), thinking mode (5 levels), skipPermissions |
| Model | defaultModel, customModelId |
| Display | fontSize, appTheme, showThinkingBlocks, autoScrollEnabled |
| Project | projectSortOrder (name/date) |
| SSH | host, port, username, authMethod, password |

Key computed properties:
- `applyThinkingMode()` - Appends thinking trigger words
- `effectivePermissionMode` - Resolves bypass vs mode setting
- `webSocketURL` - Derives ws:// from serverURL with token
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
| `WSClaudeCommand` | WebSocket send format |
| `WSMessage` | WebSocket response types |

**Storage Classes:**
| Class | Storage | Purpose |
|-------|---------|---------|
| `MessageStore` | Documents/{path}.json | Message persistence |
| `BookmarkStore` | Documents/bookmarks.json | Cross-session bookmarks |
| `SessionNamesStore` | UserDefaults | Custom session names |
| `SessionHistoryLoader` | SSH/JSONL | Load session from server |
| `IdeasStore` | Documents/ideas-{path}.json | Per-project idea persistence |

#### WebSocketManager.swift

**Connection Management:**
- `ConnectionState` enum (disconnected/connecting/connected/reconnecting)
- Exponential backoff reconnection (1s -> 2s -> 4s -> 8s max + jitter)
- 30-second processing timeout with auto-reset
- Message retry queue with max 3 attempts

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

**Streaming Callbacks:**
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
| `onSessionsUpdated()` | Session list changed |

#### SpeechManager.swift
- iOS Speech framework integration (SFSpeechRecognizer)
- AVAudioEngine for recording
- Real-time partial results
- Authorization status tracking
- **Known Issue:** Missing deinit for cleanup

#### SSHManager.swift

**Capabilities:**
| Feature | Implementation |
|---------|---------------|
| SSH Client | Citadel (pure Swift) |
| Auth | Password, SSH keys (Ed25519, RSA, ECDSA) |
| Key Storage | iOS Keychain |
| Operations | Terminal I/O, file listing, command execution |
| Auto-connect | Saved credentials priority |

**Known Issues:**
- Command injection vulnerabilities (unescaped paths)
- Password stored in UserDefaults (should use Keychain)

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
- Separate WebSocket with 15-second timeout

#### APIClient.swift
- @MainActor class for thread-safe UI updates
- HTTP client with JWT authentication
- Project listing endpoint (GET /api/projects)
- Session listing with pagination (GET /api/projects/:name/sessions)
- Session deletion (DELETE /api/projects/:name/sessions/:id)

#### Theme.swift
- `CLITheme` with colorScheme-aware colors
- Light and dark mode variants
- Tool-specific colors
- Diff colors (added/removed)

#### Utilities
| File | Purpose |
|------|---------|
| `Logger.swift` | Structured logging (debug/info/warning/error) |
| `AppError.swift` | Unified error handling |
| `ImageUtilities.swift` | MIME type detection (PNG, JPEG, GIF, WebP) |

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
- WebSocket streaming integration
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

### Views/ Folder

| File | Lines | Purpose |
|------|-------|---------|
| `MarkdownText.swift` | 490 | Full markdown rendering with math, tables, code |
| `CLIMessageView.swift` | 575 | Message bubble with role styling, context menu |
| `CLIInputView.swift` | 302 | Multi-line input, attachments, voice, [+] menu |
| `DiffView.swift` | 358 | Edit tool diff with line numbers, context collapse |
| `TodoListView.swift` | 173 | TodoWrite checklist with status colors |
| `CodeBlockView.swift` | 109 | Code display with copy button |
| `TruncatableText.swift` | 275 | Truncated text with expand button |
| `CLIStatusBarViews.swift` | 395 | Unified status bar components |
| `SessionPickerViews.swift` | 410 | Session picker, rename, export |
| `FilePickerSheet.swift` | 311 | File browser with AI suggestions |
| `CloneProjectSheet.swift` | 235 | Git clone with progress |
| `NewProjectSheet.swift` | 209 | Create empty project |
| `CommandsView.swift` | 447 | Command library CRUD |
| `CommandPickerSheet.swift` | 171 | Quick command selection |
| `BookmarksView.swift` | 150 | Bookmark list with search |
| `GlobalSearchView.swift` | 375 | Cross-session search |
| `SearchFilterViews.swift` | 232 | Message filters and search bar |
| `SuggestionChipsView.swift` | 202 | AI suggestion chips |
| `QuickSettingsSheet.swift` | 270 | Fast settings access |
| `IdeasDrawerSheet.swift` | 375 | Ideas drawer management |
| `IdeaEditorSheet.swift` | 260 | Individual idea editing |
| `IdeaRowView.swift` | 320 | Idea list item display |
| `IdeasFAB.swift` | 95 | Floating action button for ideas |
| `QuickCaptureSheet.swift` | 88 | Quick idea capture |
| `TagsFlowView.swift` | 113 | Tag flow layout for ideas |

## Data Flow

### Loading Projects
```
1. App launches
2. ContentView.task calls APIClient.fetchProjects()
3. HTTP GET /api/projects with JWT token
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
4. WebSocketManager.sendMessage() called with:
   - message text
   - project path (cwd)
   - sessionId (optional)
   - permissionMode
   - model options
5. WebSocket sends claude-command message
6. Response streamed via claude-response messages
7. Callbacks update UI:
   - onText: streaming assistant text
   - onToolUse: tool invocation display
   - onToolResult: tool output display
   - onThinking: reasoning block display
8. claude-complete signals end
9. MessageStore saves history to file
10. AI suggestions generated via ClaudeHelper
11. Local notification sent (if backgrounded)
```

### Session Management
```
1. User taps /resume or session picker
2. SessionPickerSheet shows with sessions
3. User can:
   - Select session -> loads history via SSH
   - Rename -> SessionNamesStore saves custom name
   - Delete -> removes session file via SSH
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
| Authentication | JWT tokens via username/password |
| Network | Tailscale encrypted tunnel |
| Storage | Messages in Documents (device only) |
| SSH Keys | iOS Keychain storage via `KeychainHelper` |
| SSH Password | iOS Keychain storage (migrated from UserDefaults in v0.4.0) |
| Command Escaping | `shellEscape()` function for SSH paths (added in v0.4.0) |
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
| `ModelsTests` | WebSocket message handling |
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

**Resolved in Recent Releases:**
- ✅ Missing @MainActor on APIClient and BookmarkStore (v0.4.0)
- ✅ SpeechManager resource leak (v0.4.0)
- ✅ SSH password storage - migrated to Keychain (v0.4.0)
- ✅ Command injection - added shell escaping (v0.4.0)
- ✅ WebSocket state race - fixed connection state timing (v0.4.0)

**Remaining Issues:**
| Issue | Location | Priority |
|-------|----------|----------|
| WebSocket state serialization | WebSocketManager.swift | High |
| @MainActor on BookmarkStore | Models.swift | High |
| SSH timeout handling | SSHManager.swift | Medium |
