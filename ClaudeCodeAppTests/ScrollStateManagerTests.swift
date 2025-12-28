import Combine
import XCTest
@testable import CodingBridge

@MainActor
final class ScrollStateManagerTests: XCTestCase {

    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func test_forceScrollToBottom_setsShouldScroll() {
        let manager = ScrollStateManager()

        manager.forceScrollToBottom(animated: false)

        XCTAssertTrue(manager.shouldScroll)
        XCTAssertTrue(manager.isAutoScrollEnabled)
    }

    func test_forceScrollToBottom_resetsShouldScroll() {
        let manager = ScrollStateManager()
        let expectation = XCTestExpectation(description: "shouldScroll resets")

        manager.forceScrollToBottom(animated: false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(manager.shouldScroll)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func test_requestScrollToBottom_setsShouldScrollAfterDebounce() {
        let manager = ScrollStateManager()
        let expectation = XCTestExpectation(description: "shouldScroll becomes true")

        manager.$shouldScroll
            .dropFirst()
            .sink { value in
                if value {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        manager.requestScrollToBottom(animated: false)

        wait(for: [expectation], timeout: 1.0)
    }

    func test_reset_clearsScrollState() {
        let manager = ScrollStateManager()

        manager.forceScrollToBottom(animated: false)
        manager.reset()

        XCTAssertFalse(manager.shouldScroll)
        XCTAssertTrue(manager.isAutoScrollEnabled)
    }
}
