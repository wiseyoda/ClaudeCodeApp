import SwiftUI
import PhotosUI

// MARK: - CLI Input View

struct CLIInputView: View {
    @Binding var text: String
    @Binding var selectedImage: Data?
    let isProcessing: Bool
    @FocusState var isFocused: Bool
    let onSend: () -> Void
    let onAbort: () -> Void
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var speechManager = SpeechManager()
    @State private var showImagePicker = false
    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 0) {
            // Recording indicator
            if speechManager.isRecording {
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
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(CLITheme.secondaryBackground(for: colorScheme))
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
                            .foregroundColor(CLITheme.red(for: colorScheme))
                    }
                    .accessibilityLabel("Remove image")
                    .accessibilityHint("Remove the attached image from your message")

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(CLITheme.secondaryBackground(for: colorScheme))
            }

            HStack(spacing: 8) {
                Text(">")
                    .foregroundColor(CLITheme.green(for: colorScheme))
                    .font(settings.scaledFont(.body))

                TextField("Type a message...", text: $text)
                    .font(settings.scaledFont(.body))
                    .foregroundColor(CLITheme.primaryText(for: colorScheme))
                    .focused($isFocused)
                    .disabled(isProcessing)
                    .submitLabel(.send)
                    .onSubmit { onSend() }

                // Image picker button
                if !isProcessing {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Image(systemName: "photo")
                            .foregroundColor(selectedImage != nil ? CLITheme.blue(for: colorScheme) : CLITheme.mutedText(for: colorScheme))
                    }
                    .accessibilityLabel("Attach image")
                    .accessibilityHint("Select an image to send with your message")
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
                            .foregroundColor(speechManager.isRecording ? CLITheme.red(for: colorScheme) : CLITheme.mutedText(for: colorScheme))
                    }
                    .accessibilityLabel(speechManager.isRecording ? "Stop recording" : "Voice input")
                    .accessibilityHint(speechManager.isRecording ? "Stop voice recording and add transcribed text" : "Start voice recording to dictate your message")
                }

                if (!text.isEmpty || selectedImage != nil) && !isProcessing {
                    Button(action: onSend) {
                        Image(systemName: "return")
                            .foregroundColor(CLITheme.green(for: colorScheme))
                    }
                    .accessibilityLabel("Send message")
                    .accessibilityHint(selectedImage != nil ? "Send your message with attached image" : "Send your message to Claude")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(CLITheme.background(for: colorScheme))
        }
        // iPad keyboard shortcuts
        .background(
            Group {
                // Cmd+Return to send (when not processing and has content)
                Button("") {
                    if !isProcessing && (!text.isEmpty || selectedImage != nil) {
                        onSend()
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .opacity(0)

                // Escape to abort (when processing)
                Button("") {
                    if isProcessing {
                        onAbort()
                    }
                }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)
            }
        )
    }
}
