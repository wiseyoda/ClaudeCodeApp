//
//  StatusMessage.swift
//  CodingBridge
//
//  Created on 2025-12-31.
//
//  Data model for rotating status messages shown during Claude's thinking/executing states.
//  Supports rarity tiers, time-of-day variants, and seasonal messages.
//

import Foundation

// MARK: - StatusMessage

struct StatusMessage: Codable, Identifiable, Equatable {
    let id: String
    let text: String
    let emoji: String
    let rarity: Rarity
    let category: Category
    let timeOfDay: TimeOfDay?
    let seasonal: Season?
    var seen: Bool = false

    init(
        id: String? = nil,
        text: String,
        emoji: String,
        rarity: Rarity = .common,
        category: Category,
        timeOfDay: TimeOfDay? = nil,
        seasonal: Season? = nil
    ) {
        // Generate stable ID from content so it persists across app launches
        // This ensures seenMessageIds can match messages after restart
        self.id = id ?? Self.stableId(text: text, category: category, timeOfDay: timeOfDay, seasonal: seasonal)
        self.text = text
        self.emoji = emoji
        self.rarity = rarity
        self.category = category
        self.timeOfDay = timeOfDay
        self.seasonal = seasonal
    }

    /// Generate a stable ID from message content (survives app restarts)
    private static func stableId(text: String, category: Category, timeOfDay: TimeOfDay?, seasonal: Season?) -> String {
        // Create deterministic ID from content hash
        var components = [text, category.rawValue]
        if let time = timeOfDay { components.append(time.rawValue) }
        if let season = seasonal { components.append(season.rawValue) }
        let combined = components.joined(separator: "|")

        // Simple hash - take first 16 chars of SHA-like hash
        var hash: UInt64 = 5381
        for char in combined.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(char)
        }
        return String(format: "%016llx", hash)
    }

    // MARK: - Rarity

    enum Rarity: String, Codable, CaseIterable {
        case common
        case uncommon
        case rare
        case legendary

        var weight: Double {
            switch self {
            case .common: return 0.60
            case .uncommon: return 0.25
            case .rare: return 0.12
            case .legendary: return 0.03
            }
        }

        var displayColor: String {
            switch self {
            case .common: return "gray"
            case .uncommon: return "green"
            case .rare: return "blue"
            case .legendary: return "purple"
            }
        }
    }

    // MARK: - Category

    enum Category: String, Codable, CaseIterable {
        case thinking
        case executing
        case bash
        case read
        case edit
        case search  // Grep/Glob
        case web     // WebFetch/WebSearch
        case agent   // Task/Subagent
        case idle

        /// SF Symbol name for this category
        var icon: String {
            switch self {
            case .thinking: return "brain.head.profile"
            case .executing: return "hourglass"
            case .bash: return "terminal"
            case .read: return "doc.text"
            case .edit: return "pencil.line"
            case .search: return "magnifyingglass"
            case .web: return "globe"
            case .agent: return "person.2"
            case .idle: return "checkmark.circle"
            }
        }

        /// Symbol effect for animation
        var symbolEffect: SymbolEffectType {
            switch self {
            case .thinking: return .pulse
            case .executing: return .variableColor
            case .bash: return .variableColor
            case .read: return .pulse
            case .edit: return .bounce
            case .search: return .pulse
            case .web: return .pulse
            case .agent: return .variableColor
            case .idle: return .none
            }
        }
    }

    // MARK: - TimeOfDay

    enum TimeOfDay: String, Codable, CaseIterable {
        case morning    // 5am - 12pm
        case afternoon  // 12pm - 5pm
        case evening    // 5pm - 9pm
        case night      // 9pm - 5am
        case weekend    // Sat/Sun any time

        static func current() -> TimeOfDay {
            let calendar = Calendar.current
            let now = Date()
            let hour = calendar.component(.hour, from: now)
            let weekday = calendar.component(.weekday, from: now)

            // Weekend check (1 = Sunday, 7 = Saturday)
            if weekday == 1 || weekday == 7 {
                return .weekend
            }

            switch hour {
            case 5..<12: return .morning
            case 12..<17: return .afternoon
            case 17..<21: return .evening
            default: return .night
            }
        }
    }

    // MARK: - Season

    enum Season: String, Codable, CaseIterable {
        case spring
        case summer
        case fall
        case winter
        case halloween   // Oct 15 - Nov 1
        case christmas   // Dec 15 - Dec 26
        case newYear     // Dec 31 - Jan 2
        case valentine   // Feb 13 - Feb 15

        static func current() -> Season? {
            let calendar = Calendar.current
            let now = Date()
            let month = calendar.component(.month, from: now)
            let day = calendar.component(.day, from: now)

            // Check special seasons first
            if month == 10 && day >= 15 || month == 11 && day <= 1 {
                return .halloween
            }
            if month == 12 && day >= 15 && day <= 26 {
                return .christmas
            }
            if month == 12 && day >= 31 || month == 1 && day <= 2 {
                return .newYear
            }
            if month == 2 && day >= 13 && day <= 15 {
                return .valentine
            }

            return nil  // No special season active
        }
    }

    // MARK: - Symbol Effect Type

    enum SymbolEffectType: String, Codable {
        case pulse
        case bounce
        case variableColor
        case none
    }
}

// MARK: - StatusMessage Convenience Initializers

extension StatusMessage {
    /// Create a simple message for a category
    static func simple(_ text: String, emoji: String, category: Category) -> StatusMessage {
        StatusMessage(text: text, emoji: emoji, category: category)
    }

    /// Create an uncommon message
    static func uncommon(_ text: String, emoji: String, category: Category) -> StatusMessage {
        StatusMessage(text: text, emoji: emoji, rarity: .uncommon, category: category)
    }

    /// Create a rare message
    static func rare(_ text: String, emoji: String, category: Category) -> StatusMessage {
        StatusMessage(text: text, emoji: emoji, rarity: .rare, category: category)
    }

    /// Create a legendary message
    static func legendary(_ text: String, emoji: String, category: Category) -> StatusMessage {
        StatusMessage(text: text, emoji: emoji, rarity: .legendary, category: category)
    }

    /// Create a time-specific message
    static func timed(_ text: String, emoji: String, category: Category, time: TimeOfDay, rarity: Rarity = .uncommon) -> StatusMessage {
        StatusMessage(text: text, emoji: emoji, rarity: rarity, category: category, timeOfDay: time)
    }

    /// Create a seasonal message
    static func seasonal(_ text: String, emoji: String, category: Category, season: Season, rarity: Rarity = .uncommon) -> StatusMessage {
        StatusMessage(text: text, emoji: emoji, rarity: rarity, category: category, seasonal: season)
    }
}

// MARK: - Collection Progress

struct MessageCollectionProgress: Codable {
    var seenMessageIds: Set<String> = []
    var lastUpdated: Date = Date()

    var totalSeen: Int { seenMessageIds.count }

    func seenCount(for rarity: StatusMessage.Rarity, in pool: [StatusMessage]) -> Int {
        pool.filter { $0.rarity == rarity && seenMessageIds.contains($0.id) }.count
    }

    func totalCount(for rarity: StatusMessage.Rarity, in pool: [StatusMessage]) -> Int {
        pool.filter { $0.rarity == rarity }.count
    }

    func percentage(for rarity: StatusMessage.Rarity, in pool: [StatusMessage]) -> Double {
        let total = totalCount(for: rarity, in: pool)
        guard total > 0 else { return 0 }
        return Double(seenCount(for: rarity, in: pool)) / Double(total) * 100
    }

    mutating func markSeen(_ message: StatusMessage) {
        seenMessageIds.insert(message.id)
        lastUpdated = Date()
    }

    mutating func reset() {
        seenMessageIds.removeAll()
        lastUpdated = Date()
    }
}
