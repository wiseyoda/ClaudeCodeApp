---
number: 70
title: Status Message Collection System
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

# Issue 70: Status Message Collection System

**Phase:** 3 (Interactions & Status)
**Priority:** High
**Status:** Not Started
**Depends On:** Issue #17 (Liquid Glass), Issue #26 (Chat View Redesign), Issue #27 (Settings Redesign)

## Goal

Deliver a streaming-only status banner with collectible messages, plus a Settings-based collection view.

## Scope

- In scope:
  - Status banner above the input bar while streaming (not tappable).
  - Status message collection system with rarity tiers and progress tracking.
  - Time-of-day filtering and seasonal variants.
  - Animated banner styling (shimmer, typewriter ellipsis, tool-colored accents).
  - Message collection UI in Settings.
- Out of scope:
  - Backend persistence or cross-device sync.
  - Push notifications for collection events.

## Non-goals

- Replace chat status banners for tool progress (see Issue #09).

## Dependencies

- Issue #17 (Liquid Glass) for styling.
- Issue #26 (Chat View Redesign) for banner placement.
- Issue #27 (Settings Redesign) for collection access.

## Touch Set

- Files to create:
  - `CodingBridge/Managers/StatusMessageStore.swift`
  - `CodingBridge/Models/StatusMessage.swift`
  - `CodingBridge/Views/StatusMessageBannerView.swift`
  - `CodingBridge/Views/MessageCollectionView.swift`
- Files to modify:
  - `CodingBridge/Views/ChatView.swift`
  - `CodingBridge/Views/Settings/DiagnosticsView.swift` (if collection is nested there)
  - `CodingBridge/AppSettings.swift` (toggle if needed)

## Interface Definitions

- `StatusMessage` model with rarity, season, and time-of-day metadata.
- `StatusMessageStore` for message rotation, collection progress, and unlocks.

## Edge Cases

- No messages unlocked: show starter set and locked placeholders.
- Streaming starts/stops quickly: banner should not flicker.
- Reduce Motion enabled: disable shimmer and typewriter effects.

## Acceptance Criteria

- [ ] Status banner shows only while streaming and is not tappable.
- [ ] Collection view shows rarity progress and seasonal variants.
- [ ] Status messages rotate without repetition within a short window.
- [ ] Banner adapts to tool accent color when available.

## Tests

- [ ] Unit tests for `StatusMessageStore` selection and unlock logic.
- [ ] UI tests for banner visibility and collection screen layout.

## Implementation

- Add `StatusMessageStore` as a shared manager with:
  - rarity tiers (common/uncommon/rare/legendary)
  - time-of-day buckets (morning/afternoon/evening)
  - seasonal overrides
  - progress tracking by tier
- Implement `StatusMessageBannerView` with shimmer text, animated ellipsis, and elapsed time display after 10s.
- Add a Settings entry to open `MessageCollectionView`.
