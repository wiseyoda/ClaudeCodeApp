# Issue 07: Integration & Cleanup

**Phase:** 9 (Polish & Integration)
**Priority:** Medium
**Status:** Not Started
**Depends On:** All Phase 4 issues

## Goal

Integrate new card views, update dependent files, remove old code.

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- Depends On: All Phase 4 issues.
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
## Tasks

### 1. Update CompactToolView.swift

Update to use MessageCardRouter instead of inline rendering.

```swift
// Before
switch displayItem {
case .single(let message):
    CLIMessageView(message: message, ...)

// After
switch displayItem {
case .single(let message):
    MessageCardRouter(message: message, ...)
```

### 2. Update ChatView.swift

Ensure ChatView uses MessageCardRouter for all message rendering.

### 3. Verify All Functionality

| Feature | Test |
|---------|------|
| User messages | Send message, verify display |
| Assistant messages | Receive response, verify markdown |
| Tool use | Trigger tool, verify collapsed display |
| Tool result | View result, verify expansion |
| Error display | Trigger error, verify red styling |
| Thinking blocks | Enable thinking, verify display |
| Local commands | Run /help, verify display |
| Copy action | Copy message, verify clipboard |
| Bookmark action | Bookmark message, verify state |
| Context menu | Long press, verify options |
| Collapse/expand | Toggle tool cards |
| Image attachments | Attach image, verify display |

### 4. Remove Old Files

After verification:

```bash
# Backup first
git stash

# Remove old CLIMessageView.swift
rm CodingBridge/Views/CLIMessageView.swift

# Update project.pbxproj to remove reference
```

### 5. Update Documentation

- Update docs/architecture/data and docs/architecture/ui with new component hierarchy
- Update any references to CLIMessageView

## Per-File Migration Map

### CLIMessageView.swift (~1000 lines)

- Header rendering (role icon/title) -> `ChatCardView`
- Tool invocation blocks -> `ToolCardView` (collapsed header + expanded content)
- System/error/thinking blocks -> `SystemCardView`
- Context menus -> `MessageCardProtocol` + `MessageCardActions`
- Inline markdown/code blocks -> `MarkdownText` / `CodeBlockView`

### ChatView.swift

- Inline ScrollView -> `MessageListView`
- Approval/question overlays -> `InteractionContainerView`
- Status bar components -> `StatusBarView`

### ApprovalBannerView.swift / ExitPlanModeApprovalView.swift / UserQuestionsView.swift

- Replace with `PermissionInteraction`, `PlanModeInteraction`, `QuestionInteraction`

## Regression Tests

Run existing tests to ensure no regressions:

```bash
xcodebuild test -project CodingBridge.xcodeproj -scheme CodingBridge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'
```

## Acceptance Criteria

- [ ] CompactToolView uses MessageCardRouter
- [ ] ChatView uses MessageCardRouter
- [ ] All existing functionality works
- [ ] All tests pass
- [ ] Old CLIMessageView.swift removed
- [ ] Documentation updated
- [ ] No console warnings or errors

## Rollback Plan

If issues found after integration:

1. Restore CLIMessageView.swift from git
2. Revert CompactToolView changes
3. Keep new card views for gradual migration
4. Use FeatureFlags (Issue #45) to switch between old/new

```swift
FeatureFlags.useNewCardViews = false

// In ChatView
if useNewCardViews {
    MessageCardRouter(message: message, ...)
} else {
    CLIMessageView(message: message, ...)
}
```

## Performance Validation

Compare scroll performance:

1. Load 100+ messages
2. Scroll rapidly up/down
3. Monitor for dropped frames
4. Compare CPU usage with old implementation

If performance issues found:
- Check MessageCardCache is being used
- Verify no redundant view updates
- Profile with Instruments

## Code Examples

TBD. Add concrete Swift examples before implementation.
