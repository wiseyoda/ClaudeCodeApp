---
number: 72
title: Background Continuity
phase: phase-8-ios26-platform
status: pending
completed_by: null
completed_at: null
verified_by: null
verified_at: null
commit: null
spot_checked: false
blocked_reason: null
---

# Issue 72: Background Continuity

**Phase:** 8 (iOS 26 Platform)
**Priority:** High
**Status:** Not Started
**Depends On:** Issue #26 (Chat View Redesign), Issue #66 (State Restoration)

## Goal

Support short background task switching so users can briefly leave the app and return without losing an active session.

## Scope

- In scope:
  - Lightweight background continuation for task switching (target ~30 minutes if iOS allows).
  - Preserve streaming state and pending approvals via cli-bridge.
  - User-facing messaging when background time expires.
- Out of scope:
  - Long-running background processing for hours.
  - Background execution for offline work.

## Non-goals

- Keep-alive hacks that violate platform rules.

## Dependencies

- Issue #26 (Chat View Redesign) for streaming state.
- Issue #66 (State Restoration) for resume behavior.
- cli-bridge connection policies and timeout messaging.

## Touch Set

- Files to create:
  - `CodingBridge/Managers/BackgroundManager.swift`
- Files to modify:
  - `CodingBridge/Managers/CLIBridgeManager.swift`
  - `CodingBridge/Views/ChatView.swift`

## Interface Definitions

- `BackgroundSessionState` tracking active stream, start time, and timeout deadline.

## Edge Cases

- App returns after background timeout: show cli-bridge timeout system message.
- System denies background time: fall back to state restoration on foreground.
- Multiple scenes: ensure background tracking per scene.

## Acceptance Criteria

- [ ] Short background task switching does not drop active session immediately.
- [ ] User sees a clear timeout message when background time expires.
- [ ] No Firebase-specific logic is introduced (future integration).

## Tests

- [ ] Unit tests for background state tracking.
- [ ] UI tests for resume/timeout messaging.

## Implementation

- Use iOS background task APIs to request short continuation time.
- Keep work lightweight; defer heavy processing to cli-bridge.
- Coordinate with state restoration to rebuild UI on return.
