# Generated Types Migration Plan

> Path to 100% OpenAPI-generated types for cli-bridge protocol

## Overview

This project migrates all hand-written cli-bridge types in `CLIBridgeTypes.swift` to auto-generated types from the OpenAPI spec. This ensures the iOS client stays perfectly in sync with the backend protocol.

## Prerequisites

| Issue | Status | Description |
|-------|--------|-------------|
| [#8](https://github.com/wiseyoda/cli-bridge/issues/8) | ✅ Fixed | ServerMessage uses `oneOf` with discriminator |
| [#9](https://github.com/wiseyoda/cli-bridge/issues/9) | ✅ Fixed | Push notification endpoints in OpenAPI |
| [#10](https://github.com/wiseyoda/cli-bridge/issues/10) | 🔄 Pending | File/directory endpoints in OpenAPI |
| [#11](https://github.com/wiseyoda/cli-bridge/issues/11) | 🔄 Pending | Other missing endpoints in OpenAPI |

**Do not start until all 4 issues are resolved.**

## Current State

- **Generated types:** 96 files in `CodingBridge/Generated/`
- **Hand-written types:** ~75 types in `CLIBridgeTypes.swift` (~2500 lines)
- **Migration bridge:** `CLIBridgeTypesMigration.swift` with typealiases

## Migration Phases

### Phase 1: Regenerate with Complete Spec

**Goal:** Get all types generated from updated OpenAPI spec

```bash
# After cli-bridge updates are deployed
./scripts/regenerate-api-types.sh

# Verify new types exist
ls CodingBridge/Generated/ | grep -E "Push|File|Server"
```

**Expected new generated types:**
- `ServerMessage` (now proper enum, not flat struct)
- `PushRegisterRequest`, `PushRegisterResponse`
- `LiveActivityRegisterRequest`, `LiveActivityRegisterResponse`
- `FileEntry`, `FileListResponse`, `FileContentResponse`
- `PermissionsConfig`, `GitPullResponse`, `SubRepoInfo`

**Verification:**
```bash
# Count should increase from 96 to ~110+
ls CodingBridge/Generated/*.swift | wc -l
```

---

### Phase 2: Create Comprehensive Typealiases

**Goal:** Bridge all old CLI* names to new generated types without breaking callers

**File:** `CLIBridgeTypesMigration.swift`

Add typealiases for every hand-written type:

```swift
// WebSocket Messages
public typealias CLIStartPayload = StartMessage
public typealias CLIInputPayload = InputMessage
public typealias CLIConnectedPayload = ConnectedMessage
public typealias CLIStoppedPayload = StoppedMessage
// ... etc

// Stream Content
public typealias CLIAssistantContent = AssistantStreamMessage
public typealias CLIToolUseContent = ToolUseStreamMessage
public typealias CLIUsageContent = UsageStreamMessage
// ... etc

// Server/Client Messages (now proper enums!)
public typealias CLIServerMessage = ServerMessage
public typealias CLIClientMessage = ClientMessage
public typealias CLIStreamContent = StreamMessage

// REST Types
public typealias CLIPushRegisterRequest = PushRegisterRequest
public typealias CLIFileEntry = FileEntry
// ... etc
```

**Verification:**
```bash
# Build should succeed with no errors
xcodebuild -project CodingBridge.xcodeproj -scheme CodingBridge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build
```

---

### Phase 3: Update CLIBridgeManager

**Goal:** Update WebSocket message handling to use generated types

**Key changes in `CLIBridgeManager.swift`:**

1. **Replace `CLIServerMessage` decoding:**
```swift
// Before (hand-written enum)
let serverMessage = try JSONDecoder().decode(CLIServerMessage.self, from: data)

// After (generated enum with proper discriminator)
let serverMessage = try JSONDecoder().decode(ServerMessage.self, from: data)
```

2. **Update `processServerMessage()` switch:**
```swift
// Before
switch message {
case .connected(let payload):
case .stream(let streamMsg):
// ...
}

// After (generated case names)
switch message {
case .typeConnectedMessage(let payload):
case .typeStreamServerMessage(let streamMsg):
// ...
}
```

3. **Update `send()` method:**
```swift
// Before
private func send(_ message: CLIClientMessage) async throws

// After
private func send(_ message: ClientMessage) async throws
```

**Files to update:**
- `CLIBridgeManager.swift` - Main WebSocket handling
- `CLIBridgeAdapter.swift` - Adapter layer

---

### Phase 4: Update CLIBridgeAPIClient

**Goal:** Update REST API calls to use generated types

**Key changes in `CLIBridgeAPIClient.swift`:**

```swift
// Before
func registerPushToken(...) async throws -> CLIPushRegisterResponse

// After
func registerPushToken(...) async throws -> PushRegisterResponse

// Before
func listFiles(...) async throws -> CLIFileListResponse

// After
func listFiles(...) async throws -> FileListResponse
```

**Files to update:**
- `CLIBridgeAPIClient.swift` - All REST methods

---

### Phase 5: Update Views and Stores

**Goal:** Update UI code to use generated types

**Files to check:**
- `ChatView.swift` - Message display
- `SessionStore.swift` - Session handling
- `PermissionSheet.swift` - Permission UI
- `QuestionSheet.swift` - Question UI
- `ToolResultView.swift` - Tool display
- All files using `CLI*` types

**Search for remaining usages:**
```bash
grep -r "CLI[A-Z]" CodingBridge/*.swift CodingBridge/**/*.swift | grep -v "CLIBridgeTypes\|CLIBridgeTypesMigration"
```

---

### Phase 6: Remove Hand-Written Types

**Goal:** Delete `CLIBridgeTypes.swift` entirely

1. **Move app-only types to appropriate files:**
   - `CLIDateFormatter` → `Utilities/DateFormatters.swift`
   - `ConnectionState` → `CLIBridgeManager.swift` (already there)
   - `TokenUsage` → `Models.swift`
   - `ConnectionError` → `Utilities/AppError.swift`
   - `MessageValidationError` → `Utilities/AppError.swift`

2. **Delete `CLIBridgeTypes.swift`**

3. **Rename `CLIBridgeTypesMigration.swift`:**
   - Keep only essential extensions (not typealiases)
   - Rename to `CLIBridgeExtensions.swift`

4. **Update imports and references**

---

### Phase 7: Clean Up and Document

**Goal:** Final cleanup and documentation

1. **Remove unused typealiases** from migration file

2. **Update `CLAUDE.md`:**
   - Remove references to hand-written types
   - Document generated type usage patterns

3. **Update architecture docs:**
   - `requirements/ARCHITECTURE.md`

4. **Add migration notes to `CHANGELOG.md`**

---

## Type Mapping Reference

### WebSocket Client Messages

| Old Type | New Generated Type |
|----------|-------------------|
| `CLIClientMessage` | `ClientMessage` |
| `CLIStartPayload` | `StartMessage` |
| `CLIInputPayload` | `InputMessage` |
| `CLIPermissionResponsePayload` | `PermissionResponseMessage` |
| `CLIQuestionResponsePayload` | `QuestionResponseMessage` |
| `CLISubscribeSessionsPayload` | `SubscribeSessionsMessage` |
| `CLISetModelPayload` | `SetModelMessage` |
| `CLISetPermissionModePayload` | `SetPermissionModeMessage` |
| `CLIRetryPayload` | `RetryMessage` |
| `CLIReconnectPayload` | `ReconnectMessage` |

### WebSocket Server Messages

| Old Type | New Generated Type |
|----------|-------------------|
| `CLIServerMessage` | `ServerMessage` |
| `CLIConnectedPayload` | `ConnectedMessage` |
| `CLIStoppedPayload` | `StoppedMessage` |
| `CLIModelChangedPayload` | `ModelChangedMessage` |
| `CLIPermissionModeChangedPayload` | `PermissionModeChangedMessage` |
| `CLIPongPayload` | `PongMessage` |
| `CLIQueuedPayload` | `QueuedMessage` |
| `CLIHistoryPayload` | `HistoryMessage` |
| `CLIErrorPayload` | `WsErrorMessage` |
| `CLICursorEvictedPayload` | `CursorEvictedMessage` |
| `CLICursorInvalidPayload` | `CursorInvalidMessage` |
| `CLIReconnectCompletePayload` | `ReconnectCompleteMessage` |

### Stream Content

| Old Type | New Generated Type |
|----------|-------------------|
| `CLIStreamMessage` | `StreamServerMessage` |
| `CLIStreamContent` | `StreamMessage` |
| `CLIAssistantContent` | `AssistantStreamMessage` |
| `CLIUserContent` | `UserStreamMessage` |
| `CLISystemContent` | `SystemStreamMessage` |
| `CLIThinkingContent` | `ThinkingBlock` |
| `CLIToolUseContent` | `ToolUseStreamMessage` |
| `CLIToolResultContent` | `ToolResultStreamMessage` |
| `CLIProgressContent` | `ProgressStreamMessage` |
| `CLIUsageContent` | `UsageStreamMessage` |
| `CLIStateContent` | `StateStreamMessage` |
| `CLISubagentStartContent` | `SubagentStartStreamMessage` |
| `CLISubagentCompleteContent` | `SubagentCompleteStreamMessage` |
| `CLIAgentState` | `StateStreamMessage.State` |

### Permissions & Questions

| Old Type | New Generated Type |
|----------|-------------------|
| `CLIPermissionRequest` | `PermissionRequestMessage` |
| `CLIQuestionRequest` | `QuestionMessage` |
| `CLIQuestionItem` | `QuestionItem` |
| `CLIQuestionOption` | `QuestionOption` |

### Sessions & Search

| Old Type | New Generated Type |
|----------|-------------------|
| `CLISessionEvent` | `SessionEventMessage` |
| `CLISessionMetadata` | `SessionMetadata` |
| `CLISearchSnippet` | `SearchSnippet` |
| `CLISearchResult` | `SearchResult` |
| `CLISearchResponse` | `SearchResponse` |
| `StoredMessage` | `StoredMessage` |

### Push Notifications (after #9)

| Old Type | New Generated Type |
|----------|-------------------|
| `CLIPushRegisterRequest` | `PushRegisterRequest` |
| `CLIPushRegisterResponse` | `PushRegisterResponse` |
| `CLILiveActivityRegisterRequest` | `LiveActivityRegisterRequest` |
| `CLILiveActivityRegisterResponse` | `LiveActivityRegisterResponse` |
| `CLIPushInvalidateRequest` | `PushInvalidateRequest` |
| `CLIPushStatusResponse` | `PushStatusResponse` |

### Files (after #10)

| Old Type | New Generated Type |
|----------|-------------------|
| `CLIFileEntry` | `FileEntry` |
| `CLIFileListResponse` | `FileListResponse` |
| `CLIFileContentResponse` | `FileContentResponse` |

### Other (after #11)

| Old Type | New Generated Type |
|----------|-------------------|
| `CLIGitStatus` | `APIGitStatus` |
| Permissions types | `PermissionsConfig` |
| Git pull types | `GitPullResponse` |
| Sub-repo types | `SubRepoInfo` |

---

## Testing Strategy

### Unit Tests
- All existing tests should pass with typealiases
- Add tests for generated type decoding
- Test edge cases in discriminated unions

### Integration Tests
- Test WebSocket message round-trip
- Test REST API calls with generated types
- Test Live Activity registration flow

### Manual Testing
- Connect to cli-bridge and verify all message types work
- Test permission flow
- Test question flow
- Test file browsing
- Test push notifications

---

## Rollback Plan

If issues arise during migration:

1. **Keep `CLIBridgeTypes.swift` until Phase 6**
2. **Typealiases provide backward compatibility**
3. **Can revert individual phases independently**
4. **Git branches for each phase**

---

## Success Criteria

- [ ] Zero hand-written protocol types
- [ ] All 110+ types generated from OpenAPI
- [ ] Build succeeds with no type-related warnings
- [ ] All tests pass
- [ ] App functions correctly with cli-bridge
- [ ] `CLIBridgeTypes.swift` deleted
- [ ] Documentation updated
