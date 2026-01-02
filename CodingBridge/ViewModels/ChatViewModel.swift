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

    // MARK: - Combine
    private var cancellables = Set<AnyCancellable>()

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
    @Published var showScrollToBottom = false

    // MARK: - Streaming Message Cache
    @Published var streamingMessageId = UUID()
    @Published var streamingMessageTimestamp = Date()

    // MARK: - Tool Use Tracking (internal state, no UI updates needed)
    /// Maps tool_use_id to tool name for result filtering - not @Published as changes don't affect UI
    var toolUseMap: [String: String] = [:]
    /// Tool IDs created while a subagent was active - not @Published as changes don't affect UI
    var subagentToolIds: Set<String> = []
    /// Stores committed text for message creation in onComplete (adapter clears currentText on commit)
    var committedText: String?

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
    /// Timer to auto-hide banner after 5 seconds
    var gitBannerAutoHideTimer: Task<Void, Never>?
    /// Tracks pending Bash commands that are git operations (for refresh after result)
    var pendingGitCommands: Set<String> = []

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
    var historyLoadTask: Task<Void, Never>?

    // MARK: - Display Messages Cache
    // Note: @Published wrapper triggers view re-render when cache is refreshed
    @Published private var cachedDisplayMessages: [ChatMessage] = []
    @Published private var cachedGroupedDisplayItems: [DisplayItem] = []
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

        // Forward objectWillChange from wsManager to trigger view updates
        // This fixes nested ObservableObject observation issue where SwiftUI
        // doesn't detect changes to wsManager.agentState, etc.
        // Note: No receive(on:) needed since ChatViewModel is @MainActor
        wsManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Listen for git status refresh requests (e.g., app returning from background)
        NotificationCenter.default.publisher(for: .gitStatusRefreshNeeded)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshGitStatus()
            }
            .store(in: &cancellables)
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

        // Forward objectWillChange from wsManager to trigger view updates
        wsManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Listen for git status refresh requests (e.g., app returning from background)
        NotificationCenter.default.publisher(for: .gitStatusRefreshNeeded)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshGitStatus()
            }
            .store(in: &cancellables)
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

        // Note: HealthMonitor is now managed at app level (CodingBridgeApp.swift)
        // to avoid start/stop churn when navigating between views

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
                // No sessions exist - create ephemeral placeholder and connect without sessionId
                log.debug("[ChatViewModel] No sessions found for project - creating ephemeral session")

                // Create ephemeral session placeholder (like startNewSession does)
                // This ensures selectedSession is set for UI consistency
                let ephemeralSession = ProjectSession(
                    id: "new-session-\(UUID().uuidString)",
                    summary: "New Session",
                    lastActivity: ISO8601DateFormatter().string(from: Date()),
                    messageCount: 0,
                    lastUserMessage: nil,
                    lastAssistantMessage: nil
                )
                selectedSession = ephemeralSession

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

        // Cancel any pending history load
        historyLoadTask?.cancel()
        historyLoadTask = nil

        // Cancel git refresh task
        gitRefreshTask?.cancel()
        gitRefreshTask = nil

        // Cancel git banner auto-hide timer
        gitBannerAutoHideTimer?.cancel()
        gitBannerAutoHideTimer = nil

        // Cancel todo hide timer
        todoHideTimer?.cancel()
        todoHideTimer = nil

        // Note: HealthMonitor is now managed at app level - no need to stop here

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
        // Must attach to session (reconnect WebSocket), not just set sessionId property
        // Otherwise messages go to whatever session the WebSocket was previously connected to
        wsManager.attachToSession(sessionId: session.id, projectPath: project.path)
        MessageStore.saveSessionId(session.id, for: project.path)
        loadSessionHistory(session)
    }

    func loadSessionHistory(_ session: ProjectSession) {
        // Cancel any existing history load to prevent race conditions when switching sessions rapidly
        historyLoadTask?.cancel()

        messages = []
        isLoadingHistory = true
        scrollManager.reset()

        // Capture session ID to check for staleness after async operations
        let targetSessionId = session.id

        historyLoadTask = Task {
            do {
                let limit = settings.historyLimit.rawValue
                log.debug("[ChatViewModel] Loading session history via unified API for: \(session.id) (limit: \(limit))")

                let apiClient = CLIBridgeAPIClient(serverURL: settings.serverURL)

                // Use the paginated messages endpoint with unified StoredMessage format
                let response = try await apiClient.fetchInitialMessages(
                    projectPath: project.path,
                    sessionId: session.id,
                    limit: limit
                )

                // Check if task was cancelled or session changed while loading
                guard !Task.isCancelled, selectedSession?.id == targetSessionId else {
                    log.debug("[ChatViewModel] History load cancelled or session changed, discarding results")
                    return
                }

                await wsManager.refreshTokenUsage(projectPath: project.path, sessionId: session.id)

                // Convert StoredMessages to ChatMessages using unified helper
                // Response is in "desc" order (newest first), reverse for chronological display
                let historyMessages = Array(response.toChatMessages().reversed())

                if historyMessages.isEmpty {
                    if let lastMsg = session.lastAssistantMessage {
                        messages.append(ChatMessage(role: .assistant, content: lastMsg, timestamp: Date()))
                    }
                } else {
                    messages = historyMessages
                    log.debug("[ChatViewModel] Loaded \(historyMessages.count) messages via unified API (total: \(response.total), hasMore: \(response.hasMore))")
                }
                isLoadingHistory = false
                refreshDisplayMessagesCache()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.scrollManager.forceScrollToBottom()
                }
            } catch {
                // Check if cancelled before showing error
                guard !Task.isCancelled else { return }
                log.debug("[ChatViewModel] Failed to load session history: \(error)")
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

        // Always scroll to bottom when user sends a message (regardless of auto-scroll setting)
        scrollToBottomTrigger = true

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
        committedText = nil  // Clear before new message cycle
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

    /// Retry: Find the previous user message before the given message and resend it
    /// - Parameter beforeId: The ID of the assistant message to retry (finds previous user message)
    func retryMessage(beforeId: UUID) {
        // Find the index of the message with this ID
        guard let targetIndex = messages.firstIndex(where: { $0.id == beforeId }) else {
            log.warning("[ChatViewModel] Could not find message with ID \(beforeId) for retry")
            return
        }

        // Search backwards for the most recent user message before this one
        var previousUserMessage: ChatMessage?
        for i in stride(from: targetIndex - 1, through: 0, by: -1) {
            if messages[i].role == .user {
                previousUserMessage = messages[i]
                break
            }
        }

        guard let userMessage = previousUserMessage else {
            log.warning("[ChatViewModel] No user message found before message \(beforeId)")
            return
        }

        HapticManager.medium()
        log.info("[ChatViewModel] Retrying message: \(userMessage.content.prefix(50))...")

        // Remove messages from targetIndex onwards (the assistant response and everything after)
        messages.removeSubrange(targetIndex..<messages.count)

        // Scroll to bottom
        scrollToBottomTrigger = true
        processingStartTime = Date()

        // Resend the user message
        wsManager.sendMessage(
            userMessage.content,
            projectPath: project.path,
            resumeSessionId: effectiveSessionToResume,
            permissionMode: effectivePermissionMode,
            images: nil,  // TODO: Support retrying messages with images if needed
            model: effectiveModelId
        )

        MessageStore.saveMessages(messages, for: project.path, maxMessages: settings.historyLimit.rawValue)
    }

    // MARK: - Slash Commands

    func handleSlashCommand(_ command: String) -> Bool {
        let parts = command.split(separator: " ", maxSplits: 1)
        let cmd = String(parts.first ?? "").lowercased()
        let arg = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : nil

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
            return handleResumeCommand(arg: arg)

        case "/model":
            return handleModelCommand(arg: arg)

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

    /// Handle /resume command with optional session ID argument
    /// Usage: /resume [session-id]
    private func handleResumeCommand(arg: String?) -> Bool {
        guard let sessionId = arg, !sessionId.isEmpty else {
            // No argument - show picker
            showingSessionPicker = true
            return true
        }

        // Validate session ID format (should be UUID)
        let cleanedId = sessionId.trimmingCharacters(in: .whitespaces)
        guard UUID(uuidString: cleanedId) != nil else {
            addSystemMessage("Invalid session ID format. Expected UUID (e.g., 550e8400-e29b-41d4-a716-446655440000).")
            return true
        }

        // Find session in local list or create ephemeral reference
        if let existingSession = localSessions.first(where: { $0.id == cleanedId }) {
            selectSession(existingSession)
            addSystemMessage("Resumed session: \(existingSession.summary ?? cleanedId.prefix(8).description)...")
        } else {
            // Create ephemeral session for the ID
            let ephemeralSession = ProjectSession(
                id: cleanedId,
                summary: nil,
                lastActivity: nil,
                messageCount: nil,
                lastUserMessage: nil,
                lastAssistantMessage: nil
            )
            selectSession(ephemeralSession)
            addSystemMessage("Resuming session: \(cleanedId.prefix(8))...")
        }
        return true
    }

    /// Handle /model command with model name argument
    /// Usage: /model <opus|sonnet|haiku|custom-model-id>
    private func handleModelCommand(arg: String?) -> Bool {
        guard let modelArg = arg, !modelArg.isEmpty else {
            // No argument - show current model and usage
            let current = currentModel ?? settings.defaultModel
            addSystemMessage("Current model: \(current.displayName)\nUsage: /model <opus|sonnet|haiku|model-id>")
            return true
        }

        let cleanedArg = modelArg.lowercased().trimmingCharacters(in: .whitespaces)

        // Check for standard model names
        switch cleanedArg {
        case "opus", "opus4.5", "claude-opus":
            switchToModel(.opus)
            settings.defaultModel = .opus
            addSystemMessage("Switched to Opus 4.5")
            return true

        case "sonnet", "sonnet4.5", "claude-sonnet":
            switchToModel(.sonnet)
            settings.defaultModel = .sonnet
            addSystemMessage("Switched to Sonnet 4.5")
            return true

        case "haiku", "haiku4.5", "claude-haiku":
            switchToModel(.haiku)
            settings.defaultModel = .haiku
            addSystemMessage("Switched to Haiku 4.5")
            return true

        default:
            // Validate custom model ID format (should contain hyphen or be claude-like)
            // Valid formats: claude-3-opus-20240229, anthropic.claude-v2, etc.
            let isValidCustomId = cleanedArg.contains("-") ||
                                  cleanedArg.contains(".") ||
                                  cleanedArg.hasPrefix("claude")

            if isValidCustomId {
                switchToModel(.custom, customId: modelArg)  // Use original case
                settings.defaultModel = .custom
                settings.customModelId = modelArg
                addSystemMessage("Switched to custom model: \(modelArg)")
            } else {
                addSystemMessage("Invalid model: '\(modelArg)'. Use opus, sonnet, haiku, or a valid model ID.")
            }
        }
        return true
    }

    func handleClearCommand() {
        log.debug("[ChatViewModel] /clear command - clearing state and reconnecting")

        // Clear UI state
        messages = []
        scrollManager.reset()
        MessageStore.clearMessages(for: project.path)
        MessageStore.clearSessionId(for: project.path)
        sessionStore.clearActiveSessionId(for: project.path)

        // Create ephemeral session placeholder to prevent nil selectedSession issues
        let ephemeralSession = ProjectSession(
            id: "new-session-\(UUID().uuidString)",
            summary: "New Session",
            lastActivity: ISO8601DateFormatter().string(from: Date()),
            messageCount: 0,
            lastUserMessage: nil,
            lastAssistantMessage: nil
        )
        selectedSession = ephemeralSession

        // Disconnect and reconnect WebSocket without sessionId
        wsManager.disconnect()
        wsManager.sessionId = nil
        wsManager.connect(projectPath: project.path, sessionId: nil)

        addSystemMessage("Conversation cleared. Starting fresh.")
        refreshDisplayMessagesCache()
    }

    func handleNewSessionCommand() {
        log.debug("[ChatViewModel] /new command - starting new session")

        // Clear UI state
        messages = []
        scrollManager.reset()
        MessageStore.clearMessages(for: project.path)
        MessageStore.clearSessionId(for: project.path)
        sessionStore.clearActiveSessionId(for: project.path)

        // Create ephemeral session placeholder to prevent nil selectedSession issues
        let ephemeralSession = ProjectSession(
            id: "new-session-\(UUID().uuidString)",
            summary: "New Session",
            lastActivity: ISO8601DateFormatter().string(from: Date()),
            messageCount: 0,
            lastUserMessage: nil,
            lastAssistantMessage: nil
        )
        selectedSession = ephemeralSession

        // Disconnect and reconnect WebSocket without sessionId
        wsManager.disconnect()
        wsManager.sessionId = nil
        wsManager.connect(projectPath: project.path, sessionId: nil)

        addSystemMessage("New session started.")
        refreshDisplayMessagesCache()
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
        wsManager.onText = { _ in
            // Text is accumulated in wsManager.currentText
        }

        wsManager.onTextCommit = { [weak self] text in
            // Capture committed text - message created in onComplete with full metadata
            // (adapter clears currentText on commit, so we store it here)
            self?.committedText = text
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

            // Track Bash git commands for status refresh after completion
            if name == "Bash" && self.isGitCommand(input) {
                self.pendingGitCommands.insert(id)
                log.debug("[ChatViewModel] Tracking git command: \(id.prefix(8))")
            }

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

            // Refresh git status after git command completes
            if self.pendingGitCommands.contains(id) {
                self.pendingGitCommands.remove(id)
                log.debug("[ChatViewModel] Git command completed, refreshing status")
                self.refreshGitStatus()
            }
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

            // Create assistant message from committed text (captured in onTextCommit)
            if let text = self.committedText, !text.isEmpty {
                let executionTime: TimeInterval? = self.processingStartTime.map { Date().timeIntervalSince($0) }
                let tokenCount = self.wsManager.tokenUsage?.used

                let assistantMessage = ChatMessage(
                    role: .assistant,
                    content: text,
                    timestamp: Date(),
                    executionTime: executionTime,
                    tokenCount: tokenCount
                )
                self.messages.append(assistantMessage)
            }
            self.committedText = nil
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

        wsManager.onConnectionError = { [weak self] connectionError in
            guard let self = self else { return }
            HapticManager.error()

            // Convert ConnectionError to AppError and post to ErrorStore for user-facing banner
            let appError = self.mapConnectionError(connectionError)
            ErrorStore.shared.post(appError) { [weak self] in
                // Retry action: attempt to reconnect
                self?.wsManager.connect()
            }
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

            // Reset selectedSession to ephemeral to prevent invalid-session-ID loop
            // Without this, effectiveSessionToResume would keep returning the old invalid ID
            let ephemeralSession = ProjectSession(
                id: "new-session-\(UUID().uuidString)",
                summary: "New Session",
                lastActivity: ISO8601DateFormatter().string(from: Date()),
                messageCount: 0,
                lastUserMessage: nil,
                lastAssistantMessage: nil
            )
            self.selectedSession = ephemeralSession
            self.sessionStore.clearActiveSessionId(for: self.project.path)
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
            // Use unified toChatMessages() which handles denormalized tool_use and filters ephemeral
            let historyMessages = payload.toChatMessages()
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

        wsManager.onSystem = { [weak self] content in
            guard let self = self else { return }
            // System messages with subtype "result" are final response messages from Claude
            // Skip if content matches the last assistant message (cli-bridge sends both)
            if let lastAssistant = self.messages.last(where: { $0.role == .assistant }) {
                if lastAssistant.content == content {
                    log.debug("[ChatViewModel] Skipping duplicate system/result message")
                    return
                }
            }
            // Display as assistant message if it differs
            let systemMsg = ChatMessage(
                role: .assistant,
                content: content,
                timestamp: Date()
            )
            self.messages.append(systemMsg)
            self.refreshDisplayMessagesCache()
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
                let projectDetail = try await apiClient.getProjectDetail(projectPath: project.path)
                if let git = projectDetail.git {
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

            // Notify other views (e.g., HomeView via GitStatusCoordinator)
            NotificationCenter.default.post(
                name: .gitStatusUpdated,
                object: nil,
                userInfo: ["projectPath": project.path, "status": newStatus]
            )

            if newStatus == .clean || newStatus == .notGitRepo {
                showGitBanner = false
            } else {
                showGitBanner = true
                // Auto-hide banner after 5 seconds
                self.startBannerAutoHideTimer()
            }
        }
    }

    /// Show git banner and start auto-hide timer (for manual refresh from toolbar)
    func showGitBannerAndRefresh() {
        showGitBanner = true
        refreshGitStatus()
    }

    /// Start auto-hide timer for git banner (5 seconds)
    private func startBannerAutoHideTimer() {
        gitBannerAutoHideTimer?.cancel()
        gitBannerAutoHideTimer = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            guard let self, !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                self.showGitBanner = false
            }
        }
    }

    /// Check if a Bash command input contains a git operation that affects status
    private func isGitCommand(_ input: String) -> Bool {
        let gitOperations = [
            "git push", "git pull", "git commit", "git merge",
            "git rebase", "git checkout", "git switch", "git restore",
            "git reset", "git stash", "git fetch", "git add", "git rm"
        ]
        let lowercased = input.lowercased()
        return gitOperations.contains { lowercased.contains($0) }
    }

    func refreshChatContent() async {
        HapticManager.light()

        Task {
            refreshGitStatus()
        }

        if let sessionId = wsManager.sessionId {
            do {
                let apiClient = CLIBridgeAPIClient(serverURL: settings.serverURL)
                let response = try await apiClient.fetchInitialMessages(
                    projectPath: project.path,
                    sessionId: sessionId,
                    limit: settings.historyLimit.rawValue
                )
                // Convert using unified format, reverse from desc to chronological
                let historyMessages = Array(response.toChatMessages().reversed())
                if !historyMessages.isEmpty {
                    messages = historyMessages
                    refreshDisplayMessagesCache()
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

    // MARK: - Error Mapping

    /// Convert ConnectionError to AppError for user-facing display via ErrorStore
    private func mapConnectionError(_ error: ConnectionError) -> AppError {
        switch error {
        case .networkUnavailable:
            return .networkUnavailable
        case .serverAtCapacity, .queueFull:
            return .serverUnreachable("Server is at capacity")
        case .reconnectFailed:
            return .connectionFailed("Failed to reconnect after multiple attempts")
        case .invalidServerURL:
            return .connectionFailed("Invalid server URL")
        case .agentTimedOut:
            return .sessionExpired
        case .connectionReplaced:
            return .connectionFailed("Session opened on another device")
        case .sessionNotFound, .sessionInvalid, .sessionExpired:
            return .sessionExpired
        case .rateLimited(let retryAfter):
            return .connectionFailed("Rate limited, retry in \(retryAfter)s")
        case .serverError(_, let message, _):
            return .connectionFailed(message)
        case .authenticationFailed:
            return .connectionFailed("Authentication failed")
        case .connectionFailed(let msg):
            return .connectionFailed(msg)
        case .protocolError(let msg):
            return .connectionFailed("Protocol error: \(msg)")
        case .unknown(let msg):
            return .connectionFailed(msg)
        }
    }
}
