# Changelog

All notable changes to Coding Bridge are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [0.6.4] - 2025-12-30

### Added

- **Cache-First Startup Optimization**: Near-instant app startup on repeat launches
  - Extended `ProjectCache` with session counts and recent sessions caching
  - UI renders from cache in <1ms, background tasks refresh data without blocking
  - Recent sessions now cached for instant "Recent Activity" display
  - Session counts cached per-project for immediate display

### Fixed

- **Project Card Title Priority**: Custom names from `ProjectNamesStore` now take priority
  - Previously showed cli-bridge title only, now checks local override first
  - Matches behavior of `ProjectRow` in list view
- **Context Menu Animation Jitter**: Fixed laggy/freezing long-press on project cards
  - Replaced `scaleEffect` with `opacity` in `ProjectCardButtonStyle`
  - Scale animation was conflicting with iOS contextMenu's native lift animation
- **ProjectSettingsStore Backwards Compatibility**: Fixed crash on upgrade
  - Added custom decoder for missing `enableSubrepoDiscovery` field
  - Old cached settings now load correctly with default values

### Changed

- `CLISessionMetadata` changed from `Decodable` to `Codable` (enables caching)
- Background refresh runs sub-repo discovery and session counts in parallel

---

## [0.6.2] - 2025-12-30

### Added

- **Compact Tool Views**: New grouped display for tool operations
  - `CompactToolView.swift` - Groups consecutive Read/Glob/Grep into "Explored" rows
  - Merges Bash commands with their results in collapsible terminal views
  - Smart result summaries (git status, build results, line counts)
- **Todo Progress Drawer**: Floating, collapsible todo list during streaming
  - `TodoProgressDrawer.swift` - Shows current task progress without blocking chat
  - Smooth animations and compact design

### Fixed

- **UI Freeze During Streaming**: Fixed keyboard input freezing when typing in Ideas sheet while Claude streams
  - Added 150ms throttling to `MarkdownText` block parsing
  - Prevents expensive regex operations from blocking main thread
  - Deferred parsing during rapid streaming updates
- **ChatView Performance**: Major cleanup and optimization
  - Improved message grouping logic
  - Better state management during streaming
  - Reduced unnecessary view recomputation
- **cli-bridge Integration**: Various stability improvements
  - Fixed tool error classification edge cases
  - Improved session picker reliability
  - Better background task handling

### Changed

- Unified all target versions to 0.6.2 in project settings
- Enhanced CLIMessageView with improved tool rendering
- Improved CodeBlockView and DiffView styling
- Updated documentation and test coverage notes

---

## [0.6.1] - 2025-12-29

### Fixed

- **Session History Tool Rendering**: History now displays tool usage with proper styling
  - Added `includeStructuredContent` parameter to `exportSession()` API call
  - Updated `parseExportMessage()` to handle structured content arrays from cli-bridge
  - Added `parseStructuredContent()` to parse `tool_use`, `tool_result`, and `thinking` blocks
  - Tool calls now render with tool name badges and formatted input/output
  - Thinking blocks display with distinct purple styling

### Changed

- Unified all target versions to 0.6.1 in project settings

---

## [0.6.0] - 2025-12-29

### Added

- **cli-bridge Migration**: Complete migration from WebSocket to REST API with SSE streaming
  - `CLIBridgeManager.swift` - Core REST API client, SSE stream handling
  - `CLIBridgeAdapter.swift` - Callback-style interface adapter for existing code
  - `CLIBridgeAPIClient.swift` - HTTP client for health checks and project/session listing
  - `CLIBridgeTypes.swift` - All message types and protocol models
- **Permission System**: New permission management components
  - `PermissionManager.swift` - Permission state and history tracking
  - `PermissionTypes.swift` - Permission type definitions
- **Background Infrastructure**: Live Activity and push notification support
  - `LiveActivityManager.swift` - Live Activity updates
  - `LiveActivityAttributes.swift` - Activity attribute models
  - `PushNotificationManager.swift` - Push notification handling
- **New Utilities**:
  - `HealthMonitorService.swift` - Backend connectivity monitoring
  - `KeychainHelper.swift` - Secure credential storage
  - `SSHKeyDetection.swift` - SSH key type detection and validation
  - `SearchHistoryStore.swift` - Search query persistence
- **New Views**:
  - `SettingsView.swift` - App settings UI
  - `DiagnosticsView.swift` - Debug diagnostics
  - `ServerHealthView.swift` - Backend health display
  - `PermissionSettingsView.swift` - Permission configuration
  - `FileBrowserView.swift` - File system navigation
  - `FileContentViewer.swift` - File content display
  - `GitStatusIndicator.swift` - Git status icons
  - `GitSyncBanner.swift` - Git sync notifications
  - `SSHKeyImportSheet.swift` - SSH key import UI
  - `CustomModelPickerSheet.swift` - Custom model selection
  - `SlashCommandHelpSheet.swift` - Slash command reference
  - `MetricsDashboardView.swift` - Metrics display
  - `ProjectDetailView.swift` - Project details
  - `ProjectListViews.swift` - Project list components
  - `CLIBridgeBanners.swift` - Status banners
  - `ChatViewExtensions.swift` - Chat view extensions
- **New Models**:
  - `GitModels.swift` - Git status and operations models
  - `ImageAttachment.swift` - Image attachment handling

### Removed

- **WebSocket Architecture**: Superseded by cli-bridge REST API with SSE
  - `WebSocketManager.swift` (1,363 lines)
  - `APIClient.swift` (608 lines)
  - `WebSocketManagerParsingTests.swift`
  - `WebSocketManagerSessionIdTests.swift`
  - `WebSocketModelsTests.swift`
  - `ConnectionStateTests.swift`
  - `SessionWebSocketIntegrationTests.swift`
- **Obsolete Documentation**:
  - `.claude/rules/websocket-patterns.md`
  - `requirements/projects/background-hardening/` (moved to separate planning)
  - `requirements/projects/claudecode-fork/implementation-plan.md`
  - `requirements/projects/xcode-suggestions.md`

### Changed

- **Architecture**: REST API with SSE streaming replaces WebSocket for all Claude communication
- **Code Reduction**: Net reduction of ~9,000 lines through consolidation
- **Documentation**: Updated all requirements docs for cli-bridge architecture
- Default server URL changed from port 8080 to 3100 (cli-bridge default)
- Simplified connection state management

---

## [0.5.1] - 2025-12-28

### Added

- **Message Queuing Design Documentation**: Complete feature specification for queuing messages while agent is busy
  - `requirements/projects/message-queuing/README.md` - Overview and key decisions
  - `requirements/projects/message-queuing/REQUIREMENTS.md` - Functional and non-functional requirements
  - `requirements/projects/message-queuing/ARCHITECTURE.md` - Technical design and data flows
  - `requirements/projects/message-queuing/IMPLEMENTATION-PLAN.md` - Step-by-step build plan
  - `requirements/projects/message-queuing/UI-SPEC.md` - UI/UX design specification
- **Background Hardening Design Documentation**: Complete spec for reliable background operation
  - `requirements/projects/background-hardening/` - Full requirements package (9 documents)
- **HapticManager**: Centralized haptic feedback utility for consistent tactile feedback
- **UI Test Infrastructure**: Permission approval test harness and UI test suite
  - `PermissionApprovalTestHarnessView.swift` - Debug harness for testing approval flows
  - `CodingBridgeUITests/PermissionApprovalUITests.swift` - UI automation tests
- **Integration Test Infrastructure**: Session API and WebSocket integration tests
  - `IntegrationTestConfig.swift` - Environment-based test configuration
  - `SessionAPIIntegrationTests.swift` - API endpoint tests
  - `SessionWebSocketIntegrationTests.swift` - Real-time update tests
- **New Test Cases**:
  - `ApprovalResponseTests.swift` - Permission response encoding tests
  - Additional `SessionStoreTests` for sessions-updated handling
  - Additional `WebSocketManagerParsingTests` for permission requests
  - Additional `ProjectSessionFilterTests` for agent session filtering

### Changed

- **Scroll-to-Bottom UX**: Improved detection of "at bottom" state
  - Added content and viewport dimension tracking in `ScrollStateManager`
  - Bottom anchor visibility tracking for more reliable auto-scroll
  - Button now uses compact chevron icon instead of filled circle
- **Code Block Headers**: Enhanced language display with icons and colored badges
  - Display-friendly language names (TypeScript, JavaScript, etc.)
  - SF Symbol icons per language type
  - Capsule badge with subtle cyan background

### Fixed

- **API URL Encoding**: Project names with spaces/special characters now work correctly
  - Added `addingPercentEncoding` to session, token, and upload API paths
- **Auth Retry Loop**: Added retry limit (max 1) to prevent infinite auth loops
- **WebSocket Session ID Validation**: All session ID sends now validate UUID format
- **Force Unwrap Removed**: WebSocket message type parsing now uses guard-let
- **Pull-to-Refresh**: Chat view now supports refresh gesture to reload session history

---

## [0.5.0] - 2025-12-28

### Added

- **Session API Migration** (v0.5.1): Replaced SSH-based session loading with proper API
  - `SessionRepository.swift` - Protocol + API implementation + Mock for testing
  - `SessionStore.swift` - Centralized state management with pagination
  - Clean Architecture pattern separating state, repository, and view layers
  - Backend limit increased from 5 to 1000 sessions
  - WebSocket `sessions-updated` events for real-time updates
  - 12 new unit tests for session management
- **Backend Improvements** (wiseyoda/claudecodeui fork):
  - `sessionType` field for classifying sessions (agent/helper/display)
  - `textContent` normalized field for simpler message rendering
  - `?batch=<ms>` WebSocket parameter for streaming batching
  - Cache headers (30s projects, 15s sessions) with WebSocket push updates
- **Permission Approval Banner**: Interactive approval UI when bypass permissions is OFF
  - `ApprovalBannerView` - Compact banner with Approve/Always Allow/Deny buttons
  - `ApprovalRequest` and `ApprovalResponse` models for WebSocket protocol
  - Real-time permission request handling in WebSocketManager
  - Backend fork (wiseyoda/claudecodeui) with `canUseTool` callback support
- **Session Management Improvements**:
  - SessionManager replaced with SessionStore (Clean Architecture)
  - Excludes AI helper sessions (agent-\*.jsonl) from session list
  - Load More pagination for large session lists
  - Real-time session updates via WebSocket push
- **Bulk Session Management** (Feature #19): Delete multiple sessions at once
  - Delete all sessions for a project
  - Delete sessions older than 7, 30, or 90 days
  - Keep only the last 5, 10, or 20 sessions
  - Active session protection prevents accidental deletion
- **iOS 26 Liquid Glass UI**: Full adoption of new design system
  - `GlassTint` enum with semantic colors (primary, success, warning, error, info, accent, neutral)
  - `GlassEffectModifier` and `GlassCapsuleModifier` view modifiers in Theme.swift
  - Glass effects applied to GitSyncBanner, CLIProcessingView, QuickActionButton, CLIInputView
  - Toolbars updated to use `.ultraThinMaterial` for glass-ready backgrounds
- **iOS Platform Quirks Documentation**: Documented workarounds in CLAUDE.md

### Changed

- **App Rebranding**: Display name changed from "Claude Code" to "Coding Bridge"
- **Architecture**: Session management migrated from SSH to API with Clean Architecture
- Session picker now uses API pagination instead of loading all via SSH
- Removed `SessionManager.swift` (replaced by `SessionStore.swift`)
- Session picker now filters phantom "New Session" entries (Issue #16 workaround)

### Fixed

- **"Always Allow" Permission Not Working** (Issue #24): Fixed permission response format to include explicit `alwaysAllow: true` boolean
- **Session Loading**: Now uses API instead of SSH (faster, more reliable)
- **Helper Session Hash Collisions**: Improved hash function in `ClaudeHelper.createHelperSessionId()`
- **Session Delete Race**: Timestamped tracking prevents stale UI state
- **BookmarkStore Atomic Save**: Added atomic writes for crash safety
- **Non-atomic Image Save**: Now uses atomic writes and validates JSON before saving
- **DebugLogStore Performance**: Static DateFormatter (was creating per-call)
- **ChatView Organization**: Organized 40+ @State variables with MARK sections
- Fix scroll-to-bottom button visibility when scrolling up or returning to bottom

---

## [0.4.0] - 2025-12-27

### Added

- **Message Action Bar**: Bottom bar on assistant messages with execution time, token count, copy button, and analyze button
- **Quick-Access Mode Toggles**: Restored mode and thinking chips to status bar for faster access
- **Auto-Refresh Git Status**: Periodic 30-second refresh plus auto-refresh after task completion
- **Quick Commit & Push**: Button in pending changes banner to commit and push via Claude
- **Debug Log Viewer**: Real-time WebSocket traffic debugging
  - `DebugLogStore` - Captures sent/received messages, errors, and connection events
  - `DebugLogView` - Filterable log viewer with JSON pretty-printing
  - Export logs as text for troubleshooting
- **Project Settings Override**: Per-project permission mode settings
  - `ProjectSettingsStore` - Override global settings per project
  - Settings persist in Documents directory
- **Scroll State Manager**: Improved chat scroll behavior
  - Debounced scroll requests prevent jitter during streaming
  - Tracks user intent to allow manual scrolling
  - Smooth animations with configurable timing
- **Session Management Improvements**: Enhanced session picker
  - Session sorting by last activity (most recent first)
  - Filters out placeholder sessions
  - Processing indicator for active sessions
  - Context menu for quick delete
- **Comprehensive Test Suite**: 36 new test cases bringing total from 181 to 216
  - `MessageStoreTests.swift` - Message persistence tests
  - `LoggerTests.swift` - Logging utility tests
  - `DebugLogStoreTests.swift` - Debug logging tests
  - `ProjectSettingsStoreTests.swift` - Project settings tests
  - `ScrollStateManagerTests.swift` - Scroll behavior tests
  - Extended coverage for stores, models, and helpers

### Fixed

- **WebSocket State Race**: Connection state now set only after first successful receive
- **Missing @MainActor**: Added to `APIClient.swift` and `BookmarkStore` for thread safety
- **SpeechManager Resource Leak**: Added proper `deinit` with resource cleanup
- **SSH Password Storage**: Migrated from UserDefaults to Keychain via `KeychainHelper`
- **Command Injection**: Added `shellEscape()` function used in all SSH path-handling functions
- **SSHManager Connection Leak**: Refactored to singleton pattern (`SSHManager.shared`) to prevent orphaned SSH processes
  - Added proper `deinit` that closes SSH connections
  - Updated 6 views to use shared instance instead of creating new managers
  - Added `onDisappear` cleanup in `TerminalView`

---

## [0.3.3] - 2025-12-27

### Added

- **Ideas Drawer**: Per-project idea capture with floating action button
  - Quick capture sheet via long-press on FAB
  - Full drawer with search, tags, archive/restore
  - AI enhancement fields in idea editor
  - Tags flow view for visual tag management
  - JSON persistence in Documents directory
- **Task Abort**: Reliable cancel with visual feedback
  - Red stop button during processing
  - Keyboard shortcuts: Escape and Cmd+. (iPad)
  - 3-second timeout fallback if server unresponsive
  - System message confirmation on abort
- ISSUES.md for structured bug and feature request tracking

### Fixed

- Thread safety issues via `@MainActor` additions
- WebSocket state race conditions
- Resource cleanup in SpeechManager

---

## [0.3.2] - 2025-12-27

### Added

- **Thinking Mode**: 5-level thinking (Normal to Ultrathink)
  - ThinkingModeIndicator in status bar
  - Silently appends trigger words to messages
  - Distinct icons and purple gradient colors
- **Search & Discovery**: Message search with filters
  - MessageFilter enum (All/User/Assistant/Tools/Thinking)
  - BookmarkStore with Documents persistence
  - BookmarksView with swipe-to-delete
  - GlobalSearchView for cross-session SSH search
- **Command Library**: Saved commands with categories
  - CommandStore singleton with JSON persistence
  - CommandsView for CRUD management
  - CommandPickerSheet for quick selection
  - Last-used tracking and sorting
- **AI Suggestions (POC)**: ClaudeHelper meta-AI service
  - Suggestion chips after responses
  - File context suggestions in picker
  - Separate WebSocket with 15-second timeout
- **UI Redesign**: Unified status bar with model, connection, thinking, tokens
  - QuickSettingsSheet for fast setting changes
  - Multi-line text input with word wrap
  - [+] button menu for commands, files, images, voice
- Manual pull button added to git sync banner

---

## [0.3.1] - 2025-12-27

### Added

- **SSH Key Import**: Secure key management
  - KeychainHelper for secure storage
  - SSHKeyType enum (Ed25519, RSA, ECDSA)
  - SSHKeyImportSheet with paste/file import
  - Passphrase support for encrypted keys
  - Auto-connect priority: SSH Config, Keychain, Filesystem, Password
- **Connection Status**: Visual indicator with state feedback
  - Animated pulsing dot
  - Color-coded status (green/yellow/red)
  - Message queuing with retry logic
- **iPad Experience**
  - Keyboard shortcuts (Cmd+Return, Cmd+K, Cmd+N, Cmd+., Cmd+/, Esc)
  - NavigationSplitView with sidebar
  - ProjectRow with selection indicator
  - Split view multitasking support
- TruncatableText view for long content

### Fixed

- JWT auth for project listing (was using API key incorrectly)
- API key auth handling and error messages
- Project list selection on iPhone

---

## [0.3.0] - 2025-12-27

### Added

- **Project Management**
  - Clone from GitHub URL via SSH
  - Create new empty projects
  - Delete projects with confirmation
  - File browser with breadcrumb navigation
  - @ button for file references
- **Session Management**
  - SessionNamesStore for custom names
  - Full-screen session picker
  - Rename, delete, export sessions
  - Message count and preview in rows
- **Auto-Sync**
  - GitStatus enum with 10 states
  - Background status checking
  - GitStatusIndicator icons
  - Auto-pull for clean projects
  - GitSyncBanner with "Ask Claude" action
- **Model Selection**
  - ClaudeModel enum (Opus/Sonnet/Haiku/Custom)
  - Model selector pill in nav bar
  - Model passed via WebSocket options
  - Default model in settings
- **Tool Visualization Enhancements**
  - ToolType enum with 12 tools
  - Distinct colors and SF Symbol icons
  - Rich headers with key params
  - Result count badges
  - Enhanced DiffView with line numbers
  - Context collapsing in diffs
- Copy & Share: Copy buttons, context menus, share sheet

### Changed

- Comprehensive documentation update for all features

---

## [0.2.5] - 2025-12-26

### Added

- Application hardening: extracted UI components to Views/
- Utilities: Logger, AppError, ImageUtilities
- Unit tests for parsers and markdown rendering
- Auto-focus input field when conversation loads

### Changed

- Improved error handling throughout the app
- Code organization with dedicated directories

---

## [0.2.0] - 2025-12-26

### Added

- **Slash Commands**: /clear, /init, /resume, /help, etc.
- **TodoWrite Visualization**: Visual checklist for task tracking
- **AskUserQuestion**: Interactive UI for Claude questions
- **Image Attachments**: PhotosPicker integration, SFTP upload
- Settings overhaul with iOS Form style
- Session history loading via SSH
- Polish features (L1-L4)
- Processing timeout handling

### Fixed

- Markdown rendering for headers and inline formatting
- Message streaming separation (text vs tool uses)
- Image upload via SSH with better base64 handling
- Enter key behavior (sends message)
- Auto-scroll to bottom on new messages
- Session file path leading dash preservation

---

## [0.1.0] - 2025-12-26

### Added

- **Initial Release**
- WebSocket real-time streaming chat with Claude
- Full markdown rendering (headers, code blocks, tables, lists)
- Tool visualization with collapsible messages
- SSH terminal with Citadel library
- Key-based SSH authentication
- Voice input with Speech framework
- Message persistence (50 per project)
- Draft auto-save per project
- Local notifications on task completion
- App icon assets
- Privacy keys for TCC compliance

---

## Version Summary

| Version | Highlights                                             |
| ------- | ------------------------------------------------------ |
| 0.1.0   | Initial app: WebSocket chat, SSH terminal, voice input |
| 0.2.0   | Slash commands, TodoWrite, images, settings overhaul   |
| 0.2.5   | Code hardening, tests, better error handling           |
| 0.3.0   | Project/session management, git sync, model selection  |
| 0.3.1   | iPad support, SSH keys, connection indicator           |
| 0.3.2   | Search, thinking mode, command library, UI redesign    |
| 0.3.3   | Ideas Drawer, task abort                               |
| 0.4.0   | Message action bar, critical bug fixes, test suite     |
| 0.5.0   | Session API migration, permission approval, iOS 26 UI  |
| 0.5.1   | Message queuing docs, haptics, scroll UX, bug fixes    |
| 0.6.0   | **cli-bridge migration** - REST API with SSE streaming |
| 0.6.1   | Session history tool rendering, structured content     |
| 0.6.2   | Compact tool views, UI freeze fix, ChatView cleanup    |
