# CLI-Bridge Session Management Feature Request

> Feature request for the cli-bridge team to improve session management APIs
>
> **Requester:** CodingBridge iOS Team
> **Date:** 2025-12-30
> **Priority:** High

---

## Executive Summary

CodingBridge is an iOS client for cli-bridge that provides mobile access to Claude Code sessions. We've identified several gaps in the current session management APIs that prevent us from delivering a reliable, scalable session management experience to users.

This document outlines our requirements for improved session management capabilities. We're describing **what we need** and **why**, leaving implementation decisions to the cli-bridge team.

---

## Background

### Current Usage

CodingBridge uses the following cli-bridge endpoints for session management:

- `GET /projects` - List projects with session counts
- `GET /projects/:path/sessions` - List sessions for a project
- `GET /projects/:path/sessions/:id` - Get single session
- `PUT /projects/:path/sessions/:id` - Update session (rename)
- `DELETE /projects/:path/sessions/:id` - Delete session
- `DELETE /projects/:path/sessions?filter=older_than` - Bulk delete
- `GET /sessions/recent` - Recent sessions across projects
- `GET /projects/:path/sessions/:id/export` - Export session

### User Base

- iOS users managing Claude Code sessions remotely
- Users with 50-200+ sessions per project
- Users who frequently use subagents (Task tool)
- Users who need to find specific conversations quickly

---

## Problem Statements

### Problem 1: Session Count Inconsistency

**What we're seeing:**

When we call `GET /projects`, the `sessionCount` field for ClaudeCodeApp shows **145**. However, when we call `GET /projects/-home-bridge-repos-ClaudeCodeApp/sessions?source=all&limit=500`, we receive only **101** sessions.

**Impact:**

- Users see "145 sessions" in the project list but only 101 sessions when they open the session manager
- This creates confusion and erodes trust in the app
- We cannot reliably display accurate session counts

**What we need:**

Session counts displayed in the project list should match the number of sessions returned by the sessions API when using equivalent filters.

**Acceptance Criteria:**

- `GET /projects` returns `sessionCount` that equals the count from `GET /projects/:path/sessions?source=all`
- Or, documentation explaining what `sessionCount` includes vs. what the sessions endpoint returns
- Consistency between the two numbers

---

### Problem 2: Missing Pagination Metadata

**What we're seeing:**

When we call `GET /projects/:path/sessions`, the response contains only the `sessions` array. The `total` and `hasMore` fields return `null`.

**Example response:**

```json
{
  "sessions": [...101 items...],
  "total": null,
  "hasMore": null
}
```

**Impact:**

- Cannot implement proper infinite scroll (don't know if more sessions exist)
- Cannot show "Showing X of Y sessions" to users
- Must fetch all sessions upfront to know the total count
- Poor performance for users with many sessions

**What we need:**

Accurate pagination metadata to implement efficient, user-friendly session lists.

**Acceptance Criteria:**

- `total` field returns the total number of sessions matching the filter
- `hasMore` field indicates whether additional sessions exist beyond the current page
- Pagination works correctly with `limit` and `offset` (or cursor-based pagination)

---

### Problem 3: Agent Session Visibility

**What we're seeing:**

Of our 101 sessions, **96 are agent-created** (from Task tool subagents) and only **5 are user-created**. User sessions are buried in a sea of agent sessions.

Additionally, some sessions have `agent-*` prefixed IDs but `source: "user"`:

```json
{
  "id": "agent-a53ac71",
  "source": "user",
  "messageCount": 107
}
```

**Impact:**

- Users struggle to find their own conversations
- The session list is dominated by short-lived agent sessions (most have only 2 messages)
- The relationship between `id` prefix and `source` field is unclear

**What we need:**

Better ability to distinguish and filter user-initiated sessions from agent-created sessions.

**Acceptance Criteria:**

- Clear documentation on what determines `source` value
- Explanation of when `agent-*` prefixed IDs have `source: "user"`
- Reliable way to filter for "sessions the user explicitly started" vs "sessions created programmatically"

**Nice to have:**

- Additional metadata indicating parent session (for subagent sessions)
- Session lineage/hierarchy information

---

### Problem 4: No Session Search Capability

**What we're seeing:**

Users with 100+ sessions cannot search for specific conversations. They must scroll through the entire list or remember session IDs.

**Impact:**

- Finding a specific conversation is time-consuming
- Users resort to creating new sessions instead of resuming relevant ones
- Valuable context from past sessions goes unused

**What we need:**

Ability to search sessions by content, title, or other metadata.

**Acceptance Criteria:**

- Ability to find sessions containing specific text
- Search should include session titles, user messages, and optionally assistant responses
- Results should be ranked by relevance or recency

---

### Problem 5: No Session Count Endpoint

**What we're seeing:**

To display session counts, we must either:

1. Use `sessionCount` from project list (which doesn't match reality)
2. Fetch all sessions and count them client-side

**Impact:**

- Displaying accurate counts requires fetching all session data
- Wasted bandwidth and processing for a simple count
- Slow initial load times

**What we need:**

Lightweight way to get session counts without fetching full session list.

**Acceptance Criteria:**

- Ability to get session count without full session metadata
- Support for count by source filter (user/agent/helper)
- Fast response time (<100ms)

---

### Problem 6: Permanent Deletion Only

**What we're seeing:**

When users delete sessions, they are permanently removed. There's no way to recover accidentally deleted sessions.

**Impact:**

- Users hesitant to clean up sessions (fear of losing important ones)
- No recovery from accidental deletion
- No way to "hide" sessions without destroying them

**What we need:**

Ability to soft-delete or archive sessions with potential for recovery.

**Acceptance Criteria:**

- Deleted sessions can be recovered within a reasonable timeframe
- Archived/soft-deleted sessions don't appear in normal session lists
- Clear distinction between "archive" and "permanent delete"

---

## Requirements Summary

### Must Have (P0)

| ID  | Requirement                                                     | Problem   |
| --- | --------------------------------------------------------------- | --------- |
| R1  | Consistent session counts between project list and sessions API | Problem 1 |
| R2  | Accurate `total` and `hasMore` in sessions response             | Problem 2 |
| R3  | Documentation on `source` field semantics                       | Problem 3 |

### Should Have (P1)

| ID  | Requirement                                       | Problem   |
| --- | ------------------------------------------------- | --------- |
| R4  | Session search capability                         | Problem 4 |
| R5  | Lightweight session count endpoint                | Problem 5 |
| R6  | Filter for "user-initiated" sessions specifically | Problem 3 |

### Nice to Have (P2)

| ID  | Requirement                           | Problem   |
| --- | ------------------------------------- | --------- |
| R7  | Session archive/soft-delete           | Problem 6 |
| R8  | Session parent/lineage information    | Problem 3 |
| R9  | Bulk session operations (rename, tag) | General   |

---

## Technical Context

### Our API Usage Patterns

```
App Launch:
  GET /projects → display project list with counts

Project Selection:
  GET /projects/:path/sessions?source=user&limit=50 → initial session list
  (pagination as user scrolls)

Session Selection:
  GET /projects/:path/sessions/:id/export → load history

Session Management:
  DELETE /projects/:path/sessions/:id → single delete
  DELETE /projects/:path/sessions?filter=older_than&days=30 → bulk cleanup
```

### Volume Expectations

- Typical user: 20-50 sessions per project
- Power user: 100-300 sessions per project
- Agent sessions: Can accumulate rapidly (96 in our test project)

### Performance Requirements

- Session list: <500ms for first page
- Session count: <100ms
- Session search: <1s for results

---

## Questions for cli-bridge Team

1. **Session count discrepancy:** Is the 145 vs 101 difference expected? What does `sessionCount` in the project response actually count?

2. **Source field semantics:** When does a session with `agent-*` ID get `source: "user"`? Is this when the subagent completes successfully?

3. **Pagination:** Is cursor-based or offset-based pagination preferred for the sessions endpoint?

4. **Search scope:** If search is implemented, should it search JSONL content directly or use a separate index?

5. **Archive behavior:** If archive is implemented, should archived sessions count toward `sessionCount`?

---

## Appendix: Test Data

### Server Details

- **URL:** http://10.0.3.2:3100
- **Version:** 0.1.10

### Sample API Responses

**Project List (showing count discrepancy):**

```json
{
  "projects": [
    {
      "path": "/home/bridge/repos/ClaudeCodeApp",
      "sessionCount": 145
    }
  ]
}
```

**Sessions List (actual sessions):**

```bash
GET /projects/-home-bridge-repos-ClaudeCodeApp/sessions?source=all&limit=500

# Returns 101 sessions:
# - 96 with source: "agent"
# - 5 with source: "user"
# - total: null
# - hasMore: null
```

**Session Distribution by Source:**
| Source | Count | Typical messageCount |
|--------|-------|---------------------|
| agent | 96 | 2 |
| user | 5 | 95-1586 |
| helper | 0 | - |

---

## Contact

For questions or clarification on these requirements:

- **Team:** CodingBridge iOS
- **Project:** https://github.com/[org]/ClaudeCodeApp

We're happy to provide additional test data, usage logs, or clarification on any requirements.

---

## CLI-Bridge Team Response

> **Date:** 2025-12-30
> **Status:** P0, P1, & P2 Complete ✅ - Ready for testing

### Root Cause Analysis

#### Problem 1: Session Count Inconsistency (145 vs 101)

**Root Cause Identified: Path Resolution Mismatch**

The discrepancy occurs due to inconsistent path resolution between session counting and metadata extraction:

1. **`countSessions()`** (`src/sessions/manager.ts:280`) uses `findClaudeProjectDir()` which performs smart path resolution with multiple decode variants
2. **`listSessions()`** (`src/sessions/manager.ts:20`) also uses `findClaudeProjectDir()` to find the session directory
3. **However**, `extractSessionMetadata()` (`src/sessions/metadata.ts:19`) uses `getClaudeProjectDir()` which does naive path encoding

**The Bug:** When Claude stores sessions under a path that doesn't match the naive encoding (common with dashed directory names like `cli-bridge`), `extractSessionMetadata()` fails to find the JSONL file and returns `null`. The session is counted but not included in the list.

**Files Affected:**

- `src/sessions/metadata.ts:19` - uses `getClaudeProjectDir()` (naive)
- `src/sessions/manager.ts:24` - uses `findClaudeProjectDir()` (smart)
- `src/sessions/manager.ts:281` - uses `findClaudeProjectDir()` (smart)

**Fix:** Modify `extractSessionMetadata()` to accept an optional `claudeDir` parameter, and have `listSessions()` pass the resolved directory path.

---

#### Problem 2: Missing Pagination Metadata

**Root Cause: Not Implemented**

The pagination metadata was never implemented. The response format only includes the `sessions` array:

```typescript
// src/routes/sessions.ts:84
return new Response(JSON.stringify({ sessions }), { ... });
```

The `listSessions()` function returns `SessionMetadata[]` instead of an object with pagination info.

**Fix:**

1. Change `listSessions()` to return `{ sessions, total, hasMore }`
2. Calculate `total` before applying limit/offset
3. Calculate `hasMore = offset + limit < total`
4. Update `handleSessionsList()` to return the full response

---

#### Problem 3: Source Field Semantics

**Root Cause: Source Inference Logic**

The `source` field is determined by this priority in `extractSessionMetadata()` (`src/sessions/metadata.ts:93-103`):

1. **Supplementary metadata** (`~/.cli-bridge/sessions/{sessionId}.json`) - if `source` field exists, use it
2. **Helper session detection** - if `isHelperSession(sessionId)` returns true, source = "helper"
3. **Warmup detection** - if first user message is "Warmup" or "Warm up", source = "agent"
4. **Default** - source = "user"

**Why `agent-*` IDs can have `source: "user"`:**

- Session ID prefixes (`agent-*`, `user-*`, etc.) are assigned by **Claude Code SDK**, not cli-bridge
- cli-bridge only knows a session is agent-created if:
  - Supplementary metadata explicitly sets `source: "agent"`
  - The `markSessionAsAgent()` function was called during session creation
- Sessions created by the SDK's Task tool may not have supplementary metadata if cli-bridge wasn't tracking them

**Current Behavior:**

- Helper sessions and SDK warmup sessions ARE detected automatically
- Subagent sessions require explicit marking via `saveSupplementaryMetadata()`
- The `markSessionAsAgent()` function exists (`src/agents/subagent.ts:27`) but may not be called for all SDK-spawned sessions

---

### Answers to CodingBridge Questions

1. **Session count discrepancy:** The 145 vs 101 difference is a **bug** caused by path resolution mismatch. This is being fixed.

2. **Source field semantics:** A session with `agent-*` ID gets `source: "user"` when:

   - No supplementary metadata exists for the session
   - The session is NOT a known helper session
   - The first message is NOT "Warmup" or "Warm up"
   - This typically happens when Claude Code creates agent sessions that cli-bridge didn't track

3. **Pagination:** We're implementing **offset-based pagination** (consistent with current implementation). Cursor-based is a potential future enhancement.

4. **Search scope:** Search will query JSONL content directly. A separate index may be added later for performance.

5. **Archive behavior:** Archived sessions should NOT count toward `sessionCount` (will be handled in P2).

---

### Implementation Plan

#### Phase 1: P0 Fixes (Complete ✅)

| Task                                           | Status  | Files                                                                       |
| ---------------------------------------------- | ------- | --------------------------------------------------------------------------- |
| R1: Fix path resolution in metadata extraction | ✅ Done | `src/sessions/metadata.ts`, `src/sessions/manager.ts`                       |
| R2: Add pagination metadata to response        | ✅ Done | `src/sessions/manager.ts`, `src/routes/sessions.ts`, `src/types/session.ts` |
| R3: Document source field semantics            | ✅ Done | `docs/requirements/sessions.md`                                             |

#### Phase 2: P1 Features (Complete ✅)

| Task                           | Status  | Notes                                                                |
| ------------------------------ | ------- | -------------------------------------------------------------------- |
| R4: Session search             | ✅ Done | Added `GET /projects/:path/sessions/search?q=...`                    |
| R5: Lightweight count endpoint | ✅ Done | Added `GET /projects/:path/sessions/count?source=...`                |
| R6: User-initiated filter      | ✅ Done | Added ID prefix heuristic: `agent-*` IDs now infer `source: "agent"` |

#### Phase 3: P2 Enhancements (Complete ✅)

| Task                | Status  | Notes                                                              |
| ------------------- | ------- | ------------------------------------------------------------------ |
| R7: Session archive | ✅ Done | `POST /sessions/:id/archive` and `/unarchive`, `archivedAt` field  |
| R8: Session lineage | ✅ Done | `parentSessionId` field, `GET /sessions/:id/children` endpoint     |
| R9: Bulk operations | ✅ Done | `POST /sessions/bulk` with archive/unarchive/delete/update actions |

---

### Technical Changes

#### New Types (P0)

```typescript
// src/types/session.ts

interface SessionListResult {
  sessions: SessionMetadata[];
  total: number;
  hasMore: boolean;
}
```

#### New Fields (P2)

```typescript
// SessionMetadata additions
interface SessionMetadata {
  // ... existing fields ...
  archivedAt?: string; // ISO timestamp when archived
  parentSessionId?: string; // Parent session for lineage
}

// SessionListOptions additions
interface SessionListOptions {
  // ... existing fields ...
  includeArchived?: boolean; // Include archived sessions
  archivedOnly?: boolean; // Show only archived
  parentSessionId?: string; // Filter by parent
}

// Bulk operation types
type BulkOperation =
  | { action: "archive" }
  | { action: "unarchive" }
  | { action: "delete" }
  | { action: "update"; customTitle?: string | null };

interface BulkOperationResult {
  success: string[];
  failed: Array<{ sessionId: string; error: string }>;
}
```

#### New Endpoints (P2)

```
POST /projects/:path/sessions/:id/archive     → SessionMetadata
POST /projects/:path/sessions/:id/unarchive   → SessionMetadata
GET  /projects/:path/sessions/:id/children    → SessionListResult
POST /projects/:path/sessions/bulk            → BulkOperationResult
```

#### API Response Changes (P0)

**Before:**

```json
{
  "sessions": [...]
}
```

**After:**

```json
{
  "sessions": [...],
  "total": 145,
  "hasMore": true
}
```

---

### Progress Log

| Date       | Update                                                                                |
| ---------- | ------------------------------------------------------------------------------------- |
| 2025-12-30 | Root cause analysis complete. Implementation starting.                                |
| 2025-12-30 | P0-R1 fixed: Path resolution in metadata extraction now uses resolved `claudeDir`     |
| 2025-12-30 | P0-R2 fixed: Sessions list now returns `{ sessions, total, hasMore }`                 |
| 2025-12-30 | P0-R3 completed: Source field semantics documented in `docs/requirements/sessions.md` |
| 2025-12-30 | All 300 tests passing. Ready for review.                                              |
| 2025-12-30 | P1-R4 done: Added `GET /projects/:path/sessions/search?q=...` endpoint                |
| 2025-12-30 | P1-R5 done: Added `GET /projects/:path/sessions/count` with source breakdown          |
| 2025-12-30 | P1-R6 done: Session IDs starting with `agent-` now infer `source: "agent"`            |
| 2025-12-30 | P1 complete. All 300 tests passing. Docs updated.                                     |
| 2025-12-30 | P2-R7 done: Added archive/unarchive endpoints, `archivedAt` field in metadata         |
| 2025-12-30 | P2-R8 done: Added `parentSessionId` field, `GET /sessions/:id/children` endpoint      |
| 2025-12-30 | P2-R9 done: Added `POST /sessions/bulk` for batch archive/unarchive/delete/update     |
| 2025-12-30 | P2 complete. All 300 tests passing. Docs updated. All phases done! 🎉                 |
