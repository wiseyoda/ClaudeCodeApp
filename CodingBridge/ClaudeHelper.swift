import Foundation

/// ClaudeHelper provides AI-powered suggestions using fast Haiku calls.
/// This is a "meta-AI" layer that uses Claude to enhance the user experience.
@MainActor
class ClaudeHelper: ObservableObject {
    private var settings: AppSettings
    private var webSocket: URLSessionWebSocketTask?
    private var responseBuffer = ""
    private var completion: ((Result<String, Error>) -> Void)?
    private var timeoutTask: Task<Void, Never>?

    /// Debug logging
    private var debugLog: DebugLogStore { DebugLogStore.shared }

    /// Dedicated session ID for helper queries per project.
    /// Uses a deterministic UUID based on project path to ensure all helper
    /// queries for the same project reuse the same session.
    /// Format: "helper-{deterministic-uuid}" to identify helper sessions.
    private var helperSessionIds: [String: String] = [:]

    /// Get or create a helper session ID for a project.
    /// Creates a deterministic session ID so all helper queries reuse the same session.
    private func helperSessionId(for projectPath: String) -> String {
        if let existing = helperSessionIds[projectPath] {
            return existing
        }
        // Create a deterministic UUID from the project path
        let sessionId = Self.createHelperSessionId(for: projectPath)
        helperSessionIds[projectPath] = sessionId
        return sessionId
    }

    /// Create a deterministic "helper" session ID for a project path.
    /// Uses a hash to create a valid UUID format that's consistent for the same path.
    /// Note: This is nonisolated so it can be called from non-MainActor contexts (like session filtering).
    nonisolated static func createHelperSessionId(for projectPath: String) -> String {
        // Hash the project path to get consistent bytes
        let data = projectPath.data(using: .utf8) ?? Data()
        var hash = [UInt8](repeating: 0, count: 32)

        // Initialize with non-zero seed values to prevent zero-state issues
        for i in 0..<32 {
            hash[i] = UInt8((i * 17 + 31) & 0xFF)
        }

        // Mix each byte into the hash with better avalanche properties
        for (i, byte) in data.enumerated() {
            // Mix the byte position into the hash for position sensitivity
            let positionByte = UInt8((i * 37 + 7) & 0xFF)
            let mixedByte = byte &+ positionByte

            // Update multiple positions for better diffusion
            hash[i % 32] = hash[i % 32] &+ mixedByte
            hash[(i + 1) % 32] ^= mixedByte
            hash[(i + 7) % 32] = hash[(i + 7) % 32] &+ (mixedByte >> 3)
            hash[(i + 13) % 32] ^= (mixedByte << 2) | (mixedByte >> 6)
        }

        // Final mixing pass to propagate differences
        for i in 0..<32 {
            hash[i] = hash[i] &+ hash[(i + 17) % 32]
            hash[(i + 5) % 32] ^= hash[i]
        }

        // Format as UUID v4: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
        // part1: 8 hex chars (4 bytes)
        // part2: 4 hex chars (2 bytes)
        // part3: 4 hex chars (version 4 + 3 nibbles)
        // part4: 4 hex chars (variant 8/9/a/b + 3 nibbles)
        // part5: 12 hex chars (6 bytes)
        let part1 = String(format: "%02x%02x%02x%02x", hash[0], hash[1], hash[2], hash[3])
        let part2 = String(format: "%02x%02x", hash[4], hash[5])
        // Version 4: first nibble is 4, followed by 3 nibbles from hash
        let part3 = String(format: "4%02x%01x", hash[6], hash[7] & 0x0f)
        // Variant: first nibble is 8/9/a/b, followed by 3 nibbles from hash
        let variantNibble = 0x8 | (Int(hash[8]) & 0x03)
        let part4 = String(format: "%01x%02x%01x", variantNibble, hash[9], hash[10] & 0x0f)
        let part5 = String(format: "%02x%02x%02x%02x%02x%02x", hash[11], hash[12], hash[13], hash[14], hash[15], hash[16])

        return "\(part1)-\(part2)-\(part3)-\(part4)-\(part5)"
    }

    /// Helper prompt prefixes used to identify helper-generated sessions.
    /// These are the opening phrases of prompts sent to ClaudeHelper functions.
    private static let helperPromptPrefixes = [
        "Based on this conversation context, suggest",
        "Based on this conversation, which files",
        "You are helping a developer expand a quick idea",
        "Analyze this Claude Code response and suggest"
    ]

    /// Check if a message content looks like a ClaudeHelper prompt.
    /// Used to filter out orphan helper sessions from the session list.
    nonisolated static func isHelperPrompt(_ content: String?) -> Bool {
        guard let content = content, !content.isEmpty else { return false }
        return helperPromptPrefixes.contains { content.hasPrefix($0) }
    }

    /// Check if a session ID is an agent sub-session (Task tool spawned agents).
    /// These have IDs like "agent-acfbed8" and shouldn't appear in the session picker.
    nonisolated static func isAgentSession(_ sessionId: String) -> Bool {
        sessionId.hasPrefix("agent-")
    }

    /// Check if a session should be hidden from the session picker.
    /// Only filters:
    /// - Deterministic helper session ID (orphan sessions from before fix)
    /// - Agent sub-sessions (Task tool spawned agents)
    ///
    /// Note: We don't filter by lastUserMessage content because ClaudeHelper
    /// now correctly reuses the existing session - so a real session may have
    /// a helper prompt as its last message.
    nonisolated static func isHelperSession(sessionId: String, lastUserMessage: String?, projectPath: String) -> Bool {
        // Check if ID matches the deterministic helper session ID
        if sessionId == createHelperSessionId(for: projectPath) {
            return true
        }
        // Check if this is an agent sub-session (Task tool)
        return isAgentSession(sessionId)
    }

    @Published var isLoading = false
    @Published var suggestedActions: [SuggestedAction] = []
    @Published var suggestedFiles: [String] = []

    // Idea enhancement state
    @Published var isEnhancingIdea = false
    @Published var enhancedIdea: EnhancedIdea?

    /// A suggested action that the user can tap to execute
    struct SuggestedAction: Identifiable, Equatable {
        let id = UUID()
        let label: String
        let prompt: String
        let icon: String

        static func == (lhs: SuggestedAction, rhs: SuggestedAction) -> Bool {
            lhs.id == rhs.id
        }
    }

    init(settings: AppSettings) {
        self.settings = settings
    }

    func updateSettings(_ newSettings: AppSettings) {
        self.settings = newSettings
    }

    // MARK: - Suggestion Chips

    /// Generate action suggestions based on recent conversation context
    /// - Parameters:
    ///   - recentMessages: Recent chat messages for context summary
    ///   - projectPath: The project path
    ///   - currentSessionId: Optional current session ID to use for full conversation context.
    ///     If provided, uses this session ID instead of the helper session ID.
    func generateSuggestions(
        recentMessages: [ChatMessage],
        projectPath: String,
        currentSessionId: String? = nil
    ) async {
        debugLog.log("generateSuggestions called with \(recentMessages.count) messages, session: \(currentSessionId?.prefix(8) ?? "helper")", type: .info)

        // Only use last 3-5 messages for context (keep it cheap)
        let context = recentMessages.suffix(5)
        guard !context.isEmpty else {
            debugLog.log("generateSuggestions: No messages, clearing suggestions", type: .info)
            await MainActor.run { suggestedActions = [] }
            return
        }

        // Build a summary of recent context
        let contextSummary = context.map { msg -> String in
            let role = msg.role == .user ? "User" : "Assistant"
            let content = String(msg.content.prefix(200))
            return "\(role): \(content)"
        }.joined(separator: "\n")

        let prompt = """
        Based on this conversation context, suggest 3 short next actions the user might want to take.

        Context:
        \(contextSummary)

        Return ONLY a JSON array with exactly 3 objects, each with "label" (3-5 words), "prompt" (the message to send), and "icon" (SF Symbol name).

        Example response format:
        [{"label":"Run tests","prompt":"Run the test suite and show me any failures","icon":"play.circle"},{"label":"Commit changes","prompt":"Review and commit the current changes","icon":"checkmark.circle"},{"label":"Explain this","prompt":"Explain what you just did in more detail","icon":"questionmark.circle"}]

        Respond with ONLY the JSON array, no other text.
        """

        await MainActor.run { isLoading = true }

        do {
            debugLog.log("Sending suggestion query to backend...", type: .sent)
            let response = try await sendQuickQuery(prompt: prompt, projectPath: projectPath, sessionId: currentSessionId)
            debugLog.log("Received suggestion response: \(response.prefix(200))...", type: .received)
            let actions = parseSuggestedActions(from: response)
            debugLog.log("Parsed \(actions.count) suggested actions", type: .info)
            await MainActor.run {
                suggestedActions = actions
                isLoading = false
            }
        } catch {
            debugLog.logError("Failed to generate suggestions: \(error)")
            await MainActor.run {
                suggestedActions = defaultSuggestions()
                isLoading = false
            }
        }
    }

    /// Parse JSON response into SuggestedAction array
    func parseSuggestedActions(from response: String) -> [SuggestedAction] {
        // Try to find JSON array in response
        guard let jsonStart = response.firstIndex(of: "["),
              let jsonEnd = response.lastIndex(of: "]") else {
            log.warning("No JSON array found in response: \(response.prefix(200))")
            return defaultSuggestions()
        }

        let jsonString = String(response[jsonStart...jsonEnd])

        guard let data = jsonString.data(using: .utf8) else {
            return defaultSuggestions()
        }

        do {
            let decoded = try JSONDecoder().decode([ActionJSON].self, from: data)
            return decoded.prefix(3).map { json in
                SuggestedAction(
                    label: json.label,
                    prompt: json.prompt,
                    icon: json.icon ?? "arrow.right.circle"
                )
            }
        } catch {
            log.error("Failed to decode suggestions JSON: \(error)")
            return defaultSuggestions()
        }
    }

    private struct ActionJSON: Codable {
        let label: String
        let prompt: String
        let icon: String?
    }

    /// Default suggestions when AI fails
    private func defaultSuggestions() -> [SuggestedAction] {
        [
            SuggestedAction(label: "Continue", prompt: "Continue with the next step", icon: "arrow.right.circle"),
            SuggestedAction(label: "Explain more", prompt: "Explain what you just did in more detail", icon: "questionmark.circle"),
            SuggestedAction(label: "Run tests", prompt: "Run the test suite", icon: "play.circle")
        ]
    }

    /// Clear suggestions (e.g., when user starts typing)
    func clearSuggestions() {
        suggestedActions = []
    }

    // MARK: - File Context Suggestions

    /// Suggest relevant files based on conversation context
    func suggestRelevantFiles(
        recentMessages: [ChatMessage],
        availableFiles: [String],
        projectPath: String,
        sessionId: String? = nil
    ) async {
        guard !recentMessages.isEmpty, !availableFiles.isEmpty else {
            await MainActor.run { suggestedFiles = [] }
            return
        }

        // Build context from last few messages
        let context = recentMessages.suffix(5).map { msg in
            String(msg.content.prefix(300))
        }.joined(separator: "\n")

        // Limit file list to avoid huge prompts
        let fileList = availableFiles.prefix(100).joined(separator: "\n")

        let prompt = """
        Based on this conversation, which files would be most relevant to reference next?

        Conversation:
        \(context)

        Available files:
        \(fileList)

        Return ONLY a JSON array of 3-5 file paths (strings) that are most relevant.
        Example: ["src/app.ts", "tests/app.test.ts", "package.json"]

        Respond with ONLY the JSON array, no other text.
        """

        await MainActor.run { isLoading = true }

        do {
            let response = try await sendQuickQuery(prompt: prompt, projectPath: projectPath, sessionId: sessionId)
            let files = parseFileList(from: response, availableFiles: availableFiles)
            await MainActor.run {
                suggestedFiles = files
                isLoading = false
            }
        } catch {
            log.error("Failed to suggest files: \(error)")
            await MainActor.run {
                suggestedFiles = []
                isLoading = false
            }
        }
    }

    /// Parse JSON response into file list, filtering to only available files
    func parseFileList(from response: String, availableFiles: [String]) -> [String] {
        guard let jsonStart = response.firstIndex(of: "["),
              let jsonEnd = response.lastIndex(of: "]") else {
            return []
        }

        let jsonString = String(response[jsonStart...jsonEnd])

        guard let data = jsonString.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }

        // Filter to only files that actually exist in availableFiles
        let availableSet = Set(availableFiles)
        return decoded.filter { file in
            availableSet.contains(file) || availableFiles.contains { $0.hasSuffix(file) }
        }.prefix(5).map { $0 }
    }

    func clearFileSuggestions() {
        suggestedFiles = []
    }

    // MARK: - Idea Enhancement

    /// Result of AI-enhanced idea
    struct EnhancedIdea {
        let expandedPrompt: String
        let suggestedFollowups: [String]
    }

    /// Enhance an idea into a detailed prompt using Sonnet for higher quality
    func enhanceIdea(_ ideaText: String, projectPath: String, sessionId: String? = nil) async {
        await MainActor.run {
            isEnhancingIdea = true
            enhancedIdea = nil
        }

        let prompt = """
        You are helping a developer expand a quick idea into an actionable prompt for Claude Code.

        IDEA: \(ideaText)

        Return ONLY a JSON object with this exact structure:
        {
            "expandedPrompt": "A detailed, actionable prompt (2-3 paragraphs) that Claude Code can execute. Be specific about what to build, test cases, edge cases, and success criteria.",
            "suggestedFollowups": ["3 related ideas or next steps the developer might want to explore after this"]
        }

        Make the expanded prompt specific and actionable. Include concrete steps, considerations, and acceptance criteria.
        Respond with ONLY the JSON object, no other text.
        """

        do {
            // Use Sonnet model for higher quality expansions
            // Pass session ID to reuse existing session instead of creating new ones
            let response = try await sendQuickQuery(prompt: prompt, projectPath: projectPath, model: .sonnet, sessionId: sessionId)
            let enhanced = parseEnhancedIdea(from: response)
            await MainActor.run {
                enhancedIdea = enhanced
                isEnhancingIdea = false
            }
        } catch {
            log.error("Failed to enhance idea: \(error)")
            await MainActor.run {
                isEnhancingIdea = false
            }
        }
    }

    /// Parse the enhanced idea JSON response
    func parseEnhancedIdea(from response: String) -> EnhancedIdea? {
        // Try to find JSON object in response
        guard let jsonStart = response.firstIndex(of: "{"),
              let jsonEnd = response.lastIndex(of: "}") else {
            log.warning("No JSON object found in enhancement response")
            return nil
        }

        let jsonString = String(response[jsonStart...jsonEnd])

        guard let data = jsonString.data(using: .utf8) else {
            return nil
        }

        do {
            let decoded = try JSONDecoder().decode(EnhancedIdeaJSON.self, from: data)
            return EnhancedIdea(
                expandedPrompt: decoded.expandedPrompt,
                suggestedFollowups: decoded.suggestedFollowups
            )
        } catch {
            log.error("Failed to decode enhanced idea JSON: \(error)")
            return nil
        }
    }

    private struct EnhancedIdeaJSON: Codable {
        let expandedPrompt: String
        let suggestedFollowups: [String]
    }

    func clearEnhancedIdea() {
        enhancedIdea = nil
    }

    // MARK: - Message Analysis

    /// Analyze a message and generate follow-up suggestions
    /// This uses Haiku for fast, cheap analysis
    func analyzeMessage(
        _ message: ChatMessage,
        recentMessages: [ChatMessage],
        projectPath: String,
        sessionId: String? = nil
    ) async {
        // Build context from the message and a few recent messages
        let context = recentMessages.suffix(3).map { msg -> String in
            let role = msg.role == .user ? "User" : "Assistant"
            return "\(role): \(String(msg.content.prefix(200)))"
        }.joined(separator: "\n")

        let messageToAnalyze = String(message.content.prefix(1000))

        let prompt = """
        Analyze this Claude Code response and suggest 3 helpful follow-up actions.

        Recent context:
        \(context)

        Response to analyze:
        \(messageToAnalyze)

        Return ONLY a JSON array with exactly 3 objects, each with:
        - "label": 3-5 word action description
        - "prompt": the full message to send to Claude
        - "icon": SF Symbol name (like "play.circle", "doc.text", "checkmark.circle")

        Focus on practical next steps: testing, fixing issues, expanding functionality, or documentation.

        Respond with ONLY the JSON array, no other text.
        """

        await MainActor.run {
            isLoading = true
            suggestedActions = []
        }

        do {
            let response = try await sendQuickQuery(prompt: prompt, projectPath: projectPath, sessionId: sessionId)
            let actions = parseSuggestedActions(from: response)
            await MainActor.run {
                suggestedActions = actions
                isLoading = false
            }
        } catch {
            log.error("Failed to analyze message: \(error)")
            await MainActor.run {
                suggestedActions = analyzeDefaultSuggestions()
                isLoading = false
            }
        }
    }

    /// Default suggestions for analysis when AI fails
    private func analyzeDefaultSuggestions() -> [SuggestedAction] {
        [
            SuggestedAction(label: "Run tests", prompt: "Run the test suite and show any failures", icon: "play.circle"),
            SuggestedAction(label: "Explain more", prompt: "Explain what you just did in more detail", icon: "questionmark.circle"),
            SuggestedAction(label: "Improve this", prompt: "How can we improve this implementation?", icon: "arrow.up.circle")
        ]
    }

    // MARK: - WebSocket Communication

    /// Send a quick query, defaults to Haiku for speed but can use other models
    /// - Parameters:
    ///   - prompt: The query prompt
    ///   - projectPath: The project path for context
    ///   - model: The model to use (default: .haiku). Uses full model ID for backend compatibility.
    ///   - sessionId: Optional session ID to use. If nil, uses a helper session ID.
    private func sendQuickQuery(prompt: String, projectPath: String, model: ClaudeModel = .haiku, sessionId: String? = nil) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            sendQueryViaWebSocket(prompt: prompt, projectPath: projectPath, model: model, sessionId: sessionId) { result in
                continuation.resume(with: result)
            }
        }
    }

    private func sendQueryViaWebSocket(prompt: String, projectPath: String, model: ClaudeModel = .haiku, sessionId: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = settings.webSocketURL else {
            completion(.failure(ClaudeHelperError.invalidURL))
            return
        }

        // Clean up any existing connection
        if webSocket != nil {
            debugLog.log("ClaudeHelper: Cancelling existing WebSocket", type: .info)
        }
        webSocket?.cancel()
        responseBuffer = ""
        self.completion = completion

        // Use provided session ID if available.
        // If nil, let the backend create a new session (don't use helperSessionId
        // as it may reference a non-existent session causing CLI errors).
        let effectiveSessionId = sessionId

        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()

        debugLog.logConnection("ClaudeHelper connecting to \(url.host ?? "unknown")")

        // Start receiving messages
        receiveMessage()

        // Send the query with specified model and session ID
        let command = WSClaudeCommand(
            command: prompt,
            options: WSCommandOptions(
                cwd: projectPath,
                sessionId: effectiveSessionId,
                model: model.modelId,  // Full model ID (e.g., "claude-sonnet-4-5-20250929")
                permissionMode: nil,
                images: nil
            )
        )

        debugLog.log("ClaudeHelper sending query (model: \(model.modelId ?? "default"))", type: .info)

        do {
            let data = try JSONEncoder().encode(command)
            if let jsonString = String(data: data, encoding: .utf8) {
                debugLog.logSent("ClaudeHelper sending: \(jsonString)")
                webSocket?.send(.string(jsonString)) { [weak self] error in
                    if let error = error {
                        Task { @MainActor [weak self] in
                            self?.completion?(.failure(error))
                            self?.cleanup()
                        }
                    }
                }
            }
        } catch {
            completion(.failure(error))
            cleanup()
        }

        // Set timeout - store task so it can be cancelled on success
        // 30 second timeout to allow for model switching which can take time
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000_000)  // 30 second timeout
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard let self = self, self.completion != nil else { return }
                self.debugLog.logError("ClaudeHelper timeout after 30s - buffer so far: \(self.responseBuffer.prefix(200))")
                self.completion?(.failure(ClaudeHelperError.timeout))
                self.cleanup()
            }
        }
    }

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let message):
                    self?.handleMessage(message)
                    self?.receiveMessage()  // Continue listening

                case .failure(let error):
                    self?.debugLog.logError("ClaudeHelper receive error: \(error.localizedDescription)")
                    self?.completion?(.failure(error))
                    self?.cleanup()
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            parseMessage(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                parseMessage(text)
            }
        @unknown default:
            break
        }
    }

    private func parseMessage(_ text: String) {
        debugLog.log("ClaudeHelper received message: \(text.prefix(200))...", type: .received)

        guard let data = text.data(using: .utf8),
              let msg = try? JSONDecoder().decode(WSMessage.self, from: data) else {
            debugLog.logError("ClaudeHelper: Failed to decode message")
            return
        }

        debugLog.log("ClaudeHelper message type: \(msg.type)", type: .received)

        switch msg.type {
        case "claude-response":
            // Extract text from response - SDK sends different formats:
            // 1. {type: "assistant", message: {role: "assistant", content: [...]}}
            // 2. {content: [...]} - direct content
            // 3. {message: {content: [...]}} - nested message
            guard let responseData = msg.data?.dictValue else { break }

            let outerType = responseData["type"] as? String
            debugLog.log("ClaudeHelper response outer type: \(outerType ?? "nil")", type: .received)

            // Case 1: Outer type is "assistant" with nested message.content
            if outerType == "assistant",
               let messageData = responseData["message"] as? [String: Any],
               let content = messageData["content"] as? [[String: Any]] {
                extractTextFromContent(content)
            }
            // Case 2: Direct content array at top level
            else if let content = responseData["content"] as? [[String: Any]] {
                extractTextFromContent(content)
            }
            // Case 3: Content nested in message (without outer type)
            else if let messageData = responseData["message"] as? [String: Any],
                    let content = messageData["content"] as? [[String: Any]] {
                extractTextFromContent(content)
            }

        case "claude-complete":
            debugLog.log("ClaudeHelper complete, buffer length: \(responseBuffer.count)", type: .received)
            completion?(.success(responseBuffer))
            cleanup()

        case "claude-error":
            let errorMsg = msg.error ?? "Unknown error"
            debugLog.logError("ClaudeHelper server error: \(errorMsg)")
            completion?(.failure(ClaudeHelperError.serverError(errorMsg)))
            cleanup()

        default:
            break
        }
    }

    private func extractTextFromContent(_ content: [[String: Any]]) {
        for part in content {
            if let partText = part["text"] as? String {
                responseBuffer += partText
            }
        }
    }

    private func cleanup() {
        timeoutTask?.cancel()
        timeoutTask = nil
        webSocket?.cancel()
        webSocket = nil
        completion = nil
        responseBuffer = ""
    }
}

// MARK: - Errors

enum ClaudeHelperError: Error, LocalizedError {
    case invalidURL
    case timeout
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .timeout: return "Request timed out"
        case .serverError(let msg): return msg
        }
    }
}
