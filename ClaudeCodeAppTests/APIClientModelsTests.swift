import XCTest
@testable import CodingBridge

final class APIClientModelsTests: XCTestCase {

    private func decodeAnyCodableValue(_ json: String) throws -> AnyCodableValue {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(AnyCodableValue.self, from: data)
    }

    private func decodeAnyCodableDictionary(_ json: String) throws -> [String: AnyCodableValue] {
        let data = Data(json.utf8)
        return try JSONDecoder().decode([String: AnyCodableValue].self, from: data)
    }

    private func expectedDate(_ timestamp: String, fractional: Bool) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = fractional
            ? [.withInternetDateTime, .withFractionalSeconds]
            : [.withInternetDateTime]
        guard let date = formatter.date(from: timestamp) else {
            fatalError("Failed to parse timestamp: \(timestamp)")
        }
        return date
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

    func test_sessionMessage_toChatMessage_userText() {
        let contentItem = SessionContentItem(type: "text", text: "Hello", thinking: nil, name: nil, input: nil, source: nil, toolUseId: nil, content: nil, isError: nil)
        let content = SessionMessageContent(role: "user", content: [contentItem])
        let message = SessionMessage(type: "user", timestamp: nil, message: content, toolUseResult: nil)

        let result = message.toChatMessage()

        XCTAssertEqual(result?.role, .user)
        XCTAssertEqual(result?.content, "Hello")
    }

    func test_sessionMessage_toChatMessage_userToolResult_usesToolUseResult() throws {
        let contentItem = SessionContentItem(type: "tool_result", text: nil, thinking: nil, name: nil, input: nil, source: nil, toolUseId: nil, content: nil, isError: nil)
        let content = SessionMessageContent(role: "user", content: [contentItem])
        let resultValue = try decodeAnyCodableValue("{\"stdout\":\"done\"}")
        let message = SessionMessage(type: "user", timestamp: nil, message: content, toolUseResult: resultValue)

        let result = message.toChatMessage()

        XCTAssertEqual(result?.role, .toolResult)
        XCTAssertEqual(result?.content, "done")
    }

    func test_sessionMessage_toChatMessage_userToolResult_missingResult_returnsNil() {
        let contentItem = SessionContentItem(type: "tool_result", text: nil, thinking: nil, name: nil, input: nil, source: nil, toolUseId: nil, content: nil, isError: nil)
        let content = SessionMessageContent(role: "user", content: [contentItem])
        let message = SessionMessage(type: "user", timestamp: nil, message: content, toolUseResult: nil)

        XCTAssertNil(message.toChatMessage())
    }

    func test_sessionMessage_toChatMessage_assistantText() {
        let contentItem = SessionContentItem(type: "text", text: "Hi", thinking: nil, name: nil, input: nil, source: nil, toolUseId: nil, content: nil, isError: nil)
        let content = SessionMessageContent(role: "assistant", content: [contentItem])
        let message = SessionMessage(type: "assistant", timestamp: nil, message: content, toolUseResult: nil)

        let result = message.toChatMessage()

        XCTAssertEqual(result?.role, .assistant)
        XCTAssertEqual(result?.content, "Hi")
    }

    func test_sessionMessage_toChatMessage_assistantThinking() {
        let contentItem = SessionContentItem(type: "thinking", text: nil, thinking: "Reasoning", name: nil, input: nil, source: nil, toolUseId: nil, content: nil, isError: nil)
        let content = SessionMessageContent(role: "assistant", content: [contentItem])
        let message = SessionMessage(type: "assistant", timestamp: nil, message: content, toolUseResult: nil)

        let result = message.toChatMessage()

        XCTAssertEqual(result?.role, .thinking)
        XCTAssertEqual(result?.content, "Reasoning")
    }

    func test_sessionMessage_toChatMessage_assistantToolUse() throws {
        let input = try decodeAnyCodableDictionary("{\"path\":\"/tmp\"}")
        let contentItem = SessionContentItem(type: "tool_use", text: nil, thinking: nil, name: "ls", input: input, source: nil, toolUseId: nil, content: nil, isError: nil)
        let content = SessionMessageContent(role: "assistant", content: [contentItem])
        let message = SessionMessage(type: "assistant", timestamp: nil, message: content, toolUseResult: nil)

        let result = message.toChatMessage()

        XCTAssertEqual(result?.role, .toolUse)
        XCTAssertEqual(result?.content.hasPrefix("ls("), true)
        XCTAssertEqual(result?.content.contains("path:"), true)
        XCTAssertEqual(result?.content.hasSuffix(")"), true)
    }

    func test_sessionMessage_toChatMessage_unknownType_returnsNil() {
        let contentItem = SessionContentItem(type: "text", text: "System", thinking: nil, name: nil, input: nil, source: nil, toolUseId: nil, content: nil, isError: nil)
        let content = SessionMessageContent(role: "system", content: [contentItem])
        let message = SessionMessage(type: "system", timestamp: nil, message: content, toolUseResult: nil)

        XCTAssertNil(message.toChatMessage())
    }

    func test_sessionMessage_toChatMessage_parsesFractionalTimestamp() {
        let timestamp = "2025-01-02T03:04:05.678Z"
        let contentItem = SessionContentItem(type: "text", text: "Hello", thinking: nil, name: nil, input: nil, source: nil, toolUseId: nil, content: nil, isError: nil)
        let content = SessionMessageContent(role: "user", content: [contentItem])
        let message = SessionMessage(type: "user", timestamp: timestamp, message: content, toolUseResult: nil)

        let result = message.toChatMessage()

        XCTAssertEqual(result?.timestamp, expectedDate(timestamp, fractional: true))
    }

    func test_sessionMessage_toChatMessage_parsesNonFractionalTimestamp() {
        let timestamp = "2025-01-02T03:04:05Z"
        let contentItem = SessionContentItem(type: "text", text: "Hello", thinking: nil, name: nil, input: nil, source: nil, toolUseId: nil, content: nil, isError: nil)
        let content = SessionMessageContent(role: "user", content: [contentItem])
        let message = SessionMessage(type: "user", timestamp: timestamp, message: content, toolUseResult: nil)

        let result = message.toChatMessage()

        XCTAssertEqual(result?.timestamp, expectedDate(timestamp, fractional: false))
    }

    func test_uploadedImage_base64Data_stripsPrefix() {
        let image = UploadedImage(name: "img", data: "data:image/png;base64,AAA", size: 1, mimeType: "image/png")

        XCTAssertEqual(image.base64Data, "AAA")
    }

    func test_uploadedImage_base64Data_returnsOriginalWhenNoPrefix() {
        let image = UploadedImage(name: "img", data: "AAA", size: 1, mimeType: "image/png")

        XCTAssertEqual(image.base64Data, "AAA")
    }

    func test_uploadedImage_mediaType_prefersDataPrefix() {
        let image = UploadedImage(name: "img", data: "data:image/png;base64,AAA", size: 1, mimeType: "image/jpeg")

        XCTAssertEqual(image.mediaType, "image/png")
    }

    func test_uploadedImage_mediaType_fallsBackToMimeType() {
        let image = UploadedImage(name: "img", data: "AAA", size: 1, mimeType: "image/jpeg")

        XCTAssertEqual(image.mediaType, "image/jpeg")
    }

    func test_apiError_errorDescription_matchesExpected() {
        XCTAssertEqual(APIError.invalidURL.errorDescription, "Invalid server URL")
        XCTAssertEqual(APIError.serverError.errorDescription, "Server error")
        XCTAssertEqual(APIError.decodingError.errorDescription, "Failed to decode response")
        XCTAssertEqual(APIError.authenticationFailed.errorDescription, "Authentication failed")
    }
}
