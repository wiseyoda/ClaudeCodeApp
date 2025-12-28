import XCTest
@testable import CodingBridge

final class DiffViewTests: XCTestCase {

    func testParseBasicEdit() {
        let content = "Edit(file_path: /test/file.swift, old_string: hello, new_string: world)"

        let result = DiffView.parseEditContent(content)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.old, "hello")
        XCTAssertEqual(result?.new, "world")
    }

    func testParseEditWithReplaceAll() {
        let content = "Edit(file_path: /test/file.swift, old_string: foo, new_string: bar, replace_all: true)"

        let result = DiffView.parseEditContent(content)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.old, "foo")
        XCTAssertEqual(result?.new, "bar")
    }

    func testParseEditWithMultilineStrings() {
        let content = """
        Edit(file_path: /test/file.swift, old_string: line1
        line2
        line3, new_string: new1
        new2)
        """

        let result = DiffView.parseEditContent(content)

        XCTAssertNotNil(result)
        XCTAssertTrue(result?.old.contains("line1") ?? false)
        XCTAssertTrue(result?.old.contains("line2") ?? false)
        XCTAssertTrue(result?.new.contains("new1") ?? false)
    }

    func testParseNonEditContent() {
        let content = "Grep(pattern: foo, path: /test)"

        let result = DiffView.parseEditContent(content)

        XCTAssertNil(result)
    }

    func testParseEmptyStrings() {
        let content = "Edit(file_path: /test/file.swift, old_string: , new_string: )"

        let result = DiffView.parseEditContent(content)

        // Should return nil when both strings are empty
        XCTAssertNil(result)
    }

    func testParseWithOnlyNewString() {
        let content = "Edit(file_path: /test/file.swift, old_string: , new_string: added content)"

        let result = DiffView.parseEditContent(content)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.new, "added content")
    }
}
