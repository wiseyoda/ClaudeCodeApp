# Session Manager Requirements

> Comprehensive analysis and improvement plan for session management in CodingBridge

**Status:** Implementation Ready
**Last Updated:** 2025-12-30

## Overview

This project addresses session management issues discovered in CodingBridge:
- Session count discrepancy (145 shown vs 101 returned)
- Missing pagination metadata
- Agent sessions polluting user session list
- No search capability
- Permanent delete only (no archive)

**All backend features have been implemented by the cli-bridge team.** We are now implementing the iOS frontend changes.

## Documents

| Document | Description | Status |
|----------|-------------|--------|
| [01-cli-bridge-analysis.md](./01-cli-bridge-analysis.md) | Backend session system analysis | Complete |
| [02-codingbridge-current-state.md](./02-codingbridge-current-state.md) | iOS app current implementation | Complete |
| [03-api-test-results.md](./03-api-test-results.md) | API endpoint test results | Complete |
| [04-improvement-plan.md](./04-improvement-plan.md) | **Implementation plan** | Ready |
| [05-cli-bridge-feature-request.md](./05-cli-bridge-feature-request.md) | Handoff document for cli-bridge team | Delivered |
| [06-cli-bridge-response](./06-cli-bridge-response) | Backend team's implementation response | Complete |

## Backend Status: COMPLETE

All 9 requirements implemented by cli-bridge team:

### P0 (Must Have)
- [x] R1: Session count consistency - FIXED
- [x] R2: Pagination `total`/`hasMore` - FIXED
- [x] R3: Source field semantics - DOCUMENTED

### P1 (Should Have)
- [x] R4: Session search endpoint - NEW
- [x] R5: Session count endpoint - NEW
- [x] R6: User-initiated filter - FIXED

### P2 (Nice to Have)
- [x] R7: Session archive (soft delete) - NEW
- [x] R8: Session lineage (`parentSessionId`) - NEW
- [x] R9: Bulk operations - NEW

## iOS Implementation Status: IN PROGRESS

### Files to Modify

| File | Status | Changes |
|------|--------|---------|
| `CLIBridgeTypes.swift` | Pending | New response types, CLISessionMetadata updates |
| `CLIBridgeAPIClient.swift` | Pending | 6 new API methods |
| `SessionRepository.swift` | Pending | 5 new protocol methods |
| `SessionStore.swift` | Pending | New state, 7 new methods |
| `SessionPickerViews.swift` | Pending | Search bar, archive toggle, swipe actions |

### Implementation Phases

1. **Phase 1: Types & API** - Add new types and API methods
2. **Phase 2: Repository** - Extend protocol, implement methods
3. **Phase 3: Store** - Add state, implement operations
4. **Phase 4: UI** - Search, archive, swipe actions
5. **Phase 5: Testing** - Verify all features work

## New API Endpoints

| Endpoint | Purpose |
|----------|---------|
| `GET /projects/:path/sessions/count` | Session count by source |
| `GET /projects/:path/sessions/search?q=...` | Full-text search |
| `POST /projects/:path/sessions/:id/archive` | Soft delete |
| `POST /projects/:path/sessions/:id/unarchive` | Restore |
| `GET /projects/:path/sessions/:id/children` | Session lineage |
| `POST /projects/:path/sessions/bulk` | Bulk operations |

## Architecture

```
Current Flow:
┌─────────────────────────────────────────────────┐
│  Views (ProjectRow, SessionPicker, ChatView)    │
│         ↓               ↓              ↓        │
│  SessionStore    MessageStore   SessionNames    │
│         ↓                                       │
│  SessionRepository → CLIBridgeAPIClient         │
└─────────────────────────────────────────────────┘

After Implementation:
┌─────────────────────────────────────────────────┐
│  Views (with search bar, archive toggle)        │
│                      ↓                          │
│              SessionStore                       │
│    (+ counts, search results, archive ops)      │
│                      ↓                          │
│  SessionRepository → CLIBridgeAPIClient         │
│  (+ 5 new methods)   (+ 6 new methods)          │
└─────────────────────────────────────────────────┘
```

## Key Findings (Original Analysis)

### Session Count Discrepancy (RESOLVED)
- Project list showed **145** sessions
- Sessions API returned **101** sessions
- **Root cause:** Path resolution mismatch (fixed by cli-bridge team)

### Session Distribution
| Source | Count | % |
|--------|-------|---|
| agent | 96 | 95% |
| user | 5 | 5% |
| helper | 0 | 0% |

Agent sessions now correctly identified via ID prefix heuristic.

## Success Metrics

| Metric | Before | After |
|--------|--------|-------|
| Count accuracy | ~70% | 100% |
| Agent filtering | Mixed | Correct |
| Search | None | Full-text |
| Delete options | Permanent | Archive + Delete |
| Bulk ops | Limited | Full support |
