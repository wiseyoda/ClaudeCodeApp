import XCTest
@testable import CodingBridge

final class SearchFilterViewsTests: XCTestCase {

    func test_messageFilter_icon_matchesExpected() {
        XCTAssertEqual(MessageFilter.all.icon, "line.3.horizontal.decrease.circle")
        XCTAssertEqual(MessageFilter.user.icon, "person.fill")
        XCTAssertEqual(MessageFilter.assistant.icon, "sparkle")
        XCTAssertEqual(MessageFilter.tools.icon, "wrench.fill")
        XCTAssertEqual(MessageFilter.thinking.icon, "brain")
    }

    func test_messageFilter_matches_all_returnsTrueForAnyRole() {
        let roles: [ChatMessage.Role] = [.user, .assistant, .toolUse, .toolResult, .resultSuccess, .thinking, .system, .error]

        for role in roles {
            XCTAssertTrue(MessageFilter.all.matches(role))
        }
    }

    func test_messageFilter_matches_user_onlyMatchesUser() {
        XCTAssertTrue(MessageFilter.user.matches(.user))
        XCTAssertFalse(MessageFilter.user.matches(.assistant))
    }

    func test_messageFilter_matches_assistant_onlyMatchesAssistant() {
        XCTAssertTrue(MessageFilter.assistant.matches(.assistant))
        XCTAssertFalse(MessageFilter.assistant.matches(.user))
    }

    func test_messageFilter_matches_thinking_onlyMatchesThinking() {
        XCTAssertTrue(MessageFilter.thinking.matches(.thinking))
        XCTAssertFalse(MessageFilter.thinking.matches(.assistant))
    }

    func test_messageFilter_matches_tools_includesToolUseToolResultAndResultSuccess() {
        XCTAssertTrue(MessageFilter.tools.matches(.toolUse))
        XCTAssertTrue(MessageFilter.tools.matches(.toolResult))
        XCTAssertTrue(MessageFilter.tools.matches(.resultSuccess))
        XCTAssertFalse(MessageFilter.tools.matches(.user))
    }

    func test_searchRanges_returnsEmptyWhenSearchTextEmpty() {
        let text = "Hello world"

        XCTAssertTrue(text.searchRanges(of: "").isEmpty)
    }

    func test_searchRanges_findsCaseInsensitiveMatches() {
        let text = "Hello hello HELLO"

        let ranges = text.searchRanges(of: "hello")
        let matches = ranges.map { String(text[$0]) }

        XCTAssertEqual(matches, ["Hello", "hello", "HELLO"])
    }

    func test_searchRanges_handlesNonOverlappingMatches() {
        let text = "aaaa"

        let ranges = text.searchRanges(of: "aa")
        let matches = ranges.map { String(text[$0]) }

        XCTAssertEqual(matches, ["aa", "aa"])
    }

    func test_searchRanges_returnsEmptyWhenNoMatch() {
        let text = "Hello world"

        XCTAssertTrue(text.searchRanges(of: "bye").isEmpty)
    }
}
