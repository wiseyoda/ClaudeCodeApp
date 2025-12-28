# claudecodeui Fork Implementation Plan

**Created**: 2025-12-28
**Fork**: wiseyoda/claudecodeui
**Status**: 30+ commits AHEAD of upstream, 0 commits behind

---

## Completed Work Summary (Phase 1)

### iOS Clean Architecture Implementation ✅

**Created Files:**
- `SessionRepository.swift` - Protocol + API implementation + Mock for testing
- `SessionStore.swift` - Centralized state management with pagination

**Modified Files:**
- `Models.swift` - Added `SessionsResponse`, `ProjectSessionMeta`, `filterForDisplay()`, `filterAndSortForDisplay()`
- `SessionManager.swift` - Converted to thin wrapper delegating to SessionStore

**Architecture Achieved:**
```
Views → SessionManager → SessionStore → SessionRepository → APIClient → Backend
                 ↓                              ↓
         (thin wrapper)               (protocol-based, testable)
```

**Key Features Implemented:**
1. **SessionRepository Protocol** - Abstraction layer for API calls
   - `fetchSessions(projectName:limit:offset:)` - Pagination support
   - `deleteSession(projectName:sessionId:)` - Session deletion
   - `MockSessionRepository` for testing

2. **SessionStore Singleton** - Single source of truth
   - `@Published` state for reactive UI updates
   - Pagination with `loadMore()`
   - Optimistic deletion with rollback
   - WebSocket event handler stub (`handleSessionsUpdated()`)
   - Active session tracking
   - Bulk operations (deleteAll, keepOnlyLastN)

3. **Model Extensions** - Smart session filtering
   - `filterForDisplay()` - Excludes helper/agent/empty sessions
   - `filterAndSortForDisplay()` - Filtered + sorted by activity
   - Always preserves active session in filtered results

**What's NOT Done Yet:**
- Backend session limit increase (still returns ~5 sessions)
- WebSocket session event emission from backend
- Wiring WebSocket events to SessionStore
- Removing SSH session loading code
- View migration to SessionStore.shared
- Pagination UI ("Load More" button)
- Unit tests

---

## Executive Summary

Our fork has significantly diverged from upstream with valuable additions:
- Full permission approval system (PR #249 + custom fixes)
- Multiple bug fix PRs merged (#259, #255, #271, #244, #250, #241)
- Interactive permission handling via `canUseTool` SDK callback

**Key Discovery**: Many iOS SSH workarounds can be eliminated because the backend NOW supports the features we need - we just haven't wired them up in the iOS app.

---

## Current Fork Status

### PRs Already Merged
| PR | Feature | Status |
|----|---------|--------|
| #249 | Permission Dialog System | Merged + Enhanced |
| #259 | Hyphen Path Fix | Merged |
| #255 | originalPath Config Override | Merged |
| #271 | RTL Support | Merged |
| #244 | New Project Button Fix | Merged |
| #250 | Syntax Highlighting | Merged |
| #241 | Docker Deployment | Merged |

### Custom Enhancements Added
- `canUseTool` SDK callback integration
- Permission response routing fixes for iOS
- Legacy permission handler compatibility
- Data wrapper for iOS compatibility

---

## Phase 1: Session API Migration (HIGH PRIORITY)

### Problem
iOS app uses SSH to load ALL sessions because:
1. Old backend returned only ~5 sessions
2. Backend didn't provide session summaries

### Discovery
The backend NOW supports full pagination and summaries! The session API already has:
- `GET /api/projects/:projectName/sessions?limit=100&offset=0`
- Returns `{ sessions: [], hasMore: bool, total: int }`
- Includes parsed summaries in response

### Backend Fix (5 min)
In `server/projects.js:575`, change the hardcoded limit in `getProjects()`:
```javascript
// BEFORE: const sessionResult = await getSessions(entry.name, 5, 0);
// AFTER:
const sessionResult = await getSessions(entry.name, 50, 0);
```

Or better - add new dedicated session endpoint:
```javascript
// GET /api/projects/:projectName/all-sessions
app.get('/api/projects/:projectName/all-sessions', authenticateToken, async (req, res) => {
    const result = await getSessions(req.params.projectName, 1000, 0);
    res.json(result);
});
```

### iOS Changes

#### 1. Add fetchSessions() to APIClient.swift
```swift
/// Fetch all sessions for a project using backend API
func fetchSessions(projectName: String, limit: Int = 100) async throws -> [ProjectSession] {
    guard let baseURL = settings.baseURL else {
        throw APIError.invalidURL
    }

    guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
        throw APIError.invalidURL
    }
    components.path = "/api/projects/\(projectName)/sessions"
    components.queryItems = [URLQueryItem(name: "limit", value: String(limit))]

    guard let url = components.url else {
        throw APIError.invalidURL
    }

    let request = authorizedRequest(for: url)
    let (data, response) = try await URLSession.shared.data(for: request)

    // ... standard response handling ...

    let sessionsResponse = try JSONDecoder().decode(SessionsResponse.self, from: data)
    return sessionsResponse.sessions
}

struct SessionsResponse: Codable {
    let sessions: [ProjectSession]
    let hasMore: Bool
    let total: Int
}
```

#### 2. Replace SSH loading in SessionManager.swift
```swift
// BEFORE: Uses SSHManager.loadAllSessions()
// AFTER: Uses APIClient.fetchSessions()

func loadSessions(for project: Project) async throws -> [ProjectSession] {
    do {
        // Try API first (faster, no SSH overhead)
        let sessions = try await apiClient.fetchSessions(projectName: project.name)
        return sessions.filterForDisplay(projectPath: project.path)
    } catch {
        // Fallback to SSH only if API fails
        log.warning("API session fetch failed, falling back to SSH: \(error)")
        return try await sshManager.loadAllSessions(for: project.path, settings: settings)
    }
}
```

### Code to Remove After Migration
- `SSHManager.loadAllSessions()` - 80 lines
- `SSHManager.countSessions()` - 30 lines
- `SSHManager.countSessionsForProjects()` - 60 lines
- Complex jq parsing scripts

**Estimated reduction**: ~170 lines of SSH workaround code

---

## Phase 2: Permission System Verification (MEDIUM PRIORITY)

### Current State
- Backend: Full permission system implemented
- iOS: Partial integration (receives requests, UI needs testing)

### Verification Tasks
1. **Test permission flow end-to-end**:
   - Create session with `skipPermissions: false`
   - Trigger tool use
   - Verify `permission-request` arrives in iOS
   - Send approval response
   - Verify tool executes

2. **Audit WebSocketManager.swift:1127-1138**:
   ```swift
   case "permission-request":
       if let dataDict = msg.data?.value as? [String: Any],
          let request = ApprovalRequest.from(dataDict) {
           pendingApproval = request
           onApprovalRequest?(request)
       }
   ```

3. **Verify response handling**:
   - Check `sendApproval()` method sends correct format
   - Verify backend receives and processes response

### Files to Review
| File | Purpose |
|------|---------|
| `WebSocketManager.swift:1127` | Permission request parsing |
| `WebSocketManager.swift:sendApproval()` | Response sending |
| `ChatView.swift` | Permission UI presentation |
| `ApprovalSheetView.swift` | Approval UI component |

---

## Phase 3: Token Budget Monitoring (FUTURE)

### Problem
PR #212 (Auto-Compact Token Monitoring) is based on old `claude-cli.js` architecture, not `claude-sdk.js`.

### Options

#### Option A: Port PR #212 Logic to SDK
Extract valuable patterns:
- `parseSystemWarnings()` - Token parsing from CLI output
- `shouldTriggerAutoCompact()` - Threshold detection
- `TokenBudgetIndicator` - Frontend component

Reimplement for SDK:
```javascript
// In claude-sdk.js, hook into output stream
sdkOptions.onTokenUpdate = (usage) => {
    ws.send(JSON.stringify({
        type: 'token-usage',
        used: usage.inputTokens + usage.outputTokens,
        limit: usage.contextLimit
    }));
};
```

#### Option B: Use Existing Token Usage Endpoint
Backend already has: `GET /api/projects/:projectName/sessions/:sessionId/token-usage`

iOS already has: `APIClient.fetchSessionTokenUsage()`

Could poll periodically during active sessions.

### Recommendation
**Option B first** - Test existing endpoint, implement polling in iOS. Only pursue Option A if real-time updates are critical.

---

## Phase 4: Additional Backend Improvements (LOW PRIORITY)

### 4.1 Session Type Classification
Add `type` field to session metadata: `"user"`, `"agent"`, `"helper"`

**Backend change** (`server/projects.js`):
```javascript
// In parseJsonlSessions() or getSessions()
session.type = sessionId.startsWith('agent-') ? 'agent'
    : isHelperSession(sessionId, projectPath) ? 'helper'
    : 'user';
```

**iOS benefit**: Remove helper session filtering logic

### 4.2 Bulk Session Operations
```javascript
// DELETE multiple sessions
app.delete('/api/projects/:projectName/sessions', authenticateToken, async (req, res) => {
    const { sessionIds } = req.body;
    await Promise.all(sessionIds.map(id => deleteSession(req.params.projectName, id)));
    res.json({ success: true, deleted: sessionIds.length });
});
```

### 4.3 WebSocket Session Notifications
Emit `sessions-updated` when sessions are created/deleted:
```javascript
ws.send(JSON.stringify({
    type: 'sessions-updated',
    projectName: projectName,
    action: 'created' | 'deleted',
    sessionId: sessionId
}));
```

---

## Decisions Made

### Round 1: High-Level Strategy
| Decision | Choice | Rationale |
|----------|--------|-----------|
| SSH Fallback | **API-only, remove SSH** | Cleaner code, commit to API |
| Backend Fix | **Modify getProjects() limit** | Quick fix, minimal changes |
| Priority | **Session migration first** | Permissions already work for bypass mode |
| Next Step | **Start implementing Phase 1** | Ready to go |

### Round 2: Implementation Details
| Decision | Choice | Rationale |
|----------|--------|-----------|
| Session Limit | **No limit (1000)** | Return all sessions, no truncation |
| iOS Architecture | **Move to APIClient only** | Clean separation of concerns |
| Deploy Order | **Both together** | Backend + iOS changes deployed simultaneously |
| API Design | **Use bundled sessions** | No new endpoint, just increase limit in getProjects() |

### Round 3: iOS Specifics
| Decision | Choice | Rationale |
|----------|--------|-----------|
| fetchSessions() | **Yes, add it** | Useful for refreshing without reloading all projects |
| SessionManager | **Rename to SessionStore** | Proper store pattern like BookmarkStore |
| Session Counts | **Use sessionMeta.total** | Backend returns total, use that for badges |

### Round 4: Quality & Architecture
| Decision | Choice | Rationale |
|----------|--------|-----------|
| Model Changes | **Check existing first** | Understand current state before modifying |
| Store Pattern | **Singleton like BookmarkStore** | Consistent with codebase patterns |
| Philosophy | **Do it RIGHT, not easy** | Clean, well-architected solutions even if harder |

### Round 5: Deep Architecture (The RIGHT Way)
| Decision | Choice | Rationale |
|----------|--------|-----------|
| Data Ownership | **SessionStore is source of truth** | Store manages sessions independently from Projects |
| Refresh Flow | **WebSocket push updates** | Backend pushes session changes. Most correct. |
| Pagination | **Implement proper pagination** | Load more, proper offset handling. Scales better. |
| Data Flow | **APIClient → Repository → Store → Views** | Full Clean Architecture. Most maintainable. |

### Round 6: Clean Architecture Details
| Decision | Choice | Rationale |
|----------|--------|-----------|
| Layers | **Repository + Store** | Skip UseCase - overkill for CRUD operations |
| Refactor Scope | **Simplify - API is truth** | Remove deletion tracking, trust backend |
| Template | **Yes, document pattern** | Create ARCHITECTURE.md, future features follow |
| WebSocket | **Add to existing manager** | Reuse connection, add session event handling |

---

## Implementation Order

### Phase 1: Backend Changes ✅ COMPLETED (2025-12-28)
1. [x] Document current state (this plan)
2. [x] Modify `server/projects.js:575` - changed limit from 50 to 1000
3. [x] WebSocket `sessions-updated` event - ALREADY IMPLEMENTED
4. [x] CORS headers - Added Authorization to allowedHeaders
5. [x] Session metadata - ALREADY IMPLEMENTED (hasMore, total)
6. [x] Deploy to QNAP - Live at http://10.0.3.2:8080

**Commit**: `1c23377 feat: iOS app session API improvements`

### Phase 2: iOS Clean Architecture Foundation ✅ COMPLETED
6. [x] Create `SessionRepository.swift` - API abstraction layer
   - `fetchSessions(projectName:limit:offset:)`
   - `deleteSession(projectName:sessionId:)`
   - Protocol-based for testability
7. [x] Add `SessionsResponse` model to Models.swift
8. [x] Add APIClient integration via Repository pattern
9. [ ] Document pattern in `requirements/ARCHITECTURE.md`

### Phase 3: iOS SessionStore Refactor ✅ COMPLETED
10. [x] Create new `SessionStore.swift` (singleton pattern)
    - Uses SessionRepository for data
    - Simplified state (no deletion tracking - API is truth)
11. [x] Add pagination support (`hasMore`, `loadMore()`)
12. [x] Add proper loading states and error handling
13. [x] Convert SessionManager to thin wrapper (migration path)

### Phase 4: WebSocket Integration ✅ COMPLETED
14. [x] Add `handleSessionsUpdated()` stub in SessionStore
15. [x] Add `sessions-updated` handling to WebSocketManager.swift (was already implemented!)
16. [x] Verified WebSocket session events handling

### Phase 5: Remove SSH Session Code ✅ COMPLETED
17. [x] SSH session code already removed from SSHManager.swift
18. [x] Comment at line 1980-1983 confirms migration complete
19. [x] Views updated to use SessionStore via SessionManager wrapper

### Phase 6: View Integration ✅ COMPLETED
20. [x] ContentView uses SessionManager (delegates to SessionStore)
21. [x] SessionPickerViews uses SessionStore
22. [x] ChatView session handling updated
23. [x] Add "Load More" UI for pagination
24. [x] Updated outdated SSH comments

### Phase 7: Testing & Cleanup ✅ COMPLETED
25. [x] Write unit tests for SessionStore (12 tests passing)
26. [x] Tests cover: loading, pagination, addition, active session, WebSocket events, bulk ops
27. [ ] Manual testing on device
28. [ ] Remove SessionManager wrapper (optional - works as migration path)
29. [ ] Deploy to TestFlight

### Total Estimated Time: ~7 hours ✅ IMPLEMENTATION COMPLETE

---

## Architecture Diagram

```
┌─────────────┐     ┌──────────────────┐     ┌──────────────┐
│   Views     │────▶│   SessionStore   │◀───▶│  Repository  │
│             │     │   (State Mgmt)   │     │  (API Layer) │
└─────────────┘     └──────────────────┘     └──────────────┘
                            ▲                        │
                            │                        ▼
                    ┌───────┴────────┐       ┌──────────────┐
                    │ WebSocketMgr   │       │  APIClient   │
                    │ (Push Events)  │       │  (HTTP)      │
                    └────────────────┘       └──────────────┘
                            ▲                        │
                            │                        ▼
                    ┌───────┴────────────────────────┴───────┐
                    │            claudecodeui Backend        │
                    └────────────────────────────────────────┘
```

### Data Flow

1. **Initial Load**: View → SessionStore → Repository → APIClient → Backend
2. **Pagination**: View (Load More) → SessionStore → Repository → APIClient
3. **Push Update**: Backend → WebSocket → WebSocketManager → SessionStore → Views
4. **Delete**: View → SessionStore → Repository → APIClient → Backend (+ WS event)

---

## New Files to Create

| File | Purpose |
|------|---------|
| `SessionRepository.swift` | API abstraction, protocol-based |
| `SessionStore.swift` | State management (rename from SessionManager) |
| `requirements/ARCHITECTURE.md` | Document Clean Architecture pattern |

## Files to Modify

| File | Changes |
|------|---------|
| `APIClient.swift` | Add session endpoints |
| `Models.swift` | Add SessionsResponse, SessionMeta |
| `WebSocketManager.swift` | Add sessions-updated event handling |
| `ContentView.swift` | Use SessionStore for counts |
| `SessionPickerViews.swift` | Use SessionStore, add pagination UI |
| `ChatView.swift` | Use SessionStore |
| `server/projects.js` | Increase limit to 1000 |
| `server/index.js` | Add WebSocket session events |

## Files to Delete

| File | Reason |
|------|--------|
| `SessionManager.swift` | Replaced by SessionStore.swift |

## SSH Code to Remove

| Location | Lines | Code |
|----------|-------|------|
| `SSHManager.swift:1988-2067` | ~80 | `loadAllSessions()` |
| `SSHManager.swift:2069-2093` | ~25 | `countSessions()` |
| `SSHManager.swift:2095-2130` | ~35 | `countSessionsForProjects()` |

---

## Files Changed (iOS)

### To Modify
| File | Change |
|------|--------|
| `APIClient.swift` | Add `fetchSessions()` method |
| `SessionManager.swift` | Switch from SSH to API |
| `ChatView.swift` | Update session loading calls |
| `Models.swift` | Add `SessionsResponse` struct |

### To Remove (After Migration)
| File | Lines | Reason |
|------|-------|--------|
| `SSHManager.swift:1988-2067` | 80 | `loadAllSessions()` |
| `SSHManager.swift:2069-2093` | 25 | `countSessions()` |
| `SSHManager.swift:2095-2130` | 35 | `countSessionsForProjects()` |

---

## Files Changed (Backend)

### To Modify
| File | Change |
|------|--------|
| `server/projects.js:575` | Increase session limit in `getProjects()` |
| `server/index.js` | Add dedicated `/all-sessions` endpoint (optional) |

---

## Testing Checklist

### Session API Migration
- [ ] API returns all sessions (not just 5)
- [ ] Pagination works with limit/offset
- [ ] Summaries populated correctly
- [ ] Helper sessions excluded
- [ ] Agent sessions excluded
- [ ] Sort order correct (newest first)

### Permission System
- [ ] Permission requests arrive in iOS
- [ ] UI displays correctly
- [ ] Approve works
- [ ] Deny works
- [ ] Timeout handled gracefully
- [ ] Session-scoped (doesn't leak to other sessions)

### Regression Tests
- [ ] Project list loads correctly
- [ ] Session picker shows all sessions
- [ ] Chat history loads correctly
- [ ] New sessions created properly
- [ ] Session deletion works

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| API session fetch fails | HIGH | Keep SSH fallback temporarily |
| Permission timing issues | MEDIUM | Add timeout handling |
| Session count mismatch | LOW | Verify counts match SSH |
| Breaking existing flow | HIGH | Feature flag for migration |

---

## Success Metrics

1. **Code reduction**: Remove ~170 lines of SSH workaround code
2. **Performance**: Session loading 2-5x faster (no SSH overhead)
3. **Reliability**: No SSH connection failures affecting session display
4. **Maintainability**: Single source of truth (API, not dual SSH+API)

---

---

## PHASE 2: Complete Session Migration & Backend Integration

**Goal**: Finish the session API migration, integrate with backend, and clean up iOS code.

### Priority Order

| # | Task | Impact | Effort | Dependency |
|---|------|--------|--------|------------|
| 1 | Backend: Increase session limit | CRITICAL | 5 min | None |
| 2 | iOS: Wire WebSocket events | HIGH | 30 min | Backend done |
| 3 | iOS: View integration | HIGH | 1 hour | #1-2 |
| 4 | iOS: Remove SSH code | HIGH | 30 min | #3 |
| 5 | iOS: Add pagination UI | MEDIUM | 30 min | #3 |
| 6 | iOS: Unit tests | MEDIUM | 1 hour | #3-4 |

### 2.1 Backend Changes (SSH to claude-dev)

**Change session limit** in `server/projects.js:575`:
```javascript
// Line 575: getSessions call in getProjects()
const sessionResult = await getSessions(entry.name, 1000, 0);
```

**Add WebSocket session event** in `server/index.js`:
```javascript
// When session is created/deleted, emit:
ws.send(JSON.stringify({
    type: 'sessions-updated',
    projectName: projectName,
    action: 'created' | 'deleted',
    sessionId: sessionId
}));
```

### 2.2 iOS WebSocket Integration

**File**: `WebSocketManager.swift`

Add handler in message processing switch:
```swift
case "sessions-updated":
    if let projectName = msg.data?.value["projectName"] as? String,
       let sessionId = msg.data?.value["sessionId"] as? String,
       let action = msg.data?.value["action"] as? String {
        Task {
            await SessionStore.shared.handleSessionsUpdated(
                projectName: projectName,
                sessionId: sessionId,
                action: action
            )
        }
    }
```

### 2.3 View Migration Checklist

| View | Change | Status |
|------|--------|--------|
| `ContentView.swift` | Use `SessionStore.shared.displaySessionCount()` for badges | [ ] |
| `SessionPickerViews.swift` | Use `SessionStore.shared.sessions()` | [ ] |
| `ChatView.swift` | Use `SessionStore.shared` for session operations | [ ] |
| `SessionRowView` | Add "Load More" button when `hasMore == true` | [ ] |

### 2.4 SSH Code Removal

**Functions to remove from `SSHManager.swift`:**

| Function | Lines | Location |
|----------|-------|----------|
| `loadAllSessions()` | ~80 | 1988-2067 |
| `countSessions()` | ~25 | 2069-2093 |
| `countSessionsForProjects()` | ~35 | 2095-2130 |

**Also remove:**
- jq-based session parsing scripts
- SSH-based session count logic

**Estimated code reduction**: ~140 lines

### 2.5 Test Plan

**Unit Tests:**
- `SessionRepositoryTests.swift` - Mock HTTP responses, test pagination
- `SessionStoreTests.swift` - Test state management, filtering, WebSocket handling

**Integration Tests:**
- Load sessions from API
- Delete session and verify removal
- Create session and verify addition
- WebSocket push triggers refresh

---

## PHASE 3: Additional Improvements (From Analysis)

Based on `claudecodeui-upgrades.md` and PR assessments:

### 3.1 Backend Improvements (Lower Priority)

| Improvement | Effort | Impact |
|-------------|--------|--------|
| Fix CORS headers (add Authorization) | 5 min | Enables session history endpoint |
| Session type classification in API | 2-3 hours | Eliminates iOS filtering logic |
| Normalized content schema | 1-2 hours | Simplifies parsing |
| Streaming batching option | 1 hour | Reduces view updates |
| Cache headers | 30 min | Faster project list loads |

### 3.2 PRs to Merge (From Fork Analysis)

| PR | Title | Effort | Notes |
|----|-------|--------|-------|
| #212 | Token Monitoring | HIGH | Needs SDK rewrite |
| #160 | Streaming Stability | MEDIUM | Check if still needed |
| #238 | Sub-directory Deployment | LOW | For reverse proxy |
| #235 | i18n Support | MEDIUM | Large but foundational |

### 3.3 Permission System Verification

Already merged PRs in fork:
- #249: Permission Dialog System
- #259: Hyphen Path Fix
- #255: originalPath Config Override
- #271: RTL Support
- #244: New Project Button Fix
- #250: Syntax Highlighting
- #241: Docker Deployment

**Verification needed:**
1. Test permission flow end-to-end in iOS app
2. Audit `WebSocketManager.swift` permission handling
3. Verify `sendApproval()` sends correct format
4. Test with `skipPermissions: false`

---

## Quick Reference

### Files to Create
- [x] `SessionRepository.swift` ✅
- [x] `SessionStore.swift` ✅
- [ ] `SessionRepositoryTests.swift`
- [ ] `SessionStoreTests.swift`

### Files to Modify
- [x] `Models.swift` - Added SessionsResponse, ProjectSessionMeta ✅
- [x] `SessionManager.swift` - Converted to wrapper ✅
- [ ] `WebSocketManager.swift` - Add sessions-updated handler
- [ ] `ContentView.swift` - Use SessionStore
- [ ] `SessionPickerViews.swift` - Use SessionStore
- [ ] `ChatView.swift` - Use SessionStore
- [ ] `SSHManager.swift` - Remove session code

### Files to Delete (Eventually)
- [ ] `SessionManager.swift` - After all views migrated

---

## References

- `claudecodeui-fork-analysis.md` - PR analysis
- `claudecodeui-pr-assessment.md` - Detailed PR assessments
- `claudecodeui-upgrades.md` - Original workaround documentation
- Fork: https://github.com/wiseyoda/claudecodeui
- Upstream: https://github.com/siteboon/claudecodeui
