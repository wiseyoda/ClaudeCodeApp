import XCTest
@testable import CodingBridge

final class TodoListViewTests: XCTestCase {

    func testParseSingleTodo() {
        let content = """
        TodoWrite(todos: [{"content": "Fix bug", "status": "completed", "activeForm": "Fixing bug"}])
        """

        let result = TodoListView.parseTodoContent(content)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual(result?[0].content, "Fix bug")
        XCTAssertEqual(result?[0].status, "completed")
    }

    func testParseMultipleTodos() {
        let content = """
        TodoWrite(todos: [{"content": "Task 1", "status": "completed", "activeForm": "Task 1"}, {"content": "Task 2", "status": "in_progress", "activeForm": "Task 2"}, {"content": "Task 3", "status": "pending", "activeForm": "Task 3"}])
        """

        let result = TodoListView.parseTodoContent(content)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 3)
        XCTAssertEqual(result?[0].status, "completed")
        XCTAssertEqual(result?[1].status, "in_progress")
        XCTAssertEqual(result?[2].status, "pending")
    }

    func testParseNonTodoContent() {
        let content = "Edit(file_path: /test, old_string: a, new_string: b)"

        let result = TodoListView.parseTodoContent(content)

        XCTAssertNil(result)
    }

    func testParseEmptyTodoList() {
        let content = "TodoWrite(todos: [])"

        let result = TodoListView.parseTodoContent(content)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 0)
    }

    func testTodoStatusColors() {
        // Test that different statuses exist
        let content = """
        TodoWrite(todos: [{"content": "Done", "status": "completed", "activeForm": "Done"}, {"content": "Working", "status": "in_progress", "activeForm": "Working"}, {"content": "Waiting", "status": "pending", "activeForm": "Waiting"}])
        """

        let result = TodoListView.parseTodoContent(content)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 3)

        // Verify statuses are parsed correctly
        let statuses = result?.map { $0.status } ?? []
        XCTAssertTrue(statuses.contains("completed"))
        XCTAssertTrue(statuses.contains("in_progress"))
        XCTAssertTrue(statuses.contains("pending"))
    }

    func testParseTodoWithSpecialCharacters() {
        let content = """
        TodoWrite(todos: [{"content": "Fix \\"quoted\\" text", "status": "pending", "activeForm": "Fixing"}])
        """

        let result = TodoListView.parseTodoContent(content)

        XCTAssertNotNil(result)
        // Should handle escaped quotes
        XCTAssertEqual(result?.count, 1)
    }
}
