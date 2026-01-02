# cli-bridge Feature Requests

> Requests for the cli-bridge backend team at [wiseyoda/cli-bridge](https://github.com/wiseyoda/cli-bridge).

## How to Use This Document

1. When a simplification issue would be better solved by a cli-bridge change, add it here
2. File the issue at https://github.com/wiseyoda/cli-bridge/issues
3. Update this document with the issue number once filed
4. Link the cli-bridge issue in the related simplification issue file

## Request Summary

🎉 **All cli-bridge requests are complete!** All 11 requests from ROADMAP.md items #31-#41 have been filed, verified, and closed.

| # | Request | Impact | Status | GitHub Issue |
|---|---------|--------|--------|--------------|
| #31 | Exit Plan Mode approval UI | Medium | ✅ **Completed** | [cli-bridge#29](https://github.com/wiseyoda/cli-bridge/issues/29) |
| #32 | Multi-repo/monorepo git status aggregation | Low | ✅ **Completed** | [cli-bridge#30](https://github.com/wiseyoda/cli-bridge/issues/30) |
| #33 | Batch session counts API | Medium | ✅ **Completed** | [cli-bridge#31](https://github.com/wiseyoda/cli-bridge/issues/31) |
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
| [#29](https://github.com/wiseyoda/cli-bridge/issues/29) | ✅ Closed | ExitPlanMode - documented in protocol.md, works via permission system |
| [#30](https://github.com/wiseyoda/cli-bridge/issues/30) | ✅ Closed | Subrepos endpoint - documented in protocol.md, fully implemented |
| [#31](https://github.com/wiseyoda/cli-bridge/issues/31) | ✅ Closed | Session counts - verified in `GET /projects` response |

## Implementation Reference

All cli-bridge requests have been completed and documented. Reference for iOS implementation:

### #31 - Exit Plan Mode Approval UI ✅

**Documentation**: `specifications/reference/protocol.md` → "ExitPlanMode Handling"

**How it works**:
1. Claude calls `ExitPlanMode` tool with plan content
2. cli-bridge sends `permission_request` with `tool: "ExitPlanMode"` and `input: { plan: "..." }`
3. iOS renders plan markdown and shows Approve/Reject buttons
4. iOS sends `permission_response` with `choice: "allow"` or `"deny"`

**Example message:**
```json
{
  "type": "permission",
  "id": "perm_xyz789",
  "tool": "ExitPlanMode",
  "input": { "plan": "## Implementation Plan\n\n1. Create component..." },
  "options": ["allow", "deny", "always"]
}
```

---

### #32 - Multi-repo Git Status Aggregation ✅

**Documentation**: `specifications/reference/protocol.md` → "Sub-Repositories"

**Endpoints:**
```
GET /projects/{encodedPath}/subrepos?maxDepth=2
POST /projects/{encodedPath}/subrepos/{relativePath}/pull
```

**Example response:**
```json
{
  "subrepos": [{
    "relativePath": "packages/core",
    "git": { "branch": "main", "ahead": 0, "behind": 2, ... }
  }]
}
```

---

### #33 - Batch Session Counts ✅

**Solution**: `GET /projects` already includes `sessionCount` for each project.

**Example:**
```json
{
  "projects": [
    { "name": "my-app", "sessionCount": 5, ... },
    { "name": "other-app", "sessionCount": 12, ... }
  ]
}
```

**iOS Action**: Single API call to `GET /projects` provides all session counts - no N+1 problem.
