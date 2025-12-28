import XCTest
@testable import ClaudeCodeApp

final class ConnectionStateTests: XCTestCase {
    func testIsConnectedOnlyForConnectedState() {
        XCTAssertTrue(ConnectionState.connected.isConnected)
        XCTAssertFalse(ConnectionState.disconnected.isConnected)
        XCTAssertFalse(ConnectionState.connecting.isConnected)
        XCTAssertFalse(ConnectionState.reconnecting(attempt: 2).isConnected)
    }

    func testIsConnectingForConnectingAndReconnectingStates() {
        XCTAssertTrue(ConnectionState.connecting.isConnecting)
        XCTAssertTrue(ConnectionState.reconnecting(attempt: 1).isConnecting)
        XCTAssertFalse(ConnectionState.connected.isConnecting)
        XCTAssertFalse(ConnectionState.disconnected.isConnecting)
    }

    func testDisplayTextMatchesState() {
        let cases: [(ConnectionState, String)] = [
            (.disconnected, "Disconnected"),
            (.connecting, "Connecting..."),
            (.connected, "Connected"),
            (.reconnecting(attempt: 3), "Reconnecting (3)...")
        ]

        for (state, expected) in cases {
            XCTAssertEqual(state.displayText, expected)
        }
    }

    func testAccessibilityLabelMatchesState() {
        let cases: [(ConnectionState, String)] = [
            (.disconnected, "Server disconnected"),
            (.connecting, "Connecting to server"),
            (.connected, "Connected to server"),
            (.reconnecting(attempt: 2), "Reconnecting to server, attempt 2")
        ]

        for (state, expected) in cases {
            XCTAssertEqual(state.accessibilityLabel, expected)
        }
    }

    // MARK: - Session ID Validation Tests

    func testValidateSessionIdAcceptsValidUUIDs() {
        let validUUIDs = [
            "cbd6acb5-a212-4899-90c4-ab11937e21c0",
            "ABCD1234-5678-9ABC-DEF0-123456789ABC",
            "00000000-0000-0000-0000-000000000000"
        ]

        for uuid in validUUIDs {
            XCTAssertEqual(WebSocketManager.validateSessionId(uuid), uuid,
                          "Should accept valid UUID: \(uuid)")
        }
    }

    func testValidateSessionIdRejectsInvalidFormats() {
        let invalidSessionIds = [
            "",
            "not-a-uuid",
            "cbd6acb5-a212-4899-90c4",  // Too short
            "cbd6acb5-a212-4899-90c4-ab11937e21c0-extra",  // Too long
            "cbd6acb5a2124899-90c4-ab11937e21c0",  // Missing hyphen
            "gggggggg-gggg-gggg-gggg-gggggggggggg",  // Invalid hex chars
            "12345678-1234-1234-1234-1234567890123"  // One digit too many in last section
        ]

        for id in invalidSessionIds {
            XCTAssertNil(WebSocketManager.validateSessionId(id),
                        "Should reject invalid session ID: \(id)")
        }
    }

    func testValidateSessionIdReturnsNilForNil() {
        XCTAssertNil(WebSocketManager.validateSessionId(nil))
    }
}
