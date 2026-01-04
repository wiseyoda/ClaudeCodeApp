---
number: 46
title: Localization
phase: phase-0-foundation
priority: Medium
depends_on: null
acceptance_criteria: 3
files_to_touch: 0
status: pending
completed_by: null
completed_at: null
verified_by: null
verified_at: null
commit: null
spot_checked: false
blocked_reason: null
---

# Issue 46: Localization Strategy

**Phase:** 0 (Foundation)
**Priority:** Medium
**Status:** Not Started
**Depends On:** None

## Required Documentation

Before starting work on this issue, review these architecture and design documents:

### Design System
- **[Localization](../../docs/design/12-localization.md)** - CRITICAL: String Catalogs, LocalizedStringResource patterns

### Foundation
- **[Design Decisions](../../docs/overview/design-decisions.md)** - Localization decisions

### Workflows
- **[Execution Guardrails](../../docs/workflows/guardrails.md)** - Development rules and constraints

## Goal

Ensure all user-visible strings are localizable using String Catalogs.

## Scope
- In scope:
  - Create a String Catalog for redesign strings and define key conventions.
  - Migrate user-visible strings in redesigned views to `LocalizedStringResource`.
  - Add pluralization entries for counts and token usage.
  - Document non-localizable strings (tool names, backend-controlled text).
  - English-only strings for redesign scope; catalog ready for future translations.
- Out of scope:
  - Full translation for all languages in this phase.
  - Retrofitting untouched legacy screens.
  - Localization of backend-sourced content.

## Non-goals
- Introduce RTL layout or locale-specific layout changes.
- Replace typography or layout purely for localization.
- Add runtime language switching UI.

## Dependencies
- See **Depends On** header; add runtime or tooling dependencies here.

## Tests
- [ ] Unit tests updated or added.
- [ ] UI tests updated or added (if user flows change).
## Strategy

- Use `.xcstrings` String Catalogs (Xcode 15+).
- Prefer `LocalizedStringResource` in SwiftUI views.
- Define a key naming convention: `feature.section.key`.
- Handle plurals with `String.localizedStringWithFormat` and catalog variants.

## Migration Steps

- Create a `CodingBridge.xcstrings` catalog for new redesign strings.
- Replace hardcoded strings in redesigned views with catalog keys.
- Add pluralization entries for counts and token usage.
- Document any non-localizable strings (e.g., tool names).

## Touch Set

- `CodingBridge/Features/`
- `CodingBridge/Design/`
- `CodingBridge/Localization/`

## Interface Definitions

```swift
enum LocalizationKeys {
    static let settingsConnectionTitle = "settings.connection.title"
    static let sessionsCount = "sessions.count"
}
```

## Examples

```swift
Text("settings.connection.title") // LocalizedStringResource key

Text(String.localizedStringWithFormat(
    NSLocalizedString("sessions.count", comment: ""),
    count
))
```

## Edge Cases

- Missing keys: fallback to English and log once.
- Pluralization for zero/one/many cases.

## Acceptance Criteria

- [ ] All new views use String Catalog keys
- [ ] Pluralization handled for counts
- [ ] No hardcoded user-visible strings added in redesign

## Testing

- Manual: switch system language and verify key screens.
