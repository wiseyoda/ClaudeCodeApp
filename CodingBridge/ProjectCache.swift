import Foundation

/// Caches project data for instant app startup
/// Restores cached projects immediately, then updates in background
@MainActor
class ProjectCache: ObservableObject {
    static let shared = ProjectCache()

    @Published private(set) var cachedProjects: [Project] = []
    @Published private(set) var cachedGitStatuses: [String: GitStatus] = [:]
    @Published private(set) var cachedBranchNames: [String: String] = [:]
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isStale: Bool = true

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
                    self?.lastUpdated = cache.timestamp
                    self?.isStale = cache.isStale(threshold: Self.staleThreshold)
                }
            } catch {
                log.error("[ProjectCache] Failed to decode cache: \(error)")
            }
        }
    }

    /// Save projects to cache
    func saveProjects(_ projects: [Project], gitStatuses: [String: GitStatus] = [:], branchNames: [String: String] = [:]) {
        cachedProjects = projects
        cachedGitStatuses = gitStatuses
        cachedBranchNames = branchNames
        lastUpdated = Date()
        isStale = false

        let cache = CachedProjectData(
            projects: projects,
            gitStatuses: gitStatuses,
            branchNames: branchNames,
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
        // Save updated statuses to cache
        saveProjects(cachedProjects, gitStatuses: cachedGitStatuses, branchNames: cachedBranchNames)
    }

    /// Clear the cache
    func clearCache() {
        cachedProjects = []
        cachedGitStatuses = [:]
        cachedBranchNames = [:]
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
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case projects
        case storedGitStatuses = "gitStatuses"
        case storedBranchNames = "branchNames"
        case timestamp
    }

    init(projects: [Project], gitStatuses: [String: GitStatus], branchNames: [String: String], timestamp: Date) {
        self.projects = projects
        self.storedGitStatuses = gitStatuses.mapValues { CodableGitStatus(from: $0) }
        self.storedBranchNames = branchNames
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

