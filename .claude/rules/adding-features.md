# Adding New Features

## Adding a New Tool Type

1. Add case to `ToolType` enum in `Models.swift`
2. Add icon (SF Symbol) in `ToolType.icon`
3. Add color in `ToolType.color`
4. Add display name in `ToolType.displayName`
5. Update `CLIMessageView` if special rendering needed

## Adding a New Persistence Store

1. Create `YourStore.swift` following `CommandStore` pattern
2. Use `Documents` directory for data files
3. Encode path: replace `/` with `-`, prefix with `-`
4. Add Codable model for data
5. Load on init, save on changes

```swift
@MainActor
class YourStore: ObservableObject {
    static let shared = YourStore()
    @Published var items: [Item] = []

    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("your-data.json")
    }

    init() { load() }

    func load() { /* Codable decode from fileURL */ }
    func save() { /* Codable encode to fileURL */ }
}
```

## Adding a New Sheet/Modal

1. Create `YourSheet.swift` in `Views/`
2. Add `@State private var showYourSheet = false` in parent
3. Add `.sheet(isPresented: $showYourSheet) { YourSheet() }`
4. Use `@Environment(\.dismiss) var dismiss` to close

## Adding a New Slash Command

1. Find `handleSlashCommand()` in `ChatView.swift`
2. Add case in the switch statement
3. Implement handler function
4. Add to `/help` command list
