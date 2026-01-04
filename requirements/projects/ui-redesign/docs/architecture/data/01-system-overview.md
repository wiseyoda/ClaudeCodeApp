# System Overview


```
                                    ┌─────────────────────────────┐
                                    │      Stream Events          │
                                    │  (WebSocket from backend)   │
                                    └──────────────┬──────────────┘
                                                   │
                    ┌──────────────────────────────┼──────────────────────────────┐
                    │                              │                              │
                    ▼                              ▼                              ▼
         ┌──────────────────┐         ┌──────────────────┐         ┌──────────────────┐
         │ MessageNormalizer │         │ InteractionHandler│         │ CardStatusTracker│
         │  (Result types)  │         │  (@MainActor)    │         │     (actor)      │
         └────────┬─────────┘         └────────┬─────────┘         └────────┬─────────┘
                  │                            │                            │
                  ▼                            ▼                            ▼
         ┌──────────────────┐         ┌──────────────────┐         ┌──────────────────┐
         │ MessageCardRouter │         │InteractionContainer│        │StatusBannerOverlay│
         │  (Liquid Glass)  │         │  (Liquid Glass)  │         │  (Liquid Glass)  │
         └────────┬─────────┘         └──────────────────┘         └──────────────────┘
                  │
     ┌────────────┼────────────┐
     ▼            ▼            ▼
┌─────────┐ ┌──────────┐ ┌───────────┐
│ChatCard │ │ ToolCard │ │SystemCard │
└─────────┘ └──────────┘ └───────────┘
```

---
