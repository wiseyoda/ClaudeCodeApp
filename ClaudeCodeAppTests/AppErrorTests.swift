import XCTest
@testable import ClaudeCodeApp

final class AppErrorTests: XCTestCase {
    func testErrorDescriptionStrings() {
        XCTAssertEqual(AppError.networkUnavailable.errorDescription, "No internet connection")
        XCTAssertEqual(AppError.serverUnreachable("http://localhost").errorDescription, "Cannot reach server at http://localhost")
        XCTAssertEqual(AppError.connectionFailed("timeout").errorDescription, "Connection failed: timeout")
        XCTAssertEqual(AppError.authenticationFailed.errorDescription, "Authentication failed")
        XCTAssertEqual(AppError.sessionExpired.errorDescription, "Session expired")
        XCTAssertEqual(AppError.messageFailed("oops").errorDescription, "Message failed: oops")
        XCTAssertEqual(AppError.imageUploadFailed("too big").errorDescription, "Image upload failed: too big")
        XCTAssertEqual(AppError.sshConnectionFailed("bad key").errorDescription, "SSH connection failed: bad key")
        XCTAssertEqual(AppError.invalidResponse.errorDescription, "Invalid server response")
    }

    func testRecoverySuggestions() {
        XCTAssertEqual(AppError.networkUnavailable.recoverySuggestion, "Check your internet connection and try again.")
        XCTAssertEqual(AppError.serverUnreachable("http://host").recoverySuggestion, "Check that Tailscale is connected and the server is running.")
        XCTAssertEqual(AppError.connectionFailed("oops").recoverySuggestion, "The server may be temporarily unavailable. Try again in a moment.")
        XCTAssertEqual(AppError.authenticationFailed.recoverySuggestion, "Check your credentials in Settings.")
        XCTAssertEqual(AppError.sessionExpired.recoverySuggestion, "Please reconnect to continue.")
        XCTAssertEqual(AppError.messageFailed("oops").recoverySuggestion, "Your message could not be sent. It will be retried automatically.")
        XCTAssertEqual(AppError.imageUploadFailed("oops").recoverySuggestion, "The image could not be uploaded. Try a smaller image or check your connection.")
        XCTAssertEqual(AppError.sshConnectionFailed("oops").recoverySuggestion, "Check SSH credentials in Settings and ensure the server is reachable.")
        XCTAssertEqual(AppError.invalidResponse.recoverySuggestion, "The server returned an unexpected response. Try again.")
    }

    func testRetryableFlags() {
        XCTAssertTrue(AppError.networkUnavailable.isRetryable)
        XCTAssertTrue(AppError.serverUnreachable("http://host").isRetryable)
        XCTAssertTrue(AppError.connectionFailed("timeout").isRetryable)
        XCTAssertTrue(AppError.messageFailed("oops").isRetryable)
        XCTAssertFalse(AppError.authenticationFailed.isRetryable)
        XCTAssertFalse(AppError.sessionExpired.isRetryable)
        XCTAssertFalse(AppError.invalidResponse.isRetryable)
        XCTAssertFalse(AppError.imageUploadFailed("oops").isRetryable)
        XCTAssertFalse(AppError.sshConnectionFailed("oops").isRetryable)
    }

    func testErrorAlertTitles() {
        XCTAssertEqual(ErrorAlert(.networkUnavailable).title, "Network Error")
        XCTAssertEqual(ErrorAlert(.serverUnreachable("http://host")).title, "Connection Error")
        XCTAssertEqual(ErrorAlert(.connectionFailed("timeout")).title, "Connection Error")
        XCTAssertEqual(ErrorAlert(.authenticationFailed).title, "Authentication Error")
        XCTAssertEqual(ErrorAlert(.sessionExpired).title, "Session Expired")
        XCTAssertEqual(ErrorAlert(.messageFailed("oops")).title, "Message Error")
        XCTAssertEqual(ErrorAlert(.imageUploadFailed("oops")).title, "Upload Error")
        XCTAssertEqual(ErrorAlert(.sshConnectionFailed("oops")).title, "SSH Error")
        XCTAssertEqual(ErrorAlert(.invalidResponse).title, "Server Error")
    }
}
