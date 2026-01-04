# Issue 31: File Browser Redesign

**Phase:** 5 (Secondary Views)
**Priority:** Medium
**Status:** Not Started
**Depends On:** Issue #17 (Liquid Glass), Issue #23 (Navigation)

## Goal

Redesign the file browser with Liquid Glass styling, improved navigation, and better file preview capabilities.

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- Depends On: Issue #17 (Liquid Glass), Issue #23 (Navigation).
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
## Design

```
┌─────────────────────────────────────────────────────────┐
│ ←  Files                    🔍       ⋯  │
├─────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────────┐ │
│ │ 📁 ~/workspace/my-project                           │ │
│ │ ─────────────────────────────────────────────────── │ │
│ │ 📁 ..                                               │ │
│ │ 📁 src/                                             │ │
│ │ 📁 tests/                                           │ │
│ │ 📁 docs/                                            │ │
│ │ ─────────────────────────────────────────────────── │ │
│ │ 📄 README.md                           3.2 KB      │ │
│ │ 📄 package.json                        1.1 KB      │ │
│ │ 📄 tsconfig.json                       0.8 KB      │ │
│ │ 📄 .gitignore                          0.2 KB      │ │
│ │ 🖼️ logo.png                           24.5 KB      │ │
│ └─────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────────┐ │
│ │ 📁 Quick Access                                     │ │
│ │ 🏠 Home   📂 Projects   📥 Downloads   ⭐ Starred  │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## Implementation

### FileBrowserView

```swift
struct FileBrowserView: View {
    let initialPath: String?

    @State private var viewModel: FileBrowserViewModel
    @State private var searchText = ""
    @State private var showNewFolderSheet = false

    @Environment(\.dismiss) var dismiss

    init(initialPath: String? = nil) {
        self.initialPath = initialPath
        self._viewModel = State(initialValue: FileBrowserViewModel(initialPath: initialPath))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Current path breadcrumb
            PathBreadcrumbView(
                path: viewModel.currentPath,
                onNavigate: { viewModel.navigateTo($0) }
            )

            // File list
            FileListView(
                items: viewModel.filteredItems(searchText: searchText),
                isLoading: viewModel.isLoading,
                onSelect: handleSelection,
                onDelete: viewModel.deleteItem,
                onRename: viewModel.renameItem
            )

            // Quick access bar
            QuickAccessBar(
                onNavigate: viewModel.navigateTo,
                starred: viewModel.starredPaths
            )
        }
        .navigationTitle("Files")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Filter files")
        .toolbar {
            FileBrowserToolbar(
                onNewFolder: { showNewFolderSheet = true },
                onRefresh: { Task { await viewModel.refresh() } },
                sortOrder: $viewModel.sortOrder
            )
        }
        .sheet(isPresented: $showNewFolderSheet) {
            NewFolderSheet(
                currentPath: viewModel.currentPath,
                onCreate: { name in
                    Task { await viewModel.createFolder(name: name) }
                }
            )
        }
        .task {
            await viewModel.loadDirectory()
        }
    }

    private func handleSelection(_ item: FileItem) {
        if item.isDirectory {
            viewModel.navigateTo(item.path)
        } else {
            // Open file viewer or return selection
        }
    }
}
```

### FileBrowserViewModel

```swift
@MainActor @Observable
final class FileBrowserViewModel {
    private(set) var currentPath: String
    private(set) var items: [FileItem] = []
    private(set) var isLoading = false
    private(set) var starredPaths: [String] = []

    var sortOrder: SortOrder = .name

    private var sshManager: SSHManager?

    init(initialPath: String? = nil) {
        self.currentPath = initialPath ?? "$HOME"
        loadStarredPaths()
    }

    func loadDirectory() async {
        isLoading = true
        defer { isLoading = false }

        do {
            sshManager = sshManager ?? SSHManager()
            try await sshManager?.connectWithSavedCredentials()
            items = try await sshManager?.listFiles(at: currentPath) ?? []
            sortItems()
        } catch {
            Logger.error("Failed to load directory: \(error)")
        }
    }

    func navigateTo(_ path: String) {
        currentPath = path
        Task { await loadDirectory() }
    }

    func refresh() async {
        await loadDirectory()
    }

    func filteredItems(searchText: String) -> [FileItem] {
        if searchText.isEmpty {
            return items
        }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    func createFolder(name: String) async {
        do {
            try await sshManager?.createDirectory(at: "\(currentPath)/\(name)")
            await loadDirectory()
        } catch {
            Logger.error("Failed to create folder: \(error)")
        }
    }

    func deleteItem(_ item: FileItem) async {
        do {
            try await sshManager?.deleteFile(at: item.path)
            items.removeAll { $0.id == item.id }
        } catch {
            Logger.error("Failed to delete: \(error)")
        }
    }

    func renameItem(_ item: FileItem, newName: String) async {
        do {
            let newPath = (currentPath as NSString).appendingPathComponent(newName)
            try await sshManager?.rename(from: item.path, to: newPath)
            await loadDirectory()
        } catch {
            Logger.error("Failed to rename: \(error)")
        }
    }

    func toggleStar(_ path: String) {
        if starredPaths.contains(path) {
            starredPaths.removeAll { $0 == path }
        } else {
            starredPaths.append(path)
        }
        saveStarredPaths()
    }

    private func sortItems() {
        items.sort { lhs, rhs in
            // Directories first
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory
            }

            switch sortOrder {
            case .name:
                return lhs.name.localizedCompare(rhs.name) == .orderedAscending
            case .date:
                return lhs.modifiedDate > rhs.modifiedDate
            case .size:
                return lhs.size > rhs.size
            }
        }
    }

    private func loadStarredPaths() {
        starredPaths = UserDefaults.standard.stringArray(forKey: "starredPaths") ?? []
    }

    private func saveStarredPaths() {
        UserDefaults.standard.set(starredPaths, forKey: "starredPaths")
    }
}

enum SortOrder: String, CaseIterable {
    case name, date, size

    var displayName: String {
        switch self {
        case .name: return "Name"
        case .date: return "Date"
        case .size: return "Size"
        }
    }
}
```

### FileItem Model

```swift
struct FileItem: Identifiable, Hashable {
    let id: String
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
    let modifiedDate: Date
    let permissions: String

    var icon: String {
        if isDirectory {
            return "folder.fill"
        }

        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift", "ts", "js", "py", "go", "rs":
            return "doc.text.fill"
        case "json", "yaml", "yml", "toml":
            return "doc.badge.gearshape.fill"
        case "md", "txt", "rtf":
            return "doc.plaintext.fill"
        case "png", "jpg", "jpeg", "gif", "webp":
            return "photo.fill"
        case "pdf":
            return "doc.richtext.fill"
        default:
            return "doc.fill"
        }
    }

    var iconColor: Color {
        if isDirectory { return .blue }

        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return .orange
        case "ts", "js": return .yellow
        case "py": return .green
        case "json", "yaml", "yml": return .purple
        case "md": return .cyan
        default: return .secondary
        }
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
```

### FileListView

```swift
struct FileListView: View {
    let items: [FileItem]
    let isLoading: Bool
    let onSelect: (FileItem) -> Void
    let onDelete: (FileItem) async -> Void
    let onRename: (FileItem, String) async -> Void

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if items.isEmpty {
                ContentUnavailableView(
                    "Empty Folder",
                    systemImage: "folder",
                    description: Text("This folder has no files")
                )
            } else {
                List {
                    ForEach(items) { item in
                        FileRowView(item: item)
                            .contentShape(Rectangle())
                            .onTapGesture { onSelect(item) }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    Task { await onDelete(item) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                FileContextMenu(
                                    item: item,
                                    onOpen: { onSelect(item) },
                                    onRename: { newName in
                                        Task { await onRename(item, newName) }
                                    },
                                    onDelete: {
                                        Task { await onDelete(item) }
                                    }
                                )
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .glassEffectUnpadded()
    }
}
```

### FileRowView

```swift
struct FileRowView: View {
    let item: FileItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.title2)
                .foregroundStyle(item.iconColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .lineLimit(1)

                if !item.isDirectory {
                    Text(item.formattedSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if item.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
```

### PathBreadcrumbView

```swift
struct PathBreadcrumbView: View {
    let path: String
    let onNavigate: (String) -> Void

    var pathComponents: [(name: String, path: String)] {
        var components: [(String, String)] = []
        var currentPath = ""

        for component in path.split(separator: "/") {
            currentPath += "/\(component)"
            components.append((String(component), currentPath))
        }

        return components
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                Button {
                    onNavigate("$HOME")
                } label: {
                    Image(systemName: "house.fill")
                }

                ForEach(pathComponents, id: \.path) { component in
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Button(component.name) {
                        onNavigate(component.path)
                    }
                }
            }
            .font(.subheadline)
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .glassEffect()
    }
}
```

### QuickAccessBar

```swift
struct QuickAccessBar: View {
    let onNavigate: (String) -> Void
    let starred: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                QuickAccessButton(icon: "house.fill", label: "Home") {
                    onNavigate("$HOME")
                }

                QuickAccessButton(icon: "folder.fill", label: "Projects") {
                    onNavigate("$HOME/workspace")
                }

                QuickAccessButton(icon: "arrow.down.circle.fill", label: "Downloads") {
                    onNavigate("$HOME/Downloads")
                }

                if !starred.isEmpty {
                    Divider()
                        .frame(height: 24)

                    ForEach(starred, id: \.self) { path in
                        QuickAccessButton(
                            icon: "star.fill",
                            label: (path as NSString).lastPathComponent
                        ) {
                            onNavigate(path)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .glassEffect()
    }
}

struct QuickAccessButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: label)
    }
}
```

## Files to Create

```
CodingBridge/Features/Files/
├── FileBrowserView.swift          # ~100 lines
├── FileBrowserViewModel.swift     # ~120 lines
├── FileItem.swift                 # ~60 lines
├── FileListView.swift             # ~80 lines
├── FileRowView.swift              # ~40 lines
├── PathBreadcrumbView.swift       # ~50 lines
├── QuickAccessBar.swift           # ~60 lines
├── FileContextMenu.swift          # ~40 lines
└── NewFolderSheet.swift           # ~50 lines
```

## Files to Modify

| File | Changes |
|------|---------|
| Current `FileBrowserView.swift` | Replace with new implementation |
| `SSHManager.swift` | Add rename method |

## Security Checklist

- [ ] File paths passed to SSHManager are shell-escaped
- [ ] Use `$HOME` instead of `~` for remote paths
- [ ] No file contents or secrets logged
- [ ] Delete/rename actions require explicit user intent

## Acceptance Criteria

- [ ] Directory listing with icons
- [ ] File type detection and colors
- [ ] Breadcrumb navigation
- [ ] Quick access bar
- [ ] Starred folders
- [ ] Search/filter
- [ ] Create folder
- [ ] Delete with swipe
- [ ] Context menu actions
- [ ] Sort options
- [ ] Liquid Glass styling
- [ ] Security checklist complete
- [ ] Build passes

## Testing

```swift
struct FileBrowserTests: XCTestCase {
    func testFileIconMapping() {
        let swiftFile = FileItem(
            id: "1",
            name: "test.swift",
            path: "/test.swift",
            isDirectory: false,
            size: 1024,
            modifiedDate: .now,
            permissions: "-rw-r--r--"
        )

        XCTAssertEqual(swiftFile.icon, "doc.text.fill")
        XCTAssertEqual(swiftFile.iconColor, .orange)
    }

    func testSortOrder() {
        let viewModel = FileBrowserViewModel()

        viewModel.sortOrder = .name
        XCTAssertEqual(viewModel.sortOrder.displayName, "Name")
    }
}
```
