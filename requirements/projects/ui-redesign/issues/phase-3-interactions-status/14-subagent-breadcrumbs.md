# Issue 14: Subagent Breadcrumb Trail

**Phase:** 3 (Interactions & Status)
**Priority:** Medium
**Status:** Not Started
**Depends On:** Issue 09 (Card Status Banners)

## Goal

Show parent → child relationship for subagent/Task tool calls with a breadcrumb trail in the card header.

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- Depends On: Issue 09 (Card Status Banners).
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
## Current State

- Subagent messages appear in flat timeline
- No visual hierarchy showing parent-child relationships
- Hard to track which agent spawned which

## Solution

### SubagentContext Tracking

```swift
actor SubagentContextTracker {
    private var agentStack: [SubagentInfo] = []

    func breadcrumbs() -> [SubagentBreadcrumb] {
        agentStack.map { SubagentBreadcrumb(id: $0.id, name: $0.displayName) }
    }

    func pushAgent(_ info: SubagentInfo) {
        agentStack.append(info)
    }

    func popAgent(id: String) {
        if let index = agentStack.firstIndex(where: { $0.id == id }) {
            agentStack.removeSubrange(index...)
        }
    }

    func clear() {
        agentStack.removeAll()
    }
}

struct SubagentBreadcrumb: Identifiable {
    let id: String
    let name: String
}

struct SubagentInfo: Identifiable {
    let id: String
    let displayName: String
    let description: String
    let startTime: Date
}
```

### BreadcrumbTrailView

```swift
struct BreadcrumbTrailView: View {
    let breadcrumbs: [SubagentBreadcrumb]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MessageDesignSystem.Spacing.xs) {
                ForEach(Array(breadcrumbs.enumerated()), id: \.element.id) { index, crumb in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }

                    BreadcrumbChip(
                        name: crumb.name,
                        isLast: index == breadcrumbs.count - 1
                    )
                }
            }
        }
    }
}

struct BreadcrumbChip: View {
    let name: String
    let isLast: Bool

    var body: some View {
        Text(name)
            .font(MessageDesignSystem.labelFont())
            .foregroundStyle(isLast ? .primary : .secondary)
            .padding(.horizontal, MessageDesignSystem.Spacing.sm)
            .padding(.vertical, MessageDesignSystem.Spacing.xxs)
            .background(isLast ? .purple.opacity(0.15) : .quaternary)
            .clipShape(Capsule())
    }
}
```

### Integration with StatusBannerOverlay

```swift
struct StatusBannerOverlay: View {
    let state: StatusBannerState
    let breadcrumbs: [SubagentBreadcrumb]  // NEW

    var body: some View {
        VStack(alignment: .leading, spacing: MessageDesignSystem.Spacing.xs) {
            // Breadcrumb trail (if any)
            if !breadcrumbs.isEmpty {
                BreadcrumbTrailView(breadcrumbs: breadcrumbs)
            }

            // Status content
            HStack(spacing: MessageDesignSystem.Spacing.sm) {
                statusIcon
                statusText
                Spacer()
                progressIndicator
            }
        }
        .font(MessageDesignSystem.labelFont())
        .padding(.horizontal, MessageDesignSystem.Spacing.cardPadding)
        .padding(.vertical, MessageDesignSystem.Spacing.sm)
        .background(bannerBackground)
    }
}
```

### Event Handling

```swift
// In ChatViewModel+StreamEvents
case .subagentStart(let msg):
    let info = SubagentInfo(
        id: msg.id,
        displayName: msg.displayAgentType,
        description: msg.description,
        startTime: .now
    )
    await subagentTracker.pushAgent(info)
    await cardStatusTracker.startSubagent(toolUseId: msg.id, info: ...)

case .subagentComplete(let msg):
    await subagentTracker.popAgent(id: msg.id)
    await cardStatusTracker.complete(toolUseId: msg.id)

case .result(let msg):
    await subagentTracker.clear()
    await cardStatusTracker.clearAll()
```

### Visual Example

```
┌─────────────────────────────────────────────────────────────────┐
│  [Explore] → [code-reviewer] → [grep-analyzer]                  │  ← Breadcrumbs
│  ⚙️ grep-analyzer  "Searching for patterns..."   [12s]         │  ← Status
├─────────────────────────────────────────────────────────────────┤
│ 🔧 Task                                                         │
│    Explore codebase for authentication patterns                 │
└─────────────────────────────────────────────────────────────────┘
```

### Collapsed Breadcrumb (Many Levels)

When breadcrumb trail is > 3 levels, collapse middle:

```
[Root] → ... → [code-reviewer] → [current-agent]
```

```swift
extension BreadcrumbTrailView {
    private var displayBreadcrumbs: [SubagentBreadcrumb] {
        if breadcrumbs.count <= 3 {
            return breadcrumbs
        }

        // Show first, ellipsis indicator, last two
        return [
            breadcrumbs.first!,
            SubagentBreadcrumb(id: "ellipsis", name: "..."),
            breadcrumbs[breadcrumbs.count - 2],
            breadcrumbs.last!
        ]
    }
}
```

## Files to Create

```
CodingBridge/ViewModels/
└── SubagentContextTracker.swift

CodingBridge/Views/Messages/Components/
└── BreadcrumbTrailView.swift
```

## Files to Modify

| File | Changes |
|------|---------|
| `StatusBannerOverlay.swift` | Add breadcrumbs parameter |
| `CardStatusTracker.swift` | Track parent-child relationships |
| `ChatViewModel+StreamEvents.swift` | Update subagentTracker on events |
| `MessageCardRouter.swift` | Pass breadcrumbs to status overlay |

## Acceptance Criteria

- [ ] Subagent breadcrumb trail shows in status banner
- [ ] Trail updates as agents spawn/complete
- [ ] Collapsed view for deep hierarchies (>3 levels)
- [ ] Current agent highlighted
- [ ] Trail clears on session end
- [ ] Build passes

## Future Enhancement

Could add:
- Tap breadcrumb to scroll to that agent's messages
- Expand collapsed breadcrumb on tap
- Animate breadcrumb additions/removals
