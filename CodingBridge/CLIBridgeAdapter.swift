import Foundation
import Combine

// MARK: - CLI Bridge Adapter
// Adapts CLIBridgeManager to provide a consistent streaming interface
// Used by ChatView and other components that need real-time Claude communication

/// Adapter that provides streaming interface using CLIBridgeManager
@MainActor
class CLIBridgeAdapter: ObservableObject {
    // MARK: - Published State

    @Published var connectionState: ConnectionState = .disconnected
    @Published var isProcessing: Bool = false
    @Published var isAborting: Bool = false
    @Published var currentText: String = ""
    @Published var lastError: String?
    @Published var sessionId: String?
    @Published var tokenUsage: TokenUsage?
    @Published var currentModel: ClaudeModel?
    @Published var currentModelId: String?
    @Published var isSwitchingModel: Bool = false
    @Published var pendingApproval: ApprovalRequest?
    @Published var pendingQuestion: AskUserQuestionData?
    @Published var isReattaching: Bool = false

    // MARK: - CLI Bridge-Specific State (new features)

    /// Input is queued (sent while agent was busy)
    @Published var isInputQueued: Bool = false

    /// Position in queue (1-based)
    @Published var queuePosition: Int = 0

    /// Active subagent (Task tool spawn)
    @Published var activeSubagent: CLISubagentStartContent?

    /// Progress for long-running tool
    @Published var toolProgress: CLIProgressContent?

    /// Session-level permission mode override (not persisted, lost on disconnect)
    @Published var sessionPermissionMode: PermissionMode?

    // MARK: - Callbacks

    var onText: ((String) -> Void)?
    var onTextCommit: ((String) -> Void)?
    var onToolUse: ((String, String, String) -> Void)?  // (id, tool, input)
    var onToolResult: ((String, String, String) -> Void)?  // (id, tool, output)
    var onThinking: ((String) -> Void)?
    var onComplete: ((String?) -> Void)?
    var onAskUserQuestion: ((AskUserQuestionData) -> Void)?
    var onError: ((String) -> Void)?
    var onSessionCreated: ((String) -> Void)?
    var onModelChanged: ((ClaudeModel, String) -> Void)?
    var onAborted: (() -> Void)?
    var onSessionRecovered: (() -> Void)?
    var onSessionAttached: (() -> Void)?
    var onApprovalRequest: ((ApprovalRequest) -> Void)?

    // CLI Bridge-specific callbacks
    var onSubagentStart: ((CLISubagentStartContent) -> Void)?
    var onSubagentComplete: ((CLISubagentCompleteContent) -> Void)?
    var onInputQueued: ((Int) -> Void)?  // position
    var onQueueCleared: (() -> Void)?
    var onProgress: ((CLIProgressContent) -> Void)?
    var onSessionEvent: ((CLISessionEvent) -> Void)?
    var onHistory: ((CLIHistoryPayload) -> Void)?

    // Connection lifecycle callbacks
    var onConnectionReplaced: (() -> Void)?
    var onReconnecting: ((Int, TimeInterval) -> Void)?  // (attempt, delay)
    var onConnectionError: ((ConnectionError) -> Void)?
    var onNetworkStatusChanged: ((Bool) -> Void)?  // isAvailable

    // MARK: - Computed Properties

    /// Convenience property to check connection state
    var isConnected: Bool {
        connectionState.isConnected
    }

    // MARK: - Private State

    private let manager: CLIBridgeManager
    private var settings: AppSettings
    private var currentProjectPath: String?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(settings: AppSettings? = nil, manager: CLIBridgeManager? = nil) {
        self.settings = settings ?? AppSettings()
        self.manager = manager ?? CLIBridgeManager()
        setupCallbacks()
        setupStateObservation()
    }

    func updateSettings(_ newSettings: AppSettings) {
        self.settings = newSettings
        manager.updateServerURL(newSettings.serverURL)
    }

    // MARK: - Connection

    /// Connect to a project
    func connect(projectPath: String, sessionId: String? = nil) {
        currentProjectPath = projectPath
        let modelId = resolveModelId()
        log.debug("[CLIBridgeAdapter] Connecting with model: \(modelId ?? "nil") (settings.defaultModel: \(settings.defaultModel.shortName))")
        Task {
            await manager.connect(
                projectPath: projectPath,
                sessionId: sessionId,
                model: modelId,
                helper: false
            )
        }
    }

    /// Connect without parameters (uses stored project path)
    /// This is used when reconnecting after app returns to foreground
    func connect() {
        guard let projectPath = currentProjectPath else {
            log.warning("CLIBridgeAdapter.connect() called without stored project path")
            return
        }
        connect(projectPath: projectPath, sessionId: sessionId)
    }

    func disconnect() {
        manager.disconnect()
    }

    /// Attach to an existing active session
    func attachToSession(sessionId: String, projectPath: String) {
        isReattaching = true
        currentProjectPath = projectPath
        Task {
            // Reconnect with the existing session ID
            await manager.connect(
                projectPath: projectPath,
                sessionId: sessionId,
                model: resolveModelId(),
                helper: false
            )
            await MainActor.run {
                isReattaching = false
                onSessionAttached?()
            }
        }
    }

    /// Recover from background processing
    func recoverFromBackground(sessionId: String, projectPath: String) {
        log.info("Recovering session from background: \(sessionId.prefix(8))...")
        attachToSession(sessionId: sessionId, projectPath: projectPath)
    }

    /// Refresh token usage from the server
    /// Token usage is automatically updated via stream messages, but this can force a refresh
    func refreshTokenUsage(projectPath: String, sessionId: String) async {
        if let usage = manager.tokenUsage {
            tokenUsage = TokenUsage(
                used: usage.contextUsed ?? usage.totalTokens,
                total: usage.contextLimit ?? 200_000
            )
        }
    }

    // MARK: - Messaging

    /// Send a message to Claude with optional image attachments
    /// - Parameters:
    ///   - message: The text message to send
    ///   - projectPath: Path to the project
    ///   - resumeSessionId: Optional session ID to resume
    ///   - permissionMode: Optional permission mode override
    ///   - images: Optional array of ImageAttachment objects
    ///   - model: Optional model override
    func sendMessage(
        _ message: String,
        projectPath: String,
        resumeSessionId: String? = nil,
        permissionMode: String? = nil,
        images: [ImageAttachment]? = nil,
        model: String? = nil
    ) {
        currentProjectPath = projectPath
        Task {
            // If not connected, connect first
            if !manager.connectionState.isConnected {
                await manager.connect(
                    projectPath: projectPath,
                    sessionId: resumeSessionId,
                    model: model ?? resolveModelId()
                )

                // Wait briefly for connection
                try? await Task.sleep(nanoseconds: 500_000_000)
            }

            // Always send permission mode before first message in a session
            // This ensures the agent respects current app settings
            if let mode = permissionMode {
                do {
                    let cliMode = parsePermissionMode(mode)
                    try await manager.setPermissionMode(cliMode)
                    log.debug("Set permission mode: \(mode)")
                } catch {
                    log.warning("Failed to set permission mode: \(error)")
                }
            }

            // Process and build image attachments
            var cliImages: [CLIImageAttachment]? = nil
            if let attachments = images, !attachments.isEmpty {
                cliImages = await prepareImages(attachments)
            }

            do {
                manager.clearCurrentText()
                isProcessing = true
                // Send thinking mode to server (nil for normal mode)
                let thinkingMode = settings.thinkingMode == .normal ? nil : settings.thinkingMode.rawValue
                try await manager.sendInput(message, images: cliImages, thinkingMode: thinkingMode)
            } catch {
                isProcessing = false
                lastError = error.localizedDescription
                onError?(error.localizedDescription)
            }
        }
    }

    // MARK: - Image Processing

    /// Prepare images for sending using smart upload strategy
    /// - Small images (<500KB): inline as base64
    /// - Large images: upload via REST API and use reference ID
    private func prepareImages(_ attachments: [ImageAttachment]) async -> [CLIImageAttachment] {
        var result: [CLIImageAttachment] = []

        for attachment in attachments {
            do {
                // Process image (HEIC conversion, compression)
                let processed = try ImageUtilities.prepareForUpload(attachment.originalData)
                let dataToSend = processed.data

                if dataToSend.count > ImageAttachment.uploadThreshold {
                    // Large image: upload first, then reference
                    if let agentId = manager.connectionState.agentId {
                        do {
                            let referenceId = try await uploadImage(dataToSend, mimeType: processed.mimeType, agentId: agentId)
                            result.append(CLIImageAttachment(referenceId: referenceId))
                            log.debug("Uploaded large image (\(processed.finalSize) bytes), ref: \(referenceId)")
                        } catch {
                            // Fallback to inline if upload fails
                            log.warning("Image upload failed, falling back to inline: \(error)")
                            let base64 = dataToSend.base64EncodedString()
                            result.append(CLIImageAttachment(base64Data: base64, mimeType: processed.mimeType))
                        }
                    } else {
                        // No agent ID yet, use inline
                        let base64 = dataToSend.base64EncodedString()
                        result.append(CLIImageAttachment(base64Data: base64, mimeType: processed.mimeType))
                    }
                } else {
                    // Small image: inline as base64
                    let base64 = dataToSend.base64EncodedString()
                    result.append(CLIImageAttachment(base64Data: base64, mimeType: processed.mimeType))
                    log.debug("Inlined small image (\(processed.finalSize) bytes)")
                }
            } catch {
                // If processing fails, try with original data
                log.warning("Image processing failed: \(error)")
                let mimeType = ImageUtilities.detectMediaType(from: attachment.originalData)
                let base64 = attachment.originalData.base64EncodedString()
                result.append(CLIImageAttachment(base64Data: base64, mimeType: mimeType))
            }
        }

        return result
    }

    /// Upload image to server via REST API
    private func uploadImage(_ data: Data, mimeType: String, agentId: String) async throws -> String {
        let apiClient = await MainActor.run { CLIBridgeAPIClient(serverURL: self.settings.serverURL) }
        let response = try await apiClient.uploadImage(agentId: agentId, imageData: data, mimeType: mimeType)
        return response.id
    }

    /// Parse permission mode string to CLI type
    private func parsePermissionMode(_ mode: String) -> CLISetPermissionModePayload.CLIPermissionMode {
        switch mode {
        case "bypassPermissions":
            return .bypassPermissions
        case "acceptEdits":
            return .acceptEdits
        default:
            return .default
        }
    }

    /// Abort the current operation (convenience alias for abort())
    func abortSession() {
        abort()
    }

    func abort() {
        isAborting = true
        Task {
            do {
                try await manager.interrupt()
                isAborting = false
                isProcessing = false
                onAborted?()
            } catch {
                isAborting = false
                lastError = error.localizedDescription
            }
        }
    }

    /// Approve the pending permission request
    func approvePendingRequest(alwaysAllow: Bool = false) {
        guard let approval = pendingApproval else { return }
        respondToApproval(requestId: approval.id, approved: true, alwaysAllow: alwaysAllow)
        pendingApproval = nil
    }

    /// Deny the pending permission request
    func denyPendingRequest() {
        guard let approval = pendingApproval else { return }
        respondToApproval(requestId: approval.id, approved: false, alwaysAllow: false)
        pendingApproval = nil
    }

    func respondToApproval(requestId: String, approved: Bool, alwaysAllow: Bool) {
        Task {
            let choice: CLIPermissionResponsePayload.CLIPermissionChoice
            if alwaysAllow {
                choice = .always
            } else if approved {
                choice = .allow
            } else {
                choice = .deny
            }

            do {
                try await manager.respondToPermission(id: requestId, choice: choice)
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    /// Respond to a pending question with user's answers
    func respondToQuestion(requestId: String, answers: [String: Any]) {
        Task {
            do {
                try await manager.respondToQuestion(id: requestId, answers: answers)
                await MainActor.run {
                    pendingQuestion = nil
                }
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    /// Clear pending question without responding (e.g., when cancelled)
    func clearPendingQuestion() {
        pendingQuestion = nil
    }

    func switchModel(to model: ClaudeModel) {
        isSwitchingModel = true
        Task {
            do {
                let modelId = model.modelId ?? settings.customModelId
                try await manager.setModel(modelId)
            } catch {
                lastError = error.localizedDescription
            }
            isSwitchingModel = false
        }
    }

    /// Cancel queued input (if input was queued while agent was busy)
    func cancelQueuedInput() {
        guard isInputQueued else { return }
        Task {
            do {
                try await manager.cancelQueuedInput()
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    // MARK: - Permission Mode Control

    /// Set permission mode for current session only (not persisted)
    /// This overrides the global and project-level settings until disconnect
    func setSessionPermissionMode(_ mode: PermissionMode) {
        Task {
            do {
                try await manager.setPermissionMode(mode.toCLIPermissionMode())
                sessionPermissionMode = mode
                log.debug("Set session permission mode: \(mode.rawValue)")
            } catch {
                lastError = error.localizedDescription
                log.error("Failed to set session permission mode: \(error)")
            }
        }
    }

    /// Clear session permission mode override (revert to project/global settings)
    func clearSessionPermissionMode() {
        sessionPermissionMode = nil
    }

    /// Clear current streaming text (both adapter and manager state)
    func clearCurrentText() {
        currentText = ""
        manager.clearCurrentText()
    }

    // MARK: - Image Upload via REST API

    /// Upload an image via REST API for use in messages.
    /// For large images, this is more efficient than base64 encoding in WebSocket.
    /// - Returns: The image reference ID to use in CLIImageAttachment
    func uploadImage(_ imageData: Data) async throws -> String {
        guard let agentId = manager.connectionState.agentId else {
            throw CLIBridgeError.notConnected
        }

        let mimeType = ImageUtilities.detectMediaType(from: imageData)
        let apiClient = await MainActor.run { CLIBridgeAPIClient(serverURL: self.settings.serverURL) }
        let response = try await apiClient.uploadImage(agentId: agentId, imageData: imageData, mimeType: mimeType)
        return response.id
    }

    // MARK: - Session Event Subscription

    /// Subscribe to session events for real-time session list updates.
    /// Events include session creation, updates, and deletion.
    func subscribeToSessionEvents(projectPath: String? = nil) {
        Task {
            do {
                try await manager.subscribeToSessions(projectPath: projectPath)
            } catch {
                log.error("Failed to subscribe to session events: \(error)")
            }
        }
    }

    /// Send a message with an uploaded image reference.
    /// Use this after uploading an image via uploadImage() for large images.
    func sendMessageWithImageReference(
        _ message: String,
        imageId: String,
        projectPath: String,
        resumeSessionId: String? = nil,
        model: String? = nil
    ) {
        currentProjectPath = projectPath
        Task {
            // Connect if needed
            if !manager.connectionState.isConnected {
                await manager.connect(
                    projectPath: projectPath,
                    sessionId: resumeSessionId,
                    model: model ?? resolveModelId()
                )
                try? await Task.sleep(nanoseconds: 500_000_000)
            }

            do {
                manager.clearCurrentText()
                isProcessing = true
                // Use image reference instead of base64
                let images = [CLIImageAttachment(referenceId: imageId)]
                try await manager.sendInput(message, images: images)
            } catch {
                isProcessing = false
                lastError = error.localizedDescription
                onError?(error.localizedDescription)
            }
        }
    }

    // MARK: - Private Helpers

    private func setupCallbacks() {
        // Map CLIBridgeManager callbacks to adapter callbacks

        manager.onText = { [weak self] content, isFinal in
            guard let self = self else { return }
            self.currentText = self.manager.currentText
            self.onText?(content)

            if isFinal {
                // Capture text and clear BEFORE callback to prevent streaming view showing same text
                // SwiftUI may render immediately after messages.append(), so currentText must be empty
                let textToCommit = self.currentText
                self.manager.clearCurrentText()
                self.currentText = ""
                self.onTextCommit?(textToCommit)
            }
        }

        manager.onThinking = { [weak self] content in
            self?.onThinking?(content)
        }

        manager.onToolStart = { [weak self] id, tool, input in
            // Convert input dict to JSON string for compatibility
            // First, recursively convert to ensure all values are JSON-serializable
            let sanitizedInput = Self.sanitizeForJSON(input)
            let inputString: String
            if let data = try? JSONSerialization.data(withJSONObject: sanitizedInput),
               let str = String(data: data, encoding: .utf8) {
                inputString = str
            } else {
                // Fallback: try to produce a JSON-like string manually
                inputString = Self.toJSONLikeString(input)
            }
            self?.onToolUse?(id, tool, inputString)
        }

        manager.onToolResult = { [weak self] id, tool, output, success in
            self?.onToolResult?(id, tool, output)
        }

        manager.onStopped = { [weak self] reason in
            self?.isProcessing = false
            self?.onComplete?(self?.sessionId)
        }

        manager.onError = { [weak self] error in
            self?.lastError = error.message
            self?.onError?(error.message)
        }

        manager.onSessionConnected = { [weak self] sessionId in
            guard let self = self else { return }
            self.sessionId = sessionId
            self.onSessionCreated?(sessionId)

            // Check if server model matches desired model, switch if needed
            let desiredModelId = self.resolveModelId()
            let serverModelId = self.manager.currentModel
            log.debug("[CLIBridgeAdapter] Session connected - server model: \(serverModelId ?? "nil"), desired: \(desiredModelId ?? "nil")")

            // If server is using a different model, send set_model to switch
            if let desired = desiredModelId,
               let server = serverModelId,
               !self.modelsMatch(server: server, desired: desired) {
                log.info("[CLIBridgeAdapter] Model mismatch - switching to \(desired)")
                Task {
                    do {
                        try await self.manager.setModel(desired)
                    } catch {
                        log.error("[CLIBridgeAdapter] Failed to set model: \(error)")
                    }
                }
            }
        }

        manager.onModelChanged = { [weak self] modelId in
            guard let self = self else { return }
            let model = self.parseModelFromId(modelId)
            self.currentModel = model
            self.currentModelId = modelId
            self.onModelChanged?(model, modelId)
        }

        manager.onPermissionRequest = { [weak self] request in
            guard let self = self else { return }

            // Convert to ApprovalRequest for compatibility
            let approval = ApprovalRequest(
                id: request.id,
                toolName: request.tool,
                input: request.input.mapValues { $0.value },
                receivedAt: Date()
            )
            self.pendingApproval = approval
            self.onApprovalRequest?(approval)
        }

        manager.onQuestionRequest = { [weak self] request in
            guard let self = self else { return }
            // Convert to AskUserQuestionData for compatibility (uses existing Models.swift types)
            // Preserve the request ID for respondToQuestion API call
            let questions = request.questions.map { q in
                UserQuestion(
                    question: q.question,
                    header: q.header,
                    options: q.options.map { QuestionOption(label: $0.label, description: $0.description) },
                    multiSelect: q.multiSelect
                )
            }
            let data = AskUserQuestionData(requestId: request.id, questions: questions)
            // Set published property (like pendingApproval) for reliable UI binding
            self.pendingQuestion = data
            self.onAskUserQuestion?(data)
        }

        // Subagent callbacks
        manager.onSubagentStart = { [weak self] content in
            self?.activeSubagent = content
            self?.onSubagentStart?(content)
        }

        manager.onSubagentComplete = { [weak self] content in
            self?.activeSubagent = nil
            self?.onSubagentComplete?(content)
        }

        // Session event callback (for real-time session list updates)
        manager.onSessionEvent = { [weak self] event in
            self?.onSessionEvent?(event)
        }

        // History callback (for session resume/replay)
        manager.onHistory = { [weak self] payload in
            self?.onHistory?(payload)
        }

        // Connection lifecycle callbacks
        manager.onConnectionReplaced = { [weak self] in
            log.warning("[CLIBridgeAdapter] Connection replaced by another client")
            self?.onConnectionReplaced?()
        }

        manager.onReconnecting = { [weak self] attempt, delay in
            log.info("[CLIBridgeAdapter] Reconnecting: attempt \(attempt), delay \(delay)s")
            self?.onReconnecting?(attempt, delay)
        }

        manager.onConnectionError = { [weak self] error in
            log.error("[CLIBridgeAdapter] Connection error: \(error.localizedDescription)")
            self?.onConnectionError?(error)
        }

        manager.onNetworkStatusChanged = { [weak self] isAvailable in
            log.debug("[CLIBridgeAdapter] Network status: \(isAvailable ? "available" : "unavailable")")
            self?.onNetworkStatusChanged?(isAvailable)
        }

        // Permission mode changed callback
        manager.onPermissionModeChanged = { [weak self] mode in
            guard let self = self else { return }
            if let permMode = PermissionMode(rawValue: mode) {
                self.sessionPermissionMode = permMode
                log.debug("[CLIBridgeAdapter] Permission mode changed: \(mode)")
            }
        }
    }

    /// Setup Combine observation of manager state changes
    private func setupStateObservation() {
        // Observe connection state changes
        manager.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                switch state {
                case .disconnected:
                    self.connectionState = .disconnected
                case .connecting:
                    self.connectionState = .connecting
                case .connected:
                    self.connectionState = .connected
                case .reconnecting(let attempt):
                    self.connectionState = .reconnecting(attempt: attempt)
                }
            }
            .store(in: &cancellables)

        // Observe agent state changes
        manager.$agentState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.isProcessing = state.isProcessing
            }
            .store(in: &cancellables)

        // NOTE: currentText is updated via onText callback, NOT via Combine subscription
        // Using both paths creates a race condition where the async Combine dispatch
        // can overwrite the cleared text after onTextCommit has already processed it

        // Observe session ID changes
        manager.$sessionId
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessionId in
                self?.sessionId = sessionId
            }
            .store(in: &cancellables)

        // Observe model changes
        manager.$currentModel
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] modelId in
                guard let self = self else { return }
                self.currentModelId = modelId
                self.currentModel = self.parseModelFromId(modelId)
            }
            .store(in: &cancellables)

        // Observe token usage changes
        manager.$tokenUsage
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] usage in
                // Use totalTokens (input + output) as used, with 200K default context limit
                self?.tokenUsage = TokenUsage(
                    used: usage.contextUsed ?? usage.totalTokens,
                    total: usage.contextLimit ?? 200_000
                )
            }
            .store(in: &cancellables)

        // Observe error changes
        manager.$lastError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.lastError = error
            }
            .store(in: &cancellables)

        // Observe input queue state
        manager.$isInputQueued
            .receive(on: DispatchQueue.main)
            .sink { [weak self] queued in
                self?.isInputQueued = queued
            }
            .store(in: &cancellables)

        manager.$queuePosition
            .receive(on: DispatchQueue.main)
            .sink { [weak self] position in
                self?.queuePosition = position
            }
            .store(in: &cancellables)

        // Observe subagent state
        manager.$activeSubagent
            .receive(on: DispatchQueue.main)
            .sink { [weak self] subagent in
                self?.activeSubagent = subagent
            }
            .store(in: &cancellables)

        // Observe tool progress
        manager.$toolProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.toolProgress = progress
            }
            .store(in: &cancellables)
    }

    private func resolveModelId() -> String? {
        switch settings.defaultModel {
        case .opus, .sonnet, .haiku:
            return settings.defaultModel.modelId
        case .custom:
            return settings.customModelId.isEmpty ? nil : settings.customModelId
        }
    }

    private func parseModelFromId(_ modelId: String) -> ClaudeModel {
        if modelId.contains("opus") {
            return .opus
        } else if modelId.contains("sonnet") {
            return .sonnet
        } else if modelId.contains("haiku") {
            return .haiku
        } else {
            return .custom
        }
    }

    /// Check if server model matches desired model
    /// Server may return full model ID (e.g., "claude-sonnet-4-20250514") while we send alias ("sonnet")
    private func modelsMatch(server: String, desired: String) -> Bool {
        // Direct match
        if server == desired { return true }

        // Server returns full ID, we sent alias
        // "claude-sonnet-4-20250514" should match "sonnet"
        // "claude-opus-4-5-20251101" should match "opus"
        // "claude-3-5-haiku-20241022" should match "haiku"
        let serverLower = server.lowercased()
        let desiredLower = desired.lowercased()

        if serverLower.contains(desiredLower) { return true }
        if desiredLower.contains(serverLower) { return true }

        return false
    }

    // MARK: - JSON Serialization Helpers

    /// Recursively convert a value to ensure it's JSON-serializable
    /// This handles nested arrays/dicts that might contain non-Foundation types
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
            // Convert unknown types to string representation
            return String(describing: value)
        }
    }

    /// Produce a JSON-like string for a dictionary when JSONSerialization fails
    /// This is a fallback that produces parseable output for TodoListView
    private static func toJSONLikeString(_ value: Any) -> String {
        switch value {
        case let array as [Any]:
            let elements = array.map { toJSONLikeString($0) }
            return "[\(elements.joined(separator: ", "))]"
        case let dict as [String: Any]:
            let pairs = dict.map { key, val in
                "\"\(escapeJSON(key))\": \(toJSONLikeString(val))"
            }
            return "{\(pairs.joined(separator: ", "))}"
        case let string as String:
            return "\"\(escapeJSON(string))\""
        case let number as NSNumber:
            return "\(number)"
        case let bool as Bool:
            return bool ? "true" : "false"
        case let int as Int:
            return "\(int)"
        case let double as Double:
            return "\(double)"
        case is NSNull:
            return "null"
        default:
            return "\"\(escapeJSON(String(describing: value)))\""
        }
    }

    /// Escape special characters for JSON strings
    private static func escapeJSON(_ string: String) -> String {
        var result = string
        result = result.replacingOccurrences(of: "\\", with: "\\\\")
        result = result.replacingOccurrences(of: "\"", with: "\\\"")
        result = result.replacingOccurrences(of: "\n", with: "\\n")
        result = result.replacingOccurrences(of: "\r", with: "\\r")
        result = result.replacingOccurrences(of: "\t", with: "\\t")
        return result
    }

    // MARK: - State Synchronization

    /// Sync CLIBridgeManager state to adapter published properties
    private func syncState() {
        // Map connection state
        switch manager.connectionState {
        case .disconnected:
            connectionState = .disconnected
        case .connecting:
            connectionState = .connecting
        case .connected:
            connectionState = .connected
        case .reconnecting(let attempt):
            connectionState = .reconnecting(attempt: attempt)
        }

        // Map agent state to isProcessing
        isProcessing = manager.agentState.isProcessing

        // Sync other state
        sessionId = manager.sessionId
        currentModelId = manager.currentModel
        if let modelId = manager.currentModel {
            currentModel = parseModelFromId(modelId)
        }
        lastError = manager.lastError

        // Map token usage
        if let usage = manager.tokenUsage {
            tokenUsage = TokenUsage(
                used: usage.contextUsed ?? usage.totalTokens,
                total: usage.contextLimit ?? 200_000
            )
        }
    }
}
