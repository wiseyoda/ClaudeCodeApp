# Test Coverage

## Summary
- **Last Updated**: 2025-12-27
- **Total Test Files**: 37
- **Total Test Cases**: 334
- **Estimated Coverage**: ~50% (models, stores, utilities, persistence, session filtering; managers partially covered)

## Current Coverage
Most tests are unit tests in `CodingBridgeTests/` using XCTest. Coverage spans parsing, enums, and store logic:
- `CodingBridgeTests/StringMarkdownTests.swift`: Markdown/string helpers (code fences, HTML decode, usage limit formatting, math escapes).
- `CodingBridgeTests/DiffViewTests.swift`: `DiffView.parseEditContent` parsing for Edit tool payloads.
- `CodingBridgeTests/TodoListViewTests.swift`: TodoWrite parsing and status handling.
- `CodingBridgeTests/ImageUtilitiesTests.swift`: MIME type detection via magic bytes and fallback behavior.
- `CodingBridgeTests/ModelsTests.swift`: core models and JSONL parsing (`Project`, `ChatMessage`, `SessionHistoryLoader`, `WSImage`, `AnyCodable`, `UserQuestion`/`AskUserQuestionData`, `ProjectSession`) including tool result dicts and missing timestamp handling.
- `CodingBridgeTests/ModelEnumTests.swift`: `ClaudeModel` and `GitStatus` computed properties.
- `CodingBridgeTests/AppErrorTests.swift`: `AppError` strings, retryability, and `ErrorAlert` titles.
- `CodingBridgeTests/ClaudeHelperTests.swift`: JSON parsing for suggestions, file list filtering, and idea enhancement.
- `CodingBridgeTests/ClaudeHelperSessionIdTests.swift`: helper session ID determinism and UUID format checks.
- `CodingBridgeTests/CommandStoreTests.swift`: categories, sorting, CRUD, `markUsed`, default command creation, and invalid-file handling using temp files.
- `CodingBridgeTests/IdeasStoreTests.swift`: quick add, filters, tags, archive counts, enhancements, persistence round-trip, and invalid-file handling using temp files.
- `CodingBridgeTests/BookmarkStoreTests.swift`: toggle, search, removal, and invalid-file handling using temp files.
- `CodingBridgeTests/IdeaTests.swift`: idea prompt formatting.
- `CodingBridgeTests/SSHKeyDetectionTests.swift`: SSH key format detection and `SSHError` descriptions.
- `CodingBridgeTests/AppSettingsTests.swift`: `ThinkingMode`, `ClaudeMode`, `AppTheme`, `ProjectSortOrder`, `FontSizePreset`, `SSHAuthType` enums; `AppSettings` URL construction, effective SSH host, permission modes, thinking mode application (38 tests).
- `CodingBridgeTests/ArchivedProjectsStoreTests.swift`: archive/unarchive/toggle logic, path edge cases (11 tests).
- `CodingBridgeTests/FileEntryTests.swift`: `FileEntry.parse` handling for files, directories, symlinks, dot entries, icon mapping, and size formatting.
- `CodingBridgeTests/NamesStoreTests.swift`: Project/Session custom name persistence and clear behavior.
- `CodingBridgeTests/ProjectSessionFilterTests.swift`: session filtering/sorting for display and project display sessions.
- `CodingBridgeTests/TruncatableTextTests.swift`: `TruncatableText.lineLimit` behavior for stack traces, JSON, tool names, and defaults.
- `CodingBridgeTests/CLIThemeToolTypeTests.swift`: `CLITheme.ToolType` parsing plus display name and icon mapping.
- `CodingBridgeTests/SpecialKeyTests.swift`: `SpecialKey.sequence` control and arrow key mappings.
- `CodingBridgeTests/ConnectionStateTests.swift`: `ConnectionState` flags, display text, and accessibility labels.
- `CodingBridgeTests/MessageStoreTests.swift`: `MessageStore` load/save/clear operations for messages, drafts, and session IDs; UserDefaults migration; image persistence/cleanup; multi-project isolation; path encoding with special characters (26 tests).
- `CodingBridgeTests/LoggerTests.swift`: `LogLevel` enum properties; `Logger` singleton access; logging methods handle empty, long, unicode, and special character messages (14 tests).
- `CodingBridgeTests/DebugLogStoreTests.swift`: Debug log types, entry formatting, logging behavior, filtering, and export formatting (9 tests).
- `CodingBridgeTests/APIClientModelsTests.swift`: `SessionMessage` conversions, `AnyCodableValue` string extraction, `UploadedImage` parsing, and `APIError` descriptions (18 tests).
- `CodingBridgeTests/SearchFilterViewsTests.swift`: `MessageFilter` icon/matching logic and `String.searchRanges` behavior (10 tests).
- `CodingBridgeTests/ProjectSettingsStoreTests.swift`: per-project override persistence, effective setting resolution, and storage key encoding (9 tests).
- `CodingBridgeTests/SessionManagerTests.swift`: session insertion, display filtering/sorting, active session persistence, and deletion counts.
- `CodingBridgeTests/WebSocketModelsTests.swift`: WebSocket message encoding/decoding and `AnyCodable` array/double handling (10 tests).
- `CodingBridgeTests/WebSocketManagerSessionIdTests.swift`: session ID validation logic.
- `CodingBridgeTests/WebSocketManagerParsingTests.swift`: WebSocketManager parsing for session events, token budgets, assistant/tool content, model switch confirmations, and session recovery (7 tests).
- `CodingBridgeTests/ScrollStateManagerTests.swift`: scroll debouncing, reset behavior, and auto-scroll flags (4 tests).
- `CodingBridgeTests/SSHManagerTests.swift`: SSH config parsing, command building for `cd`, and ANSI stripping (6 tests).
- `CodingBridgeTests/SpeechManagerTests.swift`: authorization gating, availability, and recording toggles (3 tests).
- `CodingBridgeTests/CodingBridgeTests.swift`: Swift Testing stub; currently no assertions.

No UI tests, integration tests, or automated coverage reporting are configured.

## Running Tests
- `xcodebuild test -project CodingBridge.xcodeproj -scheme CodingBridge -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'`
- For coverage metrics, enable in Xcode or pass `-enableCodeCoverage YES` to `xcodebuild`.

## Roadmap for Future Tests
Priority additions to improve coverage and regression safety:
- **WebSocket + backend**: `WebSocketManager` state transitions, reconnect backoff, streaming assembly, tool-use message ordering, error handling. Requires mocking `URLSessionWebSocketTask`.
- **SSH + file operations**: `SSHManager` path escaping, ls output parsing, git status parsing. Requires mocking SSH client.
- **MessageStore edge cases**: corrupted file handling, image cleanup, UserDefaults migration paths. Current tests cover happy paths.
- **UI flows**: snapshot or XCUITest coverage for chat rendering (Markdown, diff, todo list), attachments, project/session pickers.
- **Performance**: large message histories, long streaming responses, and file browser pagination.

## Recent Additions (2025-12-27)

### Session 10 (Latest)
- **WebSocketManagerParsingTests.swift**: 7 tests covering session creation, token budgets, assistant/tool content parsing, model switch confirmations, and session error recovery.
- **SSHManagerTests.swift**: 6 tests covering SSH config parsing, `cd` command building, and ANSI stripping.
- **SpeechManagerTests.swift**: 3 tests covering authorization gating, availability, and recording toggles.

### Session 9
- **NamesStoreTests.swift**: 5 tests covering project/session custom name persistence and clearing.
- **SessionManagerTests.swift**: 11 tests covering session insertion, display filtering/sorting, active session persistence, and deletion counts.
- **ProjectSessionFilterTests.swift**: 6 tests covering helper/empty filtering, active inclusion, and display sorting.
- **WebSocketManagerSessionIdTests.swift**: 4 tests covering session ID validation for UUID formats.
- **ClaudeHelperSessionIdTests.swift**: 3 tests covering helper session ID determinism and UUID formatting.

### Session 8
- **CommandStoreTests.swift**: 2 tests covering default command creation and invalid file handling.
- **IdeasStoreTests.swift**: 3 tests covering persistence round-trip, invalid file handling, and search filtering by title/tags.
- **BookmarkStoreTests.swift**: 1 test covering invalid file handling.
- **ModelsTests.swift**: 2 tests covering tool result dict parsing and missing timestamp handling.

### Session 7
- **ScrollStateManagerTests.swift**: 4 tests covering scroll debouncing, immediate scroll, and reset behavior.

### Session 6
- **MessageStoreTests.swift**: 4 tests covering UserDefaults migration, invalid migration data handling, image persistence, and orphaned image cleanup.

### Session 5
- **ProjectSettingsStoreTests.swift**: 9 tests covering per-project overrides, effective skip-permissions resolution, persistence, and encoded storage keys.
- **WebSocketModelsTests.swift**: 10 tests covering WebSocket message encoding/decoding and additional `AnyCodable` shapes.

### Session 4
- **APIClientModelsTests.swift**: 18 tests covering `SessionMessage` conversion paths, `AnyCodableValue` string formatting, `UploadedImage` helpers, and `APIError` descriptions.
- **SearchFilterViewsTests.swift**: 10 tests covering message filter icons and matching, plus `searchRanges` edge cases.

### Session 3
- **DebugLogStoreTests.swift**: 9 tests covering `DebugLogType` metadata, `DebugLogEntry` formatting, `DebugLogStore` logging behavior, trimming, filters, and export formatting.

### Session 2
- **MessageStoreTests.swift**: 22 tests covering `MessageStore` file-based persistence for messages, drafts, and session IDs. Tests load/save/clear operations, streaming message exclusion, 50-message limit, timestamp preservation, multi-project isolation, and path encoding with slashes/spaces.
- **LoggerTests.swift**: 14 tests covering `LogLevel` enum raw values and emoji properties; `Logger` singleton access; logging method robustness with empty, long, unicode, special character, and interpolated messages.

### Session 1
- **ConnectionStateTests.swift**: 4 tests covering connection state flags, labels, and display text.
- **CLIThemeToolTypeTests.swift**: 2 tests covering tool type parsing and display metadata.
- **SpecialKeyTests.swift**: 2 tests covering control and arrow escape sequences.
- **FileEntryTests.swift**: 8 tests covering `FileEntry.parse` variations, icon mapping, and size formatting.
- **TruncatableTextTests.swift**: 4 tests covering content-aware line limit selection.
- **AppSettingsTests.swift**: 38 tests covering `ThinkingMode`, `ClaudeMode`, `AppTheme`, `ProjectSortOrder`, `FontSizePreset`, `SSHAuthType` enums plus `AppSettings` computed properties (URL construction, WebSocket URL generation, effective SSH host resolution, permission mode logic, thinking mode application).
- **ArchivedProjectsStoreTests.swift**: 11 tests covering archive/unarchive/toggle operations and edge cases (special characters, empty paths, trailing slashes).

## Test Conventions
- Keep new tests in `CodingBridgeTests/` and name files `*Tests.swift`.
- Prefer small, deterministic units; use fixtures for JSONL, tool payloads, and SSH outputs.
