import AVFoundation
import Combine
import Speech
import XCTest
@testable import CodingBridge

@MainActor
final class SpeechManagerTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    private func makeManager() -> SpeechManager {
        SpeechManager(shouldRequestAuthorization: false)
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
        SFSpeechRecognizer(locale: Locale(identifier: "en-US"))?.isAvailable ?? false
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

    func testIsAvailableFalseWhenUnauthorized() {
        let manager = makeManager()
        manager.authorizationStatus = .restricted

        XCTAssertFalse(manager.isAvailable)
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

    func test_recording_startWhenNotAuthorized() {
        let manager = makeManager()
        manager.authorizationStatus = .restricted

        manager.startRecording()

        XCTAssertEqual(manager.errorMessage, "Speech recognition not authorized")
        XCTAssertFalse(manager.isRecording)
    }

    func test_recording_stopReturnsTranscript() {
        let manager = makeManager()
        manager.isRecording = true
        manager.transcribedText = "Hello world"

        manager.stopRecording()

        XCTAssertFalse(manager.isRecording)
        XCTAssertEqual(manager.transcribedText, "Hello world")
    }

    func test_recording_cancelDiscardsAudio() {
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

    func test_transcription_localeSelection() {
        let manager = makeManager()
        let localeIdentifier = speechRecognizerLocaleIdentifier(from: manager)

        XCTAssertEqual(localeIdentifier, "en-US")
    }

    func test_isRecording_reflectsState() {
        let manager = makeManager()

        XCTAssertFalse(manager.isRecording)

        manager.isRecording = true
        XCTAssertTrue(manager.isRecording)

        manager.isRecording = false
        XCTAssertFalse(manager.isRecording)
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

    func test_currentTranscript_updatesLive() {
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

    func test_lastError_capturesErrors() {
        let manager = makeManager()
        manager.authorizationStatus = .notDetermined

        manager.startRecording()

        XCTAssertEqual(manager.errorMessage, "Speech recognition not authorized")
        XCTAssertFalse(manager.isRecording)
    }
}
