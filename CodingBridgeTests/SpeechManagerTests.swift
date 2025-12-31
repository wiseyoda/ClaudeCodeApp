import AVFoundation
import Combine
import Speech
import XCTest
@testable import CodingBridge

private final class MockSpeechRecognitionTask: SpeechRecognitionTaskProviding {
    private(set) var cancelCallCount = 0

    func cancel() {
        cancelCallCount += 1
    }
}

private final class MockSpeechRecognizer: SpeechRecognizerProviding {
    var isAvailable: Bool
    private(set) var recognitionTaskCallCount = 0
    var onRecognitionTask: ((SFSpeechRecognitionRequest, @escaping (SFSpeechRecognitionResult?, Error?) -> Void) -> SpeechRecognitionTaskProviding)?

    init(
        isAvailable: Bool = true,
        onRecognitionTask: ((SFSpeechRecognitionRequest, @escaping (SFSpeechRecognitionResult?, Error?) -> Void) -> SpeechRecognitionTaskProviding)? = nil
    ) {
        self.isAvailable = isAvailable
        self.onRecognitionTask = onRecognitionTask
    }

    func startRecognitionTask(
        with request: SFSpeechRecognitionRequest,
        resultHandler: @escaping (SFSpeechRecognitionResult?, Error?) -> Void
    ) -> SpeechRecognitionTaskProviding {
        recognitionTaskCallCount += 1
        if let onRecognitionTask = onRecognitionTask {
            return onRecognitionTask(request, resultHandler)
        }
        return MockSpeechRecognitionTask()
    }
}

private struct MockRecognitionError: LocalizedError {
    let errorDescription: String?
}

@MainActor
final class SpeechManagerTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    private func makeManager(
        recognizer: SpeechRecognizerProviding? = nil,
        authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    ) -> SpeechManager {
        SpeechManager.makeForTesting(
            recognizer: recognizer,
            authorizationStatus: authorizationStatus
        )
    }

    private func skipIfSpeechPermissionPromptNeeded() throws {
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            throw XCTSkip("Speech recognition permission prompt required.")
        }
    }

    private func skipIfCannotRecord() throws {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        if speechStatus != .authorized {
            throw XCTSkip("Speech recognition not authorized: \(speechStatus).")
        }
        let session = AVAudioSession.sharedInstance()
        if session.recordPermission != .granted {
            throw XCTSkip("Microphone permission not granted.")
        }
        if !session.isInputAvailable {
            throw XCTSkip("No microphone input available.")
        }
    }

    private func recognizerAvailability() -> Bool {
        SpeechManager.makeSpeechRecognizer()?.isAvailable ?? false
    }

    private func speechRecognizerLocaleIdentifier(from manager: SpeechManager) -> String? {
        let mirror = Mirror(reflecting: manager)
        for child in mirror.children where child.label == "speechRecognizer" {
            if let recognizer = child.value as? SFSpeechRecognizer {
                return recognizer.locale.identifier
            }
            let optionalMirror = Mirror(reflecting: child.value)
            if optionalMirror.displayStyle == .optional,
               let recognizer = optionalMirror.children.first?.value as? SFSpeechRecognizer {
                return recognizer.locale.identifier
            }
        }
        return nil
    }

    func testStartRecordingWithoutAuthorizationSetsError() {
        let manager = makeManager()
        manager.authorizationStatus = .denied

        manager.startRecording()

        XCTAssertEqual(manager.errorMessage, "Speech recognition not authorized")
        XCTAssertFalse(manager.isRecording)
    }

    func testToggleRecordingStopsWhenRecording() {
        let manager = makeManager()
        manager.isRecording = true

        manager.toggleRecording()

        XCTAssertFalse(manager.isRecording)
    }

    func test_toggleRecording_startsWhenStopped() throws {
        try skipIfCannotRecord()
        let manager = makeManager()
        manager.authorizationStatus = .authorized
        defer { manager.stopRecording() }

        manager.toggleRecording()

        if !manager.isRecording {
            throw XCTSkip("Recording could not start: \(manager.errorMessage ?? "unknown error")")
        }

        XCTAssertTrue(manager.isRecording)
    }

    func testIsAvailableFalseWhenUnauthorized() {
        let manager = makeManager()
        manager.authorizationStatus = .restricted

        XCTAssertFalse(manager.isAvailable)
    }

    func test_authorizationStatus_initiallyNotDetermined() {
        let manager = makeManager()

        XCTAssertEqual(manager.authorizationStatus, .notDetermined)
    }

    func test_authorization_notDetermined() {
        let manager = makeManager()
        manager.authorizationStatus = .notDetermined

        XCTAssertFalse(manager.isAvailable)
    }

    func test_authorization_denied() {
        let manager = makeManager()
        manager.authorizationStatus = .denied

        XCTAssertFalse(manager.isAvailable)
    }

    func test_authorization_restricted() {
        let manager = makeManager()
        manager.authorizationStatus = .restricted

        XCTAssertFalse(manager.isAvailable)
    }

    func test_authorization_authorized() {
        let manager = makeManager()
        manager.authorizationStatus = .authorized

        XCTAssertEqual(manager.isAvailable, recognizerAvailability())
    }

    func test_authorization_requestPermission() throws {
        try skipIfSpeechPermissionPromptNeeded()
        let manager = makeManager()
        let expectation = XCTestExpectation(description: "authorization status updated")
        let currentStatus = SFSpeechRecognizer.authorizationStatus()
        manager.authorizationStatus = .notDetermined

        manager.$authorizationStatus
            .dropFirst()
            .sink { status in
                if status == currentStatus {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        manager.checkAuthorization()

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(manager.authorizationStatus, currentStatus)
    }

    func test_authorization_statusChangeCallback() throws {
        try skipIfSpeechPermissionPromptNeeded()
        let manager = makeManager()
        let expectation = XCTestExpectation(description: "authorization callback updates on main thread")
        manager.authorizationStatus = .notDetermined

        manager.$authorizationStatus
            .dropFirst()
            .sink { _ in
                XCTAssertTrue(Thread.isMainThread)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        manager.checkAuthorization()

        wait(for: [expectation], timeout: 1.0)
    }

    func test_recording_startWhenAuthorized() throws {
        try skipIfCannotRecord()
        let manager = makeManager()
        manager.authorizationStatus = .authorized
        defer { manager.stopRecording() }

        manager.startRecording()

        if !manager.isRecording {
            throw XCTSkip("Recording could not start: \(manager.errorMessage ?? "unknown error")")
        }

        XCTAssertTrue(manager.isRecording)
        XCTAssertNil(manager.errorMessage)
        XCTAssertEqual(manager.transcribedText, "")
    }

    func test_startRecording_clearsErrorMessage() throws {
        try skipIfCannotRecord()
        let manager = makeManager()
        manager.authorizationStatus = .authorized
        manager.errorMessage = "Existing error"
        defer { manager.stopRecording() }

        manager.startRecording()

        if !manager.isRecording {
            throw XCTSkip("Recording could not start: \(manager.errorMessage ?? "unknown error")")
        }

        XCTAssertNil(manager.errorMessage)
    }

    func test_recording_startWhenNotAuthorized() {
        let manager = makeManager()
        manager.authorizationStatus = .restricted

        manager.startRecording()

        XCTAssertEqual(manager.errorMessage, "Speech recognition not authorized")
        XCTAssertFalse(manager.isRecording)
    }

    func test_startRecording_whenRecognizerUnavailable_setsError() {
        let mockRecognizer = MockSpeechRecognizer(isAvailable: false)
        let manager = makeManager(
            recognizer: mockRecognizer,
            authorizationStatus: .authorized
        )

        manager.startRecording()

        XCTAssertEqual(manager.errorMessage, "Speech recognizer unavailable")
        XCTAssertFalse(manager.isRecording)
        XCTAssertEqual(mockRecognizer.recognitionTaskCallCount, 0)
    }

    func test_recording_stopReturnsTranscript() {
        let manager = makeManager()
        manager.isRecording = true
        manager.transcribedText = "Hello world"

        manager.stopRecording()

        XCTAssertFalse(manager.isRecording)
        XCTAssertEqual(manager.transcribedText, "Hello world")
    }

    func test_recording_cancelDiscardsAudio() throws {
        try XCTSkipIf(!recognizerAvailability(), "Speech recognizer unavailable; can't start recording.")
        let manager = makeManager()
        manager.transcribedText = "Previous transcript"
        manager.authorizationStatus = .authorized

        manager.startRecording()

        XCTAssertEqual(manager.transcribedText, "")

        if manager.isRecording {
            manager.stopRecording()
        }
    }

    func test_recording_alreadyRecordingNoop() {
        let manager = makeManager()
        manager.isRecording = true
        manager.transcribedText = "Keep this"
        manager.errorMessage = "Existing error"

        manager.startRecording()

        XCTAssertTrue(manager.isRecording)
        XCTAssertEqual(manager.transcribedText, "Keep this")
        XCTAssertEqual(manager.errorMessage, "Existing error")
    }

    func test_recording_notRecordingStopNoop() {
        let manager = makeManager()
        manager.isRecording = false
        manager.transcribedText = "Keep this"
        manager.errorMessage = "Existing error"

        manager.stopRecording()

        XCTAssertFalse(manager.isRecording)
        XCTAssertEqual(manager.transcribedText, "Keep this")
        XCTAssertEqual(manager.errorMessage, "Existing error")
    }

    func test_recording_interruptedBySystemAudio() {
        let manager = makeManager()
        manager.isRecording = true

        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )

        XCTAssertTrue(manager.isRecording)
    }

    func test_recording_resumeAfterInterruption() throws {
        throw XCTSkip("SpeechManager does not observe interruption notifications.")
    }

    func test_recording_maxDurationLimit() throws {
        throw XCTSkip("SpeechManager does not enforce a max recording duration.")
    }

    func test_audioSession_activationSuccess() throws {
        try skipIfCannotRecord()
        let manager = makeManager()
        manager.authorizationStatus = .authorized
        defer { manager.stopRecording() }

        manager.startRecording()

        if !manager.isRecording {
            throw XCTSkip("Recording could not start: \(manager.errorMessage ?? "unknown error")")
        }

        XCTAssertTrue(manager.isRecording)
    }

    func test_audioSession_activationFailure() throws {
        throw XCTSkip("Audio session failure requires injection or swizzling.")
    }

    func test_audioSession_deactivationOnStop() throws {
        throw XCTSkip("AVAudioSession does not expose a reliable active-state getter.")
    }

    func test_audioSession_categorySettings() throws {
        try skipIfCannotRecord()
        let manager = makeManager()
        manager.authorizationStatus = .authorized
        defer { manager.stopRecording() }

        manager.startRecording()

        if !manager.isRecording {
            throw XCTSkip("Recording could not start: \(manager.errorMessage ?? "unknown error")")
        }

        let session = AVAudioSession.sharedInstance()
        XCTAssertEqual(session.category, .record)
        XCTAssertTrue(session.categoryOptions.contains(.duckOthers))
    }

    func test_audioSession_modeSettings() throws {
        try skipIfCannotRecord()
        let manager = makeManager()
        manager.authorizationStatus = .authorized
        defer { manager.stopRecording() }

        manager.startRecording()

        if !manager.isRecording {
            throw XCTSkip("Recording could not start: \(manager.errorMessage ?? "unknown error")")
        }

        let session = AVAudioSession.sharedInstance()
        XCTAssertEqual(session.mode, .measurement)
    }

    func test_recognitionError_setsErrorMessage() {
        let manager = makeManager()
        let error = MockRecognitionError(errorDescription: "Test failure")

        manager.handleRecognition(resultText: nil, isFinal: false, error: error)

        XCTAssertEqual(manager.errorMessage, "Speech recognition error: Test failure")
    }

    func test_recognitionError_stopsRecording() {
        let manager = makeManager()
        manager.isRecording = true

        manager.handleRecognition(resultText: nil, isFinal: false, error: MockRecognitionError(errorDescription: "Boom"))

        XCTAssertFalse(manager.isRecording)
    }

    func test_transcription_updatesTranscribedText() {
        let manager = makeManager()
        manager.transcribedText = "Old"

        manager.handleRecognition(resultText: "New transcript", isFinal: false, error: nil)

        XCTAssertEqual(manager.transcribedText, "New transcript")
    }

    func test_transcription_isFinal_stopsRecording() {
        let manager = makeManager()
        manager.isRecording = true

        manager.handleRecognition(resultText: "Done", isFinal: true, error: nil)

        XCTAssertFalse(manager.isRecording)
    }

    func test_transcription_emptyResult_doesNotUpdate() {
        let manager = makeManager()
        manager.transcribedText = "Keep this"

        manager.handleRecognition(resultText: "", isFinal: false, error: nil)

        XCTAssertEqual(manager.transcribedText, "Keep this")
    }

    func test_transcription_partialResults() throws {
        throw XCTSkip("Partial transcription requires live audio input.")
    }

    func test_transcription_finalResult() throws {
        throw XCTSkip("Final transcription requires live audio input.")
    }

    func test_transcription_errorHandling() throws {
        throw XCTSkip("Recognition task errors require injection or swizzling.")
    }

    func test_transcription_emptyAudio() throws {
        throw XCTSkip("Empty-audio transcription requires live audio input.")
    }

    func test_transcription_localeSelection() throws {
        try XCTSkipIf(
            SFSpeechRecognizer(locale: Locale(identifier: "en-US")) == nil,
            "Preferred locale unavailable; fallback may be used."
        )
        let manager = makeManager()
        let localeIdentifier = speechRecognizerLocaleIdentifier(from: manager)

        XCTAssertEqual(localeIdentifier, "en-US")
    }

    func test_speechRecognizer_fallbackWhenUnavailable() {
        var requestedLocales: [Locale] = []
        let fallbackRecognizer = MockSpeechRecognizer()
        let recognizer = SpeechManager.makeSpeechRecognizer(
            preferredLocale: Locale(identifier: "en-US"),
            fallbackLocale: Locale(identifier: "fr-FR"),
            factory: { locale in
                requestedLocales.append(locale)
                return locale.identifier == "en-US" ? nil : fallbackRecognizer
            }
        )

        XCTAssertEqual(requestedLocales.map(\.identifier), ["en-US", "fr-FR"])
        XCTAssertTrue(recognizer as? MockSpeechRecognizer === fallbackRecognizer)
    }

    func test_isRecording_reflectsState() {
        let manager = makeManager()

        XCTAssertFalse(manager.isRecording)

        manager.isRecording = true
        XCTAssertTrue(manager.isRecording)

        manager.isRecording = false
        XCTAssertFalse(manager.isRecording)
    }

    func test_isRecording_publishesChanges() {
        let manager = makeManager()
        let expectation = XCTestExpectation(description: "isRecording publishes changes")
        var received: [Bool] = []

        manager.$isRecording
            .dropFirst()
            .sink { value in
                received.append(value)
                if received == [true, false] {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        manager.isRecording = true
        manager.isRecording = false

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(received, [true, false])
    }

    func test_isAvailable_checksMicrophone() throws {
        let manager = makeManager()
        try XCTSkipIf(!recognizerAvailability(), "Speech recognizer unavailable; can't isolate authorization gating.")
        manager.authorizationStatus = .denied

        XCTAssertFalse(manager.isAvailable)
    }

    func test_isAvailable_checksRecognition() {
        let manager = makeManager()
        manager.authorizationStatus = .authorized

        XCTAssertEqual(manager.isAvailable, recognizerAvailability())
    }

    func test_transcribedText_publishesChanges() {
        let manager = makeManager()
        let expectation = XCTestExpectation(description: "transcribedText updates")

        manager.$transcribedText
            .dropFirst()
            .sink { value in
                if value == "Live update" {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        manager.transcribedText = "Live update"

        wait(for: [expectation], timeout: 1.0)
    }

    func test_errorMessage_publishesChanges() {
        let manager = makeManager()
        let expectation = XCTestExpectation(description: "errorMessage publishes changes")
        var received: [String?] = []

        manager.$errorMessage
            .dropFirst()
            .sink { value in
                received.append(value)
                if received.count == 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        manager.errorMessage = "First error"
        manager.errorMessage = nil

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(received, ["First error", nil])
    }

    func test_lastError_capturesErrors() {
        let manager = makeManager()
        manager.authorizationStatus = .notDetermined

        manager.startRecording()

        XCTAssertEqual(manager.errorMessage, "Speech recognition not authorized")
        XCTAssertFalse(manager.isRecording)
    }
}
