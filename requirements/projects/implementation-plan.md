# claudecodeui Fork Implementation Plan

**Last Updated**: 2025-12-28
**Fork**: wiseyoda/claudecodeui
**Status**: Session API migration COMPLETE, follow-up items below

---

## Next Phase: Remaining Work

All session migration work is complete. These are the remaining items consolidated from all previous phases.

### Priority 1: Final Validation

| # | Task | Effort | Notes |
|---|------|--------|-------|
| 1 | Manual testing on device | 30 min | Test session loading, pagination, deletion, WebSocket updates |
| 2 | Deploy to TestFlight | 15 min | After validation |

### Priority 2: Documentation & Cleanup

| # | Task | Effort | Notes |
|---|------|--------|-------|
| 3 | Document Clean Architecture pattern | 30 min | Create `requirements/ARCHITECTURE.md` |
| 4 | Remove SessionManager wrapper | 30 min | Optional - works as migration path for now |

### Priority 3: Permission System Verification

| # | Task | Effort | Notes |
|---|------|--------|-------|
| 5 | Test permission flow end-to-end | 1 hour | Create session with `skipPermissions: false`, trigger tool, verify request/response |
| 6 | Audit `WebSocketManager.swift` permission handling | 30 min | Lines 1127-1138, verify `sendApproval()` format |
| 7 | Test with `skipPermissions: false` in production | 30 min | Verify full flow works |

**Files to review:**
- `WebSocketManager.swift:1127` - Permission request parsing
- `WebSocketManager.swift:sendApproval()` - Response sending
- `ChatView.swift` - Permission UI presentation
- `ApprovalSheetView.swift` - Approval UI component

### Priority 4: Token Budget Monitoring

| # | Task | Effort | Notes |
|---|------|--------|-------|
| 8 | Test existing token usage endpoint | 30 min | `GET /api/projects/:projectName/sessions/:sessionId/token-usage` |
| 9 | Implement token usage polling in iOS | 1 hour | Poll during active sessions |
| 10 | Evaluate PR #212 for SDK port | 2-3 hours | Only if real-time updates needed |

**Options:**
- **Option A**: Port PR #212 logic to claude-sdk.js (HIGH effort)
- **Option B**: Use existing token endpoint with polling (LOW effort) - **Recommended first**

### Priority 5: Backend Improvements (Lower Priority)

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 11 | Session type classification in API | 2-3 hours | Eliminates iOS filtering logic |
| 12 | Normalized content schema | 1-2 hours | Simplifies JSONL parsing |
| 13 | Streaming batching option | 1 hour | Reduces view updates |
| 14 | Cache headers for project list | 30 min | Faster startup |

### Priority 6: PRs to Evaluate

| PR | Title | Effort | Notes |
|----|-------|--------|-------|
| #212 | Token Monitoring | HIGH | Needs SDK rewrite for claude-sdk.js |
| #160 | Streaming Stability | MEDIUM | Check if still needed with current implementation |
| #238 | Sub-directory Deployment | LOW | For reverse proxy setups |
| #235 | i18n Support | MEDIUM | Large but foundational for localization |

---

## Testing Checklist

### Session API (Ready to Test)
- [ ] API returns all sessions (not just 5)
- [ ] Pagination works (Load More button)
- [ ] Summaries populated correctly
- [ ] Helper sessions excluded from display
- [ ] Agent sessions excluded from display
- [ ] Sort order correct (newest first)
- [ ] WebSocket push updates work
- [ ] Session deletion updates list

### Permission System (Needs Verification)
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

## Quick Reference

### Current Architecture
```
Views → SessionManager → SessionStore → SessionRepository → APIClient → Backend
           (wrapper)     (source of truth)   (testable)
```

### Key Files
| File | Purpose |
|------|---------|
| `SessionRepository.swift` | Protocol + API implementation + Mock |
| `SessionStore.swift` | Centralized state management, pagination |
| `SessionManager.swift` | Thin wrapper (migration path) |
| `WebSocketManager.swift:1127-1141` | sessions-updated event handler |

### Backend Endpoints
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/projects` | GET | All projects with up to 1000 sessions each |
| `/api/projects/:name/sessions?limit=100&offset=0` | GET | Paginated sessions |
| `/api/projects/:name/sessions/:id/messages` | GET | Session messages |

### WebSocket Events
| Event | Direction | Purpose |
|-------|-----------|---------|
| `sessions-updated` | Backend → iOS | Session created/updated/deleted |
| `permission-request` | Backend → iOS | Tool approval request |

---

## References

- `claudecodeui-fork-analysis.md` - PR analysis
- `claudecodeui-pr-assessment.md` - Detailed PR assessments
- `claudecodeui-upgrades.md` - Backend improvement wishlist
- Fork: https://github.com/wiseyoda/claudecodeui
- Upstream: https://github.com/siteboon/claudecodeui

---
---

# Completed Work (Historical Record)

## Session API Migration - COMPLETED 2025-12-28

### Backend Changes ✅

| Change | Status | Commit |
|--------|--------|--------|
| Session limit increased (50 → 1000) | ✅ Done | `1c23377` |
| WebSocket `sessions-updated` events | ✅ Already implemented | - |
| CORS headers (Authorization allowed) | ✅ Done | `1c23377` |
| Session metadata (hasMore, total) | ✅ Already implemented | - |
| Deployed to QNAP | ✅ Live at http://10.0.3.2:8080 | - |

### iOS Clean Architecture ✅

**New Files Created:**
- `SessionRepository.swift` - Protocol + API implementation + Mock for testing
- `SessionStore.swift` - Centralized state management with pagination
- `SessionStoreTests.swift` - 12 unit tests (all passing)

**Files Modified:**
- `Models.swift` - Added `SessionsResponse`, `ProjectSessionMeta`, `filterForDisplay()`, `filterAndSortForDisplay()`
- `SessionManager.swift` - Converted to thin wrapper delegating to SessionStore
- `WebSocketManager.swift` - Already had `sessions-updated` handler at lines 1127-1141
- `SSHManager.swift` - SSH session code removed (comment at line 1980-1983)
- `SessionPickerViews.swift` - Added "Load More" button, updated comments
- `ChatView.swift` - Updated session handling, fixed outdated SSH comments

**Commit**: `ddedf9a feat: Migrate session management from SSH to API with Clean Architecture`

### Implementation Phases Completed

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | Backend Changes | ✅ Complete |
| 2 | iOS Clean Architecture Foundation | ✅ Complete |
| 3 | iOS SessionStore Refactor | ✅ Complete |
| 4 | WebSocket Integration | ✅ Complete |
| 5 | Remove SSH Session Code | ✅ Complete |
| 6 | View Integration | ✅ Complete |
| 7 | Testing | ✅ 12 unit tests passing |

### Key Features Implemented

1. **SessionRepository Protocol** - Abstraction layer for API calls
   - `fetchSessions(projectName:limit:offset:)` - Pagination support
   - `deleteSession(projectName:sessionId:)` - Session deletion
   - `MockSessionRepository` for testing

2. **SessionStore Singleton** - Single source of truth
   - `@Published` state for reactive UI updates
   - Pagination with `loadMore()`
   - Optimistic deletion with rollback
   - WebSocket event handler (`handleSessionsUpdated()`)
   - Active session tracking
   - Bulk operations (deleteAll, keepOnlyLastN)

3. **Model Extensions** - Smart session filtering
   - `filterForDisplay()` - Excludes helper/agent/empty sessions
   - `filterAndSortForDisplay()` - Filtered + sorted by activity
   - Always preserves active session in filtered results

4. **Pagination UI** - "Load More" button in SessionPickerViews

### Code Metrics

| Metric | Value |
|--------|-------|
| Files changed | 20 |
| Lines added | 2,234 |
| Lines removed | 639 |
| Net change | +1,595 |
| Unit tests added | 12 |

### PRs Already Merged in Fork

| PR | Feature |
|----|---------|
| #249 | Permission Dialog System |
| #259 | Hyphen Path Fix |
| #255 | originalPath Config Override |
| #271 | RTL Support |
| #244 | New Project Button Fix |
| #250 | Syntax Highlighting |
| #241 | Docker Deployment |

### Architecture Diagram

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

### Decisions Made

| Decision | Choice | Rationale |
|----------|--------|-----------|
| SSH Fallback | API-only, remove SSH | Cleaner code, commit to API |
| Session Limit | 1000 (no truncation) | Return all sessions |
| iOS Architecture | Repository + Store | Clean Architecture without UseCase overkill |
| Store Pattern | Singleton like BookmarkStore | Consistent with codebase |
| Refresh Flow | WebSocket push updates | Most correct, real-time |
| Pagination | Proper offset handling | Scales better |
