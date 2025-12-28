import SwiftUI
import PhotosUI

// MARK: - CLI Input View
// iOS 26+: TextEditor supports AttributedString for rich text
// Consider migrating to TextEditor with AttributedString binding for:
// - Syntax highlighting of code blocks
// - Styled @mentions and file references
// - Rich formatting in prompts

struct CLIInputView: View {
    @Binding var text: String
    @Binding var selectedImage: Data?
    let isProcessing: Bool
    let isAborting: Bool
    let projectPath: String?
    @FocusState var isFocused: Bool
    let onSend: () -> Void
    let onAbort: () -> Void
    var recentMessages: [ChatMessage]
    var claudeHelper: ClaudeHelper?

    // Ideas FAB properties
    var ideaCount: Int
    var onIdeasTap: () -> Void
    var onIdeasLongPress: () -> Void

    // Session ID for AI file suggestions (avoids creating orphan sessions)
    var sessionId: String?

    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var speechManager = SpeechManager()
    @ObservedObject private var commandStore = CommandStore.shared
    @State private var showAttachmentMenu = false
    @State private var showFilePicker = false
    @State private var showCommandPicker = false
    @State private var showPhotoPicker = false
    @State private var selectedItem: PhotosPickerItem?

    init(
        text: Binding<String>,
        selectedImage: Binding<Data?>,
        isProcessing: Bool,
        isAborting: Bool = false,
        projectPath: String?,
        isFocused: FocusState<Bool>,
        onSend: @escaping () -> Void,
        onAbort: @escaping () -> Void,
        recentMessages: [ChatMessage] = [],
        claudeHelper: ClaudeHelper? = nil,
        ideaCount: Int = 0,
        onIdeasTap: @escaping () -> Void = {},
        onIdeasLongPress: @escaping () -> Void = {},
        sessionId: String? = nil
    ) {
        self._text = text
        self._selectedImage = selectedImage
        self.isProcessing = isProcessing
        self.isAborting = isAborting
        self.projectPath = projectPath
        self._isFocused = isFocused
        self.onSend = onSend
        self.onAbort = onAbort
        self.recentMessages = recentMessages
        self.claudeHelper = claudeHelper
        self.ideaCount = ideaCount
        self.onIdeasTap = onIdeasTap
        self.onIdeasLongPress = onIdeasLongPress
        self.sessionId = sessionId
    }

    var body: some View {
        VStack(spacing: 0) {
            // Recording indicator
            if speechManager.isRecording {
                recordingIndicator
            }

            // Image preview
            if let imageData = selectedImage, let uiImage = UIImage(data: imageData) {
                imagePreview(uiImage)
            }

            // Main input row
            HStack(alignment: .bottom, spacing: 8) {
                // [+] Attachment menu button
                if !isProcessing {
                    attachmentMenuButton
                }

                // Multi-line text input with iOS 26+ glass-ready styling
                TextField("Type a message...", text: $text, axis: .vertical)
                    .font(settings.scaledFont(.body))
                    .foregroundColor(CLITheme.primaryText(for: colorScheme))
                    .focused($isFocused)
                    .disabled(isProcessing)
                    .lineLimit(1...8)
                    .textFieldStyle(.plain)
                    .submitLabel(.send)
                    .onSubmit {
                        if !isProcessing && (!text.isEmpty || selectedImage != nil) {
                            onSend()
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .glassBackground(cornerRadius: 20)

                // Send button
                sendButton
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(CLITheme.background(for: colorScheme))
        }
        // iPad keyboard shortcuts
        .background(keyboardShortcuts)
        .sheet(isPresented: $showFilePicker) {
            if let projectPath = projectPath {
                FilePickerSheet(
                    projectPath: projectPath,
                    recentMessages: recentMessages,
                    claudeHelper: claudeHelper,
                    sessionId: sessionId
                ) { selectedPath in
                    insertFileReference(selectedPath)
                }
            }
        }
        .sheet(isPresented: $showCommandPicker) {
            CommandPickerSheet(
                commandStore: commandStore,
                onSelect: { command in
                    insertCommandContent(command.content)
                }
            )
        }
    }

    // MARK: - Subviews

    private var recordingIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(CLITheme.red(for: colorScheme))
                .frame(width: 8, height: 8)
            Text("Recording...")
                .font(settings.scaledFont(.small))
                .foregroundColor(CLITheme.red(for: colorScheme))
            if !speechManager.transcribedText.isEmpty {
                Text(speechManager.transcribedText)
                    .font(settings.scaledFont(.small))
                    .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                    .lineLimit(1)
            }
            Spacer()
            Button("Done") {
                finishRecording()
            }
            .font(settings.scaledFont(.small))
            .foregroundColor(CLITheme.blue(for: colorScheme))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        // iOS 26+: Glass background with error tint for recording state
        .glassBackground(tint: .error, cornerRadius: 0)
    }

    private func imagePreview(_ uiImage: UIImage) -> some View {
        HStack {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 80)
                .cornerRadius(8)

            Button {
                selectedImage = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
            }
            .accessibilityLabel("Remove image")

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(CLITheme.secondaryBackground(for: colorScheme))
    }

    private var attachmentMenuButton: some View {
        Menu {
            // Saved Commands
            if !commandStore.commands.isEmpty {
                Button {
                    showCommandPicker = true
                } label: {
                    Label("Saved Commands", systemImage: "text.book.closed")
                }
            }

            // File reference
            if projectPath != nil {
                Button {
                    showFilePicker = true
                } label: {
                    Label("Reference File", systemImage: "at")
                }
            }

            // Photo picker - use Button to trigger separate PhotosPicker
            // PhotosPicker inside Menu doesn't work properly on iPhone
            Button {
                showPhotoPicker = true
            } label: {
                Label("Attach Image", systemImage: "photo")
            }

            // Voice input
            Button {
                if speechManager.isRecording {
                    finishRecording()
                } else {
                    speechManager.startRecording()
                }
            } label: {
                Label(
                    speechManager.isRecording ? "Stop Recording" : "Voice Input",
                    systemImage: speechManager.isRecording ? "stop.circle" : "mic"
                )
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(CLITheme.blue(for: colorScheme))
        }
        .accessibilityLabel("Add attachment")
        // PhotosPicker must be outside Menu to work on iPhone
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        selectedImage = data
                    }
                }
            }
        }
    }

    private var sendButton: some View {
        Group {
            if isAborting {
                // Aborting state - show spinner
                ProgressView()
                    .frame(width: 28, height: 28)
                    .accessibilityLabel("Aborting")
            } else if isProcessing {
                // Abort button when processing
                Button(action: onAbort) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(CLITheme.red(for: colorScheme))
                }
                .accessibilityLabel("Stop")
                .accessibilityHint("Double tap to stop the current task")
            } else if !text.isEmpty || selectedImage != nil {
                // Send button when there's content
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(CLITheme.green(for: colorScheme))
                }
                .accessibilityLabel("Send")
            } else {
                // Microphone button when empty
                Button {
                    speechManager.startRecording()
                } label: {
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(CLITheme.mutedText(for: colorScheme))
                }
                .accessibilityLabel("Voice input")
            }
        }
    }

    private var keyboardShortcuts: some View {
        Group {
            // Cmd+Return to send
            Button("") {
                if !isProcessing && (!text.isEmpty || selectedImage != nil) {
                    onSend()
                }
            }
            .keyboardShortcut(.return, modifiers: .command)
            .opacity(0)

            // Escape to abort
            Button("") {
                if isProcessing {
                    onAbort()
                }
            }
            .keyboardShortcut(.escape, modifiers: [])
            .opacity(0)
        }
    }

    // MARK: - Actions

    private func finishRecording() {
        speechManager.stopRecording()
        if !speechManager.transcribedText.isEmpty {
            if text.isEmpty {
                text = speechManager.transcribedText
            } else {
                text += " " + speechManager.transcribedText
            }
        }
        // Refocus input field after recording completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isFocused = true
        }
    }

    private func insertFileReference(_ path: String) {
        let reference = "@\(path)"
        if text.isEmpty {
            text = reference + " "
        } else if text.hasSuffix(" ") {
            text += reference + " "
        } else {
            text += " " + reference + " "
        }
    }

    private func insertCommandContent(_ content: String) {
        // Replace entire text with command content
        text = content
    }
}
