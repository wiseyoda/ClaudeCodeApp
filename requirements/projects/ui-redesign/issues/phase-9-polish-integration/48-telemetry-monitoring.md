---
number: 48
title: Telemetry and Performance Monitoring
phase: phase-9-polish-integration
status: pending
completed_by: null
completed_at: null
verified_by: null
verified_at: null
commit: null
spot_checked: false
blocked_reason: null
---

# Issue 48: Telemetry and Performance Monitoring

**Phase:** 9 (Polish & Integration)
**Priority:** Medium
**Status:** Not Started
**Depends On:** 40 (Testing Strategy), 44 (Debug Tooling), 45 (Feature Flags)

## Goal

Establish privacy-respecting telemetry and performance monitoring plumbing for production readiness, with provider-agnostic interfaces (Firebase integration after redesign).

## Scope

- In scope:
  - Provider-agnostic telemetry protocol and schema.
  - Local batching/backoff logic and Diagnostics previews.
  - App launch timing, message render/scroll performance, WebSocket stability metrics, and high-level feature usage events.
- Out of scope:
  - Advertising analytics, cohort profiling, or third-party data enrichment.
  - Any provider SDK integration (Firebase deferred to the Firebase project).

## Non-goals

- No user tracking beyond operational metrics.

## Dependencies

- Issue 40 for performance targets.
- Issue 44 for logging and diagnostic hooks.
- Issue 45 for rollout controls.

## Touch Set

- Files to create: `CodingBridge/Monitoring/TelemetryManager.swift`, `CodingBridge/Monitoring/TelemetryEvent.swift`.
- Files to modify: key view models (ChatViewModel, SessionStore), `CodingBridge/App/CodingBridgeApp.swift`.

## Interface Definitions

- `TelemetryEvent` schema with strict field allowlist.
- `TelemetryManager` protocol with batching and backoff.
- Redaction rules for file paths and user content.
- `TelemetryProvider` enum or strategy holder (local only; Firebase later).

## Edge Cases

- Offline sessions and delayed flush.
- High-frequency events (scroll, typing) should be throttled.
- Privacy opt-out toggles mid-session.

## Acceptance Criteria

- [ ] Performance metrics recorded for launch and long-session scroll.
- [ ] Event payloads exclude message content and file contents.
- [ ] Opt-out supported and persisted.
- [ ] Debug logging available to validate payloads.
- [ ] Provider integration explicitly deferred (no Firebase SDK in redesign).

## Tests

- [ ] Unit tests for event schema validation and redaction.
- [ ] Integration test for batching and retry logic (mock transport).
