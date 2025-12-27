# Repository Guidelines

## Project Structure & Module Organization
- `ClaudeCodeApp/`: SwiftUI app source (views, managers, utilities, extensions).
- `ClaudeCodeApp/Views/`, `ClaudeCodeApp/Utilities/`, `ClaudeCodeApp/Extensions/`: UI components, helpers, and shared extensions.
- `ClaudeCodeApp/Assets.xcassets` and `assets/`: app assets and design resources.
- `ClaudeCodeAppTests/`: XCTest unit tests.
- `requirements/`: product, architecture, and backend docs.
- `ClaudeCodeApp.xcodeproj`: Xcode project entry point.

## Build, Test, and Development Commands
- `open ClaudeCodeApp.xcodeproj`: open the project in Xcode.
- `xcodebuild -project ClaudeCodeApp.xcodeproj -scheme ClaudeCodeApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`: build from the CLI.
- `xcodebuild test -project ClaudeCodeApp.xcodeproj -scheme ClaudeCodeApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`: run unit tests.
- Backend requirement: the app expects a running `claudecodeui` backend; see `requirements/BACKEND.md` for setup.

## Coding Style & Naming Conventions
- Use standard Swift/Xcode formatting (4-space indentation). No repository-wide SwiftLint/SwiftFormat config is present.
- Naming: `UpperCamelCase` for types/files, `lowerCamelCase` for methods and properties.
- Concurrency: add `@MainActor` to new `ObservableObject` types and use `Task { @MainActor in }` for UI updates from async code.
- Security: escape file paths passed to `SSHManager.executeCommand()`; never store secrets in `@AppStorage` (use Keychain).

## Testing Guidelines
- Framework: XCTest in `ClaudeCodeAppTests/`.
- Naming: `*Tests.swift` files with `test...` methods.
- Add tests for parsing/model changes to keep utilities and protocol handling stable.

## Commit & Pull Request Guidelines
- Commit messages follow Conventional Commits (`feat:`, `fix:`, `docs:`).
- PRs should include a concise summary, testing notes, and links to related issues/roadmap items.
- Provide screenshots or short recordings for UI changes and note backend config impacts when applicable.

## References
- `CLAUDE.md`: coding rules, security constraints, and architecture notes.
- `README.md`: setup, feature overview, and testing command example.
