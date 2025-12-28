# Repository Guidelines

## Project Structure & Module Organization
- `CodingBridge/`: SwiftUI app source (views, managers, utilities, extensions).
- `CodingBridge/Views/`, `CodingBridge/Utilities/`, `CodingBridge/Extensions/`: UI components, helpers, and shared extensions.
- `CodingBridge/Assets.xcassets` and `assets/`: app assets and design resources.
- `CodingBridgeTests/`: XCTest unit tests.
- `requirements/`: product, architecture, and backend docs.
- `CodingBridge.xcodeproj`: Xcode project entry point.

## Build, Test, and Development Commands
- `open CodingBridge.xcodeproj`: open the project in Xcode.
- `xcodebuild -project CodingBridge.xcodeproj -scheme CodingBridge -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'`: build from the CLI.
- `xcodebuild test -project CodingBridge.xcodeproj -scheme CodingBridge -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'`: run unit tests.
- Backend requirement: the app expects a running `claudecodeui` backend; see `requirements/BACKEND.md` for setup.

## Coding Style & Naming Conventions
- Use standard Swift/Xcode formatting (4-space indentation). No repository-wide SwiftLint/SwiftFormat config is present.
- Naming: `UpperCamelCase` for types/files, `lowerCamelCase` for methods and properties.
- Concurrency: add `@MainActor` to new `ObservableObject` types and use `Task { @MainActor in }` for UI updates from async code.
- Security: escape file paths passed to `SSHManager.executeCommand()`; never store secrets in `@AppStorage` (use Keychain).

## Testing Guidelines
- Framework: XCTest in `CodingBridgeTests/`.
- Naming: `*Tests.swift` files with `test...` methods.
- Add tests for parsing/model changes to keep utilities and protocol handling stable.

## Commit & Pull Request Guidelines
- Commit messages follow Conventional Commits (`feat:`, `fix:`, `docs:`).
- PRs should include a concise summary, testing notes, and links to related issues/roadmap items.
- Provide screenshots or short recordings for UI changes and note backend config impacts when applicable.

## References
- `CLAUDE.md`: coding rules, security constraints, and architecture notes.
- `README.md`: setup, feature overview, and testing command example.
