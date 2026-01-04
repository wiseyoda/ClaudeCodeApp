---
number: 08
title: Stream Interaction Handler
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

# Issue 08: Stream Interaction Handler

**Phase:** 3 (Interactions & Status)
**Priority:** High
**Status:** Not Started
**Depends On:** Issue 01 (Design Tokens), Issue 02 (Reusable Components)

## Goal
Define and implement Stream Interaction Handler as described in this spec.

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- Depends On: Issue 01 (Design Tokens), Issue 02 (Reusable Components).
- Add runtime or tooling dependencies here.

## Touch Set
- Files to create: TBD.
- Files to modify: TBD.

## Interface Definitions
- List new or changed models, protocols, and API payloads.

## Tests
- [ ] Unit tests updated or added.
- [ ] UI tests updated or added (if user flows change).
## Problem

Currently three separate UIs handle stream interactions requiring user action:

| Interaction | Current UI | Location |
|-------------|------------|----------|
| Permission Request | `ApprovalBannerView` (banner) | ChatView status section |
| Exit Plan Mode | `ExitPlanModeApprovalView` (sheet) | ChatView sheet overlay |
| Ask User Question | `UserQuestionsView` (sheet) | ChatView sheet overlay |

This leads to:
- Inconsistent UX (banner vs sheet)
- Duplicated action handling patterns
- No unified prioritization when multiple interactions pending
- Scattered state management across ChatViewModel

## Solution

Create a unified `StreamInteractionHandler` that:
1. Manages all pending interactions in a queue
2. Presents consistent UI for all interaction types
3. Handles prioritization (questions > plan mode > permissions)
4. Provides unified dismiss/complete patterns
5. Presents Ask User Questions as a modal/pull-up over chat

## Files to Create

```
CodingBridge/Views/Interactions/
├── StreamInteractionHandler.swift    # Manager + container view
├── InteractionCard.swift             # Base card for all interactions
├── PermissionInteraction.swift       # Permission request UI
├── PlanModeInteraction.swift         # Exit plan mode UI
├── QuestionInteraction.swift         # Ask user question UI
└── InteractionQueue.swift            # Queue management
```

## Design

### InteractionType Enum

```swift
enum InteractionType: Identifiable {
    case permission(ApprovalRequest)
    case planMode(ApprovalRequest)      // isExitPlanMode == true
    case question(AskUserQuestionData)

    var id: String {
        switch self {
        case .permission(let request): return "permission-\(request.id)"
        case .planMode(let request): return "plan-\(request.id)"
        case .question(let data): return "question-\(data.requestId)"
        }
    }

    var priority: Int {
        switch self {
        case .question: return 0        // Highest - blocks on answer
        case .planMode: return 1        // User reviewing plan
        case .permission: return 2      // Can timeout
        }
    }
}
```

### Interface Definitions

```swift
typealias PermissionResponseHandler = (ApprovalRequest, PermissionChoice) -> Void
typealias QuestionResponseHandler = (AskUserQuestionData) -> Void
```

### StreamInteractionHandler

```swift
@MainActor
@Observable
final class StreamInteractionHandler {
    private(set) var pendingInteractions: [InteractionType] = []

    /// The interaction currently being shown to user
    var currentInteraction: InteractionType? {
        pendingInteractions.sorted { $0.priority < $1.priority }.first
    }

    /// Add new interaction to queue
    func enqueue(_ interaction: InteractionType) {
        pendingInteractions.append(interaction)
    }

    /// Remove interaction after user action
    func complete(_ interaction: InteractionType) {
        pendingInteractions.removeAll { $0.id == interaction.id }
    }

    /// Clear all interactions (session end/error)
    func clearAll() {
        pendingInteractions.removeAll()
    }
}
```

### InteractionContainerView

```swift
struct InteractionContainerView: View {
    @Bindable var handler: StreamInteractionHandler
    let onPermissionResponse: PermissionResponseHandler
    let onQuestionAnswer: QuestionResponseHandler

    var body: some View {
        if let interaction = handler.currentInteraction {
            InteractionCard {
                switch interaction {
                case .permission(let request):
                    PermissionInteraction(
                        request: request,
                        onResponse: { choice in
                            onPermissionResponse(request, choice)
                            handler.complete(interaction)
                        }
                    )

                case .planMode(let request):
                    PlanModeInteraction(
                        request: request,
                        onApprove: {
                            onPermissionResponse(request, .allow)
                            handler.complete(interaction)
                        },
                        onReject: {
                            onPermissionResponse(request, .deny)
                            handler.complete(interaction)
                        }
                    )

                case .question(let data):
                    QuestionInteraction(
                        data: data,
                        onSubmit: { answered in
                            onQuestionAnswer(answered)
                            handler.complete(interaction)
                        }
                    )
                }
            }
        }
    }
}
```

### Unified InteractionCard

```swift
struct InteractionCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(.secondary.opacity(0.5))
                .frame(width: 36, height: 4)
                .padding(.top, MessageDesignSystem.Spacing.sm)

            content()
                .padding(MessageDesignSystem.Spacing.cardPadding)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: MessageDesignSystem.CornerRadius.xl))
        .shadow(radius: 10)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
```

## UI Design

All interactions use the same card structure:

```
┌─────────────────────────────────────┐
│              ═══                    │  ← Drag indicator
│                                     │
│  [Icon]  Title                      │  ← Header
│          Subtitle/description       │
│                                     │
│  ┌─────────────────────────────┐   │
│  │                             │   │  ← Content area
│  │  (varies by type)           │   │
│  │                             │   │
│  └─────────────────────────────┘   │
│                                     │
│  [Cancel]              [Primary]   │  ← Actions
└─────────────────────────────────────┘
```

### Permission Interaction

```
[🔧]  Bash Tool
      Execute: npm install

      ⚠️ Timeout in 4:32

[Deny]  [Always Allow]  [Approve]
```

### Plan Mode Interaction

```
[📋]  Review Plan
      Claude has created an implementation plan

┌─────────────────────────────────┐
│  ## Implementation Steps        │
│  1. Create new file...          │  ← Scrollable markdown
│  2. Update imports...           │
└─────────────────────────────────┘

[Reject]                [Approve]
```

### Question Interaction

```
[❓]  Claude needs input
      Which approach should we use?

      ○ Option A - Fast but limited
      ● Option B - Comprehensive (Recommended)
      ○ Other: [________________]

[Cancel]                 [Submit]
```

## Integration with ChatView

Replace scattered state with unified handler:

```swift
// Before (in ChatView)
@State private var showQuestions = false
// Computed: exitPlanModeBinding
// In viewModel: pendingApproval, pendingQuestion

// After
@State private var interactionHandler = StreamInteractionHandler()

// In ChatViewModel+StreamEvents
case .permissionRequest(let msg):
    let request = ApprovalRequest(from: msg)
    if request.isExitPlanMode {
        interactionHandler.enqueue(.planMode(request))
    } else {
        interactionHandler.enqueue(.permission(request))
    }

case .questionRequest(let msg):
    let data = AskUserQuestionData(from: msg)
    interactionHandler.enqueue(.question(data))
```

## Cleanup

When final result message received:

```swift
case .result(let msg):
    // Clear any pending interactions that weren't explicitly handled
interactionHandler.clearAll()
```

## Edge Cases

- WebSocket drops mid-approval: keep the current interaction visible and retry response when reconnected.
- Permission request times out: expire the interaction and show a transient banner.
- Question request arrives while another question is pending: queue in priority order.
- Session changes while interaction active: clear interactions and show a brief notice.

## Acceptance Criteria

- [ ] StreamInteractionHandler manages all pending interactions
- [ ] Unified InteractionCard UI for all types
- [ ] Priority-based presentation (question > plan > permission)
- [ ] Permission timeout still works
- [ ] Plan mode markdown rendering preserved
- [ ] Question multi-select/single-select preserved
- [ ] Interactions cleared on session end
- [ ] Files linked in project.pbxproj
- [ ] Build passes

## Migration

1. Create new interaction files
2. Update ChatViewModel to use StreamInteractionHandler
3. Update ChatView to use InteractionContainerView
4. Remove old:
   - `ApprovalBannerView.swift` (move logic to PermissionInteraction)
   - `ExitPlanModeApprovalView` (move to PlanModeInteraction)
   - `UserQuestionsView.swift` (move to QuestionInteraction)

## Testing

```swift
class StreamInteractionHandlerTests: XCTestCase {
    func testPriorityOrder() {
        let handler = StreamInteractionHandler()
        handler.enqueue(.permission(mockPermission))
        handler.enqueue(.question(mockQuestion))

        // Question should be current (higher priority)
        XCTAssertEqual(handler.currentInteraction?.priority, 0)
    }

    func testClearAll() {
        let handler = StreamInteractionHandler()
        handler.enqueue(.permission(mockPermission))
        handler.enqueue(.planMode(mockPlan))

        handler.clearAll()
        XCTAssertNil(handler.currentInteraction)
    }
}
```

## Test Examples

TBD. Add XCTest examples before implementation.
