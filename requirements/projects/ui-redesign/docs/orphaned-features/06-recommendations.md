# Recommendations


### Immediate Actions

1. **Create dedicated issues for Critical items (with decisions captured):**

   - Status Message Collection System
   - Status banner placement above input bar (streaming-only)
   - StatusBubbleView animations
   - Message Grouping/Compaction (core)
   - WritePreview full-screen viewer

2. **Document iPhone navigation migration:**

   - Add to Issue #23 or create new issue
   - iPhone uses TabView + simplified Home/Projects surface; "New Project" is a primary action (not a tab); iPad stays NavigationSplitView

3. **Document redesign decisions for high-priority behavior:**
   - Local command palette + autocomplete (iPad hardware keyboard)
   - System message subtype rendering
   - cli-bridge git status fields + unknown state fallback
   - Offline resume via cli-bridge replay/timeout (lightweight client handling)
   - Centralized haptics with a global Settings toggle

### Add to Existing Issues

| Orphaned Feature      | Suggested Issue                                    |
| --------------------- | -------------------------------------------------- |
| WritePreviewView      | Issue #05 (ToolCardView)                           |
| LocalCommand handling | Issue #06 (SystemCardView) or Issue #26 (ChatView) |
| SearchHistoryStore    | Issue #33 (GlobalSearch)                           |
| TodoProgressDrawer    | Issue #05 (ToolCardView)                           |
| GitStatusCoordinator  | Remove; replace with cli-bridge status             |

### Document What Gets Removed

The redesign should explicitly list features that are intentionally being dropped with rationale:

```markdown
## Intentionally Removed Features

| Feature   | Rationale |
| --------- | --------- |
| (example) | (example) |
```

---
