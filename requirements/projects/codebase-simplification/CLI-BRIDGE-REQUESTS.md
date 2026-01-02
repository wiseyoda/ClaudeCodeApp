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
| #34 | Idempotent reconnection protocol | Medium | [cli-bridge#20](https://github.com/wiseyoda/cli-bridge/issues/20) | Filed |
| #35 | Typed StreamMessage in paginated responses | Medium | [cli-bridge#21](https://github.com/wiseyoda/cli-bridge/issues/21) | Filed |
| #36 | Normalize model ID handling (echo alias) | Medium | [cli-bridge#17](https://github.com/wiseyoda/cli-bridge/issues/17) | Filed |
| #37 | Typed tool input (no JSONValue dict) | Medium | [cli-bridge#16](https://github.com/wiseyoda/cli-bridge/issues/16) | Filed |
| #38 | Fix duplicate idle state messages | Low | [cli-bridge#15](https://github.com/wiseyoda/cli-bridge/issues/15) | Filed |
| #39 | Include session count in project list response | Medium | [cli-bridge#18](https://github.com/wiseyoda/cli-bridge/issues/18) | Filed |
| #40 | Standardize ISO8601 with fractional seconds | Low | [cli-bridge#13](https://github.com/wiseyoda/cli-bridge/issues/13) | Filed |
| #41 | Document error responses in OpenAPI schema | Low | [cli-bridge#14](https://github.com/wiseyoda/cli-bridge/issues/14) | Filed |

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
| [#13](https://github.com/wiseyoda/cli-bridge/issues/13) | Open | ISO8601 date format |
| [#14](https://github.com/wiseyoda/cli-bridge/issues/14) | Open | OpenAPI error docs |
| [#15](https://github.com/wiseyoda/cli-bridge/issues/15) | Open | Duplicate idle states |
| [#16](https://github.com/wiseyoda/cli-bridge/issues/16) | Open | Typed tool input |
| [#17](https://github.com/wiseyoda/cli-bridge/issues/17) | Open | Model ID normalization |
| [#18](https://github.com/wiseyoda/cli-bridge/issues/18) | Open | Session count in project list |
| [#20](https://github.com/wiseyoda/cli-bridge/issues/20) | Open | Idempotent reconnection |
| [#21](https://github.com/wiseyoda/cli-bridge/issues/21) | Open | Typed paginated messages |

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
