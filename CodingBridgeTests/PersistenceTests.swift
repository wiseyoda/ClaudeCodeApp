import XCTest
@testable import CodingBridge

@MainActor
final class PersistenceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MessageStore.clearGlobalRecoveryState()
    }

    override func tearDown() {
        MessageStore.clearGlobalRecoveryState()
        super.tearDown()
    }

    // MARK: - MessageStore Global Recovery State

    func test_saveGlobalRecoveryStatePersistsAllFields() {
        MessageStore.saveGlobalRecoveryState(
            wasProcessing: true,
            sessionId: "session-1",
            projectPath: "/tmp/project"
        )

        XCTAssertTrue(MessageStore.wasProcessingOnBackground)
        XCTAssertEqual(MessageStore.lastBackgroundSessionId, "session-1")
        XCTAssertEqual(MessageStore.lastBackgroundProjectPath, "/tmp/project")
    }

    func test_saveGlobalRecoveryStateHandlesNilValues() {
        // First set all values
        MessageStore.saveGlobalRecoveryState(
            wasProcessing: true,
            sessionId: "session-1",
            projectPath: "/tmp/project"
        )

        // Then save with nil values
        MessageStore.saveGlobalRecoveryState(
            wasProcessing: false,
            sessionId: nil,
            projectPath: nil
        )

        XCTAssertFalse(MessageStore.wasProcessingOnBackground)
        XCTAssertNil(MessageStore.lastBackgroundSessionId)
        XCTAssertNil(MessageStore.lastBackgroundProjectPath)
    }

    func test_clearGlobalRecoveryStateResetsAllFields() {
        MessageStore.saveGlobalRecoveryState(
            wasProcessing: true,
            sessionId: "session-1",
            projectPath: "/tmp/project"
        )

        MessageStore.clearGlobalRecoveryState()

        XCTAssertFalse(MessageStore.wasProcessingOnBackground)
        XCTAssertNil(MessageStore.lastBackgroundSessionId)
        XCTAssertNil(MessageStore.lastBackgroundProjectPath)
    }

    func test_wasProcessingOnBackgroundDefaultsToFalse() {
        MessageStore.clearGlobalRecoveryState()

        XCTAssertFalse(MessageStore.wasProcessingOnBackground)
    }

    // MARK: - MessageStore Draft Persistence

    func test_saveDraftPersistsText() {
        MessageStore.saveDraft("Hello world", for: "/tmp/project")

        XCTAssertEqual(MessageStore.loadDraft(for: "/tmp/project"), "Hello world")
    }

    func test_saveDraftEmptyStringClearsDraft() {
        MessageStore.saveDraft("Hello", for: "/tmp/project")
        MessageStore.saveDraft("", for: "/tmp/project")

        XCTAssertEqual(MessageStore.loadDraft(for: "/tmp/project"), "")
    }

    func test_clearDraftRemovesDraft() {
        MessageStore.saveDraft("Hello", for: "/tmp/project")
        MessageStore.clearDraft(for: "/tmp/project")

        XCTAssertEqual(MessageStore.loadDraft(for: "/tmp/project"), "")
    }

    func test_draftIsolatedPerProject() {
        MessageStore.saveDraft("Project 1 draft", for: "/tmp/project1")
        MessageStore.saveDraft("Project 2 draft", for: "/tmp/project2")

        XCTAssertEqual(MessageStore.loadDraft(for: "/tmp/project1"), "Project 1 draft")
        XCTAssertEqual(MessageStore.loadDraft(for: "/tmp/project2"), "Project 2 draft")
    }
}
