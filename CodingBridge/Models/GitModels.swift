import Foundation

// MARK: - Git Status

/// Represents the git sync status of a project
enum GitStatus: Equatable {
    case unknown        // Status not yet checked
    case checking       // Currently checking status
    case notGitRepo     // Not a git repository
    case clean          // Clean, up to date with remote
    case dirty          // Has uncommitted local changes
    case ahead(Int)     // Has unpushed commits
    case behind(Int)    // Behind remote (can auto-pull)
    case diverged       // Both ahead and behind (needs manual resolution)
    case dirtyAndAhead  // Uncommitted changes + unpushed commits
    case error(String)  // Failed to check status

    /// Icon to display for this status
    var icon: String {
        switch self {
        case .unknown, .checking:
            return "circle.dotted"
        case .notGitRepo:
            return "minus.circle"
        case .clean:
            return "checkmark.circle.fill"
        case .dirty:
            return "exclamationmark.triangle.fill"
        case .ahead:
            return "arrow.up.circle.fill"
        case .behind:
            return "arrow.down.circle.fill"
        case .diverged:
            return "arrow.up.arrow.down.circle.fill"
        case .dirtyAndAhead:
            return "exclamationmark.arrow.triangle.2.circlepath"
        case .error:
            return "xmark.circle"
        }
    }

    /// Color name for the status icon
    var colorName: String {
        switch self {
        case .unknown, .checking, .notGitRepo:
            return "gray"
        case .clean:
            return "green"
        case .dirty, .dirtyAndAhead, .diverged:
            return "orange"
        case .ahead:
            return "blue"
        case .behind:
            return "cyan"
        case .error:
            return "red"
        }
    }

    /// Short description for accessibility
    var accessibilityLabel: String {
        switch self {
        case .unknown:
            return "Status unknown"
        case .checking:
            return "Checking status"
        case .notGitRepo:
            return "Not a git repository"
        case .clean:
            return "Clean, up to date"
        case .dirty:
            return "Has uncommitted changes"
        case .ahead(let count):
            return "\(count) unpushed commit\(count == 1 ? "" : "s")"
        case .behind(let count):
            return "\(count) commit\(count == 1 ? "" : "s") behind remote"
        case .diverged:
            return "Diverged from remote"
        case .dirtyAndAhead:
            return "Uncommitted changes and unpushed commits"
        case .error(let msg):
            return "Error: \(msg)"
        }
    }

    /// Whether auto-pull is safe for this status
    var canAutoPull: Bool {
        switch self {
        case .behind:
            return true
        default:
            return false
        }
    }

    /// Whether this status indicates local changes that need attention
    var hasLocalChanges: Bool {
        switch self {
        case .dirty, .ahead, .dirtyAndAhead, .diverged:
            return true
        default:
            return false
        }
    }
}

// MARK: - Multi-Repo Git Status

/// Represents a nested git repository within a project
struct SubRepo: Identifiable, Hashable {
    let id: UUID
    let relativePath: String  // e.g., "packages/api" or "services/auth"
    let fullPath: String      // Full path for git commands
    var status: GitStatus

    init(relativePath: String, fullPath: String, status: GitStatus = .unknown) {
        self.id = UUID()
        self.relativePath = relativePath
        self.fullPath = fullPath
        self.status = status
    }

    // Hashable conformance (exclude status for stable identity)
    func hash(into hasher: inout Hasher) {
        hasher.combine(relativePath)
        hasher.combine(fullPath)
    }

    static func == (lhs: SubRepo, rhs: SubRepo) -> Bool {
        lhs.relativePath == rhs.relativePath && lhs.fullPath == rhs.fullPath
    }
}

/// Aggregated status for a project with multiple nested git repositories
struct MultiRepoStatus {
    var subRepos: [SubRepo]
    var isScanning: Bool = false

    init(subRepos: [SubRepo] = [], isScanning: Bool = false) {
        self.subRepos = subRepos
        self.isScanning = isScanning
    }

    /// Human-readable summary of sub-repo statuses (e.g., "2 dirty, 1 behind")
    var summary: String {
        guard !subRepos.isEmpty else { return "" }

        var counts: [String: Int] = [:]

        for subRepo in subRepos {
            switch subRepo.status {
            case .dirty, .dirtyAndAhead:
                counts["dirty", default: 0] += 1
            case .behind:
                counts["behind", default: 0] += 1
            case .ahead:
                counts["ahead", default: 0] += 1
            case .diverged:
                counts["diverged", default: 0] += 1
            case .error:
                counts["error", default: 0] += 1
            case .clean:
                counts["clean", default: 0] += 1
            case .unknown, .checking, .notGitRepo:
                break
            }
        }

        // Build summary string, prioritizing actionable items
        var parts: [String] = []
        if let count = counts["dirty"], count > 0 {
            parts.append("\(count) dirty")
        }
        if let count = counts["behind"], count > 0 {
            parts.append("\(count) behind")
        }
        if let count = counts["ahead"], count > 0 {
            parts.append("\(count) ahead")
        }
        if let count = counts["diverged"], count > 0 {
            parts.append("\(count) diverged")
        }
        if let count = counts["error"], count > 0 {
            parts.append("\(count) error")
        }

        if parts.isEmpty {
            let cleanCount = counts["clean"] ?? 0
            if cleanCount == subRepos.count {
                return "all clean"
            }
            return "\(subRepos.count) repos"
        }

        return parts.joined(separator: ", ")
    }

    /// Returns the most actionable/urgent status for badge coloring
    var worstStatus: GitStatus {
        // Priority order: error > diverged > dirty > behind > ahead > clean > unknown
        var hasError = false
        var hasDiverged = false
        var hasDirty = false
        var hasBehind = false
        var hasAhead = false
        var hasClean = false

        for subRepo in subRepos {
            switch subRepo.status {
            case .error:
                hasError = true
            case .diverged:
                hasDiverged = true
            case .dirty, .dirtyAndAhead:
                hasDirty = true
            case .behind:
                hasBehind = true
            case .ahead:
                hasAhead = true
            case .clean:
                hasClean = true
            default:
                break
            }
        }

        if hasError { return .error("sub-repo error") }
        if hasDiverged { return .diverged }
        if hasDirty { return .dirty }
        if hasBehind { return .behind(1) }
        if hasAhead { return .ahead(1) }
        if hasClean { return .clean }
        return .unknown
    }

    /// Whether any sub-repo needs user attention
    var hasActionableItems: Bool {
        subRepos.contains { subRepo in
            switch subRepo.status {
            case .dirty, .dirtyAndAhead, .behind, .ahead, .diverged, .error:
                return true
            default:
                return false
            }
        }
    }

    /// Count of sub-repos that can be auto-pulled
    var pullableCount: Int {
        subRepos.filter { $0.status.canAutoPull }.count
    }

    /// Whether there are any sub-repos
    var hasSubRepos: Bool {
        !subRepos.isEmpty
    }
}
