import XCTest
import Speech
@testable import CodingBridge

@MainActor
final class SpeechManagerTests: XCTestCase {
    func testStartRecordingWithoutAuthorizationSetsError() {
        let manager = SpeechManager(shouldRequestAuthorization: false)
        manager.authorizationStatus = .denied

        manager.startRecording()

        XCTAssertEqual(manager.errorMessage, "Speech recognition not authorized")
        XCTAssertFalse(manager.isRecording)
    }

    func testToggleRecordingStopsWhenRecording() {
        let manager = SpeechManager(shouldRequestAuthorization: false)
        manager.isRecording = true

        manager.toggleRecording()

        XCTAssertFalse(manager.isRecording)
    }

    func testIsAvailableFalseWhenUnauthorized() {
        let manager = SpeechManager(shouldRequestAuthorization: false)
        manager.authorizationStatus = .restricted

        XCTAssertFalse(manager.isAvailable)
    }
}
