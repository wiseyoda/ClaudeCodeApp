# Test Coverage

## Summary
- **Last Updated**: 2025-12-27
- **Total Test Files**: 21
- **Total Test Cases**: 181
- **Estimated Coverage**: ~40% (models, stores, utilities; managers untested)

## Current Coverage
Most tests are unit tests in `ClaudeCodeAppTests/` using XCTest. Coverage spans parsing, enums, and store logic:
- `ClaudeCodeAppTests/StringMarkdownTests.swift`: Markdown/string helpers (code fences, HTML decode, usage limit formatting, math escapes).
- `ClaudeCodeAppTests/DiffViewTests.swift`: `DiffView.parseEditContent` parsing for Edit tool payloads.
- `ClaudeCodeAppTests/TodoListViewTests.swift`: TodoWrite parsing and status handling.
- `ClaudeCodeAppTests/ImageUtilitiesTests.swift`: MIME type detection via magic bytes and fallback behavior.
- `ClaudeCodeAppTests/ModelsTests.swift`: core models and JSONL parsing (`Project`, `ChatMessage`, `SessionHistoryLoader`, `WSImage`, `AnyCodable`, `UserQuestion`/`AskUserQuestionData`, `ProjectSession`).
- `ClaudeCodeAppTests/ModelEnumTests.swift`: `ClaudeModel` and `GitStatus` computed properties.
- `ClaudeCodeAppTests/AppErrorTests.swift`: `AppError` strings, retryability, and `ErrorAlert` titles.
- `ClaudeCodeAppTests/ClaudeHelperTests.swift`: JSON parsing for suggestions, file list filtering, and idea enhancement.
- `ClaudeCodeAppTests/CommandStoreTests.swift`: categories, sorting, CRUD, and `markUsed` using temp files.
- `ClaudeCodeAppTests/IdeasStoreTests.swift`: quick add, filters, tags, archive counts, and enhancements using temp files.
- `ClaudeCodeAppTests/BookmarkStoreTests.swift`: toggle, search, and removal using temp files.
- `ClaudeCodeAppTests/IdeaTests.swift`: idea prompt formatting.
- `ClaudeCodeAppTests/SSHKeyDetectionTests.swift`: SSH key format detection and `SSHError` descriptions.
- `ClaudeCodeAppTests/AppSettingsTests.swift`: `ThinkingMode`, `ClaudeMode`, `AppTheme`, `ProjectSortOrder`, `FontSizePreset`, `SSHAuthType` enums; `AppSettings` URL construction, effective SSH host, permission modes, thinking mode application (38 tests).
- `ClaudeCodeAppTests/ArchivedProjectsStoreTests.swift`: archive/unarchive/toggle logic, path edge cases (11 tests).
- `ClaudeCodeAppTests/FileEntryTests.swift`: `FileEntry.parse` handling for files, directories, symlinks, dot entries, icon mapping, and size formatting.
- `ClaudeCodeAppTests/TruncatableTextTests.swift`: `TruncatableText.lineLimit` behavior for stack traces, JSON, tool names, and defaults.
- `ClaudeCodeAppTests/CLIThemeToolTypeTests.swift`: `CLITheme.ToolType` parsing plus display name and icon mapping.
- `ClaudeCodeAppTests/SpecialKeyTests.swift`: `SpecialKey.sequence` control and arrow key mappings.
- `ClaudeCodeAppTests/ConnectionStateTests.swift`: `ConnectionState` flags, display text, and accessibility labels.
- `ClaudeCodeAppTests/ClaudeCodeAppTests.swift`: Swift Testing stub; currently no assertions.

No UI tests, integration tests, or automated coverage reporting are configured.

## Running Tests
- `xcodebuild test -project ClaudeCodeApp.xcodeproj -scheme ClaudeCodeApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- For coverage metrics, enable in Xcode or pass `-enableCodeCoverage YES` to `xcodebuild`.

## Roadmap for Future Tests
Priority additions to improve coverage and regression safety:
- **WebSocket + backend**: `WebSocketManager` state transitions, reconnect backoff, streaming assembly, tool-use message ordering, error handling. Requires mocking `URLSessionWebSocketTask`.
- **SSH + file operations**: `SSHManager` path escaping, ls output parsing, git status parsing. Requires mocking SSH client.
- **Persistence stores**: `MessageStore` read/write/migration, corrupted file handling, and image cleanup edge cases. Requires refactoring to support dependency injection for file paths.
- **UI flows**: snapshot or XCUITest coverage for chat rendering (Markdown, diff, todo list), attachments, project/session pickers.
- **Performance**: large message histories, long streaming responses, and file browser pagination.

## Recent Additions (2025-12-27)
- **ConnectionStateTests.swift**: 4 tests covering connection state flags, labels, and display text.
- **CLIThemeToolTypeTests.swift**: 2 tests covering tool type parsing and display metadata.
- **SpecialKeyTests.swift**: 2 tests covering control and arrow escape sequences.
- **FileEntryTests.swift**: 8 tests covering `FileEntry.parse` variations, icon mapping, and size formatting.
- **TruncatableTextTests.swift**: 4 tests covering content-aware line limit selection.
- **AppSettingsTests.swift**: 38 tests covering `ThinkingMode`, `ClaudeMode`, `AppTheme`, `ProjectSortOrder`, `FontSizePreset`, `SSHAuthType` enums plus `AppSettings` computed properties (URL construction, WebSocket URL generation, effective SSH host resolution, permission mode logic, thinking mode application).
- **ArchivedProjectsStoreTests.swift**: 11 tests covering archive/unarchive/toggle operations and edge cases (special characters, empty paths, trailing slashes).

## Test Conventions
- Keep new tests in `ClaudeCodeAppTests/` and name files `*Tests.swift`.
- Prefer small, deterministic units; use fixtures for JSONL, tool payloads, and SSH outputs.
