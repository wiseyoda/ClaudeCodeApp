# Repository Guidelines

## Project Overview
- SwiftUI iOS 26+ client for the claudecodeui backend (wiseyoda fork), using WebSocket + REST for chat and Citadel SSH for file ops.
- Default simulator target is iPhone 17 Pro on iOS 26.2.

## Project Structure & Module Organization
- `CodingBridge/`: SwiftUI app code (views, stores, managers, utilities).
- `CodingBridge/Views/`, `CodingBridge/Utilities/`, `CodingBridge/Extensions/`: UI components, helpers, and shared extensions.
- `CodingBridge/Assets.xcassets` and `assets/`: app assets and design resources.
- `CodingBridgeTests/`: XCTest unit tests.
- `CodingBridgeUITests/`: XCTest UI tests (launches the app via a test harness).
- `requirements/` and `requirements/projects/`: product, architecture, backend, and deployment docs.
- `CHANGELOG.md`, `ROADMAP.md`, `ISSUES.md`, `FUTURE-IDEAS.md`: planning and tracking docs.
- `CodingBridge.xcodeproj`: Xcode project entry point.

## Key Files & Architecture
- `WebSocketManager.swift`: streaming, reconnection, session events.
- `SSHManager.swift`: terminal, file ops, git via Citadel.
- `SessionStore.swift` + `SessionRepository.swift` + `APIClient.swift`: session state and data layer (Clean Architecture).
- `ChatView.swift`, `ContentView.swift`, `TerminalView.swift`, `UserQuestionsView.swift`: primary UI flows.
- `Models.swift`, `AppSettings.swift`, `ClaudeHelper.swift`, `IdeasStore.swift`, `CommandStore.swift`, `BookmarkStore.swift`: models, settings, helpers, persistence.

## Build, Test, and Development Commands
- `open CodingBridge.xcodeproj`: open the project in Xcode.
- `xcodebuild -project CodingBridge.xcodeproj -scheme CodingBridge -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'`: build from the CLI.
- `xcodebuild test -project CodingBridge.xcodeproj -scheme CodingBridge -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' -only-testing:CodingBridgeTests`: run unit tests.
- `xcodebuild test -project CodingBridge.xcodeproj -scheme CodingBridge -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' -only-testing:CodingBridgeUITests`: run UI tests.
- Backend requirement: the app expects a running `claudecodeui` backend; see `requirements/BACKEND.md` for setup.

## Coding Style & Naming Conventions
- Use standard Swift/Xcode formatting (4-space indentation). No repository-wide SwiftLint/SwiftFormat config is present.
- Naming: `UpperCamelCase` for types/files, `lowerCamelCase` for methods and properties.
- Concurrency: add `@MainActor` to new `ObservableObject` types and use `Task { @MainActor in }` for UI updates from async code.
- State management: use `@StateObject` for manager ownership in views and `@EnvironmentObject` for `AppSettings`.
- Singletons: prefer `CommandStore.shared`, `BookmarkStore.shared`, `SessionStore.shared` for shared stores.
- Adding files: new `.swift` files must be added to `CodingBridge.xcodeproj` (`project.pbxproj`) or they will not compile.

## Security & SSH
- Escape file paths passed to `SSHManager.executeCommand()` using proper shell quoting.
- Use `$HOME` instead of `~` in SSH commands; use double quotes when a path includes `$HOME`.
- Never store secrets in `@AppStorage` (use `KeychainHelper`).

## Testing Guidelines
- Framework: XCTest in `CodingBridgeTests/`.
- UI tests live in `CodingBridgeUITests/` and use the `PermissionApprovalTestHarnessView` when `CODINGBRIDGE_UITEST_MODE=1` or `--ui-test-mode` is set.
- Naming: `*Tests.swift` files with `test...` methods.
- Add tests for parsing/model/protocol changes to keep utilities and protocol handling stable.
- Use `MockSessionRepository` when covering session flows.
- Coverage notes live in `TEST-COVERAGE.md`.
- Integration tests are gated by environment variables: `CODINGBRIDGE_TEST_BACKEND_URL`, `CODINGBRIDGE_TEST_AUTH_TOKEN`, and `CODINGBRIDGE_TEST_PROJECT_NAME` or `CODINGBRIDGE_TEST_PROJECT_PATH` (optional: `CODINGBRIDGE_TEST_REQUIRE_SUMMARIES`, `CODINGBRIDGE_TEST_WEBSOCKET_URL`, `CODINGBRIDGE_TEST_ALLOW_MUTATIONS`, `CODINGBRIDGE_TEST_DELETE_SESSION_ID`).

## Commit & Pull Request Guidelines
- Commit messages follow Conventional Commits (`feat:`, `fix:`, `docs:`).
- PRs should include a concise summary, testing notes, and links to related issues/roadmap items.
- Provide screenshots or short recordings for UI changes and note backend config impacts when applicable.

## References
- `CLAUDE.md`: coding rules, security constraints, and architecture notes.
- `README.md`: setup, feature overview, and testing examples.
- `requirements/ARCHITECTURE.md`, `requirements/OVERVIEW.md`, `requirements/BACKEND.md`, `requirements/SESSIONS.md`, `requirements/QNAP-CONTAINER.md`: requirements and backend docs.
- `ROADMAP.md`, `ISSUES.md`, `CHANGELOG.md`, `FUTURE-IDEAS.md`: planning and tracking.
- `TEST-COVERAGE.md`, `SESSION-ANALYSIS.md`: test coverage and session log analysis.
