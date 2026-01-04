---
number: 42
title: Spotlight Integration
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

# Issue 42: Spotlight Integration

**Phase:** 8 (iOS 26 Platform)
**Priority:** Medium
**Status:** Not Started
**Depends On:** Issue #26 (Chat View), Issue #32 (Session Picker)

## Goal

Index projects, sessions, and key messages in Spotlight for fast system-wide search.

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- Depends On: Issue #26 (Chat View), Issue #32 (Session Picker).
- Add runtime or tooling dependencies here.

## Touch Set
- Files to create: TBD.
- Files to modify: TBD.

## Interface Definitions
- List new or changed models, protocols, and API payloads.

## Edge Cases
- TBD.

## Tests
- [ ] Unit tests updated or added.
- [ ] UI tests updated or added (if user flows change).
## Implementation

### Searchable Items

```swift
import CoreSpotlight
import UniformTypeIdentifiers

func indexSession(_ session: Session, project: Project) async {
    let attributes = CSSearchableItemAttributeSet(contentType: .text)
    attributes.title = "\(project.displayName) — \(session.title)"
    attributes.contentDescription = session.summary
    attributes.keywords = [project.displayName, session.title]

    let item = CSSearchableItem(
        uniqueIdentifier: "session-\(session.id)",
        domainIdentifier: "sessions",
        attributeSet: attributes
    )

    try? CSSearchableIndex.default().indexSearchableItems([item])
}
```

### Deep Linking

- Store enough metadata in `userInfo` to open the session.
- Use `onContinueUserActivity` in the app scene to route to the session view.

## Security & Privacy

- Do not index secrets or file contents.
- Only index user-visible text (session titles, summaries).
- Offer a setting to disable Spotlight indexing.

## Files to Create

```
CodingBridge/Platform/Spotlight/
├── SpotlightIndexer.swift         # ~80 lines
└── SpotlightCoordinator.swift     # ~60 lines
```

## Acceptance Criteria

- [ ] Projects and sessions appear in Spotlight
- [ ] Selecting a result opens the correct session
- [ ] Index updates on rename or delete
- [ ] User can disable Spotlight indexing
- [ ] No sensitive data indexed

## Testing

- Manual: search for project/session names in Spotlight
- Verify deep link opens correct view
