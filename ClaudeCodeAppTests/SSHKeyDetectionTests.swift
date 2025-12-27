import XCTest
@testable import ClaudeCodeApp

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
}
