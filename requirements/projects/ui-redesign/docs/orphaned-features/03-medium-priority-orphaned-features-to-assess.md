# Medium Priority Orphaned Features - TO ASSESS


| File                                      | Bytes  | Purpose                                                                       | Decision                               |
| ----------------------------------------- | ------ | ----------------------------------------------------------------------------- | -------------------------------------- |
| `Utilities/NetworkMonitor.swift`          | 4,451  | Connection type detection (WiFi/cellular/wired), expensive/constrained status | Keep; drive offline banner + expensive network behavior |
| `Managers/BackgroundManager.swift`        | 7,848  | BGContinuedProcessingTask for long operations                                 | Keep; support short background task switching (target ~30 min if iOS allows) and keep work lightweight; lean on cli-bridge now, stay Firebase-ready |
| `Utilities/SearchHistoryStore.swift`      | 2,004  | Recent search query storage (max 10)                                          | Keep                                  |
| `ErrorAnalyticsStore.swift`               | 9,277  | Error analytics collection                                                    | Merge into Diagnostics now; provider-agnostic hooks, Firebase later |
| `Views/ErrorInsightsView.swift`           | 10,860 | Error insights dashboard                                                      | Merge into Diagnostics                 |
| `ToolErrorClassification.swift`           | 14,148 | Classify tool errors by type                                                  | Keep                                  |
| `ProjectNamesStore.swift`                 | 1,082  | Custom project display names                                                  | Keep                                  |
| `Persistence/ArchivedProjectsStore.swift` | 1,315  | Project archiving                                                             | Keep                                  |
| `Views/TodoProgressDrawer.swift`          | 6,394  | Todo progress tracking drawer                                                 | Keep (explicit requirement)            |
| `UserQuestionsView.swift`                 | 11,296 | User question display                                                         | Keep; show questions as a modal/pull-up over chat |
| `Views/ProjectCard.swift`                 | 10,775 | Glass card with git status, session count, branch badges                      | Keep concept; simplify for large project lists; iOS 26.2 best practice |
| `Views/SkeletonView.swift`                | 4,837  | Loading placeholder skeletons                                                 | Keep if best-practice for loading states |
| `Views/MessageActionBar.swift`            | 7,092  | Action buttons on messages                                                    | Keep                                  |

---
