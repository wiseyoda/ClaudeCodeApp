# CodingBridge Roadmap

> Focused simplification plan for the iOS client.
>
> **Completed work** lives in [CHANGELOG.md](CHANGELOG.md); this roadmap lists open work only.

---

## Current Focus: Simplification Program (Reset)

### Goals
- Reduce debugging time by removing legacy layers and duplication.
- Simplify state and persistence so behavior is predictable and testable.
- Align documentation with the real runtime architecture (WebSocket + REST + SSH).

### Assessment Summary (Validated)
- Claude's score tables and pros/cons are not in the repo; add them when available.

**Top Priority (all 5-star across impact, simplification, iOS practices)**

| # | Item | Lines Saved |
|---|------|-------------|
| #9 | WebSocket callbacks -> StreamEvent enum | 49 callbacks -> 1 |
| #17 | Remove CLIBridgeAdapter layer | ~1,002 lines |
| #1 | Remove CLIBridgeTypesMigration | ~2,398 lines |

**Corrections to Claude assessment (verified in code)**
- #4 extractFilePath has been replaced with ToolParser.extractParam() calls (Complete).
- #6 effectiveSessionToResume has been removed; manager.sessionId used directly (Complete).
- #7 effectivePermissionMode String wrapper removed; effectiveModelId and effectivePermissionModeValue retained as resolution logic (Complete).
- #18 groupMessagesForDisplay inlined as computed property in ChatViewModel; function remains in CompactToolView.swift with DisplayItem types (Complete).

**Keep-as-is guidance (defer until after streaming refactor)**
- #8 streamingMessageId/streamingMessageTimestamp now use a stable ID + computed timestamp (Complete).
- #15 ScrollStateManager removed (Complete) - ChatView already used native ScrollViewReader.
- #19 message pruning removed (Complete) - persistence now handles limits via MessageStore.saveMessages.

### Plan of Record (Dependency Chain)

| Order | # | Task | Impact | Depends On | Status | Notes |
|-------|---|------|--------|------------|--------|-------|
| 1 | #9 | WebSocket callbacks -> StreamEvent enum | High | - | Complete | Legacy callbacks removed; StreamEvent-only callbacks. |
| 2 | #17 | Remove CLIBridgeAdapter layer | High | #9 | Complete | ~800 lines deleted, ChatViewModel uses manager directly. |
| 3 | #1 | Remove CLIBridgeTypesMigration | High | #17 | Complete | Split into CLIBridgeAppTypes.swift + CLIBridgeExtensions.swift. |
| 4 | #27 | Consolidate network/lifecycle/reconnect logic; remove sleep-based connects | High | #17 | Complete | Removed duplicate ChatView reconnect handler; rely on CLIBridgeManager lifecycle observers. |
| 5 | #23 | Unify draft + processing persistence | High | #27 | Complete | Deleted DraftInputPersistence.swift; unified global recovery in MessageStore. |
| 6 | #25 | Finish or remove MessageQueuePersistence | Medium | #23 | Complete | Deleted dead code; recovery state handled by MessageStore. |
| 7 | #5 | Consolidate stores into one persistence layer | Medium | #23/#25 | Won't Fix | Audit found no duplication; stores are intentionally separate. |
| 8 | #21 | Centralize project path encode/decode (preserve hyphens) | High | #1 | Complete | Created ProjectPathEncoder utility; migrated MessageStore to - encoding. |
| 9 | #22 | Replace hard-coded path stripping in Project.title | Low | #21 | Complete | Removed hard-coded path prefix; name field is already basename. |
| 10 | #26 | Reconfigure long-lived services on serverURL change | Medium | #21 | Complete | 5 services now auto-reconfigure via Combine publisher. |
| 11 | #24 | Define a single permission resolution pipeline | Medium | #23/#26 | Complete | ChatViewModel uses PermissionManager.resolvePermissionMode() for 5-level resolution. |
| 12 | #16 | Consolidate sheet booleans into activeSheet enum | Low | - | Complete | 7 @Published booleans replaced with single ActiveSheet enum. |
| 13 | #30 | Update docs to match WebSocket streaming; remove SSE/WebSocketManager refs | Medium | #1/#17 | Complete | Updated 9 files to reflect WebSocket architecture. |

### Backlog (Unscheduled or Parallel)

| # | Task | Impact | Depends On | Status | Notes |
|---|------|--------|------------|--------|-------|
| #2 | Simplify PaginatedMessage.toChatMessage() | Medium | #1 | Pending | Should be done after type cleanup. |
| #3 | Remove formatJSONValue() custom serializer | Low | #2 | Pending | Use JSONEncoder. |
| #4 | Eliminate extractFilePath() parsing | Medium | - | Complete | Replaced with ToolParser.extractParam() calls. |
| #6 | Remove effectiveSessionToResume computed property | Low | #23 | Complete | Removed; manager.sessionId used directly. |
| #7 | Remove effectiveModelId/effectivePermissionMode indirection | Low | #23 | Complete | Removed String wrapper; retained resolution logic. |
| #8 | Eliminate streamingMessageId/timestamp | Low | - | Complete | Streaming identity now stable and computed. |
| #10 | Remove toolUseMap dictionary | Low | #9 | Complete | Tool name now taken directly from StreamEvent. |
| #11 | Remove subagentToolIds tracking | Low | #9 | Complete | Removed Set tracking; filter based on activeSubagent at event time. |
| #12 | Remove pendingGitCommands tracking | Low | - | Complete | Refresh git status on completion only. |
| #13 | Remove todoHideTimer auto-hide logic | Low | - | Complete | Removed auto-hide timer; manual dismiss only. |
| #14 | Simplify git banner state | Low | - | Pending | Remove auto-hide and cleanup flags. |
| #15 | Remove ScrollStateManager | Medium | #9/#17 | Complete | Deleted ScrollStateManager (230 lines); ChatView uses native ScrollViewReader. |
| #18 | Inline groupMessagesForDisplay() | Medium | - | Complete | Now computed property in ChatViewModel; function in CompactToolView.swift. |
| #19 | Remove message pruning | Low | #23 | Complete | Removed pruneMessagesIfNeeded() and 2 call sites. |
| #20 | Simplify slash command handling | Low | - | Complete | Replaced switch with registry pattern. |
| #28 | Gate ToolTestView/dev tools behind DEBUG or feature flag | Low | - | Complete | ToolTestView and ContentView dev tool button wrapped in #if DEBUG. |
| #29 | Standardize SSHManager ownership | Medium | - | Pending | Align singleton vs per-view usage. |

### cli-bridge Feature Requests / Issues

| # | Task | Impact | Depends On | Status | Notes |
|---|------|--------|------------|--------|-------|
| #31 | Exit Plan Mode approval UI | Medium | #9/#24 | Pending | Based on Issue #22; match CLI flow. |
| #32 | Multi-repo/monorepo git status aggregation | Low | - | Pending | Based on Issue #18; needs subrepo discovery strategy. |
| #33 | Batch session counts API (cli-bridge) | Medium | - | Pending | Based on Issue #36; backend request. |
| #34 | Idempotent reconnection protocol | Medium | - | Pending | Reduces client dedupe; [cli-bridge#20](https://github.com/wiseyoda/cli-bridge/issues/20). |
| #35 | Typed StreamMessage in paginated responses | Medium | - | Pending | Unblocks #2; [cli-bridge#21](https://github.com/wiseyoda/cli-bridge/issues/21). |
| #36 | Normalize model ID handling (echo alias) | Medium | - | Pending | Removes heuristic matching; [cli-bridge#17](https://github.com/wiseyoda/cli-bridge/issues/17). |
| #37 | Typed tool input (no JSONValue dict) | Medium | - | Pending | Simplifies tool parsing; [cli-bridge#16](https://github.com/wiseyoda/cli-bridge/issues/16). |
| #38 | Fix duplicate idle state messages | Low | - | Pending | Remove client-side skip; [cli-bridge#15](https://github.com/wiseyoda/cli-bridge/issues/15). |
| #39 | Include session count in project list response | Medium | - | Pending | Alternative to #33; [cli-bridge#18](https://github.com/wiseyoda/cli-bridge/issues/18). |
| #40 | Standardize ISO8601 with fractional seconds | Low | - | Pending | Simplify date parsing; [cli-bridge#13](https://github.com/wiseyoda/cli-bridge/issues/13). |
| #41 | Document error responses in OpenAPI schema | Low | - | Pending | Enable typed errors; [cli-bridge#14](https://github.com/wiseyoda/cli-bridge/issues/14). |

### Refactor Opportunities (Post-simplification)

| # | Task | Impact | Depends On | Status | Notes |
|---|------|--------|------------|--------|-------|
| #42 | Split ChatViewModel into focused modules | Low | #17 | Pending | ~1641 lines; revisit after streaming/persistence cleanup. |
| #43 | Split Models.swift into model + persistence files | Medium | #1 | Pending | ~1103 lines; aligns with store consolidation. |
| #44 | Split SSHManager into key/file/git modules | Medium | - | Pending | ~1401 lines; depends on ownership decision (#29). |
| #45 | Split CLIBridgeManager into connection + stream handler | Medium | #9/#17 | Pending | ~1237 lines; reduce churn risk. |

---

## Completed Work

Phases 1-7 and release milestones are recorded in [CHANGELOG.md](CHANGELOG.md). This roadmap is forward-looking only.
