---
number: 68
title: Share Extension
phase: phase-8-ios26-platform
status: pending
completed_by: null
completed_at: null
verified_by: null
verified_at: null
commit: null
spot_checked: false
blocked_reason: null
---

# Issue 68: Share Extension

**Phase:** 8 (iOS 26 Platform)
**Priority:** Low
**Status:** Not Started
**Depends On:** 57 (Export & Share)
**Target:** iOS 26.2, Xcode 26.2, Swift 6.2.1

## Goal

Create a Share Extension that allows users to send content (text, code, images, URLs) directly to CodingBridge from other apps, creating quick chat prompts or capturing ideas.

## Scope

- In scope:
  - Share Extension target
  - Text/URL/image handling
  - Project selection sheet
  - Quick capture to Ideas
  - Direct chat prompt creation
  - App Groups for data sharing
- Out of scope:
  - Full chat interface in extension
  - File attachment handling
  - Background processing

## Non-goals

- Processing shared content in extension
- Immediate agent response
- Extension-only functionality

## Dependencies

- Issue #57 (Export & Share) for content handling patterns

## Touch Set

- Files to create:
  - `ShareExtension/ShareViewController.swift`
  - `ShareExtension/ShareExtension.entitlements`
  - `CodingBridge/Services/SharedContentManager.swift`
- Files to modify:
  - Add Share Extension target to project
  - `CodingBridge.entitlements` (add App Groups)
  - Update Info.plist for extension

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      External App                                │
│                          │                                       │
│                    Share Sheet                                   │
│                          │                                       │
└──────────────────────────┼───────────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Share Extension                                │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │              ShareViewController                             ││
│  │  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐ ││
│  │  │Content Preview│  │Project Picker│  │  Action Buttons   │ ││
│  │  └──────────────┘  └──────────────┘  └────────────────────┘ ││
│  └─────────────────────────────────────────────────────────────┘│
│                          │                                       │
│                    App Groups                                    │
│                    (Shared Container)                            │
│                          │                                       │
└──────────────────────────┼───────────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Main App                                      │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │           SharedContentManager                               ││
│  │  - Reads pending content from App Groups                     ││
│  │  - Creates chat prompt or idea                               ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

---

## Share Extension

### Info.plist Configuration

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionAttributes</key>
    <dict>
        <key>NSExtensionActivationRule</key>
        <dict>
            <key>NSExtensionActivationSupportsText</key>
            <true/>
            <key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
            <integer>1</integer>
            <key>NSExtensionActivationSupportsImageWithMaxCount</key>
            <integer>3</integer>
            <key>NSExtensionActivationSupportsFileWithMaxCount</key>
            <integer>5</integer>
        </dict>
    </dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.share-services</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).ShareViewController</string>
</dict>
```

### ShareViewController

```swift
import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    // MARK: - UI Elements

    private let containerView = UIView()
    private let headerLabel = UILabel()
    private let contentPreview = UITextView()
    private let projectPicker = UISegmentedControl()
    private let actionStack = UIStackView()
    private let sendButton = UIButton(type: .system)
    private let saveIdeaButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)

    // MARK: - State

    private var sharedContent: SharedContent?
    private var projects: [Project] = []
    private var selectedProjectIndex = 0

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadProjects()
        extractSharedContent()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)

        // Container
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 16
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        // Header
        headerLabel.text = "Share to CodingBridge"
        headerLabel.font = .boldSystemFont(ofSize: 18)
        headerLabel.textAlignment = .center
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(headerLabel)

        // Content preview
        contentPreview.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        contentPreview.backgroundColor = .secondarySystemBackground
        contentPreview.layer.cornerRadius = 8
        contentPreview.isEditable = false
        contentPreview.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(contentPreview)

        // Project picker
        projectPicker.translatesAutoresizingMaskIntoConstraints = false
        projectPicker.addTarget(self, action: #selector(projectChanged), for: .valueChanged)
        containerView.addSubview(projectPicker)

        // Action buttons
        setupActionButtons()

        setupConstraints()
    }

    private func setupActionButtons() {
        actionStack.axis = .horizontal
        actionStack.spacing = 12
        actionStack.distribution = .fillEqually
        actionStack.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(actionStack)

        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        saveIdeaButton.setTitle("Save as Idea", for: .normal)
        saveIdeaButton.addTarget(self, action: #selector(saveIdeaTapped), for: .touchUpInside)

        sendButton.setTitle("Send to Chat", for: .normal)
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.backgroundColor = .systemBlue
        sendButton.layer.cornerRadius = 8
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)

        actionStack.addArrangedSubview(cancelButton)
        actionStack.addArrangedSubview(saveIdeaButton)
        actionStack.addArrangedSubview(sendButton)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            headerLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            headerLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            headerLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            contentPreview.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 16),
            contentPreview.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            contentPreview.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            contentPreview.heightAnchor.constraint(equalToConstant: 150),

            projectPicker.topAnchor.constraint(equalTo: contentPreview.bottomAnchor, constant: 16),
            projectPicker.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            projectPicker.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            actionStack.topAnchor.constraint(equalTo: projectPicker.bottomAnchor, constant: 20),
            actionStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            actionStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            actionStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            actionStack.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    // MARK: - Data Loading

    private func loadProjects() {
        projects = SharedContentManager.loadProjects()

        projectPicker.removeAllSegments()
        for (index, project) in projects.prefix(4).enumerated() {
            projectPicker.insertSegment(withTitle: project.name, at: index, animated: false)
        }

        if !projects.isEmpty {
            projectPicker.selectedSegmentIndex = 0
        }
    }

    private func extractSharedContent() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            return
        }

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                // Text
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { [weak self] data, _ in
                        if let text = data as? String {
                            DispatchQueue.main.async {
                                self?.handleText(text)
                            }
                        }
                    }
                }

                // URL
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] data, _ in
                        if let url = data as? URL {
                            DispatchQueue.main.async {
                                self?.handleURL(url)
                            }
                        }
                    }
                }

                // Image
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.image.identifier) { [weak self] data, _ in
                        if let imageURL = data as? URL,
                           let imageData = try? Data(contentsOf: imageURL) {
                            DispatchQueue.main.async {
                                self?.handleImage(imageData)
                            }
                        }
                    }
                }
            }
        }
    }

    private func handleText(_ text: String) {
        sharedContent = SharedContent(type: .text, text: text)
        contentPreview.text = text
    }

    private func handleURL(_ url: URL) {
        sharedContent = SharedContent(type: .url, text: url.absoluteString, url: url)
        contentPreview.text = "URL: \(url.absoluteString)"
    }

    private func handleImage(_ data: Data) {
        sharedContent = SharedContent(type: .image, imageData: data)
        contentPreview.text = "[Image attached - \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))]"
    }

    // MARK: - Actions

    @objc private func projectChanged() {
        selectedProjectIndex = projectPicker.selectedSegmentIndex
    }

    @objc private func cancelTapped() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    @objc private func saveIdeaTapped() {
        guard var content = sharedContent, !projects.isEmpty else { return }

        content.action = .saveAsIdea
        content.projectPath = projects[selectedProjectIndex].path

        SharedContentManager.save(content)
        extensionContext?.completeRequest(returningItems: nil)
    }

    @objc private func sendTapped() {
        guard var content = sharedContent, !projects.isEmpty else { return }

        content.action = .sendToChat
        content.projectPath = projects[selectedProjectIndex].path

        SharedContentManager.save(content)

        // Open main app
        if let url = URL(string: "codingbridge://share") {
            extensionContext?.open(url)
        }

        extensionContext?.completeRequest(returningItems: nil)
    }
}
```

---

## Shared Content Manager

### SharedContentManager

```swift
import Foundation

/// Manages shared content between extension and main app.
struct SharedContentManager {
    static let appGroupIdentifier = "group.com.codingbridge.shared"

    private static var sharedContainer: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    private static var pendingContentURL: URL? {
        sharedContainer?.appendingPathComponent("pending-share.json")
    }

    // MARK: - Save (from Extension)

    static func save(_ content: SharedContent) {
        guard let url = pendingContentURL else { return }

        do {
            let data = try JSONEncoder().encode(content)
            try data.write(to: url)
        } catch {
            print("Failed to save shared content: \(error)")
        }
    }

    // MARK: - Load (from Main App)

    static func loadPendingContent() -> SharedContent? {
        guard let url = pendingContentURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let content = try JSONDecoder().decode(SharedContent.self, from: data)

            // Clear after reading
            try FileManager.default.removeItem(at: url)

            return content
        } catch {
            print("Failed to load shared content: \(error)")
            return nil
        }
    }

    // MARK: - Projects (for Extension)

    static func loadProjects() -> [Project] {
        guard let url = sharedContainer?.appendingPathComponent("projects.json") else {
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Project].self, from: data)
        } catch {
            return []
        }
    }

    static func saveProjects(_ projects: [Project]) {
        guard let url = sharedContainer?.appendingPathComponent("projects.json") else { return }

        do {
            let data = try JSONEncoder().encode(projects)
            try data.write(to: url)
        } catch {
            print("Failed to save projects: \(error)")
        }
    }
}

// MARK: - Models

struct SharedContent: Codable {
    var type: ContentType
    var text: String?
    var url: URL?
    var imageData: Data?
    var action: ShareAction = .sendToChat
    var projectPath: String?

    enum ContentType: String, Codable {
        case text
        case url
        case image
        case file
    }

    enum ShareAction: String, Codable {
        case sendToChat
        case saveAsIdea
    }
}

struct Project: Codable, Identifiable {
    var id: String { path }
    let name: String
    let path: String
}
```

---

## Main App Integration

### Handling Shared Content

```swift
extension ContentView {
    func handleSharedContent() {
        guard let content = SharedContentManager.loadPendingContent() else { return }

        switch content.action {
        case .sendToChat:
            sendToChat(content)
        case .saveAsIdea:
            saveAsIdea(content)
        }
    }

    private func sendToChat(_ content: SharedContent) {
        guard let projectPath = content.projectPath else { return }

        // Navigate to project
        StateRestorationManager.shared.selectedProjectPath = projectPath

        // Set input text
        if let text = content.text {
            QuickChatStore.shared.pendingMessage = text
        }
    }

    private func saveAsIdea(_ content: SharedContent) {
        guard let projectPath = content.projectPath,
              let text = content.text else { return }

        let store = IdeasStore(projectPath: projectPath)
        store.addIdea(Idea(text: text, title: "Shared: \(text.prefix(30))..."))
    }
}
```

### URL Scheme Handling

```swift
struct CodingBridgeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleURL(url)
                }
        }
    }

    private func handleURL(_ url: URL) {
        if url.scheme == "codingbridge" && url.host == "share" {
            // Handle shared content
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                ContentView.shared?.handleSharedContent()
            }
        }
    }
}
```

---

## Edge Cases

- **No projects available**: Show "Open app to create project" message
- **Large image shared**: Compress before storing
- **Extension memory limit**: Handle gracefully with error message
- **App not installed**: Not applicable (extension requires app)
- **Shared content expires**: Clear after 24 hours

## Acceptance Criteria

- [ ] Share Extension target builds
- [ ] App Groups configured for both targets
- [ ] Text sharing works
- [ ] URL sharing works
- [ ] Image sharing works
- [ ] Project selection works
- [ ] "Send to Chat" opens app correctly
- [ ] "Save as Idea" persists correctly
- [ ] Content preview displays correctly

## Testing

```swift
class SharedContentManagerTests: XCTestCase {
    func testSaveAndLoad() {
        let content = SharedContent(type: .text, text: "Test content")
        SharedContentManager.save(content)

        let loaded = SharedContentManager.loadPendingContent()

        XCTAssertEqual(loaded?.text, "Test content")
        XCTAssertEqual(loaded?.type, .text)
    }

    func testProjectPersistence() {
        let projects = [
            Project(name: "Test", path: "/test/path"),
        ]

        SharedContentManager.saveProjects(projects)
        let loaded = SharedContentManager.loadProjects()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].name, "Test")
    }

    func testContentCleared() {
        let content = SharedContent(type: .text, text: "Test")
        SharedContentManager.save(content)

        _ = SharedContentManager.loadPendingContent()
        let secondLoad = SharedContentManager.loadPendingContent()

        XCTAssertNil(secondLoad)
    }
}
```
