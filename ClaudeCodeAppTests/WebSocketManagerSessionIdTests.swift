import XCTest
@testable import CodingBridge

final class WebSocketManagerSessionIdTests: XCTestCase {
    func testValidateSessionIdReturnsNilForNilOrEmpty() {
        XCTAssertNil(WebSocketManager.validateSessionId(nil))
        XCTAssertNil(WebSocketManager.validateSessionId(""))
    }

    func testValidateSessionIdRejectsNonUUID() {
        XCTAssertNil(WebSocketManager.validateSessionId("not-a-uuid"))
        XCTAssertNil(WebSocketManager.validateSessionId("12345678"))
        XCTAssertNil(WebSocketManager.validateSessionId("cbd6acb5a212489990c4ab11937e21c0"))
    }

    func testValidateSessionIdAcceptsLowercaseUUID() {
        let id = "cbd6acb5-a212-4899-90c4-ab11937e21c0"

        XCTAssertEqual(WebSocketManager.validateSessionId(id), id)
    }

    func testValidateSessionIdAcceptsUppercaseUUID() {
        let id = "CBD6ACB5-A212-4899-90C4-AB11937E21C0"

        XCTAssertEqual(WebSocketManager.validateSessionId(id), id)
    }
}
