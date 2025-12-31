import SwiftUI
import PhotosUI

// MARK: - CLI Input View
// iOS 26+: TextEditor with AttributedString for rich text input
// Features:
// - Syntax highlighting via AttributedString styles
// - Automatic Markdown detection and styling
// - Native rich text formatting keyboard shortcuts

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

    // Ideas FAB properties
    var ideaCount: Int
    var onIdeasTap: () -> Void
    var onIdeasLongPress: () -> Void

    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var speechManager = SpeechManager()
    @State private var showAttachmentMenu = false
    @State private var showFilePicker = false
    @State private var showCommandPicker = false
    @State private var showPhotoPicker = false
    @State private var selectedItems: [PhotosPickerItem] = []

    /// Rich text content using iOS 26's AttributedString support
    /// Synced bidirectionally with the plain text binding for compatibility
    @State private var richText: AttributedString = AttributedString()

    /// Selection state for AttributedString text editing (iOS 26+)
    @State private var textSelection = AttributedTextSelection()

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
        ideaCount: Int = 0,
        onIdeasTap: @escaping () -> Void = {},
        onIdeasLongPress: @escaping () -> Void = {}
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
        self.ideaCount = ideaCount
        self.onIdeasTap = onIdeasTap
        self.onIdeasLongPress = onIdeasLongPress
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
            HStack(alignment: .center, spacing: 8) {
                // [+] Attachment menu button
                if !isProcessing {
                    attachmentMenuButton
                }

                // iOS 26+ Rich text input with AttributedString support
                // Enables Markdown-style formatting, code highlighting, and @mentions
                TextEditor(text: $richText, selection: $textSelection)
                    .font(settings.scaledFont(.body))
                    .foregroundStyle(CLITheme.primaryText(for: colorScheme))
                    .focused($isFocused)
                    .disabled(isProcessing)
                    .scrollContentBackground(.hidden)
                    .contentMargins(.vertical, 0, for: .scrollContent)
                    .frame(minHeight: 36, maxHeight: 200)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassBackground(cornerRadius: 20)
                    .onAppear {
                        // Initialize rich text from plain text binding
                        richText = styleInputText(text)
                    }
                    .onChange(of: text) { _, newText in
                        // Sync from parent: update rich text when plain text changes externally
                        let newRichText = styleInputText(newText)
                        if String(richText.characters) != newText {
                            richText = newRichText
                        }
                    }
                    .onChange(of: richText) { _, newRichText in
                        // Sync to parent: update plain text when rich text changes
                        let plainText = String(newRichText.characters)
                        if text != plainText {
                            text = plainText
                        }
                    }

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
                    projectPath: projectPath
                ) { selectedPath in
                    insertFileReference(selectedPath)
                }
            }
        }
        .sheet(isPresented: $showCommandPicker) {
            CommandPickerSheet(
                commandStore: CommandStore.shared,
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
            // Saved Commands - always show option, picker handles empty state
            Button {
                showCommandPicker = true
            } label: {
                Label("Saved Commands", systemImage: "text.book.closed")
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

    // MARK: - Rich Text Styling (iOS 26+)

    /// Apply syntax highlighting styles to input text
    /// - Styles @file references in cyan
    /// - Styles inline code (backticks) in monospace with background
    /// - Styles slash commands in yellow
    private func styleInputText(_ plainText: String) -> AttributedString {
        guard !plainText.isEmpty else {
            return AttributedString()
        }

        var attributedString = AttributedString(plainText)

        // Style @file references (e.g., @src/file.swift)
        let filePattern = try? NSRegularExpression(pattern: "@[\\w/.\\-]+", options: [])
        if let matches = filePattern?.matches(in: plainText, range: NSRange(plainText.startIndex..., in: plainText)) {
            for match in matches {
                if let range = Range(match.range, in: plainText),
                   let attrRange = Range(range, in: attributedString) {
                    attributedString[attrRange].foregroundColor = CLITheme.cyan(for: colorScheme)
                    attributedString[attrRange].font = settings.scaledFont(.body).monospaced()
                }
            }
        }

        // Style inline code with backticks (e.g., `code`)
        let codePattern = try? NSRegularExpression(pattern: "`[^`]+`", options: [])
        if let matches = codePattern?.matches(in: plainText, range: NSRange(plainText.startIndex..., in: plainText)) {
            for match in matches {
                if let range = Range(match.range, in: plainText),
                   let attrRange = Range(range, in: attributedString) {
                    attributedString[attrRange].foregroundColor = CLITheme.green(for: colorScheme)
                    attributedString[attrRange].font = settings.scaledFont(.body).monospaced()
                    attributedString[attrRange].backgroundColor = CLITheme.secondaryBackground(for: colorScheme)
                }
            }
        }

        // Style slash commands (e.g., /help, /model)
        let slashPattern = try? NSRegularExpression(pattern: "^/[a-z]+", options: [.anchorsMatchLines])
        if let matches = slashPattern?.matches(in: plainText, range: NSRange(plainText.startIndex..., in: plainText)) {
            for match in matches {
                if let range = Range(match.range, in: plainText),
                   let attrRange = Range(range, in: attributedString) {
                    attributedString[attrRange].foregroundColor = CLITheme.yellow(for: colorScheme)
                    attributedString[attrRange].font = settings.scaledFont(.body).bold()
                }
            }
        }

        return attributedString
    }
}
