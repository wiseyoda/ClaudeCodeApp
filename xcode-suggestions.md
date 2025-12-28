High‑impact recommendations based on your current codebase

I took a tour through the app’s core views and managers — ContentView, ChatView, APIClient, WebSocketManager, SessionManager, TerminalView, theming, and quick settings — and captured the most impactful improvements I’d suggest. I’ve grouped them by priority so you can act quickly where it matters most.

1) Critical fixes and build hygiene

• Remove or rename the duplicate ContentView definition
   • You currently have two files declaring struct ContentView: ContentView.swift􀰓 (your real app) and ContentView.swift􀰓 (template “Hello, world!”). This will cause ambiguous type errors or unexpected previews/builds.
   • Action: Either delete ContentView.swift􀰓 or exclude it from the target. If you need it for another target, rename the type.

• Ensure WebSocket authentication is handled
   • WebSocketManager.connect() uses URLSession.webSocketTask(with: url) without adding headers. If your backend expects a bearer token (like your HTTP APIs do), make sure the token is passed either via query string (wss://…?token=…) or by constructing a URLRequest and setting Authorization: Bearer <token>.
   • This will eliminate intermittent “session not found / resume failed” issues that are actually auth failures.

• Avoid multiple SSH connections unintentionally
   • ChatView and SessionManager use SSHManager.shared, but TerminalView creates a fresh @StateObject private var sshManager = SSHManager(). If SSHManager isn’t explicitly designed for multiple connections, this can cause confusing states or race conditions.
   • Prefer a single shared instance (or a connection‑scoped owner) for clarity and stability.

2) Quick UX wins

• Persist “expanded projects” and the Git banner per project
   • You already persist archives, names, and sessions nicely. Persisting expandedProjects and showGitBanner (per project path) will make the sidebar feel “sticky” and respectful of user preference.

• Make the workspace root configurable
   • ContentView filters by a hard‑coded workspacePrefix = "/home/dev/workspace/". Expose this in AppSettings so users on different servers or environments can see their projects without editing code.

• Compress images before sending via WebSocket
   • In ChatView.sendMessage, you currently send imageData.base64EncodedString() as‑is. To reduce bandwidth and latency:

if let data = imageToSend,
       let uiImage = UIImage(data: data),
       let compressed = uiImage.jpegData(compressionQuality: 0.7) {
        wsManager.sendMessage(..., imageData: compressed, ...)
    }

• Also consider resizing very large images (e.g., max dimension 2048px).

• Adopt your glass effects consistently on pills and banners
   • You’ve built excellent glassBackground/glassCapsule modifiers. Applying them to ModePill, GitSyncBanner action chips, and the status bar will harmonize the UI with iOS 26 Liquid Glass guidelines.

• Add on‑change reconnect for server settings
   • When serverURL or auth state changes, proactively reconnect the socket:

.onChange(of: settings.serverURL) { _, _ in
        wsManager.disconnect()
        wsManager.connect()
    }

3) Stability and performance

• Debounce or batch background work on appearance
   • ContentView does: load projects → check all Git statuses → discover sub‑repos → load counts. You’re already batching / grouping well, but consider:
      • Cancelling prior runs if the user taps refresh repeatedly
      • Deferring discoverAllSubRepos() until the user expands a project the first time (lazy discovery)

• Ignore noisy directories during sub‑repo discovery
   • In discoverAllSubRepos, filter out common vendor dirs (node_modules, .git, build, dist, Pods, etc.). This reduces scanning time and false positives.

• Adopt iOS 26’s @IncrementalState where you’ve already planned to
   • You called this out in DebugLogStore and ChatView comments. The biggest wins:
      • Debug log list
      • Large message lists in ChatView (especially during streaming)
   • This reduces view thrashing and improves scroll smoothness.

• Consider message pagination for very long sessions
   • You already persist and cap saved messages, which is great. For sessions with very long histories fetched via API, consider lazy loading older messages as the user scrolls up.

4) Architecture and maintainability

• Consolidate session source of truth behind SessionManager
   • You’ve already done most of this, and the “reject recently deleted” logic is excellent. One next step:
      • Prefer API endpoints for counts and history whenever possible; fall back to SSH for bulk ops or when API isn’t available. This reduces coupling to filesystem layout on the server.

• Reduce singleton coupling for testability
   • Stores like SSHManager.shared, SessionManager.shared, ProjectSettingsStore.shared are fine for the app, but consider injecting protocol‑backed dependencies in views that you want to unit test later.

• Extract “Git status” orchestration into a small helper
   • ChatView holds “refresh/pull/commit/push” banner logic. Extracting a GitSyncController (a tiny type that coordinates SSHManager + banner state) will shrink ChatView and make it easier to test.

5) Platform features you’re close to fully leveraging

• Liquid Glass polish (SwiftUI iOS 26)
   • You already use glassEffect via your modifiers — consider:
      • Using interactive glass where appropriate on tappable chips (you have a flag for this)
      • Adding subtle transitions when banners appear/disappear to match the “fluid” feel

• New toolbar features
   • Consider toolbarTitleMenu for session actions (new session, resume, delete) right from the nav title in ChatView.
   • On iPad, using toolbar placements to create a consistent “editor” feel (mode toggles left, actions right) can help.

• Notifications
   • You already send a local notification when a task completes in the background. Consider requesting authorization early (with rationale), and offering a setting to opt‑out.

• App Intents (Shortcuts)
   • Useful intents:
      • “Send prompt to Project”
      • “Start new chat in Project”
      • “Search messages in Project”
   • This can make the app feel everywhere without opening it.

6) Security and privacy

• Keychain handling is solid; add passphrase validation feedback
   • SSHKeyImportSheet validates key format and tracks passphrase. Consider a quick “test connection” button after import to confirm the key works.

• Continue redacting tokens in logs
   • You already do this in APIClient.fetchProjects() — keep the same standard for WebSocket connect logs if you add headers or query tokens there.

• Optional certificate pinning
   • If your server is static and security‑sensitive, consider pinning to reduce MITM risk on public networks.

7) Accessibility and localization

• Accessibility is already thoughtful (labels/hints everywhere). A few extras:
   • Provide role grouping for message lists (e.g., “User message”, “Assistant message”, “Thinking”) so VoiceOver users can quickly navigate by rotor.
   • Respect Dynamic Type everywhere (you mostly do via settings.scaledFont) and ensure minimum contrast on colored badges in light mode.
   • Localize user‑visible strings. Most strings are currently inline literals; wrapping them in LocalizedStringKey and starting a Localizable.strings file will set you up for international users.

8) Testing and observability

• Add focused tests using the Swift Testing framework
   • Good candidates:
      • SessionMessage.toChatMessage() mapping
      • SessionHistoryLoader.parseSessionHistory(_:)
      • MessageStore read/write/cleanup of orphaned images
      • WebSocketManager.validateSessionId(_:) and model switch parsing
   • Example:

import Testing

    @Suite("SessionMessage mapping")
    struct SessionMessageTests {
        @Test
        func mapsAssistantText() throws {
            let json = """
            {"type":"assistant","message":{"content":[{"type":"text","text":"Hello"}]}}
            """
            let data = Data(json.utf8)
            let response = try JSONDecoder().decode(SessionMessage.self, from: data)
            let msg = response.toChatMessage()
            #expect(msg?.role == .assistant)
            #expect(msg?.content == "Hello")
        }
    }

• Add a lightweight “mock” WebSocket path for previews/tests
   • A MockWebSocketManager (same API, no network) lets you preview ChatView with streaming, tool uses, and completions deterministically.

• Error analytics is a nice touch
   • You already track categories and trends. Consider a small “share diagnostics” export and a “clear older than X days” maintenance button.

9) Git workflow polish

• Add a simple “ignore patterns” list for sub‑repo scanning
   • Keep it in AppSettings or a config file on the server (e.g., .claudeignore) so teams can tailor scanning without code changes.

• Make “auto‑pull when behind” opt‑in per project
   • You already show the banner and can auto‑pull; some teams will want stricter control or to disable auto‑pull on critical repos.

10) Future‑looking enhancements

• On‑device model (Foundation Models)
   • For small tasks like summarizing a long response into chips or offline “idea enhancement”, you could try Apple’s on‑device models (where available) to keep latency near‑zero and preserve privacy. Your ClaudeHelper abstraction is already a good place to swap in a local engine.

• Assistive Access mode
   • A simplified mode with larger controls and fewer affordances could make the app friendlier to users with cognitive needs. Your existing architecture would adapt well to a “reduced UI” toggle.

⸻

Summary of strengths

• Robust, thoughtful WebSocket flow with reconnection, buffering, and session recovery.
• Clear separation of HTTP (APIClient) and real‑time (WebSocketManager), with a centralized SessionManager.
• Accessibility, persistence, and keyboard shortcuts are well‑implemented.
• Git integration and monorepo support are a real differentiator — the banners and action chips are excellent.

If you want me to implement changes

• I can quickly remove the duplicate ContentView, add WebSocket auth headers, compress images before sending, make the workspace root configurable, and apply your glass effects consistently — these are all small, high‑value edits.
• If you prefer, we can also start a short test suite covering message mapping and persistence to lock in behavior before we iterate further.

Would you like me to apply the “critical fixes + quick UX wins” in a single pass now?
