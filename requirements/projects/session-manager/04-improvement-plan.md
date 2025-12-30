# Session Management Improvement Plan

> Comprehensive plan to make session management idiot-proof, scalable, maintainable, simpler, and better

**Status:** Ready for Implementation
**Last Updated:** 2025-12-30
**Backend Status:** All P0/P1/P2 requirements complete (see `06-cli-bridge-response`)

---

## Executive Summary

Session management was fragmented across multiple components with inconsistent counts, unclear ownership, and poor visibility into agent-created sessions. The cli-bridge team has implemented all requested backend features. This document now focuses on the CodingBridge iOS implementation.

**Key Goals:**
1. **Accurate counts** - Use new count endpoint for precise session counts
2. **Clean separation** - Agent sessions correctly identified and filterable
3. **Robust pagination** - `total` and `hasMore` now work correctly
4. **Search capability** - New server-side search with snippets
5. **Soft delete** - Archive/unarchive instead of permanent delete
6. **Bulk operations** - Efficient multi-session management

---

## Part 1: CLI-Bridge Features - COMPLETE

> All features implemented by cli-bridge team. See `06-cli-bridge-response` for details.

### 1.1 Fixed Issues

| Issue | Status | Notes |
|-------|--------|-------|
| Session count mismatch (145 vs 101) | **FIXED** | Path resolution issue resolved |
| Pagination `total`/`hasMore` null | **FIXED** | Now returns accurate metadata |
| `agent-*` IDs with wrong source | **FIXED** | ID prefix now infers source correctly |

### 1.2 New Endpoints Available

| Endpoint | Purpose |
|----------|---------|
| `GET /projects/:path/sessions/count` | Lightweight count by source |
| `GET /projects/:path/sessions/search?q=...` | Full-text session search |
| `POST /projects/:path/sessions/:id/archive` | Soft delete |
| `POST /projects/:path/sessions/:id/unarchive` | Restore archived |
| `GET /projects/:path/sessions/:id/children` | Session lineage |
| `POST /projects/:path/sessions/bulk` | Bulk operations |

### 1.3 New Session Fields

```json
{
  "archivedAt": "2025-12-30T15:00:00Z",
  "parentSessionId": "parent-session-uuid"
}
```

### 1.4 New Query Parameters

| Parameter | Values | Default | Description |
|-----------|--------|---------|-------------|
| `includeArchived` | true/false | false | Include archived in list |
| `archivedOnly` | true/false | false | Only show archived |
| `parentSessionId` | uuid | - | Filter by parent session |

---

## Part 2: CodingBridge Implementation

### 2.1 New Types (CLIBridgeTypes.swift)

```swift
// Session count breakdown
struct CLISessionCountResponse: Decodable {
    let total: Int
    let user: Int?
    let agent: Int?
    let helper: Int?
}

// Session search result
struct CLISessionSearchMatch: Codable {
    let messageId: String
    let role: String
    let snippet: String
    let timestamp: String
}

struct CLISessionSearchResult: Codable, Identifiable {
    let sessionId: String
    let projectPath: String
    let score: Double
    let matches: [CLISessionSearchMatch]
    var id: String { sessionId }
}

struct CLISessionSearchResponse: Codable {
    let query: String
    let total: Int
    let results: [CLISessionSearchResult]
    let hasMore: Bool
}

// Bulk operations
struct CLIBulkOperationRequest: Encodable {
    let sessionIds: [String]
    let operation: Operation

    struct Operation: Encodable {
        let action: String  // "archive", "unarchive", "delete", "update"
        let customTitle: String?
    }
}

struct CLIBulkOperationResponse: Decodable {
    let success: [String]
    let failed: [Failure]

    struct Failure: Decodable {
        let sessionId: String
        let error: String
    }
}
```

### 2.2 CLISessionMetadata Updates

Add to existing struct:

```swift
// NEW fields (optional for backward compatibility)
let archivedAt: String?
let parentSessionId: String?

// NEW computed properties
var isArchived: Bool { archivedAt != nil }

var archivedDate: Date? {
    guard let archivedAt = archivedAt else { return nil }
    return Self.isoFormatter.date(from: archivedAt)
}
```

### 2.3 New API Methods (CLIBridgeAPIClient.swift)

```swift
// Count endpoint
func getSessionCount(
    projectPath: String,
    source: CLISessionMetadata.SessionSource? = nil
) async throws -> CLISessionCountResponse

// Search endpoint
func searchSessions(
    projectPath: String,
    query: String,
    limit: Int = 20,
    offset: Int = 0
) async throws -> CLISessionSearchResponse

// Archive/unarchive
func archiveSession(projectPath: String, sessionId: String) async throws -> CLISessionMetadata
func unarchiveSession(projectPath: String, sessionId: String) async throws -> CLISessionMetadata

// Children (lineage)
func getSessionChildren(
    projectPath: String,
    sessionId: String,
    limit: Int = 50,
    offset: Int = 0
) async throws -> CLISessionsResponse

// Bulk operations
func bulkSessionOperation(
    projectPath: String,
    sessionIds: [String],
    action: String,
    customTitle: String? = nil
) async throws -> CLIBulkOperationResponse
```

### 2.4 Updated fetchSessions()

```swift
func fetchSessions(
    projectPath: String,
    limit: Int = 100,
    cursor: String? = nil,
    source: CLISessionMetadata.SessionSource? = nil,
    includeArchived: Bool = false,    // NEW
    archivedOnly: Bool = false,       // NEW
    parentSessionId: String? = nil    // NEW
) async throws -> CLISessionsResponse
```

### 2.5 Repository Layer (SessionRepository.swift)

Extend protocol with new methods:

```swift
protocol SessionRepository {
    // Existing
    func fetchSessions(projectName: String, limit: Int, offset: Int) async throws -> SessionsResponse
    func deleteSession(projectName: String, sessionId: String) async throws

    // NEW
    func getSessionCount(projectName: String, source: CLISessionMetadata.SessionSource?) async throws -> CLISessionCountResponse
    func searchSessions(projectName: String, query: String, limit: Int, offset: Int) async throws -> CLISessionSearchResponse
    func archiveSession(projectName: String, sessionId: String) async throws -> CLISessionMetadata
    func unarchiveSession(projectName: String, sessionId: String) async throws -> CLISessionMetadata
    func bulkOperation(projectName: String, sessionIds: [String], action: String, customTitle: String?) async throws -> CLIBulkOperationResponse
}
```

### 2.6 SessionStore Updates

New state:

```swift
@Published private(set) var countsByProject: [String: CLISessionCountResponse] = [:]
@Published private(set) var searchResults: [String: CLISessionSearchResponse] = [:]
@Published private(set) var isSearching: [String: Bool] = [:]
@Published var showArchivedSessions: Bool = false
```

New methods:

```swift
// Counts
func loadSessionCounts(for projectPath: String) async
func userSessionCount(for projectPath: String) -> Int

// Search
func searchSessions(for projectPath: String, query: String) async
func clearSearch(for projectPath: String)

// Archive
func archiveSession(_ session: ProjectSession, for projectPath: String) async -> Bool
func unarchiveSession(_ session: ProjectSession, for projectPath: String) async -> Bool

// Bulk operations
func bulkArchive(sessionIds: [String], for projectPath: String) async -> (success: Int, failed: Int)
func bulkDelete(sessionIds: [String], for projectPath: String) async -> (success: Int, failed: Int)
```

### 2.7 UI Updates (SessionPickerViews.swift)

#### Search Bar
- TextField with debounced input (300ms)
- Shows search results with snippets when query is non-empty
- Tap result navigates to session

#### Archive Toggle
- Toolbar button: "Show Archived"
- Fetches with `archivedOnly=true` when enabled
- Archived sessions styled differently (dimmed, archive icon)

#### Swipe Actions
```swift
.swipeActions(edge: .leading) {
    Button { archiveSession(session) }
        label: { Label("Archive", systemImage: "archivebox") }
        .tint(.orange)
}
.swipeActions(edge: .trailing) {
    Button(role: .destructive) { deleteSession(session) }
        label: { Label("Delete", systemImage: "trash") }
}
```

#### Bulk Selection (P2)
- Edit mode enables multi-select
- Bulk action toolbar with archive/delete buttons

---

## Implementation Phases

### Phase 1: Types & API Layer

**Files:** `CLIBridgeTypes.swift`, `CLIBridgeAPIClient.swift`

- [ ] Add `CLISessionCountResponse` type
- [ ] Add `CLISessionSearchMatch`, `CLISessionSearchResult`, `CLISessionSearchResponse` types
- [ ] Add `CLIBulkOperationRequest`, `CLIBulkOperationResponse` types
- [ ] Update `CLISessionMetadata` with `archivedAt`, `parentSessionId`
- [ ] Add `getSessionCount()` method
- [ ] Add `searchSessions()` method
- [ ] Add `archiveSession()` method
- [ ] Add `unarchiveSession()` method
- [ ] Add `getSessionChildren()` method
- [ ] Add `bulkSessionOperation()` method
- [ ] Update `fetchSessions()` with new query parameters

### Phase 2: Repository Layer

**Files:** `SessionRepository.swift`

- [ ] Extend `SessionRepository` protocol with new methods
- [ ] Implement new methods in `CLIBridgeSessionRepository`
- [ ] Update `MockSessionRepository` for testing

### Phase 3: Store Layer

**Files:** `SessionStore.swift`

- [ ] Add new published state (counts, search results, etc.)
- [ ] Implement `loadSessionCounts(for:)`
- [ ] Implement `searchSessions(for:query:)`
- [ ] Implement `archiveSession(_:for:)` with optimistic update
- [ ] Implement `unarchiveSession(_:for:)`
- [ ] Implement `bulkArchive(sessionIds:for:)`
- [ ] Implement `bulkDelete(sessionIds:for:)`

### Phase 4: UI Layer

**Files:** `SessionPickerViews.swift`

- [ ] Add search bar with debounced input
- [ ] Add search results display with snippets
- [ ] Add "Show Archived" toggle in toolbar
- [ ] Add archive swipe action (left swipe)
- [ ] Update delete swipe action (right swipe)
- [ ] Style archived sessions differently
- [ ] Add bulk selection mode (P2)

### Phase 5: Testing & Verification

- [ ] Unit tests for new types (decoding)
- [ ] Build and run on simulator
- [ ] Test search functionality
- [ ] Test archive/unarchive roundtrip
- [ ] Test pagination with new params
- [ ] Verify counts match between endpoints

---

## File Changes Summary

### Modified Files

| File | Changes |
|------|---------|
| `CLIBridgeTypes.swift` | New response types, update CLISessionMetadata |
| `CLIBridgeAPIClient.swift` | 6 new methods, update fetchSessions |
| `SessionRepository.swift` | 5 new protocol methods, implementations |
| `SessionStore.swift` | New state, 7 new methods |
| `SessionPickerViews.swift` | Search bar, archive toggle, swipe actions |

### No New Files Required

We're extending existing architecture rather than creating new abstractions. This keeps the change set minimal and reduces risk.

---

## Success Metrics

| Metric | Before | After |
|--------|--------|-------|
| Count accuracy | ~70% (101/145) | 100% (counts match) |
| Agent session filtering | Mixed in list | Correctly identified, separate |
| Search capability | None | Full-text with snippets |
| Delete options | Permanent only | Archive + permanent delete |
| Bulk operations | Limited | Archive/delete multiple |

---

## Testing Checklist

```swift
// Type decoding tests
func testCLISessionCountResponseDecoding()
func testCLISessionSearchResponseDecoding()
func testCLIBulkOperationResponseDecoding()
func testCLISessionMetadataWithArchivedAt()

// API integration tests
func testGetSessionCountReturnsBreakdown()
func testSearchSessionsReturnsSnippets()
func testArchiveUnarchiveRoundtrip()
func testBulkArchivePartialFailure()

// Store tests
func testArchiveRemovesFromList()
func testUnarchiveAddsToList()
func testSearchResultsCleared()
```

---

## Backward Compatibility

All changes are backward compatible:

1. **New types** - Added, don't affect existing code
2. **New CLISessionMetadata fields** - Optional, nil if not present
3. **New API methods** - Added, existing methods unchanged
4. **Updated fetchSessions()** - New params have defaults
5. **New SessionStore state** - Added, existing state unchanged
6. **UI** - Additive changes, existing functionality preserved

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Backend API changes | Low | cli-bridge team confirmed stable API |
| Type decoding failures | Medium | Defensive optional handling |
| UI performance (search) | Low | Debounce + pagination |
| Optimistic update failures | Low | Rollback on error |

---

## Related Documents

| Document | Purpose |
|----------|---------|
| `01-cli-bridge-analysis.md` | Backend session system analysis |
| `02-codingbridge-current-state.md` | iOS app current implementation |
| `03-api-test-results.md` | API endpoint test results |
| `05-cli-bridge-feature-request.md` | Original feature request |
| `06-cli-bridge-response` | Backend team's implementation response |
