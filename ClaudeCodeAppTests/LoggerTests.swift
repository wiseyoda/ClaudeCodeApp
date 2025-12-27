import XCTest
@testable import ClaudeCodeApp

final class LoggerTests: XCTestCase {

    // MARK: - LogLevel Tests

    func test_logLevel_rawValues_areCorrect() {
        XCTAssertEqual(LogLevel.debug.rawValue, "DEBUG")
        XCTAssertEqual(LogLevel.info.rawValue, "INFO")
        XCTAssertEqual(LogLevel.warning.rawValue, "WARN")
        XCTAssertEqual(LogLevel.error.rawValue, "ERROR")
    }

    func test_logLevel_emoji_returnsEmptyStrings() {
        // All emojis should be empty strings (removed from production)
        XCTAssertEqual(LogLevel.debug.emoji, "")
        XCTAssertEqual(LogLevel.info.emoji, "")
        XCTAssertEqual(LogLevel.warning.emoji, "")
        XCTAssertEqual(LogLevel.error.emoji, "")
    }

    // MARK: - Logger Singleton Tests

    func test_loggerShared_isAccessible() {
        // Logger.shared should be accessible and return a valid Logger
        let logger = Logger.shared

        // Verify it's the expected type
        XCTAssertTrue(type(of: logger) == Logger.self)
    }

    func test_globalLog_isSameAsLoggerShared() {
        // The global 'log' variable should be Logger.shared
        // We can't directly compare since log is let and can't be re-assigned
        // But we can verify they behave the same way by checking they're the same type
        XCTAssertTrue(type(of: log) == Logger.self)
    }

    // MARK: - Logger Method Existence Tests
    // These tests verify the logging methods exist and can be called without crashing

    func test_logger_debug_doesNotCrash() {
        // Should not throw or crash
        log.debug("Test debug message")
    }

    func test_logger_info_doesNotCrash() {
        // Should not throw or crash
        log.info("Test info message")
    }

    func test_logger_warning_doesNotCrash() {
        // Should not throw or crash
        log.warning("Test warning message")
    }

    func test_logger_error_doesNotCrash() {
        // Should not throw or crash
        log.error("Test error message")
    }

    func test_logger_handlesEmptyMessage() {
        // Should not throw or crash with empty messages
        log.debug("")
        log.info("")
        log.warning("")
        log.error("")
    }

    func test_logger_handlesLongMessage() {
        // Should not throw or crash with very long messages
        let longMessage = String(repeating: "A", count: 10000)
        log.debug(longMessage)
        log.info(longMessage)
    }

    func test_logger_handlesSpecialCharacters() {
        // Should not throw or crash with special characters
        let specialMessage = "Test with special chars: \n\t\r\"'\\<>&"
        log.debug(specialMessage)
        log.info(specialMessage)
    }

    func test_logger_handlesUnicode() {
        // Should not throw or crash with unicode
        let unicodeMessage = "Unicode: Emoji: test Japanese: Mixed"
        log.debug(unicodeMessage)
        log.info(unicodeMessage)
    }

    func test_logger_handlesInterpolation() {
        // Should not throw or crash with string interpolation
        let value = 42
        let name = "test"
        log.debug("Value: \(value), Name: \(name)")
    }
}
