import XCTest
@testable import CodingBridge

final class LiveActivityTypesTests: XCTestCase {

    // MARK: - LiveActivityStatus Tests

    func test_liveActivityStatus_displayText_returnsCorrectStrings() {
        XCTAssertEqual(LiveActivityStatus.processing.displayText, "Working...")
        XCTAssertEqual(LiveActivityStatus.awaitingApproval.displayText, "Needs Approval")
        XCTAssertEqual(LiveActivityStatus.awaitingAnswer.displayText, "Question")
        XCTAssertEqual(LiveActivityStatus.complete.displayText, "Complete")
        XCTAssertEqual(LiveActivityStatus.error.displayText, "Error")
    }

    func test_liveActivityStatus_icon_returnsValidSFSymbols() {
        XCTAssertEqual(LiveActivityStatus.processing.icon, "gearshape.2.fill")
        XCTAssertEqual(LiveActivityStatus.awaitingApproval.icon, "checkmark.shield.fill")
        XCTAssertEqual(LiveActivityStatus.awaitingAnswer.icon, "questionmark.bubble.fill")
        XCTAssertEqual(LiveActivityStatus.complete.icon, "checkmark.circle.fill")
        XCTAssertEqual(LiveActivityStatus.error.icon, "exclamationmark.triangle.fill")
    }

    func test_liveActivityStatus_rawValues_matchServerExpectations() {
        XCTAssertEqual(LiveActivityStatus.processing.rawValue, "processing")
        XCTAssertEqual(LiveActivityStatus.awaitingApproval.rawValue, "awaiting_approval")
        XCTAssertEqual(LiveActivityStatus.awaitingAnswer.rawValue, "awaiting_answer")
        XCTAssertEqual(LiveActivityStatus.complete.rawValue, "complete")
        XCTAssertEqual(LiveActivityStatus.error.rawValue, "error")
    }

    func test_liveActivityStatus_initFromRawValue() {
        XCTAssertEqual(LiveActivityStatus(rawValue: "processing"), .processing)
        XCTAssertEqual(LiveActivityStatus(rawValue: "awaiting_approval"), .awaitingApproval)
        XCTAssertEqual(LiveActivityStatus(rawValue: "awaiting_answer"), .awaitingAnswer)
        XCTAssertEqual(LiveActivityStatus(rawValue: "complete"), .complete)
        XCTAssertEqual(LiveActivityStatus(rawValue: "error"), .error)
        XCTAssertNil(LiveActivityStatus(rawValue: "invalid"))
    }

    // MARK: - LAProgress Tests

    func test_laProgress_percentage_calculatesCorrectly() {
        let progress = LAProgress(completed: 3, total: 10, currentTask: nil)
        XCTAssertEqual(progress.percentage, 30.0, accuracy: 0.001)
    }

    func test_laProgress_percentage_returnsZeroWhenTotalIsZero() {
        let progress = LAProgress(completed: 0, total: 0, currentTask: nil)
        XCTAssertEqual(progress.percentage, 0.0)
    }

    func test_laProgress_displayText_formatsCorrectly() {
        let progress = LAProgress(completed: 5, total: 12, currentTask: "Building...")
        XCTAssertEqual(progress.displayText, "5/12")
    }

    func test_laProgress_encodesAndDecodes() throws {
        let progress = LAProgress(completed: 2, total: 5, currentTask: "Running tests")

        let data = try JSONEncoder().encode(progress)
        let decoded = try JSONDecoder().decode(LAProgress.self, from: data)

        XCTAssertEqual(decoded.completed, 2)
        XCTAssertEqual(decoded.total, 5)
        XCTAssertEqual(decoded.currentTask, "Running tests")
    }

    // MARK: - LAApprovalInfo Tests

    func test_laApprovalInfo_encodesAndDecodes() throws {
        let approval = LAApprovalInfo(
            id: "req-123",
            toolName: "Bash",
            summary: "Execute npm install"
        )

        let data = try JSONEncoder().encode(approval)
        let decoded = try JSONDecoder().decode(LAApprovalInfo.self, from: data)

        XCTAssertEqual(decoded.id, "req-123")
        XCTAssertEqual(decoded.toolName, "Bash")
        XCTAssertEqual(decoded.summary, "Execute npm install")
    }

    // MARK: - LAQuestionInfo Tests

    func test_laQuestionInfo_encodesAndDecodes() throws {
        let question = LAQuestionInfo(
            id: "q-456",
            preview: "Which testing framework should I use?"
        )

        let data = try JSONEncoder().encode(question)
        let decoded = try JSONDecoder().decode(LAQuestionInfo.self, from: data)

        XCTAssertEqual(decoded.id, "q-456")
        XCTAssertEqual(decoded.preview, "Which testing framework should I use?")
    }

    // MARK: - LAErrorInfo Tests

    func test_laErrorInfo_encodesAndDecodes() throws {
        let errorInfo = LAErrorInfo(message: "Connection failed", recoverable: true)

        let data = try JSONEncoder().encode(errorInfo)
        let decoded = try JSONDecoder().decode(LAErrorInfo.self, from: data)

        XCTAssertEqual(decoded.message, "Connection failed")
        XCTAssertTrue(decoded.recoverable)
    }

    func test_laErrorInfo_nonRecoverable() throws {
        let errorInfo = LAErrorInfo(message: "Authentication expired", recoverable: false)

        let data = try JSONEncoder().encode(errorInfo)
        let decoded = try JSONDecoder().decode(LAErrorInfo.self, from: data)

        XCTAssertEqual(decoded.message, "Authentication expired")
        XCTAssertFalse(decoded.recoverable)
    }

    // MARK: - ContentState Factory Methods Tests

    func test_contentState_processing_createsCorrectState() {
        let state = CodingBridgeAttributes.ContentState.processing(operation: "Analyzing code")

        XCTAssertEqual(state.status, .processing)
        XCTAssertEqual(state.currentOperation, "Analyzing code")
        XCTAssertNil(state.todoProgress)
        XCTAssertNil(state.approvalRequest)
        XCTAssertNil(state.question)
        XCTAssertNil(state.error)
    }

    func test_contentState_processing_usesDefaultOperation() {
        let state = CodingBridgeAttributes.ContentState.processing()

        XCTAssertEqual(state.status, .processing)
        XCTAssertEqual(state.currentOperation, "Starting...")
    }

    func test_contentState_awaitingApproval_createsCorrectState() {
        let approval = LAApprovalInfo(id: "req-1", toolName: "Write", summary: "Write file")
        let state = CodingBridgeAttributes.ContentState.awaitingApproval(approval: approval)

        XCTAssertEqual(state.status, .awaitingApproval)
        XCTAssertEqual(state.currentOperation, "Waiting for approval: Write")
        XCTAssertEqual(state.approvalRequest?.id, "req-1")
    }

    func test_contentState_awaitingAnswer_createsCorrectState() {
        let question = LAQuestionInfo(id: "q-1", preview: "What's the target framework?")
        let state = CodingBridgeAttributes.ContentState.awaitingAnswer(question: question)

        XCTAssertEqual(state.status, .awaitingAnswer)
        XCTAssertEqual(state.currentOperation, "Question from Claude")
        XCTAssertEqual(state.question?.id, "q-1")
    }

    func test_contentState_complete_createsCorrectState() {
        let state = CodingBridgeAttributes.ContentState.complete(elapsedSeconds: 120)

        XCTAssertEqual(state.status, .complete)
        XCTAssertEqual(state.currentOperation, "Task completed")
        XCTAssertEqual(state.elapsedSeconds, 120)
    }

    func test_contentState_error_createsCorrectState() {
        let errorInfo = LAErrorInfo(message: "Network timeout", recoverable: true)
        let state = CodingBridgeAttributes.ContentState.error(errorInfo)

        XCTAssertEqual(state.status, .error)
        XCTAssertEqual(state.currentOperation, "Network timeout")
        XCTAssertEqual(state.error?.message, "Network timeout")
        XCTAssertTrue(state.error?.recoverable ?? false)
    }
}
