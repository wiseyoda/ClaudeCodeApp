//
//  StatusMessageStore.swift
//  CodingBridge
//
//  Created on 2025-12-31.
//
//  Manages status message pools with rarity-weighted selection, time-of-day filtering,
//  and collection progress tracking. Provides rotating fun/pop-culture messages for
//  the StatusBubbleView.
//

import Foundation

// MARK: - StatusMessageStore

@MainActor
class StatusMessageStore: ObservableObject {
    static let shared = StatusMessageStore()

    @Published private(set) var collectionProgress: MessageCollectionProgress

    private let allMessages: [StatusMessage]
    private var lastSelectedMessage: StatusMessage?
    private var lastCategory: StatusMessage.Category?

    private init() {
        self.allMessages = Self.buildMessagePool()
        self.collectionProgress = Self.loadProgress()
    }

    // MARK: - Message Selection

    /// Select a random message for the given state and optional tool
    func selectMessage(for state: CLIAgentState, tool: String? = nil) -> StatusMessage {
        let category = category(for: state, tool: tool)

        // Filter by category, time, and season
        let currentTime = StatusMessage.TimeOfDay.current()
        let currentSeason = StatusMessage.Season.current()

        var pool = allMessages.filter { message in
            message.category == category &&
            (message.timeOfDay == nil || message.timeOfDay == currentTime) &&
            (message.seasonal == nil || message.seasonal == currentSeason)
        }

        // If no messages match (shouldn't happen), fall back to category only
        if pool.isEmpty {
            pool = allMessages.filter { $0.category == category }
        }

        // Avoid repeating the same message twice in a row
        if let last = lastSelectedMessage, pool.count > 1 {
            pool = pool.filter { $0.id != last.id }
        }

        // Weighted random selection
        let selected = weightedRandom(from: pool)

        // Track selection
        lastSelectedMessage = selected
        lastCategory = category
        markSeen(selected)

        return selected
    }

    /// Get category for state/tool combination
    private func category(for state: CLIAgentState, tool: String?) -> StatusMessage.Category {
        switch state {
        case .thinking:
            return .thinking
        case .idle, .stopped:
            return .idle
        case .executing:
            guard let tool = tool else { return .executing }
            switch tool.lowercased() {
            case "bash", "bashoutput", "killshell":
                return .bash
            case "read", "glob", "grep", "ls":
                return tool.lowercased() == "read" ? .read : .search
            case "edit", "write", "notebookedit":
                return .edit
            case "webfetch", "websearch":
                return .web
            case "task", "todowrite":
                return .agent
            default:
                // MCP tools and others default to executing
                return .executing
            }
        case .starting, .waitingInput, .waitingPermission, .recovering:
            return .executing
        }
    }

    /// Weighted random selection based on rarity
    private func weightedRandom(from pool: [StatusMessage]) -> StatusMessage {
        guard !pool.isEmpty else {
            // Fallback
            return StatusMessage.simple("Working...", emoji: "⏳", category: .executing)
        }

        // Calculate total weight
        let totalWeight = pool.reduce(0.0) { $0 + $1.rarity.weight }

        // Pick random point
        var random = Double.random(in: 0..<totalWeight)

        // Find message at that point
        for message in pool.shuffled() {
            random -= message.rarity.weight
            if random <= 0 {
                return message
            }
        }

        return pool.randomElement()!
    }

    // MARK: - Collection Progress

    private func markSeen(_ message: StatusMessage) {
        collectionProgress.markSeen(message)
        saveProgress()
    }

    func resetProgress() {
        collectionProgress.reset()
        saveProgress()
    }

    private func saveProgress() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(collectionProgress) {
            UserDefaults.standard.set(data, forKey: "statusMessageProgress")
        }
    }

    private static func loadProgress() -> MessageCollectionProgress {
        guard let data = UserDefaults.standard.data(forKey: "statusMessageProgress"),
              let progress = try? JSONDecoder().decode(MessageCollectionProgress.self, from: data) else {
            return MessageCollectionProgress()
        }
        return progress
    }

    // MARK: - Statistics

    var totalMessages: Int { allMessages.count }

    func seenCount(for rarity: StatusMessage.Rarity) -> Int {
        collectionProgress.seenCount(for: rarity, in: allMessages)
    }

    func totalCount(for rarity: StatusMessage.Rarity) -> Int {
        collectionProgress.totalCount(for: rarity, in: allMessages)
    }

    func percentage(for rarity: StatusMessage.Rarity) -> Double {
        collectionProgress.percentage(for: rarity, in: allMessages)
    }
}

// MARK: - Message Pool Builder

extension StatusMessageStore {
    private static func buildMessagePool() -> [StatusMessage] {
        var messages: [StatusMessage] = []

        // MARK: Thinking Messages
        messages.append(contentsOf: [
            .simple("Thinking...", emoji: "💭", category: .thinking),
            .simple("Processing...", emoji: "🧠", category: .thinking),
            .simple("Pondering...", emoji: "🤔", category: .thinking),
            .simple("Having ideas...", emoji: "💡", category: .thinking),
            .simple("Focusing...", emoji: "🎯", category: .thinking),
            .simple("Analyzing...", emoji: "🔍", category: .thinking),

            .uncommon("Consulting the oracle...", emoji: "🔮", category: .thinking),
            .uncommon("Channeling wisdom...", emoji: "✨", category: .thinking),
            .uncommon("Brewing thoughts...", emoji: "☕", category: .thinking),
            .uncommon("Neurons firing...", emoji: "⚡", category: .thinking),
            .uncommon("Pushing up glasses...", emoji: "🤓", category: .thinking),
            .uncommon("Getting creative...", emoji: "🎨", category: .thinking),
            .uncommon("Piecing it together...", emoji: "🧩", category: .thinking),
            .uncommon("In the zone...", emoji: "🌀", category: .thinking),

            .rare("You shall not pass... yet...", emoji: "🧙", category: .thinking),      // LOTR
            .rare("Winter is coming... for this bug...", emoji: "⚔️", category: .thinking), // GoT
            .rare("Accio solution...", emoji: "🪄", category: .thinking),                   // HP
            .rare("These aren't the bugs you're looking for...", emoji: "🌌", category: .thinking), // SW
            .rare("Taking the red pill...", emoji: "💊", category: .thinking),              // Matrix
            .rare("We need to go deeper...", emoji: "🌀", category: .thinking),             // Inception
            .rare("My spidey sense is tingling...", emoji: "🕷️", category: .thinking),     // Spider-Man

            .legendary("Great Scott! I've got it!", emoji: "⚡", category: .thinking),     // BttF
            .legendary("I am one with the code...", emoji: "🎯", category: .thinking),     // R1
        ])

        // MARK: Executing Messages
        messages.append(contentsOf: [
            .simple("Preparing...", emoji: "⏳", category: .executing),
            .simple("Warming up engines...", emoji: "🚀", category: .executing),
            .simple("Getting ready...", emoji: "🔧", category: .executing),
            .simple("Initializing...", emoji: "⚙️", category: .executing),
            .simple("On it...", emoji: "🏃", category: .executing),

            .uncommon("Setting the stage...", emoji: "🎬", category: .executing),
            .uncommon("Tuning up...", emoji: "🎸", category: .executing),
            .uncommon("One sec, coffee break...", emoji: "☕", category: .executing),
            .uncommon("Stretching first...", emoji: "🤸", category: .executing),

            .rare("Roads? Where we're going...", emoji: "🚗", category: .executing),       // BttF
            .rare("And my axe!", emoji: "⚔️", category: .executing),                        // LOTR
            .rare("Hold onto your butts...", emoji: "🦖", category: .executing),           // JP
            .rare("Never tell me the odds...", emoji: "🎰", category: .executing),         // SW

            .legendary("Alright alright alright...", emoji: "🎬", category: .executing),   // McConaughey
        ])

        // MARK: Bash Messages
        messages.append(contentsOf: [
            .simple("Running command...", emoji: "💻", category: .bash),
            .simple("Executing...", emoji: "🖥️", category: .bash),
            .simple("Terminal time...", emoji: "⚡", category: .bash),

            .uncommon("sudo make it happen...", emoji: "🎮", category: .bash),
            .uncommon("Hacking the mainframe...", emoji: "👨‍💻", category: .bash),
            .uncommon("I'm in...", emoji: "🕶️", category: .bash),
            .uncommon("Shell yeah...", emoji: "🐚", category: .bash),
            .uncommon("Fingers crossed...", emoji: "🤞", category: .bash),

            .rare("I know kung fu...", emoji: "🕶️", category: .bash),                      // Matrix
            .rare("It's a Unix system, I know this!", emoji: "💻", category: .bash),      // JP
            .rare("Open the pod bay doors...", emoji: "🔴", category: .bash),             // 2001
            .rare("I'll be back... with results...", emoji: "🤖", category: .bash),       // T2
            .rare("Execute Order 66...", emoji: "🎯", category: .bash),                    // SW

            .legendary("PC LOAD LETTER?!", emoji: "📺", category: .bash),                  // Office Space
        ])

        // MARK: Read Messages
        messages.append(contentsOf: [
            .simple("Reading...", emoji: "📖", category: .read),
            .simple("Taking a look...", emoji: "👀", category: .read),
            .simple("Exploring...", emoji: "📂", category: .read),

            .uncommon("Studying the archives...", emoji: "🤓", category: .read),
            .uncommon("Hitting the books...", emoji: "📚", category: .read),
            .uncommon("Peeking...", emoji: "👁️", category: .read),
            .uncommon("Snooping around...", emoji: "🕵️", category: .read),

            .rare("The sacred texts!", emoji: "📜", category: .read),                      // SW
            .rare("X marks the spot...", emoji: "🗺️", category: .read),                   // Indiana Jones
            .rare("Enhance... enhance... enhance...", emoji: "👀", category: .read),      // Every cop show
            .rare("Elementary, my dear Watson...", emoji: "🔍", category: .read),         // Sherlock
        ])

        // MARK: Edit Messages
        messages.append(contentsOf: [
            .simple("Editing...", emoji: "✏️", category: .edit),
            .simple("Writing...", emoji: "📝", category: .edit),
            .simple("Making changes...", emoji: "🔧", category: .edit),

            .uncommon("Painting with code...", emoji: "🎨", category: .edit),
            .uncommon("Polishing...", emoji: "💅", category: .edit),
            .uncommon("Sprinkling magic...", emoji: "✨", category: .edit),
            .uncommon("Surgical precision...", emoji: "🔪", category: .edit),
            .uncommon("Abracadabra...", emoji: "🪄", category: .edit),

            .rare("I am altering the code. Pray I don't alter it further...", emoji: "⚔️", category: .edit), // SW
            .rare("It's alive! IT'S ALIVE!", emoji: "⚡", category: .edit),                // Frankenstein
            .rare("We can rebuild it. Better. Stronger...", emoji: "🔧", category: .edit), // Six Million

            .legendary("I am inevitable (these changes)...", emoji: "🎯", category: .edit), // Thanos
        ])

        // MARK: Search Messages
        messages.append(contentsOf: [
            .simple("Searching...", emoji: "🔎", category: .search),
            .simple("Looking...", emoji: "🔍", category: .search),
            .simple("Exploring...", emoji: "🗺️", category: .search),

            .uncommon("Investigating...", emoji: "🕵️", category: .search),
            .uncommon("On the trail...", emoji: "🔦", category: .search),
            .uncommon("Treasure hunting...", emoji: "🏴‍☠️", category: .search),
            .uncommon("Pattern matching...", emoji: "📊", category: .search),

            .rare("My precious... where is it...", emoji: "💍", category: .search),       // LOTR
            .rare("The name's Grep. James Grep...", emoji: "🕵️", category: .search),     // Bond
            .rare("There is no try, only find...", emoji: "🎯", category: .search),       // SW

            .legendary("Just keep searching, just keep searching...", emoji: "🌊", category: .search), // Nemo
        ])

        // MARK: Web Messages
        messages.append(contentsOf: [
            .simple("Fetching...", emoji: "🌐", category: .web),
            .simple("Reaching out...", emoji: "📡", category: .web),
            .simple("Surfing the web...", emoji: "🕸️", category: .web),

            .uncommon("Riding the waves...", emoji: "🏄", category: .web),
            .uncommon("Calling the internet...", emoji: "📞", category: .web),
            .uncommon("Down the rabbit hole...", emoji: "🕳️", category: .web),
            .uncommon("Hope it's not a 404...", emoji: "🤞", category: .web),

            .rare("Follow the white rabbit...", emoji: "🐇", category: .web),              // Matrix
            .rare("E.T. phone home...", emoji: "📡", category: .web),                       // E.T.
            .rare("Beam me up, Scotty...", emoji: "🚀", category: .web),                    // Trek
            .rare("You've got mail!", emoji: "💌", category: .web),                         // AOL

            .legendary("Shall we play a game?", emoji: "🎰", category: .web),              // WarGames
        ])

        // MARK: Agent Messages
        messages.append(contentsOf: [
            .simple("Agent working...", emoji: "🤖", category: .agent),
            .simple("Delegating...", emoji: "👥", category: .agent),
            .simple("Processing...", emoji: "🔄", category: .agent),

            .uncommon("Agent deployed...", emoji: "🕵️", category: .agent),
            .uncommon("Mission in progress...", emoji: "🎯", category: .agent),
            .uncommon("Calling in backup...", emoji: "👷", category: .agent),
            .uncommon("Player 2 has entered...", emoji: "🎮", category: .agent),

            .rare("Avengers, assemble!", emoji: "🦸", category: .agent),                   // Avengers
            .rare("Autobots, roll out!", emoji: "🤖", category: .agent),                  // Transformers
            .rare("I volunteer as tribute!", emoji: "🎯", category: .agent),              // HG
            .rare("For Frodo!", emoji: "⚔️", category: .agent),                            // LOTR

            .legendary("Send in the clones!", emoji: "🎪", category: .agent),             // SW
        ])

        // MARK: Idle Messages
        messages.append(contentsOf: [
            .simple("Ready for input...", emoji: "", category: .idle),
            .simple("What's next?", emoji: "", category: .idle),
            .simple("Standing by...", emoji: "", category: .idle),
            .simple("At your service...", emoji: "", category: .idle),

            .uncommon("Let's build something...", emoji: "", category: .idle),
            .uncommon("What shall we create?", emoji: "", category: .idle),
            .uncommon("On a roll! Keep going...", emoji: "", category: .idle),
            .uncommon("Your move...", emoji: "", category: .idle),

            .rare("I'm ready, I'm ready!", emoji: "", category: .idle),                    // SpongeBob
            .rare("Talk to me, Goose...", emoji: "", category: .idle),                     // Top Gun
            .rare("As you wish...", emoji: "", category: .idle),                           // PB
            .rare("Make it so...", emoji: "", category: .idle),                            // TNG

            .legendary("Witness me!", emoji: "", category: .idle),                         // Mad Max
        ])

        // MARK: Time-of-Day Messages

        // Morning
        messages.append(contentsOf: [
            .timed("Good morning! Let's code...", emoji: "☀️", category: .thinking, time: .morning),
            .timed("Coffee and code...", emoji: "☕", category: .thinking, time: .morning),
            .timed("Early bird gets the merge...", emoji: "🌅", category: .thinking, time: .morning, rarity: .rare),
        ])

        // Night
        messages.append(contentsOf: [
            .timed("Burning the midnight oil...", emoji: "🌙", category: .thinking, time: .night),
            .timed("Night owl mode...", emoji: "🦉", category: .thinking, time: .night),
            .timed("3am thoughts hit different...", emoji: "🌌", category: .thinking, time: .night, rarity: .legendary),
        ])

        // Weekend
        messages.append(contentsOf: [
            .timed("Weekend warrior...", emoji: "🎮", category: .thinking, time: .weekend),
            .timed("Side project time?", emoji: "🏠", category: .thinking, time: .weekend),
            .timed("No meetings today...", emoji: "😎", category: .thinking, time: .weekend, rarity: .rare),
        ])

        // MARK: Seasonal Messages

        // Halloween
        messages.append(contentsOf: [
            .seasonal("Spooky season coding...", emoji: "🎃", category: .thinking, season: .halloween),
            .seasonal("Boo! Ready to haunt bugs...", emoji: "👻", category: .thinking, season: .halloween),
            .seasonal("Something wicked this way compiles...", emoji: "🦇", category: .thinking, season: .halloween, rarity: .rare),
            .seasonal("Skeleton code? Refactor it...", emoji: "💀", category: .thinking, season: .halloween, rarity: .legendary),
        ])

        // Christmas
        messages.append(contentsOf: [
            .seasonal("Ho ho ho, let's go...", emoji: "🎄", category: .thinking, season: .christmas),
            .seasonal("Making a list, checking it twice...", emoji: "🎅", category: .thinking, season: .christmas),
            .seasonal("Let it snow, let it flow...", emoji: "❄️", category: .thinking, season: .christmas, rarity: .rare),
            .seasonal("Dashing through the code...", emoji: "🦌", category: .thinking, season: .christmas, rarity: .legendary),
        ])

        // New Year
        messages.append(contentsOf: [
            .seasonal("New year, new codebase...", emoji: "🎆", category: .thinking, season: .newYear),
            .seasonal("Cheers to no bugs...", emoji: "🥂", category: .thinking, season: .newYear),
            .seasonal("Resolution: write tests...", emoji: "✨", category: .thinking, season: .newYear, rarity: .rare),
        ])

        // Valentine
        messages.append(contentsOf: [
            .seasonal("Code is my valentine...", emoji: "💕", category: .thinking, season: .valentine),
            .seasonal("Roses are red, builds are green...", emoji: "🌹", category: .thinking, season: .valentine, rarity: .legendary),
        ])

        return messages
    }
}
