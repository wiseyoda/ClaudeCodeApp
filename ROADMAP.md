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
- #4 extractFilePath is still present in `CodingBridge/Views/CompactToolView.swift`.
- #6 effectiveSessionToResume is still present in `CodingBridge/ViewModels/ChatViewModel.swift`.
- #7 effectiveModelId/effectivePermissionMode are still present in `CodingBridge/ViewModels/ChatViewModel.swift`.
- #18 groupMessagesForDisplay still lives in `CodingBridge/Views/CompactToolView.swift` and is used by `CodingBridge/ViewModels/ChatViewModel.swift`.

**Keep-as-is guidance (defer until after streaming refactor)**
- #8 streamingMessageId/streamingMessageTimestamp are still used by `CodingBridge/ChatView.swift`.
- #15 ScrollStateManager provides streaming-safe debounce; reconsider after #9/#17.
- #19 message pruning is tied to persistence/history safety; reconsider after #23.

### Plan of Record (Dependency Chain)

| Order | # | Task | Impact | Depends On | Status | Notes |
|-------|---|------|--------|------------|--------|-------|
| 1 | #9 | WebSocket callbacks -> StreamEvent enum | High | - | Complete | Legacy callbacks removed; StreamEvent-only callbacks. |
| 2 | #17 | Remove CLIBridgeAdapter layer | High | #9 | Complete | ~800 lines deleted, ChatViewModel uses manager directly. |
| 3 | #1 | Remove CLIBridgeTypesMigration | High | #17 | Complete | Split into CLIBridgeAppTypes.swift + CLIBridgeExtensions.swift. |
| 4 | #27 | Consolidate network/lifecycle/reconnect logic; remove sleep-based connects | High | #17 | Planned | Reduce duplicate reconnect paths. |
| 5 | #23 | Unify draft + processing persistence | High | #27 | Planned | Single source of truth for recovery. |
| 6 | #25 | Finish or remove MessageQueuePersistence | Medium | #23 | Planned | Either wire queue or delete it. |
| 7 | #5 | Consolidate stores into one persistence layer | Medium | #23/#25 | Planned | Avoid state duplication. |
| 8 | #16 | Consolidate sheet booleans into activeSheet enum | Low | #5 | Planned | Reduce UI state sprawl. |
| 9 | #21 | Centralize project path encode/decode (preserve hyphens) | High | #1 | Planned | Fix path ambiguity across API layers. |
| 10 | #22 | Replace hard-coded path stripping in Project.title | Low | #21 | Planned | Use basename or server displayName. |
| 11 | #26 | Reconfigure long-lived services on serverURL change | Medium | #21 | Planned | Avoid stale serverURL in stores/services. |
| 12 | #24 | Define a single permission resolution pipeline | Medium | #23/#26 | Planned | Global -> project -> session -> server. |
| 13 | #30 | Update docs to match WebSocket streaming; remove SSE/WebSocketManager refs | Medium | #1/#17 | Planned | Align docs with code. |

### Backlog (Unscheduled or Parallel)

| # | Task | Impact | Depends On | Status | Notes |
|---|------|--------|------------|--------|-------|
| #2 | Simplify PaginatedMessage.toChatMessage() | Medium | #1 | Pending | Should be done after type cleanup. |
| #3 | Remove formatJSONValue() custom serializer | Low | #2 | Pending | Use JSONEncoder. |
| #4 | Eliminate extractFilePath() parsing | Medium | - | Pending | Still in `CodingBridge/Views/CompactToolView.swift`. |
| #6 | Remove effectiveSessionToResume computed property | Low | #23 | Pending | Still used by send flow. |
| #7 | Remove effectiveModelId/effectivePermissionMode indirection | Low | #23 | Pending | Still used by send flow. |
| #8 | Eliminate streamingMessageId/timestamp | Low | - | Deferred | Revisit after streaming refactor. |
| #10 | Remove toolUseMap dictionary | Low | #9 | Pending | Depends on StreamEvent consolidation. |
| #11 | Remove subagentToolIds tracking | Low | #9 | Pending | Depends on StreamEvent consolidation. |
| #12 | Remove pendingGitCommands tracking | Low | - | Pending | Consider refresh-on-complete only. |
| #13 | Remove todoHideTimer auto-hide logic | Low | - | Pending | Manual dismiss only. |
| #14 | Simplify git banner state | Low | - | Pending | Remove auto-hide and cleanup flags. |
| #15 | Remove ScrollStateManager | Medium | #9/#17 | Deferred | Streaming debounce still needed. |
| #18 | Inline groupMessagesForDisplay() | Medium | - | Pending | Still in `CodingBridge/Views/CompactToolView.swift`. |
| #19 | Remove message pruning | Low | #23 | Deferred | Keep until persistence is unified. |
| #20 | Simplify slash command handling | Low | - | Pending | Replace switch with registry. |
| #28 | Gate ToolTestView/dev tools behind DEBUG or feature flag | Low | - | Pending | Avoid production exposure. |
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
| #42 | Split ChatViewModel into focused modules | Low | #17/#5 | Pending | ~1641 lines; revisit after streaming/persistence cleanup. |
| #43 | Split Models.swift into model + persistence files | Medium | #5 | Pending | ~1103 lines; aligns with store consolidation. |
| #44 | Split SSHManager into key/file/git modules | Medium | - | Pending | ~1401 lines; depends on ownership decision (#29). |
| #45 | Split CLIBridgeManager into connection + stream handler | Medium | #9/#17 | Pending | ~1237 lines; reduce churn risk. |

---

## Completed Work

Phases 1-7 and release milestones are recorded in [CHANGELOG.md](CHANGELOG.md). This roadmap is forward-looking only.
