---
number: 52
title: Error Recovery UI
phase: phase-3-interactions-status
status: pending
completed_by: null
completed_at: null
verified_by: null
verified_at: null
commit: null
spot_checked: false
blocked_reason: null
---

# Issue 52: Error Recovery UI

**Phase:** 3 (Interactions & Status)
**Priority:** High
**Status:** Not Started
**Depends On:** 08 (Stream Interaction Handler), 09 (Card Status Banners), 63 (Error Type Hierarchy)

## Goal

Provide user-facing recovery UI for errors, retries, and offline states.

## Decisions

- Use ToolErrorClassification to map tool failures into user-facing recovery cards.
- Offline banners and reconnect prompts should use NetworkMonitor for connection type and constrained/expensive hints.

## Scope

- In scope:
  - Error banners and blocking sheets
  - Retry/abort actions
  - Offline and reconnect UI
- Out of scope:
  - Backend retry logic changes

## Non-goals

- TBD.

## Dependencies

- 08 (Stream Interaction Handler), 09 (Card Status Banners), 63 (Error Type Hierarchy).

## Touch Set

- Files to create: TBD.
- Files to modify: TBD.

## Interface Definitions

- List new or changed models, protocols, and API payloads.

## Edge Cases

- TBD.

## Acceptance Criteria

- [ ] Meets the Goal and Scope.
- [ ] Definition of Done checklist satisfied.

## Tests

- [ ] Unit tests updated or added.
- [ ] UI tests updated or added (if user flows change).

## Implementation

TBD.
