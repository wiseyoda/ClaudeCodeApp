import SwiftUI

/// Main drawer view for managing and browsing ideas
struct IdeasDrawerSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject var ideasStore: IdeasStore
    let projectPath: String
    let onSendIdea: (Idea) -> Void

    @State private var searchText = ""
    @State private var selectedTag: String?
    @State private var showNewIdeaEditor = false
    @State private var editingIdea: Idea?
    @State private var newIdea = Idea(text: "")
    @State private var showArchived = false

    @Environment(\.colorScheme) private var colorScheme

    private let tagColors: [Color] = [
        .blue, .purple, .pink, .orange, .green, .cyan, .indigo, .mint, .teal
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tag filter chips
                if !ideasStore.allTags.isEmpty {
                    tagFilterSection
                }

                // Ideas list
                if filteredIdeas.isEmpty {
                    emptyState
                } else {
                    ideasList
                }
            }
            .background(CLITheme.background(for: colorScheme))
            .navigationTitle("Ideas")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search ideas...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .principal) {
                    // Archive toggle with count badge
                    Button {
                        withAnimation {
                            showArchived.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showArchived ? "tray.full" : "archivebox")
                            Text(showArchived ? "Archived (\(ideasStore.archivedCount))" : "Active (\(ideasStore.activeCount))")
                                .font(.subheadline)
                        }
                        .foregroundStyle(showArchived ? CLITheme.orange(for: colorScheme) : CLITheme.primaryText(for: colorScheme))
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNewIdeaEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(showArchived) // Can't add to archive directly
                }
            }
            .sheet(isPresented: $showNewIdeaEditor) {
                newIdeaSheet
            }
            .sheet(item: $editingIdea) { idea in
                editIdeaSheet(for: idea)
            }
        }
    }

    // MARK: - Tag Filter Section

    private var tagFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" chip
                TagFilterChip(
                    tag: "All",
                    isSelected: selectedTag == nil,
                    color: .secondary
                ) {
                    selectedTag = nil
                }

                // Tag chips
                ForEach(ideasStore.allTags, id: \.self) { tag in
                    TagFilterChip(
                        tag: tag,
                        isSelected: selectedTag == tag,
                        color: colorForTag(tag)
                    ) {
                        selectedTag = selectedTag == tag ? nil : tag
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(CLITheme.secondaryBackground(for: colorScheme))
    }

    // MARK: - Ideas List

    private var ideasList: some View {
        List {
            ForEach(filteredIdeas) { idea in
                IdeaRowView(
                    idea: idea,
                    onSend: {
                        sendIdea(idea)
                    },
                    onEdit: {
                        editingIdea = idea
                    },
                    onArchiveToggle: {
                        toggleArchive(idea)
                    },
                    onDelete: {
                        deleteIdea(idea)
                    }
                )
            }
            .onDelete(perform: deleteIdeas)
        }
        .listStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: showArchived ? "archivebox" : "lightbulb")
                .font(.system(size: 48))
                .foregroundStyle(CLITheme.mutedText(for: colorScheme))

            if showArchived {
                // Archive empty state
                if searchText.isEmpty && selectedTag == nil {
                    Text("No archived ideas")
                        .font(.headline)
                        .foregroundStyle(CLITheme.secondaryText(for: colorScheme))

                    Text("Archived ideas will appear here.\nSwipe left on an idea to archive it.")
                        .font(.subheadline)
                        .foregroundStyle(CLITheme.mutedText(for: colorScheme))
                        .multilineTextAlignment(.center)

                    Button {
                        showArchived = false
                    } label: {
                        Label("View Active Ideas", systemImage: "tray.full")
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 8)
                } else {
                    Text("No matching archived ideas")
                        .font(.headline)
                        .foregroundStyle(CLITheme.secondaryText(for: colorScheme))

                    Button {
                        searchText = ""
                        selectedTag = nil
                    } label: {
                        Text("Clear filters")
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                // Active ideas empty state
                if searchText.isEmpty && selectedTag == nil {
                    Text("No ideas yet")
                        .font(.headline)
                        .foregroundStyle(CLITheme.secondaryText(for: colorScheme))

                    Text("Capture ideas while Claude is working.\nLong-press the lightbulb for quick capture.")
                        .font(.subheadline)
                        .foregroundStyle(CLITheme.mutedText(for: colorScheme))
                        .multilineTextAlignment(.center)

                    Button {
                        showNewIdeaEditor = true
                    } label: {
                        Label("Add First Idea", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
                } else {
                    Text("No matching ideas")
                        .font(.headline)
                        .foregroundStyle(CLITheme.secondaryText(for: colorScheme))

                    Button {
                        searchText = ""
                        selectedTag = nil
                    } label: {
                        Text("Clear filters")
                    }
                    .buttonStyle(.bordered)
                }
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Sheets

    private var newIdeaSheet: some View {
        IdeaEditorSheet(
            isPresented: $showNewIdeaEditor,
            idea: $newIdea,
            existingTags: ideasStore.allTags,
            isNew: true,
            onSave: {
                let trimmedText = newIdea.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedText.isEmpty {
                    ideasStore.add(newIdea)
                }
                // Reset for next time
                newIdea = Idea(text: "")
            },
            onDelete: nil
        )
    }

    private func editIdeaSheet(for idea: Idea) -> some View {
        // Create a binding that updates the store
        let binding = Binding<Idea>(
            get: {
                ideasStore.ideas.first { $0.id == idea.id } ?? idea
            },
            set: { newValue in
                ideasStore.update(newValue)
            }
        )

        return IdeaEditorSheet(
            isPresented: Binding(
                get: { editingIdea != nil },
                set: { if !$0 { editingIdea = nil } }
            ),
            idea: binding,
            existingTags: ideasStore.allTags,
            isNew: false,
            onSave: {
                // Already saved via binding
            },
            onDelete: {
                deleteIdea(idea)
            }
        )
    }

    // MARK: - Computed Properties

    private var filteredIdeas: [Idea] {
        ideasStore.filter(byTag: selectedTag, searchText: searchText, showArchived: showArchived)
    }

    // MARK: - Actions

    private func sendIdea(_ idea: Idea) {
        onSendIdea(idea)
        isPresented = false
    }

    private func deleteIdea(_ idea: Idea) {
        withAnimation {
            ideasStore.delete(idea)
        }
    }

    private func deleteIdeas(at offsets: IndexSet) {
        let ideas = filteredIdeas
        for index in offsets {
            ideasStore.delete(ideas[index])
        }
    }

    private func toggleArchive(_ idea: Idea) {
        withAnimation {
            if idea.isArchived {
                ideasStore.unarchive(idea)
            } else {
                ideasStore.archive(idea)
            }
        }
    }

    private func colorForTag(_ tag: String) -> Color {
        tagColors[abs(tag.hashValue) % tagColors.count]
    }
}

// MARK: - Preview

#Preview("Ideas Drawer") {
    struct PreviewWrapper: View {
        @State private var isPresented = true
        @StateObject private var ideasStore = IdeasStore(projectPath: "/preview/project")

        var body: some View {
            Color.gray
                .sheet(isPresented: $isPresented) {
                    IdeasDrawerSheet(
                        isPresented: $isPresented,
                        ideasStore: ideasStore,
                        projectPath: "/preview/project"
                    ) { idea in
                        print("Send: \(idea.text)")
                    }
                }
                .onAppear {
                    ideasStore.add(Idea(
                        text: "Add dark mode support",
                        title: "Dark Mode",
                        tags: ["feature", "ui"]
                    ))
                    ideasStore.add(Idea(
                        text: "Fix the bug where messages don't scroll properly",
                        tags: ["bug"]
                    ))
                    ideasStore.add(Idea(
                        text: "Refactor the WebSocket manager for better reconnection handling",
                        title: "WebSocket Refactor",
                        tags: ["refactoring", "networking"]
                    ))
                }
        }
    }

    return PreviewWrapper()
}

#Preview("Empty State") {
    struct PreviewWrapper: View {
        @State private var isPresented = true
        @StateObject private var ideasStore = IdeasStore(projectPath: "/empty/project")

        var body: some View {
            Color.gray
                .sheet(isPresented: $isPresented) {
                    IdeasDrawerSheet(
                        isPresented: $isPresented,
                        ideasStore: ideasStore,
                        projectPath: "/empty/project"
                    ) { _ in }
                }
        }
    }

    return PreviewWrapper()
}
