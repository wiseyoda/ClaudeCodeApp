# Test Coverage

## Summary
- **Last Updated**: 2025-12-30 (Post-Agent Sprint Analysis)
- **Total Test Files**: 58 unit tests + 2 helpers + 1 UI test
- **Total Test Methods**: 1,604
- **Current Status**: 1,539 passing, 44 skipped, 10 failing, 1 UI test failing
- **Estimated Coverage**: ~87% (models, stores, utilities, CLI bridge, managers, adapters well covered)
- **Recent Focus**: Agents 11-14 added significant mock-based coverage for hardware-dependent managers.

> **Note**: WebSocket-related tests were removed in v0.6.0 when migrating to cli-bridge REST API with SSE streaming.

## Test Quality Assessment

### Strengths
1. **Comprehensive Type Coverage**: CLI bridge types have 300+ tests covering all parsing scenarios
2. **Mock Infrastructure**: Well-established `makeForTesting()` and mock protocols for dependency injection
3. **Error Handling**: Extensive coverage of error paths, edge cases, and recovery flows
4. **Deterministic Tests**: Hardware-dependent tests properly skip via `XCTSkip`

### Areas for Improvement
1. **10 Failing Tests**: Related to recent API changes (AnyCodableValue, SessionStore, ProjectCache)
2. **UI Test Flakiness**: PermissionApprovalUITests fails due to simulator launch issues
3. **Integration Tests**: Limited real-server coverage (env-gated)

## Categorical Breakdown

### By Test Count (Top 20 files)
| Test File | Tests | Category |
|-----------|-------|----------|
| SSHManagerTests | 97 | Managers |
| StoresExtendedTests | 88 | Stores |
| CLIBridgeManagerTests | 84 | CLI Bridge |
| CLIBridgeAdapterTests | 84 | CLI Bridge |
| ManagersTests | 83 | Managers |
| CLIBridgeTypesTests | 83 | Types |
| CLIProjectFileTypesTests | 66 | Types |
| UtilitiesExtendedTests | 62 | Utilities |
| CLIBridgeAPIClientTests | 58 | CLI Bridge |
| ToolErrorClassificationTests | 56 | Utilities |
| PermissionManagerTests | 53 | Managers |
| ChatViewModelTests | 53 | ViewModels |
| ModelsExtendedTests | 50 | Models |
| CLIStreamContentTests | 50 | Types |
| PermissionTypesTests | 46 | Types |
| SpeechManagerTests | 45 | Managers |
| ModelsTests | 44 | Models |
| CLISessionTypesTests | 44 | Types |
| ThemeTests | 41 | UI |
| PushNotificationManagerTests | 33 | Managers |

### By Domain
| Domain | Test Files | Total Tests | Coverage |
|--------|------------|-------------|----------|
| **CLI Bridge** | 5 files | ~350 | REST API, SSE streaming, adapters, types |
| **Types/Models** | 12 files | ~450 | JSON parsing, Codable, enums |
| **Managers** | 6 files | ~400 | SSH, Speech, Push, Background, Live Activity |
| **Stores** | 8 files | ~200 | Persistence, caching, session management |
| **Utilities** | 6 files | ~150 | Keychain, networking, haptics, logging |
| **ViewModels** | 1 file | 53 | ChatViewModel state/callbacks |

## Recent Updates (2025-12-30 Agent Sprint Completion)

### Agent Work Summary
| Agent | Test File | Tests Added | Focus Area |
|-------|-----------|-------------|------------|
| #1 | CLIBridgeAPIClientTests | 58 | REST endpoints, error handling, path encoding |
| #2 | StoresExtendedTests | 88 | Error/analytics stores, caching, repositories |
| #3 | PermissionManagerTests | 53 | Config, always-allow/deny, resolution logic |
| #4 | SSHManagerTests | 52 | Path escaping, parsing, git status |
| #5 | CLIBridgeAdapterTests | 84 | Images, model switching, permissions, callbacks |
| #6 | ChatViewModelTests | 56 | Session/input handling, message parsing |
| #7 | PushNotificationManagerTests | 33 | Token registration, status, routing |
| #8 | ManagersTests | 75 | Background, Notification, OfflineQueue, LiveActivity |
| #9 | SpeechManagerTests | 33 | Auth states, recording lifecycle, audio session |
| #10 | UtilitiesExtendedTests | 62 | Network, haptic, keychain, health monitor |
| #11 | CLIBridgeManagerTests | 84 | Network failures, reconnect, stream parsing |
| #12-14 | Various | +100 | Mock SSH client, LiveActivity provider injection |

### Agents 11-14 Additions (Latest)
- **SSHManagerTests (+45)**: Full mock SSH client coverage - connect, execute, file ops, git commands, timeout handling
- **SpeechManagerTests (+12)**: Recognition handler injection, published property updates, locale fallback
- **ManagersTests (+8)**: LiveActivityManager provider injection, push token serialization
- **UtilitiesExtendedTests**: HealthMonitorService edge cases

### Skipped Tests (44 total)
- **SSHManagerTests**: 23 skipped (require real SSH connection)
- **SpeechManagerTests**: 21 skipped (require microphone/speech recognition hardware)

### Failing Tests (10 total)
Need investigation - likely due to recent API changes:
- `ProjectCacheTests.test_cache_corruptedCacheRecovery`
- `ProjectCacheTests.test_cache_manualInvalidation`
- `ChatViewModelTests.test_selectSession_setsSessionAndLoadsHistory`
- `CLIBridgeTypesTests.test_anyCodableValue_encodesNull`
- `CLIBridgeTypesTests.test_anyCodableValue_encodesPrimitiveTypes`
- `SessionStoreTests` (5 tests related to session loading/updating)

## Coverage Matrix

### ✅ Fully Covered (90%+)
| Source File | Test File | Tests |
|-------------|-----------|-------|
| `Models.swift` | `ModelsTests.swift`, `ModelsExtendedTests.swift` | 94 |
| `CLIBridgeTypes.swift` | `CLIBridgeTypesTests.swift`, + 5 type test files | 300+ |
| `Theme.swift` | `ThemeTests.swift`, `CLIThemeToolTypeTests.swift` | 43 |
| `PermissionTypes.swift` | `PermissionTypesTests.swift` | 46 |
| `PermissionManager.swift` | `PermissionManagerTests.swift` | 53 |
| `ToolErrorClassification.swift` | `ToolErrorClassificationTests.swift` | 56 |
| `AppSettings.swift` | `AppSettingsTests.swift` | 32 |
| `CLIBridgeAdapter.swift` | `CLIBridgeAdapterTests.swift` | 84 |
| `CLIBridgeAPIClient.swift` | `CLIBridgeAPIClientTests.swift` | 58 |
| `CLIBridgeManager.swift` | `CLIBridgeManagerTests.swift` | 84 |
| `SSHManager.swift` | `SSHManagerTests.swift` | 97 |
| `ChatViewModel.swift` | `ChatViewModelTests.swift` | 53 |
| `PushNotificationManager.swift` | `PushNotificationManagerTests.swift` | 33 |
| `BackgroundManager.swift` | `ManagersTests.swift` | 20+ |
| `NotificationManager.swift` | `ManagersTests.swift` | 20+ |
| `OfflineActionQueue.swift` | `ManagersTests.swift` | 15+ |
| `SpeechManager.swift` | `SpeechManagerTests.swift` | 45 |
| `NetworkMonitor.swift` | `UtilitiesExtendedTests.swift` | 12 |
| `HapticManager.swift` | `UtilitiesExtendedTests.swift` | 14 |
| `KeychainHelper.swift` | `UtilitiesExtendedTests.swift` | 23 |
| `HealthMonitorService.swift` | `UtilitiesExtendedTests.swift` | 13 |
| `ErrorStore.swift` | `StoresExtendedTests.swift` | 22 |
| `ErrorAnalyticsStore.swift` | `StoresExtendedTests.swift` | 19 |
| `ProjectCache.swift` | `StoresExtendedTests.swift` | 21 |
| All persistence stores | Various test files | 100+ |

### ⚠️ Partially Covered (40-89%)
| Source File | Test File | Coverage Gap |
|-------------|-----------|--------------|
| `LiveActivityManager.swift` | `ManagersTests.swift` | cleanupStaleActivities + real ActivityKit integration requires entitlements |
| `SessionStore.swift` | `SessionStoreTests.swift` | Some tests failing - needs investigation |

### ❌ Not Covered (<40%)
| Source File | Why | Priority |
|-------------|-----|----------|
| `ArchivedProjectsStore.swift` | Has tests but persistence edge cases missing | LOW |

### 🚫 Not Testable / View Files
| Source File | Reason |
|-------------|--------|
| `CodingBridgeApp.swift` | App entry point |
| `ContentView.swift` | Root view composition |
| `ChatView.swift` | Complex UI, requires UI tests |
| `TerminalView.swift` | Terminal UI |
| Views/*.swift (56 files) | UI components, need UI/snapshot tests |

## Test Files Reference

### Unit Tests (58 files)
```
CodingBridgeTests/
├── APIClientModelsTests.swift      # API client model parsing (4)
├── AppErrorTests.swift             # Error types and alerts (4)
├── ApprovalResponseTests.swift     # Permission response encoding (3)
├── AppSettingsTests.swift          # Settings enums and computed props (32)
├── ArchivedProjectsStoreTests.swift # Archive toggle logic (11)
├── BookmarkStoreTests.swift        # Bookmark CRUD (4)
├── ChatViewModelTests.swift        # ViewModel state and callbacks (53)
├── ClaudeHelperSessionIdTests.swift # Helper session ID generation
├── ClaudeHelperTests.swift         # JSON parsing, filtering
├── CLIBridgeAdapterTests.swift     # Adapter images, model switching, permissions (84)
├── CLIBridgeAPIClientTests.swift   # REST API client coverage (58)
├── CLIBridgeManagerTests.swift     # SSE streaming, reconnection, error handling (84)
├── CLIBridgeTypesTests.swift       # Core CLI bridge types (83)
├── CLIProjectFileTypesTests.swift  # Project/file models (66)
├── CLIPushNotificationTypesTests.swift # Push notification types (25)
├── CLISearchExportTypesTests.swift # Search/export types (23)
├── CLISessionTypesTests.swift      # Session metadata parsing (44)
├── CLIStreamContentTests.swift     # SSE stream content types (50)
├── CLIThemeToolTypeTests.swift     # Tool type parsing (2)
├── CodingBridgeTests.swift         # Swift Testing stub (1)
├── CommandStoreTests.swift         # Command CRUD, categories (7)
├── DebugLogStoreTests.swift        # Debug log formatting (9)
├── DiffViewTests.swift             # Edit diff parsing (6)
├── FileEntryTests.swift            # File entry parsing (8)
├── IdeasStoreTests.swift           # Ideas CRUD, filtering (8)
├── IdeaTests.swift                 # Idea prompt formatting (2)
├── ImageUtilitiesTests.swift       # MIME detection, processing (21)
├── LiveActivityTypesTests.swift    # Live Activity attributes (18)
├── LoggerTests.swift               # Logger robustness (13)
├── ManagersTests.swift             # Background/notification/offline/LiveActivity (83)
├── MessageStoreTests.swift         # Message persistence (26)
├── ModelEnumTests.swift            # Model enum properties (2)
├── ModelsExtendedTests.swift       # Extended model coverage (50)
├── ModelsTests.swift               # Core model parsing (44)
├── NamesStoreTests.swift           # Name persistence (5)
├── PermissionTypesTests.swift      # Permission modes and config (46)
├── PermissionManagerTests.swift    # Permission config cache/resolution (53)
├── PersistenceTests.swift          # Draft/queue persistence (18)
├── ProjectSessionFilterTests.swift # Session filtering logic (10)
├── ProjectSettingsStoreTests.swift # Per-project settings (9)
├── PushNotificationManagerTests.swift # Push token handling (33)
├── PushNotificationTypesTests.swift # Push payload parsing (12)
├── ScrollStateManagerTests.swift   # Scroll debouncing (4)
├── SearchFilterViewsTests.swift    # Message filter matching (10)
├── SessionAPIIntegrationTests.swift # Env-gated API tests (4)
├── SessionStoreTests.swift         # Session state management (14)
├── SpecialKeyTests.swift           # Terminal key sequences (2)
├── SpeechManagerTests.swift        # Speech auth, recording, audio session (45)
├── SSHKeyDetectionTests.swift      # SSH key format detection (12)
├── SSHManagerTests.swift           # SSH config parsing, mock client (97)
├── StoresExtendedTests.swift       # Error/analytics/cache stores (88)
├── StringMarkdownTests.swift       # Markdown helpers (16)
├── SubModelsTests.swift            # Git/Image/Task models (30)
├── ThemeTests.swift                # Theme colors and glass tints (41)
├── TodoListViewTests.swift         # TodoWrite parsing (6)
├── ToolErrorClassificationTests.swift # Error classification (56)
├── TruncatableTextTests.swift      # Text truncation logic (4)
└── UtilitiesExtendedTests.swift    # Network/haptic/keychain/health (62)
```

### Helper Files (not tests)
- `IntegrationTestConfig.swift` - Test configuration
- `IntegrationTestClient.swift` - HTTP client helper

### UI Tests
- `CodingBridgeUITests/PermissionApprovalUITests.swift` - Approval banner (1 failing)

## Running Tests

```bash
# Run all unit tests
xcodebuild test -project CodingBridge.xcodeproj -scheme CodingBridge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'

# Run specific test file
xcodebuild test -project CodingBridge.xcodeproj -scheme CodingBridge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' \
  -only-testing:CodingBridgeTests/SSHManagerTests

# With coverage
xcodebuild test -project CodingBridge.xcodeproj -scheme CodingBridge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' \
  -enableCodeCoverage YES
```

## Remaining Coverage Goals

### Priority 1: Fix Failing Tests
1. **AnyCodableValue encoding** - 2 tests in CLIBridgeTypesTests
2. **SessionStore loading** - 5 tests related to session management
3. **ProjectCache invalidation** - 2 cache tests

### Priority 2: High Impact
4. **SSHManager streaming** - executeCommandStream, uploadImage flows
5. **LiveActivityManager** - cleanupStaleActivities (requires entitlements)

### Priority 3: Nice to Have
6. **UI snapshot tests** - Message rendering, diff view, tool views
7. **Performance tests** - Large message histories, long streams
8. **Integration tests** - End-to-end flows with real cli-bridge server

## Test Conventions

- Test files go in `CodingBridgeTests/` named `*Tests.swift`
- Use XCTest framework (Swift Testing available but not widely used)
- Prefer small, deterministic unit tests
- Use `makeForTesting()` factory methods for dependency injection
- Use `resetForTesting()` for singleton cleanup between tests
- Mock protocols for external dependencies (SSH, network, speech)
- Hardware-dependent tests use `XCTSkip` when unavailable
- Integration tests must be env-gated

## Recent History

### 2025-12-30 (Current) - Agent Sprint Completion
- **1,604 test methods** (1,539 passing, 44 skipped, 10 failing)
- **+600+ new tests** added via 14 parallel agents
- Coverage increased from ~70% to ~87%
- Mock infrastructure established for SSH, Speech, LiveActivity
- All core managers now have comprehensive mock-based coverage

### Previous (2025-12-29)
- 987 tests passing
- Initial CLI bridge type coverage
- Basic store and utility tests
