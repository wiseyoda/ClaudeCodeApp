import Foundation

class APIClient: ObservableObject {
    private let settings: AppSettings
    @Published var isLoading = false

    init(settings: AppSettings) {
        self.settings = settings
    }

    // MARK: - Projects

    func fetchProjects() async throws -> [Project] {
        guard let url = settings.baseURL?.appendingPathComponent("api/projects") else {
            throw APIError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }

        let projectsResponse = try JSONDecoder().decode(ProjectsResponse.self, from: data)
        return projectsResponse.projects
    }

    // MARK: - Chat Streaming

    func sendMessage(
        _ message: String,
        project: Project,
        sessionId: String?,
        onEvent: @escaping (StreamEvent) -> Void
    ) async throws -> String? {
        guard let url = settings.baseURL?.appendingPathComponent("api/chat") else {
            throw APIError.invalidURL
        }

        let requestId = UUID().uuidString

        let chatRequest = ChatRequest(
            message: message,
            sessionId: sessionId,
            requestId: requestId,
            workingDirectory: project.path,
            allowedTools: nil
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(chatRequest)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("[API] No HTTP response")
            throw APIError.serverError
        }

        print("[API] Response status: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            print("[API] Non-200 status: \(httpResponse.statusCode)")
            throw APIError.serverError
        }

        var newSessionId: String?
        var currentText = ""
        var lineCount = 0

        for try await line in bytes.lines {
            lineCount += 1
            print("[API] Line \(lineCount): \(line.prefix(200))")
            guard !line.isEmpty else { continue }

            // Parse JSON line
            guard let data = line.data(using: .utf8) else { continue }

            do {
                let streamLine = try JSONDecoder().decode(StreamLine.self, from: data)

                // Handle "done" message
                if streamLine.type == "done" {
                    onEvent(.complete)
                    continue
                }

                // Unwrap the inner event data
                guard let event = streamLine.data else { continue }

                // Extract session ID and emit system init info
                if event.type == "system", event.subtype == "init" {
                    if let sid = event.session_id {
                        newSessionId = sid
                    }
                    let toolCount = event.tools?.count ?? 0
                    let shortSession = event.session_id.map { String($0.prefix(8)) }
                    onEvent(.systemInit(
                        model: event.model,
                        session: shortSession,
                        tools: toolCount,
                        cwd: event.cwd
                    ))
                }

                // Handle assistant messages
                if event.type == "assistant", let message = event.message {
                    if let contents = message.content {
                        for content in contents {
                            if content.type == "text", let text = content.text {
                                currentText += text
                                onEvent(.text(currentText))
                            } else if content.type == "tool_use", let name = content.name {
                                let inputStr = content.input?.map { "\($0.key): \($0.value.stringValue)" }.joined(separator: ", ") ?? ""
                                onEvent(.toolUse(name: name, input: inputStr))
                            }
                        }
                    }
                }

                // Handle tool results
                if event.type == "user", let message = event.message {
                    if let contents = message.content {
                        for content in contents {
                            if content.type == "tool_result", let text = content.text {
                                onEvent(.toolResult(text))
                            }
                        }
                    }
                }

                // Handle result/completion with result text
                if event.type == "result" {
                    if let resultText = event.result, currentText.isEmpty {
                        currentText = resultText
                        onEvent(.text(currentText))
                    }
                    // Emit result info
                    let success = event.subtype == "success"
                    onEvent(.resultInfo(
                        success: success,
                        durationMs: event.duration_ms,
                        cost: event.cost,
                        inputTokens: event.input_tokens,
                        outputTokens: event.output_tokens
                    ))
                    onEvent(.complete)
                }

            } catch {
                // Show raw line for debugging
                print("[API] JSON parse error for line: \(line.prefix(200))")
                onEvent(.debug("RAW: \(line)"))
                continue
            }
        }

        print("[API] Stream complete. Total lines: \(lineCount), text length: \(currentText.count)")
        return newSessionId ?? sessionId
    }

    // MARK: - Abort

    func abortRequest(_ requestId: String) async throws {
        guard let url = settings.baseURL?.appendingPathComponent("api/abort/\(requestId)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        _ = try await URLSession.shared.data(for: request)
    }
}

// MARK: - Types

enum StreamEvent {
    case text(String)
    case toolUse(name: String, input: String)
    case toolResult(String)
    case complete
    case debug(String)  // For debugging raw responses
    case systemInit(model: String?, session: String?, tools: Int, cwd: String?)
    case resultInfo(success: Bool, durationMs: Int?, cost: Double?, inputTokens: Int?, outputTokens: Int?)
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case serverError
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .serverError: return "Server error"
        case .decodingError: return "Failed to decode response"
        }
    }
}
