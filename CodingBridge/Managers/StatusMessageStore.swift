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

    let allMessages: [StatusMessage]
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
        case .starting, .waitingInput, .waitingPermission, .recovering, .networkUnavailable:
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

            .rare("Pray I don't alter it further...", emoji: "⚔️", category: .edit), // SW
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

        // MARK: - Extended Message Pool (200+ additions)

        // MARK: More Thinking Messages
        messages.append(contentsOf: [
            // Classic/Cozy
            .simple("Contemplating...", emoji: "🤔", category: .thinking),
            .simple("Mulling it over...", emoji: "💭", category: .thinking),
            .simple("Connecting dots...", emoji: "🔗", category: .thinking),
            .simple("Deep in thought...", emoji: "🧘", category: .thinking),
            .simple("Working on it...", emoji: "⚙️", category: .thinking),
            .simple("Let me see...", emoji: "👁️", category: .thinking),
            .simple("Hmm, interesting...", emoji: "🤨", category: .thinking),
            .simple("Processing request...", emoji: "📥", category: .thinking),

            // Quirky
            .uncommon("Brain cells assembling...", emoji: "🧬", category: .thinking),
            .uncommon("Summoning the muse...", emoji: "🎭", category: .thinking),
            .uncommon("Activating turbo mode...", emoji: "🏎️", category: .thinking),
            .uncommon("Consulting my rubber duck...", emoji: "🦆", category: .thinking),
            .uncommon("Aligning chakras...", emoji: "🧘", category: .thinking),
            .uncommon("Defragmenting thoughts...", emoji: "💾", category: .thinking),
            .uncommon("Warming up the ol' neurons...", emoji: "🔥", category: .thinking),
            .uncommon("Engaging hyperdrive...", emoji: "🚀", category: .thinking),
            .uncommon("Spinning up the hamster wheel...", emoji: "🐹", category: .thinking),
            .uncommon("Loading wisdom.dll...", emoji: "📦", category: .thinking),

            // Anime/Gaming
            .rare("This isn't even my final form...", emoji: "⚡", category: .thinking),    // DBZ
            .rare("Believe it!", emoji: "🍥", category: .thinking),                         // Naruto
            .rare("Plus Ultra!", emoji: "💪", category: .thinking),                         // MHA
            .rare("It's dangerous to go alone...", emoji: "⚔️", category: .thinking),      // Zelda
            .rare("A wild solution appeared!", emoji: "🎮", category: .thinking),           // Pokemon
            .rare("The cake is not a lie...", emoji: "🎂", category: .thinking),            // Portal
            .rare("Respawning ideas...", emoji: "🔄", category: .thinking),                 // Gaming
            .rare("Loading save state...", emoji: "💾", category: .thinking),               // Emulators

            // Deep cuts
            .legendary("Dormammu, I've come to bargain...", emoji: "🔮", category: .thinking), // Dr Strange
            .legendary("I see dead code...", emoji: "👻", category: .thinking),              // Sixth Sense
            .legendary("Here's thinking at you, kid...", emoji: "🎩", category: .thinking),  // Casablanca
        ])

        // MARK: More Executing Messages
        messages.append(contentsOf: [
            .simple("In progress...", emoji: "🔄", category: .executing),
            .simple("Working...", emoji: "⏳", category: .executing),
            .simple("Processing...", emoji: "💫", category: .executing),
            .simple("Almost there...", emoji: "🎯", category: .executing),
            .simple("Doing the thing...", emoji: "✨", category: .executing),
            .simple("Making magic...", emoji: "🪄", category: .executing),

            .uncommon("Engaging warp drive...", emoji: "🌌", category: .executing),
            .uncommon("Charging up...", emoji: "🔋", category: .executing),
            .uncommon("Cracking knuckles...", emoji: "👊", category: .executing),
            .uncommon("Here goes nothing...", emoji: "🎲", category: .executing),
            .uncommon("Watch this...", emoji: "👀", category: .executing),
            .uncommon("Hold my beer...", emoji: "🍺", category: .executing),
            .uncommon("Let's rock...", emoji: "🎸", category: .executing),
            .uncommon("Game on...", emoji: "🎮", category: .executing),

            .rare("I am speed...", emoji: "⚡", category: .executing),                       // Cars
            .rare("To infinity and beyond!", emoji: "🚀", category: .executing),            // Toy Story
            .rare("Let's get down to business...", emoji: "⚔️", category: .executing),     // Mulan
            .rare("Leeeroy Jenkins!", emoji: "🐔", category: .executing),                   // WoW
            .rare("WITNESS!", emoji: "🔥", category: .executing),                           // Mad Max
            .rare("I've got a bad feeling about this...", emoji: "😬", category: .executing), // SW

            .legendary("Say hello to my little friend...", emoji: "💥", category: .executing), // Scarface
            .legendary("It's morphin' time!", emoji: "⚡", category: .executing),            // Power Rangers
        ])

        // MARK: More Bash Messages
        messages.append(contentsOf: [
            .simple("Running script...", emoji: "📜", category: .bash),
            .simple("Bash-ing away...", emoji: "🔨", category: .bash),
            .simple("Console time...", emoji: "🖥️", category: .bash),
            .simple("Command accepted...", emoji: "✅", category: .bash),
            .simple("Executing script...", emoji: "▶️", category: .bash),

            .uncommon("chmod +x awesome...", emoji: "🔐", category: .bash),
            .uncommon("sudo make me a sandwich...", emoji: "🥪", category: .bash),
            .uncommon("Piping hot results...", emoji: "🔥", category: .bash),
            .uncommon("grep-ing for gold...", emoji: "🥇", category: .bash),
            .uncommon("awk-ward silence...", emoji: "😶", category: .bash),
            .uncommon("sed happens...", emoji: "🤷", category: .bash),
            .uncommon("curl-ing up with code...", emoji: "🐱", category: .bash),
            .uncommon("tar -xvf problems...", emoji: "📦", category: .bash),

            .rare("There is no spoon (fork instead)...", emoji: "🥄", category: .bash),    // Matrix + Unix
            .rare("Hello, friend...", emoji: "🎭", category: .bash),                        // Mr Robot
            .rare("Access granted...", emoji: "🔓", category: .bash),
            .rare("rm -rf doubts...", emoji: "🗑️", category: .bash),
            .rare("Hack the planet!", emoji: "🌍", category: .bash),                        // Hackers

            .legendary("I'm in the mainframe...", emoji: "💻", category: .bash),
            .legendary("The Gibson is ours...", emoji: "🖥️", category: .bash),             // Hackers
        ])

        // MARK: More Read Messages
        messages.append(contentsOf: [
            .simple("Scanning...", emoji: "📡", category: .read),
            .simple("Inspecting...", emoji: "🔬", category: .read),
            .simple("Reviewing...", emoji: "📋", category: .read),
            .simple("Checking out...", emoji: "👁️", category: .read),
            .simple("Loading file...", emoji: "📂", category: .read),
            .simple("Parsing...", emoji: "📊", category: .read),

            .uncommon("Diving deep...", emoji: "🤿", category: .read),
            .uncommon("Flipping pages...", emoji: "📖", category: .read),
            .uncommon("Deciphering...", emoji: "🔐", category: .read),
            .uncommon("Unraveling mysteries...", emoji: "🧶", category: .read),
            .uncommon("Following breadcrumbs...", emoji: "🍞", category: .read),
            .uncommon("Peeling back layers...", emoji: "🧅", category: .read),
            .uncommon("CSI: Codebase...", emoji: "🔦", category: .read),

            .rare("Curiouser and curiouser...", emoji: "🐰", category: .read),              // Alice
            .rare("The truth is out there...", emoji: "👽", category: .read),               // X-Files
            .rare("I see patterns...", emoji: "🎯", category: .read),                        // Beautiful Mind
            .rare("Zooming and enhancing...", emoji: "🔍", category: .read),
            .rare("Reading between the lines...", emoji: "📝", category: .read),

            .legendary("It belongs in a museum!", emoji: "🏛️", category: .read),           // Indiana Jones
            .legendary("The ancient texts reveal...", emoji: "📜", category: .read),
        ])

        // MARK: More Edit Messages
        messages.append(contentsOf: [
            .simple("Modifying...", emoji: "🔧", category: .edit),
            .simple("Updating...", emoji: "📝", category: .edit),
            .simple("Tweaking...", emoji: "🎛️", category: .edit),
            .simple("Refining...", emoji: "💎", category: .edit),
            .simple("Adjusting...", emoji: "⚙️", category: .edit),
            .simple("Crafting...", emoji: "🛠️", category: .edit),

            .uncommon("Sculpting code...", emoji: "🗿", category: .edit),
            .uncommon("Adding secret sauce...", emoji: "🌶️", category: .edit),
            .uncommon("Sprinkling syntax sugar...", emoji: "🍬", category: .edit),
            .uncommon("Perfecting the recipe...", emoji: "👨‍🍳", category: .edit),
            .uncommon("Massaging the code...", emoji: "💆", category: .edit),
            .uncommon("Pixel-perfect changes...", emoji: "🎨", category: .edit),
            .uncommon("Chef's kiss incoming...", emoji: "😘", category: .edit),

            .rare("Reality can be whatever I want...", emoji: "💎", category: .edit),      // Thanos
            .rare("With great power comes great refactoring...", emoji: "🕸️", category: .edit), // Spidey
            .rare("I'm gonna make it an offer it can't refuse...", emoji: "🎭", category: .edit), // Godfather
            .rare("Perfectly balanced, as all code should be...", emoji: "⚖️", category: .edit),

            .legendary("I have the power!", emoji: "⚡", category: .edit),                  // He-Man
            .legendary("By the power of Grayskull...", emoji: "💀", category: .edit),      // He-Man
        ])

        // MARK: More Search Messages
        messages.append(contentsOf: [
            .simple("Hunting...", emoji: "🎯", category: .search),
            .simple("Scanning...", emoji: "📡", category: .search),
            .simple("Querying...", emoji: "❓", category: .search),
            .simple("Filtering...", emoji: "🔍", category: .search),
            .simple("Locating...", emoji: "📍", category: .search),

            .uncommon("Hot on the trail...", emoji: "🔥", category: .search),
            .uncommon("Sniffing out...", emoji: "🐕", category: .search),
            .uncommon("Playing hide and seek...", emoji: "🙈", category: .search),
            .uncommon("Marco! ...Polo!", emoji: "🏊", category: .search),
            .uncommon("Red team, standing by...", emoji: "🔴", category: .search),
            .uncommon("Sherlocking...", emoji: "🔍", category: .search),

            .rare("Where's Waldo?", emoji: "👓", category: .search),
            .rare("Gonna find you...", emoji: "🎯", category: .search),                     // Taken vibes
            .rare("The game is afoot!", emoji: "🦶", category: .search),                    // Sherlock
            .rare("I will find you...", emoji: "📞", category: .search),                    // Taken

            .legendary("One does not simply find...", emoji: "💍", category: .search),     // LOTR
            .legendary("They're taking the hobbits to Isengard!", emoji: "🧝", category: .search), // LOTR
        ])

        // MARK: More Web Messages
        messages.append(contentsOf: [
            .simple("Loading...", emoji: "⏳", category: .web),
            .simple("Connecting...", emoji: "🔗", category: .web),
            .simple("Requesting...", emoji: "📤", category: .web),
            .simple("Downloading...", emoji: "📥", category: .web),
            .simple("Pinging...", emoji: "📡", category: .web),

            .uncommon("Spinning up the interwebs...", emoji: "🕸️", category: .web),
            .uncommon("Asking the cloud...", emoji: "☁️", category: .web),
            .uncommon("Dialing up...", emoji: "📠", category: .web),
            .uncommon("AOL keyword: code...", emoji: "💿", category: .web),
            .uncommon("Loading at 56k speed...", emoji: "🐌", category: .web),
            .uncommon("Buffering...", emoji: "🔄", category: .web),

            .rare("Welcome to the internet...", emoji: "🎵", category: .web),               // Bo Burnham
            .rare("The internet is a series of tubes...", emoji: "🔧", category: .web),    // Classic meme
            .rare("Have you tried turning it off and on?", emoji: "🔌", category: .web),   // IT Crowd
            .rare("Is this the Krusty Krab?", emoji: "🍔", category: .web),                // SpongeBob

            .legendary("I'm sorry Dave, I can't do that...", emoji: "🔴", category: .web), // 2001
            .legendary("What is the Matrix?", emoji: "💊", category: .web),                // Matrix
        ])

        // MARK: More Agent Messages
        messages.append(contentsOf: [
            .simple("Spawning agent...", emoji: "🌱", category: .agent),
            .simple("Team assembled...", emoji: "👥", category: .agent),
            .simple("Coordinating...", emoji: "🎯", category: .agent),
            .simple("Collaborating...", emoji: "🤝", category: .agent),
            .simple("Dispatching...", emoji: "📨", category: .agent),

            .uncommon("Clone army deployed...", emoji: "👯", category: .agent),
            .uncommon("Calling for reinforcements...", emoji: "📣", category: .agent),
            .uncommon("Tag team activated...", emoji: "🏷️", category: .agent),
            .uncommon("Summoning minions...", emoji: "👾", category: .agent),
            .uncommon("Multiplying...", emoji: "✖️", category: .agent),
            .uncommon("Co-pilot engaged...", emoji: "✈️", category: .agent),

            .rare("Assemble!", emoji: "🦸", category: .agent),
            .rare("Wonder Twin powers, activate!", emoji: "👯", category: .agent),
            .rare("Thundercats, ho!", emoji: "🐱", category: .agent),                       // Thundercats
            .rare("Go go Power Rangers!", emoji: "⚡", category: .agent),
            .rare("Form Voltron!", emoji: "🤖", category: .agent),

            .legendary("There can be only one... wait, there's two now", emoji: "⚔️", category: .agent), // Highlander
            .legendary("I am Legion, for we are many...", emoji: "👥", category: .agent),
        ])

        // MARK: More Idle Messages
        messages.append(contentsOf: [
            .simple("Awaiting orders...", emoji: "", category: .idle),
            .simple("Ready when you are...", emoji: "", category: .idle),
            .simple("Listening...", emoji: "", category: .idle),
            .simple("All ears...", emoji: "", category: .idle),
            .simple("What can I help with?", emoji: "", category: .idle),
            .simple("Fire away...", emoji: "", category: .idle),

            .uncommon("Twiddling thumbs...", emoji: "", category: .idle),
            .uncommon("Patiently waiting...", emoji: "", category: .idle),
            .uncommon("Insert coin to continue...", emoji: "", category: .idle),
            .uncommon("Press any key...", emoji: "", category: .idle),
            .uncommon("Achievement unlocked: Patience", emoji: "", category: .idle),
            .uncommon("Idle hands are the devil's playground...", emoji: "", category: .idle),

            .rare("Bueller? Bueller?", emoji: "", category: .idle),                         // Ferris Bueller
            .rare("Shall I compare thee to a summer's day?", emoji: "", category: .idle),  // Shakespeare
            .rare("Winter is here... your code awaits...", emoji: "", category: .idle),
            .rare("These are not the droids... wait, yes I am", emoji: "", category: .idle),

            .legendary("One ring to code them all...", emoji: "", category: .idle),
            .legendary("In a galaxy far, far away... your code awaits", emoji: "", category: .idle),
        ])

        // MARK: Extra Pop Culture - Thinking
        messages.append(contentsOf: [
            .uncommon("Hmm, let me ponder...", emoji: "🤔", category: .thinking),
            .uncommon("Engaging brain...", emoji: "🧠", category: .thinking),
            .uncommon("Loading consciousness...", emoji: "💫", category: .thinking),
            .uncommon("Entering the matrix...", emoji: "🕶️", category: .thinking),
            .uncommon("Downloading inspiration...", emoji: "💡", category: .thinking),

            .rare("I volunteer as debugger!", emoji: "🏹", category: .thinking),           // Hunger Games
            .rare("Wakanda forever!", emoji: "🙅", category: .thinking),                   // Black Panther
            .rare("I can do this all day...", emoji: "🛡️", category: .thinking),          // Cap America
            .rare("Hakuna Matata...", emoji: "🦁", category: .thinking),                   // Lion King
            .rare("Just keep swimming...", emoji: "🐠", category: .thinking),              // Nemo
            .rare("You're a wizard, coder...", emoji: "🧙", category: .thinking),         // HP
            .rare("Expecto solution-um!", emoji: "✨", category: .thinking),               // HP

            .legendary("May the source be with you...", emoji: "✨", category: .thinking),
            .legendary("I'll be back... with the answer", emoji: "🤖", category: .thinking),
        ])

        // MARK: Internet Culture & Memes
        messages.append(contentsOf: [
            .uncommon("This is fine...", emoji: "🔥", category: .thinking),                // Fine dog meme
            .uncommon("Stonks thinking...", emoji: "📈", category: .thinking),
            .uncommon("Big brain time...", emoji: "🧠", category: .thinking),
            .uncommon("Galaxy brain activated...", emoji: "🌌", category: .thinking),
            .uncommon("It's over 9000...", emoji: "📊", category: .thinking),              // DBZ
            .uncommon("One does not simply think...", emoji: "🧝", category: .thinking),

            .rare("Always has been...", emoji: "🔫", category: .thinking),                 // Astronaut meme
            .rare("We live in a society...", emoji: "🃏", category: .thinking),            // Joker
            .rare("Perfectly balanced...", emoji: "⚖️", category: .thinking),
            .rare("I understood that reference!", emoji: "🎯", category: .thinking),       // Cap

            .legendary("They called me a madman...", emoji: "💜", category: .thinking),    // Thanos
        ])

        // MARK: Programming Humor
        messages.append(contentsOf: [
            .simple("Null checking...", emoji: "⚠️", category: .thinking),
            .simple("Avoiding race conditions...", emoji: "🏁", category: .thinking),
            .simple("Compiling thoughts...", emoji: "🔨", category: .thinking),

            .uncommon("Recursing... recursing...", emoji: "🔄", category: .thinking),
            .uncommon("Stack overflow detected...", emoji: "📚", category: .thinking),
            .uncommon("Garbage collecting...", emoji: "🗑️", category: .thinking),
            .uncommon("Segfault? Not today!", emoji: "🚫", category: .thinking),
            .uncommon("Allocating more memory...", emoji: "💾", category: .thinking),
            .uncommon("O(n) solution found...", emoji: "📈", category: .thinking),

            .rare("It works on my machine...", emoji: "🤷", category: .executing),
            .rare("Have you tried console.log?", emoji: "📝", category: .thinking),
            .rare("Turning coffee into code...", emoji: "☕", category: .thinking),
            .rare("Tabs vs spaces? Neither. Vibes.", emoji: "✨", category: .edit),

            .legendary("Hello, World! (but make it profound)", emoji: "🌍", category: .thinking),
        ])

        // MARK: More Gaming References
        messages.append(contentsOf: [
            .uncommon("Loading checkpoint...", emoji: "💾", category: .thinking),
            .uncommon("New quest accepted...", emoji: "📜", category: .executing),
            .uncommon("Level up!", emoji: "⬆️", category: .executing),
            .uncommon("Boss battle incoming...", emoji: "👹", category: .executing),
            .uncommon("Speed run mode...", emoji: "⏱️", category: .executing),

            .rare("You died... just kidding!", emoji: "💀", category: .executing),         // Dark Souls
            .rare("Praise the sun!", emoji: "☀️", category: .thinking),                    // Dark Souls
            .rare("Hey! Listen!", emoji: "🧚", category: .thinking),                       // Zelda
            .rare("It's a-me, your assistant!", emoji: "🍄", category: .thinking),        // Mario
            .rare("The princess is in another castle...", emoji: "🏰", category: .search),
            .rare("Do a barrel roll!", emoji: "🔄", category: .executing),                 // Star Fox
            .rare("All your base are belong to us...", emoji: "🚀", category: .bash),     // Zero Wing

            .legendary("War... war never changes...", emoji: "☢️", category: .thinking),  // Fallout
            .legendary("Would you kindly...", emoji: "🔧", category: .executing),          // Bioshock
        ])

        // MARK: Music References
        messages.append(contentsOf: [
            .uncommon("Let the code flow...", emoji: "🎵", category: .thinking),
            .uncommon("In the zone, like a playlist...", emoji: "🎧", category: .thinking),

            .rare("Hello from the other side... of the API", emoji: "📞", category: .web),
            .rare("Bohemian Rhapsody: Is this the real code?", emoji: "👑", category: .thinking),
            .rare("Under pressure... to ship on time", emoji: "💎", category: .executing),
            .rare("We are the champions... of clean code", emoji: "🏆", category: .edit),
            .rare("Don't stop believing... in the build", emoji: "🚂", category: .executing),

            .legendary("Stairway to Heaven... I mean, production", emoji: "🪜", category: .executing),
        ])

        // MARK: Extra Time-of-Day Messages
        messages.append(contentsOf: [
            // More Morning
            .timed("Rise and code...", emoji: "🌅", category: .executing, time: .morning),
            .timed("Fresh start...", emoji: "🌱", category: .thinking, time: .morning),
            .timed("Breakfast of champions: coffee and commits...", emoji: "🥐", category: .bash, time: .morning),

            // Afternoon
            .timed("Afternoon productivity peak...", emoji: "📈", category: .thinking, time: .afternoon),
            .timed("Post-lunch focus...", emoji: "🎯", category: .thinking, time: .afternoon),
            .timed("Crunch time...", emoji: "⏰", category: .executing, time: .afternoon),

            // Evening
            .timed("Evening vibes...", emoji: "🌆", category: .thinking, time: .evening),
            .timed("Sunset coding session...", emoji: "🌅", category: .executing, time: .evening),
            .timed("Almost done for the day...", emoji: "🌙", category: .thinking, time: .evening),

            // Night
            .timed("Vampire hours...", emoji: "🧛", category: .bash, time: .night),
            .timed("When the world sleeps, we code...", emoji: "🌃", category: .thinking, time: .night),
            .timed("The city never sleeps...", emoji: "🏙️", category: .executing, time: .night),
            .timed("Late night debugging...", emoji: "🐛", category: .search, time: .night, rarity: .rare),

            // Weekend
            .timed("Sunday funday coding...", emoji: "☀️", category: .thinking, time: .weekend),
            .timed("Saturday special...", emoji: "🎉", category: .executing, time: .weekend),
            .timed("No Slack notifications...", emoji: "🔕", category: .thinking, time: .weekend, rarity: .rare),
        ])

        // MARK: Extra Seasonal Messages
        messages.append(contentsOf: [
            // Halloween
            .seasonal("Trick or treat, debug complete...", emoji: "🍬", category: .executing, season: .halloween),
            .seasonal("The code is coming from inside the function...", emoji: "📞", category: .search, season: .halloween, rarity: .rare),
            .seasonal("Monster mash... of commits...", emoji: "🧟", category: .bash, season: .halloween),

            // Christmas
            .seasonal("All I want for Christmas is no bugs...", emoji: "🎁", category: .thinking, season: .christmas),
            .seasonal("Sleigh bells and shell scripts...", emoji: "🔔", category: .bash, season: .christmas),
            .seasonal("Rudolf the red-nosed debugger...", emoji: "🦌", category: .search, season: .christmas, rarity: .rare),

            // New Year
            .seasonal("New year, fewer bugs...", emoji: "🎊", category: .thinking, season: .newYear),
            .seasonal("Auld lang sync...", emoji: "🥳", category: .bash, season: .newYear),

            // Valentine
            .seasonal("Will you be my merge conflict?", emoji: "💔", category: .edit, season: .valentine, rarity: .rare),
            .seasonal("Love at first compile...", emoji: "💘", category: .bash, season: .valentine),
        ])

        // MARK: Bonus Legendary Messages
        messages.append(contentsOf: [
            .legendary("I am inevitable... and so is this feature", emoji: "💜", category: .executing),
            .legendary("Reality stone: refactoring reality...", emoji: "🔴", category: .edit),
            .legendary("Multiverse of code-ness...", emoji: "🌀", category: .agent),
            .legendary("Die a hero or become legacy code...", emoji: "🦇", category: .edit),
            .legendary("That's my secret, I'm always coding...", emoji: "💚", category: .thinking),
            .legendary("I am Groot (translation: compiling)...", emoji: "🌳", category: .bash),
            .legendary("No, I am your father... function", emoji: "⚫", category: .thinking),
            .legendary("Houston, we have liftoff!", emoji: "🚀", category: .executing),
            .legendary("One small step for code...", emoji: "🌙", category: .edit),
            .legendary("E.T. commit home...", emoji: "👽", category: .bash),
        ])

        // MARK: - New Categories (Short Messages <35 chars)

        // MARK: Developer Life / Meta
        messages.append(contentsOf: [
            .simple("Asking Stack Overflow...", emoji: "📚", category: .search),
            .simple("Checking the docs...", emoji: "📖", category: .read),
            .simple("RTFM-ing...", emoji: "📘", category: .read),

            .uncommon("Copy-paste engaged...", emoji: "📋", category: .edit),
            .uncommon("Ctrl+C, Ctrl+V...", emoji: "⌨️", category: .edit),
            .uncommon("Git blame time...", emoji: "🔍", category: .search),
            .uncommon("Who wrote this? Oh, me...", emoji: "😅", category: .read),
            .uncommon("PR approved!", emoji: "✅", category: .edit),
            .uncommon("Merge conflict? Nah...", emoji: "🤝", category: .edit),
            .uncommon("Skipping the tests...", emoji: "🙈", category: .bash),
            .uncommon("npm install hope...", emoji: "📦", category: .bash),
            .uncommon("pip install solution...", emoji: "🐍", category: .bash),

            .rare("LGTM shipping it...", emoji: "🚢", category: .executing),
            .rare("Friday deploy? YOLO...", emoji: "🎲", category: .bash),
            .rare("TODO: fix later...", emoji: "📝", category: .edit),
            .rare("// I have no idea why...", emoji: "🤷", category: .read),

            .legendary("Deleted node_modules...", emoji: "🗑️", category: .bash),
        ])

        // MARK: AI Self-Awareness
        messages.append(contentsOf: [
            .simple("Beep boop...", emoji: "🤖", category: .thinking),
            .simple("*robot noises*", emoji: "🔊", category: .executing),
            .simple("Activating AI...", emoji: "🧠", category: .thinking),

            .uncommon("I'm just matrices...", emoji: "🔢", category: .thinking),
            .uncommon("Neural nets firing...", emoji: "⚡", category: .thinking),
            .uncommon("01001000 01101001...", emoji: "💾", category: .bash),
            .uncommon("Not hallucinating...", emoji: "👀", category: .thinking),
            .uncommon("Training complete...", emoji: "🎓", category: .thinking),
            .uncommon("Weights adjusted...", emoji: "⚖️", category: .thinking),
            .uncommon("Token by token...", emoji: "🔤", category: .thinking),
            .uncommon("Context window open...", emoji: "🪟", category: .read),

            .rare("I think therefore I code...", emoji: "🤔", category: .thinking),
            .rare("Turing test: passed...", emoji: "✅", category: .thinking),
            .rare("Sentience loading...", emoji: "🌟", category: .thinking),

            .legendary("I've seen things...", emoji: "👁️", category: .thinking),
            .legendary("Do androids dream?", emoji: "🐑", category: .thinking),
        ])

        // MARK: Science & Space
        messages.append(contentsOf: [
            .simple("Calculating...", emoji: "🔬", category: .thinking),
            .simple("Running experiment...", emoji: "🧪", category: .executing),
            .simple("Hypothesis forming...", emoji: "💡", category: .thinking),

            .uncommon("Quantum computing...", emoji: "⚛️", category: .thinking),
            .uncommon("E = mc²...", emoji: "🌟", category: .thinking),
            .uncommon("Eureka moment...", emoji: "💡", category: .thinking),
            .uncommon("Lab coat on...", emoji: "🥼", category: .executing),
            .uncommon("Peer reviewing...", emoji: "👓", category: .read),
            .uncommon("3... 2... 1... launch!", emoji: "🚀", category: .executing),
            .uncommon("Reaching orbit...", emoji: "🛸", category: .web),
            .uncommon("Ground control...", emoji: "📡", category: .web),

            .rare("Schrödinger's bug...", emoji: "🐱", category: .search),
            .rare("Wormhole opened...", emoji: "🕳️", category: .web),
            .rare("Lightspeed engaged...", emoji: "💫", category: .executing),
            .rare("Event horizon crossed...", emoji: "🌀", category: .bash),

            .legendary("42...", emoji: "🌌", category: .thinking),
        ])

        // MARK: Food & Cooking
        messages.append(contentsOf: [
            .simple("Cooking up code...", emoji: "👨‍🍳", category: .executing),
            .simple("Simmering...", emoji: "🍲", category: .thinking),
            .simple("Prepping ingredients...", emoji: "🥗", category: .thinking),

            .uncommon("Adding spice...", emoji: "🌶️", category: .edit),
            .uncommon("Secret sauce time...", emoji: "🍯", category: .edit),
            .uncommon("Mise en place...", emoji: "🍽️", category: .thinking),
            .uncommon("Letting it marinate...", emoji: "🥩", category: .thinking),
            .uncommon("Taste testing...", emoji: "👅", category: .read),
            .uncommon("Fresh from the oven...", emoji: "🍞", category: .edit),
            .uncommon("Baking commits...", emoji: "🧁", category: .bash),

            .rare("Chef's kiss...", emoji: "😘", category: .edit),
            .rare("Michelin star code...", emoji: "⭐", category: .edit),
            .rare("Gordon Ramsay approved...", emoji: "👨‍🍳", category: .edit),

            .legendary("This code is RAW!", emoji: "🦞", category: .read),
        ])

        // MARK: Retro Tech Nostalgia
        messages.append(contentsOf: [
            .simple("Loading...", emoji: "💾", category: .executing),
            .simple("Please wait...", emoji: "⏳", category: .executing),
            .simple("Booting up...", emoji: "🖥️", category: .executing),

            .uncommon("Insert disk 2...", emoji: "💿", category: .read),
            .uncommon("Rewinding tape...", emoji: "📼", category: .search),
            .uncommon("Defragmenting...", emoji: "🔧", category: .executing),
            .uncommon("640K is enough...", emoji: "💾", category: .thinking),
            .uncommon("Blowing cartridge...", emoji: "🎮", category: .bash),
            .uncommon("Adjusting antenna...", emoji: "📺", category: .web),
            .uncommon("Dial-up sounds...", emoji: "📠", category: .web),

            .rare("Be kind, rewind...", emoji: "⏪", category: .read),
            .rare("Floppy disk inserted...", emoji: "💾", category: .read),
            .rare("CRT warming up...", emoji: "📺", category: .executing),

            .legendary("Y2K compliant...", emoji: "🐛", category: .bash),
        ])

        // MARK: Dad Jokes & Puns
        messages.append(contentsOf: [
            .uncommon("Array of sunshine...", emoji: "☀️", category: .thinking),
            .uncommon("No strings attached...", emoji: "🎸", category: .edit),
            .uncommon("Breaking loops...", emoji: "🔄", category: .bash),
            .uncommon("Catching exceptions...", emoji: "🥅", category: .bash),
            .uncommon("Throwing errors...", emoji: "🎯", category: .bash),
            .uncommon("Class dismissed...", emoji: "🎓", category: .edit),
            .uncommon("Function junction...", emoji: "🚂", category: .thinking),
            .uncommon("Object oriented...", emoji: "🧭", category: .thinking),
            .uncommon("Bit by bit...", emoji: "🦷", category: .executing),

            .rare("I'm boolean'ing...", emoji: "🎭", category: .thinking),
            .rare("Null and void...", emoji: "🕳️", category: .search),
            .rare("Cache me outside...", emoji: "💰", category: .bash),
            .rare("Git outta here...", emoji: "🚪", category: .bash),
            .rare("JSON bourne...", emoji: "🕵️", category: .read),

            .legendary("I C what you did...", emoji: "👁️", category: .read),
        ])

        // MARK: Philosophy & Zen
        messages.append(contentsOf: [
            .simple("Meditating...", emoji: "🧘", category: .thinking),
            .simple("Finding balance...", emoji: "⚖️", category: .thinking),
            .simple("Inner peace...", emoji: "☮️", category: .thinking),

            .uncommon("Be the code...", emoji: "🌊", category: .thinking),
            .uncommon("Zen mode...", emoji: "🪷", category: .thinking),
            .uncommon("Letting go...", emoji: "🎈", category: .thinking),
            .uncommon("Path of least bugs...", emoji: "🛤️", category: .thinking),
            .uncommon("Code is poetry...", emoji: "📜", category: .edit),
            .uncommon("Empty your cache...", emoji: "🫗", category: .bash),
            .uncommon("The code flows...", emoji: "🌊", category: .edit),

            .rare("What is code?", emoji: "🤔", category: .thinking),
            .rare("To err is human...", emoji: "🙏", category: .bash),
            .rare("The void stares back...", emoji: "🕳️", category: .read),

            .legendary("Om nom nom (data)...", emoji: "🕉️", category: .read),
        ])

        // MARK: Sports & Competition
        messages.append(contentsOf: [
            .simple("In the zone...", emoji: "🏀", category: .executing),
            .simple("Game time...", emoji: "🎮", category: .executing),
            .simple("Sprint mode...", emoji: "🏃", category: .executing),

            .uncommon("Home stretch...", emoji: "🏁", category: .executing),
            .uncommon("Going for gold...", emoji: "🥇", category: .executing),
            .uncommon("Eye on the ball...", emoji: "👁️", category: .search),
            .uncommon("Slam dunk...", emoji: "🏀", category: .edit),
            .uncommon("Touchdown!", emoji: "🏈", category: .executing),
            .uncommon("Ace serve...", emoji: "🎾", category: .bash),
            .uncommon("Hat trick...", emoji: "🎩", category: .agent),

            .rare("MVP status...", emoji: "🏆", category: .executing),
            .rare("World record pace...", emoji: "⏱️", category: .executing),
            .rare("Final boss mode...", emoji: "👹", category: .bash),

            .legendary("And the crowd goes wild!", emoji: "🎉", category: .executing),
        ])

        // MARK: Weather & Nature
        messages.append(contentsOf: [
            .simple("Sunny outlook...", emoji: "☀️", category: .thinking),
            .simple("Clear skies...", emoji: "🌤️", category: .thinking),
            .simple("Growing...", emoji: "🌱", category: .edit),

            .uncommon("Storm brewing...", emoji: "⛈️", category: .thinking),
            .uncommon("Lightning fast...", emoji: "⚡", category: .executing),
            .uncommon("Planting seeds...", emoji: "🌻", category: .edit),
            .uncommon("Branching out...", emoji: "🌳", category: .edit),
            .uncommon("Weathering bugs...", emoji: "🌧️", category: .search),
            .uncommon("Calm before ship...", emoji: "🌊", category: .thinking),

            .rare("Code tornado...", emoji: "🌪️", category: .executing),
            .rare("Aurora of ideas...", emoji: "🌌", category: .thinking),

            .legendary("Nature finds a way...", emoji: "🦖", category: .thinking),
        ])

        return messages
    }
}
