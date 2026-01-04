# Issue 69: Voice Input

**Phase:** 7 (Advanced Features)
**Priority:** Low
**Status:** Not Started
**Depends On:** 26 (Chat View Redesign)
**Target:** iOS 26.2, Xcode 26.2, Swift 6.2.1

## Goal

Enhance the existing SpeechManager with improved voice input UX, continuous dictation, voice commands, and better visual feedback for iOS 26.

## Scope

- In scope:
  - Improved recording indicator UI
  - Continuous dictation mode
  - Basic voice commands (/help, /clear, /send)
  - Partial results with confidence indicators
  - Hands-free mode with auto-send
  - Silence detection and auto-stop
- Out of scope:
  - Offline speech recognition
  - Custom wake words
  - Full conversation via voice
  - Voice output (TTS responses)

## Non-goals

- Replace typed input entirely
- Multi-language simultaneous recognition
- Voice authentication

## Dependencies

- Issue #26 (Chat View Redesign) for input integration

## Touch Set

- Files to create:
  - `CodingBridge/Views/Input/VoiceInputOverlay.swift`
  - `CodingBridge/Managers/VoiceCommandHandler.swift`
- Files to modify:
  - `CodingBridge/Managers/SpeechManager.swift` (enhance existing)
  - `CodingBridge/Views/CLIInputView.swift` (integrate overlay)

---

## Enhanced SpeechManager

### SpeechManager Updates

```swift
import Speech
import AVFoundation

/// Manages speech recognition with enhanced iOS 26 features.
@MainActor @Observable
final class SpeechManager: NSObject {
    // MARK: - State

    private(set) var isRecording = false
    private(set) var isAuthorized = false
    private(set) var partialResult = ""
    private(set) var confidence: Float = 0
    private(set) var audioLevel: Float = 0
    private(set) var silenceDuration: TimeInterval = 0

    var transcribedText: String = ""
    var onTranscriptionComplete: ((String) -> Void)?

    // MARK: - Configuration

    var autoSendEnabled = false
    var silenceThreshold: TimeInterval = 2.0
    var continuousDictation = false

    // MARK: - Private

    @ObservationIgnored
    private var recognizer: SFSpeechRecognizer?

    @ObservationIgnored
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    @ObservationIgnored
    private var recognitionTask: SFSpeechRecognitionTask?

    @ObservationIgnored
    private var audioEngine: AVAudioEngine?

    @ObservationIgnored
    private var silenceTimer: Timer?

    @ObservationIgnored
    private var levelTimer: Timer?

    // MARK: - Initialization

    override init() {
        super.init()
        recognizer = SFSpeechRecognizer(locale: Locale.current)
        recognizer?.delegate = self
        checkAuthorization()
    }

    // MARK: - Authorization

    private func checkAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                self?.isAuthorized = status == .authorized
            }
        }
    }

    // MARK: - Recording Control

    func startRecording() throws {
        guard isAuthorized else {
            throw SpeechError.notAuthorized
        }

        guard let recognizer, recognizer.isAvailable else {
            throw SpeechError.recognizerNotAvailable
        }

        // Cancel any existing task
        stopRecording()

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true
        recognitionRequest?.addsPunctuation = true

        // iOS 26: Enable on-device if available
        if #available(iOS 26, *) {
            recognitionRequest?.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        }

        // Set up audio engine
        audioEngine = AVAudioEngine()
        let inputNode = audioEngine!.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            self?.updateAudioLevel(buffer: buffer)
        }

        audioEngine!.prepare()
        try audioEngine!.start()

        // Start recognition
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest!) { [weak self] result, error in
            Task { @MainActor in
                self?.handleRecognitionResult(result, error: error)
            }
        }

        isRecording = true
        startSilenceDetection()
        startLevelMonitoring()
    }

    func stopRecording() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil
        audioEngine = nil

        silenceTimer?.invalidate()
        levelTimer?.invalidate()

        isRecording = false
        silenceDuration = 0
    }

    func cancelRecording() {
        stopRecording()
        transcribedText = ""
        partialResult = ""
    }

    // MARK: - Result Handling

    private func handleRecognitionResult(_ result: SFSpeechRecognitionResult?, error: Error?) {
        if let error {
            Logger.speech.error("Recognition error: \(error)")
            stopRecording()
            return
        }

        guard let result else { return }

        let transcription = result.bestTranscription.formattedString
        partialResult = transcription

        // Update confidence
        if let segment = result.bestTranscription.segments.last {
            confidence = Float(segment.confidence)
        }

        // Reset silence timer on new input
        resetSilenceTimer()

        // Check for voice commands
        if let command = VoiceCommandHandler.detectCommand(in: transcription) {
            handleVoiceCommand(command)
            return
        }

        if result.isFinal {
            transcribedText = transcription
            partialResult = ""
            onTranscriptionComplete?(transcription)

            if !continuousDictation {
                stopRecording()
            }
        }
    }

    private func handleVoiceCommand(_ command: VoiceCommand) {
        stopRecording()
        VoiceCommandHandler.execute(command)
    }

    // MARK: - Audio Level

    private func updateAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)

        var sum: Float = 0
        for i in 0..<frameCount {
            sum += abs(channelData[i])
        }

        let average = sum / Float(frameCount)
        let level = min(1.0, average * 10)  // Normalize

        Task { @MainActor in
            self.audioLevel = level
        }
    }

    private func startLevelMonitoring() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            // Level updates come from audio buffer tap
        }
    }

    // MARK: - Silence Detection

    private func startSilenceDetection() {
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkSilence()
            }
        }
    }

    private func resetSilenceTimer() {
        silenceDuration = 0
    }

    private func checkSilence() {
        if audioLevel < 0.01 {
            silenceDuration += 0.5

            if silenceDuration >= silenceThreshold && !partialResult.isEmpty {
                // Auto-stop on silence
                transcribedText = partialResult
                onTranscriptionComplete?(transcribedText)
                stopRecording()
            }
        } else {
            silenceDuration = 0
        }
    }

    // MARK: - Errors

    enum SpeechError: Error {
        case notAuthorized
        case recognizerNotAvailable
    }
}

extension SpeechManager: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(
        _ speechRecognizer: SFSpeechRecognizer,
        availabilityDidChange available: Bool
    ) {
        Task { @MainActor in
            if !available {
                stopRecording()
            }
        }
    }
}
```

---

## Voice Commands

### VoiceCommandHandler

```swift
/// Handles voice command detection and execution.
enum VoiceCommandHandler {
    /// Recognized voice commands.
    enum VoiceCommand: String, CaseIterable {
        case help = "help"
        case clear = "clear"
        case send = "send"
        case cancel = "cancel"
        case newChat = "new chat"
        case stopRecording = "stop"

        var phrases: [String] {
            switch self {
            case .help:
                return ["help", "show help", "what can i say"]
            case .clear:
                return ["clear", "clear message", "delete"]
            case .send:
                return ["send", "send message", "submit"]
            case .cancel:
                return ["cancel", "never mind", "forget it"]
            case .newChat:
                return ["new chat", "start new", "start over"]
            case .stopRecording:
                return ["stop", "stop recording", "done"]
            }
        }
    }

    /// Detect voice command in transcription.
    static func detectCommand(in text: String) -> VoiceCommand? {
        let lowercased = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        for command in VoiceCommand.allCases {
            for phrase in command.phrases {
                if lowercased == phrase || lowercased.hasSuffix(phrase) {
                    return command
                }
            }
        }

        return nil
    }

    /// Execute voice command.
    @MainActor
    static func execute(_ command: VoiceCommand) {
        NotificationCenter.default.post(
            name: .voiceCommandExecuted,
            object: nil,
            userInfo: ["command": command]
        )
    }
}

extension Notification.Name {
    static let voiceCommandExecuted = Notification.Name("voiceCommandExecuted")
}
```

---

## Voice Input Overlay

### VoiceInputOverlay

```swift
import SwiftUI

/// Full-screen overlay for voice input with visual feedback.
struct VoiceInputOverlay: View {
    @Environment(\.dismiss) var dismiss
    @State private var speechManager = SpeechManager()

    @State private var waveformPhase: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0

    let onComplete: (String) -> Void

    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Status
                statusView

                // Waveform visualization
                waveformView

                // Transcription preview
                transcriptionView

                Spacer()

                // Controls
                controlsView
            }
            .padding()
        }
        .onAppear {
            startRecording()
        }
        .onDisappear {
            speechManager.stopRecording()
        }
    }

    @ViewBuilder
    private var statusView: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(speechManager.isRecording ? .red : .gray)
                .frame(width: 12, height: 12)
                .scaleEffect(pulseScale)
                .animation(
                    .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                    value: pulseScale
                )

            Text(statusText)
                .font(.headline)
                .foregroundStyle(.white)
        }
        .onAppear {
            pulseScale = 1.2
        }
    }

    private var statusText: String {
        if !speechManager.isAuthorized {
            return "Microphone Access Required"
        }
        if speechManager.isRecording {
            return "Listening..."
        }
        return "Tap to Start"
    }

    @ViewBuilder
    private var waveformView: some View {
        WaveformVisualizer(
            audioLevel: speechManager.audioLevel,
            isActive: speechManager.isRecording
        )
        .frame(height: 100)
    }

    @ViewBuilder
    private var transcriptionView: some View {
        VStack(spacing: 8) {
            if !speechManager.partialResult.isEmpty {
                Text(speechManager.partialResult)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                // Confidence indicator
                HStack {
                    ForEach(0..<5, id: \.self) { index in
                        Circle()
                            .fill(index < Int(speechManager.confidence * 5) ? .green : .gray)
                            .frame(width: 8, height: 8)
                    }
                }
            } else {
                Text("Say something...")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    @ViewBuilder
    private var controlsView: some View {
        HStack(spacing: 40) {
            Button(action: { cancel() }) {
                VStack {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 44))
                    Text("Cancel")
                        .font(.caption)
                }
                .foregroundStyle(.white)
            }

            Button(action: { toggleRecording() }) {
                VStack {
                    Image(systemName: speechManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 64))
                    Text(speechManager.isRecording ? "Stop" : "Record")
                        .font(.caption)
                }
                .foregroundStyle(speechManager.isRecording ? .red : .white)
            }

            Button(action: { done() }) {
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                    Text("Done")
                        .font(.caption)
                }
                .foregroundStyle(.green)
            }
            .disabled(speechManager.partialResult.isEmpty)
        }
    }

    // MARK: - Actions

    private func startRecording() {
        do {
            try speechManager.startRecording()
        } catch {
            Logger.speech.error("Failed to start: \(error)")
        }
    }

    private func toggleRecording() {
        if speechManager.isRecording {
            speechManager.stopRecording()
        } else {
            startRecording()
        }
    }

    private func done() {
        let text = speechManager.partialResult.isEmpty
            ? speechManager.transcribedText
            : speechManager.partialResult
        onComplete(text)
        dismiss()
    }

    private func cancel() {
        speechManager.cancelRecording()
        dismiss()
    }
}

// MARK: - Waveform Visualizer

struct WaveformVisualizer: View {
    let audioLevel: Float
    let isActive: Bool

    @State private var bars: [CGFloat] = Array(repeating: 0.1, count: 30)

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<30, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(isActive ? .blue : .gray)
                    .frame(width: 4, height: bars[index] * 80)
            }
        }
        .onChange(of: audioLevel) { _, newLevel in
            updateBars(level: newLevel)
        }
    }

    private func updateBars(level: Float) {
        withAnimation(.easeOut(duration: 0.1)) {
            bars = bars.dropFirst() + [CGFloat(level)]
        }
    }
}
```

---

## Input View Integration

### CLIInputView Updates

```swift
extension CLIInputView {
    @ViewBuilder
    var voiceButton: some View {
        Button(action: { showVoiceOverlay = true }) {
            Image(systemName: "mic.fill")
                .foregroundStyle(speechManager.isAuthorized ? .blue : .gray)
        }
        .disabled(!speechManager.isAuthorized)
        .fullScreenCover(isPresented: $showVoiceOverlay) {
            VoiceInputOverlay { transcription in
                inputText += (inputText.isEmpty ? "" : " ") + transcription
            }
        }
    }
}
```

---

## Edge Cases

- **No microphone permission**: Show settings prompt
- **Background noise**: Increase silence threshold
- **Dictation interrupted by call**: Resume gracefully
- **Very long dictation**: Split into chunks
- **Recognition unavailable**: Fallback to keyboard

## Acceptance Criteria

- [ ] Enhanced SpeechManager with silence detection
- [ ] Voice command detection (help, clear, send, cancel)
- [ ] VoiceInputOverlay with waveform visualization
- [ ] Continuous dictation mode option
- [ ] Auto-send after silence option
- [ ] Confidence indicator for transcription
- [ ] Integration with CLIInputView

## Testing

```swift
class SpeechManagerTests: XCTestCase {
    func testVoiceCommandDetection() {
        XCTAssertEqual(
            VoiceCommandHandler.detectCommand(in: "help"),
            .help
        )
        XCTAssertEqual(
            VoiceCommandHandler.detectCommand(in: "please send"),
            .send
        )
        XCTAssertNil(
            VoiceCommandHandler.detectCommand(in: "hello world")
        )
    }

    func testCommandPhrases() {
        let sendCommand = VoiceCommandHandler.VoiceCommand.send
        XCTAssertTrue(sendCommand.phrases.contains("send"))
        XCTAssertTrue(sendCommand.phrases.contains("send message"))
    }

    @MainActor
    func testSpeechManagerState() {
        let manager = SpeechManager()

        XCTAssertFalse(manager.isRecording)
        XCTAssertEqual(manager.partialResult, "")
        XCTAssertEqual(manager.audioLevel, 0)
    }
}
```
