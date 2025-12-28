# Future Ideas

> Strategic feature proposals for Coding Bridge. These ideas represent the longer-term vision for transforming mobile AI-assisted development. For committed work, see [ROADMAP.md](ROADMAP.md).

---

## Product Vision

**Coding Bridge is the only native mobile client for AI-assisted development.** While desktop tools require sitting at a computer, Coding Bridge meets developers where they are: commuting, walking, reviewing code between meetings, or capturing ideas before they slip away.

Our mission: **Make mobile the best place for AI-assisted development planning, review, and monitoring.**

We will not try to compete with desktop IDEs for writing code. Instead, we lean into what mobile does uniquely well:
- **Always with you** - Capture ideas instantly, review code anywhere
- **Voice-first** - Hands-free interactions during commutes and walks
- **Glanceable** - Quick status checks via widgets and Live Activities
- **Proactive** - Push approvals and notifications that fit your workflow

---

## Strategic Themes

### Theme 1: Voice-First Development
Transform commute time into productive development time with conversational AI interactions.

### Theme 2: Platform-Native Intelligence
Leverage WidgetKit, App Intents, Shortcuts, and Live Activities to make Claude a first-class iOS citizen.

### Theme 3: Seamless Context Switching
Enable effortless handoff between mobile and desktop, multiple servers, and team collaboration.

### Theme 4: Proactive Assistance
Move from reactive chat to proactive suggestions, approvals, and status updates.

### Theme 5: Developer Workflow Integration
Integrate with the tools developers already use: GitHub, Shortcuts, automation workflows.

---

## Feature Proposals

### 1. Voice Conversation Mode

**Status:** [ ] Approved for Roadmap

**Theme:** Voice-First Development

**Problem Statement:**
Developers cannot use Coding Bridge during activities where hands are occupied (commuting, walking, exercising). The current voice input captures speech but requires looking at the screen to read responses, limiting mobile utility.

**User Stories:**
- As a developer commuting on a train, I want to have a voice conversation with Claude so that I can review code or plan features without looking at my phone
- As a developer walking between meetings, I want Claude to read responses aloud so that I can stay productive
- As an iPad user with accessibility needs, I want full voice control so that I can use the app hands-free

**Proposed Solution:**
Add a "Voice Mode" that enables continuous bidirectional voice conversation with Claude, including text-to-speech for responses.

**Key Functionality:**
- [ ] Voice activation ("Hey Claude" or button press)
- [ ] Text-to-speech response readback using AVSpeechSynthesizer
- [ ] Bluetooth headphone support with play/pause controls
- [ ] Background audio session for multitasking
- [ ] Speed control for response readback (0.5x to 2x)
- [ ] Interrupt response with new voice command
- [ ] Visual waveform when listening/speaking

**Success Metrics:**
- Voice mode sessions lasting over 5 minutes
- Percentage of users enabling voice mode at least once per week
- User satisfaction score for voice interactions

**Technical Considerations:**
- Dependencies: Existing SpeechManager infrastructure
- Complexity: Medium
- Platform APIs: AVSpeechSynthesizer, AVAudioSession, MPRemoteCommandCenter
- Backend needs: None (text-based interaction unchanged)

**Competitive Analysis:**
No competitor offers voice conversation mode for AI-assisted development. ChatGPT mobile has voice but not in a development context.

**Open Questions:**
- Should we use system TTS or integrate a neural voice API?
- How to handle code snippets in voice output?
- Privacy implications of always-listening mode?

**Priority Score:** 9/10

---

### 2. Home Screen Widget

**Status:** [ ] Approved for Roadmap

**Theme:** Platform-Native Intelligence

**Problem Statement:**
Users must open the app to check project status, pending Claude requests, or recent activity. This friction reduces engagement and delays time-sensitive approvals.

**User Stories:**
- As a developer, I want to see my active Claude task status at a glance so that I know when tasks complete
- As a developer, I want to quickly launch into my most recent project so that I can continue where I left off
- As a team lead, I want to see pending approvals on my home screen so that I never miss a request

**Proposed Solution:**
Create a family of WidgetKit widgets providing at-a-glance project status and quick actions.

**Key Functionality:**
- [ ] Small widget: Active task status with progress indicator
- [ ] Medium widget: Recent projects with one-tap launch
- [ ] Large widget: Activity feed with last 3 actions
- [ ] Lock Screen widget: Current task status
- [ ] Quick action: Start new chat from widget

**Success Metrics:**
- Widget adoption rate (% of users with widget on home screen)
- Widget interaction rate (taps per day)
- Time-to-action reduction for pending approvals

**Technical Considerations:**
- Dependencies: App Groups for shared data, background refresh
- Complexity: Medium
- Platform APIs: WidgetKit, AppIntentConfiguration, TimelineProvider
- Backend needs: Lightweight status endpoint or local state sync

**Competitive Analysis:**
GitHub Mobile offers widgets for notifications. No AI coding assistant has widgets.

**Open Questions:**
- How to handle multiple servers in widgets?
- What refresh frequency balances battery vs freshness?
- Should widgets work offline with cached data?

**Priority Score:** 8/10

---

### 3. Live Activities for Long Tasks

**Status:** [ ] Approved for Roadmap

**Theme:** Platform-Native Intelligence

**Problem Statement:**
When Claude is running tests, building, or executing multi-step tasks, users must keep the app open or wait for a notification. There is no way to monitor progress without switching apps.

**User Stories:**
- As a developer, I want to see test progress on my Lock Screen so that I can monitor without unlocking
- As a developer, I want to see build status in the Dynamic Island so that I can multitask confidently
- As a developer, I want live progress updates so that I know my task is still running

**Proposed Solution:**
Implement Live Activities that appear on Lock Screen and Dynamic Island during long-running Claude operations.

**Key Functionality:**
- [ ] Start Live Activity when task begins (if estimated >30 seconds)
- [ ] Show current operation (testing, building, etc.) with progress
- [ ] Display elapsed time and estimated remaining
- [ ] Update via WebSocket events
- [ ] Tap to return to app
- [ ] End gracefully on completion or error

**Success Metrics:**
- Percentage of eligible tasks showing Live Activities
- User engagement with Live Activity (tap-to-open rate)
- Reduction in "check-in" app opens during tasks

**Technical Considerations:**
- Dependencies: Backend must send progress events
- Complexity: Medium
- Platform APIs: ActivityKit, Push Tokens for updates
- Backend needs: Progress events in WebSocket stream (may need backend change)

**Competitive Analysis:**
Sports apps and ride-sharing use Live Activities effectively. No development tools leverage this yet.

**Open Questions:**
- How to estimate task duration for progress bar?
- Should Live Activities work for all tasks or only specific types?
- How to handle tasks that run longer than the 8-hour limit?

**Priority Score:** 8/10

---

### 4. Siri Shortcuts Integration

**Status:** [ ] Approved for Roadmap

**Theme:** Platform-Native Intelligence

**Problem Statement:**
Users cannot trigger Claude actions via Siri or integrate Coding Bridge into iOS Shortcuts automations. This limits voice-only scenarios and automation possibilities.

**User Stories:**
- As a developer, I want to say "Hey Siri, check my build status" so that I can get updates hands-free
- As a developer, I want to create a Shortcut that runs my test suite when I arrive at work so that tests are ready when I sit down
- As a power user, I want to chain Claude commands with other Shortcuts so that I can build custom workflows

**Proposed Solution:**
Expose core Coding Bridge actions as App Intents for Siri and Shortcuts.

**Key Functionality:**
- [ ] Intent: Send message to Claude (with project selection)
- [ ] Intent: Check task status
- [ ] Intent: Get git status for project
- [ ] Intent: Run saved command by name
- [ ] Intent: Start new session in project
- [ ] Siri voice responses for status checks
- [ ] Shortcuts gallery with example workflows

**Success Metrics:**
- Number of Shortcut actions configured per user
- Siri invocations per week
- User-created automations

**Technical Considerations:**
- Dependencies: None (uses existing app functionality)
- Complexity: Medium
- Platform APIs: App Intents, SiriKit, Shortcuts
- Backend needs: None

**Competitive Analysis:**
GitHub Mobile has basic Shortcuts. No AI assistant has deep Shortcuts integration.

**Open Questions:**
- Should intents wait for task completion or return immediately?
- How to handle authentication in background Shortcuts?
- What parameters make sense for voice-only interactions?

**Priority Score:** 7/10

---

### 5. Approval Queue and Push Notifications

**Status:** [ ] Approved for Roadmap | **Foundation:** ✅ Basic approval UI complete

**Theme:** Proactive Assistance

**Foundation Implemented (December 2025):**
- `ApprovalBannerView` - Real-time approval UI for tool permission requests
- `ApprovalRequest/Response` models with WebSocket protocol
- Backend `canUseTool` callback in wiseyoda/claudecodeui fork
- This feature would extend the existing approval system with push notifications

**Problem Statement:**
When Claude needs permission to run a command, users only see the request if the app is open. Time-sensitive approvals (like deploying) may be delayed for hours.

**User Stories:**
- As a developer, I want push notifications when Claude needs approval so that I can unblock tasks quickly
- As a developer, I want to approve/reject from the notification so that I do not need to open the app
- As a team member, I want an approval queue so that I can handle multiple pending requests efficiently

**Proposed Solution:**
Implement push notification infrastructure for tool approvals with actionable notifications and a dedicated queue view.

**Key Functionality:**
- [ ] Push notifications for pending approvals
- [ ] Rich notification with command preview
- [ ] Quick actions: Approve / Deny / View Details
- [ ] Approval Queue view showing all pending requests
- [ ] Approve all / Deny all for batch operations
- [ ] Notification history with outcomes

**Success Metrics:**
- Time-to-approval reduction
- Percentage of approvals handled via notification (vs opening app)
- Push notification opt-in rate

**Technical Considerations:**
- Dependencies: APNs infrastructure, backend push support
- Complexity: High
- Platform APIs: UserNotifications, UNNotificationAction, UNNotificationCategory
- Backend needs: Push notification endpoint, persistent approval queue

**Competitive Analysis:**
GitHub has actionable notifications for PR reviews. This would be first for AI approvals.

**Open Questions:**
- How to implement push without a dedicated push server?
- Should approvals expire after a timeout?
- How to handle offline approvals?

**Priority Score:** 7/10

---

### 6. Multi-Server Support

**Status:** [ ] Approved for Roadmap

**Theme:** Seamless Context Switching

**Problem Statement:**
Users with multiple development environments (work, personal, different machines) must manually change server settings each time they switch contexts.

**User Stories:**
- As a developer, I want to save multiple server configurations so that I can switch between work and home easily
- As a consultant, I want to connect to different client servers so that I can manage multiple projects
- As a team member, I want to share server configurations so that onboarding is easier

**Proposed Solution:**
Allow saving, switching, and sharing multiple server configurations.

**Key Functionality:**
- [ ] Server configuration profiles (name, URL, SSH, credentials)
- [ ] Quick server switcher in settings and status bar
- [ ] Visual indicator of current server
- [ ] Export/import server configs (QR code or JSON)
- [ ] Per-server project and session data isolation
- [ ] Default server selection

**Concept:**
```
+-- Servers ----------------------+
| * Home NAS (connected)          |
|   10.0.1.50:8080                |
|                                 |
| o Work Server                   |
|   work.example.com:8080         |
|                                 |
| o Dev Container                 |
|   claude-dev:8080               |
|                                 |
| [+ Add Server]                  |
+---------------------------------+
```

**Success Metrics:**
- Number of saved servers per user
- Server switch frequency
- Reduction in settings changes

**Technical Considerations:**
- Dependencies: Refactor AppSettings to support multiple configs
- Complexity: Medium
- Platform APIs: Keychain for per-server credentials
- Backend needs: None

**Competitive Analysis:**
Database clients (TablePlus, DBeaver) handle multiple servers well. Apply patterns to this app.

**Open Questions:**
- How to migrate existing settings to multi-server model?
- Should projects be associated with servers or independent?
- How to handle iCloud sync across multiple servers?

**Priority Score:** 6/10

---

### 7. Session Sharing and Export

**Status:** [ ] Approved for Roadmap

**Theme:** Seamless Context Switching

**Problem Statement:**
Developers cannot easily share Claude conversations with teammates for code review, knowledge transfer, or debugging assistance.

**User Stories:**
- As a developer, I want to share a session link so that teammates can see how I solved a problem
- As a team lead, I want to export sessions for documentation so that we preserve institutional knowledge
- As a developer, I want to generate a gist from a session so that I can reference it in PRs

**Proposed Solution:**
Enable session export to multiple formats and optional link-based sharing.

**Key Functionality:**
- [ ] Export to Markdown with full tool output
- [ ] Export to PDF with syntax highlighting
- [ ] Generate shareable link (requires backend support)
- [ ] Create GitHub Gist from session
- [ ] QR code for quick sharing
- [ ] Read-only web viewer for shared sessions
- [ ] Bulk export project history

**Success Metrics:**
- Sessions exported per user per month
- Shared session view count
- Gist creation rate

**Technical Considerations:**
- Dependencies: PDF generation, markdown export (partial exists)
- Complexity: Medium (link sharing requires backend)
- Platform APIs: UIActivityViewController, PDFKit
- Backend needs: Session hosting endpoint for link sharing

**Competitive Analysis:**
ChatGPT has shareable links. No coding assistant has this for development sessions.

**Open Questions:**
- How long should shared links remain valid?
- Should shared sessions include tool outputs or just text?
- Privacy considerations for shared code?

**Priority Score:** 5/10

---

### 8. Project Timeline and Activity Feed

**Status:** [ ] Approved for Roadmap

**Theme:** Seamless Context Switching

**Problem Statement:**
After stepping away from a project, developers struggle to remember what was done and where they left off. Session lists show timestamps but not meaningful activity summaries.

**User Stories:**
- As a developer returning to a project, I want to see a timeline of all activity so that I can quickly catch up
- As a developer, I want to filter by activity type so that I can find specific actions
- As a team member, I want to see what Claude did while I was away so that I understand project changes

**Proposed Solution:**
Create an activity timeline aggregating commits, sessions, tool executions, and key events.

**Key Functionality:**
- [ ] Timeline view with chronological activity
- [ ] Activity types: commits, sessions, tool runs, errors
- [ ] Filter by type, date range, search
- [ ] Expandable detail for each activity
- [ ] "Jump to session" from activity
- [ ] Daily/weekly summary digest

**Success Metrics:**
- Timeline view usage frequency
- Time to context recovery (subjective)
- Filter usage patterns

**Technical Considerations:**
- Dependencies: Git log parsing, session metadata aggregation
- Complexity: Medium
- Platform APIs: None specific
- Backend needs: None (SSH-based data collection)

**Competitive Analysis:**
GitHub has activity feeds. Linear has project timelines. Apply to AI sessions.

**Open Questions:**
- How far back should timeline go?
- Should we track local activity or only server-side?
- How to present large timelines efficiently?

**Priority Score:** 5/10

---

### 9. Syntax Highlighting in Code Blocks

**Status:** [ ] Approved for Roadmap

**Theme:** Developer Workflow Integration

**Problem Statement:**
Code blocks in Claude responses render as plain monospace text, making it harder to read and review code on mobile.

**User Stories:**
- As a developer reviewing code, I want syntax highlighting so that I can read code more easily
- As a developer learning from examples, I want language-aware coloring so that I understand code structure
- As a user copying code, I want to see the same highlighting I would in my IDE

**Proposed Solution:**
Add language-aware syntax highlighting to code blocks using a Swift highlighting library.

**Key Functionality:**
- [ ] Language detection from markdown fence (```swift, etc.)
- [ ] Syntax highlighting for 10+ popular languages
- [ ] Light/dark theme variants
- [ ] Line numbers option
- [ ] Horizontal scroll for long lines
- [ ] Copy with or without highlighting

**Success Metrics:**
- User preference for highlighted vs plain code
- Time spent viewing code blocks
- Reduction in "show me that code again" requests

**Technical Considerations:**
- Dependencies: Syntax highlighting library (Splash, Highlighter)
- Complexity: Medium
- Platform APIs: AttributedString rendering
- Backend needs: None

**Competitive Analysis:**
All code editors and GitHub mobile have syntax highlighting. This is expected functionality.

**Open Questions:**
- Which highlighting library best balances features and bundle size?
- How to handle unknown or mixed languages?
- Should highlighting be configurable or automatic?

**Priority Score:** 6/10

---

### 10. Workflow Automation (Recipes)

**Status:** [ ] Approved for Roadmap

**Theme:** Developer Workflow Integration

**Problem Statement:**
Developers perform repetitive multi-step sequences (test, commit, push, PR) that require manual intervention at each step.

**User Stories:**
- As a developer, I want to define "deploy" as test-commit-push-PR so that one command does everything
- As a team, I want to share standard workflows so that everyone follows the same process
- As a developer, I want conditional logic so that the workflow stops on failures

**Proposed Solution:**
Build a recipe system for defining and executing multi-step Claude command sequences.

**Key Functionality:**
- [ ] Recipe definition: name, steps, conditions
- [ ] Step types: Claude command, wait, conditional
- [ ] Conditional logic: stop on error, continue, branch
- [ ] Recipe library with sharing
- [ ] Progress tracking through steps
- [ ] Recipe trigger from Shortcuts

**Success Metrics:**
- Recipes created per user
- Recipe execution frequency
- Time saved per recipe run

**Technical Considerations:**
- Dependencies: Command Library foundation
- Complexity: High
- Platform APIs: None specific
- Backend needs: None (orchestrated client-side)

**Competitive Analysis:**
GitHub Actions, n8n, Shortcuts all offer workflow automation. Apply to AI coding.

**Open Questions:**
- How complex should conditional logic be?
- Should recipes be editable visually or text-based?
- How to handle long-running steps in recipes?

**Priority Score:** 4/10

---

### 11. iCloud Sync

**Status:** [ ] Approved for Roadmap

**Theme:** Seamless Context Switching

**Problem Statement:**
Users with multiple iOS devices must manually configure each one. Settings, saved commands, and bookmarks do not sync.

**User Stories:**
- As a developer with iPhone and iPad, I want my settings to sync so that both devices are configured the same
- As a developer, I want my saved commands available on all devices so that I do not recreate them
- As a developer, I want my bookmarks synced so that I can access them anywhere

**Proposed Solution:**
Implement iCloud sync for app data using CloudKit.

**Key Functionality:**
- [ ] Sync AppSettings across devices
- [ ] Sync CommandStore (saved commands with categories)
- [ ] Sync BookmarkStore (bookmarked messages)
- [ ] Sync SessionNamesStore (custom session names)
- [ ] Sync ArchivedProjectsStore (archived project paths)
- [ ] Sync IdeasStore (per-project ideas)
- [ ] Sync status indicator in Settings
- [ ] Graceful fallback to local storage

**Success Metrics:**
- Percentage of users with iCloud enabled
- Sync conflict rate
- Cross-device usage patterns

**Technical Considerations:**
- Dependencies: Apple Developer account with CloudKit
- Complexity: High
- Platform APIs: NSUbiquitousKeyValueStore, CKContainer
- Backend needs: None
- Conflict resolution: Last-write-wins for settings, merge strategy for collections

**Competitive Analysis:**
Most iOS apps support iCloud sync. This is expected functionality.

**Open Questions:**
- How to handle multi-server data in iCloud?
- What happens when iCloud is disabled mid-use?
- Should session history sync or stay local?

**Priority Score:** 5/10

---

### 12. Hybrid Model Mode

**Status:** [ ] Approved for Roadmap

**Theme:** Proactive Assistance

**Problem Statement:**
Users manually select which Claude model to use. Simple questions waste expensive model capacity; complex tasks may use underpowered models.

**User Stories:**
- As a developer, I want the app to automatically choose the right model so that I get fast answers for simple questions
- As a developer, I want complex tasks to use more powerful models so that I get better results
- As a cost-conscious user, I want to optimize token usage so that I stay within budget

**Proposed Solution:**
Implement automatic model selection based on task complexity analysis.

**Key Functionality:**
- [ ] Task complexity classifier (simple question vs complex task)
- [ ] Model routing rules (Haiku for simple, Sonnet/Opus for complex)
- [ ] User override option
- [ ] Token usage tracking and reporting
- [ ] Cost estimation display
- [ ] Learning from user corrections

**Success Metrics:**
- Model routing accuracy
- Token cost reduction
- User satisfaction with auto-selection

**Technical Considerations:**
- Dependencies: Multiple model API access
- Complexity: High
- Platform APIs: None specific
- Backend needs: May require backend routing support

**Competitive Analysis:**
Cursor uses hybrid models effectively. Apply to mobile.

**Open Questions:**
- What signals indicate task complexity?
- How to handle mid-conversation complexity changes?
- Should users see which model is responding?

**Priority Score:** 4/10

---

### 13. Session Templates

**Status:** [ ] Approved for Roadmap

**Theme:** Developer Workflow Integration

**Problem Statement:**
Developers often start sessions with the same context or instructions. This is repetitive and error-prone.

**User Stories:**
- As a developer, I want to start sessions with pre-loaded context so that I do not repeat myself
- As a team, I want to share session templates so that everyone uses consistent prompts
- As a developer, I want project-specific templates so that context is always relevant

**Proposed Solution:**
Create a template system for session initialization.

**Key Functionality:**
- [ ] Template creation from existing session
- [ ] Template variables (project name, date, etc.)
- [ ] Per-project default template
- [ ] Template library with categories
- [ ] Import/export templates
- [ ] Quick-start from template

**Success Metrics:**
- Templates created per user
- Template usage frequency
- Time saved per session start

**Technical Considerations:**
- Dependencies: None
- Complexity: Low
- Platform APIs: None specific
- Backend needs: None

**Competitive Analysis:**
VS Code has workspace settings. Apply to session context.

**Open Questions:**
- How to handle template versioning?
- Should templates include file context?
- How to validate template variables?

**Priority Score:** 4/10

---

### 14. Share Extension

**Status:** [ ] Approved for Roadmap

**Theme:** Developer Workflow Integration

**Problem Statement:**
Users cannot easily send content from other apps (Safari, Notes, Slack) to Claude for analysis.

**User Stories:**
- As a developer reading documentation, I want to share a page to Claude so that I can ask questions about it
- As a developer reviewing a Slack thread, I want to share it to Claude so that I can summarize or analyze it
- As a developer, I want to share code snippets from any app so that Claude can help me understand them

**Proposed Solution:**
Implement iOS Share Extension for receiving content from other apps.

**Key Functionality:**
- [ ] Accept text, URLs, and images
- [ ] Project selection on share
- [ ] Quick action buttons (summarize, explain, continue)
- [ ] Preview shared content before sending
- [ ] Open in app after sharing

**Success Metrics:**
- Share extension usage frequency
- Content types shared
- Conversion to full app sessions

**Technical Considerations:**
- Dependencies: App Groups for data sharing
- Complexity: Medium
- Platform APIs: Share Extension, NSExtensionContext
- Backend needs: None

**Competitive Analysis:**
ChatGPT has a share extension. Match parity.

**Open Questions:**
- How to handle large shared content?
- Should sharing start a new session or continue?
- How to handle authentication in extension?

**Priority Score:** 5/10

---

### 15. Handoff Support

**Status:** [ ] Approved for Roadmap

**Theme:** Seamless Context Switching

**Problem Statement:**
Users cannot seamlessly continue work between iPhone, iPad, and Mac (if a Mac app exists).

**User Stories:**
- As a developer, I want to start on iPhone and continue on iPad so that I can use the larger screen
- As a developer, I want Handoff to show the current session so that I can pick up where I left off
- As a developer, I want Universal Clipboard to work with code so that I can copy on one device and paste on another

**Proposed Solution:**
Implement Handoff and Universal Clipboard support.

**Key Functionality:**
- [ ] Handoff activity for current session
- [ ] Universal Clipboard for copied code
- [ ] Handoff indicator in status bar
- [ ] Graceful degradation when Handoff unavailable

**Success Metrics:**
- Handoff usage frequency
- Cross-device session continuity
- Universal Clipboard usage

**Technical Considerations:**
- Dependencies: iCloud account, same Apple ID
- Complexity: Medium
- Platform APIs: NSUserActivity, UIPasteboard
- Backend needs: None

**Competitive Analysis:**
Apple apps support Handoff. Third-party adoption varies.

**Open Questions:**
- How to handle session state in Handoff?
- What about in-progress Claude responses?
- How to test Handoff effectively?

**Priority Score:** 3/10

---

## Quick Wins

Low-effort, high-value improvements that could ship quickly.

### QW1: Configurable Message History Limit

**Effort:** Low | **Impact:** Medium

Change hardcoded 50-message limit to user-configurable (25, 50, 100, 200). Requires only `AppSettings` change and `MessageStore` modification.

**Note:** This is currently on ROADMAP.md Priority 2 for near-term implementation.

### QW1.5: Enhanced Grep Result Actions

**Effort:** Low | **Impact:** Medium | **Source:** Session Analysis 2025-12-28

Session analysis shows Grep usage increased to 11.6% of tool calls (94 occurrences). Add enhanced copy functionality:

- Individual file path copy buttons in expanded view
- "Copy All Paths" quick action in header
- Pattern highlight in results (optional)

**Files to modify:** `CLIMessageView.swift` (consider extracting to `GrepResultView.swift` if complex)

### QW2: Haptic Feedback for Key Actions ✅

**Status:** Complete | **Implemented:** December 2025

Added `HapticManager` utility with light/medium/rigid/success/warning/error feedback:
- **Send message:** Medium impact haptic
- **Abort:** Rigid impact haptic
- **Error:** Error notification haptic
- **Copy actions:** Light impact haptic (code blocks, quick actions, context menu)

**Files modified:** `HapticManager.swift` (new), `ChatView.swift`, `CLIMessageView.swift`, `CodeBlockView.swift`

### QW3: Message Timestamps Display ✅

**Status:** Complete | **Implemented:** December 2025

Added relative timestamp display to message headers:
- Shows abbreviated relative time ("2 min. ago") next to each message header
- Uses `RelativeDateTimeFormatter` with `.abbreviated` style
- Muted text color at 70% opacity to not distract from content

**Files modified:** `CLIMessageView.swift`

### QW4: Code Block Language Badge ✅

**Status:** Complete | **Implemented:** December 2025

Enhanced `CodeBlockView` with language display:
- Pill-shaped badge with language icon and display name
- Language detection from markdown fence (swift, typescript, python, etc.)
- SF Symbol icons for language categories (terminal for shell, globe for web, etc.)

**Files modified:** `CodeBlockView.swift`

### QW5: Pull-to-Refresh on Chat ✅

**Status:** Complete | **Implemented:** December 2025

Added `.refreshable` modifier to chat ScrollView:
- Reloads session history from API
- Refreshes git status in background
- Light haptic feedback on pull

**Files modified:** `ChatView.swift`

### QW6: Unit Tests for Session Analysis Helpers

**Effort:** Low | **Impact:** Medium | **Source:** Session Analysis 2025-12-28

Add unit tests for helpers implemented from session analysis recommendations:

- [ ] Test `extractBashExitCode()` helper in CLIMessageView
- [ ] Test `isVerboseHelpOutput()` detection in TruncatableText
- [ ] Test file path counting logic in `resultCountBadge`
- [ ] Test agent type extraction from Task tool

**Files to create:** `CLIMessageViewTests.swift`, `TruncatableTextTests.swift`

---

## Moonshots

### M0: Persistent Todo Progress Drawer

**Vision:** Extract Claude's TodoWrite tool output into a persistent, collapsible drawer that shows real-time task progress. As Claude works through tasks, users see checkboxes being completed in real-time—like watching an agent check off tasks as it works.

**Why it matters:** The TodoWrite tool is one of Claude's most useful features for complex multi-step tasks, but its output currently scrolls by in the message stream. A dedicated drawer would make progress visible at a glance and persist until the user sends their next message.

**Key Functionality:**
- [ ] Detect TodoWrite tool calls in the message stream
- [ ] Extract todo items and their status (pending, in_progress, completed)
- [ ] Display in a collapsible drawer above the input area
- [ ] Update in real-time as new TodoWrite messages arrive
- [ ] Show progress indicator (e.g., "3/7 tasks complete")
- [ ] Persist drawer until user sends next message
- [ ] Collapse/expand toggle for minimal distraction
- [ ] Optional: Animate checkbox completion for satisfying feedback

**User Stories:**
- As a developer watching Claude work, I want to see task progress at a glance so I know how much is done
- As a developer, I want the todo list to persist after streaming so I can review what was accomplished
- As a developer, I want to collapse the drawer when I don't need it so it doesn't take up space

**Technical Considerations:**
- Dependencies: TodoWrite tool parsing (needs research into exact JSON format)
- Complexity: Medium
- Data flow: WebSocket → parse TodoWrite → update drawer state → render
- State management: Track current todos, update on each TodoWrite message
- Edge cases: Multiple TodoWrite calls, empty todo list, rapid updates

**Research Needed:**
- Exact JSON structure of TodoWrite tool output in WebSocket stream
- How to differentiate TodoWrite from other tool calls
- Best UX for drawer animation and placement
- Whether to show historical todos or only current session

**Complexity:** Medium

**Differentiation:** No other mobile AI client shows real-time task progress this way. This makes the "agent working for you" experience tangible and visible.

---

Ambitious features that could fundamentally change the product.

### M1: Split-View Code Editor (iPad)

**Vision:** Transform iPad into a legitimate development environment with a split view showing code alongside chat. Users could view, navigate, and make quick edits to files while conversing with Claude.

**Why it matters:** iPad Pro has the hardware to be a development machine. This feature bridges the gap between mobile companion and primary tool.

**Complexity:** Very High (requires code editor component, syntax highlighting, file sync)

**Differentiation:** No mobile AI assistant offers integrated code editing.

### M2: Semantic Code Search

**Vision:** Natural language search across entire codebases. "Find where we handle authentication errors" returns relevant code with explanations.

**Why it matters:** grep and regex require knowing what you are looking for. Semantic search finds what you mean.

**Complexity:** Very High (requires embeddings, vector search, backend infrastructure)

**Differentiation:** Could be a killer feature that justifies the app for non-mobile use cases.

### M3: Predictive Development Assistant

**Vision:** AI that proactively suggests actions based on patterns. "You usually run tests before commits" or "This file often changes with that one." Learn from user behavior to anticipate needs.

**Why it matters:** Moves from reactive to proactive AI. The assistant that knows what you need before you ask.

**Complexity:** Very High (requires pattern learning, on-device ML, privacy-preserving analytics)

**Differentiation:** True AI-native experience that learns and adapts to each developer.

---

## Not Planned

These features have been considered but are not on the roadmap. Rationale is provided for reference.

| Feature | Reason |
|---------|--------|
| **Sound Effects** | Adds noise without value; keep the experience focused |
| **Custom Themes** | System/Dark/Light modes are sufficient; maintenance burden |
| **Offline Mode** | Complexity outweighs benefit; app requires server connection |
| **Apple Watch App** | Screen too small for meaningful code interaction |
| **Message Virtualization** | Premature optimization; 50-message limit handles performance |
| **Lazy Image Loading** | Premature optimization for current usage patterns |

---

## Feature Prioritization Matrix

| Feature | Impact | Feasibility | Score | Theme |
|---------|--------|-------------|-------|-------|
| Voice Conversation Mode | 9 | 8 | 9 | Voice-First |
| Home Screen Widget | 8 | 8 | 8 | Platform-Native |
| Live Activities | 8 | 7 | 8 | Platform-Native |
| Siri Shortcuts | 7 | 8 | 7 | Platform-Native |
| Approval Queue + Push | 8 | 5 | 7 | Proactive |
| Multi-Server Support | 6 | 7 | 6 | Context Switching |
| Syntax Highlighting | 6 | 8 | 6 | Workflow |
| iCloud Sync | 6 | 5 | 5 | Context Switching |
| Session Sharing | 6 | 6 | 5 | Context Switching |
| Share Extension | 5 | 7 | 5 | Workflow |
| Project Timeline | 5 | 7 | 5 | Context Switching |
| Hybrid Model Mode | 6 | 4 | 4 | Proactive |
| Session Templates | 5 | 8 | 4 | Workflow |
| Workflow Automation | 7 | 4 | 4 | Workflow |
| Handoff Support | 4 | 6 | 3 | Context Switching |

---

## Recommended Implementation Order

```
Phase 1: Voice & Widgets (Q1)
+-- Voice Conversation Mode           [High impact, extends existing code]
+-- Home Screen Widget                [High visibility, platform showcase]
+-- Syntax Highlighting               [Quality of life, expected feature]

Phase 2: Platform Integration (Q2)
+-- Live Activities                   [iOS differentiation]
+-- Siri Shortcuts                    [Automation unlocks]
+-- Quick Wins (QW1-QW5)              [Polish and refinement]

Phase 3: Collaboration & Sync (Q3)
+-- Multi-Server Support              [Power user need]
+-- Session Sharing                   [Team collaboration]
+-- Share Extension                   [Platform integration]

Phase 4: Advanced Features (Q4)
+-- iCloud Sync                       [Cross-device experience]
+-- Approval Queue + Push             [Requires backend work]
+-- Project Timeline                  [Context management]

Phase 5: Power User & Beyond (Q4+)
+-- Hybrid Model Mode                 [Advanced feature]
+-- Session Templates                 [Workflow optimization]
+-- Workflow Automation               [Power user automation]
+-- Handoff Support                   [Apple ecosystem]
+-- Moonshots                         [Long-term vision]
```

---

## Dependencies Map

```
Voice Mode
  +-- AVSpeechSynthesizer (iOS native)
  +-- MPRemoteCommandCenter (Bluetooth)

Widgets / Live Activities
  +-- App Groups (shared data)
  +-- Background refresh
  +-- [Live Activities] Backend progress events

Shortcuts
  +-- App Intents framework
  +-- Existing app functionality

Push Notifications
  +-- Backend APNs support (NEW)
  +-- Approval queue endpoint (NEW)

Multi-Server
  +-- AppSettings refactor
  +-- Keychain per-server storage

iCloud Sync
  +-- Apple Developer account with CloudKit
  +-- Data model versioning

Share Extension
  +-- App Groups for data sharing
  +-- Extension-safe code paths
```

---

## Known Backend Issues

These issues affect future features and require coordination with the backend team:

1. **CORS Limitation**: History API endpoints do not accept Authorization headers
   - Workaround: Load history via SSH from `~/.claude/projects/`
   - Proper fix requires backend change

2. **Session File Format**: JSONL with specific message types
   - Location: `~/.claude/projects/{encoded-path}/{session-id}.jsonl`
   - Encoded path: `/home/dev/project` -> `-home-dev-project`

3. **Push Notifications**: No APNs infrastructure exists
   - Blocks: Approval Queue feature
   - Requires: Backend push endpoint, token management

4. **Progress Events**: WebSocket does not stream task progress
   - Blocks: Live Activities with accurate progress
   - Requires: Backend progress event emission

---

## Notes for Contributors

- **Start with Quick Wins** - Build momentum with visible improvements
- **Voice Mode is the differentiator** - No competitor has this; prioritize accordingly
- **Widgets showcase iOS investment** - Apple features apps with great widgets
- **Backend changes are blockers** - Features requiring backend work need coordination
- **Test on real devices** - Voice, widgets, and Live Activities need physical devices
- **Check ROADMAP.md first** - Some quick wins may already be scheduled for near-term work

---

*Last updated: December 28, 2025*
*Next review: January 2025*
