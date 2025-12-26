import SwiftUI
import UIKit
import PhotosUI

struct ChatView: View {
    let project: Project
    let apiClient: APIClient
    @EnvironmentObject var settings: AppSettings
    @StateObject private var wsManager: WebSocketManager
    @StateObject private var sshManager = SSHManager()  // For image uploads
    @Environment(\.scenePhase) private var scenePhase

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var selectedImage: Data?
    @State private var processingStartTime: Date?
    @State private var selectedSession: ProjectSession?
    @State private var isUploadingImage = false
    @FocusState private var isInputFocused: Bool

    init(project: Project, apiClient: APIClient) {
        self.project = project
        self.apiClient = apiClient
        // Initialize WebSocketManager with settings from apiClient
        let settings = AppSettings()
        _wsManager = StateObject(wrappedValue: WebSocketManager(settings: settings))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Session picker if project has sessions
            if let sessions = project.sessions, !sessions.isEmpty {
                SessionPicker(sessions: sessions, selected: $selectedSession) { session in
                    // Load session
                    wsManager.sessionId = session.id
                    messages = []
                    if let lastMsg = session.lastAssistantMessage {
                        messages.append(ChatMessage(role: .assistant, content: lastMsg, timestamp: Date()))
                    }
                }
            }

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(messages) { message in
                            CLIMessageView(message: message)
                                .id(message.id)
                        }

                        // Streaming indicator
                        if wsManager.isProcessing {
                            if wsManager.currentText.isEmpty {
                                CLIProcessingView()
                                    .id("streaming")
                            } else {
                                CLIMessageView(message: ChatMessage(
                                    role: .assistant,
                                    content: wsManager.currentText,
                                    timestamp: Date(),
                                    isStreaming: true
                                ))
                                .id("streaming")
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .background(CLITheme.background)
                .onChange(of: messages.count) { _, _ in
                    // Delay to ensure view has rendered
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            if let lastId = messages.last?.id {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }
                .onChange(of: wsManager.currentText) { _, _ in
                    withAnimation {
                        proxy.scrollTo("streaming", anchor: .bottom)
                    }
                }
                .onChange(of: wsManager.isProcessing) { _, isProcessing in
                    // Scroll when processing starts or ends
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            if isProcessing {
                                proxy.scrollTo("streaming", anchor: .bottom)
                            } else if let lastId = messages.last?.id {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            // Status bar
            CLIStatusBar(
                isProcessing: wsManager.isProcessing,
                isUploadingImage: isUploadingImage,
                startTime: processingStartTime,
                tokenUsage: wsManager.tokenUsage
            )

            // Terminal input - use id to maintain focus stability during re-renders
            CLIInputView(
                text: $inputText,
                selectedImage: $selectedImage,
                isProcessing: wsManager.isProcessing,
                isFocused: _isInputFocused,
                onSend: sendMessage
            )
            .id("input-view")

            // Mode selector
            CLIModeSelector()
        }
        .background(CLITheme.background)
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(CLITheme.secondaryBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        messages = []
                        wsManager.sessionId = nil
                        selectedSession = nil
                        MessageStore.clearMessages(for: project.path)
                    } label: {
                        Label("New Chat", systemImage: "plus")
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
                        .foregroundColor(CLITheme.secondaryText)
                }
            }
        }
        .onAppear {
            // Update WebSocketManager with actual EnvironmentObject settings
            wsManager.updateSettings(settings)
            setupWebSocketCallbacks()
            wsManager.connect()

            // Load persisted messages
            let savedMessages = MessageStore.loadMessages(for: project.path)
            if !savedMessages.isEmpty {
                messages = savedMessages
            }

            // Load draft input
            let savedDraft = MessageStore.loadDraft(for: project.path)
            if !savedDraft.isEmpty {
                inputText = savedDraft
            }
        }
        .onDisappear {
            wsManager.disconnect()
            // Save messages when leaving
            MessageStore.saveMessages(messages, for: project.path)
        }
        .onChange(of: messages) { _, newMessages in
            // Save messages whenever they change (debounced by iOS)
            MessageStore.saveMessages(newMessages, for: project.path)
        }
        .onChange(of: inputText) { _, newText in
            // Auto-save draft input
            MessageStore.saveDraft(newText, for: project.path)
        }
        .onChange(of: wsManager.isProcessing) { _, isProcessing in
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
    }

    private func setupWebSocketCallbacks() {
        wsManager.onText = { text in
            // Text is accumulated in wsManager.currentText
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
            let resultMsg = ChatMessage(
                role: .toolResult,
                content: String(result.prefix(500)) + (result.count > 500 ? "..." : ""),
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
            // Add final assistant message
            if !wsManager.currentText.isEmpty {
                let assistantMessage = ChatMessage(
                    role: .assistant,
                    content: wsManager.currentText,
                    timestamp: Date()
                )
                messages.append(assistantMessage)
            }
            processingStartTime = nil
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
            // Session created notification
            let systemMsg = ChatMessage(
                role: .system,
                content: "Session: \(sessionId.prefix(8))...",
                timestamp: Date()
            )
            messages.append(systemMsg)
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || selectedImage != nil else { return }

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

        // If we have an image, upload it via SFTP first
        if let imageData = imageToSend {
            isUploadingImage = true
            Task {
                do {
                    let remotePath = try await uploadImageViaSSH(imageData)
                    // Include the file path in the message for Claude to read
                    let messageWithPath = text.isEmpty
                        ? "Please look at this image: \(remotePath)"
                        : "\(text)\n\n[Image uploaded to: \(remotePath)]"

                    await MainActor.run {
                        isUploadingImage = false
                        wsManager.sendMessage(
                            messageWithPath,
                            projectPath: project.path,
                            resumeSessionId: selectedSession?.id,
                            permissionMode: settings.claudeMode.serverValue
                        )
                    }
                } catch {
                    await MainActor.run {
                        isUploadingImage = false
                        // Show error but still send the text-only message
                        let errorMsg = ChatMessage(
                            role: .error,
                            content: "Image upload failed: \(error.localizedDescription). Sending text only."
                        )
                        messages.append(errorMsg)

                        if !text.isEmpty {
                            wsManager.sendMessage(
                                text,
                                projectPath: project.path,
                                resumeSessionId: selectedSession?.id,
                                permissionMode: settings.claudeMode.serverValue
                            )
                        }
                    }
                }
            }
        } else {
            // No image, send text directly
            wsManager.sendMessage(
                text,
                projectPath: project.path,
                resumeSessionId: selectedSession?.id,
                permissionMode: settings.claudeMode.serverValue
            )
        }
    }

    /// Upload image via SSH/SFTP and return the remote file path
    private func uploadImageViaSSH(_ imageData: Data) async throws -> String {
        // Connect to SSH if not already connected
        if !sshManager.isConnected {
            // Try SSH config hosts first, then fall back to settings
            if let configHost = sshManager.availableHosts.first(where: {
                $0.hostName == settings.effectiveSSHHost || $0.host.contains("claude")
            }) {
                try await sshManager.connectWithConfigHost(configHost.host)
            } else if settings.sshAuthType == .publicKey {
                // Use key auth with default key
                try await sshManager.connectWithKey(
                    host: settings.effectiveSSHHost,
                    port: settings.sshPort,
                    username: settings.sshUsername.isEmpty ? NSUserName() : settings.sshUsername,
                    privateKeyPath: NSHomeDirectory() + "/.ssh/id_ed25519"
                )
            } else {
                // Use password auth
                try await sshManager.connect(
                    host: settings.effectiveSSHHost,
                    port: settings.sshPort,
                    username: settings.sshUsername,
                    password: settings.sshPassword
                )
            }
        }

        // Upload the image
        return try await sshManager.uploadImage(imageData)
    }
}

// MARK: - Session Picker

struct SessionPicker: View {
    let sessions: [ProjectSession]
    @Binding var selected: ProjectSession?
    let onSelect: (ProjectSession) -> Void
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    selected = nil
                } label: {
                    Text("New")
                        .font(settings.scaledFont(.small))
                        .foregroundColor(selected == nil ? CLITheme.background : CLITheme.cyan)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selected == nil ? CLITheme.cyan : CLITheme.secondaryBackground)
                        .cornerRadius(4)
                }

                ForEach(sessions.prefix(5)) { session in
                    Button {
                        selected = session
                        onSelect(session)
                    } label: {
                        Text(session.summary ?? "Session")
                            .font(settings.scaledFont(.small))
                            .foregroundColor(selected?.id == session.id ? CLITheme.background : CLITheme.primaryText)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selected?.id == session.id ? CLITheme.cyan : CLITheme.secondaryBackground)
                            .cornerRadius(4)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(CLITheme.background)
    }
}

// MARK: - CLI Message View

struct CLIMessageView: View {
    let message: ChatMessage
    @State private var isExpanded: Bool
    @EnvironmentObject var settings: AppSettings

    init(message: ChatMessage) {
        self.message = message
        // Collapse result messages, Grep/Glob tool uses, and thinking blocks by default
        let shouldStartCollapsed = message.role == .resultSuccess ||
            message.role == .toolResult ||
            message.role == .thinking ||
            (message.role == .toolUse && (message.content.hasPrefix("Grep") || message.content.hasPrefix("Glob")))
        self._isExpanded = State(initialValue: !shouldStartCollapsed)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Header line with bullet
            HStack(spacing: 6) {
                Text(bulletChar)
                    .foregroundColor(bulletColor)
                    .font(settings.scaledFont(.body))

                Text(headerText)
                    .foregroundColor(headerColor)
                    .font(settings.scaledFont(.body))

                if isCollapsible {
                    Text(isExpanded ? "[-]" : "[+]")
                        .foregroundColor(CLITheme.mutedText)
                        .font(settings.scaledFont(.small))
                }

                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if isCollapsible {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                }
            }

            // Content
            if isExpanded || !isCollapsible {
                contentView
                    .padding(.leading, 16)
            }
        }
        .padding(.vertical, 4)
    }

    private var bulletChar: String {
        switch message.role {
        case .user: return ">"
        case .assistant: return " "
        case .system: return "*"
        case .error: return "!"
        case .toolUse: return "*"
        case .toolResult: return "└"
        case .resultSuccess: return "*"
        case .thinking: return "💭"
        }
    }

    private var bulletColor: Color {
        switch message.role {
        case .user: return CLITheme.blue
        case .assistant: return CLITheme.primaryText
        case .system: return CLITheme.cyan
        case .error: return CLITheme.red
        case .toolUse: return CLITheme.green
        case .toolResult: return CLITheme.mutedText
        case .resultSuccess: return CLITheme.green
        case .thinking: return CLITheme.purple
        }
    }

    private var headerText: String {
        switch message.role {
        case .user: return message.content
        case .assistant: return ""
        case .system: return "System (init)"
        case .error: return "Error"
        case .toolUse:
            // Show just tool name in header (e.g., "Grep" from "Grep(pattern: ...)")
            if let parenIndex = message.content.firstIndex(of: "(") {
                return String(message.content[..<parenIndex])
            }
            return message.content
        case .toolResult: return "Result"
        case .resultSuccess: return "Done"
        case .thinking: return "Thinking"
        }
    }

    private var headerColor: Color {
        switch message.role {
        case .user: return CLITheme.blue
        case .assistant: return CLITheme.primaryText
        case .system: return CLITheme.cyan
        case .error: return CLITheme.red
        case .toolUse: return CLITheme.yellow
        case .toolResult: return CLITheme.mutedText
        case .resultSuccess: return CLITheme.green
        case .thinking: return CLITheme.purple
        }
    }

    private var isCollapsible: Bool {
        switch message.role {
        case .system, .toolUse, .toolResult, .resultSuccess, .thinking: return true
        default: return false
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch message.role {
        case .user:
            // Show image if attached
            if let imageData = message.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 200, maxHeight: 150)
                    .cornerRadius(8)
            }
        case .assistant:
            MarkdownText(message.content)
                .textSelection(.enabled)
        case .system, .resultSuccess:
            Text(message.content)
                .font(settings.scaledFont(.small))
                .foregroundColor(CLITheme.secondaryText)
                .textSelection(.enabled)
        case .error:
            Text(message.content)
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.red)
                .textSelection(.enabled)
        case .toolUse:
            // Show diff view for Edit tool, otherwise show raw content
            if message.content.hasPrefix("Edit"),
               let parsed = DiffView.parseEditContent(message.content) {
                DiffView(oldString: parsed.old, newString: parsed.new)
            } else {
                Text(message.content)
                    .font(settings.scaledFont(.small))
                    .foregroundColor(CLITheme.secondaryText)
                    .textSelection(.enabled)
            }
        case .toolResult:
            Text(message.content)
                .font(settings.scaledFont(.small))
                .foregroundColor(CLITheme.secondaryText)
                .lineLimit(isExpanded ? nil : 3)
                .textSelection(.enabled)
        case .thinking:
            Text(message.content)
                .font(settings.scaledFont(.small))
                .foregroundColor(CLITheme.purple.opacity(0.8))
                .italic()
                .textSelection(.enabled)
        }
    }
}

// MARK: - Diff View for Edit Tool

struct DiffView: View {
    let oldString: String
    let newString: String
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Removed section
            if !oldString.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("- Removed:")
                        .font(settings.scaledFont(.small))
                        .foregroundColor(CLITheme.red)
                    Text(oldString)
                        .font(settings.scaledFont(.small))
                        .foregroundColor(CLITheme.diffRemovedText)
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(CLITheme.diffRemoved)
                        .cornerRadius(4)
                }
            }

            // Added section
            if !newString.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("+ Added:")
                        .font(settings.scaledFont(.small))
                        .foregroundColor(CLITheme.green)
                    Text(newString)
                        .font(settings.scaledFont(.small))
                        .foregroundColor(CLITheme.diffAddedText)
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(CLITheme.diffAdded)
                        .cornerRadius(4)
                }
            }
        }
    }

    /// Parse old_string and new_string from Edit tool content
    static func parseEditContent(_ content: String) -> (old: String, new: String)? {
        // Content format: "Edit(file_path: /path, old_string: ..., new_string: ...)"
        // We need to extract old_string and new_string

        // Simple parsing - look for old_string: and new_string:
        guard content.hasPrefix("Edit") else { return nil }

        var oldString = ""
        var newString = ""

        // Extract old_string value
        if let oldRange = content.range(of: "old_string: ") {
            let afterOld = content[oldRange.upperBound...]
            // Find the end - either ", new_string:" or end of content
            if let endRange = afterOld.range(of: ", new_string: ") {
                oldString = String(afterOld[..<endRange.lowerBound])
            }
        }

        // Extract new_string value
        if let newRange = content.range(of: "new_string: ") {
            let afterNew = content[newRange.upperBound...]
            // Find the end - either ")" or ", replace_all:"
            if let endRange = afterNew.range(of: ", replace_all:") {
                newString = String(afterNew[..<endRange.lowerBound])
            } else if let endRange = afterNew.range(of: ")") {
                newString = String(afterNew[..<endRange.lowerBound])
            } else {
                newString = String(afterNew)
            }
        }

        if oldString.isEmpty && newString.isEmpty {
            return nil
        }

        return (oldString, newString)
    }
}

// MARK: - CLI Processing View

struct CLIProcessingView: View {
    @State private var dotCount = 0
    @EnvironmentObject var settings: AppSettings
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 6) {
            Text("+")
                .foregroundColor(CLITheme.yellow)
            Text("Thinking" + String(repeating: ".", count: dotCount))
                .foregroundColor(CLITheme.yellow)
            Spacer()
        }
        .font(settings.scaledFont(.body))
        .onReceive(timer) { _ in
            dotCount = (dotCount + 1) % 4
        }
    }
}

// MARK: - CLI Status Bar

struct CLIStatusBar: View {
    let isProcessing: Bool
    let isUploadingImage: Bool
    let startTime: Date?
    let tokenUsage: WebSocketManager.TokenUsage?
    @EnvironmentObject var settings: AppSettings

    @State private var elapsedTime: String = "0s"
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 12) {
            if isUploadingImage {
                HStack(spacing: 4) {
                    Circle()
                        .fill(CLITheme.cyan)
                        .frame(width: 6, height: 6)
                    Text("uploading image")
                        .foregroundColor(CLITheme.cyan)
                }
            } else if isProcessing {
                HStack(spacing: 4) {
                    Circle()
                        .fill(CLITheme.yellow)
                        .frame(width: 6, height: 6)
                    Text("processing")
                        .foregroundColor(CLITheme.yellow)
                }
            } else {
                HStack(spacing: 4) {
                    Circle()
                        .fill(CLITheme.green)
                        .frame(width: 6, height: 6)
                    Text("ready")
                        .foregroundColor(CLITheme.green)
                }
            }

            Spacer()

            // Context usage from WebSocket (only show if actually received from server)
            if let usage = tokenUsage {
                let percentage = Double(usage.used) / Double(usage.total) * 100
                let color = percentage > 80 ? CLITheme.red : (percentage > 60 ? CLITheme.yellow : CLITheme.mutedText)
                Text("\(formatTokens(usage.used))/\(formatTokens(usage.total))")
                    .foregroundColor(color)
            }

            if isProcessing {
                Text(elapsedTime)
                    .foregroundColor(CLITheme.mutedText)
            }
        }
        .font(settings.scaledFont(.small))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(CLITheme.secondaryBackground)
        .onReceive(timer) { _ in
            if let start = startTime {
                let elapsed = Int(Date().timeIntervalSince(start))
                if elapsed < 60 {
                    elapsedTime = "\(elapsed)s"
                } else {
                    elapsedTime = "\(elapsed / 60)m \(elapsed % 60)s"
                }
            }
        }
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000.0)
        }
        return "\(count)"
    }
}

// MARK: - CLI Input View

struct CLIInputView: View {
    @Binding var text: String
    @Binding var selectedImage: Data?
    let isProcessing: Bool
    @FocusState var isFocused: Bool
    let onSend: () -> Void
    @EnvironmentObject var settings: AppSettings
    @StateObject private var speechManager = SpeechManager()
    @State private var showImagePicker = false
    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 0) {
            // Recording indicator
            if speechManager.isRecording {
                HStack(spacing: 8) {
                    Circle()
                        .fill(CLITheme.red)
                        .frame(width: 8, height: 8)
                    Text("Recording...")
                        .font(settings.scaledFont(.small))
                        .foregroundColor(CLITheme.red)
                    if !speechManager.transcribedText.isEmpty {
                        Text(speechManager.transcribedText)
                            .font(settings.scaledFont(.small))
                            .foregroundColor(CLITheme.secondaryText)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(CLITheme.secondaryBackground)
            }

            // Image preview
            if let imageData = selectedImage, let uiImage = UIImage(data: imageData) {
                HStack {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 100)
                        .cornerRadius(8)

                    Button {
                        selectedImage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(CLITheme.red)
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(CLITheme.secondaryBackground)
            }

            HStack(spacing: 8) {
                Text(">")
                    .foregroundColor(CLITheme.green)
                    .font(settings.scaledFont(.body))

                TextField("Type a message...", text: $text)
                    .font(settings.scaledFont(.body))
                    .foregroundColor(CLITheme.primaryText)
                    .focused($isFocused)
                    .disabled(isProcessing)
                    .submitLabel(.send)
                    .onSubmit { onSend() }

                // Image picker button
                if !isProcessing {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Image(systemName: "photo")
                            .foregroundColor(selectedImage != nil ? CLITheme.blue : CLITheme.mutedText)
                    }
                    .onChange(of: selectedItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                selectedImage = data
                            }
                        }
                    }
                }

                // Microphone button
                if !isProcessing {
                    Button {
                        if speechManager.isRecording {
                            speechManager.stopRecording()
                            // Append transcribed text to input
                            if !speechManager.transcribedText.isEmpty {
                                if text.isEmpty {
                                    text = speechManager.transcribedText
                                } else {
                                    text += " " + speechManager.transcribedText
                                }
                            }
                        } else {
                            speechManager.startRecording()
                        }
                    } label: {
                        Image(systemName: speechManager.isRecording ? "stop.circle.fill" : "mic.fill")
                            .foregroundColor(speechManager.isRecording ? CLITheme.red : CLITheme.mutedText)
                    }
                }

                if (!text.isEmpty || selectedImage != nil) && !isProcessing {
                    Button(action: onSend) {
                        Image(systemName: "return")
                            .foregroundColor(CLITheme.green)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(CLITheme.background)
        }
    }
}

// MARK: - CLI Mode Selector

struct CLIModeSelector: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                settings.claudeMode = settings.claudeMode.next()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: settings.claudeMode.icon)
                    .font(.system(size: 12))
                Text(settings.claudeMode.displayName)
                    .font(settings.scaledFont(.small))
                Text("- Tap to cycle")
                    .font(settings.scaledFont(.small))
                    .foregroundColor(CLITheme.mutedText)
            }
            .foregroundColor(settings.claudeMode.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CLITheme.secondaryBackground)
    }
}

// MARK: - Code Block with Copy Button

struct CodeBlockView: View {
    let code: String
    let language: String?
    let settings: AppSettings

    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header with language and copy button
            HStack {
                if let lang = language, !lang.isEmpty {
                    Text(lang)
                        .font(settings.scaledFont(.small))
                        .foregroundColor(CLITheme.mutedText)
                }
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                    showCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showCopied = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        Text(showCopied ? "Copied!" : "Copy")
                    }
                    .font(settings.scaledFont(.small))
                    .foregroundColor(showCopied ? CLITheme.green : CLITheme.mutedText)
                }
                .buttonStyle(.plain)
            }

            // Code content
            Text(code)
                .font(settings.scaledFont(.small))
                .foregroundColor(CLITheme.cyan)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CLITheme.secondaryBackground)
                .cornerRadius(6)
        }
    }
}

// MARK: - Markdown Text View

struct MarkdownText: View {
    let content: String
    @EnvironmentObject var settings: AppSettings

    init(_ content: String) {
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                blockView(for: block)
            }
        }
    }

    private enum Block {
        case paragraph(String)
        case header(String, Int) // content, level (1-6)
        case codeBlock(String, String?) // content, language
        case bulletList([String])
        case numberedList([String])
        case table([[String]]) // rows of cells
        case horizontalRule
    }

    private func parseBlocks() -> [Block] {
        var blocks: [Block] = []
        let lines = content.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // Code block
            if line.hasPrefix("```") {
                let language = String(line.dropFirst(3))
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                blocks.append(.codeBlock(codeLines.joined(separator: "\n"), language.isEmpty ? nil : language))
                i += 1
                continue
            }

            // Horizontal rule (---, ***, ___)
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine == "---" || trimmedLine == "***" || trimmedLine == "___" {
                blocks.append(.horizontalRule)
                i += 1
                continue
            }

            // Headers
            if line.hasPrefix("#") {
                let headerMatch = line.prefix(while: { $0 == "#" })
                let level = min(headerMatch.count, 6)
                let headerText = String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                if !headerText.isEmpty {
                    blocks.append(.header(headerText, level))
                }
                i += 1
                continue
            }

            // Table (detect by | at start and |---)
            if line.contains("|") && !line.trimmingCharacters(in: .whitespaces).isEmpty {
                var tableLines: [String] = []
                while i < lines.count && lines[i].contains("|") {
                    let tableLine = lines[i].trimmingCharacters(in: .whitespaces)
                    // Skip separator lines like |---|---|
                    if !tableLine.contains("---") {
                        tableLines.append(tableLine)
                    }
                    i += 1
                }
                if !tableLines.isEmpty {
                    let rows = tableLines.map { row -> [String] in
                        row.split(separator: "|", omittingEmptySubsequences: false)
                            .map { String($0).trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                    }
                    blocks.append(.table(rows))
                }
                continue
            }

            // Numbered list
            if line.range(of: #"^\d+\.\s+"#, options: .regularExpression) != nil {
                var items: [String] = []
                while i < lines.count {
                    if lines[i].range(of: #"^\d+\.\s+"#, options: .regularExpression) != nil {
                        let itemText = lines[i].replacingOccurrences(of: #"^\d+\.\s+"#, with: "", options: .regularExpression)
                        items.append(itemText)
                        i += 1
                    } else {
                        break
                    }
                }
                blocks.append(.numberedList(items))
                continue
            }

            // Bullet list
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                var items: [String] = []
                while i < lines.count && (lines[i].hasPrefix("- ") || lines[i].hasPrefix("* ")) {
                    items.append(String(lines[i].dropFirst(2)))
                    i += 1
                }
                blocks.append(.bulletList(items))
                continue
            }

            // Regular paragraph
            if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                blocks.append(.paragraph(line))
            }
            i += 1
        }

        return blocks
    }

    @ViewBuilder
    private func blockView(for block: Block) -> some View {
        switch block {
        case .paragraph(let text):
            renderInlineMarkdown(text)
        case .header(let text, let level):
            headerView(text: text, level: level)
        case .codeBlock(let code, let language):
            CodeBlockView(code: code, language: language, settings: settings)
        case .bulletList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(settings.scaledFont(.body))
                            .foregroundColor(CLITheme.green)
                        renderInlineMarkdown(item)
                    }
                }
            }
        case .numberedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(settings.scaledFont(.body))
                            .foregroundColor(CLITheme.yellow)
                            .frame(minWidth: 20, alignment: .trailing)
                        renderInlineMarkdown(item)
                    }
                }
            }
        case .table(let rows):
            tableView(rows: rows)
        case .horizontalRule:
            Rectangle()
                .fill(CLITheme.mutedText.opacity(0.4))
                .frame(height: 1)
                .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func headerView(text: String, level: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            renderStyledText(text, style: headerStyle(for: level))

            // Underline for H1 and H2
            if level <= 2 {
                Rectangle()
                    .fill(level == 1 ? CLITheme.cyan : CLITheme.cyan.opacity(0.5))
                    .frame(height: level == 1 ? 2 : 1)
            }
        }
        .padding(.top, headerTopPadding(for: level))
        .padding(.bottom, 4)
    }

    private func headerStyle(for level: Int) -> TextStyle {
        switch level {
        case 1: return TextStyle(font: .title2, color: CLITheme.cyan, weight: .bold)
        case 2: return TextStyle(font: .title3, color: CLITheme.cyan, weight: .semibold)
        case 3: return TextStyle(font: .headline, color: CLITheme.primaryText, weight: .semibold)
        default: return TextStyle(font: .subheadline, color: CLITheme.primaryText, weight: .medium)
        }
    }

    private func headerTopPadding(for level: Int) -> CGFloat {
        switch level {
        case 1: return 16
        case 2: return 12
        case 3: return 8
        default: return 4
        }
    }

    private struct TextStyle {
        let font: Font.TextStyle
        let color: Color
        let weight: Font.Weight
    }

    @ViewBuilder
    private func renderStyledText(_ text: String, style: TextStyle) -> some View {
        // Parse bold and inline code within the text
        let attributed = parseInlineFormatting(text)
        Text(attributed)
            .font(.system(style.font, design: .default, weight: style.weight))
            .foregroundColor(style.color)
    }

    /// Parse inline markdown (bold, italic, code) into AttributedString
    private func parseInlineFormatting(_ text: String) -> AttributedString {
        var result = AttributedString()
        var remaining = text[...]
        let fontSize = UIFont.preferredFont(forTextStyle: .body).pointSize

        while !remaining.isEmpty {
            // Find the earliest formatting marker
            var earliestRange: Range<Substring.Index>?
            var markerType: String?

            // Check for bold **
            if let boldRange = remaining.range(of: "**") {
                if earliestRange == nil || boldRange.lowerBound < earliestRange!.lowerBound {
                    earliestRange = boldRange
                    markerType = "bold"
                }
            }

            // Check for inline code `
            if let codeRange = remaining.range(of: "`") {
                if earliestRange == nil || codeRange.lowerBound < earliestRange!.lowerBound {
                    earliestRange = codeRange
                    markerType = "code"
                }
            }

            guard let range = earliestRange, let type = markerType else {
                // No more formatting, add the rest
                result.append(AttributedString(String(remaining)))
                break
            }

            // Add text before the marker
            let beforeMarker = String(remaining[..<range.lowerBound])
            if !beforeMarker.isEmpty {
                result.append(AttributedString(beforeMarker))
            }

            // Process the formatted text
            let afterMarker = remaining[range.upperBound...]

            switch type {
            case "bold":
                // Find closing **
                if let closeRange = afterMarker.range(of: "**") {
                    let boldText = String(afterMarker[..<closeRange.lowerBound])
                    var boldAttr = AttributedString(boldText)
                    boldAttr.font = .boldSystemFont(ofSize: fontSize)
                    result.append(boldAttr)
                    remaining = afterMarker[closeRange.upperBound...]
                } else {
                    // No closing marker, treat as literal
                    result.append(AttributedString("**"))
                    remaining = afterMarker
                }

            case "code":
                // Find closing `
                if let closeRange = afterMarker.range(of: "`") {
                    let codeText = String(afterMarker[..<closeRange.lowerBound])
                    var codeAttr = AttributedString(codeText)
                    codeAttr.font = .monospacedSystemFont(ofSize: fontSize - 1, weight: .regular)
                    codeAttr.foregroundColor = CLITheme.cyan
                    result.append(codeAttr)
                    remaining = afterMarker[closeRange.upperBound...]
                } else {
                    // No closing marker, treat as literal
                    result.append(AttributedString("`"))
                    remaining = afterMarker
                }

            default:
                remaining = afterMarker
            }
        }

        return result
    }

    @ViewBuilder
    private func tableView(rows: [[String]]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        Text(cell)
                            .font(settings.scaledFont(.small))
                            .foregroundColor(rowIndex == 0 ? CLITheme.cyan : CLITheme.primaryText)
                            .fontWeight(rowIndex == 0 ? .semibold : .regular)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(rowIndex == 0 ? CLITheme.secondaryBackground : Color.clear)
                    }
                }
                if rowIndex == 0 {
                    Rectangle()
                        .fill(CLITheme.mutedText.opacity(0.3))
                        .frame(height: 1)
                }
            }
        }
        .background(CLITheme.background)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(CLITheme.mutedText.opacity(0.3), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func renderInlineMarkdown(_ text: String) -> some View {
        let attributed = parseInlineFormatting(text)
        Text(attributed)
            .font(settings.scaledFont(.body))
            .foregroundColor(CLITheme.primaryText)
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
