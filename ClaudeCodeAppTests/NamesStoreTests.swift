import XCTest
@testable import ClaudeCodeApp

final class NamesStoreTests: XCTestCase {
    private let projectKey = "project_custom_names"
    private let sessionKey = "session_custom_names"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: projectKey)
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: projectKey)
        UserDefaults.standard.removeObject(forKey: sessionKey)
        super.tearDown()
    }

    func testProjectNamesStoreStoresAndRetrievesName() {
        let store = ProjectNamesStore.shared
        let path = "/tmp/project-one"

        store.setName("Project One", for: path)

        XCTAssertEqual(store.getName(for: path), "Project One")
        XCTAssertTrue(store.hasCustomName(for: path))
    }

    func testProjectNamesStoreClearsOnNilOrEmpty() {
        let store = ProjectNamesStore.shared
        let path = "/tmp/project-two"

        store.setName("Temp", for: path)
        store.setName(nil, for: path)

        XCTAssertNil(store.getName(for: path))
        XCTAssertFalse(store.hasCustomName(for: path))

        store.setName("Temp", for: path)
        store.setName("", for: path)

        XCTAssertNil(store.getName(for: path))
        XCTAssertFalse(store.hasCustomName(for: path))
    }

    func testProjectNamesStorePersistsMultipleEntries() {
        let store = ProjectNamesStore.shared
        let firstPath = "/tmp/project-alpha"
        let secondPath = "/tmp/project-beta"

        store.setName("Alpha", for: firstPath)
        store.setName("Beta", for: secondPath)

        XCTAssertEqual(store.getName(for: firstPath), "Alpha")
        XCTAssertEqual(store.getName(for: secondPath), "Beta")
    }

    func testSessionNamesStoreStoresAndClearsName() {
        let store = SessionNamesStore.shared
        let sessionId = "session-123"

        XCTAssertNil(store.getName(for: sessionId))

        store.setName("First Session", for: sessionId)
        XCTAssertEqual(store.getName(for: sessionId), "First Session")

        store.setName(nil, for: sessionId)
        XCTAssertNil(store.getName(for: sessionId))
    }

    func testSessionNamesStoreClearsOnEmptyString() {
        let store = SessionNamesStore.shared
        let sessionId = "session-456"

        store.setName("Named", for: sessionId)
        store.setName("", for: sessionId)

        XCTAssertNil(store.getName(for: sessionId))
    }
}
