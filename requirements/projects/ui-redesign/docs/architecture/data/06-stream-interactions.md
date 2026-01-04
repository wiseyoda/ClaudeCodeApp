# Stream Interactions


### Unified Interaction Types

```swift
enum InteractionType: Identifiable {
    case permission(ApprovalRequest)
    case planMode(ApprovalRequest)
    case question(AskUserQuestionData)

    var id: String {
        switch self {
        case .permission(let req): return "permission-\(req.id)"
        case .planMode(let req): return "plan-\(req.id)"
        case .question(let q): return "question-\(q.requestId)"
        }
    }

    var priority: Int {
        switch self {
        case .question: return 0    // Highest - blocks on answer
        case .planMode: return 1    // User reviewing plan
        case .permission: return 2  // Can timeout
        }
    }
}
```

### Unified Interaction UI (Liquid Glass)

All interactions use the same card structure with Liquid Glass:

```
┌─────────────────────────────────────┐
│              ═══                    │  ← Drag indicator
│                                     │
│  [Icon]  Title                      │  ← Header (consistent)
│          Subtitle/description       │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  (content varies by type)   │   │  ← Content area
│  └─────────────────────────────┘   │
│                                     │
│  [Cancel]              [Primary]   │  ← Actions (consistent)
└─────────────────────────────────────┘
        ↑ .glassEffect() applied
```

---
