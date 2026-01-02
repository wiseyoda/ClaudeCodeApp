# Issue #5: Consolidate stores into a single persistence layer

> **Status**: Won't Fix (verified 2026-01-02)
> **Priority**: Tier 2
> **Depends On**: #23/#25
> **Blocks**: #16/#42/#43 (unblocked - see Resolution below)

---

## Summary

Implement roadmap task: Consolidate stores into a single persistence layer.

## Resolution: Won't Fix

**Date**: 2026-01-02

After completing issues #23 and #25, a comprehensive audit was performed on all persistence stores in the codebase. The conclusion is that **further consolidation would add abstraction without removing complexity**, violating the core principle of the simplification project.

### Audit Findings

| Store | Persistence | Scope | Purpose |
|-------|-------------|-------|---------|
| MessageStore | File | Per-project | Chat messages, drafts, session IDs |
| BookmarkStore | File | Global | Cross-session bookmarks |
| ArchivedProjectsStore | UserDefaults | Global | Hidden project paths |
| CommandStore | File | Global | Saved commands |
| IdeasStore | File | Per-project | Ideas per project |
| SessionStore | API | N/A | API-backed, no local persistence |
| ProjectSettingsStore | File | Global | Per-project overrides |
| SearchHistoryStore | UserDefaults | Global | Search queries |
| StatusMessageStore | UserDefaults | Global | Message collection progress |
| ErrorAnalyticsStore | File | Global | Error tracking |
| ErrorStore | Memory | Global | In-memory error display |

### Why Consolidation Is Not Needed

1. **No state duplication exists** - Each store manages a distinct concern
2. **Issues #23/#25 already resolved the actual problems**:
   - #23 unified draft + processing persistence into MessageStore
   - #25 deleted MessageQueuePersistence dead code
3. **Different scopes require different approaches**:
   - Per-project stores use path-encoded filenames
   - Global stores use single files
   - API-backed stores have no local persistence
4. **Current architecture follows iOS best practices**:
   - Codable for serialization
   - Documents directory for file storage
   - Background queues for thread safety
5. **A "unified layer" would add indirection**:
   - New abstraction over working code
   - More complexity, not less
   - Risk of bugs in stable code

### Impact on Dependent Issues

The blocked issues (#16, #42, #43) are **not actually blocked** by this decision:

- **#16 (activeSheet enum)**: UI state consolidation, unrelated to persistence
- **#42 (Split ChatViewModel)**: Can proceed without persistence changes
- **#43 (Split Models.swift)**: Can split files without unifying persistence

These issues should be unblocked in the dependency graph.

---

## Original Problem Statement

Current implementation adds indirection or duplication, which slows debugging and makes behavior harder to reason about.

**Finding**: After #23/#25, there is no remaining indirection or duplication in persistence. The stores are intentionally separate because they serve different purposes.

---

## Acceptance Criteria

- [x] Audit completed - stores reviewed
- [x] No actionable consolidation identified
- [x] Decision documented with rationale

---

## Completion Log

| Date | Action | Outcome |
|------|--------|---------|
| 2026-01-02 | Comprehensive audit of all stores | 11 stores identified, no duplication found |
| 2026-01-02 | Marked Won't Fix | Adding abstraction would violate simplification goals |
| 2026-01-02 | Verified | Dependencies removed and roadmap aligned |
