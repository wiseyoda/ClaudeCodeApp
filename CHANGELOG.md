# Changelog

All notable changes to ClaudeCodeApp are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

### Added
- **SessionManager**: Centralized session management with filtering and sorting
  - Excludes AI helper sessions (agent-*.jsonl) from session list
  - Configurable response timeout in Settings
  - Session sorting by last activity
- **Bulk Session Management** (Feature #19): Delete multiple sessions at once
  - Delete all sessions for a project
  - Delete sessions older than 7, 30, or 90 days
  - Keep only the last 5, 10, or 20 sessions
  - Active session protection prevents accidental deletion
  - Accessible via "Manage" button in session picker toolbar
- **iOS 26 Compatibility Research**: Documented Liquid Glass UI requirements and migration path

### Changed
- Session picker now filters phantom "New Session" entries
- Improved session delete handling to avoid stale UI state

### Fixed
- **SpeechManager**: Changed print() calls to Logger for consistent logging
- **WebSocketManager**: Made `isAppInForeground` @Published for proper SwiftUI observability
- **DebugLogStore**: Static DateFormatter for performance (was creating per-call)
- **GlobalSearchView**: Proper error logging instead of silent try? failures
- **ChatView**: Organized 40+ @State variables with MARK sections for maintainability

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

| Version | Highlights |
|---------|------------|
| 0.1.0 | Initial app: WebSocket chat, SSH terminal, voice input |
| 0.2.0 | Slash commands, TodoWrite, images, settings overhaul |
| 0.2.5 | Code hardening, tests, better error handling |
| 0.3.0 | Project/session management, git sync, model selection |
| 0.3.1 | iPad support, SSH keys, connection indicator |
| 0.3.2 | Search, thinking mode, command library, UI redesign |
| 0.3.3 | Ideas Drawer, task abort |
| 0.4.0 | Message action bar, critical bug fixes, test suite (current) |
