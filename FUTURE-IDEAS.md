# Future Ideas

> Ambitious feature ideas that could make ClaudeCodeApp a killer app. These are longer-term visions, not immediate priorities. See ROADMAP.md for current work.

---

## Implemented Ideas

### Contextual AI Copilot (POC)
Smart suggestions that understand your project context.

**Status:** Implemented Dec 27, 2025

**What's Working:**
- `ClaudeHelper` service sends recent messages to Haiku
- Returns JSON array of 3 suggested actions with labels, prompts, and icons
- `SuggestionChipsView` displays tappable chips below input
- Chips appear after Claude completes a response
- Tapping a chip sends the suggested prompt immediately
- ~100-200 tokens per call (fractions of a cent)

**Future Enhancements:**
- Pattern learning across sessions (persisted suggestions)
- Project-specific suggestion tuning
- Confidence scoring for suggestions

### Smart Context Injection (Partial POC)
Auto-attach relevant files to every message.

**Status:** Partial implementation Dec 27, 2025

**What's Working:**
- `ClaudeHelper.suggestRelevantFiles()` analyzes conversation context
- File picker shows "Suggested" section with AI-recommended files
- Uses Haiku to match conversation topics to available files
- Sparkle icon distinguishes AI suggestions from regular files

**Remaining Work:**
- Auto-attach without opening file picker
- Pin files to always include
- Token usage meter
- Proactive suggestions in chat

### Ideas Drawer
Capture ideas during long-running Claude operations.

**Status:** Implemented Dec 27, 2025

**What's Working:**
- `IdeasStore` for per-project idea persistence (JSON in Documents)
- `Idea` struct with text, title, tags, timestamps, AI enhancement fields
- `IdeasFAB` floating action button with count badge
- `QuickCaptureSheet` for rapid idea capture via long-press on FAB
- `IdeasDrawerSheet` for full idea management
- `IdeaEditorSheet` for editing with title, content, tags
- `TagsFlowView` for tag UI
- Archive/restore functionality
- Search and filter by tag

**Future Enhancements:**
- AI enhancement integration (expand prompt, suggest follow-ups)
- Convert ideas to prompts with one tap
- Idea templates for common patterns

---

## Priority Ideas

### 1. Voice-Driven Coding Mode

Hands-free coding for commuting/walking.

**Concept:**
- Continuous voice conversation with Claude
- Audio readback of responses (text-to-speech)
- "Hey Claude, what's the status of my build?" with audio response
- Bluetooth headphone support with play/pause controls
- Background audio session for multitasking

**Why it's compelling:** Code review and planning during your commute. Unique differentiator.

**Effort:** Medium (extends existing SpeechManager, adds AVSpeechSynthesizer)

---

### 2. Approval Queue Widget

iOS Lock Screen widget for tool approvals.

**Concept:**
- See pending Claude tool requests at a glance
- Quick approve/reject without opening app
- "Claude wants to run: git push" with [Approve] [Deny]
- Home screen widget showing active session status
- Live Activity for long-running tasks

**Why it's compelling:** Don't miss Claude's requests while multitasking.

**Effort:** Medium (WidgetKit, App Intents, push notifications)

---

### 3. Project Timeline / Activity Feed

Visual history of everything that happened in a project.

**Concept:**
- Timeline showing: commits, sessions, tool executions, errors
- "What happened yesterday?" at a glance
- Searchable activity log across all sessions
- Diff snapshots at key points
- Filter by activity type (git, tools, errors)

**Why it's compelling:** Context switching is hard. See exactly where you left off.

**Effort:** Medium (aggregates existing data, new UI)

---

### 4. Shareable Session Links

Share Claude conversations with teammates.

**Concept:**
- Generate a link to a session (or session excerpt)
- Optional: embed as code gist/GitHub discussion
- Read-only viewer that renders tool outputs properly
- "Here's how I fixed that bug" - sharable proof of work
- QR code for quick sharing

**Why it's compelling:** Team collaboration and knowledge sharing. Great for async teams.

**Effort:** Medium (requires backend support or static export)

---

### 5. Workflow Automation (Recipes)

Multi-step automation chains.

**Concept:**
- "When I say 'deploy', run tests -> commit -> push -> create PR"
- Visual recipe builder with drag-and-drop steps
- Conditional logic: "If tests fail, stop and show me"
- Scheduled recipes: "Every morning, show me failing tests"
- Share recipes with team

**Why it's compelling:** Goes beyond single commands to full automation.

**Effort:** High (visual builder, scheduling, conditionals)

---

### 6. Split View Code Editor

View/edit files alongside chat.

**Concept:**
- Show file contents in split view while chatting
- Tap code references in chat to open the file
- Make quick edits without asking Claude
- Real-time diff preview before Claude commits
- Syntax highlighting with language detection

**Why it's compelling:** iPad becomes a legitimate dev environment.

**Effort:** High (requires code editor component, syntax highlighting)

---

### 7. AI-Powered Code Search

Natural language search across your entire codebase.

**Concept:**
- "Find where we handle authentication errors"
- "Show functions that call the database"
- Semantic search, not just grep
- Cross-project search with project selection
- Results ranked by relevance

**Why it's compelling:** Natural language is more accessible than grep.

**Effort:** High (requires embeddings, semantic search infrastructure)

---

### 8. Session Templates

Preset conversation starters with system prompts.

**Concept:**
- "Code Review" template: pre-loaded with review guidelines
- "Bug Fix" template: structured debugging workflow
- "New Feature" template: architecture-first approach
- Share templates via export/import
- Template marketplace or community sharing

**Why it's compelling:** Consistent quality across sessions. Encode team best practices.

**Effort:** Low-Medium (extends Command Library concept)

---

## Impact vs Effort Matrix

```
                    HIGH IMPACT
                         |
    Workflow Automation  |   Approval Widget
                         |   Voice Mode
                         |
    ─────────────────────┼─────────────────────
    AI Code Search       |   Session Templates
    Split View Editor    |   Project Timeline
                         |   Shareable Links
                         |
                    LOW IMPACT

         HIGH EFFORT              LOW EFFORT
```

---

## Recommended Exploration Order

If exploring these ideas, consider this sequence:

1. **Session Templates** - Low effort, builds on Command Library (which is now done)
2. **Approval Queue Widget** - High visibility, solves real pain point
3. **Voice-Driven Mode** - Unique differentiator, extends existing speech code
4. **Project Timeline** - Aggregates existing data in new way
5. **Shareable Links** - Medium effort, high team value

---

## Dependencies & Prerequisites

| Feature | Requires |
|---------|----------|
| Voice Mode | AVSpeechSynthesizer, background audio |
| Project Timeline | Git log parsing, session aggregation |
| Shareable Links | Backend support or static HTML export |
| Workflow Automation | Already has Command Library foundation |
| Split View Editor | Syntax highlighting library |
| AI Code Search | Embeddings API, vector search |
| Approval Widget | WidgetKit, push notification infrastructure |
| Session Templates | Already has Command Library foundation |

---

## Notes

- These ideas emerged from a comprehensive code review of the current app
- Many build on existing infrastructure (SSH, WebSocket, file browser)
- Voice Mode and Approval Widget have highest unique value
- Some features (AI Search) may require backend changes
- Consider user research before major investment

---

*Created: December 27, 2025*
*Updated: December 27, 2025*
