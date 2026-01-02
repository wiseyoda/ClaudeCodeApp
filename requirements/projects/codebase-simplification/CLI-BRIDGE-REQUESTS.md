# cli-bridge Feature Requests

> Requests for the cli-bridge backend team at [wiseyoda/cli-bridge](https://github.com/wiseyoda/cli-bridge).

## How to Use This Document

1. When a simplification issue would be better solved by a cli-bridge change, add it here
2. File the issue at https://github.com/wiseyoda/cli-bridge/issues
3. Update this document with the issue number once filed
4. Link the cli-bridge issue in the related simplification issue file

## Pending Requests

These are extracted from ROADMAP.md items #31-#41 and need to be filed as GitHub issues.

| # | Request | Impact | Status | GitHub Issue |
|---|---------|--------|--------|--------------|
| #31 | Exit Plan Mode approval UI | Medium | Pending | - |
| #32 | Multi-repo/monorepo git status aggregation | Low | Pending | - |
| #33 | Batch session counts API | Medium | Pending | - |
| #34 | Idempotent reconnection protocol | Medium | **Completed** | [cli-bridge#20](https://github.com/wiseyoda/cli-bridge/issues/20) |
| #35 | Typed StreamMessage in paginated responses | Medium | **Completed** | [cli-bridge#21](https://github.com/wiseyoda/cli-bridge/issues/21) |
| #36 | Normalize model ID handling (echo alias) | Medium | **Completed** | [cli-bridge#17](https://github.com/wiseyoda/cli-bridge/issues/17) |
| #37 | Typed tool input (no JSONValue dict) | Medium | **Completed** | [cli-bridge#16](https://github.com/wiseyoda/cli-bridge/issues/16) |
| #38 | Fix duplicate idle state messages | Low | **Completed** | [cli-bridge#15](https://github.com/wiseyoda/cli-bridge/issues/15) |
| #39 | Include session count in project list response | Medium | **Completed** | [cli-bridge#18](https://github.com/wiseyoda/cli-bridge/issues/18) |
| #40 | Standardize ISO8601 with fractional seconds | Low | **Completed** | [cli-bridge#13](https://github.com/wiseyoda/cli-bridge/issues/13) |
| #41 | Document error responses in OpenAPI schema | Low | **Completed** | [cli-bridge#14](https://github.com/wiseyoda/cli-bridge/issues/14) |

## Request Template

When filing new issues, use this template:

```markdown
## Summary

[One-line description of what you need]

## iOS Client Context

This request comes from the CodingBridge iOS client codebase simplification project.

**Related iOS issue**: `requirements/projects/codebase-simplification/issues/{number}-{name}.md`

## Current Behavior

[What happens now that needs to change]

## Proposed Behavior

[What you want to happen instead]

## Impact on iOS Client

[How this would simplify the iOS code]

- Lines saved: ~X
- Files affected: Y
- Complexity reduction: [description]

## Alternatives Considered

[What workarounds exist in the iOS client, if any]
```

## Filed Issues Status

Track status of filed issues here:

| Issue | Status | Notes |
|-------|--------|-------|
| [#13](https://github.com/wiseyoda/cli-bridge/issues/13) | ✅ Closed | ISO8601 date format - `normalizeISO8601()` utility added |
| [#14](https://github.com/wiseyoda/cli-bridge/issues/14) | ✅ Closed | OpenAPI error docs - typed error schemas registered |
| [#15](https://github.com/wiseyoda/cli-bridge/issues/15) | ✅ Closed | Duplicate idle states - state deduplication in agent |
| [#16](https://github.com/wiseyoda/cli-bridge/issues/16) | ✅ Closed | Typed tool input - `inputDescription` field added |
| [#17](https://github.com/wiseyoda/cli-bridge/issues/17) | ✅ Closed | Model ID normalization - `modelAlias` echoed in connected |
| [#18](https://github.com/wiseyoda/cli-bridge/issues/18) | ✅ Closed | Session count in project list - already implemented |
| [#20](https://github.com/wiseyoda/cli-bridge/issues/20) | ✅ Closed | Idempotent reconnection - protocol documented |
| [#21](https://github.com/wiseyoda/cli-bridge/issues/21) | ✅ Closed | Typed paginated messages - `StreamMessageSchema` used |

## Unfiled Requests

These still need to be filed:

### #31 - Exit Plan Mode Approval UI

**Summary**: Provide a way to approve/reject plan mode exit via the API

**Context**: When Claude enters plan mode and wants to exit, the CLI shows a confirmation. The iOS client needs an equivalent approval flow.

**iOS Workaround**: Currently handled ad-hoc, needs formal API support.

---

### #32 - Multi-repo Git Status Aggregation

**Summary**: Aggregate git status across monorepo subprojects

**Context**: Some projects have multiple git repositories. iOS client wants to show unified git status.

**iOS Workaround**: Individual git status calls per subrepo.

---

### #33 - Batch Session Counts API

**Summary**: Get session counts for multiple projects in one request

**Context**: Home screen shows session counts for all projects. Currently requires N API calls.

**iOS Workaround**: Fire parallel requests, cache aggressively.
