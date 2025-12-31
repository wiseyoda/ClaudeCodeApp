import SwiftUI

/// Root tab bar navigation for the app
/// Shows 5 tabs: Home, Terminal, New Project (sheet), Commands, Settings
struct MainTabView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @State private var selectedTab: Tab = .home
    @State private var showNewProject = false
    @State private var showCloneProject = false
    private var commandStore = CommandStore.shared  // @Observable classes don't need @ObservedObject

    enum Tab: Hashable {
        case home
        case terminal
        case newProject  // Triggers sheet, not a real destination
        case commands
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Home (ContentView handles adaptive layout)
            ContentView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(Tab.home)

            // Tab 2: Terminal
            NavigationStack {
                TerminalView()
                    .navigationTitle("Terminal")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
            }
            .tabItem {
                Label("Terminal", systemImage: "terminal.fill")
            }
            .tag(Tab.terminal)

            // Tab 3: New Project (placeholder - triggers sheet)
            Color.clear
                .tabItem {
                    Label("New", systemImage: "plus.circle.fill")
                }
                .tag(Tab.newProject)

            // Tab 4: Commands
            CommandsTabView(commandStore: commandStore)
                .tabItem {
                    Label("Commands", systemImage: "text.book.closed.fill")
                }
                .tag(Tab.commands)

            // Tab 5: Settings
            SettingsView(showDismissButton: false)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(Tab.settings)
        }
        .tint(CLITheme.cyan(for: colorScheme))
        .onChange(of: selectedTab) { _, newTab in
            // When "New" tab is tapped, show sheet and reset to home
            if newTab == .newProject {
                showNewProject = true
                // Reset to home after small delay to allow sheet to appear
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    selectedTab = .home
                }
            }
        }
        .sheet(isPresented: $showNewProject) {
            NewProjectSheet {
                // Refresh projects after creation
                // ContentView handles this via its own state
            }
        }
        .sheet(isPresented: $showCloneProject) {
            CloneProjectSheet {
                // Refresh projects after cloning
            }
        }
    }
}

// MARK: - Commands Tab View (Standalone version without dismiss button)

/// Standalone version of CommandsView for tab embedding
/// Removes the "Done" button since we're not in a sheet
struct CommandsTabView: View {
    var commandStore: CommandStore  // @Observable classes don't need @ObservedObject
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    @State private var showingAddCategory = false
    @State private var newCategoryName = ""
    @State private var showingAddCommand = false
    @State private var selectedCategory: String?

    var body: some View {
        NavigationStack {
            List {
                if commandStore.categories.isEmpty {
                    emptyState
                } else {
                    ForEach(commandStore.categories, id: \.self) { category in
                        NavigationLink(value: category) {
                            CategoryRow(
                                category: category,
                                count: commandStore.count(in: category),
                                settings: settings,
                                colorScheme: colorScheme
                            )
                        }
                        .listRowBackground(CLITheme.background(for: colorScheme))
                    }
                    .onDelete(perform: deleteCategories)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(CLITheme.background(for: colorScheme))
            .navigationTitle("Commands")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationDestination(for: String.self) { category in
                CommandListView(
                    category: category,
                    commandStore: commandStore
                )
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingAddCommand = true
                        } label: {
                            Label("New Command", systemImage: "plus")
                        }

                        Button {
                            showingAddCategory = true
                        } label: {
                            Label("New Category", systemImage: "folder.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("New Category", isPresented: $showingAddCategory) {
                TextField("Category name", text: $newCategoryName)
                Button("Cancel", role: .cancel) {
                    newCategoryName = ""
                }
                Button("Create") {
                    if !newCategoryName.isEmpty {
                        // Create a placeholder command in the new category
                        selectedCategory = newCategoryName
                        newCategoryName = ""
                        showingAddCommand = true
                    }
                }
            }
            .sheet(isPresented: $showingAddCommand) {
                CommandEditorSheet(
                    commandStore: commandStore,
                    initialCategory: selectedCategory
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 48))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))

            Text("No Saved Commands")
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.primaryText(for: colorScheme))

            Text("Save frequently used commands for quick access")
                .font(settings.scaledFont(.small))
                .foregroundColor(CLITheme.mutedText(for: colorScheme))
                .multilineTextAlignment(.center)

            Button {
                showingAddCategory = true
            } label: {
                Label("Create Category", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func deleteCategories(at offsets: IndexSet) {
        let categoriesToDelete = offsets.map { commandStore.categories[$0] }
        for category in categoriesToDelete {
            // Delete all commands in this category
            let commands = commandStore.commands(in: category)
            for command in commands {
                commandStore.delete(command)
            }
        }
    }
}


#Preview {
    MainTabView()
        .environmentObject(AppSettings())
}
