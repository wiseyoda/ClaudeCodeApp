# Test Coverage

## Summary
- **Last Updated**: 2025-12-30
- **Total Test Files**: 60 (+ 2 helpers, 1 UI test)
- **Total Test Cases**: 1,581 (1,563 passing, 18 skipped for hardware dependencies)
- **Estimated Coverage**: ~85% (models, stores, utilities, CLI bridge types, managers, adapters well covered)
- **Recent Focus**: Parallel agent test development added 594 new tests across 10 categories.

> **Note**: WebSocket-related tests were removed in v0.6.0 when migrating to cli-bridge REST API with SSE streaming.

## Recent Updates (2025-12-30 Parallel Agent Sprint)

Added 594 new tests via 10 parallel agents:

| Agent | Test File | Tests Added | Coverage |
|-------|-----------|-------------|----------|
| #1 | CLIBridgeAPIClientTests | 58 | REST endpoints, projects, sessions, files, permissions, push, export, error handling, path encoding |
| #2 | StoresExtendedTests | 88 | ErrorStore, ErrorAnalyticsStore, SessionRepository, ProjectCache, SearchHistoryStore |
| #3 | PermissionManagerTests | 53 | Config load/update, always-allow/deny lists, resolution logic, tool approval, cache |
| #4 | SSHManagerTests | 52 | Path escaping, list parsing, git status parsing, ANSI stripping, key normalization |
| #5 | CLIBridgeAdapterTests | 84 | Image handling, model switching, permissions, questions, JSON helpers, callbacks |
| #6 | ChatViewModelTests | 56 | Session management, input handling, WebSocket callbacks, message parsing, filters |
| #7 | PushNotificationManagerTests | 33 | Token registration/invalidation, status checks, notification routing |
| #8 | ManagersTests | 75 | BackgroundManager, NotificationManager, OfflineActionQueue, LiveActivityManager |
| #9 | SpeechManagerTests | 33 | Authorization states, recording lifecycle, audio session settings |
| #10 | UtilitiesExtendedTests | 62 | NetworkMonitor, HapticManager, KeychainHelper, HealthMonitorService |

**Skipped Tests (18)**: Hardware-dependent tests for microphone, Live Activities, and speech recognition are skipped via XCTSkip when permissions/hardware unavailable.

**Blockers**: Live Activity push token refresh and full active-state transitions still need ActivityKit test injection or entitlements for deterministic coverage.

## Coverage Matrix

### ✅ Fully Covered (90%+)
| Source File | Test File | Tests |
|-------------|-----------|-------|
| `Models.swift` | `ModelsTests.swift`, `ModelsExtendedTests.swift` | 65+ |
| `CLIBridgeTypes.swift` | `CLIBridgeTypesTests.swift`, `CLIStreamContentTests.swift`, `CLISessionTypesTests.swift`, `CLIProjectFileTypesTests.swift`, `CLISearchExportTypesTests.swift`, `CLIPushNotificationTypesTests.swift` | 200+ |
| `Theme.swift` | `ThemeTests.swift`, `CLIThemeToolTypeTests.swift` | 43 |
| `PermissionTypes.swift` | `PermissionTypesTests.swift` | 45+ |
| `PermissionManager.swift` | `PermissionManagerTests.swift` | 50+ |
| `ToolErrorClassification.swift` | `ToolErrorClassificationTests.swift` | 56 |
| `AppSettings.swift` | `AppSettingsTests.swift` | 38 |
| `CommandStore.swift` | `CommandStoreTests.swift` | 15+ |
| `IdeasStore.swift` | `IdeasStoreTests.swift`, `IdeaTests.swift` | 20+ |
| `BookmarkStore.swift` | `BookmarkStoreTests.swift` | 10+ |
| `SessionStore.swift` | `SessionStoreTests.swift`, `ProjectSessionFilterTests.swift` | 20+ |
| `DebugLogStore.swift` | `DebugLogStoreTests.swift` | 9 |
| `ProjectSettingsStore.swift` | `ProjectSettingsStoreTests.swift` | 9 |
| `ProjectNamesStore.swift` | `NamesStoreTests.swift` | 5 |
| `ClaudeHelper.swift` | `ClaudeHelperTests.swift`, `ClaudeHelperSessionIdTests.swift` | 15+ |
| `ChatViewModel.swift` | `ChatViewModelTests.swift` | 56 |
| `CLIBridgeAdapter.swift` | `CLIBridgeAdapterTests.swift` | 84 |
| `CLIBridgeAPIClient.swift` | `CLIBridgeAPIClientTests.swift` | 58 |
| `PushNotificationManager.swift` | `PushNotificationManagerTests.swift` | 33 |
| `BackgroundManager.swift` | `ManagersTests.swift` | 20+ |
| `NotificationManager.swift` | `ManagersTests.swift` | 20+ |
| `OfflineActionQueue.swift` | `ManagersTests.swift` | 15+ |
| `NetworkMonitor.swift` | `UtilitiesExtendedTests.swift` | 12 |
| `HapticManager.swift` | `UtilitiesExtendedTests.swift` | 14 |
| `KeychainHelper.swift` | `UtilitiesExtendedTests.swift` | 23 |
| `HealthMonitorService.swift` | `UtilitiesExtendedTests.swift` | 13 |
| `ErrorStore.swift` | `StoresExtendedTests.swift` | 22 |
| `ErrorAnalyticsStore.swift` | `StoresExtendedTests.swift` | 19 |
| `SessionRepository.swift` | `StoresExtendedTests.swift` | 14 |
| `ProjectCache.swift` | `StoresExtendedTests.swift` | 21 |
| `SearchHistoryStore.swift` | `StoresExtendedTests.swift` | 12 |
| `Logger.swift` | `LoggerTests.swift` | 14 |
| `AppError.swift` | `AppErrorTests.swift` | 4 |
| `ImageUtilities.swift` | `ImageUtilitiesTests.swift` | 10+ |
| `SSHKeyDetection.swift` | `SSHKeyDetectionTests.swift` | 10+ |
| `ScrollStateManager.swift` | `ScrollStateManagerTests.swift` | 4 |
| `String+Markdown.swift` | `StringMarkdownTests.swift` | 20+ |
| `DraftInputPersistence.swift` | `PersistenceTests.swift` | 15+ |
| `MessageQueuePersistence.swift` | `PersistenceTests.swift` | 15+ |
| `GitModels.swift` | `SubModelsTests.swift` | 20+ |
| `ImageAttachment.swift` | `SubModelsTests.swift` | 10+ |
| `TaskState.swift` | `SubModelsTests.swift` | 15+ |
| `LiveActivityAttributes.swift` | `LiveActivityTypesTests.swift` | 10+ |

### ⚠️ Partially Covered (40-89%)
| Source File | Test File | Coverage Gap |
|-------------|-----------|--------------|
| `CLIBridgeManager.swift` | `CLIBridgeManagerTests.swift` | Connection lifecycle, stream parsing, reconnection covered; network edge cases remain |
| `SSHManager.swift` | `SSHManagerTests.swift` | Path escaping, parsing, ANSI stripping covered; SSH-backed ops need mocks/integration |
| `LiveActivityManager.swift` | `ManagersTests.swift` | Guards/reset covered; push token refresh needs ActivityKit entitlements |
| `SpeechManager.swift` | `SpeechManagerTests.swift` | Authorization, recording, audio session covered; live transcription hardware-bound (XCTSkip) |

### ❌ Not Covered (<40%)
| Source File | Why | Priority |
|-------------|-----|----------|
| `ArchivedProjectsStore.swift` | Has tests but persistence edge cases missing | **LOW** |

### 🚫 Not Testable / View Files
| Source File | Reason |
|-------------|--------|
| `CodingBridgeApp.swift` | App entry point |
| `ContentView.swift` | Root view composition |
| `ChatView.swift` | Complex UI, requires UI tests |
| `TerminalView.swift` | Terminal UI |
| `UserQuestionsView.swift` | Question UI |
| Views/*.swift (52 files) | UI components, best covered by UI/snapshot tests |

## Test Files Reference

### Unit Tests (60 files)
```
CodingBridgeTests/
├── APIClientModelsTests.swift      # API client model parsing
├── AppErrorTests.swift             # Error types and alerts
├── ApprovalResponseTests.swift     # Permission response encoding
├── AppSettingsTests.swift          # Settings enums and computed props
├── ArchivedProjectsStoreTests.swift # Archive toggle logic
├── BookmarkStoreTests.swift        # Bookmark CRUD
├── ChatViewModelTests.swift        # ViewModel state and callbacks
├── ClaudeHelperSessionIdTests.swift # Helper session ID generation
├── ClaudeHelperTests.swift         # JSON parsing, filtering
├── CLIBridgeAdapterTests.swift     # Adapter images, model switching, permissions, JSON helpers
├── CLIBridgeAPIClientTests.swift   # REST API client coverage
├── CLIBridgeManagerTests.swift     # WebSocket lifecycle, stream parsing, reconnection
├── CLIBridgeTypesTests.swift       # Core CLI bridge types
├── CLIProjectFileTypesTests.swift  # Project/file models
├── CLIPushNotificationTypesTests.swift # Push notification types
├── CLISearchExportTypesTests.swift # Search/export types
├── CLISessionTypesTests.swift      # Session metadata parsing
├── CLIStreamContentTests.swift     # SSE stream content types
├── CLIThemeToolTypeTests.swift     # Tool type parsing
├── CodingBridgeTests.swift         # Swift Testing stub
├── CommandStoreTests.swift         # Command CRUD, categories
├── DebugLogStoreTests.swift        # Debug log formatting
├── DiffViewTests.swift             # Edit diff parsing
├── FileEntryTests.swift            # File entry parsing
├── IdeasStoreTests.swift           # Ideas CRUD, filtering
├── IdeaTests.swift                 # Idea prompt formatting
├── ImageUtilitiesTests.swift       # MIME detection, processing
├── LiveActivityTypesTests.swift    # Live Activity attributes
├── LoggerTests.swift               # Logger robustness
├── ManagersTests.swift             # Background/notification/offline managers
├── MessageStoreTests.swift         # Message persistence
├── ModelEnumTests.swift            # Model enum properties
├── ModelsExtendedTests.swift       # Extended model coverage
├── ModelsTests.swift               # Core model parsing
├── NamesStoreTests.swift           # Name persistence
├── PermissionTypesTests.swift      # Permission modes and config
├── PermissionManagerTests.swift    # Permission config cache/resolution
├── PersistenceTests.swift          # Draft/queue persistence
├── ProjectSessionFilterTests.swift # Session filtering logic
├── ProjectSettingsStoreTests.swift # Per-project settings
├── PushNotificationManagerTests.swift # Push token handling, registration/invalidation, status, notification routing
├── PushNotificationTypesTests.swift # Push payload parsing
├── ScrollStateManagerTests.swift   # Scroll debouncing
├── SearchFilterViewsTests.swift    # Message filter matching
├── SessionAPIIntegrationTests.swift # Env-gated API tests
├── SessionStoreTests.swift         # Session state management
├── SpecialKeyTests.swift           # Terminal key sequences
├── SpeechManagerTests.swift        # Speech authorization, recording state, audio session, published updates (transcription skipped)
├── SSHKeyDetectionTests.swift      # SSH key format detection
├── SSHManagerTests.swift           # SSH config parsing
├── StoresExtendedTests.swift       # Error/analytics/cache stores
├── StringMarkdownTests.swift       # Markdown helpers
├── SubModelsTests.swift            # Git/Image/Task models
├── ThemeTests.swift                # Theme colors and glass tints
├── TodoListViewTests.swift         # TodoWrite parsing
├── ToolErrorClassificationTests.swift # Error classification
├── TruncatableTextTests.swift      # Text truncation logic
└── UtilitiesExtendedTests.swift    # Network/haptic/keychain/health
```

### Integration Tests (env-gated)
- `SessionAPIIntegrationTests.swift` - Session API pagination, deletion

### UI Tests
- `CodingBridgeUITests/PermissionApprovalUITests.swift` - Approval banner

### Helper Files (not tests)
- `IntegrationTestConfig.swift` - Test configuration
- `IntegrationTestClient.swift` - HTTP client helper

## Running Tests

```bash
# Run all unit tests
xcodebuild test -project CodingBridge.xcodeproj -scheme CodingBridge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'

# Run specific test file
xcodebuild test -project CodingBridge.xcodeproj -scheme CodingBridge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' \
  -only-testing:CodingBridgeTests/ModelsTests

# With coverage
xcodebuild test -project CodingBridge.xcodeproj -scheme CodingBridge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' \
  -enableCodeCoverage YES
```

## Integration Test Configuration

Integration tests are opt-in via environment variables:

**Required:**
- `CODINGBRIDGE_TEST_BACKEND_URL` - cli-bridge server URL
- `CODINGBRIDGE_TEST_AUTH_TOKEN` - Auth token (if required)
- `CODINGBRIDGE_TEST_PROJECT_NAME` or `CODINGBRIDGE_TEST_PROJECT_PATH`

**Optional:**
- `CODINGBRIDGE_TEST_SESSION_MIN_TOTAL` - Min sessions (default: 6)
- `CODINGBRIDGE_TEST_REQUIRE_SUMMARIES=1` - Require session summaries
- `CODINGBRIDGE_TEST_ALLOW_MUTATIONS=1` - Allow destructive tests
- `CODINGBRIDGE_TEST_DELETE_SESSION_ID` - Session to delete
- `CODINGBRIDGE_TEST_WEBSOCKET_URL` - WebSocket URL override

## Remaining Coverage Goals

### Priority 1: High Impact
1. **SSHManager (expanded)** - SSH-backed operations (connect/execute), git pull/diff, file ops need mock injection
2. **CLIBridgeManager edge cases** - Network failure scenarios, reconnection edge cases

### Priority 2: Medium Impact
3. **LiveActivityManager** - Push token refresh with ActivityKit entitlements
4. **SpeechManager** - Live transcription tests (currently hardware-dependent)

### Priority 3: Nice to Have
5. **UI snapshot tests** - Message rendering, diff view, tool views
6. **Performance tests** - Large message histories, long streams
7. **Integration tests** - End-to-end flows with real cli-bridge server

## Test Conventions

- Test files go in `CodingBridgeTests/` named `*Tests.swift`
- Use XCTest framework (Swift Testing available but not widely used)
- Prefer small, deterministic unit tests
- Use fixtures for JSONL, tool payloads, SSH outputs
- Mock external dependencies (network, file system)
- Integration tests must be env-gated

## Recent History

### 2025-12-30 (Current) - Parallel Agent Sprint
- **1,581 tests** (1,563 passing, 18 skipped)
- **+594 new tests** added via 10 parallel agents
- Coverage increased from ~70% to ~85%
- All core managers, adapters, and stores now have comprehensive test coverage
- MockURLProtocol patterns established for network testing
- Test infrastructure: `makeForTesting()`, `resetForTesting()` methods added to key classes

### Previous (2025-12-29)
- 987 tests passing
- Initial CLI bridge type coverage
- Basic store and utility tests
