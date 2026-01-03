import SwiftUI
import UIKit
import PhotosUI

// MARK: - ChatView

struct ChatView: View {
    // MARK: - Properties
    let project: Project
    let initialGitStatus: GitStatus
    var onSessionsChanged: (() -> Void)?

    // MARK: - Environment
    @EnvironmentObject var settings: AppSettings
    // Note: scenePhase removed - reconnection handled by CLIBridgeManager lifecycle observers
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - ViewModel
    @StateObject private var viewModel: ChatViewModel

    // MARK: - Focus State (must stay in View for @FocusState)
    @FocusState private var isInputFocused: Bool
    @State private var autoScrollWorkItem: DispatchWorkItem?
    @State private var lastStreamingAutoScrollTime: Date = .distantPast

    private let streamingAutoScrollThrottle: TimeInterval = 0.12

    // MARK: - Computed Properties

    /// Display name for project - uses custom name from ProjectNamesStore if set, otherwise server title
    private var displayName: String {
        if let customName = ProjectNamesStore.shared.getName(for: project.path) {
            return customName
        }
        return project.title
    }

    /// Stable bottom padding to avoid list jumps when agent state changes.
    private let bottomSpacerHeight: CGFloat = 65

    /// Binding for ExitPlanMode approval sheet - extracted to avoid type-checking complexity
    private var exitPlanModeBinding: Binding<ApprovalRequest?> {
        Binding<ApprovalRequest?>(
            get: {
                guard let approval = viewModel.pendingApproval, approval.isExitPlanMode else {
                    return nil
                }
                return approval
            },
            set: { _ in }  // Handled by approve/deny actions
        )
    }

    /// Sheet view for ExitPlanMode approval - extracted to avoid type-checking complexity
    @ViewBuilder
    private func exitPlanModeSheet(for approval: ApprovalRequest) -> some View {
        ExitPlanModeApprovalView(
            request: approval,
            onApprove: {
                viewModel.approvePendingRequest(alwaysAllow: false)
            },
            onDeny: {
                viewModel.denyPendingRequest()
            }
        )
    }

    init(project: Project, initialGitStatus: GitStatus = .unknown, onSessionsChanged: (() -> Void)? = nil) {
        self.project = project
        self.initialGitStatus = initialGitStatus
        self.onSessionsChanged = onSessionsChanged
        // Initialize ViewModel with placeholder settings - will be updated in onAppear
        _viewModel = StateObject(wrappedValue: ChatViewModel(
            project: project,
            initialGitStatus: initialGitStatus,
            settings: AppSettings(),
            onSessionsChanged: onSessionsChanged
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar (when searching)
            if viewModel.isSearching {
                ChatSearchBar(
                    searchText: $viewModel.searchText,
                    isSearching: $viewModel.isSearching,
                    selectedFilter: $viewModel.messageFilter
                )

                // Result count
                SearchResultCount(count: viewModel.displayMessages.count, searchText: viewModel.searchText)
            }

            // Git status banner (when there are local changes)
            gitStatusBannerView

            sessionPickerView
            messagesScrollView
            statusAndInputView
        }
        .background(CLITheme.background(for: colorScheme))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                ChatTitleView(displayName: displayName)
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                ChatToolbarActions(
                    gitStatus: viewModel.gitStatus,
                    isSearching: viewModel.isSearching,
                    ideasCount: viewModel.ideasStore.ideas.count,
                    isProcessing: viewModel.isProcessing,
                    onGitStatusTap: viewModel.showGitBannerAndRefresh,
                    onToggleSearch: {
                        withAnimation {
                            viewModel.isSearching.toggle()
                            if !viewModel.isSearching {
                                viewModel.searchText = ""
                                viewModel.messageFilter = .all
                            }
                        }
                    },
                    onShowIdeas: { viewModel.showIdeasDrawer = true },
                    onQuickCapture: { viewModel.showQuickCapture = true },
                    onNewChat: viewModel.startNewSession,
                    onShowBookmarks: { viewModel.showingBookmarks = true },
                    onAbort: viewModel.abortSession
                )
            }
        }
        .onAppear {
            // Update ViewModel with actual settings from environment
            viewModel.settings = settings
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
            autoScrollWorkItem?.cancel()
            autoScrollWorkItem = nil
        }
        .onChange(of: viewModel.messages.count) { _, _ in
            // Only trigger on count changes (not content changes during streaming)
            // This reduces onChange overhead from O(n) array comparison to O(1) int comparison
            viewModel.handleMessagesChange()
        }
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.refreshDisplayMessagesCache()
        }
        .onChange(of: viewModel.messageFilter) { _, _ in
            viewModel.refreshDisplayMessagesCache()
        }
        .onChange(of: settings.defaultModel) { oldModel, newModel in
            viewModel.handleModelChange(oldModel: oldModel, newModel: newModel)
        }
        .onChange(of: viewModel.inputText) { _, newText in
            viewModel.handleInputTextChange(newText)
        }
        .onChange(of: viewModel.isProcessing) { oldValue, isProcessing in
            viewModel.handleProcessingChange(oldValue: oldValue, isProcessing: isProcessing)

            // Refocus input when processing completes
            if oldValue && !isProcessing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isInputFocused = true
                }
            }
        }
        // Note: Reconnection on app foreground is handled centrally by CLIBridgeManager's
        // lifecycle observers (didBecomeActiveNotification). No scenePhase handler needed.
        .sheet(item: Binding(
            get: { viewModel.pendingQuestion },
            set: { _ in }  // Handled by viewModel
        )) { questionData in
            userQuestionsSheet(questionData)
        }
        .sheet(item: $viewModel.activeSheet) { sheet in
            sheetContent(for: sheet)
        }
        // ExitPlanMode approval sheet (shown when pending approval is ExitPlanMode)
        .sheet(item: exitPlanModeBinding) { approval in
            exitPlanModeSheet(for: approval)
        }
        // MARK: - Keyboard Shortcuts (iPad)
        .background {
            keyboardShortcutButtons
        }
    }

    // MARK: - Keyboard Shortcut Buttons

    @ViewBuilder
    private var keyboardShortcutButtons: some View {
        // Cmd+Return: Send message
        Button("") {
            viewModel.sendMessage()
        }
        .keyboardShortcut(.return, modifiers: .command)
        .hidden()

        // Cmd+K: Clear conversation
        Button("") {
            viewModel.handleClearCommand()
        }
        .keyboardShortcut("k", modifiers: .command)
        .hidden()

        // Cmd+N: New session
        Button("") {
            viewModel.handleNewSessionCommand()
        }
        .keyboardShortcut("n", modifiers: .command)
        .hidden()

        // Cmd+.: Abort current request
        Button("") {
            if viewModel.isProcessing {
                HapticManager.rigid()
                viewModel.abortSession()
            }
        }
        .keyboardShortcut(".", modifiers: .command)
        .hidden()

        // Cmd+/: Show help
        Button("") {
            viewModel.showingHelpSheet = true
        }
        .keyboardShortcut("/", modifiers: .command)
        .hidden()

        // Cmd+R: Resume session picker
        Button("") {
            viewModel.showingSessionPicker = true
        }
        .keyboardShortcut("r", modifiers: .command)
        .hidden()
    }

    /// Sheet view for AskUserQuestion
    @ViewBuilder
    private func userQuestionsSheet(_ questionData: AskUserQuestionData) -> some View {
        UserQuestionsSheetWrapper(
            initialData: questionData,
            onSubmit: { answeredData in
                viewModel.handleQuestionAnswer(answeredData)
            },
            onCancel: {
                viewModel.handleQuestionCancel()
            }
        )
    }

    // MARK: - View Components

    @ViewBuilder
    private var sessionPickerView: some View {
        SessionBar(
            project: project,
            sessions: viewModel.localSessionsBinding,
            selected: $viewModel.selectedSession,
            isLoading: viewModel.isLoadingHistory,
            isProcessing: viewModel.isProcessing,
            activeSessionId: viewModel.activeSessionId,
            onSelect: { session in
                viewModel.selectSession(session)
            },
            onNew: {
                viewModel.startNewSession()
            },
            onDelete: { session in
                Task {
                    await viewModel.deleteSession(session)
                }
            }
        )
    }

    @ViewBuilder
    private var gitStatusBannerView: some View {
        if viewModel.showGitBanner {
            switch viewModel.gitStatus {
            case .dirty, .dirtyAndAhead, .diverged:
                GitSyncBanner(
                    status: viewModel.gitStatus,
                    isAutoPulling: false,
                    isRefreshing: viewModel.gitStatus == .checking,
                    onDismiss: { viewModel.showGitBanner = false },
                    onRefresh: { viewModel.refreshGitStatus() },
                    onPull: nil,
                    onCommit: { viewModel.promptClaudeForCommit() },
                    onAskClaude: { viewModel.promptClaudeForCleanup() }
                )

            case .behind:
                GitSyncBanner(
                    status: viewModel.gitStatus,
                    isAutoPulling: viewModel.isAutoPulling,
                    isRefreshing: viewModel.gitStatus == .checking,
                    onDismiss: { viewModel.showGitBanner = false },
                    onRefresh: { viewModel.refreshGitStatus() },
                    onPull: { Task { await viewModel.performAutoPull() } },
                    onCommit: nil,
                    onAskClaude: nil
                )

            case .ahead:
                GitSyncBanner(
                    status: viewModel.gitStatus,
                    isAutoPulling: false,
                    isRefreshing: viewModel.gitStatus == .checking,
                    onDismiss: { viewModel.showGitBanner = false },
                    onRefresh: { viewModel.refreshGitStatus() },
                    onPull: nil,
                    onCommit: { viewModel.promptClaudeForPush() },
                    onAskClaude: { viewModel.promptClaudeForCleanup() }
                )

            default:
                EmptyView()
            }
        }
    }

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottom) {
                // PERF: Using List instead of ScrollView+VStack for cell recycling
                // List reuses cells like UITableView, critical for 200+ messages
                List {
                    // Loading indicator
                    if viewModel.isLoadingHistory && viewModel.messages.isEmpty {
                        loadingHistoryView
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }

                    ForEach(viewModel.groupedDisplayItems) { item in
                        DisplayItemView(
                            item: item,
                            projectPath: project.path,
                            projectTitle: project.title,
                            hideTodoInline: viewModel.showTodoDrawer
                        )
                        .id(item.id)
                        .environment(\.retryAction, viewModel.retryMessage)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
                        .listRowBackground(Color.clear)
                    }

                    if viewModel.isProcessing {
                        streamingIndicatorView
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
                            .listRowBackground(Color.clear)
                    }

                    // Bottom anchor for scrollTo target
                    // Extra space ensures last message appears above status bar
                    Spacer()
                        .frame(height: bottomSpacerHeight)
                        .id("bottomAnchor")
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .transaction { transaction in
                    if viewModel.showScrollToBottom {
                        transaction.disablesAnimations = true
                    }
                }
                .scrollContentBackground(.hidden)
                .background(CLITheme.background(for: colorScheme))
                .scrollDismissesKeyboard(.interactively)
                .refreshable {
                    await viewModel.refreshChatContent()
                }
                // PERF: Simplified scroll detection - only track when user manually scrolls
                .onScrollPhaseChange { oldPhase, newPhase in
                    // Show scroll button when user starts interacting
                    if newPhase == .interacting {
                        isInputFocused = false
                        viewModel.showScrollToBottom = true
                    }
                    // Hide when scroll ends and we're likely at bottom
                    if oldPhase == .decelerating && newPhase == .idle {
                        // Give a moment for scroll to settle
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            // Will be hidden by auto-scroll if at bottom
                        }
                    }
                }

                // Manual scroll to bottom button
                if viewModel.showScrollToBottom {
                    Button {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo("bottomAnchor")
                            }
                        }
                        viewModel.showScrollToBottom = false
                    } label: {
                        Image(systemName: "chevron.compact.down")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(CLITheme.primaryText(for: colorScheme).opacity(0.6))
                            .frame(width: 60, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 16)
                    .transition(.opacity)
                }
            }
            // Auto-scroll when new messages arrive (if enabled)
            // PERF: Delay scroll to let List's UICollectionView finish updating
            .onChange(of: viewModel.messages.count) { oldCount, newCount in
                if settings.autoScrollEnabled && !viewModel.showScrollToBottom {
                    // Longer delay when loading many messages (history load)
                    let delay = (newCount - oldCount) > 5 ? 0.3 : 0.1
                    scheduleScrollToBottom(
                        proxy,
                        delay: delay,
                        animated: !viewModel.isProcessing
                    )
                }
            }
            .onChange(of: viewModel.currentStreamingText) { _, newText in
                guard settings.autoScrollEnabled,
                      !viewModel.showScrollToBottom,
                      !newText.isEmpty else { return }
                let now = Date()
                if now.timeIntervalSince(lastStreamingAutoScrollTime) >= streamingAutoScrollThrottle {
                    lastStreamingAutoScrollTime = now
                    scheduleScrollToBottom(proxy, delay: 0.05, animated: false)
                }
            }
            // Explicit scroll trigger (used when sending messages - always scrolls)
            .onChange(of: viewModel.scrollToBottomTrigger) { _, shouldScroll in
                if shouldScroll {
                    scheduleScrollToBottom(proxy, delay: 0.15, animated: true)
                    viewModel.scrollToBottomTrigger = false
                    viewModel.showScrollToBottom = false
                }
            }
            .onAppear {
                guard !viewModel.isLoadingHistory else { return }
                scheduleScrollToBottom(proxy, delay: 0.5, animated: false)
            }
            .onReceive(NotificationCenter.default.publisher(for: .backgroundRecoveryNeeded)) { notification in
                guard let userInfo = notification.userInfo,
                      let sessionId = userInfo["sessionId"] as? String,
                      let projectPath = userInfo["projectPath"] as? String,
                      projectPath == project.path else {
                    return
                }
                log.info("Background recovery requested for session: \(sessionId.prefix(8))...")
                // Reconnect to the session after background recovery
                Task {
                    await viewModel.manager.connect(projectPath: projectPath, sessionId: sessionId)
                }
            }
        }
    }

    @ViewBuilder
    private var loadingHistoryView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
                .tint(CLITheme.cyan(for: colorScheme))
            Text("Loading session history...")
                .font(CLITheme.monoSmall)
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 100)
    }

    @ViewBuilder
    private var streamingIndicatorView: some View {
        if viewModel.isReattaching {
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
        } else if viewModel.currentStreamingText.isEmpty {
            // StatusBubbleView now rendered in statusAndInputView (fixed position)
            EmptyView()
                .id("statusBubble")
        } else {
            CLIMessageView(
                message: ChatMessage(
                    id: viewModel.streamingMessageId,
                    role: .assistant,
                    content: viewModel.currentStreamingText,
                    timestamp: viewModel.streamingMessageTimestamp,
                    isStreaming: true
                ),
                projectPath: project.path,
                projectTitle: project.title
            )
            .id(viewModel.streamingMessageId)
        }
    }

    private var statusAndInputView: some View {
        VStack(spacing: 0) {
            // Todo progress drawer
            if viewModel.showTodoDrawer && !viewModel.currentTodos.isEmpty {
                TodoProgressDrawer(
                    todos: viewModel.currentTodos,
                    isExpanded: $viewModel.isTodoDrawerExpanded
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
            }

            // Permission approval banner (regular tools only - ExitPlanMode uses sheet)
            if let approval = viewModel.pendingApproval, !approval.isExitPlanMode {
                ApprovalBannerView(
                    request: approval,
                    onApprove: {
                        viewModel.approvePendingRequest(alwaysAllow: false)
                    },
                    onAlwaysAllow: {
                        viewModel.approvePendingRequest(alwaysAllow: true)
                    },
                    onDeny: {
                        viewModel.denyPendingRequest()
                    }
                )
            }

            // Input queued banner
            if viewModel.isInputQueued {
                InputQueuedBanner(
                    position: viewModel.queuePosition,
                    onCancel: {
                        viewModel.cancelQueuedInput()
                    }
                )
            }

            // Subagent banner
            if let subagent = viewModel.activeSubagent {
                SubagentBanner(subagent: subagent) {
                    viewModel.clearActiveSubagent()
                }
            }

            // Tool progress banner
            if let progress = viewModel.toolProgress, viewModel.pendingApproval == nil, viewModel.pendingQuestion == nil {
                ToolProgressBanner(progress: progress) {
                    viewModel.clearToolProgress()
                }
            }

            // Status bubble (fixed position, shows when agent is working)
            if viewModel.manager.agentState.isWorking {
                StatusBubbleView(
                    state: viewModel.manager.agentState,
                    tool: viewModel.manager.currentTool
                )
            }

            // Unified status bar
            UnifiedStatusBar(
                isProcessing: viewModel.isProcessing,
                tokenUsage: viewModel.tokenUsage,
                effectivePermissionMode: viewModel.effectivePermissionModeValue,
                projectPath: project.path,
                gitStatus: viewModel.gitStatus,
                onGitStatusTap: viewModel.showGitBannerAndRefresh,
                showQuickSettings: $viewModel.showQuickSettings
            )

            CLIInputView(
                text: $viewModel.inputText,
                selectedImages: $viewModel.selectedImages,
                isProcessing: viewModel.isProcessing,
                isAborting: viewModel.isAborting,
                projectPath: project.path,
                isFocused: _isInputFocused,
                onSend: viewModel.sendMessage,
                onAbort: { viewModel.abortSession() },
                recentMessages: viewModel.messages
            )
            .id("input-view")
        }
    }

    private func scheduleScrollToBottom(
        _ proxy: ScrollViewProxy,
        delay: TimeInterval,
        animated: Bool
    ) {
        autoScrollWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            if animated {
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("bottomAnchor")
                }
            } else {
                proxy.scrollTo("bottomAnchor")
            }
        }
        autoScrollWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    // MARK: - Sheet Content

    @ViewBuilder
    private func sheetContent(for sheet: ChatViewModel.ActiveSheet) -> some View {
        switch sheet {
        case .help:
            SlashCommandHelpSheet()

        case .sessionPicker:
            SessionPickerSheet(
                project: project,
                sessions: viewModel.localSessionsBinding,
                onSelect: { session in
                    viewModel.activeSheet = nil
                    viewModel.selectSession(session)
                },
                onCancel: {
                    viewModel.activeSheet = nil
                },
                onDelete: { session in
                    Task { await viewModel.deleteSession(session) }
                }
            )

        case .modelPicker:
            CustomModelPickerSheet(
                customModelId: $viewModel.customModelId,
                onConfirm: { modelId in
                    viewModel.activeSheet = nil
                    viewModel.switchToModel(.custom, customId: modelId)
                    settings.customModelId = modelId
                },
                onCancel: {
                    viewModel.activeSheet = nil
                }
            )

        case .bookmarks:
            BookmarksView()
                .environmentObject(settings)

        case .ideasDrawer:
            IdeasDrawerSheet(
                isPresented: Binding(
                    get: { viewModel.activeSheet == .ideasDrawer },
                    set: { if !$0 { viewModel.activeSheet = nil } }
                ),
                ideasStore: viewModel.ideasStore,
                projectPath: project.path,
                onSendIdea: { idea in
                    viewModel.appendToInput(idea.formattedPrompt)
                }
            )

        case .quickCapture:
            QuickCaptureSheet(
                isPresented: Binding(
                    get: { viewModel.activeSheet == .quickCapture },
                    set: { if !$0 { viewModel.activeSheet = nil } }
                )
            ) { text in
                viewModel.ideasStore.quickAdd(text)
            }

        case .quickSettings:
            QuickSettingsSheet(
                tokenUsage: viewModel.tokenUsage.map { (current: $0.used, max: $0.total) }
            )
        }
    }
}

#Preview {
    @Previewable @State var settings = AppSettings()
    NavigationStack {
        ChatView(
            project: Project(
                name: "test-project",
                path: "/test/project",
                displayName: "Test Project",
                fullPath: "/test/project",
                sessions: nil,
                sessionMeta: nil
            )
        )
    }
    .environmentObject(settings)
}
