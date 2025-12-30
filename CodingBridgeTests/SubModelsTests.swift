import XCTest
@testable import CodingBridge

final class SubModelsTests: XCTestCase {
    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func decodeJSON<T: Decodable>(_ type: T.Type, json: String) throws -> T {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(type, from: data)
    }

    private func tinyPNGData() -> Data {
        let base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg=="
        return Data(base64Encoded: base64) ?? Data()
    }

    // MARK: - GitModels

    func test_gitStatus_iconsForAdditionalCases() {
        let cases: [(GitStatus, String)] = [
            (.unknown, "circle.dotted"),
            (.checking, "circle.dotted"),
            (.notGitRepo, "minus.circle"),
            (.dirty, "exclamationmark.triangle.fill"),
            (.diverged, "arrow.up.arrow.down.circle.fill")
        ]

        for (status, icon) in cases {
            XCTAssertEqual(status.icon, icon)
        }
    }

    func test_gitStatus_colorNameForCases() {
        let cases: [(GitStatus, String)] = [
            (.unknown, "gray"),
            (.checking, "gray"),
            (.notGitRepo, "gray"),
            (.dirty, "orange"),
            (.diverged, "orange")
        ]

        for (status, color) in cases {
            XCTAssertEqual(status.colorName, color)
        }
    }

    func test_gitStatus_hasLocalChanges() {
        XCTAssertTrue(GitStatus.dirty.hasLocalChanges)
        XCTAssertTrue(GitStatus.ahead(1).hasLocalChanges)
        XCTAssertTrue(GitStatus.dirtyAndAhead.hasLocalChanges)
        XCTAssertTrue(GitStatus.diverged.hasLocalChanges)
        XCTAssertFalse(GitStatus.clean.hasLocalChanges)
        XCTAssertFalse(GitStatus.notGitRepo.hasLocalChanges)
    }

    func test_gitStatus_canAutoPullOnlyBehind() {
        XCTAssertTrue(GitStatus.behind(2).canAutoPull)
        XCTAssertFalse(GitStatus.ahead(1).canAutoPull)
        XCTAssertFalse(GitStatus.clean.canAutoPull)
    }

    func test_subRepo_equalityIgnoresStatus() {
        let one = SubRepo(relativePath: "a", fullPath: "/tmp/a", status: .clean)
        let two = SubRepo(relativePath: "a", fullPath: "/tmp/a", status: .dirty)

        XCTAssertEqual(one, two)
    }

    func test_multiRepoStatus_summaryEmpty() {
        let status = MultiRepoStatus(subRepos: [])

        XCTAssertEqual(status.summary, "")
        XCTAssertFalse(status.hasSubRepos)
    }

    func test_multiRepoStatus_summaryAllClean() {
        let repos = [
            SubRepo(relativePath: "a", fullPath: "/a", status: .clean),
            SubRepo(relativePath: "b", fullPath: "/b", status: .clean)
        ]
        let status = MultiRepoStatus(subRepos: repos)

        XCTAssertEqual(status.summary, "all clean")
    }

    func test_multiRepoStatus_summaryCountsInOrder() {
        let repos = [
            SubRepo(relativePath: "a", fullPath: "/a", status: .dirty),
            SubRepo(relativePath: "b", fullPath: "/b", status: .dirtyAndAhead),
            SubRepo(relativePath: "c", fullPath: "/c", status: .behind(2)),
            SubRepo(relativePath: "d", fullPath: "/d", status: .ahead(1)),
            SubRepo(relativePath: "e", fullPath: "/e", status: .diverged),
            SubRepo(relativePath: "f", fullPath: "/f", status: .error("boom"))
        ]
        let status = MultiRepoStatus(subRepos: repos)

        XCTAssertEqual(status.summary, "2 dirty, 1 behind, 1 ahead, 1 diverged, 1 error")
    }

    func test_multiRepoStatus_summaryFallbacksToRepoCount() {
        let repos = [
            SubRepo(relativePath: "a", fullPath: "/a", status: .unknown),
            SubRepo(relativePath: "b", fullPath: "/b", status: .checking)
        ]
        let status = MultiRepoStatus(subRepos: repos)

        XCTAssertEqual(status.summary, "2 repos")
    }

    func test_multiRepoStatus_worstStatusPriority() {
        let repos = [
            SubRepo(relativePath: "a", fullPath: "/a", status: .dirty),
            SubRepo(relativePath: "b", fullPath: "/b", status: .error("boom"))
        ]
        let status = MultiRepoStatus(subRepos: repos)

        XCTAssertEqual(status.worstStatus, .error("sub-repo error"))
    }

    func test_multiRepoStatus_hasActionableItems() {
        let cleanStatus = MultiRepoStatus(subRepos: [SubRepo(relativePath: "a", fullPath: "/a", status: .clean)])
        XCTAssertFalse(cleanStatus.hasActionableItems)

        let actionableStatus = MultiRepoStatus(subRepos: [SubRepo(relativePath: "b", fullPath: "/b", status: .behind(1))])
        XCTAssertTrue(actionableStatus.hasActionableItems)
    }

    func test_multiRepoStatus_pullableCountCountsBehind() {
        let repos = [
            SubRepo(relativePath: "a", fullPath: "/a", status: .behind(1)),
            SubRepo(relativePath: "b", fullPath: "/b", status: .behind(2)),
            SubRepo(relativePath: "c", fullPath: "/c", status: .ahead(1))
        ]
        let status = MultiRepoStatus(subRepos: repos)

        XCTAssertEqual(status.pullableCount, 2)
        XCTAssertTrue(status.hasSubRepos)
    }

    // MARK: - ImageAttachment

    func test_imageAttachment_initDetectsMimeType() {
        let attachment = ImageAttachment(data: tinyPNGData())

        XCTAssertEqual(attachment.mimeType, "image/png")
    }

    func test_imageAttachment_dataForSendingUsesProcessedData() {
        let original = Data([0x00, 0x01])
        var attachment = ImageAttachment(data: original)
        let processed = Data([0x02, 0x03, 0x04])
        attachment.processedData = processed

        XCTAssertEqual(attachment.dataForSending, processed)
        XCTAssertEqual(attachment.sizeBytes, processed.count)
    }

    func test_imageAttachment_shouldUploadUsesThreshold() {
        let largeData = Data(repeating: 0x00, count: ImageAttachment.uploadThreshold + 1)
        let attachment = ImageAttachment(data: largeData)

        XCTAssertTrue(attachment.shouldUpload)
    }

    func test_imageAttachment_sizeStringMatchesFormatter() {
        let data = Data(repeating: 0x00, count: 2048)
        let attachment = ImageAttachment(data: data)
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file

        XCTAssertEqual(attachment.sizeString, formatter.string(fromByteCount: Int64(data.count)))
    }

    func test_imageAttachment_equatableUsesId() {
        let id = UUID()
        let first = ImageAttachment(id: id, data: Data([0x00]))
        let second = ImageAttachment(id: id, data: Data([0x01]))
        let third = ImageAttachment(data: Data([0x00]))

        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first, third)
    }

    func test_imageAttachment_uploadThresholdConstant() {
        XCTAssertEqual(ImageAttachment.uploadThreshold, 500_000)
    }

    // MARK: - TaskState

    func test_taskStatus_displayTextAndColor() {
        let approval = BackgroundApprovalRequest(
            id: "req-1",
            toolName: "Read",
            summary: "Read file",
            details: nil,
            expiresAt: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(TaskStatus.idle.displayText, "Ready")
        XCTAssertEqual(TaskStatus.processing(operation: nil).displayText, "Working...")
        XCTAssertEqual(TaskStatus.awaitingApproval(request: approval).displayText, "Needs approval: Read")
        XCTAssertEqual(TaskStatus.awaitingAnswer(question: BackgroundUserQuestion(id: "q", question: "Q")).displayText, "Question pending")
        XCTAssertEqual(TaskStatus.completed(result: .success(summary: nil)).displayText, "Complete")
        XCTAssertEqual(TaskStatus.error(message: "Oops").displayText, "Error: Oops")

        XCTAssertEqual(TaskStatus.idle.color, .gray)
        XCTAssertEqual(TaskStatus.processing(operation: "Op").color, .blue)
        XCTAssertEqual(TaskStatus.awaitingApproval(request: approval).color, .orange)
        XCTAssertEqual(TaskStatus.awaitingAnswer(question: BackgroundUserQuestion(id: "q", question: "Q")).color, .purple)
        XCTAssertEqual(TaskStatus.completed(result: .success(summary: nil)).color, .green)
        XCTAssertEqual(TaskStatus.completed(result: .failure(error: "boom")).color, .red)
    }

    func test_taskStatus_requiresUserActionFlags() {
        XCTAssertTrue(TaskStatus.awaitingApproval(request: BackgroundApprovalRequest(id: "1", toolName: "Read", summary: "Read")).requiresUserAction)
        XCTAssertTrue(TaskStatus.awaitingAnswer(question: BackgroundUserQuestion(id: "q", question: "Q")).requiresUserAction)
        XCTAssertFalse(TaskStatus.processing(operation: "Op").requiresUserAction)
    }

    func test_taskStatus_roundTripCodable() throws {
        let approval = BackgroundApprovalRequest(
            id: "req-1",
            toolName: "Read",
            summary: "Read file",
            details: "details",
            expiresAt: Date(timeIntervalSince1970: 42)
        )
        let question = BackgroundUserQuestion(id: "q1", question: "Q?", options: ["A", "B"])

        let cases: [TaskStatus] = [
            .idle,
            .processing(operation: "Working"),
            .awaitingApproval(request: approval),
            .awaitingAnswer(question: question),
            .completed(result: .success(summary: "OK")),
            .error(message: "Bad")
        ]

        for status in cases {
            let decoded = try roundTrip(status)
            XCTAssertEqual(decoded, status)
        }
    }

    func test_taskStatus_decodeUnknownTypeFallsBackToIdle() throws {
        let json = """
        { "type": "unknown" }
        """
        let decoded = try decodeJSON(TaskStatus.self, json: json)

        XCTAssertEqual(decoded, .idle)
    }

    func test_taskResult_roundTripCodable() throws {
        let cases: [TaskResult] = [
            .success(summary: "Done"),
            .failure(error: "Oops"),
            .cancelled
        ]

        for result in cases {
            let decoded = try roundTrip(result)
            XCTAssertEqual(decoded, result)
        }
    }

    func test_taskResult_decodeUnknownTypeFallsBackToCancelled() throws {
        let json = """
        { "type": "unknown" }
        """
        let decoded = try decodeJSON(TaskResult.self, json: json)

        XCTAssertEqual(decoded, .cancelled)
    }

    func test_taskState_initDefaults() {
        let start = Date(timeIntervalSince1970: 100)
        let state = TaskState(sessionId: "session-1", projectPath: "/tmp/project", startTime: start)

        XCTAssertEqual(state.status, .idle)
        XCTAssertEqual(state.startTime, start)
        XCTAssertEqual(state.lastUpdateTime, start)
        XCTAssertEqual(state.elapsedSeconds, 0)
        XCTAssertNil(state.todoProgress)
    }

    func test_taskState_updateStatusUpdatesElapsed() {
        var state = TaskState(
            sessionId: "session-1",
            projectPath: "/tmp/project",
            startTime: Date(timeIntervalSinceNow: -5)
        )

        state.updateStatus(.processing(operation: "Work"))

        XCTAssertGreaterThanOrEqual(state.elapsedSeconds, 5)
        XCTAssertEqual(state.status, .processing(operation: "Work"))
    }

    func test_taskState_updateProgressUpdatesLastUpdateTime() {
        var state = TaskState(
            sessionId: "session-1",
            projectPath: "/tmp/project",
            startTime: Date(timeIntervalSince1970: 100)
        )
        let previousUpdate = state.lastUpdateTime
        let progress = TodoProgress(completed: 1, total: 3, currentTask: "Step")

        state.updateProgress(progress)

        XCTAssertEqual(state.todoProgress, progress)
        XCTAssertNotEqual(state.lastUpdateTime, previousUpdate)
    }

    func test_todoProgress_textAndFraction() {
        let progress = TodoProgress(completed: 2, total: 4, currentTask: nil)

        XCTAssertEqual(progress.progressText, "2 of 4")
        XCTAssertEqual(progress.progressFraction, 0.5, accuracy: 0.0001)
    }

    func test_todoProgress_fractionHandlesZeroTotal() {
        let progress = TodoProgress(completed: 2, total: 0, currentTask: nil)

        XCTAssertEqual(progress.progressFraction, 2.0, accuracy: 0.0001)
    }

    func test_taskStateColor_hexValues() {
        XCTAssertEqual(TaskStateColor.gray.hexValue, "#8E8E93")
        XCTAssertEqual(TaskStateColor.blue.hexValue, "#007AFF")
        XCTAssertEqual(TaskStateColor.orange.hexValue, "#FF9500")
        XCTAssertEqual(TaskStateColor.purple.hexValue, "#AF52DE")
        XCTAssertEqual(TaskStateColor.green.hexValue, "#34C759")
        XCTAssertEqual(TaskStateColor.red.hexValue, "#FF3B30")
    }
}
