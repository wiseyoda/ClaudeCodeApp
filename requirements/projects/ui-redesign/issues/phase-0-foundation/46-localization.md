# Issue 46: Localization Strategy

**Phase:** 0 (Foundation)
**Priority:** Medium
**Status:** Not Started
**Depends On:** None

## Goal

Ensure all user-visible strings are localizable using String Catalogs.

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

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
