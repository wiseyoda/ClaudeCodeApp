# claudecodeui Fork Implementation Plan

**Last Updated**: 2025-12-28
**Fork**: wiseyoda/claudecodeui
**Status**: Core implementation complete, iOS integration remaining

---

## Outstanding Work

### Priority 1: iOS Client Updates (Leverage New Backend Features)

These iOS updates will simplify the codebase by using the new backend capabilities.

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1 | Use `sessionType` API field instead of local filtering | 1 hour | Remove `ClaudeHelper.createHelperSessionId()` iOS logic |
| 2 | Use `textContent` field for message rendering | 30 min | Simplify `SessionMessage` decoding |
| 3 | Enable `?batch=<ms>` WebSocket parameter | 30 min | Reduce view updates during streaming |
| 4 | Retest "Always Allow" permission after fix | 15 min | Verify Issue #24 fix works |

**Files to Update:**
- `Models.swift` - Use `sessionType` from API response
- `SessionStore.swift` - Simplify `filterForDisplay()` to trust backend
- `ChatView.swift` - Enable batching parameter in WebSocket connection
- `APIClient.swift` - Use `textContent` field when available

---

### Priority 2: Remaining Backend Improvements

From `claudecodeui-upgrades.md` - items not yet addressed:

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 5 | Session ID known before first message | Medium | Cleaner session creation flow |
| 6 | Bulk session operations API | Low | Delete multiple sessions at once |
| 7 | JWT Token Refresh endpoint | Medium | Avoid re-login on token expiry |

**Lower Priority (Nice to Have):**

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 8 | Image upload accepts base64 in JSON body | Low | Simpler client code |

---

### Priority 3: PR Evaluation

| PR | Title | Status | Notes |
|----|-------|--------|-------|
| #257 | Fix Broken Pasted Image Upload | Review | FormData Content-Type fix - check if already fixed |

---

### Priority 4: Testing Checklists

Complete these verification steps:

**Session API:**
- [ ] API returns all sessions (not just 5)
- [ ] Pagination works (Load More button)
- [ ] Summaries populated correctly
- [x] Helper sessions excluded from display
- [x] Agent sessions excluded from display
- [x] Sort order correct (newest first)
- [ ] WebSocket push updates work
- [x] Session deletion updates list

**Permission System:**
- [x] Permission requests arrive in iOS
- [x] UI displays correctly
- [x] Approve works
- [x] Deny works
- [x] Timeout handled gracefully
- [x] "Always Allow" remembers decision

---

## Quick Reference

### Architecture
```
Views → SessionStore → SessionRepository → APIClient → Backend
         (state)       (testable)          (HTTP)
```

### Key Files
| File | Purpose |
|------|---------|
| `SessionRepository.swift` | Protocol + API implementation + Mock |
| `SessionStore.swift` | Centralized state management, pagination |
| `WebSocketManager.swift:1127-1141` | sessions-updated event handler |

### Backend Endpoints
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/projects` | GET | All projects (cached 30s) |
| `/api/projects/:name/sessions?limit=100&offset=0&type=display` | GET | Paginated sessions |
| `/api/projects/:name/sessions/:id/messages` | GET | Session messages |

### WebSocket Events
| Event | Direction | Purpose |
|-------|-----------|---------|
| `sessions-updated` | Backend → iOS | Session created/updated/deleted |
| `permission-request` | Backend → iOS | Tool approval request |

---

## References

- Fork: https://github.com/wiseyoda/claudecodeui
- Upstream: https://github.com/siteboon/claudecodeui
