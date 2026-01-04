# Target File Structure

```
CodingBridge/
├── App/
│   ├── CodingBridgeApp.swift           # App entry, intents registration
│   ├── AppState.swift                  # Global app state (@Observable)
│   └── NavigationState.swift           # Navigation path management
│
├── Design/
│   ├── DesignSystem.swift              # All design tokens
│   ├── LiquidGlassStyles.swift         # Glass effect configurations
│   └── ComponentStyles.swift           # Button, card, input styles
│
├── Navigation/
│   ├── MainNavigationView.swift        # NavigationSplitView root
│   ├── SidebarView.swift               # Project list sidebar
│   └── DetailContainerView.swift       # Detail area routing
│
├── Features/
│   ├── Chat/
│   │   ├── ChatView.swift              # Main chat container
│   │   ├── ChatViewModel.swift         # @MainActor @Observable
│   │   ├── MessageListView.swift       # Virtualized list
│   │   ├── InputView.swift             # Message input
│   │   ├── StatusBarView.swift         # Token usage, status
│   │   └── Cards/
│   │       ├── MessageCardProtocol.swift
│   │       ├── MessageCardRouter.swift
│   │       ├── ChatCardView.swift
│   │       ├── ToolCardView.swift
│   │       └── SystemCardView.swift
│   │
│   ├── Projects/
│   │   ├── ProjectListView.swift       # Project list component
│   │   ├── ProjectRowView.swift        # Each project cell
│   │   ├── NewProjectSheet.swift       # Create project
│   │   └── CloneProjectSheet.swift     # Clone from URL
│   │
│   ├── Settings/
│   │   ├── SettingsView.swift          # Main settings
│   │   ├── QuickSettingsView.swift     # In-chat settings
│   │   └── ProjectSettingsView.swift   # Per-project settings
│   │
│   ├── Terminal/
│   │   ├── TerminalView.swift          # SSH terminal
│   │   ├── TerminalToolbar.swift       # Control keys
│   │   └── TerminalHistoryView.swift   # Scrollback
│   │
│   ├── Files/
│   │   ├── FileBrowserView.swift       # File browser
│   │   ├── FilePickerSheet.swift       # Quick file picker
│   │   └── FileTreeRow.swift           # Tree rows
│   │
│   ├── Sessions/
│   │   ├── SessionPickerView.swift     # Session list
│   │   ├── SessionRowView.swift        # Each session
│   │   └── SessionSummaryView.swift    # Summary card
│   │
│   ├── Search/
│   │   ├── GlobalSearchView.swift      # Global search
│   │   └── SearchResultRow.swift       # Search results
│   │
│   ├── Commands/
│   │   ├── CommandsView.swift          # Saved commands
│   │   └── CommandPickerSheet.swift    # Command picker
│   │
│   ├── Ideas/
│   │   ├── IdeasDrawerSheet.swift      # Ideas management
│   │   └── IdeasRowView.swift          # Individual idea
│   │
│   ├── Help/
│   │   ├── HelpSheet.swift             # Help and onboarding
│   │   └── KeyboardShortcutsSheet.swift# Shortcut help
│   │
│   └── Export/
│       ├── ExportSheet.swift           # Export sessions
│       └── ShareSheet.swift            # Share UI
│
├── Components/
│   ├── Cards/
│   │   ├── ToolCardView.swift
│   │   ├── SystemCardView.swift
│   │   └── ChatCardView.swift
│   │
│   ├── Buttons/
│   │   ├── PrimaryButton.swift
│   │   └── GlassButton.swift
│   │
│   ├── Inputs/
│   │   ├── GlassTextField.swift
│   │   └── AutoGrowingTextEditor.swift
│   │
│   └── Misc/
│       ├── LoadingView.swift
│       ├── EmptyStateView.swift
│       └── ErrorBannerView.swift
│
├── Services/
│   ├── CLIBridgeManager.swift          # WebSocket streaming
│   ├── SSHManager.swift                # Terminal + file ops
│   ├── SessionRepository.swift         # Data layer
│   ├── SessionStore.swift              # State management
│   ├── MessageNormalizer.swift         # Data normalization
│   ├── StreamInteractionHandler.swift  # Interaction handling
│   ├── CardStatusTracker.swift         # Status tracking
│   └── SubagentContextTracker.swift    # Subagent breadcrumbs
│
├── Models/
│   ├── ChatMessage.swift
│   ├── Session.swift
│   ├── Project.swift
│   └── ToolInvocation.swift
│
└── Extensions/
    ├── View+Glass.swift
    ├── Color+Tokens.swift
    └── Font+Tokens.swift
```
