import Foundation
import Speech
import AVFoundation

protocol SpeechRecognitionTaskProviding {
    func cancel()
}

extension SFSpeechRecognitionTask: SpeechRecognitionTaskProviding {}

protocol SpeechRecognizerProviding {
    var isAvailable: Bool { get }
    func startRecognitionTask(
        with request: SFSpeechRecognitionRequest,
        resultHandler: @escaping (SFSpeechRecognitionResult?, Error?) -> Void
    ) -> SpeechRecognitionTaskProviding
}

extension SFSpeechRecognizer: SpeechRecognizerProviding {
    func startRecognitionTask(
        with request: SFSpeechRecognitionRequest,
        resultHandler: @escaping (SFSpeechRecognitionResult?, Error?) -> Void
    ) -> SpeechRecognitionTaskProviding {
        recognitionTask(with: request, resultHandler: resultHandler)
    }
}

@MainActor
class SpeechManager: ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SpeechRecognitionTaskProviding?
    private var speechRecognizer: SpeechRecognizerProviding?

    @Published var isRecording = false
    @Published var transcribedText = ""
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?

    init(shouldRequestAuthorization: Bool = true) {
        speechRecognizer = Self.makeSpeechRecognizer()
        if shouldRequestAuthorization {
            checkAuthorization()
        }
    }

    static func makeSpeechRecognizer(
        preferredLocale: Locale = Locale(identifier: "en-US"),
        fallbackLocale: Locale = Locale.current,
        factory: (Locale) -> SpeechRecognizerProviding? = { SFSpeechRecognizer(locale: $0) }
    ) -> SpeechRecognizerProviding? {
        if let recognizer = factory(preferredLocale) {
            return recognizer
        }
        return factory(fallbackLocale)
    }

#if DEBUG
    static func makeForTesting(
        recognizer: SpeechRecognizerProviding? = nil,
        authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    ) -> SpeechManager {
        let manager = SpeechManager(shouldRequestAuthorization: false)
        manager.authorizationStatus = authorizationStatus
        if let recognizer = recognizer {
            manager.speechRecognizer = recognizer
        }
        return manager
    }
#endif

    deinit {
        // Clean up audio resources to prevent memory leaks
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    func checkAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                self?.authorizationStatus = status
            }
        }
    }

    var isAvailable: Bool {
        authorizationStatus == .authorized && (speechRecognizer?.isAvailable ?? false)
    }

    func startRecording() {
        guard !isRecording else { return }
        guard authorizationStatus == .authorized else {
            errorMessage = "Speech recognition not authorized"
            return
        }
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognizer unavailable"
            return
        }

        // Reset state
        transcribedText = ""
        errorMessage = nil

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Audio session error: \(error.localizedDescription)"
            return
        }

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "Unable to create recognition request"
            return
        }
        recognitionRequest.shouldReportPartialResults = true

        // Setup audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            errorMessage = "Unable to create audio engine"
            return
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        // Start recognition task
        recognitionTask = speechRecognizer.startRecognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                self?.handleRecognition(
                    resultText: result?.bestTranscription.formattedString,
                    isFinal: result?.isFinal == true,
                    error: error
                )
            }
        }

        // Start audio engine
        do {
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
            log.info("Recording started")
        } catch {
            errorMessage = "Audio engine error: \(error.localizedDescription)"
            stopRecording()
        }
    }

    func handleRecognition(resultText: String?, isFinal: Bool, error: Error?) {
        if let error = error {
            errorMessage = "Speech recognition error: \(error.localizedDescription)"
            stopRecording()
            return
        }

        if let resultText, !resultText.isEmpty {
            transcribedText = resultText
        }

        if isFinal {
            stopRecording()
        }
    }

    func stopRecording() {
        guard isRecording else { return }

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        audioEngine = nil

        // Deactivate audio session to allow keyboard to work properly
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        isRecording = false
        log.info("Recording stopped, text: \(transcribedText)")
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
}
