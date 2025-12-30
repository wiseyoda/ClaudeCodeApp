import XCTest
@testable import CodingBridge

final class CLISearchExportTypesTests: XCTestCase {
    private func makeSnippet(
        type: String = "user",
        text: String = "Hello world",
        matchStart: Int = 0,
        matchLength: Int = 5
    ) -> CLISearchSnippet {
        CLISearchSnippet(type: type, text: text, matchStart: matchStart, matchLength: matchLength)
    }

    private func makeResult(
        sessionId: String = "session-1",
        projectPath: String = "/Users/dev/project",
        snippets: [CLISearchSnippet] = [CLISearchSnippet(type: "user", text: "Hello", matchStart: 0, matchLength: 5)],
        score: Double = 0.75,
        timestamp: String = "2024-01-02T03:04:05Z"
    ) -> CLISearchResult {
        CLISearchResult(
            sessionId: sessionId,
            projectPath: projectPath,
            snippets: snippets,
            score: score,
            timestamp: timestamp
        )
    }

    private func isoDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: value)
    }

    private func decodeJSON<T: Decodable>(_ type: T.Type, json: String) throws -> T {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(type, from: data)
    }

    func test_searchSnippet_idCombinesTypeAndMatchStart() {
        let snippet = makeSnippet(type: "assistant", matchStart: 7)

        XCTAssertEqual(snippet.id, "assistant-7")
    }

    func test_searchSnippet_matchedTextExtractsSubstring() {
        let snippet = makeSnippet(text: "Hello world", matchStart: 6, matchLength: 5)

        XCTAssertEqual(snippet.matchedText, "world")
    }

    func test_searchSnippet_beforeMatchReturnsPrefix() {
        let snippet = makeSnippet(text: "Hello world", matchStart: 6, matchLength: 5)

        XCTAssertEqual(snippet.beforeMatch, "Hello ")
    }

    func test_searchSnippet_afterMatchReturnsSuffix() {
        let snippet = makeSnippet(text: "Hello world", matchStart: 0, matchLength: 5)

        XCTAssertEqual(snippet.afterMatch, " world")
    }

    func test_searchSnippet_messageTypeIconMapsTypes() {
        let cases: [(String, String)] = [
            ("user", "person.fill"),
            ("assistant", "sparkle"),
            ("system", "gearshape.fill"),
            ("tool_use", "hammer.fill"),
            ("tool_result", "doc.text.fill"),
            ("other", "text.bubble")
        ]

        for (type, icon) in cases {
            let snippet = makeSnippet(type: type)
            XCTAssertEqual(snippet.messageTypeIcon, icon)
        }
    }

    func test_searchResult_idUsesSessionId() {
        let result = makeResult(sessionId: "session-42")

        XCTAssertEqual(result.id, "session-42")
    }

    func test_searchResult_dateParsesValidTimestamp() {
        let timestamp = "2024-01-02T03:04:05Z"
        let result = makeResult(timestamp: timestamp)

        XCTAssertEqual(result.date, isoDate(timestamp))
    }

    func test_searchResult_dateReturnsNilForInvalidTimestamp() {
        let result = makeResult(timestamp: "not-a-date")

        XCTAssertNil(result.date)
    }

    func test_searchResult_projectNameExtractsLastPathComponent() {
        let result = makeResult(projectPath: "/Users/dev/my-project")

        XCTAssertEqual(result.projectName, "my-project")
    }

    func test_searchResult_projectNameHandlesTrailingSlash() {
        let result = makeResult(projectPath: "/Users/dev/my-project/")

        XCTAssertEqual(result.projectName, "my-project")
    }

    func test_searchResult_formattedDateFallsBackWhenInvalid() {
        let result = makeResult(timestamp: "bad-timestamp")

        XCTAssertEqual(result.formattedDate, "bad-timestamp")
    }

    func test_searchResult_snippetReturnsFirstSnippetText() {
        let snippets = [
            makeSnippet(text: "First match", matchStart: 0, matchLength: 5),
            makeSnippet(text: "Second match", matchStart: 0, matchLength: 6)
        ]
        let result = makeResult(snippets: snippets)

        XCTAssertEqual(result.snippet, "First match")
    }

    func test_searchResult_snippetReturnsEmptyWhenNoSnippets() {
        let result = makeResult(snippets: [])

        XCTAssertEqual(result.snippet, "")
    }

    func test_searchResponse_decodesFields() throws {
        let json = """
        {
          "query": "error",
          "total": 2,
          "results": [
            {
              "sessionId": "session-1",
              "projectPath": "/Users/dev/project",
              "snippets": [
                { "type": "user", "text": "hello", "matchStart": 0, "matchLength": 5 }
              ],
              "score": 0.9,
              "timestamp": "2024-01-02T03:04:05Z"
            }
          ],
          "hasMore": true
        }
        """

        let response = try decodeJSON(CLISearchResponse.self, json: json)

        XCTAssertEqual(response.query, "error")
        XCTAssertEqual(response.total, 2)
        XCTAssertEqual(response.results.count, 1)
        XCTAssertEqual(response.results.first?.sessionId, "session-1")
        XCTAssertEqual(response.hasMore, true)
    }

    func test_searchResponse_decodesHasMoreFalse() throws {
        let json = """
        {
          "query": "empty",
          "total": 0,
          "results": [],
          "hasMore": false
        }
        """

        let response = try decodeJSON(CLISearchResponse.self, json: json)

        XCTAssertEqual(response.hasMore, false)
        XCTAssertTrue(response.results.isEmpty)
    }

    func test_searchError_decodesFields() throws {
        let json = """
        {
          "error": "bad_request",
          "message": "Missing query"
        }
        """

        let response = try decodeJSON(CLISearchError.self, json: json)

        XCTAssertEqual(response.error, "bad_request")
        XCTAssertEqual(response.message, "Missing query")
    }

    func test_exportFormat_rawValues() {
        XCTAssertEqual(CLIExportFormat.markdown.rawValue, "markdown")
        XCTAssertEqual(CLIExportFormat.json.rawValue, "json")
    }

    func test_exportFormat_decodesMarkdown() throws {
        let format = try decodeJSON(CLIExportFormat.self, json: "\"markdown\"")

        XCTAssertEqual(format, .markdown)
    }

    func test_exportFormat_decodesJson() throws {
        let format = try decodeJSON(CLIExportFormat.self, json: "\"json\"")

        XCTAssertEqual(format, .json)
    }

    func test_exportFormat_encodesMarkdown() throws {
        let data = try JSONEncoder().encode(CLIExportFormat.markdown)

        XCTAssertEqual(String(decoding: data, as: UTF8.self), "\"markdown\"")
    }

    func test_exportFormat_encodesJson() throws {
        let data = try JSONEncoder().encode(CLIExportFormat.json)

        XCTAssertEqual(String(decoding: data, as: UTF8.self), "\"json\"")
    }

    func test_exportFormat_decodeUnknownThrows() {
        XCTAssertThrowsError(try decodeJSON(CLIExportFormat.self, json: "\"xml\""))
    }

    func test_exportResponse_initStoresFields() {
        let response = CLIExportResponse(sessionId: "session-99", format: .markdown, content: "# Notes")

        XCTAssertEqual(response.sessionId, "session-99")
        XCTAssertEqual(response.format, .markdown)
        XCTAssertEqual(response.content, "# Notes")
    }
}
