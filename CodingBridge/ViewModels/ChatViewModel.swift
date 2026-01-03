import SwiftUI
import Combine

/// ViewModel for ChatView - manages all chat state and business logic
/// Extracted from ChatView to improve maintainability and testability
///
/// Extensions:
/// - ChatViewModel+Sessions.swift - Session management
/// - ChatViewModel+SlashCommands.swift - Slash command handling
/// - ChatViewModel+StreamEvents.swift - Stream event handling
/// - ChatViewModel+Git.swift - Git operations
/// - ChatViewModel+ManagerState.swift - Manager state accessors and actions
@MainActor
class ChatViewModel: ObservableObject {
    // MARK: - Dependencies
    let project: Project
    let initialGitStatus: GitStatus
    var onSessionsChanged: (() -> Void)?

    // MARK: - Combine
    var cancellables = Set<AnyCancellable>()

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
    /// Tracks whether the current response has been committed to messages
    var hasFinalizedCurrentResponse = false
    /// Tracks how much streaming text has been flushed to messages (for correct tool ordering)
    var flushedTextLength = 0

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
    /// Version counter to force cache invalidation when messages are updated in-place
    /// (hash key only tracks count and last message, so updates to middle messages need this)
    /// Internal access for use in extensions
    var displayCacheVersion: Int = 0

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

        if manager.sessionId == nil,
           let savedSessionId = MessageStore.loadSessionId(for: project.path),
           UUID(uuidString: savedSessionId) != nil {
            manager.sessionId = savedSessionId
        }

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
                    lastActivity: CLIDateFormatter.string(from: Date()),
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

        // Note: HealthMonitor is now managed at app level - no need to stop here

        // Delay disconnect to handle NavigationSplitView layout recreations
        disconnectTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            manager.disconnect(preserveSession: true)
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
        hasFinalizedCurrentResponse = false
        flushedTextLength = 0
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
        hasFinalizedCurrentResponse = false
        flushedTextLength = 0

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

    // MARK: - Helper Methods

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
        hasher.combine(messages.last?.content)
        hasher.combine(displayCacheVersion)  // Force invalidation when messages updated in-place
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

        filtered = filtered.filter { $0.isDisplayable }

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

    // MARK: - Testable Methods (can be overridden in test subclasses)

    /// Load session history - implementation in ChatViewModel+Sessions.swift
    func loadSessionHistory(_ session: ProjectSession) {
        loadSessionHistoryImpl(session)
    }
}
