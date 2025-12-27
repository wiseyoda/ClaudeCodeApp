import SwiftUI
import PhotosUI

// MARK: - CLI Input View

struct CLIInputView: View {
    @Binding var text: String
    @Binding var selectedImage: Data?
    let isProcessing: Bool
    let projectPath: String?
    @FocusState var isFocused: Bool
    let onSend: () -> Void
    let onAbort: () -> Void
    var recentMessages: [ChatMessage]
    var claudeHelper: ClaudeHelper?
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var speechManager = SpeechManager()
    @ObservedObject private var commandStore = CommandStore.shared
    @State private var showAttachmentMenu = false
    @State private var showFilePicker = false
    @State private var showCommandPicker = false
    @State private var selectedItem: PhotosPickerItem?

    init(
        text: Binding<String>,
        selectedImage: Binding<Data?>,
        isProcessing: Bool,
        projectPath: String?,
        isFocused: FocusState<Bool>,
        onSend: @escaping () -> Void,
        onAbort: @escaping () -> Void,
        recentMessages: [ChatMessage] = [],
        claudeHelper: ClaudeHelper? = nil
    ) {
        self._text = text
        self._selectedImage = selectedImage
        self.isProcessing = isProcessing
        self.projectPath = projectPath
        self._isFocused = isFocused
        self.onSend = onSend
        self.onAbort = onAbort
        self.recentMessages = recentMessages
        self.claudeHelper = claudeHelper
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

                // Multi-line text input
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
                    .background(CLITheme.secondaryBackground(for: colorScheme))
                    .cornerRadius(20)

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
                    claudeHelper: claudeHelper
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
        .background(CLITheme.secondaryBackground(for: colorScheme))
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

            // Photo picker
            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label("Attach Image", systemImage: "photo")
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        selectedImage = data
                    }
                }
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
    }

    private var sendButton: some View {
        Group {
            if isProcessing {
                // Abort button when processing
                Button(action: onAbort) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(CLITheme.red(for: colorScheme))
                }
                .accessibilityLabel("Stop")
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
