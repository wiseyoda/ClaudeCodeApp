# Codebase Simplification Project

> **Project Type**: Technical debt reduction
> **Status**: Active
> **Source of Truth**: Individual issue files in `./issues/`

---

## Purpose

Systematically reduce codebase complexity to improve debugging speed and developer experience.

**Trigger**: 8+ hours lost debugging ChatView after KV Store implementation due to accumulated workarounds, indirection layers, and callback spaghetti.

## Goals

| Goal | What Success Looks Like |
|------|------------------------|
| **Reduce indirection** | Fewer layers to trace when debugging |
| **Improve type safety** | Typed enums instead of callback closures |
| **Eliminate dead code** | Remove unused typealiases, adapters, legacy paths |
| **Consolidate state** | Single source of truth for related concerns |
| **Align with iOS idioms** | SwiftUI patterns, Foundation APIs, protocol-oriented design |

## Non-Goals

These are explicitly **OUT OF SCOPE** for this project:

- **New features** - Cleanup only. No new functionality.
- **UI changes** - No user-visible changes unless required for simplification.
- **Performance optimization** - Unless complexity reduction naturally improves it.
- **Refactoring working code** - If it works and is simple, leave it alone.
- **Breaking API contracts** - External-facing behavior must remain identical.

---

## How This Project Works

### Issue Files Are the Source of Truth

Each issue lives in `./issues/` as a standalone markdown file. Issue files contain:

- Complete problem description
- Specific files and functions to modify
- Step-by-step implementation plan
- Acceptance criteria
- Verification commands

**Do not duplicate issue details in this README.** If you need to know what issues exist or their status, look in `./issues/`.

### Finding Issues

```bash
# List all issues
ls -la requirements/projects/codebase-simplification/issues/

# Find issues by status
grep -l "Status.*Pending" requirements/projects/codebase-simplification/issues/*.md
grep -l "Status.*Complete" requirements/projects/codebase-simplification/issues/*.md
```

### Issue File Naming

```
{number}-{short-name}.md

Examples:
  01-remove-typealiases.md
  09-callback-consolidation.md
  17-remove-adapter.md
```

### Creating New Issues

1. Copy `ISSUE-TEMPLATE.md` to `issues/{number}-{short-name}.md`
2. Fill in all sections completely
3. Ensure the issue is self-contained (no external dependencies for understanding)

---

## Agent Instructions

> **CRITICAL**: Read this section completely before starting any work.

### What "Simplification" Means

Simplification is **removing indirection, not adding abstraction**. The correct response to complexity is often deletion, not reorganization.

**DO:**
- Delete unused code paths
- Inline trivial wrappers
- Replace callbacks with enums
- Use Foundation APIs instead of custom implementations
- Merge related state into single sources of truth

**DO NOT:**
- Add new abstraction layers to "organize" complexity
- Create generic frameworks for one-off use cases
- Refactor code that isn't covered by an issue file
- Make "improvements" beyond the specific task
- Add comments/docs to unchanged code

### Execution Rules

1. **Read the issue file first** - Each issue is self-contained with all context needed
2. **One issue at a time** - Complete and verify before moving to next
3. **Check dependencies** - Some issues depend on others; issue files specify this
4. **Build must pass** - Run `xcodebuild` after every change
5. **No scope creep** - If you find related problems, create a new issue file
6. **Preserve behavior** - All user-facing functionality must remain identical
7. **Update issue status** - Mark complete only after verification passes

### When You Find New Problems

If you discover something that should be simplified but isn't covered by an existing issue:

1. **Do not fix it inline** - Stay focused on current task
2. **Create a new issue file** - Use ISSUE-TEMPLATE.md
3. **Continue current work** - Address new issue separately

---

## Verification

Every completed issue must pass these checks:

### Build Verification

```bash
xcodebuild -project CodingBridge.xcodeproj -scheme CodingBridge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'
```

### Quality Checks

- [ ] Build succeeds with no new warnings
- [ ] App launches in simulator
- [ ] Basic functionality works (send message, view history)
- [ ] No user-visible behavior changes

### Issue-Specific Verification

Each issue file contains additional verification commands specific to that task. Run those as well.

---

## Project Structure

```
codebase-simplification/
├── README.md              # This file - project overview and agent instructions
├── ISSUE-TEMPLATE.md      # Template for creating new issue files
└── issues/                # Individual issue files (source of truth)
    ├── NN-short-name.md
    ├── NN-short-name.md
    └── ...
```

---

## Context

### Why This Project Exists

The CodingBridge codebase grew organically during rapid feature development. Technical debt accumulated in predictable patterns:

- **Adapter pattern overuse** - Wrapper layers that forward 1:1
- **Callback proliferation** - Many separate callbacks instead of typed events
- **Migration cruft** - Typealiases from API evolution still present
- **State duplication** - Same concepts tracked in multiple places

This debt compounds: debugging requires tracing through extra layers, understanding scattered callbacks, and mapping aliases back to actual types.

### Guiding Principles

1. **Delete over refactor** - Removing code is better than reorganizing it
2. **Explicit over clever** - Clear code beats elegant abstraction
3. **Single source of truth** - One place for each piece of state
4. **iOS idioms** - Use platform patterns, not custom solutions
5. **Best solution, not workaround** - Fix problems at the right layer (see cli-bridge section)

---

## Working with cli-bridge

CodingBridge is an iOS client for the [cli-bridge](https://github.com/wiseyoda/cli-bridge) backend. Some simplification issues may be best solved by changes to cli-bridge rather than workarounds in the iOS client.

### Always Use the Best Solution

**Do not create iOS workarounds when the right fix is in cli-bridge.**

When evaluating a simplification task, ask:
- Is this complexity caused by a cli-bridge API limitation?
- Would a small backend change eliminate significant iOS code?
- Is the iOS code compensating for missing server-side data?

If yes, the best solution may be a cli-bridge change.

### Development Setup

> **IMPORTANT**: All work on this project uses `localhost:3100` only. Do not test against the production QNAP server (`172.20.0.2`).

We have full access to cli-bridge source code for testing:

```bash
# cli-bridge source location
~/dev/cli-bridge/

# Start dev server (REQUIRED before testing)
cd ~/dev/cli-bridge && deno task dev

# Verify server is running
curl -s http://localhost:3100/health

# View OpenAPI spec
curl -s http://localhost:3100/openapi.json
open http://localhost:3100/docs
```

**Before starting any work:**
1. Start the local cli-bridge dev server
2. Ensure app settings point to `http://localhost:3100`
3. Verify connectivity with `curl -s http://localhost:3100/health`

This ensures we can test API changes locally without affecting production.

### Requesting cli-bridge Changes

The cli-bridge team has an established workflow for hardening and testing changes. **They should implement cli-bridge fixes, not us.**

**For small changes** (e.g., "add field X to response Y"):
- Document the request in the issue file under a "cli-bridge Request" section
- Include the specific API change needed
- Tag as blocked on cli-bridge if iOS work depends on it

**For larger changes** (e.g., new endpoint, breaking change, architectural):
- Create a GitHub issue: https://github.com/wiseyoda/cli-bridge/issues
- Link the GitHub issue in the iOS issue file
- Wait for cli-bridge team to implement and deploy

### Issue File Format for cli-bridge Dependencies

When an issue requires cli-bridge changes, add this section to the issue file:

```markdown
## cli-bridge Dependency

**Change Required**: {Description of what cli-bridge needs to do}

**API Impact**:
- Endpoint: `{method} {path}`
- Change: {Add field / New endpoint / Modify behavior}

**GitHub Issue**: {link if created, or "Not yet filed - small change"}

**Status**: Pending cli-bridge | cli-bridge Complete | N/A
```

### When to Create a cli-bridge GitHub Issue

| Scope | Action |
|-------|--------|
| Add a field to existing response | Document in iOS issue file |
| Add optional parameter to existing endpoint | Document in iOS issue file |
| New endpoint | Create GitHub issue |
| Breaking change to existing endpoint | Create GitHub issue |
| Architectural change | Create GitHub issue |

---

## References

- [ROADMAP.md](../../../ROADMAP.md) - High-level project tracking
- [ARCHITECTURE.md](../../ARCHITECTURE.md) - System architecture
- [CHANGELOG.md](../../../CHANGELOG.md) - Version history

---

_Project created: January 2, 2026_
