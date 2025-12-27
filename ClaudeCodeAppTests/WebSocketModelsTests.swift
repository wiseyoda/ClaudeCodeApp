import XCTest
@testable import ClaudeCodeApp

final class WebSocketModelsTests: XCTestCase {

    private func decodeJSONDictionary(from data: Data) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dict = object as? [String: Any] else {
            XCTFail("Expected dictionary JSON")
            return [:]
        }
        return dict
    }

    func test_wsCommandOptions_encodesRequiredFieldsOnly() throws {
        let options = WSCommandOptions(
            cwd: "/tmp",
            sessionId: nil,
            model: nil,
            permissionMode: nil,
            images: nil
        )

        let data = try JSONEncoder().encode(options)
        let dict = try decodeJSONDictionary(from: data)

        XCTAssertEqual(dict["cwd"] as? String, "/tmp")
        XCTAssertNil(dict["sessionId"])
        XCTAssertNil(dict["model"])
        XCTAssertNil(dict["permissionMode"])
        XCTAssertNil(dict["images"])
    }

    func test_wsCommandOptions_encodesOptionalFields() throws {
        let images = [WSImage(mediaType: "image/png", base64Data: "AAA")]
        let options = WSCommandOptions(
            cwd: "/workspace",
            sessionId: "session-1",
            model: "claude-3-5-sonnet",
            permissionMode: "plan",
            images: images
        )

        let data = try JSONEncoder().encode(options)
        let dict = try decodeJSONDictionary(from: data)

        XCTAssertEqual(dict["cwd"] as? String, "/workspace")
        XCTAssertEqual(dict["sessionId"] as? String, "session-1")
        XCTAssertEqual(dict["model"] as? String, "claude-3-5-sonnet")
        XCTAssertEqual(dict["permissionMode"] as? String, "plan")

        let imagesArray = dict["images"] as? [[String: Any]]
        XCTAssertEqual(imagesArray?.count, 1)
        XCTAssertEqual(imagesArray?.first?["data"] as? String, "data:image/png;base64,AAA")
    }

    func test_wsClaudeCommand_encodesTypeAndOptions() throws {
        let options = WSCommandOptions(cwd: "/tmp", sessionId: nil, model: nil, permissionMode: nil, images: nil)
        let command = WSClaudeCommand(command: "ls", options: options)

        let data = try JSONEncoder().encode(command)
        let dict = try decodeJSONDictionary(from: data)

        XCTAssertEqual(dict["type"] as? String, "claude-command")
        XCTAssertEqual(dict["command"] as? String, "ls")

        let optionsDict = dict["options"] as? [String: Any]
        XCTAssertEqual(optionsDict?["cwd"] as? String, "/tmp")
    }

    func test_wsAbortSession_encodesDefaults() throws {
        let abort = WSAbortSession(sessionId: "session-42")

        let data = try JSONEncoder().encode(abort)
        let dict = try decodeJSONDictionary(from: data)

        XCTAssertEqual(dict["type"] as? String, "abort-session")
        XCTAssertEqual(dict["sessionId"] as? String, "session-42")
        XCTAssertEqual(dict["provider"] as? String, "claude")
    }

    func test_wsMessage_decodesAllFields() throws {
        let json = """
        {
            "type": "message",
            "sessionId": "session-1",
            "data": {"stdout": "ok"},
            "error": "error",
            "exitCode": 2,
            "isNewSession": true
        }
        """

        let data = Data(json.utf8)
        let message = try JSONDecoder().decode(WSMessage.self, from: data)

        XCTAssertEqual(message.type, "message")
        XCTAssertEqual(message.sessionId, "session-1")
        XCTAssertEqual(message.error, "error")
        XCTAssertEqual(message.exitCode, 2)
        XCTAssertEqual(message.isNewSession, true)
        XCTAssertEqual(message.data?.stringValue, "{\"stdout\":\"ok\"}")
    }

    func test_wsMessage_decodesStringData() throws {
        let json = """
        {
            "type": "message",
            "data": "raw text"
        }
        """

        let data = Data(json.utf8)
        let message = try JSONDecoder().decode(WSMessage.self, from: data)

        XCTAssertEqual(message.data?.stringValue, "raw text")
    }

    func test_wsMessage_decodesDictionaryData() throws {
        let json = """
        {
            "type": "message",
            "data": {"status": "ok"}
        }
        """

        let data = Data(json.utf8)
        let message = try JSONDecoder().decode(WSMessage.self, from: data)

        let dict = message.data?.dictValue
        XCTAssertEqual(dict?["status"] as? String, "ok")
    }

    func test_anyCodable_decodesArray() throws {
        let json = """
        { "value": [1, "two"] }
        """
        let data = Data(json.utf8)

        struct Wrapper: Decodable {
            let value: AnyCodable
        }

        let decoded = try JSONDecoder().decode(Wrapper.self, from: data)
        let array = decoded.value.value as? [Any]

        XCTAssertEqual(array?.count, 2)
        XCTAssertEqual(array?.first as? Int, 1)
        XCTAssertEqual(array?.last as? String, "two")
    }

    func test_anyCodable_decodesDouble() throws {
        let json = """
        { "value": 3.14 }
        """
        let data = Data(json.utf8)

        struct Wrapper: Decodable {
            let value: AnyCodable
        }

        let decoded = try JSONDecoder().decode(Wrapper.self, from: data)

        XCTAssertEqual(decoded.value.value as? Double, 3.14)
    }

    func test_anyCodable_stringValue_forArrayFallsBackToDescription() throws {
        let json = """
        { "value": [1, "two"] }
        """
        let data = Data(json.utf8)

        struct Wrapper: Decodable {
            let value: AnyCodable
        }

        let decoded = try JSONDecoder().decode(Wrapper.self, from: data)

        XCTAssertTrue(decoded.value.stringValue.contains("1"))
        XCTAssertTrue(decoded.value.stringValue.contains("two"))
    }
}
