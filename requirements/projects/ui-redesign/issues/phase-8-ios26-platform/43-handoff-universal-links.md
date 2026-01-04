# Issue 43: Handoff & Universal Links

**Phase:** 8 (iOS 26 Platform)
**Priority:** Low
**Status:** Not Started
**Depends On:** Issue #23 (Navigation), Issue #26 (Chat View)

## Goal

Enable continuity across devices for active sessions and shared links.

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- Depends On: Issue #23 (Navigation), Issue #26 (Chat View).
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

### Handoff (NSUserActivity)

```swift
struct ChatView: View {
    let session: Session

    var body: some View {
        MessageListView(messages: session.messages)
            .userActivity("com.codingbridge.session") { activity in
                activity.title = session.title
                activity.userInfo = ["sessionId": session.id]
                activity.isEligibleForHandoff = true
                activity.isEligibleForSearch = true
            }
    }
}
```

### Universal Links

- Define a URL scheme like `https://codingbridge.app/session/{id}`.
- Route to the session in `onOpenURL` / `onContinueUserActivity`.

### Deep Link Schema

```
codingbridge://project/{encoded-path}
codingbridge://session/{encoded-path}/{sessionId}
codingbridge://settings
codingbridge://terminal
```

## Files to Modify

- `CodingBridgeApp.swift` (handle `onOpenURL`, `onContinueUserActivity`)
- `NavigationDestination.swift` (session deep link)

## Acceptance Criteria

- [ ] Active session continues on another device via Handoff
- [ ] Universal link opens correct session
- [ ] Invalid links show a user-friendly error
- [ ] Handoff activity is cleared on session delete

## Testing

- Manual: open session on one device, continue on another
- Verify universal link routing
