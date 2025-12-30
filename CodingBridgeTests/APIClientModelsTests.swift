import XCTest
@testable import CodingBridge

final class APIClientModelsTests: XCTestCase {

    private func decodeAnyCodableValue(_ json: String) throws -> AnyCodableValue {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(AnyCodableValue.self, from: data)
    }

    func test_anyCodableValue_stringValue_returnsString() throws {
        let value = try decodeAnyCodableValue("\"hello\"")

        XCTAssertEqual(value.stringValue, "hello")
    }

    func test_anyCodableValue_stringValue_returnsStdoutWhenPresent() throws {
        let value = try decodeAnyCodableValue("{\"stdout\":\"ok\",\"code\":0}")

        XCTAssertEqual(value.stringValue, "ok")
    }

    func test_anyCodableValue_stringValue_serializesDictionaryWithoutStdout() throws {
        let value = try decodeAnyCodableValue("{\"error\":\"bad\"}")

        guard let dict = value.value as? [String: Any] else {
            XCTFail("Expected dictionary value")
            return
        }

        let data = try JSONSerialization.data(withJSONObject: dict)
        let expected = String(data: data, encoding: .utf8)

        XCTAssertEqual(value.stringValue, expected)
    }

    func test_anyCodableValue_stringValue_fallsBackForInt() throws {
        let value = try decodeAnyCodableValue("42")

        XCTAssertEqual(value.stringValue, "42")
    }
}
