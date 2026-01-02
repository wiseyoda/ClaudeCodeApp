# Issue #30: Update docs to match WebSocket streaming

> **Status**: Complete (verified 2026-01-02)
> **Priority**: Tier 2
> **Depends On**: #1/#17
> **Blocks**: None

---

## Summary

Update all documentation to reflect the current architecture: WebSocket streaming (not SSE), CLIBridgeManager direct usage (not CLIBridgeAdapter), and unified StreamEvent enum.

## Problem

Documentation references outdated architecture:
- SSE streaming instead of WebSocket
- CLIBridgeAdapter layer that was removed in #17
- CLIBridgeTypes.swift instead of split CLIBridgeAppTypes.swift + CLIBridgeExtensions.swift
- Individual callbacks instead of unified StreamEvent enum

## Solution

Update all .md files in requirements/ and root to reflect the actual code architecture after #1 and #17 were completed.

---

## Scope

### In Scope

- Apply the Update docs to match WebSocket streaming change in the listed files
- Remove or replace the legacy path

### Out of Scope

- New features or UX changes
- Unrelated refactors outside this task

---

## Implementation

### Files to Modify

| File | Change |
|---|---|
| requirements/ARCHITECTURE.md | SSE -> WebSocket, CLIBridgeAdapter -> CLIBridgeManager, add StreamEvent docs |
| CLAUDE.md | Update key files table, remove CLIBridgeAdapter reference |
| requirements/OVERVIEW.md | SSE -> WebSocket, add v0.7.0 resolved section |
| requirements/BACKEND.md | SSE -> WebSocket, update troubleshooting |
| requirements/SESSIONS.md | SSE -> WebSocket |
| README.md | SSE -> WebSocket, remove CLIBridgeAdapter references |
| AGENTS.md | WebSocketManager -> CLIBridgeManager, APIClient -> CLIBridgeAPIClient |
| requirements/projects/message-queuing/ARCHITECTURE.md | SSE -> WebSocket, CLIBridgeAdapter -> CLIBridgeManager |
| requirements/projects/message-queuing/IMPLEMENTATION-PLAN.md | CLIBridgeAdapter -> CLIBridgeManager |
| requirements/projects/firebase-integration/guides/01-firebase-console.md | sse_reconnect -> websocket_reconnect |
| requirements/projects/firebase-integration/guides/06-remote-config.md | sse_reconnect -> websocket_reconnect |
| requirements/projects/firebase-integration/IMPLEMENTATION-PLAN.md | sse_reconnect -> websocket_reconnect |
| requirements/projects/firebase-integration/REVIEW-NOTES.md | sse_reconnect -> websocket_reconnect |

### Files to Delete

| File | Reason |
|---|---|
| None | N/A |

### Steps

1. **Audit**
   - Review current implementation and usage
   - Confirm dependent call sites

2. **Implement**
   - Apply the simplification change
   - Update references and remove old code paths

3. **Verify**
   - Build passes: `xcodebuild -project CodingBridge.xcodeproj -scheme CodingBridge -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'`
   - No new warnings
   - App launches and basic functionality works

---

## Acceptance Criteria

- [x] Update docs to match WebSocket streaming is implemented as described
- [x] All SSE references updated to WebSocket
- [x] All CLIBridgeAdapter references updated to CLIBridgeManager
- [x] StreamEvent enum documented in ARCHITECTURE.md
- [x] No code changes (documentation only)

---

## Verification Commands

```bash
# Build verification
xcodebuild -project CodingBridge.xcodeproj -scheme CodingBridge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'

# Custom verification command if applicable
rg -n "SSE" CodingBridge

# Line count verification (if removing code)
# wc -l path/to/file.swift
```

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Behavior regression from deleted paths | Keep behavior tests/manual checks and verify builds |
| Missed references after cleanup | Use `rg` to confirm symbol removal and update all call sites |

---

## Notes

None.

---

## Assessment (from ROADMAP.md)

| Impact | Simplification | iOS Best Practices |
|--------|----------------|-------------------|
| 3/5 | 3/5 | 3/5 |

**Rationale:**
- Impact: Medium per roadmap
- Simplification: reduces indirection and duplicate paths

---

## Completion Log

| Date | Action | Outcome |
|------|--------|---------|
| 2026-01-02 | Started implementation | Identified 9 files with outdated references |
| 2026-01-02 | Completed | Updated ARCHITECTURE.md, CLAUDE.md, OVERVIEW.md, BACKEND.md, SESSIONS.md, message-queuing docs, firebase-integration docs |
| 2026-01-02 | Verified | README and remaining docs aligned to WebSocket streaming |

## Changes Made

### requirements/ARCHITECTURE.md
- Updated system diagram: CLIBridgeAdapter -> CLIBridgeManager, SSE Streaming -> WebSocket Stream
- Updated CLI Bridge Architecture section with WebSocket description
- Updated Core Components table: removed CLIBridgeAdapter, added CLIBridgeAppTypes and CLIBridgeExtensions
- Updated Message Flow diagram for WebSocket
- Added comprehensive StreamEvent Enum documentation table
- Updated Permission Approval System diagram for WebSocket
- Updated Data Flow sections for WebSocket
- Added v0.7.0 resolved section

### CLAUDE.md
- Updated Key Files table: added CLIBridgeAppTypes.swift and CLIBridgeExtensions.swift
- Removed CLIBridgeAdapter.swift reference
- Updated example to use CLIBridgeManager instead of CLIBridgeAdapter

### requirements/OVERVIEW.md
- Updated Background section: SSE -> WebSocket
- Updated Chat Interface: SSE -> WebSocket
- Updated Permission Approval: SSE -> WebSocket
- Updated Completed Features: SSE -> WebSocket
- Added v0.7.0 resolved section

### requirements/BACKEND.md
- Updated overview: SSE -> WebSocket
- Updated Send Message section for WebSocket
- Updated event types table with additional WebSocket events
- Updated troubleshooting section for WebSocket

### requirements/SESSIONS.md
- Updated troubleshooting: SSE -> WebSocket

### requirements/projects/message-queuing/ARCHITECTURE.md
- Updated diagram: CLIBridgeAdapter -> CLIBridgeManager, SSE -> WebSocket
- Updated integration points for CLIBridgeManager
- Updated code examples

### requirements/projects/message-queuing/IMPLEMENTATION-PLAN.md
- Updated CLIBridgeAdapter references to CLIBridgeManager
- Updated SSE references to WebSocket

### requirements/projects/firebase-integration/guides/01-firebase-console.md
- Updated sse_reconnect_delay_ms to websocket_reconnect_delay_ms

### requirements/projects/firebase-integration/guides/06-remote-config.md
- Updated sse_reconnect_delay_ms to websocket_reconnect_delay_ms

### requirements/projects/firebase-integration/IMPLEMENTATION-PLAN.md
- Updated sse_reconnect_delay_ms to websocket_reconnect_delay_ms

### requirements/projects/firebase-integration/REVIEW-NOTES.md
- Updated sse_reconnect_delay_ms to websocket_reconnect_delay_ms

### README.md
- Updated backend description, diagram, component table, and endpoints to WebSocket
- Removed CLIBridgeAdapter reference

### AGENTS.md
- Updated key file references to CLIBridgeManager and CLIBridgeAPIClient
