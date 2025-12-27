import SwiftUI

/// Full editor for creating and editing ideas with title, text, and tags
struct IdeaEditorSheet: View {
    @Binding var isPresented: Bool
    @Binding var idea: Idea
    let existingTags: [String]  // For autocomplete
    let isNew: Bool
    let onSave: () -> Void
    let onDelete: (() -> Void)?

    @State private var tagInput = ""
    @State private var showDeleteConfirmation = false
    @FocusState private var focusedField: Field?

    @Environment(\.colorScheme) private var colorScheme

    private enum Field: Hashable {
        case title
        case text
        case tag
    }

    private let tagColors: [Color] = [
        .blue, .purple, .pink, .orange, .green, .cyan, .indigo, .mint, .teal
    ]

    var body: some View {
        NavigationStack {
            Form {
                // Title section
                Section {
                    TextField("Brief label (optional)", text: Binding(
                        get: { idea.title ?? "" },
                        set: { idea.title = $0.isEmpty ? nil : $0 }
                    ))
                    .focused($focusedField, equals: .title)
                } header: {
                    Text("Title")
                } footer: {
                    Text("A short label to identify this idea quickly")
                }

                // Content section
                Section {
                    TextEditor(text: $idea.text)
                        .focused($focusedField, equals: .text)
                        .frame(minHeight: 120)
                } header: {
                    Text("Idea")
                }

                // Tags section
                Section {
                    // Current tags
                    if !idea.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(idea.tags, id: \.self) { tag in
                                    RemovableTagChip(
                                        tag: tag,
                                        color: colorForTag(tag)
                                    ) {
                                        removeTag(tag)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    // Tag input with autocomplete
                    HStack {
                        TextField("Add tag", text: $tagInput)
                            .focused($focusedField, equals: .tag)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit {
                                addTag()
                            }

                        Button {
                            addTag()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(tagInput.isEmpty ? .secondary : .blue)
                        }
                        .disabled(tagInput.isEmpty)
                    }

                    // Autocomplete suggestions
                    if !tagInput.isEmpty {
                        let suggestions = filteredSuggestions
                        if !suggestions.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(suggestions, id: \.self) { suggestion in
                                        Button {
                                            tagInput = suggestion
                                            addTag()
                                        } label: {
                                            Text(suggestion)
                                                .font(.caption)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(Color.secondary.opacity(0.2))
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text("Tags")
                } footer: {
                    Text("Organize ideas with free-form tags")
                }

                // Delete section (only for existing ideas)
                if !isNew, onDelete != nil {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Idea")
                            }
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "New Idea" : "Edit Idea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                    .disabled(idea.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                // Focus on text field for new ideas
                if isNew {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        focusedField = .text
                    }
                }
            }
            .confirmationDialog(
                "Delete this idea?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    onDelete?()
                    isPresented = false
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }

    // MARK: - Tag Management

    private var filteredSuggestions: [String] {
        let lowercased = tagInput.lowercased()
        return existingTags
            .filter { tag in
                tag.lowercased().contains(lowercased) && !idea.tags.contains(tag)
            }
            .prefix(5)
            .map { $0 }
    }

    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !idea.tags.contains(trimmed) else {
            tagInput = ""
            return
        }

        idea.tags.append(trimmed)
        tagInput = ""
    }

    private func removeTag(_ tag: String) {
        idea.tags.removeAll { $0 == tag }
    }

    private func colorForTag(_ tag: String) -> Color {
        tagColors[abs(tag.hashValue) % tagColors.count]
    }
}

// MARK: - Preview

#Preview("New Idea") {
    struct PreviewWrapper: View {
        @State private var isPresented = true
        @State private var idea = Idea(text: "")

        var body: some View {
            Color.gray
                .sheet(isPresented: $isPresented) {
                    IdeaEditorSheet(
                        isPresented: $isPresented,
                        idea: $idea,
                        existingTags: ["swift", "ios", "bug", "feature", "refactoring"],
                        isNew: true,
                        onSave: { print("Saved: \(idea)") },
                        onDelete: nil
                    )
                }
        }
    }

    return PreviewWrapper()
}

#Preview("Edit Idea") {
    struct PreviewWrapper: View {
        @State private var isPresented = true
        @State private var idea = Idea(
            text: "Add dark mode support to the settings page",
            title: "Dark Mode",
            tags: ["feature", "ui"]
        )

        var body: some View {
            Color.gray
                .sheet(isPresented: $isPresented) {
                    IdeaEditorSheet(
                        isPresented: $isPresented,
                        idea: $idea,
                        existingTags: ["swift", "ios", "bug", "feature", "refactoring", "ui"],
                        isNew: false,
                        onSave: { print("Saved: \(idea)") },
                        onDelete: { print("Deleted") }
                    )
                }
        }
    }

    return PreviewWrapper()
}
