# Testing Navigation


```swift
struct NavigationTests: XCTestCase {
    func testProjectSelection() {
        let appState = AppState()
        let project = Project.mock()

        appState.selectedProject = project

        XCTAssertEqual(appState.selectedProject?.id, project.id)
    }

    func testNavigationPath() {
        let appState = AppState()

        appState.navigationPath.append(NavigationDestination.terminal)

        XCTAssertEqual(appState.navigationPath.count, 1)
    }

    func testColumnVisibility() {
        let appState = AppState()

        appState.columnVisibility = .detailOnly

        XCTAssertEqual(appState.columnVisibility, .detailOnly)
    }
}
```
