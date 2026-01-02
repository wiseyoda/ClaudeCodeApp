import XCTest
@testable import CodingBridge

@MainActor
final class ChatViewModelTests: XCTestCase {
    private var settingsSnapshot: [String: Any?] = [:]

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults.standard
        settingsSnapshot = [
            "showThinkingBlocks": defaults.object(forKey: "showThinkingBlocks"),
            "historyLimit": defaults.object(forKey: "historyLimit"),
            "defaultModel": defaults.object(forKey: "defaultModel"),
            "customModelId": defaults.object(forKey: "customModelId")
        ]
    }

    override func tearDown() {
        let defaults = UserDefaults.standard
        for (key, value) in settingsSnapshot {
            if let value {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        settingsSnapshot = [:]
        super.tearDown()
    }

    // MARK: - Initialization

    func test_initialState_defaults() {
        let (viewModel, _, _, _) = makeFixture()

        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertEqual(viewModel.inputText, "")
        XCTAssertTrue(viewModel.selectedImages.isEmpty)
        XCTAssertNil(viewModel.processingStartTime)
        XCTAssertNil(viewModel.selectedSession)
        XCTAssertFalse(viewModel.isUploadingImage)
        XCTAssertFalse(viewModel.isLoadingHistory)
        XCTAssertFalse(viewModel.scrollToBottomTrigger)
        XCTAssertEqual(viewModel.messageFilter, .all)
        XCTAssertEqual(viewModel.searchText, "")
    }

    func test_initialState_setsProjectAndSettings() {
        let settings = makeSettings()
        let project = makeProject(path: "/tmp/project-init")
        let manager = TestCLIBridgeManager()
        let viewModel = ChatViewModel(project: project, settings: settings, manager: manager)

        XCTAssertEqual(viewModel.project.path, project.path)
        XCTAssertTrue(viewModel.settings === settings)
        XCTAssertEqual(viewModel.initialGitStatus, .unknown)
    }

    // MARK: - Session Management

    func test_effectiveSessionToResume_prefersWsManagerSessionId() {
        let (viewModel, manager, _, _) = makeFixture()
        manager.sessionId = "session-ws"
        viewModel.selectedSession = makeSession(id: "session-selected")

        XCTAssertEqual(viewModel.effectiveSessionToResume, "session-ws")
    }

    func test_effectiveSessionToResume_nilForEphemeralSelectedSession() {
        let (viewModel, _, _, _) = makeFixture()
        viewModel.selectedSession = makeSession(id: "new-session-123")

        XCTAssertNil(viewModel.effectiveSessionToResume)
    }

    func test_effectiveSessionToResume_returnsSelectedSessionId() {
        let (viewModel, _, _, _) = makeFixture()
        viewModel.selectedSession = makeSession(id: "session-123")

        XCTAssertEqual(viewModel.effectiveSessionToResume, "session-123")
    }

    func test_effectiveSessionToResume_nilWhenNoSession() {
        let (viewModel, _, _, _) = makeFixture()

        XCTAssertNil(viewModel.effectiveSessionToResume)
    }

    func test_startNewSession_resetsStateAndAddsWelcome() {
        let (viewModel, manager, _, _) = makeFixture()
        viewModel.messages = [ChatMessage(role: .user, content: "Hello")]
        viewModel.selectedSession = makeSession(id: "session-old")
        manager.sessionId = "session-old"
        viewModel.scrollManager.userDidScrollUp()

        viewModel.startNewSession()

        XCTAssertNil(manager.sessionId)
        XCTAssertTrue(viewModel.messages.count == 1)
        XCTAssertEqual(viewModel.messages.first?.role, .system)
        XCTAssertTrue(viewModel.messages.first?.content.contains("New session started") == true)
        XCTAssertTrue(viewModel.selectedSession?.id.hasPrefix("new-session-") == true)
        XCTAssertTrue(viewModel.scrollManager.isAutoScrollEnabled)
    }

    func test_selectInitialSession_usesStoredSession() {
        let project = makeProject(path: "/tmp/project-select-initial")
        let (viewModel, _, _, _) = makeFixture(project: project)
        let session = makeSession(id: "session-1")
        viewModel.sessionStore.addSession(session, for: project.path)
        MessageStore.saveSessionId(session.id, for: project.path)

        viewModel.selectInitialSession()

        XCTAssertEqual(viewModel.selectedSession?.id, session.id)
        XCTAssertNil(viewModel.sessionStore.activeSessionId(for: project.path))
    }

    func test_selectInitialSession_createsEphemeralSession() {
        let project = makeProject(path: "/tmp/project-ephemeral")
        let (viewModel, _, _, _) = makeFixture(project: project)
        MessageStore.saveSessionId("session-missing", for: project.path)

        viewModel.selectInitialSession()

        XCTAssertEqual(viewModel.selectedSession?.id, "session-missing")
        XCTAssertNil(viewModel.selectedSession?.summary)
    }

    func test_autoSelectMostRecentSession_usesStoreSessions() {
        let project = makeProject(path: "/tmp/project-store-sessions")
        let (viewModel, _, _, _) = makeFixture(project: project)
        let older = makeSession(id: "older", lastActivity: "2024-01-01T00:00:00Z")
        let newer = makeSession(id: "newer", lastActivity: "2024-02-01T00:00:00Z")
        viewModel.sessionStore.addSession(older, for: project.path)
        viewModel.sessionStore.addSession(newer, for: project.path)

        viewModel.autoSelectMostRecentSession()

        XCTAssertEqual(viewModel.selectedSession?.id, "newer")
    }

    func test_autoSelectMostRecentSession_fallsBackToProjectSessions() {
        let older = makeSession(id: "older", lastActivity: "2024-01-01T00:00:00Z")
        let newer = makeSession(id: "newer", lastActivity: "2024-02-01T00:00:00Z")
        let project = makeProject(path: "/tmp/project-embedded", sessions: [older, newer])
        let (viewModel, _, _, _) = makeFixture(project: project)

        viewModel.autoSelectMostRecentSession()

        XCTAssertEqual(viewModel.selectedSession?.id, "newer")
    }

    func test_selectMostRecentSession_setsSessionAndLoadsHistory() {
        let project = makeProject(path: "/tmp/project-select-most-recent")
        let settings = makeSettings()
        let manager = TestCLIBridgeManager()
        let viewModel = TestChatViewModel(project: project, settings: settings, manager: manager)
        let session = makeSession(id: "session-1")

        viewModel.selectMostRecentSession(from: [session])

        XCTAssertEqual(viewModel.selectedSession?.id, "session-1")
        XCTAssertEqual(manager.sessionId, "session-1")
        XCTAssertTrue(viewModel.didLoadSessionHistory)
        XCTAssertEqual(MessageStore.loadSessionId(for: project.path), "session-1")
    }

    func test_selectSession_setsSessionAndLoadsHistory() {
        let project = makeProject(path: "/tmp/project-select-session")
        let settings = makeSettings()
        let manager = TestCLIBridgeManager()
        let viewModel = TestChatViewModel(project: project, settings: settings, manager: manager)
        let session = makeSession(id: "session-2")

        viewModel.selectSession(session)

        XCTAssertEqual(viewModel.selectedSession?.id, "session-2")
        XCTAssertEqual(manager.sessionId, "session-2")
        XCTAssertTrue(viewModel.didLoadSessionHistory)
    }

    // MARK: - Input Handling

    func test_appendToInput_whenEmpty_appendsWithSpace() {
        let (viewModel, _, _, _) = makeFixture()

        viewModel.appendToInput("Hello")

        XCTAssertEqual(viewModel.inputText, "Hello ")
    }

    func test_appendToInput_whenEndsWithSpace_appendsWithSpace() {
        let (viewModel, _, _, _) = makeFixture()
        viewModel.inputText = "Hello "

        viewModel.appendToInput("World")

        XCTAssertEqual(viewModel.inputText, "Hello World ")
    }

    func test_appendToInput_whenNoTrailingSpace_insertsSpace() {
        let (viewModel, _, _, _) = makeFixture()
        viewModel.inputText = "Hello"

        viewModel.appendToInput("World")

        XCTAssertEqual(viewModel.inputText, "Hello World ")
    }

    func test_sendMessage_addsUserMessageAndClearsInput() async {
        let (viewModel, manager, _, _) = makeFixture()
        viewModel.inputText = "Hello"

        viewModel.sendMessage()

        // Wait for async Task to complete
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.role, .user)
        XCTAssertEqual(viewModel.messages.first?.content, "Hello")
        XCTAssertEqual(viewModel.inputText, "")
        XCTAssertTrue(viewModel.selectedImages.isEmpty)
        XCTAssertNotNil(viewModel.processingStartTime)
        XCTAssertEqual(manager.sentInputs.count, 1)
        XCTAssertEqual(manager.sentInputs.first?.text, "Hello")
    }

    func test_sendMessage_ignoresEmptyMessage() {
        let (viewModel, manager, _, _) = makeFixture()
        viewModel.inputText = "   "

        viewModel.sendMessage()

        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertTrue(manager.sentInputs.isEmpty)
    }

    func test_sendMessage_withImagesUsesDefaultPrompt() async {
        let (viewModel, manager, _, _) = makeFixture()
        let imageData = Data(repeating: 0x1, count: 10)
        viewModel.selectedImages = [ImageAttachment(data: imageData)]

        viewModel.sendMessage()

        // Wait for async Task to complete
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.messages.first?.content, "[Image attached]")
        XCTAssertEqual(manager.sentInputs.first?.text, "What is this image?")
    }

    // MARK: - Slash Commands

    func test_handleSlashCommand_helpShowsSheet() {
        let (viewModel, _, _, _) = makeFixture()

        let handled = viewModel.handleSlashCommand("/help")

        XCTAssertTrue(handled)
        XCTAssertTrue(viewModel.showingHelpSheet)
    }

    func test_handleSlashCommand_exitDisconnects() {
        let (viewModel, manager, _, _) = makeFixture()

        let handled = viewModel.handleSlashCommand("/exit")

        XCTAssertTrue(handled)
        XCTAssertTrue(manager.disconnectCalled)
    }

    func test_handleSlashCommand_statusAddsSystemMessage() {
        let (viewModel, manager, _, _) = makeFixture()
        manager.connectionState = .connected(agentId: "agent-123")
        manager.sessionId = "session-123"
        manager.tokenUsage = UsageStreamMessage(
            type: .usage,
            inputTokens: 5,
            outputTokens: 0,
            contextUsed: 5,
            contextLimit: 10
        )

        let handled = viewModel.handleSlashCommand("/status")

        XCTAssertTrue(handled)
        XCTAssertEqual(viewModel.messages.last?.role, .system)
        XCTAssertTrue(viewModel.messages.last?.content.contains("Connection: Connected") == true)
        XCTAssertTrue(viewModel.messages.last?.content.contains("Tokens: 5/10") == true)
    }

    func test_handleClearCommand_clearsMessagesAndCreatesEphemeralSession() {
        let (viewModel, manager, _, _) = makeFixture()
        viewModel.messages = [ChatMessage(role: .user, content: "Hello")]
        viewModel.selectedSession = makeSession(id: "session-1")
        manager.sessionId = "session-1"

        viewModel.handleClearCommand()

        // Should create ephemeral session (not nil) to prevent invalid state
        XCTAssertNotNil(viewModel.selectedSession)
        XCTAssertTrue(viewModel.selectedSession?.id.hasPrefix("new-session-") ?? false)
        XCTAssertNil(manager.sessionId)
        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.role, .system)
    }

    // MARK: - Stream Event Handler

    func test_streamEvent_textFinal_capturesCommittedText() {
        let (viewModel, manager, _, _) = makeFixture()
        viewModel.setupStreamEventHandler()

        manager.simulateEvent(.text("Hello", isFinal: true))
        manager.simulateEvent(.stopped(reason: "complete"))

        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.role, .assistant)
        XCTAssertEqual(viewModel.messages.first?.content, "Hello")
    }

    func test_streamEvent_toolStart_addsToolUseMessage() {
        let (viewModel, manager, _, _) = makeFixture()
        viewModel.setupStreamEventHandler()

        manager.simulateEvent(.toolStart(id: "tool-1", name: "Shell", input: ["command": "ls"]))

        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.role, .toolUse)
        XCTAssertTrue(viewModel.messages.first?.content.contains("Shell(") == true)
    }

    func test_streamEvent_toolStart_tracksSubagentTool() {
        let (viewModel, manager, _, _) = makeFixture()
        viewModel.setupStreamEventHandler()
        manager.activeSubagent = CLISubagentStartContent(id: "subagent-1", description: "Task")

        manager.simulateEvent(.toolStart(id: "tool-2", name: "Shell", input: ["command": "ls"]))

        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertTrue(viewModel.subagentToolIds.contains("tool-2"))
    }

    func test_streamEvent_toolResult_filtersSubagentResult() {
        let (viewModel, manager, _, _) = makeFixture()
        viewModel.setupStreamEventHandler()
        manager.activeSubagent = CLISubagentStartContent(id: "subagent-2", description: "Task")

        manager.simulateEvent(.toolStart(id: "tool-3", name: "Shell", input: ["command": "ls"]))
        manager.simulateEvent(.toolResult(id: "tool-3", name: "Shell", output: "done", isError: false))

        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertFalse(viewModel.subagentToolIds.contains("tool-3"))
    }

    func test_streamEvent_toolResult_filtersTaskTool() {
        let (viewModel, manager, _, _) = makeFixture()
        viewModel.setupStreamEventHandler()

        manager.simulateEvent(.toolResult(id: "tool-4", name: "Task", output: "done", isError: false))

        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    func test_streamEvent_toolResult_addsToolResultMessage() {
        let (viewModel, manager, _, _) = makeFixture()
        viewModel.setupStreamEventHandler()

        manager.simulateEvent(.toolResult(id: "tool-5", name: "Shell", output: "done", isError: false))

        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.role, .toolResult)
        XCTAssertEqual(viewModel.messages.first?.content, "done")
    }

    func test_streamEvent_thinking_appendsThinkingMessage() {
        let (viewModel, manager, _, _) = makeFixture()
        viewModel.setupStreamEventHandler()

        manager.simulateEvent(.thinking("thinking"))

        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.role, .thinking)
        XCTAssertEqual(viewModel.messages.first?.content, "thinking")
    }

    func test_streamEvent_error_appendsErrorMessageAndClearsProcessingTime() {
        let (viewModel, manager, _, _) = makeFixture()
        viewModel.setupStreamEventHandler()
        viewModel.processingStartTime = Date()

        let payload = WsErrorMessage(code: "agent_error", message: "failure", recoverable: false, retryable: false)
        manager.simulateEvent(.error(payload))

        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.role, .error)
        XCTAssertTrue(viewModel.messages.first?.content.contains("failure") == true)
        XCTAssertNil(viewModel.processingStartTime)
    }

    func test_streamEvent_connectionError_clearsSessionOnExpired() {
        let (viewModel, manager, _, project) = makeFixture()
        viewModel.setupStreamEventHandler()
        manager.sessionId = "session-9"
        MessageStore.saveSessionId("session-9", for: project.path)

        manager.simulateEvent(.connectionError(.sessionExpired))

        XCTAssertEqual(viewModel.messages.last?.role, .system)
        XCTAssertNil(MessageStore.loadSessionId(for: project.path))
    }

    func test_streamEvent_reconnectComplete_appendsSystemMessage() {
        let (viewModel, manager, _, _) = makeFixture()
        viewModel.setupStreamEventHandler()

        let payload = ReconnectCompleteMessage(type: .reconnectComplete, missedCount: 0, fromMessageId: "msg-1")
        manager.simulateEvent(.reconnectComplete(payload))

        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.role, .system)
        XCTAssertTrue(viewModel.messages.first?.content.contains("Reconnected") == true)
    }

    func test_streamEvent_history_insertsMessagesAtStart() {
        let (viewModel, manager, _, _) = makeFixture()
        viewModel.setupStreamEventHandler()
        viewModel.messages = [ChatMessage(role: .user, content: "Existing")]
        // Use StreamMessage format for history (HistoryMessage takes [StreamMessage])
        let historyMessage = StreamMessage.typeAssistantStreamMessage(
            AssistantStreamMessage(type: .assistant, content: "History", delta: nil)
        )
        let payload = CLIHistoryPayload(type: .history, messages: [historyMessage], hasMore: false, cursor: nil)

        manager.simulateEvent(.history(payload))

        XCTAssertEqual(viewModel.messages.first?.content, "History")
        XCTAssertEqual(viewModel.messages.last?.content, "Existing")
    }

    // MARK: - Display Messages

    func test_refreshDisplayMessagesCache_hidesThinkingBlocksWhenDisabled() {
        let settings = makeSettings()
        settings.showThinkingBlocks = false
        let (viewModel, _, _, _) = makeFixture(settings: settings)
        viewModel.messages = [
            ChatMessage(role: .thinking, content: "thinking"),
            ChatMessage(role: .assistant, content: "answer")
        ]

        viewModel.refreshDisplayMessagesCache()

        XCTAssertEqual(viewModel.displayMessages.count, 1)
        XCTAssertEqual(viewModel.displayMessages.first?.role, .assistant)
    }

    func test_refreshDisplayMessagesCache_filtersByMessageFilter() {
        let (viewModel, _, _, _) = makeFixture()
        viewModel.messages = [
            ChatMessage(role: .user, content: "User"),
            ChatMessage(role: .assistant, content: "Assistant")
        ]
        viewModel.messageFilter = .assistant

        viewModel.refreshDisplayMessagesCache()

        XCTAssertEqual(viewModel.displayMessages.count, 1)
        XCTAssertEqual(viewModel.displayMessages.first?.role, .assistant)
    }

    func test_refreshDisplayMessagesCache_filtersBySearchText() {
        let (viewModel, _, _, _) = makeFixture()
        viewModel.messages = [
            ChatMessage(role: .assistant, content: "match this"),
            ChatMessage(role: .assistant, content: "ignore this")
        ]
        viewModel.searchText = "match"

        viewModel.refreshDisplayMessagesCache()

        XCTAssertEqual(viewModel.displayMessages.count, 1)
        XCTAssertEqual(viewModel.displayMessages.first?.content, "match this")
    }

    func test_refreshDisplayMessagesCache_appliesHistoryLimit() {
        let settings = makeSettings()
        settings.historyLimit = .small
        let (viewModel, _, _, _) = makeFixture(settings: settings)
        viewModel.messages = (0..<30).map { index in
            ChatMessage(role: .assistant, content: "message-\(index)")
        }

        viewModel.refreshDisplayMessagesCache()

        XCTAssertEqual(viewModel.displayMessages.count, 25)
        XCTAssertEqual(viewModel.displayMessages.first?.content, "message-5")
    }

    // MARK: - State & Model

    func test_stateBindings_reflectManagerFields() {
        let settings = makeSettings()
        let manager = TestCLIBridgeManager()
        let project = makeProject(path: "/tmp/project-state-bindings")
        let viewModel = ChatViewModel(project: project, settings: settings, manager: manager)
        let approval = ApprovalRequest(id: "req-1", toolName: "bash", input: ["command": "ls"], receivedAt: Date())
        let question = AskUserQuestionData(requestId: "q1", questions: [
            UserQuestion(question: "Continue?", header: nil, options: [], multiSelect: false)
        ])

        // Set manager state
        manager.connectionState = .connected(agentId: "agent-1")
        manager.agentState = .executing
        manager.currentText = "streaming"
        manager.tokenUsage = CLIUsageContent(
            type: .usage,
            inputTokens: 1,
            outputTokens: 2,
            contextUsed: 3,
            contextLimit: 7
        )
        manager.isInputQueued = true
        manager.queuePosition = 2
        manager.activeSubagent = CLISubagentStartContent(id: "subagent-1", description: "Task")
        manager.toolProgress = CLIProgressContent(tool: "Shell", elapsed: 1.0)
        manager.sessionId = "session-1"

        // Set viewModel local state
        viewModel.pendingApprovalRequest = approval
        viewModel.pendingQuestionData = question

        XCTAssertTrue(viewModel.isConnected)
        XCTAssertTrue(viewModel.isProcessing)
        XCTAssertEqual(viewModel.currentStreamingText, "streaming")
        XCTAssertEqual(viewModel.tokenUsage?.used, 3)
        XCTAssertEqual(viewModel.tokenUsage?.total, 7)
        XCTAssertEqual(viewModel.pendingApproval, approval)
        XCTAssertEqual(viewModel.pendingQuestion?.requestId, "q1")
        XCTAssertTrue(viewModel.isInputQueued)
        XCTAssertEqual(viewModel.queuePosition, 2)
        XCTAssertEqual(viewModel.activeSubagent?.displayAgentType, "Task")
        XCTAssertEqual(viewModel.toolProgress?.tool, "Shell")
        XCTAssertEqual(viewModel.activeSessionId, "session-1")
    }

    func test_handleProcessingChange_updatesStreamingMetadata() {
        let (viewModel, _, _, _) = makeFixture()
        let previousId = viewModel.streamingMessageId
        let previousTimestamp = viewModel.streamingMessageTimestamp

        viewModel.handleProcessingChange(oldValue: false, isProcessing: true)

        XCTAssertNotEqual(viewModel.streamingMessageId, previousId)
        XCTAssertTrue(viewModel.streamingMessageTimestamp >= previousTimestamp)
    }

    func test_handleModelChange_callsSetModelWhenConnected() async {
        let settings = makeSettings()
        let manager = TestCLIBridgeManager()
        let project = makeProject(path: "/tmp/project-model-change")
        let viewModel = ChatViewModel(project: project, settings: settings, manager: manager)
        manager.connectionState = .connected(agentId: "agent-1")

        viewModel.handleModelChange(oldModel: .haiku, newModel: .sonnet)

        // Wait for async Task to complete
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(manager.setModelCalls.count, 1)
        XCTAssertTrue(manager.setModelCalls.first?.contains("sonnet") == true)
    }

    // MARK: - Helpers

    private func makeSettings() -> AppSettings {
        return AppSettings()
    }

    private func makeProject(path: String = "/tmp/project-\(UUID().uuidString)", sessions: [ProjectSession]? = nil) -> Project {
        Project(
            name: "TestProject",
            path: path,
            displayName: nil,
            fullPath: nil,
            sessions: sessions,
            sessionMeta: nil
        )
    }

    private func makeSession(
        id: String = "session-\(UUID().uuidString)",
        summary: String? = "Summary",
        messageCount: Int? = 1,
        lastActivity: String? = "2024-01-01T00:00:00Z",
        lastUserMessage: String? = "Hello",
        lastAssistantMessage: String? = "Hi"
    ) -> ProjectSession {
        ProjectSession(
            id: id,
            summary: summary,
            lastActivity: lastActivity,
            messageCount: messageCount,
            lastUserMessage: lastUserMessage,
            lastAssistantMessage: lastAssistantMessage
        )
    }

    private func makeFixture(
        project: Project? = nil,
        settings: AppSettings? = nil,
        manager: TestCLIBridgeManager? = nil
    ) -> (ChatViewModel, TestCLIBridgeManager, AppSettings, Project) {
        let settings = settings ?? makeSettings()
        let manager = manager ?? TestCLIBridgeManager()
        let project = project ?? makeProject()
        let viewModel = ChatViewModel(project: project, settings: settings, manager: manager)
        return (viewModel, manager, settings, project)
    }
}

@MainActor
final class TestChatViewModel: ChatViewModel {
    var didLoadSessionHistory = false

    override func loadSessionHistory(_ session: ProjectSession) {
        didLoadSessionHistory = true
    }
}

@MainActor
final class TestCLIBridgeManager: CLIBridgeManager {
    struct SentInput: Equatable {
        let text: String
        let hasImages: Bool
        let thinkingMode: String?
    }

    struct ConnectCall: Equatable {
        let projectPath: String
        let sessionId: String?
        let model: String?
    }

    private(set) var sentInputs: [SentInput] = []
    private(set) var connectCalls: [ConnectCall] = []
    private(set) var disconnectCalled = false
    private(set) var setModelCalls: [String] = []
    private(set) var interruptCalled = false
    private(set) var respondToPermissionCalls: [(id: String, choice: CLIPermissionChoice)] = []
    private(set) var respondToQuestionCalls: [(id: String, answers: [String: Any])] = []

    override func connect(
        projectPath: String,
        sessionId: String? = nil,
        model: String? = nil,
        helper: Bool = false
    ) async {
        connectCalls.append(ConnectCall(projectPath: projectPath, sessionId: sessionId, model: model))
        if let sid = sessionId {
            self.sessionId = sid
        }
    }

    override func sendInput(_ text: String, images: [CLIImageAttachment]? = nil, thinkingMode: String? = nil) async throws {
        sentInputs.append(SentInput(text: text, hasImages: images != nil && !images!.isEmpty, thinkingMode: thinkingMode))
    }

    override func disconnect(preserveSession: Bool = false) {
        disconnectCalled = true
        connectionState = .disconnected
        agentState = .stopped
    }

    override func setModel(_ model: String) async throws {
        setModelCalls.append(model)
    }

    override func interrupt() async throws {
        interruptCalled = true
    }

    override func respondToPermission(id: String, choice: CLIPermissionChoice) async throws {
        respondToPermissionCalls.append((id, choice))
    }

    override func respondToQuestion(id: String, answers: [String: Any]) async throws {
        respondToQuestionCalls.append((id, answers))
    }

    // Convenience for tests to simulate events
    func simulateEvent(_ event: StreamEvent) {
        onEvent?(event)
    }
}
