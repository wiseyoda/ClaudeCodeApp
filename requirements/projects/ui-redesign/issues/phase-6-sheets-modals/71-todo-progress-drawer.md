---
number: 71
title: Todo Progress Drawer
phase: phase-6-sheets-modals
status: pending
completed_by: null
completed_at: null
verified_by: null
verified_at: null
commit: null
spot_checked: false
blocked_reason: null
---

# Issue 71: Todo Progress Drawer

**Phase:** 6 (Sheets & Modals)
**Priority:** High
**Status:** Not Started
**Depends On:** Issue #05 (ToolCardView), Issue #34 (Sheet System)

## Goal

Provide a persistent, lightweight drawer that summarizes todo progress and lets users expand for details.

## Scope

- In scope:
  - `TodoProgressDrawer` UI component surfaced from TodoWrite tool results.
  - Collapsible progress summary with percent complete and remaining count.
  - Expand to show full checklist state (read-only).
- Out of scope:
  - Editing todo items inline.
  - Syncing todo state to external systems.

## Non-goals

- Replace the in-card Todo checklist; the drawer complements it.

## Dependencies

- Issue #05 (ToolCardView) for TodoWrite rendering.
- Issue #34 (Sheet System) for drawer presentation mechanics.

## Touch Set

- Files to create:
  - `CodingBridge/Views/Interactions/TodoProgressDrawer.swift`
- Files to modify:
  - `CodingBridge/Views/Messages/Cards/ToolCardView.swift`
  - `CodingBridge/ViewModels/ChatViewModel.swift` (hook drawer state)

## Interface Definitions

- `TodoProgressState` with total, completed, remaining, and source toolUseId.

## Edge Cases

- No todos present: drawer hidden.
- Multiple TodoWrite steps in a session: use the most recent active list.
- Very long lists: show truncated preview with "View All".

## Acceptance Criteria

- [ ] Drawer appears when a TodoWrite tool is active or recently completed.
- [ ] Shows accurate progress and supports expand/collapse.
- [ ] Does not obstruct input or interaction cards.

## Tests

- [ ] Unit tests for progress calculation.
- [ ] UI tests for drawer show/hide and expansion.

## Implementation

- Parse TodoWrite output into `TodoProgressState`.
- Render a compact drawer above the input bar (or within the interaction stack).
- Use glass materials and match Liquid Glass spacing/typography.
