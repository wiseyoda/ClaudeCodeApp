import XCTest
@testable import ClaudeCodeApp

@MainActor
final class ArchivedProjectsStoreTests: XCTestCase {
    /// Unique UserDefaults key for test isolation
    private var testStorageKey: String!

    override func setUp() {
        super.setUp()
        // Generate a unique key for each test to prevent interference
        testStorageKey = "archived_project_paths_test_\(UUID().uuidString)"
    }

    override func tearDown() {
        // Clean up the test UserDefaults key
        UserDefaults.standard.removeObject(forKey: testStorageKey)
        super.tearDown()
    }

    // MARK: - Archive/Unarchive Tests

    func test_isArchived_returnsFalseForNewPath() {
        let store = ArchivedProjectsStore()

        XCTAssertFalse(store.isArchived("/unique/path/\(UUID().uuidString)"))
    }

    func test_archive_addsPathToArchivedSet() {
        let store = ArchivedProjectsStore()
        let testPath = "/test/project/\(UUID().uuidString)"

        store.archive(testPath)

        XCTAssertTrue(store.isArchived(testPath))
        XCTAssertTrue(store.archivedPaths.contains(testPath))
    }

    func test_unarchive_removesPathFromArchivedSet() {
        let store = ArchivedProjectsStore()
        let testPath = "/test/project/\(UUID().uuidString)"

        store.archive(testPath)
        XCTAssertTrue(store.isArchived(testPath))

        store.unarchive(testPath)

        XCTAssertFalse(store.isArchived(testPath))
        XCTAssertFalse(store.archivedPaths.contains(testPath))
    }

    func test_toggleArchive_archivesWhenNotArchived() {
        let store = ArchivedProjectsStore()
        let testPath = "/test/project/\(UUID().uuidString)"

        XCTAssertFalse(store.isArchived(testPath))

        store.toggleArchive(testPath)

        XCTAssertTrue(store.isArchived(testPath))
    }

    func test_toggleArchive_unarchivesWhenArchived() {
        let store = ArchivedProjectsStore()
        let testPath = "/test/project/\(UUID().uuidString)"

        store.archive(testPath)
        XCTAssertTrue(store.isArchived(testPath))

        store.toggleArchive(testPath)

        XCTAssertFalse(store.isArchived(testPath))
    }

    func test_archiveMultiplePaths_tracksAllPaths() {
        let store = ArchivedProjectsStore()
        let path1 = "/project/one/\(UUID().uuidString)"
        let path2 = "/project/two/\(UUID().uuidString)"
        let path3 = "/project/three/\(UUID().uuidString)"

        // Record initial count before adding
        let initialCount = store.archivedPaths.count

        store.archive(path1)
        store.archive(path2)
        store.archive(path3)

        XCTAssertTrue(store.isArchived(path1))
        XCTAssertTrue(store.isArchived(path2))
        XCTAssertTrue(store.isArchived(path3))
        // Verify 3 new paths were added
        XCTAssertEqual(store.archivedPaths.count, initialCount + 3)
    }

    func test_archiveSamePathTwice_doesNotDuplicate() {
        let store = ArchivedProjectsStore()
        let testPath = "/test/project/\(UUID().uuidString)"

        store.archive(testPath)
        store.archive(testPath)

        // Set semantics: should only have one entry
        let matchingPaths = store.archivedPaths.filter { $0 == testPath }
        XCTAssertEqual(matchingPaths.count, 1)
    }

    func test_unarchiveNonExistentPath_doesNotCrash() {
        let store = ArchivedProjectsStore()
        let testPath = "/never/archived/\(UUID().uuidString)"

        // Should not throw or crash
        store.unarchive(testPath)

        XCTAssertFalse(store.isArchived(testPath))
    }

    // MARK: - Path Edge Cases

    func test_archive_handlesPathsWithSpecialCharacters() {
        let store = ArchivedProjectsStore()
        let testPath = "/Users/dev/My Project (v2)/test-\(UUID().uuidString)"

        store.archive(testPath)

        XCTAssertTrue(store.isArchived(testPath))
    }

    func test_archive_handlesEmptyPath() {
        let store = ArchivedProjectsStore()

        store.archive("")

        XCTAssertTrue(store.isArchived(""))
    }

    func test_archive_handlesPathWithTrailingSlash() {
        let store = ArchivedProjectsStore()
        let path1 = "/project/path"
        let path2 = "/project/path/"

        store.archive(path1)

        // These are different strings, so they should be tracked separately
        XCTAssertTrue(store.isArchived(path1))
        XCTAssertFalse(store.isArchived(path2))
    }
}
