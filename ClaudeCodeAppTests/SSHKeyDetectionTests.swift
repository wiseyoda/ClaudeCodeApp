import XCTest
@testable import CodingBridge

final class SSHKeyDetectionTests: XCTestCase {
    func testDetectPrivateKeyTypeRsaPrefix() throws {
        let content = "-----BEGIN RSA PRIVATE KEY-----\nabc"

        let type = try SSHKeyDetection.detectPrivateKeyType(from: content)

        XCTAssertEqual(type, .rsa)
        XCTAssertTrue(type.isSupported)
    }

    func testDetectPrivateKeyTypeOpenSSHed25519() throws {
        let payload = "ssh-ed25519"
        let base64 = Data(payload.utf8).base64EncodedString()
        let content = """
        -----BEGIN OPENSSH PRIVATE KEY-----
        \(base64)
        -----END OPENSSH PRIVATE KEY-----
        """

        let type = try SSHKeyDetection.detectPrivateKeyType(from: content)

        XCTAssertEqual(type, .ed25519)
        XCTAssertTrue(type.isSupported)
    }

    func testDetectPrivateKeyTypeOpenSSHUnknown() throws {
        let payload = "no-known-key-type"
        let base64 = Data(payload.utf8).base64EncodedString()
        let content = """
        -----BEGIN OPENSSH PRIVATE KEY-----
        \(base64)
        -----END OPENSSH PRIVATE KEY-----
        """

        let type = try SSHKeyDetection.detectPrivateKeyType(from: content)

        XCTAssertEqual(type, .unknown)
        XCTAssertFalse(type.isSupported)
    }

    func testDetectPrivateKeyTypeThrowsOnInvalidFormat() {
        XCTAssertThrowsError(try SSHKeyDetection.detectPrivateKeyType(from: "not a key")) { error in
            guard case SSHError.keyParseError(let message) = error else {
                return XCTFail("Expected keyParseError")
            }
            XCTAssertEqual(message, "Unrecognized key format")
        }
    }

    func testIsValidKeyFormatAcceptsKnownPrefixes() {
        let prefixes = [
            "-----BEGIN OPENSSH PRIVATE KEY-----",
            "-----BEGIN RSA PRIVATE KEY-----",
            "-----BEGIN EC PRIVATE KEY-----",
            "-----BEGIN PRIVATE KEY-----",
            "-----BEGIN ENCRYPTED PRIVATE KEY-----"
        ]

        for prefix in prefixes {
            XCTAssertTrue(SSHKeyDetection.isValidKeyFormat(" \n\(prefix)\n"))
        }
    }

    func testIsValidKeyFormatRejectsUnknownPrefix() {
        XCTAssertFalse(SSHKeyDetection.isValidKeyFormat("-----BEGIN SOMETHING ELSE-----"))
    }

    func testSSHErrorDescriptions() {
        XCTAssertEqual(SSHError.connectionFailed("timeout").errorDescription, "Connection failed: timeout")
        XCTAssertEqual(SSHError.authenticationFailed.errorDescription, "Authentication failed")
        XCTAssertEqual(SSHError.notConnected.errorDescription, "Not connected")
        XCTAssertEqual(SSHError.keyNotFound("/tmp/key").errorDescription, "SSH key not found: /tmp/key")
        XCTAssertEqual(SSHError.unsupportedKeyType("ecdsa").errorDescription, "Unsupported key type: ecdsa")
        XCTAssertEqual(SSHError.keyParseError("bad base64").errorDescription, "Failed to parse key: bad base64")
    }

    func testDetectKeyWithLeadingWhitespace() throws {
        let payload = "ssh-ed25519"
        let base64 = Data(payload.utf8).base64EncodedString()
        // Lines have leading whitespace (common when pasting)
        let content = """
        -----BEGIN OPENSSH PRIVATE KEY-----
            \(base64)
        -----END OPENSSH PRIVATE KEY-----
        """

        let type = try SSHKeyDetection.detectPrivateKeyType(from: content)

        XCTAssertEqual(type, .ed25519)
    }

    func testDetectKeyWithTrailingHyphen() throws {
        // iOS text hyphenation adds trailing hyphens to wrapped lines
        let payload = "ssh-ed25519"
        let base64 = Data(payload.utf8).base64EncodedString()
        // Split base64 and add trailing hyphen like iOS would
        let half = base64.count / 2
        let part1 = String(base64.prefix(half)) + "-"  // iOS hyphenation
        let part2 = String(base64.suffix(from: base64.index(base64.startIndex, offsetBy: half)))
        let content = """
        -----BEGIN OPENSSH PRIVATE KEY-----
        \(part1)
        \(part2)
        -----END OPENSSH PRIVATE KEY-----
        """

        let type = try SSHKeyDetection.detectPrivateKeyType(from: content)

        XCTAssertEqual(type, .ed25519)
    }

    func testDetectKeyStripsAllNonBase64Characters() throws {
        // Simulate heavily corrupted paste with multiple issues
        let payload = "ssh-ed25519"
        let base64 = Data(payload.utf8).base64EncodedString()
        // Add all kinds of garbage: hyphens, extra whitespace, random chars
        let content = """
        -----BEGIN OPENSSH PRIVATE KEY-----
           \(base64.prefix(4))-
           \(base64.dropFirst(4))
        -----END OPENSSH PRIVATE KEY-----
        """

        let type = try SSHKeyDetection.detectPrivateKeyType(from: content)

        XCTAssertEqual(type, .ed25519)
    }

    func testDetectKeyRecoversTruncatedFirstCharacter() throws {
        // Real OpenSSH ed25519 key base64 (starts with b3Bl... = "openssh-key-v1")
        let validBase64 = "b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZWQyNTUxOQAAACAtu6itu6aGnHV8H/RGd+O1hyaxegB3AxylkYJB5+RS4wAAAJASqA+xEqgPsQAAAAtzc2gtZWQyNTUxOQAAACAtu6itu6aGnHV8H/RGd+O1hyaxegB3AxylkYJB5+RS4wAAAECevnrInpGhf5DhJTcFEvBlkWLqhpX9Xisf+SZRb0Bt7S27qK27poacdXwf9EZ347WHJrF6AHcDHKWRgkHn5FLjAAAACXRlc3RAdGVzdAECAwQ="

        // Simulate iOS TextEditor truncating the first 'b' character
        let truncatedBase64 = String(validBase64.dropFirst())
        let content = """
        -----BEGIN OPENSSH PRIVATE KEY-----
        \(truncatedBase64)
        -----END OPENSSH PRIVATE KEY-----
        """

        // Should recover by prepending 'b' and detect ed25519
        let type = try SSHKeyDetection.detectPrivateKeyType(from: content)

        XCTAssertEqual(type, .ed25519)
    }

    func testNormalizeSSHKeyRecoversTruncation() {
        // Real OpenSSH ed25519 key base64
        let validBase64 = "b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZWQyNTUxOQAAACAtu6itu6aGnHV8H/RGd+O1hyaxegB3AxylkYJB5+RS4wAAAJASqA+xEqgPsQAAAAtzc2gtZWQyNTUxOQAAACAtu6itu6aGnHV8H/RGd+O1hyaxegB3AxylkYJB5+RS4wAAAECevnrInpGhf5DhJTcFEvBlkWLqhpX9Xisf+SZRb0Bt7S27qK27poacdXwf9EZ347WHJrF6AHcDHKWRgkHn5FLjAAAACXRlc3RAdGVzdAECAwQ="

        // Simulate truncation
        let truncatedBase64 = String(validBase64.dropFirst())
        let truncatedContent = """
        -----BEGIN OPENSSH PRIVATE KEY-----
        \(truncatedBase64)
        -----END OPENSSH PRIVATE KEY-----
        """

        // Normalize should recover the missing 'b'
        let normalized = SSHKeyDetection.normalizeSSHKey(truncatedContent)

        // The normalized content should contain the full base64 starting with 'b'
        XCTAssertTrue(normalized.contains("b3BlbnNzaC1rZXktdjE"))
    }
}
