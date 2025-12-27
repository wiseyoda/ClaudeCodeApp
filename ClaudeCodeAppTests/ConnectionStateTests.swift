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
}
