import SwiftUI
import Combine

/// ViewModel for ChatView - manages all chat state and business logic
/// Extracted from ChatView to improve maintainability and testability
@MainActor
class ChatViewModel: ObservableObject {
    // MARK: - Dependencies
    let project: Project
    let initialGitStatus: GitStatus
    var onSessionsChanged: (() -> Void)?

    // MARK: - Managers
    let wsManager: CLIBridgeAdapter
    let ideasStore: IdeasStore
    let scrollManager = ScrollStateManager()
    let sessionStore = SessionStore.shared
    let projectSettingsStore = ProjectSettingsStore.shared

    // MARK: - Settings (injected)
    var settings: AppSettings

    // MARK: - Chat State
    @Published var messages: [ChatMessage] = []
    @Published var inputText = ""
    @Published var selectedImages: [ImageAttachment] = []
    @Published var processingStartTime: Date?
    @Published var selectedSession: ProjectSession?
    @Published var isUploadingImage = false
    @Published var isLoadingHistory = false
    @Published var scrollToBottomTrigger = false

    // MARK: - Streaming Message Cache
    @Published var streamingMessageId = UUID()
    @Published var streamingMessageTimestamp = Date()

    // MARK: - Tool Use Tracking (internal state, no UI updates needed)
    /// Maps tool_use_id to tool name for result filtering - not @Published as changes don't affect UI
    var toolUseMap: [String: String] = [:]
    /// Tool IDs created while a subagent was active - not @Published as changes don't affect UI
    var subagentToolIds: Set<String> = []

    // MARK: - Search State
    @Published var isSearching = false
    @Published var searchText = ""
    @Published var messageFilter: MessageFilter = .all

    // MARK: - Git State
    @Published var gitStatus: GitStatus = .unknown
    @Published var isAutoPulling = false
    @Published var showGitBanner = true
    /// Tracks if cleanup prompt was shown - not @Published as it's one-time flag
    var hasPromptedCleanup = false
    /// Background task for periodic git refresh - not @Published, managed internally
    var gitRefreshTask: Task<Void, Never>?

    // MARK: - Model State
    @Published var showingModelPicker = false
    @Published var currentModel: ClaudeModel?
    @Published var customModelId = ""

    // MARK: - Sheet State
    @Published var showingHelpSheet = false
    @Published var showingSessionPicker = false
    @Published var showingBookmarks = false
    @Published var showIdeasDrawer = false
    @Published var showQuickCapture = false
    @Published var showQuickSettings = false

    // MARK: - Todo Drawer State
    @Published var currentTodos: [TodoListView.TodoItem] = []
    @Published var isTodoDrawerExpanded = false
    @Published var showTodoDrawer = false
    /// Timer to auto-hide todo drawer - not @Published, managed internally
    var todoHideTimer: Task<Void, Never>?

    // MARK: - Background Tasks (internal task management, not @Published)
    var disconnectTask: Task<Void, Never>?
    var saveDebounceTask: Task<Void, Never>?
    var draftDebounceTask: Task<Void, Never>?

    // MARK: - Display Messages Cache
    private var cachedDisplayMessages: [ChatMessage] = []
    private var cachedGroupedDisplayItems: [DisplayItem] = []
    private var displayMessagesInvalidationKey: Int = 0

    // MARK: - Initialization

    init(project: Project, initialGitStatus: GitStatus = .unknown, settings: AppSettings, onSessionsChanged: (() -> Void)? = nil) {
        self.project = project
        self.initialGitStatus = initialGitStatus
        self.settings = settings
        self.onSessionsChanged = onSessionsChanged

        // Initialize managers
        self.wsManager = CLIBridgeAdapter()
        self.ideasStore = IdeasStore(projectPath: project.path)
    }

#if DEBUG
    init(
        project: Project,
        initialGitStatus: GitStatus = .unknown,
        settings: AppSettings,
        wsManager: CLIBridgeAdapter,
        onSessionsChanged: (() -> Void)? = nil
    ) {
        self.project = project
        self.initialGitStatus = initialGitStatus
        self.settings = settings
        self.onSessionsChanged = onSessionsChanged
        self.wsManager = wsManager
        self.ideasStore = IdeasStore(projectPath: project.path)
    }
#endif

    // MARK: - Lifecycle

    func onAppear() {
        // Cancel any pending disconnect (handles NavigationSplitView recreations)
        disconnectTask?.cancel()
        disconnectTask = nil

        // Configure SessionStore with settings (idempotent)
        sessionStore.configure(with: settings)

        // Update managers with actual settings
        wsManager.updateSettings(settings)
        setupWebSocketCallbacks()

        // Start health monitoring for status bar
        HealthMonitorService.shared.configure(serverURL: settings.serverURL)
        HealthMonitorService.shared.startPolling()

        // Check if we were processing when app closed (for reattachment)
        let wasProcessing = MessageStore.loadProcessingState(for: project.path)

        // Load persisted messages as temporary content while history loads
        Task {
            let savedMessages = await MessageStore.loadMessages(for: project.path)
            // Only use persisted messages if history isn't loading yet
            // This prevents race condition where persisted messages overwrite empty state
            guard !isLoadingHistory else {
                log.debug("[ChatViewModel] Skipping persisted messages - history loading from API")
                return
            }
            if !savedMessages.isEmpty {
                // Apply history limit on load for safety
                let limit = settings.historyLimit.rawValue
                messages = savedMessages.count > limit
                    ? Array(savedMessages.suffix(limit))
                    : savedMessages
                refreshDisplayMessagesCache()
            } else {
                refreshDisplayMessagesCache()
            }
        }

        // Load sessions from API, then select most recent and connect
        Task {
            await sessionStore.loadSessions(for: project.path, forceRefresh: true)

            // Select session (pre-selected from navigation, or auto-select most recent)
            selectInitialSession()

            // Connect based on selected session
            if let session = selectedSession {
                log.debug("[ChatViewModel] Opening project with session: \(session.id.prefix(8))...")
                wsManager.sessionId = session.id
                wsManager.connect(projectPath: project.path, sessionId: session.id)
                MessageStore.saveSessionId(session.id, for: project.path)
                loadSessionHistory(session)

                // Check if we need to reattach to an active session
                if wasProcessing {
                    log.debug("[ChatViewModel] Session was processing when app closed - attempting reattachment...")
                    attemptSessionReattachment(sessionId: session.id)
                }
            } else {
                // No sessions exist - connect without sessionId
                log.debug("[ChatViewModel] No sessions found for project - connecting without session")
                wsManager.connect(projectPath: project.path)
                if wasProcessing {
                    MessageStore.clearProcessingState(for: project.path)
                }
            }
        }

        // Load draft input
        let savedDraft = MessageStore.loadDraft(for: project.path)
        if !savedDraft.isEmpty {
            inputText = savedDraft
        }

        // Handle git status from ContentView
        gitStatus = initialGitStatus
        handleGitStatusOnLoad()

        // Initialize model state
        customModelId = settings.customModelId

        // Start periodic git status refresh task (every 30 seconds)
        gitRefreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled else { break }
                refreshGitStatus()
            }
        }
        // Note: Session loading is already handled in the Task above (lines 140-168)
        // with forceRefresh: true, so no additional loading is needed here.
    }

    func onDisappear() {
        // Cancel debounce and save messages/draft immediately when leaving
        saveDebounceTask?.cancel()
        saveDebounceTask = nil
        draftDebounceTask?.cancel()
        draftDebounceTask = nil
        MessageStore.saveMessages(messages, for: project.path, maxMessages: settings.historyLimit.rawValue)
        MessageStore.saveDraft(inputText, for: project.path)

        // Cancel git refresh task
        gitRefreshTask?.cancel()
        gitRefreshTask = nil

        // Cancel todo hide timer
        todoHideTimer?.cancel()
        todoHideTimer = nil

        // Stop health monitoring when leaving chat (reduces background polling)
        HealthMonitorService.shared.stopPolling()

        // Delay disconnect to handle NavigationSplitView layout recreations
        disconnectTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            wsManager.disconnect()
        }
    }

    // MARK: - Sessions

    var localSessions: [ProjectSession] {
        sessionStore.sessions(for: project.path)
    }

    var localSessionsBinding: Binding<[ProjectSession]> {
        Binding(
            get: { [weak self] in self?.sessionStore.sessions(for: self?.project.path ?? "") ?? [] },
            set: { _ in }
        )
    }

    var sessions: [ProjectSession] {
        let activeId = wsManager.sessionId
        if sessionStore.hasLoaded(for: project.path) {
            return localSessions.filterForDisplay(projectPath: project.path, activeSessionId: activeId)
        }
        let baseSessions = localSessions.isEmpty ? (project.sessions ?? []) : localSessions
        return baseSessions.filterForDisplay(projectPath: project.path, activeSessionId: activeId)
    }

    /// Compute session ID to resume, filtering out ephemeral sessions
    var effectiveSessionToResume: String? {
        if let sessionId = wsManager.sessionId {
            return sessionId
        }
        if let session = selectedSession {
            if session.id.hasPrefix("new-session-") {
                return nil
            }
            return session.id
        }
        return nil
    }

    func startNewSession() {
        log.debug("[ChatViewModel] Starting new session - clearing state and reconnecting")

        // Clear UI state
        messages = []
        scrollManager.reset()
        MessageStore.clearMessages(for: project.path)
        MessageStore.clearSessionId(for: project.path)
        sessionStore.clearActiveSessionId(for: project.path)

        // Create ephemeral session placeholder
        let ephemeralSession = ProjectSession(
            id: "new-session-\(UUID().uuidString)",
            summary: "New Session",
            lastActivity: ISO8601DateFormatter().string(from: Date()),
            messageCount: 0,
            lastUserMessage: nil,
            lastAssistantMessage: nil
        )
        selectedSession = ephemeralSession

        // CRITICAL: Disconnect and reconnect WebSocket WITHOUT a sessionId
        // This ensures the backend creates a new session when the user sends their first message
        wsManager.disconnect()
        wsManager.sessionId = nil
        log.debug("[ChatViewModel] Reconnecting WebSocket without sessionId for fresh session")
        wsManager.connect(projectPath: project.path, sessionId: nil)

        let welcomeMessage = ChatMessage(
            role: .system,
            content: "New session started. How can I help you?",
            timestamp: Date()
        )
        messages.append(welcomeMessage)
        refreshDisplayMessagesCache()
    }

    func selectInitialSession() {
        if let preSelectedId = sessionStore.loadActiveSessionId(for: project.path) {
            if let preSelectedSession = sessionStore.sessions(for: project.path).first(where: { $0.id == preSelectedId }) {
                log.debug("[ChatViewModel] Using pre-selected session: \(preSelectedId.prefix(8))...")
                selectedSession = preSelectedSession
            } else {
                log.debug("[ChatViewModel] Pre-selected session \(preSelectedId.prefix(8)) not in list, creating ephemeral...")
                let ephemeralSession = ProjectSession(
                    id: preSelectedId,
                    summary: nil,
                    lastActivity: nil,
                    messageCount: nil,
                    lastUserMessage: nil,
                    lastAssistantMessage: nil
                )
                selectedSession = ephemeralSession
            }
            sessionStore.clearActiveSessionId(for: project.path)
        } else {
            autoSelectMostRecentSession()
        }
    }

    func autoSelectMostRecentSession() {
        let storeSessions = sessionStore.displaySessions(for: project.path)
        if !storeSessions.isEmpty {
            if let mostRecent = storeSessions.first, (mostRecent.messageCount ?? 0) > 0 {
                selectedSession = mostRecent
                return
            }
        }

        guard let sessions = project.sessions else { return }
        let filteredSessions = sessions.filterAndSortForDisplay(projectPath: project.path, activeSessionId: nil)
        guard let mostRecent = filteredSessions.first,
              (mostRecent.messageCount ?? 0) > 0 else { return }

        selectedSession = mostRecent
    }

    func selectMostRecentSession(from sessions: [ProjectSession]) {
        guard let mostRecent = sessions.first else { return }

        log.debug("[ChatViewModel] Selecting most recent session: \(mostRecent.id.prefix(8))...")
        wsManager.sessionId = mostRecent.id
        selectedSession = mostRecent
        MessageStore.saveSessionId(mostRecent.id, for: project.path)

        if messages.isEmpty {
            loadSessionHistory(mostRecent)
        }
    }

    func attemptSessionReattachment(sessionId: String) {
        Task {
            var attempts = 0
            while !wsManager.connectionState.isConnected && attempts < 20 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                attempts += 1
            }

            if wsManager.connectionState.isConnected {
                log.debug("[ChatViewModel] Reattaching to session: \(sessionId.prefix(8))...")
                wsManager.attachToSession(sessionId: sessionId, projectPath: project.path)
            } else {
                log.debug("[ChatViewModel] Could not reattach - WebSocket not connected after wait")
                MessageStore.clearProcessingState(for: project.path)
            }
        }
    }

    func selectSession(_ session: ProjectSession) {
        selectedSession = session
        wsManager.sessionId = session.id
        MessageStore.saveSessionId(session.id, for: project.path)
        loadSessionHistory(session)
    }

    func loadSessionHistory(_ session: ProjectSession) {
        messages = []
        isLoadingHistory = true
        scrollManager.reset()

        Task {
            do {
                let limit = settings.historyLimit.rawValue
                log.debug("[ChatViewModel] Loading session history via paginated API for: \(session.id) (limit: \(limit))")

                let apiClient = CLIBridgeAPIClient(serverURL: settings.serverURL)

                // Use the new paginated messages endpoint - fetches only what we need
                let response = try await apiClient.fetchInitialMessages(
                    projectPath: project.path,
                    sessionId: session.id,
                    limit: limit
                )

                await wsManager.refreshTokenUsage(projectPath: project.path, sessionId: session.id)

                // Convert paginated messages to ChatMessages
                // Response is in "desc" order (newest first), reverse for chronological display
                let historyMessages = response.messages.reversed().map { $0.toChatMessage() }

                if historyMessages.isEmpty {
                    if let lastMsg = session.lastAssistantMessage {
                        messages.append(ChatMessage(role: .assistant, content: lastMsg, timestamp: Date()))
                    }
                } else {
                    messages = historyMessages
                    log.debug("[ChatViewModel] Loaded \(historyMessages.count) messages via paginated API (total: \(response.total), hasMore: \(response.hasMore))")
                }
                isLoadingHistory = false
                refreshDisplayMessagesCache()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.scrollManager.forceScrollToBottom()
                }
            } catch {
                log.debug("[ChatViewModel] Failed to load session history via paginated API: \(error)")
                // Fall back to export API for backwards compatibility
                await loadSessionHistoryFallback(session)
            }
        }
    }

    /// Fallback to export API if paginated endpoint fails (backwards compatibility)
    private func loadSessionHistoryFallback(_ session: ProjectSession) async {
        do {
            log.debug("[ChatViewModel] Falling back to export API for: \(session.id)")

            let apiClient = CLIBridgeAPIClient(serverURL: settings.serverURL)
            let exportResponse = try await apiClient.exportSession(
                projectPath: project.path,
                sessionId: session.id,
                format: .json,
                includeStructuredContent: true
            )

            let historyMessages = parseJSONLToMessages(exportResponse.content)

            if historyMessages.isEmpty {
                if let lastMsg = session.lastAssistantMessage {
                    messages.append(ChatMessage(role: .assistant, content: lastMsg, timestamp: Date()))
                }
            } else {
                // Apply history limit when loading to avoid memory bloat from large sessions
                let limit = settings.historyLimit.rawValue
                if historyMessages.count > limit {
                    messages = Array(historyMessages.suffix(limit))
                    log.debug("[ChatViewModel] Fallback: Loaded \(historyMessages.count) messages, pruned to \(limit)")
                } else {
                    messages = historyMessages
                    log.debug("[ChatViewModel] Fallback: Loaded \(historyMessages.count) messages from session export")
                }
            }
            isLoadingHistory = false
            refreshDisplayMessagesCache()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.scrollManager.forceScrollToBottom()
            }
        } catch {
            log.debug("[ChatViewModel] Fallback also failed: \(error)")
            if let lastMsg = session.lastAssistantMessage {
                messages.append(ChatMessage(role: .assistant, content: lastMsg, timestamp: Date()))
            }
            messages.append(ChatMessage(role: .system, content: "Could not load history: \(error.localizedDescription)", timestamp: Date()))
            isLoadingHistory = false
            refreshDisplayMessagesCache()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.scrollManager.forceScrollToBottom()
            }
        }
    }

    func deleteSession(_ session: ProjectSession) async {
        log.debug("[ChatViewModel] Deleting session: \(session.id)")

        let success = await sessionStore.deleteSession(session, for: project.path)

        if success {
            if selectedSession?.id == session.id {
                selectedSession = nil
                messages.removeAll()
                wsManager.sessionId = nil
                MessageStore.clearSessionId(for: project.path)
            }
            onSessionsChanged?()
        } else {
            log.debug("[ChatViewModel] Failed to delete session: \(session.id)")
        }
    }

    // MARK: - Message Sending

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !selectedImages.isEmpty else { return }

        HapticManager.medium()

        // Hide todo drawer when user sends a new message
        todoHideTimer?.cancel()
        todoHideTimer = nil
        withAnimation(.easeOut(duration: 0.2)) {
            showTodoDrawer = false
            isTodoDrawerExpanded = false
        }
        currentTodos = []

        // Check for slash commands
        if text.hasPrefix("/") && selectedImages.isEmpty {
            if handleSlashCommand(text) {
                inputText = ""
                return
            }
        }

        let imagesToSend = selectedImages
        let displayImage = imagesToSend.first?.originalData
        let imageCountSuffix = imagesToSend.count > 1 ? " (\(imagesToSend.count) images)" : ""
        let userMessage = ChatMessage(
            role: .user,
            content: text.isEmpty ? "[Image attached]\(imageCountSuffix)" : text,
            timestamp: Date(),
            imageData: displayImage
        )
        messages.append(userMessage)

        inputText = ""
        selectedImages = []
        processingStartTime = Date()

        let messageToSend = text
        let sessionToResume = effectiveSessionToResume

        if let sid = sessionToResume {
            log.debug("[ChatViewModel] Sending message with sessionToResume: \(sid.prefix(8))...")
        } else {
            log.debug("[ChatViewModel] Sending message with NO session ID - new session will be created")
        }

        let defaultPrompt = imagesToSend.count == 1 ? "What is this image?" : "What are these images?"
        wsManager.sendMessage(
            text.isEmpty ? defaultPrompt : messageToSend,
            projectPath: project.path,
            resumeSessionId: sessionToResume,
            permissionMode: effectivePermissionMode,
            images: imagesToSend.isEmpty ? nil : imagesToSend,
            model: effectiveModelId
        )

        MessageStore.saveMessages(messages, for: project.path, maxMessages: settings.historyLimit.rawValue)
    }

    // MARK: - Slash Commands

    func handleSlashCommand(_ command: String) -> Bool {
        let parts = command.lowercased().split(separator: " ", maxSplits: 1)
        let cmd = String(parts.first ?? "")

        switch cmd {
        case "/clear":
            handleClearCommand()
            return true

        case "/help":
            showingHelpSheet = true
            return true

        case "/exit":
            wsManager.disconnect()
            return true

        case "/init":
            addSystemMessage("Initializing project with Claude...")
            return false

        case "/new":
            handleNewSessionCommand()
            return true

        case "/resume":
            showingSessionPicker = true
            return true

        case "/compact":
            addSystemMessage("Sending compact request to server...")
            return false

        case "/status":
            showStatusInfo()
            return true

        default:
            if cmd.hasPrefix("/") {
                addSystemMessage("Unknown command: \(cmd). Type /help for available commands.")
                return true
            }
            return false
        }
    }

    func handleClearCommand() {
        messages.removeAll()
        wsManager.sessionId = nil
        selectedSession = nil
        scrollManager.reset()
        addSystemMessage("Conversation cleared. Starting fresh.")
        MessageStore.clearMessages(for: project.path)
        MessageStore.clearSessionId(for: project.path)
    }

    func handleNewSessionCommand() {
        messages.removeAll()
        wsManager.sessionId = nil
        selectedSession = nil
        scrollManager.reset()
        addSystemMessage("New session started.")
        MessageStore.clearMessages(for: project.path)
        MessageStore.clearSessionId(for: project.path)
    }

    func showStatusInfo() {
        var status = "Connection: \(wsManager.isConnected ? "Connected" : "Disconnected")"
        if let sessionId = wsManager.sessionId {
            status += "\nSession: \(sessionId.prefix(8))..."
        }
        if let usage = wsManager.tokenUsage {
            status += "\nTokens: \(usage.used)/\(usage.total)"
        }
        status += "\nProject: \(project.path)"
        addSystemMessage(status)
    }

    func addSystemMessage(_ content: String) {
        let msg = ChatMessage(role: .system, content: content, timestamp: Date())
        messages.append(msg)
    }

    func appendToInput(_ content: String) {
        if inputText.isEmpty {
            inputText = content + " "
        } else if inputText.hasSuffix(" ") {
            inputText += content + " "
        } else {
            inputText += " " + content + " "
        }
    }

    // MARK: - WebSocket Callbacks

    func setupWebSocketCallbacks() {
        wsManager.onText = { [weak self] text in
            // Text is accumulated in wsManager.currentText
        }

        wsManager.onTextCommit = { [weak self] text in
            guard let self = self else { return }
            let assistantMsg = ChatMessage(
                role: .assistant,
                content: text,
                timestamp: Date()
            )
            self.messages.append(assistantMsg)
        }

        wsManager.onToolUse = { [weak self] id, name, input in
            guard let self = self else { return }
            self.toolUseMap[id] = name

            if self.wsManager.activeSubagent != nil && name != "Task" {
                self.subagentToolIds.insert(id)
                log.debug("[ChatViewModel] Tracking subagent tool: \(name) (id: \(id.prefix(8)))")
                return
            }

            let toolMsg = ChatMessage(
                role: .toolUse,
                content: "\(name)(\(input))",
                timestamp: Date()
            )
            self.messages.append(toolMsg)

            if name == "TodoWrite" {
                let content = "\(name)(\(input))"
                if let todos = TodoListView.parseTodoContent(content), !todos.isEmpty {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        self.currentTodos = todos
                        self.showTodoDrawer = true
                    }
                    self.todoHideTimer?.cancel()
                    self.todoHideTimer = nil
                }
            }
        }

        wsManager.onToolResult = { [weak self] id, tool, result in
            guard let self = self else { return }
            let toolName = self.toolUseMap[id] ?? tool

            if self.subagentToolIds.contains(id) {
                log.debug("[ChatViewModel] Filtering subagent tool result: \(toolName) (id: \(id.prefix(8)))")
                self.subagentToolIds.remove(id)
                return
            }

            if toolName == "Task" {
                log.debug("[ChatViewModel] Filtering Task tool result (id: \(id.prefix(8)))")
                return
            }

            let resultMsg = ChatMessage(
                role: .toolResult,
                content: result,
                timestamp: Date()
            )
            self.messages.append(resultMsg)
        }

        wsManager.onThinking = { [weak self] thinking in
            guard let self = self else { return }
            let thinkingMsg = ChatMessage(
                role: .thinking,
                content: thinking,
                timestamp: Date()
            )
            self.messages.append(thinkingMsg)
        }

        wsManager.onComplete = { [weak self] _ in
            guard let self = self else { return }
            self.toolUseMap.removeAll()
            self.subagentToolIds.removeAll()

            if !self.wsManager.currentText.isEmpty {
                let executionTime: TimeInterval? = self.processingStartTime.map { Date().timeIntervalSince($0) }
                let tokenCount = self.wsManager.tokenUsage?.used

                let assistantMessage = ChatMessage(
                    role: .assistant,
                    content: self.wsManager.currentText,
                    timestamp: Date(),
                    executionTime: executionTime,
                    tokenCount: tokenCount
                )
                self.messages.append(assistantMessage)
            }
            self.processingStartTime = nil

            self.refreshGitStatus()

            if self.showTodoDrawer && !self.currentTodos.isEmpty {
                self.todoHideTimer?.cancel()
                self.todoHideTimer = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 15_000_000_000)
                    guard let self, !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.showTodoDrawer = false
                        self.isTodoDrawerExpanded = false
                    }
                }
            }

            // Prune old messages to maintain performance in long sessions
            self.pruneMessagesIfNeeded()

            // Clear any lingering transient state from this processing cycle
            self.cleanupAfterProcessingComplete()
        }

        wsManager.onError = { [weak self] error in
            guard let self = self else { return }
            HapticManager.error()

            let errorMessage = ChatMessage(
                role: .error,
                content: "Error: \(error)",
                timestamp: Date()
            )
            self.messages.append(errorMessage)
            self.processingStartTime = nil
        }

        wsManager.onSessionCreated = { [weak self] sessionId in
            guard let self = self else { return }

            let existingSession = self.sessionStore.sessions(for: self.project.path).first { $0.id == sessionId }
            if let existing = existingSession {
                if self.selectedSession?.id != sessionId || self.selectedSession?.summary == nil {
                    self.selectedSession = existing
                }
                self.wsManager.sessionId = sessionId
                MessageStore.saveSessionId(sessionId, for: self.project.path)
                self.sessionStore.setActiveSession(sessionId, for: self.project.path)
                return
            }

            self.wsManager.sessionId = sessionId
            MessageStore.saveSessionId(sessionId, for: self.project.path)

            let summary = self.messages.first { $0.role == .user }?.content.prefix(50).description

            let newSession = ProjectSession(
                id: sessionId,
                summary: summary,
                lastActivity: ISO8601DateFormatter().string(from: Date()),
                messageCount: 1,
                lastUserMessage: summary,
                lastAssistantMessage: nil
            )

            self.sessionStore.addSession(newSession, for: self.project.path)
            self.sessionStore.setActiveSession(sessionId, for: self.project.path)
            self.selectedSession = newSession
        }

        wsManager.onAborted = { [weak self] in
            guard let self = self else { return }
            let abortMsg = ChatMessage(
                role: .system,
                content: "⏹ Task aborted",
                timestamp: Date()
            )
            self.messages.append(abortMsg)
            self.processingStartTime = nil
        }

        wsManager.onSessionRecovered = { [weak self] in
            guard let self = self else { return }
            let recoveryMsg = ChatMessage(
                role: .system,
                content: "⚠️ Previous session expired. Starting fresh session.",
                timestamp: Date()
            )
            self.messages.append(recoveryMsg)
            MessageStore.clearSessionId(for: self.project.path)
            self.wsManager.sessionId = nil
        }

        wsManager.onSessionAttached = { [weak self] in
            guard let self = self else { return }
            let attachMsg = ChatMessage(
                role: .system,
                content: "🔄 Reconnected to active session",
                timestamp: Date()
            )
            self.messages.append(attachMsg)
            log.debug("[ChatViewModel] Successfully reattached to active session")
        }

        wsManager.onSessionEvent = { [weak self] event in
            guard let self = self else { return }
            Task { @MainActor in
                await self.sessionStore.handleCLISessionEvent(event)
            }
        }

        wsManager.onHistory = { [weak self] payload in
            guard let self = self else { return }
            let historyMessages = payload.messages.map { $0.toChatMessage() }
            if !historyMessages.isEmpty {
                self.messages.insert(contentsOf: historyMessages, at: 0)
                // Prune after inserting history to stay within limit
                self.pruneMessagesIfNeeded()
                self.refreshDisplayMessagesCache()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self.scrollToBottomTrigger = true
                }
            }
            log.debug("[ChatViewModel] Loaded \(historyMessages.count) history messages, hasMore: \(payload.hasMore)")
        }
    }

    // MARK: - Question Handling

    func handleQuestionAnswer(_ questionData: AskUserQuestionData) {
        let answerMessage = ChatMessage(
            role: .user,
            content: questionData.formatAnswers(),
            timestamp: Date()
        )
        messages.append(answerMessage)

        wsManager.respondToQuestion(
            requestId: questionData.requestId,
            answers: questionData.answersDict()
        )
        processingStartTime = Date()
    }

    func handleQuestionCancel() {
        wsManager.abortSession()
        wsManager.clearPendingQuestion()
    }

    // MARK: - Display Messages

    var displayMessages: [ChatMessage] {
        cachedDisplayMessages
    }

    var groupedDisplayItems: [DisplayItem] {
        cachedGroupedDisplayItems
    }

    private var currentDisplayMessagesKey: Int {
        var hasher = Hasher()
        hasher.combine(messages.count)
        hasher.combine(messages.last?.id)
        hasher.combine(messages.last?.content.count)
        hasher.combine(searchText)
        hasher.combine(messageFilter)
        hasher.combine(settings.showThinkingBlocks)
        hasher.combine(settings.historyLimit)
        return hasher.finalize()
    }

    func refreshDisplayMessagesCache() {
        let newKey = currentDisplayMessagesKey
        guard newKey != displayMessagesInvalidationKey else { return }
        displayMessagesInvalidationKey = newKey
        cachedDisplayMessages = computeDisplayMessages()
        cachedGroupedDisplayItems = groupMessagesForDisplay(cachedDisplayMessages)
    }

    private func computeDisplayMessages() -> [ChatMessage] {
        var filtered = messages

        if !settings.showThinkingBlocks {
            filtered = filtered.filter { $0.role != .thinking }
        }

        if messageFilter != .all {
            filtered = filtered.filter { messageFilter.matches($0.role) }
        }

        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.content.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Apply history limit - keep only the most recent messages
        let limit = settings.historyLimit.rawValue
        if filtered.count > limit {
            filtered = Array(filtered.suffix(limit))
        }

        return filtered
    }

    // MARK: - Git Status

    func handleGitStatusOnLoad() {
        Task {
            switch gitStatus {
            case .behind:
                await performAutoPull()
            case .dirty, .dirtyAndAhead, .diverged:
                break
            default:
                if gitStatus == .clean || gitStatus == .notGitRepo {
                    showGitBanner = false
                }
            }
        }
    }

    func refreshGitStatus() {
        Task {
            gitStatus = .checking

            let newStatus: GitStatus
            do {
                let apiClient = CLIBridgeAPIClient(serverURL: settings.serverURL)
                let projects = try await apiClient.fetchProjects()
                if let cliProject = projects.first(where: { $0.path == project.path }),
                   let git = cliProject.git {
                    newStatus = git.toGitStatus
                } else {
                    newStatus = .notGitRepo
                }
            } catch {
                log.debug("[ChatViewModel] Failed to fetch git status from API: \(error)")
                newStatus = .error(error.localizedDescription)
            }

            gitStatus = newStatus
            ProjectCache.shared.updateGitStatus(for: project.path, status: newStatus)

            if newStatus == .clean || newStatus == .notGitRepo {
                showGitBanner = false
            } else {
                showGitBanner = true
            }
        }
    }

    func refreshChatContent() async {
        HapticManager.light()

        Task {
            refreshGitStatus()
        }

        if let sessionId = wsManager.sessionId {
            do {
                let apiClient = CLIBridgeAPIClient(serverURL: settings.serverURL)
                let exportResponse = try await apiClient.exportSession(
                    projectPath: project.path,
                    sessionId: sessionId,
                    format: .json
                )
                let historyMessages = parseJSONLToMessages(exportResponse.content)
                if !historyMessages.isEmpty {
                    messages = historyMessages
                }
            } catch {
                log.debug("[ChatViewModel] Failed to refresh session history: \(error)")
            }
        }
    }

    func performAutoPull() async {
        isAutoPulling = true

        do {
            let apiClient = CLIBridgeAPIClient(serverURL: settings.serverURL)
            let response = try await apiClient.gitPull(projectPath: project.path)

            isAutoPulling = false
            if response.commits > 0 {
                gitStatus = .clean
                showGitBanner = false
                ProjectCache.shared.updateGitStatus(for: project.path, status: .clean)

                let filesDesc = response.files.map { " (\($0.count) files)" } ?? ""
                messages.append(ChatMessage(
                    role: .system,
                    content: "✓ Pulled \(response.commits) commit\(response.commits == 1 ? "" : "s")\(filesDesc)",
                    timestamp: Date()
                ))
            } else {
                gitStatus = .clean
                showGitBanner = false
                ProjectCache.shared.updateGitStatus(for: project.path, status: .clean)
            }
        } catch {
            isAutoPulling = false
            let errorStatus = GitStatus.error("Auto-pull failed: \(error.localizedDescription)")
            gitStatus = errorStatus
            ProjectCache.shared.updateGitStatus(for: project.path, status: errorStatus)
        }
    }

    func promptClaudeForCleanup() {
        hasPromptedCleanup = true

        let cleanupPrompt: String
        switch gitStatus {
        case .dirty:
            cleanupPrompt = """
            There are uncommitted changes in this project. Please run `git status` and `git diff` to review the changes, then help me decide how to handle them. Options might include:
            - Committing the changes with an appropriate message
            - Stashing them for later
            - Discarding them if they're not needed
            """
        case .ahead(let count):
            cleanupPrompt = """
            This project has \(count) unpushed commit\(count == 1 ? "" : "s"). Please run `git log --oneline @{upstream}..HEAD` to show me what commits need to be pushed, then help me decide whether to push them now.
            """
        case .dirtyAndAhead:
            cleanupPrompt = """
            This project has both uncommitted changes AND unpushed commits. Please:
            1. Run `git status` to show uncommitted changes
            2. Run `git log --oneline @{upstream}..HEAD` to show unpushed commits
            3. Help me decide how to handle both - whether to commit, stash, push, or discard.
            """
        case .diverged:
            cleanupPrompt = """
            This project has diverged from the remote - there are both local and remote changes. Please:
            1. Run `git status` to show the current state
            2. Run `git log --oneline HEAD...@{upstream}` to show the divergence
            3. Help me resolve this - we may need to rebase or merge.
            """
        default:
            return
        }

        let userMessage = ChatMessage(role: .user, content: cleanupPrompt, timestamp: Date())
        messages.append(userMessage)
        showGitBanner = false

        wsManager.sendMessage(
            cleanupPrompt,
            projectPath: project.path,
            resumeSessionId: effectiveSessionToResume,
            permissionMode: effectivePermissionMode,
            model: effectiveModelId
        )
        processingStartTime = Date()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.scrollToBottomTrigger = true
        }
    }

    func promptClaudeForCommit() {
        let commitPrompt = """
        Please help me commit my changes. Run `git status` and `git diff` to review what has changed, then create a commit with an appropriate message. After committing, push the changes to the remote.
        """

        let userMessage = ChatMessage(role: .user, content: commitPrompt, timestamp: Date())
        messages.append(userMessage)
        showGitBanner = false

        wsManager.sendMessage(
            commitPrompt,
            projectPath: project.path,
            resumeSessionId: effectiveSessionToResume,
            permissionMode: effectivePermissionMode,
            model: effectiveModelId
        )
        processingStartTime = Date()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.scrollToBottomTrigger = true
        }
    }

    func promptClaudeForPush() {
        let pushPrompt = """
        Please push my local commits to the remote. Run `git log --oneline @{upstream}..HEAD` to show what will be pushed, then run `git push` to push the commits.
        """

        let userMessage = ChatMessage(role: .user, content: pushPrompt, timestamp: Date())
        messages.append(userMessage)
        showGitBanner = false

        wsManager.sendMessage(
            pushPrompt,
            projectPath: project.path,
            resumeSessionId: effectiveSessionToResume,
            permissionMode: effectivePermissionMode,
            model: effectiveModelId
        )
        processingStartTime = Date()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.scrollToBottomTrigger = true
        }
    }

    // MARK: - WebSocket State Accessors
    // These expose wsManager properties to avoid nested ObservableObject observation
    // which can cause unnecessary SwiftUI re-renders

    var isProcessing: Bool { wsManager.isProcessing }
    var isAborting: Bool { wsManager.isAborting }
    var isConnected: Bool { wsManager.isConnected }
    var isReattaching: Bool { wsManager.isReattaching }
    var currentStreamingText: String { wsManager.currentText }
    var tokenUsage: TokenUsage? { wsManager.tokenUsage }
    var pendingApproval: ApprovalRequest? { wsManager.pendingApproval }
    var pendingQuestion: AskUserQuestionData? { wsManager.pendingQuestion }
    var isInputQueued: Bool { wsManager.isInputQueued }
    var queuePosition: Int { wsManager.queuePosition }
    var activeSubagent: CLISubagentStartContent? { wsManager.activeSubagent }
    var toolProgress: CLIProgressContent? { wsManager.toolProgress }
    var activeSessionId: String? { wsManager.sessionId }

    func abortSession() { wsManager.abortSession() }
    func approvePendingRequest(alwaysAllow: Bool) { wsManager.approvePendingRequest(alwaysAllow: alwaysAllow) }
    func denyPendingRequest() { wsManager.denyPendingRequest() }
    func cancelQueuedInput() { wsManager.cancelQueuedInput() }
    func clearActiveSubagent() { wsManager.activeSubagent = nil }
    func clearToolProgress() { wsManager.toolProgress = nil }

    // MARK: - Model Selection

    func switchToModel(_ model: ClaudeModel, customId: String? = nil) {
        currentModel = model
        if model == .custom, let customId = customId {
            self.customModelId = customId
            settings.customModelId = customId
        }
    }

    var effectiveModelId: String? {
        let model = currentModel ?? settings.defaultModel
        if model == .custom {
            return customModelId.isEmpty ? nil : customModelId
        }
        return model.modelId
    }

    var effectivePermissionModeValue: PermissionMode {
        projectSettingsStore.effectivePermissionMode(
            for: project.path,
            globalMode: settings.globalPermissionMode
        )
    }

    var effectivePermissionMode: String {
        effectivePermissionModeValue.rawValue
    }

    // MARK: - History Parsing

    func parseJSONLToMessages(_ jsonContent: String) -> [ChatMessage] {
        guard let data = jsonContent.data(using: .utf8) else {
            log.debug("[ChatViewModel] Failed to convert export content to data")
            return []
        }

        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let messagesArray = json["messages"] as? [[String: Any]] {
                log.debug("[ChatViewModel] Found \(messagesArray.count) messages in export")
                return messagesArray.flatMap { parseExportMessage($0) }
            }
        } catch {
            log.debug("[ChatViewModel] Failed to parse export JSON: \(error)")
        }

        return []
    }

    func parseExportMessage(_ json: [String: Any]) -> [ChatMessage] {
        guard let type = json["type"] as? String else { return [] }

        var timestamp = Date()
        if let ts = json["timestamp"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: ts) {
                timestamp = date
            } else {
                formatter.formatOptions = [.withInternetDateTime]
                timestamp = formatter.date(from: ts) ?? Date()
            }
        }

        switch type {
        case "tool_use":
            if let name = json["name"] as? String {
                var toolContent = name
                if let inputDict = json["input"] as? [String: Any],
                   let data = try? JSONSerialization.data(withJSONObject: inputDict),
                   let inputStr = String(data: data, encoding: .utf8) {
                    toolContent = "\(name)(\(inputStr))"
                }
                return [ChatMessage(role: .toolUse, content: toolContent, timestamp: timestamp)]
            }
            return []

        case "tool_result":
            let output = json["output"] as? String ?? json["content"] as? String ?? ""
            let isError = json["is_error"] as? Bool ?? !(json["success"] as? Bool ?? true)
            let role: ChatMessage.Role = isError ? .error : .toolResult
            return [ChatMessage(role: role, content: output, timestamp: timestamp)]

        case "thinking":
            if let thinking = json["content"] as? String, !thinking.isEmpty {
                return [ChatMessage(role: .thinking, content: thinking, timestamp: timestamp)]
            }
            return []

        case "user", "assistant", "system":
            if json["isMeta"] as? Bool == true {
                return []
            }

            if let content = json["content"] as? String, !content.isEmpty {
                if content.hasPrefix("Caveat: The messages below were generated") {
                    return []
                }

                if let localCommand = parseLocalCommandXML(content) {
                    return [localCommand.toChatMessage(timestamp: timestamp)]
                }

                let role: ChatMessage.Role
                switch type {
                case "user": role = .user
                case "assistant": role = .assistant
                default: role = .system
                }
                return [ChatMessage(role: role, content: content, timestamp: timestamp)]
            }
            if let contentArray = json["content"] as? [[String: Any]] {
                return parseStructuredContent(contentArray, messageType: type, timestamp: timestamp)
            }
            return []

        default:
            log.debug("[ChatViewModel] Unknown message type: \(type)")
            return []
        }
    }

    func parseStructuredContent(_ blocks: [[String: Any]], messageType: String, timestamp: Date) -> [ChatMessage] {
        var messages: [ChatMessage] = []

        for block in blocks {
            guard let blockType = block["type"] as? String else { continue }

            switch blockType {
            case "text":
                if let text = block["text"] as? String, !text.isEmpty {
                    let role: ChatMessage.Role = messageType == "user" ? .user : .assistant
                    messages.append(ChatMessage(role: role, content: text, timestamp: timestamp))
                }
            default:
                log.debug("[ChatViewModel] Unexpected nested block type '\(blockType)' - cli-bridge should flatten this")
            }
        }

        return messages
    }

    struct LocalCommand {
        let name: String
        let args: String
        let stdout: String

        func toChatMessage(timestamp: Date) -> ChatMessage {
            var content = name
            if !args.isEmpty {
                content += " \(args)"
            }
            if !stdout.isEmpty {
                content += "\n└ \(stdout)"
            }
            return ChatMessage(role: .system, content: content, timestamp: timestamp)
        }
    }

    func parseLocalCommandXML(_ content: String) -> LocalCommand? {
        guard content.contains("<command-name>") else { return nil }

        guard let nameStart = content.range(of: "<command-name>"),
              let nameEnd = content.range(of: "</command-name>") else {
            return nil
        }
        let name = String(content[nameStart.upperBound..<nameEnd.lowerBound])

        var args = ""
        if let argsStart = content.range(of: "<command-args>"),
           let argsEnd = content.range(of: "</command-args>") {
            args = String(content[argsStart.upperBound..<argsEnd.lowerBound])
        }

        var stdout = ""
        if let stdoutStart = content.range(of: "<local-command-stdout>"),
           let stdoutEnd = content.range(of: "</local-command-stdout>") {
            stdout = String(content[stdoutStart.upperBound..<stdoutEnd.lowerBound])
        }

        return LocalCommand(name: name, args: args, stdout: stdout)
    }

    // MARK: - Change Handlers

    func handleMessagesChange() {
        // Debounce both save and display cache refresh to avoid rapid updates during streaming
        saveDebounceTask?.cancel()
        let projectPath = project.path
        let maxMessages = settings.historyLimit.rawValue
        saveDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            MessageStore.saveMessages(messages, for: projectPath, maxMessages: maxMessages)
        }
        // Cache refresh is guarded by invalidation key, so call is cheap if key unchanged
        // But we still want to refresh to pick up new messages for display
        refreshDisplayMessagesCache()
    }

    // MARK: - Message Pruning

    /// Prunes the messages array to maintain performance during long streaming sessions.
    /// Uses a buffer above the history limit to avoid pruning on every single message.
    private func pruneMessagesIfNeeded() {
        let limit = settings.historyLimit.rawValue
        // Use 20% buffer above limit before pruning to avoid constant array resizing
        let pruneThreshold = limit + max(20, limit / 5)

        guard messages.count > pruneThreshold else { return }

        // Prune down to the limit
        let oldCount = messages.count
        messages = Array(messages.suffix(limit))
        log.debug("[ChatViewModel] Pruned messages from \(oldCount) to \(messages.count)")
    }

    /// Cleanup transient state after a processing cycle completes.
    /// Called from onComplete to prevent accumulation of lingering tasks/state.
    private func cleanupAfterProcessingComplete() {
        // Clear tool tracking maps that may have grown during session
        toolUseMap.removeAll(keepingCapacity: true)
        subagentToolIds.removeAll(keepingCapacity: true)

        // Ensure streaming state is reset
        wsManager.clearCurrentText()
    }

    func handleInputTextChange(_ newText: String) {
        draftDebounceTask?.cancel()
        let projectPath = project.path
        draftDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            MessageStore.saveDraft(newText, for: projectPath)
        }
    }

    func handleProcessingChange(oldValue: Bool, isProcessing: Bool) {
        MessageStore.saveProcessingState(isProcessing, for: project.path)

        if isProcessing && !oldValue {
            streamingMessageId = UUID()
            streamingMessageTimestamp = Date()
        }
    }

    func handleModelChange(oldModel: ClaudeModel, newModel: ClaudeModel) {
        guard oldModel != newModel else { return }
        guard wsManager.connectionState.isConnected else { return }
        log.debug("[ChatViewModel] Model changed from \(oldModel.shortName) to \(newModel.shortName) - calling switchModel")
        wsManager.switchModel(to: newModel)
    }
}
