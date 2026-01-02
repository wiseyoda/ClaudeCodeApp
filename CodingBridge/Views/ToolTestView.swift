import SwiftUI

#if DEBUG
/// Test harness for tool message rendering
/// Loads test fixtures from JSON and displays each message type for visual verification
struct ToolTestView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) var dismiss

    @State private var testFixtures: ToolTestFixtures?
    @State private var selectedCategory: String?
    @State private var loadError: String?
    @State private var simulatedMessages: [ChatMessage] = []
    @State private var currentAgentState: CLIAgentState = .idle
    @State private var currentTool: String?

    var body: some View {
        NavigationStack {
            Group {
                if let error = loadError {
                    errorView(error)
                } else if let fixtures = testFixtures {
                    fixturesList(fixtures)
                } else {
                    loadingView
                }
            }
            .navigationTitle("Tool Test Harness")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        clearSimulation()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(simulatedMessages.isEmpty && currentAgentState == .idle)
                }
            }
            .background(CLITheme.background(for: colorScheme))
        }
        .task {
            await loadFixtures()
        }
    }

    // MARK: - Views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading test fixtures...")
                .font(.subheadline)
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
        }
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("Failed to load fixtures")
                .font(.headline)
            Text(error)
                .font(.caption)
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private func fixturesList(_ fixtures: ToolTestFixtures) -> some View {
        List {
            // Simulated Chat Section
            if !simulatedMessages.isEmpty || currentAgentState != .idle {
                Section("Simulated Chat") {
                    VStack(alignment: .leading, spacing: 8) {
                        // Status bubble when agent is working
                        if currentAgentState != .idle && currentAgentState != .stopped {
                            StatusBubbleView(
                                state: currentAgentState,
                                tool: currentTool
                            )
                            .padding(.vertical, 4)
                        }

                        // Messages - use groupMessagesForDisplay for proper rendering
                        let displayItems = groupMessagesForDisplay(simulatedMessages)
                        ForEach(displayItems) { item in
                            DisplayItemView(
                                item: item,
                                projectPath: nil,
                                projectTitle: nil
                            )
                            .padding(.vertical, 2)
                        }
                    }
                    .listRowBackground(CLITheme.secondaryBackground(for: colorScheme))
                }
            }

            // Categories
            ForEach(categories(from: fixtures), id: \.self) { category in
                Section(category) {
                    ForEach(fixtures.messages.filter { $0.category == category }) { fixture in
                        Button {
                            simulateMessage(fixture)
                        } label: {
                            fixtureRow(fixture)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func fixtureRow(_ fixture: ToolTestFixture) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(fixture.description)
                    .font(.subheadline)
                    .foregroundColor(CLITheme.primaryText(for: colorScheme))

                Text(fixture.id)
                    .font(.caption)
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
            }

            Spacer()

            Image(systemName: "play.circle.fill")
                .font(.title2)
                .foregroundColor(CLITheme.blue(for: colorScheme))
        }
        .padding(.vertical, 4)
    }

    // MARK: - Data Loading

    private func loadFixtures() async {
        // Try loading from bundle
        guard let url = Bundle.main.url(forResource: "ToolTestMessages", withExtension: "json") else {
            loadError = "ToolTestMessages.json not found in bundle.\n\nMake sure the file is added to the Xcode project."
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let fixtures = try JSONDecoder().decode(ToolTestFixtures.self, from: data)
            self.testFixtures = fixtures
        } catch {
            loadError = "Failed to decode: \(error.localizedDescription)"
        }
    }

    private func categories(from fixtures: ToolTestFixtures) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for fixture in fixtures.messages {
            if !seen.contains(fixture.category) {
                seen.insert(fixture.category)
                result.append(fixture.category)
            }
        }
        return result
    }

    // MARK: - Simulation

    private func simulateMessage(_ fixture: ToolTestFixture) {
        let message = fixture.message

        // Handle different message types
        if let streamMessage = message["message"] as? [String: Any],
           let type = streamMessage["type"] as? String {

            switch type {
            case "state":
                handleStateMessage(streamMessage)

            case "assistant":
                if let delta = streamMessage["delta"] as? Bool, !delta,
                   let content = streamMessage["content"] as? String {
                    appendAssistantMessage(content)
                }

            case "tool_use":
                handleToolUse(streamMessage, fixtureId: fixture.id)

            case "tool_result":
                handleToolResult(streamMessage)

            case "usage":
                // Could update a usage display
                break

            case "system":
                if let content = streamMessage["content"] as? String,
                   let subtype = streamMessage["subtype"] as? String {
                    if subtype == "init" {
                        appendSystemMessage("Session initialized")
                    }
                    // Skip result subtype
                    _ = content  // Silence warning
                }

            default:
                break
            }
        } else if let type = message["type"] as? String {
            // Top-level messages (connected, etc.)
            if type == "connected" {
                appendSystemMessage("Connected to agent")
            }
        }
    }

    private func handleStateMessage(_ message: [String: Any]) {
        guard let state = message["state"] as? String else { return }

        currentTool = message["tool"] as? String

        switch state {
        case "thinking":
            currentAgentState = .thinking
        case "executing":
            currentAgentState = .executing
        case "idle":
            currentAgentState = .idle
            currentTool = nil
        default:
            break
        }
    }

    private func appendAssistantMessage(_ content: String) {
        let message = ChatMessage(
            role: .assistant,
            content: content,
            timestamp: Date()
        )
        simulatedMessages.append(message)
    }

    private func appendSystemMessage(_ content: String) {
        let message = ChatMessage(
            role: .system,
            content: content,
            timestamp: Date()
        )
        simulatedMessages.append(message)
    }

    private func handleToolUse(_ message: [String: Any], fixtureId: String? = nil) {
        guard let name = message["name"] as? String,
              let input = message["input"] as? [String: Any] else { return }

        // Create tool use message in the format expected by ToolParser: ToolName({"key":"value"})
        let jsonContent = formatInputAsJSON(input)
        let chatMessage = ChatMessage(
            role: .toolUse,
            content: "\(name)(\(jsonContent))",
            timestamp: Date()
        )
        simulatedMessages.append(chatMessage)

        // Auto-add corresponding tool result if available
        if let fixtureId = fixtureId,
           fixtureId.hasPrefix("tool-use-"),
           let fixtures = testFixtures {
            let resultId = fixtureId.replacingOccurrences(of: "tool-use-", with: "tool-result-")
            if let resultFixture = fixtures.messages.first(where: { $0.id == resultId }),
               let streamMsg = resultFixture.message["message"] as? [String: Any] {
                // Add a small delay effect by using a slightly later timestamp
                handleToolResult(streamMsg)
            }
        }
    }

    /// Convert input dictionary to JSON string for tool content
    private func formatInputAsJSON(_ input: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: input, options: []),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return jsonString
    }

    private func handleToolResult(_ message: [String: Any]) {
        guard let output = message["output"] as? String else { return }

        let isError = message["isError"] as? Bool ?? false

        // Create result message - use raw output (no markdown formatting)
        let chatMessage = ChatMessage(
            role: isError ? .error : .toolResult,
            content: output,
            timestamp: Date()
        )
        simulatedMessages.append(chatMessage)
    }


    private func clearSimulation() {
        simulatedMessages = []
        currentAgentState = .idle
        currentTool = nil
    }
}

// MARK: - Test Fixture Models

struct ToolTestFixtures: Codable {
    let description: String
    let messages: [ToolTestFixture]
}

struct ToolTestFixture: Codable, Identifiable {
    let id: String
    let category: String
    let description: String
    let message: [String: Any]

    enum CodingKeys: String, CodingKey {
        case id, category, description, message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        category = try container.decode(String.self, forKey: .category)
        description = try container.decode(String.self, forKey: .description)

        // Decode message as generic JSON
        let messageData = try container.decode(LocalJSONValue.self, forKey: .message)
        message = messageData.toDictionary() ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(category, forKey: .category)
        try container.encode(description, forKey: .description)
        try container.encode(LocalJSONValue.from(message), forKey: .message)
    }
}

/// Helper for decoding arbitrary JSON
enum LocalJSONValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([LocalJSONValue])
    case object([String: LocalJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode([LocalJSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: LocalJSONValue].self) {
            self = .object(value)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    func toDictionary() -> [String: Any]? {
        guard case .object(let dict) = self else { return nil }
        var result: [String: Any] = [:]
        for (key, value) in dict {
            result[key] = value.toAny()
        }
        return result
    }

    func toAny() -> Any {
        switch self {
        case .string(let v): return v
        case .int(let v): return v
        case .double(let v): return v
        case .bool(let v): return v
        case .null: return NSNull()
        case .array(let arr): return arr.map { $0.toAny() }
        case .object(let dict):
            var result: [String: Any] = [:]
            for (k, v) in dict {
                result[k] = v.toAny()
            }
            return result
        }
    }

    static func from(_ any: Any) -> LocalJSONValue {
        switch any {
        case let s as String: return .string(s)
        case let i as Int: return .int(i)
        case let d as Double: return .double(d)
        case let b as Bool: return .bool(b)
        case let arr as [Any]: return .array(arr.map { from($0) })
        case let dict as [String: Any]:
            var result: [String: LocalJSONValue] = [:]
            for (k, v) in dict {
                result[k] = from(v)
            }
            return .object(result)
        default: return .null
        }
    }
}

#Preview {
    ToolTestView()
        .environmentObject(AppSettings())
        .preferredColorScheme(.dark)
}
#endif
