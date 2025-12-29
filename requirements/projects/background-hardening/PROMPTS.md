# Background Hardening Prompts

Copy/paste these prompts to work on the background hardening feature.

---

## Start New Work

```
Implement background hardening for CodingBridge iOS app.

Read the project docs in this order:
1. requirements/projects/background-hardening/00-INDEX.md (navigation)
2. requirements/projects/background-hardening/01-GOALS.md (success criteria)
3. requirements/projects/background-hardening/02-STATES.md (state machine)
4. requirements/projects/background-hardening/03-ARCHITECTURE.md (components)

Then read the Phase 1 checklist:
- requirements/projects/background-hardening/phase-1/checklist.md

Work through Phase 1 systematically:
1. Read each component doc before implementing
2. Check off items in the checklist as you complete them
3. Run tests after each component
4. Don't move to Phase 2 until Phase 1 checklist is complete

Key files to modify:
- CodingBridge/Managers/ (new manager files)
- CodingBridge/Models/ (TaskState)
- CodingBridgeApp.swift (registration)
- Info.plist (background modes)

Start by reading the docs, then create a todo list and begin implementation.
```

---

## Resume Work

```
Resume background hardening implementation for CodingBridge.

1. Read requirements/projects/background-hardening/00-INDEX.md for project overview

2. Check current progress:
   - Read phase-1/checklist.md, phase-2/checklist.md, phase-3/checklist.md
   - Look for checked items [x] vs unchecked [ ]
   - Identify which phase we're in

3. Check git status for any work in progress:
   - Look for new/modified files in CodingBridge/Managers/
   - Check for BackgroundManager.swift, LiveActivityManager.swift, etc.

4. Determine next task:
   - If Phase 1 incomplete: read phase-1/ docs, continue checklist
   - If Phase 2 incomplete: read phase-2/ docs, continue checklist
   - If Phase 3 incomplete: read phase-3/ docs, continue checklist

5. Create a todo list with remaining items and continue implementation.

Reference docs are in ref/ for edge cases, settings, privacy, etc.
```

---

## Quick Reference Commands

### Check Phase Progress
```
Show me the current progress on background-hardening by reading all three checklist files and summarizing what's done vs remaining.
```

### Implement Specific Component
```
Implement [BackgroundManager/LiveActivityManager/NotificationManager/etc] for background-hardening.

Read the relevant doc first:
- requirements/projects/background-hardening/phase-X/[component].md

Then implement following the code examples, run tests, and update the checklist.
```

### Review Implementation
```
Review the background-hardening implementation so far.

1. Read the architecture doc: requirements/projects/background-hardening/03-ARCHITECTURE.md
2. Check which manager files exist in CodingBridge/Managers/
3. Verify they match the specs in the phase docs
4. Identify any gaps or issues
```

---

## Tips for Best Results

1. **Always read docs first** - The phase docs have exact code to implement
2. **Work phase by phase** - Don't skip ahead, dependencies matter
3. **Update checklists** - Mark items complete as you go
4. **Test incrementally** - Build and test after each component
5. **Reference ref/ docs** - Edge cases, settings, privacy considerations
