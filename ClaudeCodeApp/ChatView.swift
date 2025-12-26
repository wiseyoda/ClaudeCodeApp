import SwiftUI

struct ChatView: View {
    let project: Project
    let apiClient: APIClient

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var sessionId: String?
    @State private var isProcessing = false
    @State private var currentStreamingText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        // Streaming indicator
                        if isProcessing && !currentStreamingText.isEmpty {
                            MessageBubble(message: ChatMessage(
                                role: .assistant,
                                content: currentStreamingText,
                                timestamp: Date(),
                                isStreaming: true
                            ))
                            .id("streaming")
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo(messages.last?.id ?? "streaming", anchor: .bottom)
                    }
                }
                .onChange(of: currentStreamingText) { _, _ in
                    withAnimation {
                        proxy.scrollTo("streaming", anchor: .bottom)
                    }
                }
            }

            Divider()

            // Input area
            HStack(spacing: 12) {
                TextField("Message Claude...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .disabled(isProcessing)

                Button {
                    Task { await sendMessage() }
                } label: {
                    Image(systemName: isProcessing ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(isProcessing ? .red : (inputText.isEmpty ? .gray : .blue))
                }
                .disabled(inputText.isEmpty && !isProcessing)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        messages = []
                        sessionId = nil
                    } label: {
                        Label("New Chat", systemImage: "plus.bubble")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Add user message
        let userMessage = ChatMessage(role: .user, content: text, timestamp: Date())
        messages.append(userMessage)

        inputText = ""
        isProcessing = true
        currentStreamingText = ""

        do {
            let newSessionId = try await apiClient.sendMessage(
                text,
                project: project,
                sessionId: sessionId
            ) { event in
                DispatchQueue.main.async {
                    switch event {
                    case .text(let fullText):
                        currentStreamingText = fullText
                    case .toolUse(let name, let input):
                        let toolMsg = ChatMessage(
                            role: .toolUse,
                            content: "Using: \(name)\n\(input)",
                            timestamp: Date()
                        )
                        messages.append(toolMsg)
                    case .toolResult(let result):
                        let resultMsg = ChatMessage(
                            role: .toolResult,
                            content: result.prefix(500) + (result.count > 500 ? "..." : ""),
                            timestamp: Date()
                        )
                        messages.append(resultMsg)
                    case .complete:
                        break
                    }
                }
            }

            // Add final assistant message
            if !currentStreamingText.isEmpty {
                let assistantMessage = ChatMessage(
                    role: .assistant,
                    content: currentStreamingText,
                    timestamp: Date()
                )
                messages.append(assistantMessage)
            }

            sessionId = newSessionId
            currentStreamingText = ""

        } catch {
            let errorMessage = ChatMessage(
                role: .error,
                content: "Error: \(error.localizedDescription)",
                timestamp: Date()
            )
            messages.append(errorMessage)
        }

        isProcessing = false
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // Role label
                if message.role != .user {
                    HStack(spacing: 4) {
                        Image(systemName: iconName)
                            .font(.caption)
                        Text(roleLabel)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }

                // Content
                Text(message.content)
                    .padding(12)
                    .background(backgroundColor)
                    .foregroundColor(textColor)
                    .cornerRadius(16)
                    .textSelection(.enabled)

                // Streaming indicator
                if message.isStreaming {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Thinking...")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
            }

            if message.role != .user {
                Spacer(minLength: 60)
            }
        }
    }

    private var backgroundColor: Color {
        switch message.role {
        case .user: return .blue
        case .assistant: return Color(.systemGray5)
        case .system: return Color(.systemGray6)
        case .error: return .red.opacity(0.2)
        case .toolUse: return .orange.opacity(0.2)
        case .toolResult: return .green.opacity(0.1)
        }
    }

    private var textColor: Color {
        switch message.role {
        case .user: return .white
        case .error: return .red
        default: return .primary
        }
    }

    private var iconName: String {
        switch message.role {
        case .user: return "person.fill"
        case .assistant: return "sparkles"
        case .system: return "info.circle"
        case .error: return "exclamationmark.triangle"
        case .toolUse: return "wrench.and.screwdriver"
        case .toolResult: return "checkmark.circle"
        }
    }

    private var roleLabel: String {
        switch message.role {
        case .user: return "You"
        case .assistant: return "Claude"
        case .system: return "System"
        case .error: return "Error"
        case .toolUse: return "Tool"
        case .toolResult: return "Result"
        }
    }
}

#Preview {
    NavigationStack {
        ChatView(
            project: Project(path: "/test/project", encodedName: "test"),
            apiClient: APIClient(settings: AppSettings())
        )
    }
}
