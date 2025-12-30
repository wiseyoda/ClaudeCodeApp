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
    @Binding var selectedImages: [ImageAttachment]
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
    @State private var selectedItems: [PhotosPickerItem] = []

    init(
        text: Binding<String>,
        selectedImages: Binding<[ImageAttachment]>,
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
        self._selectedImages = selectedImages
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

            // Image previews (multiple)
            if !selectedImages.isEmpty {
                imagePreviewStrip
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
                        if !isProcessing && (!text.isEmpty || !selectedImages.isEmpty) {
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
                .fill(.white)
                .frame(width: 8, height: 8)
            Text("Recording...")
                .font(settings.scaledFont(.small))
                .foregroundColor(.white)
            if !speechManager.transcribedText.isEmpty {
                Text(speechManager.transcribedText)
                    .font(settings.scaledFont(.small))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
            }
            Spacer()
            Button("Done") {
                finishRecording()
            }
            .font(settings.scaledFont(.small))
            .fontWeight(.semibold)
            .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        // iOS 26+: Glass background with error tint for recording state
        .glassBackground(tint: .error, cornerRadius: 0)
    }

    private var imagePreviewStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(selectedImages) { attachment in
                    ZStack(alignment: .topTrailing) {
                        if let uiImage = attachment.displayImage {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        // Upload progress overlay
                        if case .uploading(let progress) = attachment.uploadState {
                            ZStack {
                                Color.black.opacity(0.5)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                ProgressView(value: progress)
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            }
                            .frame(width: 60, height: 60)
                        }

                        // Remove button
                        Button {
                            removeImage(attachment.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                        }
                        .offset(x: 4, y: -4)
                        .accessibilityLabel("Remove image")
                    }
                }

                // Add more button (if under limit)
                if selectedImages.count < ImageAttachment.maxImagesPerMessage && !isProcessing {
                    Button {
                        showPhotoPicker = true
                    } label: {
                        VStack {
                            Image(systemName: "plus")
                                .font(.system(size: 20))
                                .foregroundColor(CLITheme.blue(for: colorScheme))
                        }
                        .frame(width: 60, height: 60)
                        .background(CLITheme.secondaryBackground(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .accessibilityLabel("Add another image")
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 70)
        .padding(.vertical, 6)
        .background(CLITheme.secondaryBackground(for: colorScheme))
    }

    private func removeImage(_ id: UUID) {
        selectedImages.removeAll { $0.id == id }
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
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedItems,
            maxSelectionCount: ImageAttachment.maxImagesPerMessage - selectedImages.count,
            matching: .images
        )
        .onChange(of: selectedItems) { _, newItems in
            Task {
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            // Avoid duplicates and respect limit
                            if selectedImages.count < ImageAttachment.maxImagesPerMessage {
                                let attachment = ImageAttachment(data: data)
                                selectedImages.append(attachment)
                            }
                        }
                    }
                }
                // Clear selection for next time
                await MainActor.run {
                    selectedItems = []
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
            } else if !text.isEmpty || !selectedImages.isEmpty {
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
                if !isProcessing && (!text.isEmpty || !selectedImages.isEmpty) {
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
