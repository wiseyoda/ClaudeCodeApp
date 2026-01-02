import XCTest
@testable import CodingBridge

final class ProjectPathEncoderTests: XCTestCase {

    // MARK: - Encode Tests

    func testEncode_simpleAbsolutePath() {
        let path = "/home/dev/project"
        let encoded = ProjectPathEncoder.encode(path)
        XCTAssertEqual(encoded, "-home-dev-project")
    }

    func testEncode_rootPath() {
        let path = "/"
        let encoded = ProjectPathEncoder.encode(path)
        XCTAssertEqual(encoded, "-")
    }

    func testEncode_emptyString() {
        let path = ""
        let encoded = ProjectPathEncoder.encode(path)
        XCTAssertEqual(encoded, "")
    }

    func testEncode_deeplyNestedPath() {
        let path = "/Users/dev/workspace/projects/ios/CodingBridge"
        let encoded = ProjectPathEncoder.encode(path)
        XCTAssertEqual(encoded, "-Users-dev-workspace-projects-ios-CodingBridge")
    }

    func testEncode_pathWithSpaces() {
        let path = "/home/dev/My Project"
        let encoded = ProjectPathEncoder.encode(path)
        // Note: spaces are preserved by encode - consumer may need to handle them
        XCTAssertEqual(encoded, "-home-dev-My Project")
    }

    func testEncode_pathWithHyphens() {
        // This demonstrates the known limitation
        let path = "/home/my-project"
        let encoded = ProjectPathEncoder.encode(path)
        XCTAssertEqual(encoded, "-home-my-project")
    }

    // MARK: - Decode Tests

    func testDecode_simpleEncodedPath() {
        let encoded = "-home-dev-project"
        let decoded = ProjectPathEncoder.decode(encoded)
        XCTAssertEqual(decoded, "/home/dev/project")
    }

    func testDecode_rootPath() {
        let encoded = "-"
        let decoded = ProjectPathEncoder.decode(encoded)
        XCTAssertEqual(decoded, "/")
    }

    func testDecode_emptyString() {
        let encoded = ""
        let decoded = ProjectPathEncoder.decode(encoded)
        XCTAssertEqual(decoded, "")
    }

    func testDecode_deeplyNestedPath() {
        let encoded = "-Users-dev-workspace-projects-ios-CodingBridge"
        let decoded = ProjectPathEncoder.decode(encoded)
        XCTAssertEqual(decoded, "/Users/dev/workspace/projects/ios/CodingBridge")
    }

    // MARK: - Round Trip Tests

    func testRoundTrip_simplePathPreserved() {
        let original = "/home/dev/project"
        let encoded = ProjectPathEncoder.encode(original)
        let decoded = ProjectPathEncoder.decode(encoded)
        XCTAssertEqual(decoded, original)
    }

    func testRoundTrip_deeplyNestedPathPreserved() {
        let original = "/Users/dev/workspace/ios/app"
        let encoded = ProjectPathEncoder.encode(original)
        let decoded = ProjectPathEncoder.decode(encoded)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Hyphen Ambiguity Tests (Known Limitation)

    func testHyphenAmbiguity_demonstrateLimitation() {
        // These two different paths encode to the SAME string
        let pathWithHyphen = "/home/my-project"
        let pathWithSlash = "/home/my/project"

        let encodedWithHyphen = ProjectPathEncoder.encode(pathWithHyphen)
        let encodedWithSlash = ProjectPathEncoder.encode(pathWithSlash)

        // Both encode identically - this is the documented limitation
        XCTAssertEqual(encodedWithHyphen, encodedWithSlash)
        XCTAssertEqual(encodedWithHyphen, "-home-my-project")
    }

    func testHyphenAmbiguity_decodeFavorsSlash() {
        // When decoding, we always assume slashes (lossy for hyphen paths)
        let encoded = "-home-my-project"
        let decoded = ProjectPathEncoder.decode(encoded)

        // Decoding produces the slash interpretation, not the hyphen one
        XCTAssertEqual(decoded, "/home/my/project")
        XCTAssertNotEqual(decoded, "/home/my-project")
    }

    func testHyphenAmbiguity_complexPath() {
        // Real-world example: kebab-case directory names
        let path = "/home/dev/my-ios-app"
        let encoded = ProjectPathEncoder.encode(path)
        let decoded = ProjectPathEncoder.decode(encoded)

        // The path is NOT preserved due to hyphens
        XCTAssertNotEqual(decoded, path)
        XCTAssertEqual(decoded, "/home/dev/my/ios/app")
    }

    // MARK: - Validation Tests

    func testIsValidEncoded_validPath() {
        XCTAssertTrue(ProjectPathEncoder.isValidEncoded("-home-dev-project"))
        XCTAssertTrue(ProjectPathEncoder.isValidEncoded("-"))
        XCTAssertTrue(ProjectPathEncoder.isValidEncoded(""))
    }

    func testIsValidEncoded_invalidPath() {
        // Encoded paths from absolute paths should start with dash
        XCTAssertFalse(ProjectPathEncoder.isValidEncoded("home-dev-project"))
        XCTAssertFalse(ProjectPathEncoder.isValidEncoded("Users-dev"))
    }

    // MARK: - API Compatibility Tests

    func testEncode_matchesCliFormat() {
        // Test cases matching cli-bridge's expected encoding
        let testCases: [(path: String, expected: String)] = [
            ("/Users/me/MyProject", "-Users-me-MyProject"),
            ("/Users/me/My Project", "-Users-me-My Project"),
            ("/Users/me/Project+Name@2024", "-Users-me-Project+Name@2024"),
            ("/test/path", "-test-path"),
        ]

        for testCase in testCases {
            let encoded = ProjectPathEncoder.encode(testCase.path)
            XCTAssertEqual(
                encoded, testCase.expected,
                "Encoding '\(testCase.path)' should produce '\(testCase.expected)'"
            )
        }
    }
}
