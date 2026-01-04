# Issue 37: Help & Onboarding

**Phase:** 6 (Sheets & Modals)
**Priority:** Medium
**Status:** Not Started
**Depends On:** Issue #17 (Liquid Glass), Issue #34 (Sheet System)

## Goal

Create comprehensive help system and first-run onboarding experience with Liquid Glass styling.

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- Depends On: Issue #17 (Liquid Glass), Issue #34 (Sheet System).
- Add runtime or tooling dependencies here.

## Touch Set
- Files to create: TBD.
- Files to modify: TBD.

## Interface Definitions
- List new or changed models, protocols, and API payloads.

## Edge Cases
- TBD.

## Tests
- [ ] Unit tests updated or added.
- [ ] UI tests updated or added (if user flows change).
## Design - Help Sheet

```
┌─────────────────────────────────────────────────────────┐
│              ═══ Help                        [Done]     │
├─────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────────┐ │
│ │ 🔍 Search help...                                   │ │
│ └─────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────┤
│ QUICK START                                             │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ 🚀 Getting Started                              ▶  │ │
│ │ ⌨️ Keyboard Shortcuts                           ▶  │ │
│ │ 💬 Slash Commands                               ▶  │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ FEATURES                                                │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ 📁 Projects                                     ▶  │ │
│ │ 💭 Sessions                                     ▶  │ │
│ │ 🖥️ Terminal                                     ▶  │ │
│ │ 📂 File Browser                                 ▶  │ │
│ │ 💡 Ideas                                        ▶  │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ RESOURCES                                               │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ 📖 Documentation                                ▶  │ │
│ │ 🐛 Report Issue                                 ▶  │ │
│ │ ℹ️ About                                        ▶  │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## Design - Onboarding

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│                     ✨                                  │
│                                                         │
│             Welcome to CodingBridge                     │
│                                                         │
│     Your mobile companion for Claude Code               │
│                                                         │
│   ┌───────────────────────────────────────────────┐    │
│   │  ● ○ ○ ○                                      │    │
│   │                                               │    │
│   │         🔗 Connect                            │    │
│   │                                               │    │
│   │   Connect to your cli-bridge server           │    │
│   │   to start chatting with Claude               │    │
│   │                                               │    │
│   └───────────────────────────────────────────────┘    │
│                                                         │
│              [Get Started]                              │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Implementation

### HelpSheet

```swift
struct HelpSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                // Search
                if !searchText.isEmpty {
                    SearchResultsSection(query: searchText)
                } else {
                    QuickStartSection()
                    FeaturesSection()
                    ResourcesSection()
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search help")
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.glass)
    }
}
```

### QuickStartSection

```swift
struct QuickStartSection: View {
    var body: some View {
        Section {
            NavigationLink {
                GettingStartedView()
            } label: {
                Label("Getting Started", systemImage: "rocket")
            }

            NavigationLink {
                KeyboardShortcutsView()
            } label: {
                Label("Keyboard Shortcuts", systemImage: "keyboard")
            }

            NavigationLink {
                SlashCommandsHelpView()
            } label: {
                Label("Slash Commands", systemImage: "command")
            }
        } header: {
            Text("Quick Start")
        }
    }
}
```

### FeaturesSection

```swift
struct FeaturesSection: View {
    var body: some View {
        Section {
            NavigationLink {
                HelpDetailView(topic: .projects)
            } label: {
                Label("Projects", systemImage: "folder")
            }

            NavigationLink {
                HelpDetailView(topic: .sessions)
            } label: {
                Label("Sessions", systemImage: "bubble.left.and.bubble.right")
            }

            NavigationLink {
                HelpDetailView(topic: .terminal)
            } label: {
                Label("Terminal", systemImage: "terminal")
            }

            NavigationLink {
                HelpDetailView(topic: .fileBrowser)
            } label: {
                Label("File Browser", systemImage: "folder.badge.gearshape")
            }

            NavigationLink {
                HelpDetailView(topic: .ideas)
            } label: {
                Label("Ideas", systemImage: "lightbulb")
            }
        } header: {
            Text("Features")
        }
    }
}
```

### ResourcesSection

```swift
struct ResourcesSection: View {
    @Environment(\.openURL) var openURL

    var body: some View {
        Section {
            Button {
                openURL(URL(string: "https://docs.anthropic.com/claude-code")!)
            } label: {
                Label("Documentation", systemImage: "book")
            }

            Button {
                openURL(URL(string: "https://github.com/anthropics/claude-code/issues")!)
            } label: {
                Label("Report Issue", systemImage: "ladybug")
            }

            NavigationLink {
                AboutView()
            } label: {
                Label("About", systemImage: "info.circle")
            }
        } header: {
            Text("Resources")
        }
    }
}
```

### HelpDetailView

```swift
struct HelpDetailView: View {
    let topic: HelpTopic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: topic.icon)
                        .font(.largeTitle)
                        .foregroundStyle(topic.color)

                    Text(topic.title)
                        .font(.largeTitle.bold())
                }

                Text(topic.description)
                    .font(.body)
                    .foregroundStyle(.secondary)

                Divider()

                // Content sections
                ForEach(topic.sections, id: \.title) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title)
                            .font(.headline)

                        Text(section.content)
                            .font(.body)

                        if let tips = section.tips {
                            ForEach(tips, id: \.self) { tip in
                                HStack(alignment: .top) {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundStyle(.yellow)
                                    Text(tip)
                                        .font(.callout)
                                }
                                .padding()
                                .background(Color.yellow.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum HelpTopic {
    case projects, sessions, terminal, fileBrowser, ideas

    var title: String {
        switch self {
        case .projects: return "Projects"
        case .sessions: return "Sessions"
        case .terminal: return "Terminal"
        case .fileBrowser: return "File Browser"
        case .ideas: return "Ideas"
        }
    }

    var icon: String {
        switch self {
        case .projects: return "folder.fill"
        case .sessions: return "bubble.left.and.bubble.right.fill"
        case .terminal: return "terminal.fill"
        case .fileBrowser: return "folder.badge.gearshape"
        case .ideas: return "lightbulb.fill"
        }
    }

    var color: Color {
        switch self {
        case .projects: return .blue
        case .sessions: return .green
        case .terminal: return .orange
        case .fileBrowser: return .purple
        case .ideas: return .yellow
        }
    }

    var description: String {
        switch self {
        case .projects:
            return "Projects are directories on your server where Claude can work."
        case .sessions:
            return "Sessions preserve your conversation history with Claude."
        case .terminal:
            return "Access a full SSH terminal to your server."
        case .fileBrowser:
            return "Browse and manage files on your server."
        case .ideas:
            return "Capture and organize ideas for future work."
        }
    }

    var sections: [HelpSection] {
        // Return topic-specific help sections
        []
    }
}

struct HelpSection {
    let title: String
    let content: String
    let tips: [String]?
}
```

### KeyboardShortcutsView

```swift
struct KeyboardShortcutsView: View {
    var body: some View {
        List {
            Section {
                ShortcutRow(keys: "⌘ N", description: "New session")
                ShortcutRow(keys: "⌘ ⇧ N", description: "New project")
                ShortcutRow(keys: "⌘ W", description: "Close sheet")
            } header: {
                Text("General")
            }

            Section {
                ShortcutRow(keys: "⌘ Return", description: "Send message")
                ShortcutRow(keys: "⌘ K", description: "Clear chat")
                ShortcutRow(keys: "⌘ /", description: "Show commands")
            } header: {
                Text("Chat")
            }

            Section {
                ShortcutRow(keys: "⌘ ,", description: "Settings")
                ShortcutRow(keys: "⌘ ?", description: "Help")
                ShortcutRow(keys: "⌘ F", description: "Search")
            } header: {
                Text("Navigation")
            }

            Section {
                ShortcutRow(keys: "⌘ 1-9", description: "Switch project")
                ShortcutRow(keys: "⌘ [", description: "Previous session")
                ShortcutRow(keys: "⌘ ]", description: "Next session")
            } header: {
                Text("Quick Switch")
            }
        }
        .navigationTitle("Keyboard Shortcuts")
    }
}

struct ShortcutRow: View {
    let keys: String
    let description: String

    var body: some View {
        HStack {
            Text(keys)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Spacer()

            Text(description)
                .foregroundStyle(.secondary)
        }
    }
}
```

### OnboardingView

```swift
struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0

    let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "link",
            title: "Connect",
            description: "Connect to your cli-bridge server to start chatting with Claude"
        ),
        OnboardingPage(
            icon: "folder",
            title: "Projects",
            description: "Work on any project directory on your server"
        ),
        OnboardingPage(
            icon: "bubble.left.and.bubble.right",
            title: "Chat",
            description: "Have conversations with Claude about your code"
        ),
        OnboardingPage(
            icon: "wand.and.stars",
            title: "Tools",
            description: "Claude can read files, run commands, and make changes"
        )
    ]

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Logo
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(.accent)
                .symbolEffect(.breathe)

            Text("Welcome to CodingBridge")
                .font(.title.bold())

            Text("Your mobile companion for Claude Code")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            // Page content
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(height: 200)

            Spacer()

            // Get Started button
            Button {
                if currentPage < pages.count - 1 {
                    withAnimation {
                        currentPage += 1
                    }
                } else {
                    isPresented = false
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                }
            } label: {
                Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)

            // Skip button
            if currentPage < pages.count - 1 {
                Button("Skip") {
                    isPresented = false
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
    }
}

struct OnboardingPage: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: page.icon)
                .font(.system(size: 44))
                .foregroundStyle(.accent)

            Text(page.title)
                .font(.title2.bold())

            Text(page.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .glassEffect()
        .padding()
    }
}
```

### SlashCommandsHelpView

```swift
struct SlashCommandsHelpView: View {
    var body: some View {
        List {
            Section {
                CommandHelpRow(command: "/help", description: "Show available commands")
                CommandHelpRow(command: "/clear", description: "Clear the current chat")
                CommandHelpRow(command: "/new", description: "Start a new session")
            } header: {
                Text("General")
            }

            Section {
                CommandHelpRow(command: "/resume", description: "Resume a previous session")
                CommandHelpRow(command: "/sessions", description: "View all sessions")
                CommandHelpRow(command: "/export", description: "Export current session")
            } header: {
                Text("Sessions")
            }

            Section {
                CommandHelpRow(command: "/model", description: "Change Claude model")
                CommandHelpRow(command: "/think", description: "Enable thinking mode")
                CommandHelpRow(command: "/plan", description: "Enable plan mode")
            } header: {
                Text("Settings")
            }

            Section {
                CommandHelpRow(command: "/files", description: "Browse files")
                CommandHelpRow(command: "/terminal", description: "Open terminal")
                CommandHelpRow(command: "/ideas", description: "View ideas")
            } header: {
                Text("Tools")
            }
        }
        .navigationTitle("Slash Commands")
    }
}

struct CommandHelpRow: View {
    let command: String
    let description: String

    var body: some View {
        HStack {
            Text(command)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.accent)

            Spacer()

            Text(description)
                .foregroundStyle(.secondary)
        }
    }
}
```

### AboutView

```swift
struct AboutView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 60))
                            .foregroundStyle(.accent)

                        Text("CodingBridge")
                            .font(.title.bold())

                        Text("Version \(Bundle.main.appVersion)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical)
            }

            Section {
                LabeledContent("Build", value: Bundle.main.buildNumber)
                LabeledContent("iOS Version", value: UIDevice.current.systemVersion)
            } header: {
                Text("App Info")
            }

            Section {
                Link(destination: URL(string: "https://anthropic.com")!) {
                    Label("Anthropic", systemImage: "globe")
                }

                Link(destination: URL(string: "https://github.com/anthropics/claude-code")!) {
                    Label("GitHub", systemImage: "link")
                }

                Link(destination: URL(string: "https://anthropic.com/privacy")!) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }

                Link(destination: URL(string: "https://anthropic.com/terms")!) {
                    Label("Terms of Service", systemImage: "doc.text")
                }
            } header: {
                Text("Links")
            }

            Section {
                Text("Made with ❤️ for developers")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle("About")
    }
}

extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}
```

## Files to Create

```
CodingBridge/Features/Help/
├── HelpSheet.swift                # ~60 lines
├── QuickStartSection.swift        # ~40 lines
├── FeaturesSection.swift          # ~50 lines
├── ResourcesSection.swift         # ~40 lines
├── HelpDetailView.swift           # ~100 lines
├── KeyboardShortcutsView.swift    # ~80 lines
├── SlashCommandsHelpView.swift    # ~60 lines
└── AboutView.swift                # ~80 lines

CodingBridge/Features/Onboarding/
├── OnboardingView.swift           # ~100 lines
└── OnboardingPageView.swift       # ~40 lines
```

## Files to Modify

| File | Changes |
|------|---------|
| `CodingBridgeApp.swift` | Show onboarding on first launch |
| Current help views | Replace with new implementations |

## Acceptance Criteria

- [ ] Help sheet with search
- [ ] Quick start guides
- [ ] Feature documentation
- [ ] Keyboard shortcuts list
- [ ] Slash commands reference
- [ ] About view with version info
- [ ] Onboarding flow for first launch
- [ ] Skip option in onboarding
- [ ] Glass effect styling
- [ ] Build passes

## Testing

```swift
struct HelpTests: XCTestCase {
    func testOnboardingCompletion() {
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")

        XCTAssertFalse(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))

        // Simulate completion
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))
    }

    func testHelpTopics() {
        XCTAssertEqual(HelpTopic.projects.title, "Projects")
        XCTAssertEqual(HelpTopic.sessions.icon, "bubble.left.and.bubble.right.fill")
    }
}
```
