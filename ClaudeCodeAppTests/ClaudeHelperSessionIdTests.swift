import XCTest
@testable import ClaudeCodeApp

final class ClaudeHelperSessionIdTests: XCTestCase {
    func testCreateHelperSessionIdIsDeterministicForSamePath() {
        let path = "/tmp/helper-session"

        let first = ClaudeHelper.createHelperSessionId(for: path)
        let second = ClaudeHelper.createHelperSessionId(for: path)

        XCTAssertEqual(first, second)
    }

    func testCreateHelperSessionIdDiffersForDifferentPaths() {
        let basePath = "/tmp/helper-session"
        let baseId = ClaudeHelper.createHelperSessionId(for: basePath)
        var foundDifferent = false

        for index in 0..<50 {
            let candidate = "\(basePath)-\(index)"
            let candidateId = ClaudeHelper.createHelperSessionId(for: candidate)
            if candidateId != baseId {
                foundDifferent = true
                break
            }
        }

        XCTAssertTrue(foundDifferent)
    }

    func testCreateHelperSessionIdMatchesUUIDFormat() {
        let id = ClaudeHelper.createHelperSessionId(for: "/tmp/helper-session-format")

        XCTAssertNotNil(UUID(uuidString: id))

        let parts = id.split(separator: "-")
        XCTAssertEqual(parts.count, 5)
        XCTAssertTrue(parts[2].hasPrefix("4"))

        if let variant = parts[3].first {
            let allowed = ["8", "9", "a", "b", "A", "B"]
            XCTAssertTrue(allowed.contains(String(variant)))
        } else {
            XCTFail("Expected variant nibble")
        }
    }
}
