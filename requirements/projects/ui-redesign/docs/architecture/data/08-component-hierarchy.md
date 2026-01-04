# Component Hierarchy


```
ChatView
├── InteractionContainerView           # Unified user prompts (Liquid Glass)
│   ├── PermissionInteraction
│   ├── PlanModeInteraction
│   └── QuestionInteraction
│
├── MessageListView                    # Virtualized list
│   └── MessageCardRouter              # Routes by role
│       ├── ChatCardView               # user, assistant (Liquid Glass)
│       │   └── (no status banner)
│       ├── ToolCardView               # toolUse, toolResult (Liquid Glass)
│       │   └── StatusBannerOverlay    # Shows progress/subagent
│       └── SystemCardView             # error, system, etc. (Liquid Glass)
│           └── (no status banner)
│
└── InputView (Liquid Glass)
```

---
