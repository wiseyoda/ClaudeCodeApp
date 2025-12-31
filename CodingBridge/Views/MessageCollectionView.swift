//
//  MessageCollectionView.swift
//  CodingBridge
//
//  Created on 2025-12-31.
//
//  Settings UI for viewing status message collection progress.
//  Shows progress bars by rarity tier and total collection percentage.
//

import SwiftUI

// MARK: - MessageCollectionView

struct MessageCollectionView: View {
    @ObservedObject private var store = StatusMessageStore.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var showAllMessages = false
    @State private var showResetConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Progress bars for each rarity
            ForEach(StatusMessage.Rarity.allCases, id: \.self) { rarity in
                RarityProgressRow(
                    rarity: rarity,
                    seen: store.seenCount(for: rarity),
                    total: store.totalCount(for: rarity)
                )
            }

            // Divider
            Rectangle()
                .fill(Color(white: colorScheme == .dark ? 0.3 : 0.8))
                .frame(height: 1)
                .padding(.vertical, 4)

            // Total progress
            TotalProgressRow(
                seen: store.collectionProgress.totalSeen,
                total: store.totalMessages
            )

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    showAllMessages = true
                } label: {
                    Label("View All", systemImage: "list.bullet")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 4)
        }
        .sheet(isPresented: $showAllMessages) {
            AllMessagesSheet()
        }
        .confirmationDialog(
            "Reset Collection Progress?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset Progress", role: .destructive) {
                store.resetProgress()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset all message collection progress. You'll need to see messages again to rebuild your collection.")
        }
    }
}

// MARK: - Rarity Progress Row

private struct RarityProgressRow: View {
    let rarity: StatusMessage.Rarity
    let seen: Int
    let total: Int

    @Environment(\.colorScheme) var colorScheme

    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(seen) / Double(total)
    }

    private var rarityColor: Color {
        switch rarity {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .legendary: return Color(red: 0.7, green: 0.4, blue: 0.9)  // Purple/gold
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            // Rarity label
            Text(rarity.rawValue.capitalized)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(rarityColor)
                .frame(width: 70, alignment: .leading)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(white: colorScheme == .dark ? 0.2 : 0.9))

                    // Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(rarityColor.opacity(0.8))
                        .frame(width: geometry.size.width * percentage)
                }
            }
            .frame(height: 8)

            // Count
            Text("\(seen)/\(total)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)

            // Percentage
            Text("\(Int(percentage * 100))%")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(percentage >= 1.0 ? .green : .secondary)
                .frame(width: 35, alignment: .trailing)
        }
    }
}

// MARK: - Total Progress Row

private struct TotalProgressRow: View {
    let seen: Int
    let total: Int

    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(seen) / Double(total)
    }

    var body: some View {
        HStack {
            Text("Total")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))

            Spacer()

            Text("\(seen)/\(total)")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)

            Text("(\(Int(percentage * 100))%)")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(percentage >= 1.0 ? .green : .primary)
        }
    }
}

// MARK: - All Messages Sheet

struct AllMessagesSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var store = StatusMessageStore.shared
    @State private var selectedRarity: StatusMessage.Rarity?
    @State private var selectedCategory: StatusMessage.Category?

    var body: some View {
        NavigationStack {
            List {
                // Filter section
                Section {
                    Picker("Rarity", selection: $selectedRarity) {
                        Text("All").tag(nil as StatusMessage.Rarity?)
                        ForEach(StatusMessage.Rarity.allCases, id: \.self) { rarity in
                            Text(rarity.rawValue.capitalized).tag(rarity as StatusMessage.Rarity?)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Category", selection: $selectedCategory) {
                        Text("All").tag(nil as StatusMessage.Category?)
                        ForEach(StatusMessage.Category.allCases, id: \.self) { category in
                            Text(category.rawValue.capitalized).tag(category as StatusMessage.Category?)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Messages list
                Section {
                    ForEach(filteredMessages, id: \.id) { message in
                        MessageRow(message: message, isSeen: store.collectionProgress.seenMessageIds.contains(message.id))
                    }
                } header: {
                    Text("\(filteredMessages.count) messages")
                }
            }
            .navigationTitle("Message Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var filteredMessages: [StatusMessage] {
        store.allMessagesForDisplay.filter { message in
            (selectedRarity == nil || message.rarity == selectedRarity) &&
            (selectedCategory == nil || message.category == selectedCategory)
        }
    }
}

// MARK: - Message Row

private struct MessageRow: View {
    let message: StatusMessage
    let isSeen: Bool

    @Environment(\.colorScheme) var colorScheme

    private var rarityColor: Color {
        switch message.rarity {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .legendary: return Color(red: 0.7, green: 0.4, blue: 0.9)
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            // Emoji
            Text(message.emoji.isEmpty ? "  " : message.emoji)
                .font(.system(size: 16))
                .frame(width: 24)

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(message.text)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(isSeen ? .primary : .secondary)

                HStack(spacing: 6) {
                    // Rarity badge
                    Text(message.rarity.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(rarityColor.opacity(0.2))
                        .foregroundStyle(rarityColor)
                        .clipShape(RoundedRectangle(cornerRadius: 3))

                    // Category
                    Text(message.category.rawValue)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)

                    // Time/Season indicator
                    if let time = message.timeOfDay {
                        Text(time.rawValue)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.orange)
                    }
                    if let season = message.seasonal {
                        Text(season.rawValue)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.purple)
                    }
                }
            }

            Spacer()

            // Seen indicator
            if isSeen {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - StatusMessageStore Extension

extension StatusMessageStore {
    /// Expose all messages for the collection view (read-only)
    var allMessagesForDisplay: [StatusMessage] {
        allMessages
    }
}

// MARK: - Preview

#Preview("Collection Progress") {
    Form {
        Section("Message Collection") {
            MessageCollectionView()
        }
    }
}

#Preview("All Messages") {
    AllMessagesSheet()
}
