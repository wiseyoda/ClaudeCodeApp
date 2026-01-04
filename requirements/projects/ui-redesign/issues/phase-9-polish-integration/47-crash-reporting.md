---
number: 47
title: Crash Reporting
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

# Issue 47: Crash Reporting

**Phase:** 9 (Polish & Integration)
**Priority:** High
**Status:** Not Started
**Depends On:** 44 (Debug Tooling), 45 (Feature Flags)

## Goal

Define crash reporting plumbing with privacy-respecting defaults and release gating, using a provider-agnostic interface (Firebase integration happens after redesign).

## Scope

- In scope:
  - Provider-agnostic crash reporting protocol and configuration.
  - Local capture hooks (non-fatal errors) wired into Diagnostics.
  - Environment gating and opt-in/opt-out controls.
- Out of scope:
  - Product analytics, growth tracking, or cross-app attribution.
  - Any provider SDK integration (Firebase deferred to the Firebase project).

## Non-goals

- No marketing analytics or user-level profiling.

## Dependencies

- Issue 44 for debug logging hooks.
- Issue 45 for rollout controls and kill switches.

## Touch Set

- Files to create: `CodingBridge/Monitoring/CrashReporter.swift` (protocol + local no-op/logging implementation).
- Files to modify: `CodingBridge/App/CodingBridgeApp.swift`, `CodingBridge/AppSettings.swift`.

## Interface Definitions

- `CrashReporter` protocol with `start()`, `record(error:)`, `setUserContext(_:)`.
- `CrashReportingConfig` with build channel (debug/beta/release), opt-in state, and redaction rules.
- `CrashReporterProvider` enum or strategy holder (local only; Firebase later).

## Edge Cases

- Offline startup or provider endpoint outage.
- User opts out or privacy mode enabled.
- Crash in early app init before dependencies are ready.

## Acceptance Criteria

- [ ] Crash reporter initializes only for beta/release builds (or explicit opt-in).
- [ ] PII and file contents are redacted by default.
- [ ] Symbolication pipeline documented and verified.
- [ ] Kill switch available via feature flags.
- [ ] Provider integration explicitly deferred (no Firebase SDK in redesign).

## Tests

- [ ] Unit tests for config gating and redaction rules.
- [ ] Smoke test in beta build to confirm crash ingestion.
