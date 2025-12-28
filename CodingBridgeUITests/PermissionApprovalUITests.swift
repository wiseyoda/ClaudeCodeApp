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

    func testApprovalBannerActions() {
        let title = app.staticTexts["PermissionHarnessTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))

        let approveButton = app.descendants(matching: .any)["ApprovalBannerApprove"]
        XCTAssertTrue(approveButton.waitForExistence(timeout: 5))

        let decisionLabel = app.staticTexts["PermissionDecisionLabel"]
        let rememberLabel = app.staticTexts["PermissionRememberLabel"]
        let resetButton = app.descendants(matching: .any)["PermissionResetButton"]
        let timeoutButton = app.descendants(matching: .any)["PermissionTimeoutButton"]

        approveButton.tap()
        XCTAssertTrue(decisionLabel.label.contains("approve"))
        resetButton.tap()

        app.descendants(matching: .any)["ApprovalBannerDeny"].tap()
        XCTAssertTrue(decisionLabel.label.contains("deny"))
        resetButton.tap()

        app.descendants(matching: .any)["ApprovalBannerAlways"].tap()
        XCTAssertTrue(decisionLabel.label.contains("always"))
        XCTAssertTrue(rememberLabel.label.contains("yes"))
        resetButton.tap()

        timeoutButton.tap()
        XCTAssertTrue(decisionLabel.label.contains("timeout"))
    }
}
