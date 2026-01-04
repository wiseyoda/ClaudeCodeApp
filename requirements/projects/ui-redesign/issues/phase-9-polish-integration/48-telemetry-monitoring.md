# Issue 48: Telemetry and Performance Monitoring

**Phase:** 9 (Polish & Integration)
**Priority:** Medium
**Status:** Not Started
**Depends On:** 40 (Testing Strategy), 44 (Debug Tooling), 45 (Feature Flags)

## Goal

Establish privacy-respecting telemetry and performance monitoring for production readiness.

## Scope

- In scope: app launch timing, message render/scroll performance, WebSocket stability metrics, and high-level feature usage events.
- Out of scope: advertising analytics, cohort profiling, or third-party data enrichment.

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

## Edge Cases

- Offline sessions and delayed flush.
- High-frequency events (scroll, typing) should be throttled.
- Privacy opt-out toggles mid-session.

## Acceptance Criteria

- [ ] Performance metrics recorded for launch and long-session scroll.
- [ ] Event payloads exclude message content and file contents.
- [ ] Opt-out supported and persisted.
- [ ] Debug logging available to validate payloads.

## Tests

- [ ] Unit tests for event schema validation and redaction.
- [ ] Integration test for batching and retry logic (mock transport).
