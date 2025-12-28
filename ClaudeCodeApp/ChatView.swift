import SwiftUI
import UIKit
import PhotosUI

// MARK: - ChatView

struct ChatView: View {
    // MARK: - Properties
    let project: Project
    let apiClient: APIClient
    let initialGitStatus: GitStatus
    var onSessionsChanged: (() -> Void)?

    // MARK: - Environment
    @EnvironmentObject var settings: AppSettings
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Managers (StateObject/ObservedObject)
    @StateObject private var wsManager: WebSocketManager
    @StateObject private var claudeHelper: ClaudeHelper
    @StateObject private var ideasStore: IdeasStore
    @StateObject private var scrollManager = ScrollStateManager()
    @ObservedObject private var sessionManager = SessionManager.shared
    @ObservedObject private var sshManager = SSHManager.shared
    @ObservedObject private var projectSettingsStore = ProjectSettingsStore.shared

    // MARK: - Chat State (messages, input, session)
    /// iOS 26+: Migrate to @IncrementalState for better List performance with large message lists
    /// Add `.incrementalID()` modifier to CLIMessageView using `message.id`
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var selectedImage: Data?
    @State private var processingStartTime: Date?
    @State private var selectedSession: ProjectSession?
    @State private var isUploadingImage = false
    @State private var isLoadingHistory = false
    @State private var scrollToBottomTrigger = false
    @State private var pendingQuestions: AskUserQuestionData?

    // MARK: - Streaming Message Cache (prevents view thrashing during streaming)
    @State private var streamingMessageId = UUID()
    @State private var streamingMessageTimestamp = Date()

    // MARK: - Search State
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var messageFilter: MessageFilter = .all

    // MARK: - Git State
    @State private var gitStatus: GitStatus = .unknown
    @State private var isAutoPulling = false
    @State private var showGitBanner = true
    @State private var hasPromptedCleanup = false
    @State private var gitRefreshTask: Task<Void, Never>?

    // MARK: - Model State
    @State private var showingModelPicker = false
    @State private var currentModel: ClaudeModel?
    @State private var customModelId = ""

    // MARK: - Sheet State
    @State private var showingHelpSheet = false
    @State private var showingSessionPicker = false
    @State private var showingBookmarks = false
    @State private var showIdeasDrawer = false
    @State private var showQuickCapture = false
    @State private var showQuickSettings = false

    // MARK: - Scroll State
    @State private var visibleMessageIds: Set<String> = []
    @State private var savedScrollPosition: String?
    @FocusState private var isInputFocused: Bool

    // MARK: - Background Tasks
    @State private var disconnectTask: Task<Void, Never>?
    @State private var analyzeTask: Task<Void, Never>?
    @State private var saveDebounceTask: Task<Void, Never>?

    // MARK: - Display Messages Cache (prevents recomputation on every render)
    @State private var cachedDisplayMessages: [ChatMessage] = []
    @State private var displayMessagesInvalidationKey: Int = 0

    init(project: Project, apiClient: APIClient, initialGitStatus: GitStatus = .unknown, onSessionsChanged: (() -> Void)? = nil) {
        self.project = project
        self.apiClient = apiClient
        self.initialGitStatus = initialGitStatus
        self.onSessionsChanged = onSessionsChanged
        // Initialize WebSocketManager without settings - will be configured in onAppear
        _wsManager = StateObject(wrappedValue: WebSocketManager())
        _claudeHelper = StateObject(wrappedValue: ClaudeHelper(settings: AppSettings()))
        _ideasStore = StateObject(wrappedValue: IdeasStore(projectPath: project.path))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar (when searching)
            if isSearching {
                ChatSearchBar(
                    searchText: $searchText,
                    isSearching: $isSearching,
                    selectedFilter: $messageFilter
                )

                // Result count
                SearchResultCount(count: displayMessages.count, searchText: searchText)
            }

            // Git status banner (when there are local changes)
            gitStatusBannerView

            sessionPickerView
            messagesScrollView
            statusAndInputView
        }
        .background(CLITheme.background(for: colorScheme))
        .navigationBarTitleDisplayMode(.inline)
        // iOS 26+: Toolbar will automatically adopt Liquid Glass styling
        // Using Material for glass-compatible background on iOS 17-25
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            // Custom title with git status
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Text(project.title)
                        .font(.headline)
                        .foregroundColor(CLITheme.primaryText(for: colorScheme))

                    // Tappable git status indicator
                    Button {
                        refreshGitStatus()
                    } label: {
                        GitStatusIndicator(status: gitStatus)
                    }
                    .buttonStyle(.plain)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // Search button
                    Button {
                        withAnimation {
                            isSearching.toggle()
                            if !isSearching {
                                searchText = ""
                                messageFilter = .all
                            }
                        }
                    } label: {
                        Image(systemName: isSearching ? "magnifyingglass.circle.fill" : "magnifyingglass")
                            .foregroundColor(isSearching ? CLITheme.blue(for: colorScheme) : CLITheme.secondaryText(for: colorScheme))
                    }
                    .accessibilityLabel(isSearching ? "Close search" : "Search messages")

                    // Ideas button
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "lightbulb")
                            .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                        // Badge for idea count
                        if ideasStore.ideas.count > 0 {
                            Text(ideasStore.ideas.count > 99 ? "99+" : "\(ideasStore.ideas.count)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(CLITheme.red(for: colorScheme))
                                .clipShape(Capsule())
                                .offset(x: 8, y: -8)
                        }
                    }
                    .onTapGesture {
                        showIdeasDrawer = true
                    }
                    .onLongPressGesture(minimumDuration: 0.4) {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        showQuickCapture = true
                    }
                    .accessibilityLabel("Ideas")
                    .accessibilityHint("Tap to open ideas drawer, hold to quick capture")
                    .accessibilityValue(ideasStore.ideas.count > 0 ? "\(ideasStore.ideas.count) ideas" : "No ideas")

                    // More options menu
                    Menu {
                        Button {
                            startNewSession()
                        } label: {
                            Label("New Chat", systemImage: "plus")
                        }

                        Button {
                            showingBookmarks = true
                        } label: {
                            Label("Bookmarks", systemImage: "bookmark")
                        }

                        if wsManager.isProcessing {
                            Button(role: .destructive) {
                                wsManager.abortSession()
                            } label: {
                                Label("Abort", systemImage: "stop.circle")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                    }
                    .accessibilityLabel("Chat options")
                    .accessibilityHint("Open menu with new chat, bookmarks, and abort options")
                }
            }
        }
        .onAppear {
            // Cancel any pending disconnect (handles NavigationSplitView recreations)
            disconnectTask?.cancel()
            disconnectTask = nil

            // Update managers with actual EnvironmentObject settings
            wsManager.updateSettings(settings)
            claudeHelper.updateSettings(settings)
            setupWebSocketCallbacks()
            wsManager.connect()

            // Load persisted messages asynchronously to avoid blocking main thread
            Task {
                let savedMessages = await MessageStore.loadMessages(for: project.path)
                if !savedMessages.isEmpty {
                    messages = savedMessages
                    // Initialize display messages cache
                    refreshDisplayMessagesCache()
                    // Trigger scroll to bottom after a short delay to allow SwiftUI to render
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        scrollToBottomTrigger = true
                    }
                } else {
                    // Initialize empty cache
                    refreshDisplayMessagesCache()
                }
            }

            // Restore last session ID for conversation continuity
            let wasProcessing = MessageStore.loadProcessingState(for: project.path)
            if let savedSessionId = MessageStore.loadSessionId(for: project.path) {
                print("[ChatView] Loaded saved session ID: \(savedSessionId.prefix(8))...")
                wsManager.sessionId = savedSessionId
                // Find matching session in project sessions for UI
                if let sessions = project.sessions {
                    selectedSession = sessions.first { $0.id == savedSessionId }
                    if selectedSession != nil {
                        print("[ChatView] Found matching session in project.sessions")
                    } else {
                        print("[ChatView] WARNING: Saved session not found in project.sessions (count: \(sessions.count))")
                    }
                }

                // Check if we need to reattach to an active session
                if wasProcessing {
                    print("[ChatView] Session was processing when app closed - attempting reattachment...")
                    // Wait for WebSocket to connect, then attempt reattachment
                    Task {
                        // Wait for connection to be established
                        var attempts = 0
                        while !wsManager.connectionState.isConnected && attempts < 20 {
                            try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
                            attempts += 1
                        }

                        if wsManager.connectionState.isConnected {
                            wsManager.attachToSession(sessionId: savedSessionId, projectPath: project.path)
                        } else {
                            print("[ChatView] Could not reattach - WebSocket not connected after wait")
                            // Clear the processing state since we couldn't reattach
                            MessageStore.clearProcessingState(for: project.path)
                        }
                    }
                }
            } else {
                print("[ChatView] No saved session ID found for project")
                // Auto-select the most recent session if available
                if let sessions = project.sessions,
                   let mostRecent = sessions.sorted(by: { ($0.lastActivity ?? "") > ($1.lastActivity ?? "") }).first,
                   (mostRecent.messageCount ?? 0) > 1 {
                    print("[ChatView] Auto-selecting most recent session: \(mostRecent.id.prefix(8))...")
                    wsManager.sessionId = mostRecent.id
                    selectedSession = mostRecent
                    MessageStore.saveSessionId(mostRecent.id, for: project.path)
                }
                // Clear any stale processing state if no session ID
                if wasProcessing {
                    MessageStore.clearProcessingState(for: project.path)
                }
            }

            // Load draft input
            let savedDraft = MessageStore.loadDraft(for: project.path)
            if !savedDraft.isEmpty {
                inputText = savedDraft
            }

            // Auto-focus input field after view loads
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isInputFocused = true
            }

            // Handle git status from ContentView
            gitStatus = initialGitStatus
            handleGitStatusOnLoad()

            // Initialize model state
            customModelId = settings.customModelId

            // Start periodic git status refresh task (every 30 seconds)
            gitRefreshTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 30_000_000_000)  // 30 seconds
                    guard !Task.isCancelled else { break }
                    await MainActor.run {
                        refreshGitStatus()
                    }
                }
            }
        }
        .onDisappear {
            // Cancel debounce and save messages immediately when leaving
            saveDebounceTask?.cancel()
            saveDebounceTask = nil
            MessageStore.saveMessages(messages, for: project.path, maxMessages: settings.historyLimit.rawValue)

            // Cancel git refresh task
            gitRefreshTask?.cancel()
            gitRefreshTask = nil

            // Cancel any running message analysis
            analyzeTask?.cancel()
            analyzeTask = nil

            // Delay disconnect to handle NavigationSplitView layout recreations
            // If onAppear is called again quickly, the disconnect will be cancelled
            disconnectTask = Task {
                try? await Task.sleep(nanoseconds: 500_000_000)  // 500ms delay
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    wsManager.disconnect()
                }
            }
        }
        .onChange(of: messages) { _, newMessages in
            // Debounce save to avoid excessive file I/O during streaming
            // UI cache refreshes immediately, but file save waits 500ms for batching
            saveDebounceTask?.cancel()
            let projectPath = project.path
            let maxMessages = settings.historyLimit.rawValue
            saveDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 500_000_000)  // 500ms debounce
                guard !Task.isCancelled else { return }
                MessageStore.saveMessages(newMessages, for: projectPath, maxMessages: maxMessages)
            }
            // Refresh display messages cache immediately for responsive UI
            refreshDisplayMessagesCache()
        }
        .onChange(of: searchText) { _, _ in
            // Refresh display messages cache when search changes
            refreshDisplayMessagesCache()
        }
        .onChange(of: messageFilter) { _, _ in
            // Refresh display messages cache when filter changes
            refreshDisplayMessagesCache()
        }
        .onChange(of: inputText) { _, newText in
            // Auto-save draft input
            MessageStore.saveDraft(newText, for: project.path)

            // Clear suggestions when user starts typing
            if !newText.isEmpty {
                claudeHelper.clearSuggestions()
            }
        }
        .onChange(of: wsManager.isProcessing) { oldValue, isProcessing in
            // Save processing state for session recovery on app restart
            MessageStore.saveProcessingState(isProcessing, for: project.path)

            // Reset streaming message cache when new streaming session starts
            if isProcessing && !oldValue {
                streamingMessageId = UUID()
                streamingMessageTimestamp = Date()
            }

            // Refocus input when processing completes
            if !isProcessing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isInputFocused = true
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // App came to foreground
                wsManager.isAppInForeground = true
                // Reconnect if disconnected
                if !wsManager.isConnected {
                    print("[ChatView] App active - reconnecting WebSocket")
                    wsManager.connect()
                }
            case .inactive:
                // App is inactive (transitioning)
                break
            case .background:
                // App went to background
                wsManager.isAppInForeground = false
                print("[ChatView] App backgrounded")
            @unknown default:
                break
            }
        }
        .sheet(item: $pendingQuestions) { questionData in
            userQuestionsSheet(questionData)
        }
        .sheet(isPresented: $showingHelpSheet) {
            SlashCommandHelpSheet()
        }
        .sheet(isPresented: $showingSessionPicker) {
            SessionPickerSheet(
                project: project,
                sessions: localSessionsBinding,
                onSelect: { session in
                    showingSessionPicker = false
                    selectedSession = session
                    wsManager.sessionId = session.id
                    MessageStore.saveSessionId(session.id, for: project.path)
                    loadSessionHistory(session)
                },
                onCancel: {
                    showingSessionPicker = false
                },
                onDelete: { session in
                    Task { await deleteSession(session) }
                }
            )
        }
        .sheet(isPresented: $showingModelPicker) {
            CustomModelPickerSheet(
                customModelId: $customModelId,
                onConfirm: { modelId in
                    showingModelPicker = false
                    switchToModel(.custom, customId: modelId)
                    // Save custom model ID to settings
                    settings.customModelId = modelId
                },
                onCancel: {
                    showingModelPicker = false
                }
            )
        }
        .sheet(isPresented: $showingBookmarks) {
            BookmarksView()
                .environmentObject(settings)
        }
        .sheet(isPresented: $showIdeasDrawer) {
            IdeasDrawerSheet(
                isPresented: $showIdeasDrawer,
                ideasStore: ideasStore,
                claudeHelper: claudeHelper,
                projectPath: project.path,
                currentSessionId: wsManager.sessionId,
                onSendIdea: { idea in
                    appendToInput(idea.formattedPrompt)
                }
            )
        }
        .sheet(isPresented: $showQuickCapture) {
            QuickCaptureSheet(isPresented: $showQuickCapture) { text in
                ideasStore.quickAdd(text)
            }
        }
        .onAppear {
            // Initialize sessions via SessionManager - loads ALL via SSH (API only returns ~5)
            // Only load if we haven't already loaded from SSH for this project
            if !sessionManager.hasLoaded(for: project.path) {
                // Pre-populate with API sessions ONLY as temporary fallback while SSH loads
                // This will be replaced once SSH load completes
                // Note: SessionManager.addSession() rejects deleted sessions
                if localSessions.isEmpty {
                    for session in project.sessions ?? [] {
                        sessionManager.addSession(session, for: project.path)
                    }
                }
                // Load all sessions via SSH in background (this becomes the source of truth)
                Task {
                    await sessionManager.loadSessions(for: project.path, settings: settings)
                }
            }
        }
        // MARK: - Keyboard Shortcuts (iPad)
        .background {
            keyboardShortcutButtons
        }
    }

    // MARK: - Keyboard Shortcut Buttons

    /// Hidden buttons that respond to keyboard shortcuts on iPad
    @ViewBuilder
    private var keyboardShortcutButtons: some View {
        // Cmd+Return: Send message
        Button("") {
            sendMessage()
        }
        .keyboardShortcut(.return, modifiers: .command)
        .hidden()

        // Cmd+K: Clear conversation
        Button("") {
            handleClearCommand()
        }
        .keyboardShortcut("k", modifiers: .command)
        .hidden()

        // Cmd+N: New session
        Button("") {
            handleNewSessionCommand()
        }
        .keyboardShortcut("n", modifiers: .command)
        .hidden()

        // Cmd+.: Abort current request
        Button("") {
            if wsManager.isProcessing {
                wsManager.abortSession()
            }
        }
        .keyboardShortcut(".", modifiers: .command)
        .hidden()

        // Cmd+/: Show help
        Button("") {
            showingHelpSheet = true
        }
        .keyboardShortcut("/", modifiers: .command)
        .hidden()

        // Cmd+R: Resume session picker
        Button("") {
            showingSessionPicker = true
        }
        .keyboardShortcut("r", modifiers: .command)
        .hidden()
    }

    /// Sheet view for AskUserQuestion - extracted to help Swift compiler
    @ViewBuilder
    private func userQuestionsSheet(_ questionData: AskUserQuestionData) -> some View {
        // Use a StateObject wrapper to hold the mutable question data
        // This avoids binding issues that can cause the sheet to freeze
        UserQuestionsSheetWrapper(
            initialData: questionData,
            onSubmit: { answer in
                handleQuestionAnswer(answer)
            },
            onCancel: {
                handleQuestionCancel()
            }
        )
    }

    /// Handle submission of question answers
    private func handleQuestionAnswer(_ answer: String) {
        let answerMessage = ChatMessage(
            role: .user,
            content: answer,
            timestamp: Date()
        )
        messages.append(answerMessage)

        // Use stored session ID for resume
        let sessionToResume = wsManager.sessionId ?? selectedSession?.id
        wsManager.sendMessage(
            answer,
            projectPath: project.path,
            resumeSessionId: sessionToResume,
            permissionMode: effectivePermissionMode,
            model: effectiveModelId
        )
        processingStartTime = Date()
        pendingQuestions = nil
    }

    /// Handle cancellation of question dialog
    private func handleQuestionCancel() {
        wsManager.abortSession()
        pendingQuestions = nil
    }

    // MARK: - View Components (extracted to help Swift compiler)

    /// Sessions from SessionManager (single source of truth)
    private var localSessions: [ProjectSession] {
        sessionManager.sessions(for: project.path)
    }

    /// Binding for SessionPicker views
    private var localSessionsBinding: Binding<[ProjectSession]> {
        Binding(
            get: { sessionManager.sessions(for: project.path) },
            set: { _ in /* Updates go through SessionManager methods */ }
        )
    }

    /// Combined sessions list - SessionManager as single source of truth
    /// Only falls back to project.sessions before SSH has loaded
    private var sessions: [ProjectSession] {
        // If we've loaded from SSH, always use SessionManager (even if empty = all deleted)
        if sessionManager.hasLoaded(for: project.path) {
            return localSessions
        }
        // Before SSH loads, use API data as fallback
        return localSessions.isEmpty ? (project.sessions ?? []) : localSessions
    }

    @ViewBuilder
    private var sessionPickerView: some View {
        if !sessions.isEmpty {
            SessionPicker(
                sessions: localSessionsBinding,
                project: project,
                selected: $selectedSession,
                isLoading: isLoadingHistory,
                isProcessing: wsManager.isProcessing,
                activeSessionId: wsManager.sessionId,
                onSelect: { session in
                    wsManager.sessionId = session.id
                    MessageStore.saveSessionId(session.id, for: project.path)
                    loadSessionHistory(session)
                },
                onNew: {
                    startNewSession()
                },
                onDelete: { session in
                    Task {
                        await deleteSession(session)
                    }
                }
            )
        }
    }

    /// Start a completely new session - clears messages and resets session ID
    private func startNewSession() {
        messages = []
        wsManager.sessionId = nil
        selectedSession = nil
        scrollManager.reset()  // Reset scroll state for fresh session
        MessageStore.clearMessages(for: project.path)
        MessageStore.clearSessionId(for: project.path)

        // Add welcome message for new session
        let welcomeMessage = ChatMessage(
            role: .system,
            content: "New session started. How can I help you?",
            timestamp: Date()
        )
        messages.append(welcomeMessage)
    }

    @ViewBuilder
    private var gitStatusBannerView: some View {
        if showGitBanner {
            switch gitStatus {
            case .dirty, .dirtyAndAhead, .diverged:
                // Warning banner for local changes
                GitSyncBanner(
                    status: gitStatus,
                    isAutoPulling: false,
                    isRefreshing: gitStatus == .checking,
                    onDismiss: { showGitBanner = false },
                    onRefresh: { refreshGitStatus() },
                    onPull: nil,
                    onCommit: { promptClaudeForCommit() },
                    onAskClaude: { promptClaudeForCleanup() }
                )

            case .behind:
                // Auto-pull in progress or behind indicator
                GitSyncBanner(
                    status: gitStatus,
                    isAutoPulling: isAutoPulling,
                    isRefreshing: gitStatus == .checking,
                    onDismiss: { showGitBanner = false },
                    onRefresh: { refreshGitStatus() },
                    onPull: { Task { await performAutoPull() } },
                    onCommit: nil,
                    onAskClaude: nil
                )

            case .ahead:
                // Unpushed commits indicator
                GitSyncBanner(
                    status: gitStatus,
                    isAutoPulling: false,
                    isRefreshing: gitStatus == .checking,
                    onDismiss: { showGitBanner = false },
                    onRefresh: { refreshGitStatus() },
                    onPull: nil,
                    onCommit: { promptClaudeForPush() },
                    onAskClaude: { promptClaudeForCleanup() }
                )

            default:
                EmptyView()
            }
        }
    }

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            GeometryReader { outerGeometry in
                ZStack(alignment: .bottom) {
                    ScrollView {
                        messagesListView
                            .background(
                                GeometryReader { contentGeometry in
                                    Color.clear
                                        .preference(
                                            key: ContentSizePreferenceKey.self,
                                            value: contentGeometry.size
                                        )
                                        // Track scroll offset for user scroll detection
                                        .preference(
                                            key: ScrollOffsetPreferenceKey.self,
                                            value: contentGeometry.frame(in: .named("chatScroll")).minY
                                        )
                                }
                            )
                    }
                    .coordinateSpace(name: "chatScroll")
                    .scrollDismissesKeyboard(.interactively)
                    .background(CLITheme.background(for: colorScheme))
                    // Detect user scrolling - uses debounced handler to prevent UI freezes
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                        // Use debounced handler to avoid rapid state updates during scrolling
                        scrollManager.handleScrollOffset(offset)
                    }
                    // Track scroll position to detect user scrolling up
                    .onPreferenceChange(ContentSizePreferenceKey.self) { contentSize in
                        // Only track when content is larger than viewport
                        if contentSize.height > outerGeometry.size.height {
                            // Content size changed - request scroll if auto-scroll is enabled
                            if settings.autoScrollEnabled {
                                scrollManager.requestScrollToBottom()
                            }
                        }
                    }
                    // Detect user scroll gesture to disable auto-scroll when scrolled up
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 5)
                            .onChanged { value in
                                // User is scrolling up (negative translation = scrolling up in content)
                                if value.translation.height > 0 {
                                    // Scrolling up (finger moving down) - might want to disable auto-scroll
                                    // We'll let the scroll position tracker handle the actual logic
                                }
                            }
                    )

                    // Scroll to bottom button - appears when user has scrolled up
                    if !scrollManager.isAutoScrollEnabled {
                        Button {
                            scrollManager.forceScrollToBottom()
                        } label: {
                            Image(systemName: "chevron.down.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(CLITheme.blue(for: colorScheme))
                                .background(
                                    Circle()
                                        .fill(CLITheme.background(for: colorScheme))
                                        .frame(width: 32, height: 32)
                                )
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        }
                        .padding(.bottom, 12)
                        .transition(.opacity.combined(with: .scale))
                        .animation(.easeInOut(duration: 0.2), value: scrollManager.isAutoScrollEnabled)
                    }
                }
                // Unified scroll trigger - responds to scrollManager.shouldScroll
                .onChange(of: scrollManager.shouldScroll) { _, shouldScroll in
                    if shouldScroll {
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo("bottomAnchor", anchor: .bottom)
                        }
                    }
                }
                // Consolidated scroll triggers - all go through scrollManager for debouncing
                // Removed currentText.count handler to prevent scroll jitter during streaming
                .onChange(of: messages.count) { _, _ in
                    guard settings.autoScrollEnabled else { return }
                    scrollManager.requestScrollToBottom()
                }
                .onChange(of: wsManager.isProcessing) { _, isProcessing in
                    guard settings.autoScrollEnabled else { return }
                    // Scroll when processing starts or ends
                    scrollManager.requestScrollToBottom()
                }
                // Handle explicit scroll trigger (loading history, etc.)
                .onChange(of: scrollToBottomTrigger) { _, shouldScroll in
                    if shouldScroll {
                        // Force scroll bypasses user intent tracking
                        scrollManager.forceScrollToBottom()
                        scrollToBottomTrigger = false
                    }
                }
                .onAppear {
                    // Scroll to bottom on initial appear
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        scrollManager.forceScrollToBottom()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                    // Find the first visible message to restore scroll position after rotation
                    if let firstVisibleId = visibleMessageIds.first,
                       let messageUUID = UUID(uuidString: firstVisibleId),
                       displayMessages.contains(where: { $0.id == messageUUID }) {
                        savedScrollPosition = firstVisibleId
                        // Restore scroll position after layout updates
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            if let positionId = savedScrollPosition {
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    proxy.scrollTo(UUID(uuidString: positionId), anchor: .top)
                                }
                                savedScrollPosition = nil
                            }
                        }
                    }
                }
            }
        }
    }

    /// Messages filtered based on search, filter, and user settings.
    /// Uses cached result to avoid recomputation on every render during scrolling.
    private var displayMessages: [ChatMessage] {
        // Return cached value - cache is invalidated by onChange handlers
        cachedDisplayMessages
    }

    /// Compute the current invalidation key based on filter dependencies.
    /// When this changes, the cache needs to be refreshed.
    private var currentDisplayMessagesKey: Int {
        var hasher = Hasher()
        hasher.combine(messages.count)
        hasher.combine(messages.last?.id)
        hasher.combine(messages.last?.content.count)  // Detect content updates
        hasher.combine(searchText)
        hasher.combine(messageFilter)
        hasher.combine(settings.showThinkingBlocks)
        return hasher.finalize()
    }

    /// Refresh the cached display messages when dependencies change.
    private func refreshDisplayMessagesCache() {
        let newKey = currentDisplayMessagesKey
        guard newKey != displayMessagesInvalidationKey else { return }
        displayMessagesInvalidationKey = newKey
        cachedDisplayMessages = computeDisplayMessages()
    }

    /// Compute filtered messages (called only when cache is invalidated).
    private func computeDisplayMessages() -> [ChatMessage] {
        var filtered = messages

        // Filter out ClaudeHelper internal prompts (suggestions, file hints, idea enhancement)
        filtered = filtered.filter { !isClaudeHelperPrompt($0.content) }

        // Apply thinking block visibility setting
        if !settings.showThinkingBlocks {
            filtered = filtered.filter { $0.role != .thinking }
        }

        // Apply message type filter
        if messageFilter != .all {
            filtered = filtered.filter { messageFilter.matches($0.role) }
        }

        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.content.localizedCaseInsensitiveContains(searchText)
            }
        }

        return filtered
    }

    /// Check if a message is a ClaudeHelper internal prompt or response that should be hidden
    private func isClaudeHelperPrompt(_ content: String) -> Bool {
        // User prompts from ClaudeHelper
        let helperPrefixes = [
            "Based on this conversation context, suggest",
            "Based on this conversation, which files would be most relevant",
            "You are helping a developer expand a quick idea into an actionable prompt",
            "Analyze this Claude Code response and suggest"
        ]
        if helperPrefixes.contains(where: { content.hasPrefix($0) }) {
            return true
        }

        // JSON responses from ClaudeHelper (suggestions array or enhanced idea object)
        // Handle both compact and pretty-printed JSON, and markdown code blocks
        var trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip markdown code fence if present (```json ... ```)
        if trimmed.hasPrefix("```") {
            // Remove opening fence (```json or ```)
            if let firstNewline = trimmed.firstIndex(of: "\n") {
                trimmed = String(trimmed[trimmed.index(after: firstNewline)...])
            }
            // Remove closing fence
            if trimmed.hasSuffix("```") {
                trimmed = String(trimmed.dropLast(3))
            }
            trimmed = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Suggestions array: starts with [ and contains "label" and "prompt"
        if trimmed.hasPrefix("[") && trimmed.contains("\"label\"") && trimmed.contains("\"prompt\"") {
            return true
        }

        // Enhanced idea object: starts with { and contains "expandedPrompt"
        if trimmed.hasPrefix("{") && trimmed.contains("\"expandedPrompt\"") {
            return true
        }

        return false
    }

    private var messagesListView: some View {
        LazyVStack(alignment: .leading, spacing: 2) {
            ForEach(displayMessages) { message in
                CLIMessageView(
                    message: message,
                    projectPath: project.path,
                    projectTitle: project.title,
                    onAnalyze: { msg in
                        // Cancel any previous analysis task
                        analyzeTask?.cancel()
                        // Use ClaudeHelper to analyze the message
                        analyzeTask = Task {
                            guard !Task.isCancelled else { return }
                            await claudeHelper.analyzeMessage(
                                msg,
                                recentMessages: messages,
                                projectPath: project.path,
                                sessionId: wsManager.sessionId  // Use current session to avoid creating orphan sessions
                            )
                        }
                    }
                )
                .id(message.id)
                .onAppear {
                    visibleMessageIds.insert(message.id.uuidString)
                }
                .onDisappear {
                    visibleMessageIds.remove(message.id.uuidString)
                }
            }

            if wsManager.isProcessing {
                streamingIndicatorView
            }

            // Bottom anchor - use Spacer with explicit frame to ensure it's always rendered
            // Color.clear can be skipped by LazyVStack, causing scroll failures
            Spacer()
                .frame(height: 1)
                .id("bottomAnchor")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var streamingIndicatorView: some View {
        if wsManager.isReattaching {
            // Show reattaching indicator when reconnecting to active session
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Reconnecting to session...")
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
                Spacer()
            }
            .font(settings.scaledFont(.body))
            .padding(.vertical, 4)
            .id("reattaching")
        } else if wsManager.currentText.isEmpty {
            // Minimal waiting indicator - status bar already shows processing state
            HStack(spacing: 6) {
                Text("+")
                    .foregroundColor(CLITheme.yellow(for: colorScheme))
                Text("...")
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
                Spacer()
            }
            .font(settings.scaledFont(.body))
            .padding(.vertical, 4)
            .id("streaming")
        } else {
            // Use cached ID and timestamp to prevent view thrashing during streaming
            // The message struct is still recreated, but with stable identity
            CLIMessageView(
                message: ChatMessage(
                    id: streamingMessageId,
                    role: .assistant,
                    content: wsManager.currentText,
                    timestamp: streamingMessageTimestamp,
                    isStreaming: true
                ),
                projectPath: project.path,
                projectTitle: project.title
            )
            .id(streamingMessageId)  // Stable ID prevents LazyVStack recalculation
        }
    }

    private var statusAndInputView: some View {
        VStack(spacing: 0) {
            // Unified status bar with quick settings access
            UnifiedStatusBar(
                isProcessing: wsManager.isProcessing,
                connectionState: wsManager.connectionState,
                tokenUsage: wsManager.tokenUsage,
                effectiveSkipPermissions: effectiveSkipPermissions,
                projectPath: project.path,
                showQuickSettings: $showQuickSettings
            )

            // AI-powered suggestion chips (shown when enabled, not processing, and not typing)
            if settings.autoSuggestionsEnabled && !wsManager.isProcessing && inputText.isEmpty && !claudeHelper.suggestedActions.isEmpty {
                SuggestionChipsView(
                    suggestions: claudeHelper.suggestedActions,
                    isLoading: claudeHelper.isLoading,
                    onSelect: { suggestion in
                        // Insert the prompt and send immediately
                        inputText = suggestion.prompt
                        sendMessage()
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            CLIInputView(
                text: $inputText,
                selectedImage: $selectedImage,
                isProcessing: wsManager.isProcessing,
                isAborting: wsManager.isAborting,
                projectPath: project.path,
                isFocused: _isInputFocused,
                onSend: sendMessage,
                onAbort: { wsManager.abortSession() },
                recentMessages: messages,
                claudeHelper: claudeHelper,
                sessionId: wsManager.sessionId  // Pass session ID to avoid creating orphan sessions
            )
            .id("input-view")
        }
        .sheet(isPresented: $showQuickSettings) {
            QuickSettingsSheet(
                tokenUsage: wsManager.tokenUsage.map { (current: $0.used, max: $0.total) }
            )
        }
    }

    private func setupWebSocketCallbacks() {
        wsManager.onText = { text in
            // Text is accumulated in wsManager.currentText (shown in streaming view)
        }

        wsManager.onTextCommit = { text in
            // Text segment is complete (before a tool use) - add as message
            let assistantMsg = ChatMessage(
                role: .assistant,
                content: text,
                timestamp: Date()
            )
            messages.append(assistantMsg)
        }

        wsManager.onToolUse = { name, input in
            let toolMsg = ChatMessage(
                role: .toolUse,
                content: "\(name)(\(input))",
                timestamp: Date()
            )
            messages.append(toolMsg)
        }

        wsManager.onToolResult = { result in
            // Store full result - truncation is handled in display
            let resultMsg = ChatMessage(
                role: .toolResult,
                content: result,
                timestamp: Date()
            )
            messages.append(resultMsg)
        }

        wsManager.onThinking = { thinking in
            let thinkingMsg = ChatMessage(
                role: .thinking,
                content: thinking,
                timestamp: Date()
            )
            messages.append(thinkingMsg)
        }

        wsManager.onComplete = { _ in
            // Add final assistant message with execution time and token count
            if !wsManager.currentText.isEmpty {
                // Calculate execution time
                let executionTime: TimeInterval? = processingStartTime.map { Date().timeIntervalSince($0) }

                // Get token count from current usage
                let tokenCount = wsManager.tokenUsage?.used

                let assistantMessage = ChatMessage(
                    role: .assistant,
                    content: wsManager.currentText,
                    timestamp: Date(),
                    executionTime: executionTime,
                    tokenCount: tokenCount
                )
                messages.append(assistantMessage)
            }
            processingStartTime = nil

            // Refresh git status after task completion
            refreshGitStatus()

            // Generate AI-powered suggestions for next actions using current session context
            if settings.autoSuggestionsEnabled {
                Task {
                    await claudeHelper.generateSuggestions(
                        recentMessages: messages,
                        projectPath: project.path,
                        currentSessionId: wsManager.sessionId  // Use current session for full context
                    )
                }
            }
        }

        wsManager.onError = { error in
            let errorMessage = ChatMessage(
                role: .error,
                content: "Error: \(error)",
                timestamp: Date()
            )
            messages.append(errorMessage)
            processingStartTime = nil
        }

        wsManager.onSessionCreated = { sessionId in
            print("[ChatView] NEW SESSION CREATED: \(sessionId.prefix(8))...")
            // Set wsManager.sessionId so SessionPicker's activeSessionId includes this session
            wsManager.sessionId = sessionId
            // Save session ID for continuity when returning to this project
            MessageStore.saveSessionId(sessionId, for: project.path)

            // Create a new session entry and add to local list
            // Use the first user message as the summary if available
            let summary = messages.first { $0.role == .user }?.content.prefix(50).description

            let newSession = ProjectSession(
                id: sessionId,
                summary: summary,
                messageCount: 1,
                lastActivity: ISO8601DateFormatter().string(from: Date()),
                lastUserMessage: summary,
                lastAssistantMessage: nil
            )

            // Add the new session to SessionManager
            sessionManager.addSession(newSession, for: project.path)
            sessionManager.setActiveSession(sessionId, for: project.path)

            // Select the new session in the picker
            selectedSession = newSession
        }

        wsManager.onAskUserQuestion = { questionData in
            // Show the question UI sheet
            // Only set if we don't already have pending questions (prevents duplicate dialogs)
            if pendingQuestions == nil {
                print("[ChatView] Received AskUserQuestion with \(questionData.questions.count) questions")
                pendingQuestions = questionData
            } else {
                print("[ChatView] Ignoring duplicate AskUserQuestion - already showing dialog")
            }
        }

        wsManager.onAborted = {
            // Show feedback that the task was aborted
            let abortMsg = ChatMessage(
                role: .system,
                content: "⏹ Task aborted",
                timestamp: Date()
            )
            messages.append(abortMsg)
            processingStartTime = nil
        }

        wsManager.onSessionRecovered = { [weak wsManager] in
            // Show feedback that session was recovered
            let recoveryMsg = ChatMessage(
                role: .system,
                content: "⚠️ Previous session expired. Starting fresh session.",
                timestamp: Date()
            )
            messages.append(recoveryMsg)

            // Clear the stored session ID for this project
            MessageStore.clearSessionId(for: project.path)

            // CRITICAL: Clear wsManager's sessionId so next message creates new session
            wsManager?.sessionId = nil
        }

        wsManager.onSessionAttached = {
            // Show feedback that we successfully reattached to active session
            let attachMsg = ChatMessage(
                role: .system,
                content: "🔄 Reconnected to active session",
                timestamp: Date()
            )
            messages.append(attachMsg)
            print("[ChatView] Successfully reattached to active session")
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || selectedImage != nil else { return }

        // Check for slash commands (client-side handling)
        if text.hasPrefix("/") && selectedImage == nil {
            if handleSlashCommand(text) {
                inputText = ""
                return
            }
            // If command not handled, fall through to send to server
        }

        // Capture image before clearing
        let imageToSend = selectedImage

        // Add user message with optional image
        let userMessage = ChatMessage(
            role: .user,
            content: text.isEmpty ? "[Image attached]" : text,
            timestamp: Date(),
            imageData: imageToSend
        )
        messages.append(userMessage)

        inputText = ""
        selectedImage = nil
        processingStartTime = Date()

        // Apply thinking mode suffix (silently - not shown in UI)
        let messageToSend = text.isEmpty ? text : settings.applyThinkingMode(to: text)

        // Use stored session ID (from wsManager) if available, falling back to selected session
        // This ensures we resume the correct session even if selectedSession is nil
        let sessionToResume = wsManager.sessionId ?? selectedSession?.id

        // Debug: Log session ID being used
        if let sid = sessionToResume {
            print("[ChatView] Sending message with sessionToResume: \(sid.prefix(8))...")
        } else {
            print("[ChatView] WARNING: Sending message with NO session ID - new session will be created!")
        }

        // If we have an image, send it with the message
        if let imageData = imageToSend {
            // Send message with image data directly via WebSocket
            wsManager.sendMessage(
                text.isEmpty ? "What is this image?" : messageToSend,
                projectPath: project.path,
                resumeSessionId: sessionToResume,
                permissionMode: effectivePermissionMode,
                imageData: imageData,
                model: effectiveModelId
            )
        } else {
            // No image - just send text
            wsManager.sendMessage(
                messageToSend,
                projectPath: project.path,
                resumeSessionId: sessionToResume,
                permissionMode: effectivePermissionMode,
                model: effectiveModelId
            )
        }

        // Persist messages
        MessageStore.saveMessages(messages, for: project.path, maxMessages: settings.historyLimit.rawValue)
    }

    // MARK: - Slash Commands

    /// Handle slash commands, returns true if command was handled
    private func handleSlashCommand(_ command: String) -> Bool {
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
            // Disconnect and go back
            wsManager.disconnect()
            dismiss()
            return true

        case "/init":
            // Pass to Claude to create/modify CLAUDE.md
            addSystemMessage("Initializing project with Claude...")
            return false  // Let it pass through to server

        case "/new":
            // Start a new session (local command)
            handleNewSessionCommand()
            return true

        case "/resume":
            // Show session picker
            showingSessionPicker = true
            return true

        case "/compact":
            // Send to server - this is handled server-side
            addSystemMessage("Sending compact request to server...")
            return false  // Let it pass through to server

        case "/status":
            // Show connection status
            showStatusInfo()
            return true

        default:
            // Unknown command - show hint and let it pass to server
            if cmd.hasPrefix("/") {
                addSystemMessage("Unknown command: \(cmd). Type /help for available commands.")
                return true
            }
            return false
        }
    }

    private func handleClearCommand() {
        // Add confirmation message, then clear
        messages.removeAll()
        wsManager.sessionId = nil
        selectedSession = nil
        scrollManager.reset()  // Reset scroll state for fresh session
        addSystemMessage("Conversation cleared. Starting fresh.")
        MessageStore.clearMessages(for: project.path)
        MessageStore.clearSessionId(for: project.path)
    }

    private func handleNewSessionCommand() {
        // Clear and start new session
        messages.removeAll()
        wsManager.sessionId = nil
        selectedSession = nil
        scrollManager.reset()  // Reset scroll state for fresh session
        addSystemMessage("New session started.")
        MessageStore.clearMessages(for: project.path)
        MessageStore.clearSessionId(for: project.path)
    }

    private func showStatusInfo() {
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

    private func addSystemMessage(_ content: String) {
        let msg = ChatMessage(role: .system, content: content, timestamp: Date())
        messages.append(msg)
    }

    /// Append content to the input field with smart spacing
    private func appendToInput(_ content: String) {
        if inputText.isEmpty {
            inputText = content + " "
        } else if inputText.hasSuffix(" ") {
            inputText += content + " "
        } else {
            inputText += " " + content + " "
        }
    }

    /// Load all sessions via SSH (backend API only returns ~5)
    /// Delegates to SessionManager for centralized state management
    private func loadAllSessionsViaSSH() {
        Task {
            await sessionManager.loadSessions(for: project.path, settings: settings)
        }
    }

    /// Load full session history via API
    private func loadSessionHistory(_ session: ProjectSession) {
        messages = []  // Clear current messages
        isLoadingHistory = true
        scrollManager.reset()  // Reset scroll state for new history

        Task {
            do {
                print("[ChatView] Loading session history via API for: \(session.id)")

                // Fetch session messages via API (much simpler than SSH!)
                let sessionMessages = try await apiClient.fetchSessionMessages(
                    projectName: project.name,
                    sessionId: session.id
                )

                // Convert API messages to ChatMessages
                let historyMessages = sessionMessages.compactMap { $0.toChatMessage() }

                await MainActor.run {
                    isLoadingHistory = false
                    if historyMessages.isEmpty {
                        // Fallback to lastAssistantMessage if parsing failed
                        if let lastMsg = session.lastAssistantMessage {
                            messages.append(ChatMessage(role: .assistant, content: lastMsg, timestamp: Date()))
                        }
                    } else {
                        messages = historyMessages
                        print("[ChatView] Loaded \(historyMessages.count) messages from session history via API")
                    }
                    // Trigger scroll to bottom after a short delay to allow SwiftUI to render the messages
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        scrollToBottomTrigger = true
                    }
                }
            } catch {
                print("[ChatView] Failed to load session history via API: \(error)")
                await MainActor.run {
                    isLoadingHistory = false
                    // Fallback to lastAssistantMessage
                    if let lastMsg = session.lastAssistantMessage {
                        messages.append(ChatMessage(role: .assistant, content: lastMsg, timestamp: Date()))
                    }
                    // Show error message
                    messages.append(ChatMessage(role: .system, content: "Could not load history: \(error.localizedDescription)", timestamp: Date()))
                    // Trigger scroll to bottom after a short delay to allow SwiftUI to render
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        scrollToBottomTrigger = true
                    }
                }
            }
        }
    }

    /// Delete a session from the server
    private func deleteSession(_ session: ProjectSession) async {
        print("[ChatView] Deleting session: \(session.id)")

        // Use SessionManager for centralized delete
        let success = await sessionManager.deleteSession(session, projectPath: project.path, settings: settings)

        if success {
            // If we deleted the currently selected session, clear it
            if selectedSession?.id == session.id {
                selectedSession = nil
                messages.removeAll()
                wsManager.sessionId = nil
                MessageStore.clearSessionId(for: project.path)
            }

            // Notify parent to refresh project list
            onSessionsChanged?()
        } else {
            print("[ChatView] Failed to delete session: \(session.id)")
        }
    }

    // MARK: - Git Sync Handling

    /// Handle git status when view loads
    private func handleGitStatusOnLoad() {
        Task {
            switch gitStatus {
            case .behind:
                // Auto-pull for clean projects that are behind
                await performAutoPull()

            case .dirty, .dirtyAndAhead, .diverged:
                // Show banner and optionally auto-prompt Claude
                if !hasPromptedCleanup && messages.isEmpty {
                    // Only auto-prompt if this is a fresh session
                    // User can tap the banner to ask Claude later
                }

            default:
                // Hide banner for clean/unknown/notGitRepo
                if gitStatus == .clean || gitStatus == .notGitRepo {
                    showGitBanner = false
                }
            }
        }
    }

    /// Refresh git status for this project
    private func refreshGitStatus() {
        Task {
            gitStatus = .checking
            let newStatus = await sshManager.checkGitStatusWithAutoConnect(
                project.path,
                settings: settings
            )
            await MainActor.run {
                gitStatus = newStatus

                // Hide banner if now clean
                if newStatus == .clean || newStatus == .notGitRepo {
                    showGitBanner = false
                } else {
                    // Show banner for any actionable status
                    showGitBanner = true
                }
            }
        }
    }

    /// Perform auto-pull for projects that are behind remote
    private func performAutoPull() async {
        isAutoPulling = true

        let success = await sshManager.gitPullWithAutoConnect(project.path, settings: settings)

        await MainActor.run {
            isAutoPulling = false
            if success {
                // Update status to clean after successful pull
                gitStatus = .clean
                showGitBanner = false

                // Add system message about the pull
                messages.append(ChatMessage(
                    role: .system,
                    content: "✓ Auto-pulled latest changes from remote",
                    timestamp: Date()
                ))
            } else {
                // Show error in banner
                gitStatus = .error("Auto-pull failed")
            }
        }
    }

    /// Send a message to Claude asking to help with local changes
    private func promptClaudeForCleanup() {
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

        // Add user message
        let userMessage = ChatMessage(role: .user, content: cleanupPrompt, timestamp: Date())
        messages.append(userMessage)

        // Hide banner after adding message to avoid layout shift during scroll
        showGitBanner = false

        // Send to Claude (use stored session ID for resume)
        let sessionToResume = wsManager.sessionId ?? selectedSession?.id
        wsManager.sendMessage(
            cleanupPrompt,
            projectPath: project.path,
            resumeSessionId: sessionToResume,
            permissionMode: effectivePermissionMode,
            model: effectiveModelId
        )
        processingStartTime = Date()

        // Trigger scroll to bottom after a brief delay to let layout settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            scrollToBottomTrigger = true
        }
    }

    /// Send a message to Claude asking to commit changes
    private func promptClaudeForCommit() {
        let commitPrompt = """
        Please help me commit my changes. Run `git status` and `git diff` to review what has changed, then create a commit with an appropriate message. After committing, push the changes to the remote.
        """

        // Add user message
        let userMessage = ChatMessage(role: .user, content: commitPrompt, timestamp: Date())
        messages.append(userMessage)

        // Hide banner after adding message to avoid layout shift during scroll
        showGitBanner = false

        // Send to Claude (use stored session ID for resume)
        let sessionToResume = wsManager.sessionId ?? selectedSession?.id
        wsManager.sendMessage(
            commitPrompt,
            projectPath: project.path,
            resumeSessionId: sessionToResume,
            permissionMode: effectivePermissionMode,
            model: effectiveModelId
        )
        processingStartTime = Date()

        // Trigger scroll to bottom after a brief delay to let layout settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            scrollToBottomTrigger = true
        }
    }

    /// Send a message to Claude asking to push commits
    private func promptClaudeForPush() {
        let pushPrompt = """
        Please push my local commits to the remote. Run `git log --oneline @{upstream}..HEAD` to show what will be pushed, then run `git push` to push the commits.
        """

        // Add user message
        let userMessage = ChatMessage(role: .user, content: pushPrompt, timestamp: Date())
        messages.append(userMessage)

        // Hide banner after adding message to avoid layout shift during scroll
        showGitBanner = false

        // Send to Claude (use stored session ID for resume)
        let sessionToResume = wsManager.sessionId ?? selectedSession?.id
        wsManager.sendMessage(
            pushPrompt,
            projectPath: project.path,
            resumeSessionId: sessionToResume,
            permissionMode: effectivePermissionMode,
            model: effectiveModelId
        )
        processingStartTime = Date()

        // Trigger scroll to bottom after a brief delay to let layout settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            scrollToBottomTrigger = true
        }
    }

    // MARK: - Model Selection

    private func switchToModel(_ model: ClaudeModel, customId: String? = nil) {
        // Just update local state - model is passed with each message
        currentModel = model
        if model == .custom, let customId = customId {
            self.customModelId = customId
            settings.customModelId = customId
        }
    }

    /// Get the model ID to pass in WebSocket messages
    private var effectiveModelId: String? {
        let model = currentModel ?? settings.defaultModel
        if model == .custom {
            return customModelId.isEmpty ? nil : customModelId
        }
        return model.modelId
    }

    /// Whether to skip permissions for this project (considers per-project override)
    private var effectiveSkipPermissions: Bool {
        projectSettingsStore.effectiveSkipPermissions(
            for: project.path,
            globalSetting: settings.skipPermissions
        )
    }

    /// The effective permission mode to send to server for this project
    private var effectivePermissionMode: String? {
        effectiveSkipPermissions ? "bypassPermissions" : settings.claudeMode.serverValue
    }
}

// MARK: - Custom Model Picker Sheet

struct CustomModelPickerSheet: View {
    @Binding var customModelId: String
    let onConfirm: (String) -> Void
    let onCancel: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Enter a custom model ID")
                    .font(CLITheme.monoFont)
                    .foregroundColor(CLITheme.primaryText(for: colorScheme))

                TextField("e.g., claude-opus-4-5-20251101", text: $customModelId)
                    .font(CLITheme.monoFont)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                Text("Examples:\n• claude-opus-4-5-20251101\n• claude-sonnet-4-5-20250929\n• claude-sonnet-4-5-20250929[1m]")
                    .font(CLITheme.monoSmall)
                    .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
            .padding()
            .background(CLITheme.background(for: colorScheme))
            .navigationTitle("Custom Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Switch") { onConfirm(customModelId) }
                        .disabled(customModelId.isEmpty)
                }
            }
        }
    }
}

// MARK: - Git Sync Banner (Compact, Dark Mode Optimized)

struct GitSyncBanner: View {
    let status: GitStatus
    let isAutoPulling: Bool
    let isRefreshing: Bool
    let onDismiss: () -> Void
    let onRefresh: () -> Void
    let onPull: (() -> Void)?
    let onCommit: (() -> Void)?
    let onAskClaude: (() -> Void)?
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            // Status icon (compact)
            if isAutoPulling || isRefreshing {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 14, height: 14)
            } else {
                Image(systemName: status.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            // Status text (single line, compact)
            Text(isRefreshing ? "Checking..." : statusTitle)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(CLITheme.primaryText(for: colorScheme))
                .lineLimit(1)

            Spacer()

            // Action buttons (compact pills)
            if !isAutoPulling && !isRefreshing {
                HStack(spacing: 6) {
                    // Pull button (for behind status)
                    if let onPull = onPull {
                        compactButton(
                            title: "Pull",
                            icon: "arrow.down",
                            color: CLITheme.cyan(for: colorScheme),
                            action: onPull
                        )
                    }

                    // Commit/Push button
                    if let onCommit = onCommit {
                        compactButton(
                            title: commitButtonLabel,
                            icon: commitButtonIcon,
                            color: commitButtonColor,
                            action: onCommit
                        )
                    }

                    // Ask Claude button
                    if let onAskClaude = onAskClaude {
                        compactButton(
                            title: "Ask",
                            icon: "bubble.left",
                            color: CLITheme.purple(for: colorScheme),
                            action: onAskClaude
                        )
                    }

                    // Refresh button (icon only)
                    Button(action: onRefresh) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(CLITheme.mutedText(for: colorScheme))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Dismiss button (compact)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
                    .frame(width: 16, height: 16)
                    .background(
                        Circle()
                            .fill(CLITheme.mutedText(for: colorScheme).opacity(0.15))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(bannerBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(status.accessibilityLabel)
    }

    // MARK: - Compact Button Helper

    @ViewBuilder
    private func compactButton(
        title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                Text(title)
                    .font(.system(size: 10, weight: .bold))
            }
            // Dark mode: white text on colored background for high contrast
            // Light mode: colored text on light colored background
            .foregroundColor(colorScheme == .dark ? .white : color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(colorScheme == .dark ? 0.7 : 0.15))
            )
            .overlay(
                Capsule()
                    .strokeBorder(color.opacity(colorScheme == .dark ? 0.9 : 0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Computed Properties

    private var iconColor: Color {
        switch status.colorName {
        case "green": return CLITheme.green(for: colorScheme)
        case "orange": return CLITheme.yellow(for: colorScheme)
        case "blue": return CLITheme.blue(for: colorScheme)
        case "cyan": return CLITheme.cyan(for: colorScheme)
        case "red": return CLITheme.red(for: colorScheme)
        default: return CLITheme.mutedText(for: colorScheme)
        }
    }

    private var bannerBackground: Color {
        let baseColor: Color = {
            switch status {
            case .dirty, .dirtyAndAhead, .diverged:
                return CLITheme.yellow(for: colorScheme)
            case .behind:
                return CLITheme.cyan(for: colorScheme)
            case .ahead:
                return CLITheme.blue(for: colorScheme)
            case .error:
                return CLITheme.red(for: colorScheme)
            default:
                return CLITheme.mutedText(for: colorScheme)
            }
        }()
        return baseColor.opacity(colorScheme == .dark ? 0.15 : 0.08)
    }

    private var statusTitle: String {
        if isAutoPulling { return "Pulling..." }
        switch status {
        case .dirty: return "Uncommitted changes"
        case .ahead(let count): return "\(count) unpushed"
        case .behind(let count): return "\(count) behind"
        case .dirtyAndAhead: return "Changes + unpushed"
        case .diverged: return "Diverged"
        case .error(let msg): return "Error: \(msg.prefix(20))"
        default: return ""
        }
    }

    private var commitButtonLabel: String {
        switch status {
        case .ahead: return "Push"
        default: return "Commit"
        }
    }

    private var commitButtonIcon: String {
        switch status {
        case .ahead: return "arrow.up"
        default: return "checkmark"
        }
    }

    private var commitButtonColor: Color {
        switch status {
        case .ahead: return CLITheme.blue(for: colorScheme)
        default: return CLITheme.green(for: colorScheme)
        }
    }

    private var commitButtonAccessibilityLabel: String {
        switch status {
        case .dirty, .dirtyAndAhead, .diverged:
            return "Commit changes"
        case .ahead:
            return "Push commits"
        default:
            return "Commit changes"
        }
    }
}

// MARK: - Slash Command Help Sheet

struct SlashCommandHelpSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Keyboard Shortcuts section
                    Text("Keyboard Shortcuts")
                        .font(.headline)
                        .foregroundColor(CLITheme.primaryText(for: colorScheme))

                    VStack(alignment: .leading, spacing: 12) {
                        KeyboardShortcutRow(shortcut: "⌘ Return", description: "Send message")
                        KeyboardShortcutRow(shortcut: "⌘ K", description: "Clear conversation")
                        KeyboardShortcutRow(shortcut: "⌘ N", description: "New session")
                        KeyboardShortcutRow(shortcut: "⌘ .", description: "Abort current request")
                        KeyboardShortcutRow(shortcut: "⌘ /", description: "Show this help")
                        KeyboardShortcutRow(shortcut: "⌘ R", description: "Resume session picker")
                    }

                    Divider()
                        .padding(.vertical, 8)

                    // Slash Commands section
                    Text("Slash Commands")
                        .font(.headline)
                        .foregroundColor(CLITheme.primaryText(for: colorScheme))

                    VStack(alignment: .leading, spacing: 12) {
                        SlashCommandRow(command: "/clear", description: "Clear conversation and start fresh")
                        SlashCommandRow(command: "/new", description: "Start a new session")
                        SlashCommandRow(command: "/init", description: "Create/modify CLAUDE.md (via Claude)")
                        SlashCommandRow(command: "/resume", description: "Resume a previous session")
                        SlashCommandRow(command: "/compact", description: "Compact conversation to save context")
                        SlashCommandRow(command: "/status", description: "Show connection and session info")
                        SlashCommandRow(command: "/exit", description: "Close chat and return to projects")
                        SlashCommandRow(command: "/help", description: "Show this help")
                    }

                    Divider()
                        .padding(.vertical, 8)

                    Text("Claude Commands")
                        .font(.headline)
                        .foregroundColor(CLITheme.primaryText(for: colorScheme))

                    Text("Other slash commands (like /review, /commit) are passed directly to Claude for handling.")
                        .font(.subheadline)
                        .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                }
                .padding()
            }
            .background(CLITheme.background(for: colorScheme))
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .keyboardShortcut(.escape)
                }
            }
        }
    }
}

struct KeyboardShortcutRow: View {
    let shortcut: String
    let description: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(CLITheme.yellow(for: colorScheme))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(CLITheme.secondaryBackground(for: colorScheme))
                .cornerRadius(6)

            Text(description)
                .font(.subheadline)
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

private struct SlashCommandRow: View {
    let command: String
    let description: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(command)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(CLITheme.cyan(for: colorScheme))
                .frame(width: 100, alignment: .leading)

            Text(description)
                .font(.subheadline)
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Placeholder Extension

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// MARK: - Preference Keys

/// Preference key for tracking content size
struct ContentSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

/// Preference key for tracking scroll offset within coordinate space
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    let settings = AppSettings()
    return NavigationStack {
        ChatView(
            project: Project(
                name: "test-project",
                path: "/test/project",
                displayName: "Test Project",
                fullPath: "/test/project",
                sessions: nil
            ),
            apiClient: APIClient(settings: settings)
        )
    }
    .environmentObject(settings)
}
