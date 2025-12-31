import Foundation

/// Caches project data for instant app startup
/// Restores cached projects immediately, then updates in background
@MainActor
class ProjectCache: ObservableObject {
    static let shared = ProjectCache()

    @Published private(set) var cachedProjects: [Project] = []
    @Published private(set) var cachedGitStatuses: [String: GitStatus] = [:]
    @Published private(set) var cachedBranchNames: [String: String] = [:]
    @Published private(set) var cachedSessionCounts: [String: Int] = [:]
    @Published private(set) var cachedRecentSessions: [CLISessionMetadata] = []
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isStale: Bool = true

    /// Timestamp of last recent sessions fetch (for TTL)
    private var recentSessionsCacheTime: Date?

    /// TTL for recent sessions cache (60 seconds)
    private static let recentSessionsTTL: TimeInterval = 60

    /// Whether we have cached recent sessions
    var hasRecentSessions: Bool {
        !cachedRecentSessions.isEmpty
    }

    /// Whether recent sessions cache is still valid (within TTL)
    var isRecentSessionsCacheValid: Bool {
        guard let cacheTime = recentSessionsCacheTime else { return false }
        return Date().timeIntervalSince(cacheTime) < Self.recentSessionsTTL
    }

    private static let cacheFile: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("project-cache.json")
    }()

    private static let fileQueue = DispatchQueue(label: "com.codingbridge.projectcache", qos: .userInitiated)

    /// How long before cache is considered stale (5 minutes)
    private static let staleThreshold: TimeInterval = 300

    init() {
        loadCache()
    }

    /// Check if we have cached data available
    var hasCachedData: Bool {
        !cachedProjects.isEmpty
    }

    /// Load cached projects (called on init)
    private func loadCache() {
        let cacheFile = Self.cacheFile

        Self.fileQueue.async { [weak self] in
            guard let data = try? Data(contentsOf: cacheFile) else { return }

            do {
                let cache = try JSONDecoder().decode(CachedProjectData.self, from: data)
                Task { @MainActor [weak self] in
                    self?.cachedProjects = cache.projects
                    self?.cachedGitStatuses = cache.gitStatuses
                    self?.cachedBranchNames = cache.branchNames
                    self?.cachedSessionCounts = cache.sessionCounts
                    self?.cachedRecentSessions = cache.recentSessions
                    self?.lastUpdated = cache.timestamp
                    self?.isStale = cache.isStale(threshold: Self.staleThreshold)
                }
            } catch {
                log.error("[ProjectCache] Failed to decode cache: \(error)")
            }
        }
    }

    /// Save projects to cache
    func saveProjects(
        _ projects: [Project],
        gitStatuses: [String: GitStatus] = [:],
        branchNames: [String: String] = [:],
        sessionCounts: [String: Int]? = nil,
        recentSessions: [CLISessionMetadata]? = nil
    ) {
        cachedProjects = projects
        cachedGitStatuses = gitStatuses
        cachedBranchNames = branchNames
        if let counts = sessionCounts {
            cachedSessionCounts = counts
        }
        if let sessions = recentSessions {
            cachedRecentSessions = sessions
        }
        lastUpdated = Date()
        isStale = false

        persistCache()
    }

    /// Persist current cache state to disk
    private func persistCache() {
        let cache = CachedProjectData(
            projects: cachedProjects,
            gitStatuses: cachedGitStatuses,
            branchNames: cachedBranchNames,
            sessionCounts: cachedSessionCounts,
            recentSessions: cachedRecentSessions,
            timestamp: Date()
        )

        let cacheFile = Self.cacheFile

        Self.fileQueue.async {
            do {
                let data = try JSONEncoder().encode(cache)
                try data.write(to: cacheFile, options: .atomic)
            } catch {
                log.error("[ProjectCache] Failed to save cache: \(error)")
            }
        }
    }

    /// Update git status for a single project (progressive loading)
    func updateGitStatus(for projectPath: String, status: GitStatus, branchName: String? = nil) {
        cachedGitStatuses[projectPath] = status
        if let branch = branchName {
            cachedBranchNames[projectPath] = branch
        }
    }

    /// Update branch name for a single project
    func updateBranchName(for projectPath: String, branch: String) {
        cachedBranchNames[projectPath] = branch
    }

    /// Batch update git statuses
    func updateGitStatuses(_ statuses: [String: GitStatus], branchNames: [String: String] = [:]) {
        for (path, status) in statuses {
            cachedGitStatuses[path] = status
        }
        for (path, branch) in branchNames {
            cachedBranchNames[path] = branch
        }
        persistCache()
    }

    /// Update session count for a single project
    func updateSessionCount(for projectPath: String, count: Int) {
        cachedSessionCounts[projectPath] = count
    }

    /// Batch update session counts and persist
    func updateSessionCounts(_ counts: [String: Int]) {
        for (path, count) in counts {
            cachedSessionCounts[path] = count
        }
        persistCache()
    }

    /// Get cached session count for a project
    func sessionCount(for projectPath: String) -> Int? {
        cachedSessionCounts[projectPath]
    }

    /// Update recent sessions cache
    func updateRecentSessions(_ sessions: [CLISessionMetadata]) {
        cachedRecentSessions = sessions
        recentSessionsCacheTime = Date()
        persistCache()
    }

    /// Clear the cache
    func clearCache() {
        cachedProjects = []
        cachedGitStatuses = [:]
        cachedBranchNames = [:]
        cachedSessionCounts = [:]
        cachedRecentSessions = []
        lastUpdated = nil
        isStale = true

        let cacheFile = Self.cacheFile
        Self.fileQueue.async {
            try? FileManager.default.removeItem(at: cacheFile)
        }
    }
}

// MARK: - Cache Data Model

private struct CachedProjectData: Codable {
    let projects: [Project]
    let storedGitStatuses: [String: CodableGitStatus]
    let storedBranchNames: [String: String]?
    let storedSessionCounts: [String: Int]?
    let storedRecentSessions: [CLISessionMetadata]?
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case projects
        case storedGitStatuses = "gitStatuses"
        case storedBranchNames = "branchNames"
        case storedSessionCounts = "sessionCounts"
        case storedRecentSessions = "recentSessions"
        case timestamp
    }

    init(
        projects: [Project],
        gitStatuses: [String: GitStatus],
        branchNames: [String: String],
        sessionCounts: [String: Int],
        recentSessions: [CLISessionMetadata],
        timestamp: Date
    ) {
        self.projects = projects
        self.storedGitStatuses = gitStatuses.mapValues { CodableGitStatus(from: $0) }
        self.storedBranchNames = branchNames
        self.storedSessionCounts = sessionCounts
        self.storedRecentSessions = recentSessions
        self.timestamp = timestamp
    }

    /// Check if cache is stale based on age
    func isStale(threshold: TimeInterval) -> Bool {
        return Date().timeIntervalSince(timestamp) > threshold
    }

    /// Get git statuses as [String: GitStatus]
    var gitStatuses: [String: GitStatus] {
        storedGitStatuses.mapValues { $0.toGitStatus }
    }

    /// Get branch names (optional for backwards compatibility)
    var branchNames: [String: String] {
        storedBranchNames ?? [:]
    }

    /// Get session counts (optional for backwards compatibility)
    var sessionCounts: [String: Int] {
        storedSessionCounts ?? [:]
    }

    /// Get recent sessions (optional for backwards compatibility)
    var recentSessions: [CLISessionMetadata] {
        storedRecentSessions ?? []
    }
}

/// Codable wrapper for GitStatus enum
private struct CodableGitStatus: Codable {
    let type: String
    let count: Int?
    let message: String?

    init(from status: GitStatus) {
        switch status {
        case .unknown:
            self.type = "unknown"
            self.count = nil
            self.message = nil
        case .checking:
            self.type = "checking"
            self.count = nil
            self.message = nil
        case .notGitRepo:
            self.type = "notGitRepo"
            self.count = nil
            self.message = nil
        case .clean:
            self.type = "clean"
            self.count = nil
            self.message = nil
        case .dirty:
            self.type = "dirty"
            self.count = nil
            self.message = nil
        case .ahead(let n):
            self.type = "ahead"
            self.count = n
            self.message = nil
        case .behind(let n):
            self.type = "behind"
            self.count = n
            self.message = nil
        case .diverged:
            self.type = "diverged"
            self.count = nil
            self.message = nil
        case .dirtyAndAhead:
            self.type = "dirtyAndAhead"
            self.count = nil
            self.message = nil
        case .error(let msg):
            self.type = "error"
            self.count = nil
            self.message = msg
        }
    }

    var toGitStatus: GitStatus {
        switch type {
        case "unknown": return .unknown
        case "checking": return .checking
        case "notGitRepo": return .notGitRepo
        case "clean": return .clean
        case "dirty": return .dirty
        case "ahead": return .ahead(count ?? 0)
        case "behind": return .behind(count ?? 0)
        case "diverged": return .diverged
        case "dirtyAndAhead": return .dirtyAndAhead
        case "error": return .error(message ?? "Unknown error")
        default: return .unknown
        }
    }
}

