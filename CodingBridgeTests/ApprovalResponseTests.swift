import XCTest
@testable import CodingBridge

final class ApprovalResponseTests: XCTestCase {
    func testApprovalResponseEncodesAllow() throws {
        let response = ApprovalResponse(requestId: "req-allow", allow: true, alwaysAllow: false)
        let json = try decodeJSON(response)

        XCTAssertEqual(json["type"] as? String, "permission-response")
        XCTAssertEqual(json["requestId"] as? String, "req-allow")
        XCTAssertEqual(json["decision"] as? String, "allow")
        XCTAssertEqual(json["alwaysAllow"] as? Bool, false)
    }

    func testApprovalResponseEncodesAlwaysAllow() throws {
        let response = ApprovalResponse(requestId: "req-always", allow: true, alwaysAllow: true)
        let json = try decodeJSON(response)

        XCTAssertEqual(json["decision"] as? String, "allow")
        XCTAssertEqual(json["alwaysAllow"] as? Bool, true)
    }

    func testApprovalResponseEncodesDeny() throws {
        let response = ApprovalResponse(requestId: "req-deny", allow: false, alwaysAllow: false)
        let json = try decodeJSON(response)

        XCTAssertEqual(json["decision"] as? String, "deny")
        XCTAssertEqual(json["alwaysAllow"] as? Bool, false)
    }

    private func decodeJSON(_ response: ApprovalResponse) throws -> [String: Any] {
        let data = try JSONEncoder().encode(response)
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        return object as? [String: Any] ?? [:]
    }
}
