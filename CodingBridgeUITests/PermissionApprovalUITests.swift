import XCTest

final class PermissionApprovalUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--ui-test-mode")
        app.launchEnvironment["CODINGBRIDGE_UITEST_MODE"] = "1"
        app.launch()
    }

    /// Helper to wait for a label to contain expected text
    private func waitForLabel(_ element: XCUIElement, toContain text: String, timeout: TimeInterval = 3) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    func testApprovalBannerActions() {
        let title = app.staticTexts["PermissionHarnessTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))

        let approveButton = app.descendants(matching: .any)["ApprovalBannerApprove"]
        XCTAssertTrue(approveButton.waitForExistence(timeout: 5))

        let decisionLabel = app.staticTexts["PermissionDecisionLabel"]
        let rememberLabel = app.staticTexts["PermissionRememberLabel"]
        let resetButton = app.descendants(matching: .any)["PermissionResetButton"]
        let timeoutButton = app.descendants(matching: .any)["PermissionTimeoutButton"]

        // Test Approve
        approveButton.tap()
        XCTAssertTrue(waitForLabel(decisionLabel, toContain: "approve"))
        resetButton.tap()

        // Wait for banner to reappear after reset
        let denyButton = app.descendants(matching: .any)["ApprovalBannerDeny"]
        XCTAssertTrue(denyButton.waitForExistence(timeout: 3))

        // Test Deny
        denyButton.tap()
        XCTAssertTrue(waitForLabel(decisionLabel, toContain: "deny"))
        resetButton.tap()

        // Wait for banner to reappear after reset
        XCTAssertTrue(app.descendants(matching: .any)["ApprovalBannerAlways"].waitForExistence(timeout: 3))

        // Test Always Allow - this triggers a confirmation dialog
        app.descendants(matching: .any)["ApprovalBannerAlways"].tap()

        // Wait for and tap "Always Allow" in the confirmation dialog
        let alwaysAllowConfirmButton = app.buttons["Always Allow"]
        XCTAssertTrue(alwaysAllowConfirmButton.waitForExistence(timeout: 3), "Confirmation dialog should appear")
        alwaysAllowConfirmButton.tap()

        XCTAssertTrue(waitForLabel(decisionLabel, toContain: "always"), "Expected 'always' but got: '\(decisionLabel.label)'")
        XCTAssertTrue(waitForLabel(rememberLabel, toContain: "yes"))
        resetButton.tap()

        // Wait for reset to complete and timeout button to be accessible
        XCTAssertTrue(timeoutButton.waitForExistence(timeout: 3))

        // Test Timeout
        timeoutButton.tap()
        XCTAssertTrue(waitForLabel(decisionLabel, toContain: "timeout"))
    }
}
