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
    let manager: CLIBridgeManager
    let ideasStore: IdeasStore
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

    // MARK: - Connection State (previously from adapter)
    @Published var pendingApprovalRequest: ApprovalRequest?
    @Published var pendingQuestionData: AskUserQuestionData?
    @Published var sessionPermissionMode: PermissionMode?
    @Published var isReattachingSession = false

    // MARK: - Streaming Message Identity
    // Stable ID for the streaming message view - only one streaming message exists at a time,
    // so a constant UUID avoids unnecessary @Published overhead and view invalidation
    let streamingMessageId = UUID()
    // Timestamp for streaming message display - uses processingStartTime when available
    var streamingMessageTimestamp: Date { processingStartTime ?? Date() }

    // MARK: - Tool Use Tracking (internal state, no UI updates needed)
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

    // MARK: - Model State
    @Published var currentModel: ClaudeModel?
    @Published var customModelId = ""

    // MARK: - Sheet State
    /// Enum representing which sheet is currently presented (if any)
    enum ActiveSheet: Identifiable {
        case help
        case sessionPicker
        case bookmarks
        case ideasDrawer
        case quickCapture
        case quickSettings
        case modelPicker

        var id: String {
            switch self {
            case .help: return "help"
            case .sessionPicker: return "sessionPicker"
            case .bookmarks: return "bookmarks"
            case .ideasDrawer: return "ideasDrawer"
            case .quickCapture: return "quickCapture"
            case .quickSettings: return "quickSettings"
            case .modelPicker: return "modelPicker"
            }
        }
    }

    @Published var activeSheet: ActiveSheet?

    // Convenience computed properties for compatibility with existing code
    var showingHelpSheet: Bool {
        get { activeSheet == .help }
        set { activeSheet = newValue ? .help : nil }
    }
    var showingSessionPicker: Bool {
        get { activeSheet == .sessionPicker }
        set { activeSheet = newValue ? .sessionPicker : nil }
    }
    var showingBookmarks: Bool {
        get { activeSheet == .bookmarks }
        set { activeSheet = newValue ? .bookmarks : nil }
    }
    var showIdeasDrawer: Bool {
        get { activeSheet == .ideasDrawer }
        set { activeSheet = newValue ? .ideasDrawer : nil }
    }
    var showQuickCapture: Bool {
        get { activeSheet == .quickCapture }
        set { activeSheet = newValue ? .quickCapture : nil }
    }
    var showQuickSettings: Bool {
        get { activeSheet == .quickSettings }
        set { activeSheet = newValue ? .quickSettings : nil }
    }
    var showingModelPicker: Bool {
        get { activeSheet == .modelPicker }
        set { activeSheet = newValue ? .modelPicker : nil }
    }

    // MARK: - Todo Drawer State
    @Published var currentTodos: [TodoListView.TodoItem] = []
    @Published var isTodoDrawerExpanded = false
    @Published var showTodoDrawer = false

    // MARK: - Background Tasks (internal task management, not @Published)
    var disconnectTask: Task<Void, Never>?
    var saveDebounceTask: Task<Void, Never>?
    var draftDebounceTask: Task<Void, Never>?
    var historyLoadTask: Task<Void, Never>?

    // MARK: - Display Messages Cache
    // Note: @Published wrapper triggers view re-render when cache is refreshed
    @Published private var cachedDisplayMessages: [ChatMessage] = []
    private var displayMessagesInvalidationKey: Int = 0

    // MARK: - Initialization

    init(project: Project, initialGitStatus: GitStatus = .unknown, settings: AppSettings, onSessionsChanged: (() -> Void)? = nil) {
        self.project = project
        self.initialGitStatus = initialGitStatus
        self.settings = settings
        self.onSessionsChanged = onSessionsChanged

        // Initialize managers - use CLIBridgeManager directly (no adapter layer)
        self.manager = CLIBridgeManager(serverURL: settings.serverURL)
        self.ideasStore = IdeasStore(projectPath: project.path)

        // Forward objectWillChange from manager to trigger view updates
        // This fixes nested ObservableObject observation issue where SwiftUI
        // doesn't detect changes to manager.agentState, etc.
        // Note: No receive(on:) needed since ChatViewModel is @MainActor
        manager.objectWillChange
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
        manager: CLIBridgeManager,
        onSessionsChanged: (() -> Void)? = nil
    ) {
        self.project = project
        self.initialGitStatus = initialGitStatus
        self.settings = settings
        self.onSessionsChanged = onSessionsChanged
        self.manager = manager
        self.ideasStore = IdeasStore(projectPath: project.path)

        // Forward objectWillChange from manager to trigger view updates
        manager.objectWillChange
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

        // Update manager with actual settings
        manager.updateServerURL(settings.serverURL)
        setupStreamEventHandler()

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
                manager.sessionId = session.id
                Task {
                    await manager.connect(projectPath: project.path, sessionId: session.id)
                }
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

                Task {
                    await manager.connect(projectPath: project.path)
                }
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

        // Note: HealthMonitor is now managed at app level - no need to stop here

        // Delay disconnect to handle NavigationSplitView layout recreations
        disconnectTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            manager.disconnect()
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
        let activeId = manager.sessionId
        if sessionStore.hasLoaded(for: project.path) {
            return localSessions.filterForDisplay(projectPath: project.path, activeSessionId: activeId)
        }
        let baseSessions = localSessions.isEmpty ? (project.sessions ?? []) : localSessions
        return baseSessions.filterForDisplay(projectPath: project.path, activeSessionId: activeId)
    }

    func startNewSession() {
        log.debug("[ChatViewModel] Starting new session - clearing state and reconnecting")

        // Clear UI state
        messages = []
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
        manager.disconnect()
        manager.sessionId = nil
        log.debug("[ChatViewModel] Reconnecting WebSocket without sessionId for fresh session")
        Task {
            await manager.connect(projectPath: project.path, sessionId: nil)
        }

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
        manager.sessionId = mostRecent.id
        selectedSession = mostRecent
        MessageStore.saveSessionId(mostRecent.id, for: project.path)

        if messages.isEmpty {
            loadSessionHistory(mostRecent)
        }
    }

    func attemptSessionReattachment(sessionId: String) {
        Task {
            var attempts = 0
            while !manager.connectionState.isConnected && attempts < 20 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                attempts += 1
            }

            if manager.connectionState.isConnected {
                log.debug("[ChatViewModel] Reattaching to session: \(sessionId.prefix(8))...")
                attachToSession(sessionId: sessionId, projectPath: project.path)
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
        attachToSession(sessionId: session.id, projectPath: project.path)
        MessageStore.saveSessionId(session.id, for: project.path)
        loadSessionHistory(session)
    }

    func loadSessionHistory(_ session: ProjectSession) {
        // Cancel any existing history load to prevent race conditions when switching sessions rapidly
        historyLoadTask?.cancel()

        messages = []
        isLoadingHistory = true

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

                // Token usage is tracked via StreamEvents when messages arrive

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
                    self?.scrollToBottomTrigger = true
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
                    self?.scrollToBottomTrigger = true
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
                manager.sessionId = nil
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

        if let sid = manager.sessionId {
            log.debug("[ChatViewModel] Sending message with sessionId: \(sid.prefix(8))...")
        } else {
            log.debug("[ChatViewModel] Sending message with NO session ID - new session will be created")
        }

        let defaultPrompt = imagesToSend.count == 1 ? "What is this image?" : "What are these images?"
        committedText = nil  // Clear before new message cycle
        sendToManager(
            text.isEmpty ? defaultPrompt : messageToSend,
            projectPath: project.path,
            resumeSessionId: manager.sessionId,
            permissionMode: effectivePermissionModeValue.rawValue,
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
        sendToManager(
            userMessage.content,
            projectPath: project.path,
            resumeSessionId: manager.sessionId,
            permissionMode: effectivePermissionModeValue.rawValue,
            images: nil,  // TODO: Support retrying messages with images if needed
            model: effectiveModelId
        )

        MessageStore.saveMessages(messages, for: project.path, maxMessages: settings.historyLimit.rawValue)
    }

    // MARK: - Slash Commands

    /// Slash command handler closure type
    /// - Parameters:
    ///   - arg: Optional argument string (text after command)
    /// - Returns: true if command was fully handled, false to pass through to server
    typealias SlashCommandHandler = (_ arg: String?) -> Bool

    /// Registry of slash commands mapping command name to handler
    private lazy var slashCommandRegistry: [String: SlashCommandHandler] = [
        "/clear": { [weak self] _ in
            self?.handleClearCommand()
            return true
        },
        "/help": { [weak self] _ in
            self?.showingHelpSheet = true
            return true
        },
        "/exit": { [weak self] _ in
            self?.manager.disconnect()
            return true
        },
        "/init": { [weak self] _ in
            self?.addSystemMessage("Initializing project with Claude...")
            return false
        },
        "/new": { [weak self] _ in
            self?.handleNewSessionCommand()
            return true
        },
        "/resume": { [weak self] arg in
            self?.handleResumeCommand(arg: arg) ?? true
        },
        "/model": { [weak self] arg in
            self?.handleModelCommand(arg: arg) ?? true
        },
        "/compact": { [weak self] _ in
            self?.addSystemMessage("Sending compact request to server...")
            return false
        },
        "/status": { [weak self] _ in
            self?.showStatusInfo()
            return true
        },
    ]

    func handleSlashCommand(_ command: String) -> Bool {
        let parts = command.split(separator: " ", maxSplits: 1)
        let cmd = String(parts.first ?? "").lowercased()
        let arg = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : nil

        if let handler = slashCommandRegistry[cmd] {
            return handler(arg)
        }

        // Unknown command starting with /
        if cmd.hasPrefix("/") {
            addSystemMessage("Unknown command: \(cmd). Type /help for available commands.")
            return true
        }
        return false
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
        manager.disconnect()
        manager.sessionId = nil
        Task {
            await manager.connect(projectPath: project.path, sessionId: nil)
        }

        addSystemMessage("Conversation cleared. Starting fresh.")
        refreshDisplayMessagesCache()
    }

    func handleNewSessionCommand() {
        log.debug("[ChatViewModel] /new command - starting new session")

        // Clear UI state
        messages = []
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
        manager.disconnect()
        manager.sessionId = nil
        Task {
            await manager.connect(projectPath: project.path, sessionId: nil)
        }

        addSystemMessage("New session started.")
        refreshDisplayMessagesCache()
    }

    func showStatusInfo() {
        var status = "Connection: \(manager.connectionState.isConnected ? "Connected" : "Disconnected")"
        if let sessionId = manager.sessionId {
            status += "\nSession: \(sessionId.prefix(8))..."
        }
        if let usage = tokenUsage {
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

    // MARK: - Stream Event Handler

    /// Setup unified StreamEvent handler - replaces individual callbacks
    func setupStreamEventHandler() {
        manager.onEvent = { [weak self] event in
            guard let self = self else { return }
            self.handleStreamEvent(event)
        }
    }

    /// Handle all stream events from CLIBridgeManager
    private func handleStreamEvent(_ event: StreamEvent) {
        switch event {
        // MARK: Content Events
        case .text(let content, let isFinal):
            // Text is accumulated in manager.currentText
            if isFinal {
                // Capture committed text - message created in handleStopped with full metadata
                committedText = content
                manager.clearCurrentText()
            }

        case .thinking(let content):
            let thinkingMsg = ChatMessage(
                role: .thinking,
                content: content,
                timestamp: Date()
            )
            messages.append(thinkingMsg)

        case .toolStart(_, let name, let input):
            // Filter tools from subagent execution (except Task itself which we show)
            if manager.activeSubagent != nil && name != "Task" {
                log.debug("[ChatViewModel] Filtering subagent tool: \(name)")
                return
            }

            // Convert input dict to JSON string
            let inputString = Self.toJSONString(input)
            let toolMsg = ChatMessage(
                role: .toolUse,
                content: "\(name)(\(inputString))",
                timestamp: Date()
            )
            messages.append(toolMsg)

            if name == "TodoWrite" {
                let content = "\(name)(\(inputString))"
                if let todos = TodoListView.parseTodoContent(content), !todos.isEmpty {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        self.currentTodos = todos
                        self.showTodoDrawer = true
                    }
                }
            }

        case .toolResult(_, let tool, let output, _):
            let toolName = tool
            // Filter tool results from subagent execution and Task tool itself
            if manager.activeSubagent != nil && toolName != "Task" {
                log.debug("[ChatViewModel] Filtering subagent tool result: \(toolName)")
                return
            }

            if toolName == "Task" {
                log.debug("[ChatViewModel] Filtering Task tool result")
                return
            }

            let resultMsg = ChatMessage(
                role: .toolResult,
                content: output,
                timestamp: Date()
            )
            messages.append(resultMsg)

        case .system(let content):
            // System messages with subtype "result" are final response messages from Claude
            // Skip if content matches the last assistant message (cli-bridge sends both)
            if let lastAssistant = messages.last(where: { $0.role == .assistant }) {
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
            messages.append(systemMsg)
            refreshDisplayMessagesCache()

        case .user:
            // User message echo - ignore (we already have it locally)
            break

        case .progress, .usage, .stateChanged:
            // These are handled via Combine observation on manager state
            break

        // MARK: Agent State Events
        case .stopped:
            handleStopped()

        case .modelChanged:
            // Model changes are tracked via manager.$currentModel
            break

        case .permissionModeChanged(let mode):
            if let permMode = PermissionMode(rawValue: mode) {
                sessionPermissionMode = permMode
                log.debug("[ChatViewModel] Permission mode changed: \(mode)")
            }

        // MARK: Session Events
        case .connected(let sessionIdValue, _, _):
            handleSessionConnected(sessionId: sessionIdValue)

        case .sessionEvent(let event):
            Task { @MainActor in
                await sessionStore.handleCLISessionEvent(event)
            }

        case .history(let payload):
            handleHistoryPayload(payload)

        // MARK: Interactive Events
        case .permissionRequest(let request):
            // Convert to ApprovalRequest for UI
            let approval = ApprovalRequest(
                id: request.id,
                toolName: request.tool,
                input: request.input.mapValues { $0.value },
                receivedAt: Date()
            )
            pendingApprovalRequest = approval

        case .questionRequest(let request):
            // Convert to AskUserQuestionData for UI
            let questions = request.questions.map { q in
                UserQuestion(
                    question: q.question,
                    header: q.header,
                    options: q.options.map { QuestionOption(label: $0.label, description: $0.description) },
                    multiSelect: q.multiSelect
                )
            }
            pendingQuestionData = AskUserQuestionData(requestId: request.id, questions: questions)

        // MARK: Subagent Events
        case .subagentStart, .subagentComplete:
            // Subagent state tracked via manager.activeSubagent
            break

        // MARK: Queue Events
        case .inputQueued, .queueCleared:
            // Queue state tracked via manager.isInputQueued / queuePosition
            break

        // MARK: Connection Events
        case .connectionReplaced:
            log.warning("[ChatViewModel] Connection replaced by another client")

        case .reconnecting(let attempt, let delay):
            log.info("[ChatViewModel] Reconnecting: attempt \(attempt), delay \(delay)s")

        case .reconnectComplete:
            let attachMsg = ChatMessage(
                role: .system,
                content: "Reconnected to active session",
                timestamp: Date()
            )
            messages.append(attachMsg)
            log.debug("[ChatViewModel] Successfully reconnected to session")

        case .connectionError(let error):
            handleConnectionError(error)

        case .networkStatusChanged(let isOnline):
            log.debug("[ChatViewModel] Network status: \(isOnline ? "online" : "offline")")

        case .cursorEvicted, .cursorInvalid:
            // Cursor issues handled at manager level with reconnect
            break

        // MARK: Error Events
        case .error(let payload):
            HapticManager.error()
            let errorMessage = ChatMessage(
                role: .error,
                content: "Error: \(payload.message)",
                timestamp: Date()
            )
            messages.append(errorMessage)
            processingStartTime = nil
        }
    }

    // MARK: - Event Handlers

    private func handleStopped() {
        // Create assistant message from committed text
        if let text = committedText, !text.isEmpty {
            let executionTime: TimeInterval? = processingStartTime.map { Date().timeIntervalSince($0) }
            let tokenCount = manager.tokenUsage?.totalTokens

            let assistantMessage = ChatMessage(
                role: .assistant,
                content: text,
                timestamp: Date(),
                executionTime: executionTime,
                tokenCount: tokenCount
            )
            messages.append(assistantMessage)
        }
        committedText = nil
        processingStartTime = nil

        refreshGitStatus()

        cleanupAfterProcessingComplete()
    }

    private func handleSessionConnected(sessionId: String) {
        let existingSession = sessionStore.sessions(for: project.path).first { $0.id == sessionId }
        if let existing = existingSession {
            if selectedSession?.id != sessionId || selectedSession?.summary == nil {
                selectedSession = existing
            }
            MessageStore.saveSessionId(sessionId, for: project.path)
            sessionStore.setActiveSession(sessionId, for: project.path)
            return
        }

        MessageStore.saveSessionId(sessionId, for: project.path)

        let summary = messages.first { $0.role == .user }?.content.prefix(50).description

        let newSession = ProjectSession(
            id: sessionId,
            summary: summary,
            lastActivity: ISO8601DateFormatter().string(from: Date()),
            messageCount: 1,
            lastUserMessage: summary,
            lastAssistantMessage: nil
        )

        sessionStore.addSession(newSession, for: project.path)
        sessionStore.setActiveSession(sessionId, for: project.path)
        selectedSession = newSession
    }

    private func handleHistoryPayload(_ payload: CLIHistoryPayload) {
        // Use unified toChatMessages() which handles denormalized tool_use and filters ephemeral
        let historyMessages = payload.toChatMessages()
        if !historyMessages.isEmpty {
            messages.insert(contentsOf: historyMessages, at: 0)
            refreshDisplayMessagesCache()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.scrollToBottomTrigger = true
            }
        }
        log.debug("[ChatViewModel] Loaded \(historyMessages.count) history messages, hasMore: \(payload.hasMore)")
    }

    private func handleConnectionError(_ error: ConnectionError) {
        HapticManager.error()

        // Handle session-related errors specially
        switch error {
        case .sessionNotFound, .sessionInvalid, .sessionExpired:
            let recoveryMsg = ChatMessage(
                role: .system,
                content: "Previous session expired. Starting fresh session.",
                timestamp: Date()
            )
            messages.append(recoveryMsg)
            MessageStore.clearSessionId(for: project.path)

            // Reset selectedSession to ephemeral to prevent invalid-session-ID loop
            let ephemeralSession = ProjectSession(
                id: "new-session-\(UUID().uuidString)",
                summary: "New Session",
                lastActivity: ISO8601DateFormatter().string(from: Date()),
                messageCount: 0,
                lastUserMessage: nil,
                lastAssistantMessage: nil
            )
            selectedSession = ephemeralSession
            sessionStore.clearActiveSessionId(for: project.path)
            return
        default:
            break
        }

        // Convert ConnectionError to AppError and post to ErrorStore for user-facing banner
        let appError = mapConnectionError(error)
        ErrorStore.shared.post(appError) { [weak self] in
            // Retry action: attempt to reconnect
            guard let self = self else { return }
            Task {
                await self.manager.connect(
                    projectPath: self.project.path,
                    sessionId: self.manager.sessionId
                )
            }
        }
    }

    // MARK: - JSON Serialization Helper

    private static func toJSONString(_ value: [String: JSONValue]) -> String {
        toJSONString(value.mapValues { $0.value })
    }

    private static func toJSONString(_ value: [String: Any]) -> String {
        let sanitized = sanitizeForJSON(value)
        if let data = try? JSONSerialization.data(withJSONObject: sanitized),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }

    private static func sanitizeForJSON(_ value: Any) -> Any {
        switch value {
        case let array as [Any]:
            return array.map { sanitizeForJSON($0) }
        case let dict as [String: Any]:
            return dict.mapValues { sanitizeForJSON($0) }
        case let string as String:
            return string
        case let number as NSNumber:
            return number
        case let bool as Bool:
            return bool
        case let int as Int:
            return int
        case let double as Double:
            return double
        case is NSNull:
            return NSNull()
        default:
            return String(describing: value)
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

        Task {
            do {
                try await manager.respondToQuestion(
                    id: questionData.requestId,
                    answers: questionData.answersDict()
                )
                pendingQuestionData = nil
            } catch {
                log.error("[ChatViewModel] Failed to respond to question: \(error)")
            }
        }
        processingStartTime = Date()
    }

    func handleQuestionCancel() {
        abortSession()
        clearPendingQuestion()
    }

    // MARK: - Display Messages

    var displayMessages: [ChatMessage] {
        cachedDisplayMessages
    }

    /// Grouped display items for the chat view - computed inline from cached display messages
    var groupedDisplayItems: [DisplayItem] {
        groupMessagesForDisplay(cachedDisplayMessages)
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
            }
        }
    }

    /// Show git banner and refresh status (for manual refresh from toolbar)
    func showGitBannerAndRefresh() {
        showGitBanner = true
        refreshGitStatus()
    }

    func refreshChatContent() async {
        HapticManager.light()

        Task {
            refreshGitStatus()
        }

        if let sessionId = manager.sessionId {
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

        sendToManager(
            cleanupPrompt,
            projectPath: project.path,
            resumeSessionId: manager.sessionId,
            permissionMode: effectivePermissionModeValue.rawValue,
            images: nil,
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

        sendToManager(
            commitPrompt,
            projectPath: project.path,
            resumeSessionId: manager.sessionId,
            permissionMode: effectivePermissionModeValue.rawValue,
            images: nil,
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

        sendToManager(
            pushPrompt,
            projectPath: project.path,
            resumeSessionId: manager.sessionId,
            permissionMode: effectivePermissionModeValue.rawValue,
            images: nil,
            model: effectiveModelId
        )
        processingStartTime = Date()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.scrollToBottomTrigger = true
        }
    }

    // MARK: - Manager State Accessors
    // These expose manager properties to avoid nested ObservableObject observation
    // which can cause unnecessary SwiftUI re-renders

    var isProcessing: Bool { manager.agentState.isProcessing }
    // Aborting state is transient - tracks whether an interrupt was requested but not yet complete
    // For now, we don't have explicit abort tracking, so this is always false
    var isAborting: Bool { false }
    var isConnected: Bool { manager.connectionState.isConnected }
    var isReattaching: Bool { isReattachingSession }
    var currentStreamingText: String { manager.currentText }
    var tokenUsage: TokenUsage? {
        guard let usage = manager.tokenUsage else { return nil }
        return TokenUsage(
            used: usage.contextUsed ?? usage.totalTokens,
            total: usage.contextLimit ?? 200_000
        )
    }
    var pendingApproval: ApprovalRequest? { pendingApprovalRequest }
    var pendingQuestion: AskUserQuestionData? { pendingQuestionData }
    var isInputQueued: Bool { manager.isInputQueued }
    var queuePosition: Int { manager.queuePosition }
    var activeSubagent: CLISubagentStartContent? { manager.activeSubagent }
    var toolProgress: CLIProgressContent? { manager.toolProgress }
    var activeSessionId: String? { manager.sessionId }

    func abortSession() {
        Task {
            do {
                try await manager.interrupt()
                let abortMsg = ChatMessage(
                    role: .system,
                    content: "Task aborted",
                    timestamp: Date()
                )
                messages.append(abortMsg)
                processingStartTime = nil
            } catch {
                log.error("[ChatViewModel] Failed to abort: \(error)")
            }
        }
    }

    func approvePendingRequest(alwaysAllow: Bool) {
        guard let approval = pendingApprovalRequest else { return }
        let choice: CLIPermissionChoice = alwaysAllow ? .always : .allow
        Task {
            do {
                try await manager.respondToPermission(id: approval.id, choice: choice)
                pendingApprovalRequest = nil
            } catch {
                log.error("[ChatViewModel] Failed to approve: \(error)")
            }
        }
    }

    func denyPendingRequest() {
        guard let approval = pendingApprovalRequest else { return }
        Task {
            do {
                try await manager.respondToPermission(id: approval.id, choice: .deny)
                pendingApprovalRequest = nil
            } catch {
                log.error("[ChatViewModel] Failed to deny: \(error)")
            }
        }
    }

    func cancelQueuedInput() {
        guard manager.isInputQueued else { return }
        Task {
            do {
                try await manager.cancelQueuedInput()
            } catch {
                log.error("[ChatViewModel] Failed to cancel queued input: \(error)")
            }
        }
    }

    func clearPendingQuestion() {
        pendingQuestionData = nil
    }

    func clearActiveSubagent() { manager.activeSubagent = nil }
    func clearToolProgress() { manager.toolProgress = nil }

    // MARK: - Message Sending Helpers

    /// Send a message to the manager, handling connection if needed
    private func sendToManager(
        _ message: String,
        projectPath: String,
        resumeSessionId: String?,
        permissionMode: String?,
        images: [ImageAttachment]?,
        model: String?
    ) {
        Task {
            do {
                // Ensure connected to the right project/session
                await manager.connect(
                    projectPath: projectPath,
                    sessionId: resumeSessionId,
                    model: model
                )

                // Set permission mode if specified
                if let mode = permissionMode, let cliMode = CLIPermissionMode(rawValue: mode) {
                    try await manager.setPermissionMode(cliMode)
                }

                // Convert images to CLIImageAttachment if present
                var cliImages: [CLIImageAttachment]?
                if let images = images, !images.isEmpty {
                    cliImages = images.map { attachment in
                        let base64 = attachment.dataForSending.base64EncodedString()
                        return CLIImageAttachment(
                            type: .base64,
                            data: base64,
                            mimeType: attachment.mimeType
                        )
                    }
                }

                // Get thinking mode if active (not normal)
                let thinkingMode = settings.thinkingMode == .normal ? nil : settings.thinkingMode.rawValue

                // Send the message
                try await manager.sendInput(message, images: cliImages, thinkingMode: thinkingMode)
            } catch {
                log.error("[ChatViewModel] Failed to send message: \(error)")
                let errorMessage = ChatMessage(
                    role: .error,
                    content: "Failed to send message: \(error.localizedDescription)",
                    timestamp: Date()
                )
                messages.append(errorMessage)
                processingStartTime = nil
            }
        }
    }

    /// Attach to an existing session (for session picker selection)
    private func attachToSession(sessionId: String, projectPath: String) {
        isReattachingSession = true
        Task {
            await manager.connect(
                projectPath: projectPath,
                sessionId: sessionId
            )
            isReattachingSession = false
        }
    }

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

    /// Unified permission resolution using PermissionManager pipeline.
    /// Resolution order (highest to lowest priority):
    /// 1. Session override (per-session UI override)
    /// 2. Local project override (iOS ProjectSettingsStore)
    /// 3. Server project config (cli-bridge settings)
    /// 4. Global app setting (iOS AppSettings)
    /// 5. Server global default (cli-bridge config)
    var effectivePermissionModeValue: PermissionMode {
        PermissionManager.shared.resolvePermissionMode(
            for: project.path,
            sessionOverride: sessionPermissionMode,
            localProjectOverride: projectSettingsStore.permissionModeOverride(for: project.path),
            globalAppSetting: settings.globalPermissionMode
        )
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

    /// Cleanup transient state after a processing cycle completes.
    /// Called from onComplete to prevent accumulation of lingering tasks/state.
    private func cleanupAfterProcessingComplete() {
        // Ensure streaming state is reset
        manager.clearCurrentText()
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
        // Note: streamingMessageId is now a stable constant, and streamingMessageTimestamp
        // is derived from processingStartTime, so no manual reset is needed here
    }

    func handleModelChange(oldModel: ClaudeModel, newModel: ClaudeModel) {
        guard oldModel != newModel else { return }
        guard manager.connectionState.isConnected else { return }
        guard let modelId = newModel.modelId else {
            log.debug("[ChatViewModel] Model \(newModel.shortName) has no modelId, skipping switch")
            return
        }
        log.debug("[ChatViewModel] Model changed from \(oldModel.shortName) to \(newModel.shortName) - calling setModel")
        Task {
            do {
                try await manager.setModel(modelId)
            } catch {
                log.error("[ChatViewModel] Failed to switch model: \(error)")
            }
        }
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
