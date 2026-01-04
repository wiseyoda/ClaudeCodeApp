# Architectural Gaps


### Navigation Pattern Conflict - NEED!

| Aspect | Current                                         | Redesign                    |
| ------ | ----------------------------------------------- | --------------------------- |
| iPhone | Tab-based (MainTabView) with HomeView card grid | NavigationSplitView sidebar |
| iPad   | Sidebar + Detail                                | NavigationSplitView (same)  |

**Decision:** iPhone uses TabView for primary sections with a simplified Home/Projects surface; "New Project" moves to a prominent primary action (not a tab). iPad stays on NavigationSplitView.

### State Management Not Migrated - ASSESS NEED?

| Current File             | Lines  | Purpose                | Issue Mentioned |
| ------------------------ | ------ | ---------------------- | --------------- |
| `ErrorStore.swift`       | 5,650  | Error state management | Not mentioned   |
| `Models/TaskState.swift` | 8,864  | Task status enum       | Not mentioned   |
| `ProjectCache.swift`     | 11,364 | Project caching        | Not mentioned   |

**Decision:** Replace these stores with repository-layer caching and error pipelines to improve maintainability/scalability.

---
