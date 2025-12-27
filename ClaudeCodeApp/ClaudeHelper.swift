import Foundation

/// ClaudeHelper provides AI-powered suggestions using fast Haiku calls.
/// This is a "meta-AI" layer that uses Claude to enhance the user experience.
@MainActor
class ClaudeHelper: ObservableObject {
    private var settings: AppSettings
    private var webSocket: URLSessionWebSocketTask?
    private var responseBuffer = ""
    private var completion: ((Result<String, Error>) -> Void)?

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
    func generateSuggestions(
        recentMessages: [ChatMessage],
        projectPath: String
    ) async {
        // Only use last 3-5 messages for context (keep it cheap)
        let context = recentMessages.suffix(5)
        guard !context.isEmpty else {
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
            let response = try await sendQuickQuery(prompt: prompt, projectPath: projectPath)
            let actions = parseSuggestedActions(from: response)
            await MainActor.run {
                suggestedActions = actions
                isLoading = false
            }
        } catch {
            log.error("Failed to generate suggestions: \(error)")
            await MainActor.run {
                suggestedActions = defaultSuggestions()
                isLoading = false
            }
        }
    }

    /// Parse JSON response into SuggestedAction array
    private func parseSuggestedActions(from response: String) -> [SuggestedAction] {
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
        projectPath: String
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
            let response = try await sendQuickQuery(prompt: prompt, projectPath: projectPath)
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
    private func parseFileList(from response: String, availableFiles: [String]) -> [String] {
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
    func enhanceIdea(_ ideaText: String, projectPath: String) async {
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
            let response = try await sendQuickQuery(prompt: prompt, projectPath: projectPath, model: "sonnet")
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
    private func parseEnhancedIdea(from response: String) -> EnhancedIdea? {
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

    // MARK: - WebSocket Communication

    /// Send a quick query, defaults to Haiku for speed but can use other models
    private func sendQuickQuery(prompt: String, projectPath: String, model: String = "haiku") async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            sendQueryViaWebSocket(prompt: prompt, projectPath: projectPath, model: model) { result in
                continuation.resume(with: result)
            }
        }
    }

    private func sendQueryViaWebSocket(prompt: String, projectPath: String, model: String = "haiku", completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = settings.webSocketURL else {
            completion(.failure(ClaudeHelperError.invalidURL))
            return
        }

        // Clean up any existing connection
        webSocket?.cancel()
        responseBuffer = ""
        self.completion = completion

        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()

        // Start receiving messages
        receiveMessage()

        // Send the query with specified model
        let command = WSClaudeCommand(
            command: prompt,
            options: WSCommandOptions(
                cwd: projectPath,
                sessionId: nil,
                model: model,  // Use specified model (haiku for suggestions, sonnet for enhancement)
                permissionMode: nil,
                images: nil
            )
        )

        do {
            let data = try JSONEncoder().encode(command)
            if let jsonString = String(data: data, encoding: .utf8) {
                webSocket?.send(.string(jsonString)) { [weak self] error in
                    if let error = error {
                        self?.completion?(.failure(error))
                        self?.cleanup()
                    }
                }
            }
        } catch {
            completion(.failure(error))
            cleanup()
        }

        // Set timeout
        Task {
            try? await Task.sleep(nanoseconds: 15_000_000_000)  // 15 second timeout
            await MainActor.run {
                if self.completion != nil {
                    self.completion?(.failure(ClaudeHelperError.timeout))
                    self.cleanup()
                }
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
        guard let data = text.data(using: .utf8),
              let msg = try? JSONDecoder().decode(WSMessage.self, from: data) else {
            return
        }

        switch msg.type {
        case "claude-response":
            // Extract text from response
            if let responseData = msg.data?.dictValue,
               let content = responseData["content"] as? [[String: Any]] {
                for part in content {
                    if let partText = part["text"] as? String {
                        responseBuffer += partText
                    }
                }
            } else if let responseData = msg.data?.dictValue,
                      let messageData = responseData["message"] as? [String: Any],
                      let content = messageData["content"] as? [[String: Any]] {
                for part in content {
                    if let partText = part["text"] as? String {
                        responseBuffer += partText
                    }
                }
            }

        case "claude-complete":
            completion?(.success(responseBuffer))
            cleanup()

        case "claude-error":
            let errorMsg = msg.error ?? "Unknown error"
            completion?(.failure(ClaudeHelperError.serverError(errorMsg)))
            cleanup()

        default:
            break
        }
    }

    private func cleanup() {
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
