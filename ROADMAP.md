# CodingBridge Roadmap

> Forward-looking development plan for the iOS client.
>
> **Completed work** lives in [CHANGELOG.md](CHANGELOG.md); this roadmap lists open work only.

---

## Simplification Program: COMPLETE

**Released in v0.7.0** (2026-01-02) - All 45 simplification issues resolved (1 marked "Won't Fix" after audit).

The codebase simplification project achieved its goals:
- Removed ~4,000 lines of legacy code (adapters, migration layers, duplicate paths)
- Consolidated 49 WebSocket callbacks into single StreamEvent enum
- Split large files into focused modules (ChatViewModel, CLIBridgeManager, SSHManager, Models)
- Unified persistence and permission resolution pipelines
- Updated documentation to match WebSocket streaming architecture

See [CHANGELOG.md](CHANGELOG.md) v0.7.0 for complete details.

---

## Current Focus: Stabilization

No new feature work scheduled. Focus areas:
- Bug fixes as reported in [ISSUES.md](ISSUES.md)
- Performance monitoring and optimization
- Test coverage improvements

---

## Future Considerations

Items for potential future development (not prioritized):

| Area | Description |
|------|-------------|
| Background Processing | Message queuing while agent is busy (see requirements/projects/message-queuing/) |
| Push Notifications | Background task completion alerts via APNs/FCM |
| Offline Support | Queue actions for sync when connectivity returns |
| Test Coverage | Expand unit and integration test suites |

---

## Completed Work

All historical milestones and phase completions are documented in [CHANGELOG.md](CHANGELOG.md).

### Simplification Issue Summary (v0.7.0)

<details>
<summary>45 issues completed (click to expand)</summary>

#### Core Architecture (High Impact)

| # | Task | Notes |
|---|------|-------|
| #1 | Remove CLIBridgeTypesMigration | Split into CLIBridgeAppTypes.swift + CLIBridgeExtensions.swift |
| #9 | WebSocket callbacks -> StreamEvent enum | 49 callbacks consolidated to 1 |
| #17 | Remove CLIBridgeAdapter layer | ~800 lines deleted |
| #27 | Consolidate reconnect logic | CLIBridgeManager owns lifecycle |

#### State Management

| # | Task | Notes |
|---|------|-------|
| #7 | Remove effectiveModelId/effectivePermissionMode indirection | Retained resolution logic only |
| #8 | Eliminate streamingMessageId/timestamp | Stable ID + computed timestamp |
| #16 | Consolidate sheet booleans | Single ActiveSheet enum |
| #24 | Permission resolution pipeline | 5-level resolution via PermissionManager |

#### Persistence

| # | Task | Notes |
|---|------|-------|
| #5 | Consolidate stores | Won't Fix - stores intentionally separate |
| #21 | Centralize path encoding | ProjectPathEncoder utility |
| #23 | Unify draft + processing persistence | Deleted DraftInputPersistence.swift |
| #25 | Remove MessageQueuePersistence | Deleted dead code |

#### Code Cleanup

| # | Task | Notes |
|---|------|-------|
| #2 | Simplify PaginatedMessage.toChatMessage() | 25 lines saved |
| #3 | Remove formatJSONValue() | Replaced with JSONEncoder |
| #4 | Eliminate extractFilePath() | Use ToolParser.extractParam() |
| #6 | Remove effectiveSessionToResume | Use manager.sessionId directly |
| #10 | Remove toolUseMap dictionary | Tool name from StreamEvent |
| #11 | Remove subagentToolIds tracking | Filter at event time |
| #12 | Remove pendingGitCommands tracking | Refresh on completion only |
| #13 | Remove todoHideTimer | Manual dismiss only |
| #14 | Simplify git banner state | Removed auto-hide timer |
| #15 | Remove ScrollStateManager | 230 lines deleted |
| #18 | Inline groupMessagesForDisplay() | Now computed property |
| #19 | Remove message pruning | MessageStore handles limits |
| #20 | Simplify slash command handling | Registry pattern |
| #22 | Fix Project.title path stripping | Use name field directly |
| #26 | Service reconfiguration on serverURL change | Combine publisher |
| #28 | Gate dev tools behind DEBUG | ToolTestView wrapped |
| #29 | Standardize SSHManager ownership | Per-view instance pattern |
| #30 | Update docs for WebSocket | 9 files updated |

#### cli-bridge Integration

| # | Task | Notes |
|---|------|-------|
| #31 | Exit Plan Mode approval UI | Sheet with markdown preview |
| #32 | Multi-repo git status | Subrepo discovery API |
| #33 | Batch session counts | GET /projects includes counts |
| #34 | Idempotent reconnection | Server guarantees no duplicates |
| #35 | Typed StreamMessage | PaginatedMessage uses typed field |
| #36 | Normalize model ID | Uses modelAlias from server |
| #37 | Typed tool input | Uses inputDescription when available |
| #38 | Fix duplicate idle state | Server deduplicates |
| #39 | Session count in project list | Duplicate of #33 |
| #40 | ISO8601 fractional seconds | Single formatter |
| #41 | OpenAPI error responses | Typed error wrappers |

#### File Splits

| # | Task | Notes |
|---|------|-------|
| #42 | Split ChatViewModel | 6 focused modules |
| #43 | Split Models.swift | 10 focused files |
| #44 | Split SSHManager | 4 modules |
| #45 | Split CLIBridgeManager | 5 modules |

</details>
