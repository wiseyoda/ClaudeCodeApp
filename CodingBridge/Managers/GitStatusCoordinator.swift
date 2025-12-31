import SwiftUI

/// Coordinates git status checking and multi-repo management for projects.
/// Extracts git-related logic from ContentView to keep it focused on navigation/layout.
@MainActor
class GitStatusCoordinator: ObservableObject {
    @Published var gitStatuses: [String: GitStatus] = [:]
    @Published var branchNames: [String: String] = [:]
    @Published var multiRepoStatuses: [String: MultiRepoStatus] = [:]
    @Published var expandedProjects: Set<String> = []
    @Published var isCheckingGitStatus = false
    @Published var gitRefreshError: String?
    @Published var showGitRefreshError = false

    private let projectCache = ProjectCache.shared
    private let projectSettingsStore = ProjectSettingsStore.shared

    /// Returns the effective git status for a project path.
    /// Prefers local state when .checking (during refresh), otherwise uses ProjectCache.
    func effectiveGitStatus(for path: String) -> GitStatus {
        let localStatus = gitStatuses[path]
        // During refresh, show .checking from local state
        if localStatus == .checking {
            return .checking
        }
        // Otherwise prefer cache (which ChatView updates)
        return projectCache.cachedGitStatuses[path] ?? localStatus ?? .unknown
    }

    /// Load initial data from cache
    func loadFromCache() {
        gitStatuses = projectCache.cachedGitStatuses
        branchNames = projectCache.cachedBranchNames
    }

    /// Extract git statuses from CLI projects response
    func updateFromCLIProjects(_ cliProjects: [CLIProject]) {
        for cliProject in cliProjects {
            if let git = cliProject.git {
                gitStatuses[cliProject.path] = git.toGitStatus
                if let branch = git.branch {
                    branchNames[cliProject.path] = branch
                }
            }
        }
    }

    /// Refresh git status for all projects via cli-bridge API
    func checkAllGitStatuses(serverURL: String, projects: [Project]) async {
        guard !isCheckingGitStatus else { return }

        isCheckingGitStatus = true

        // Mark all as checking
        for project in projects {
            gitStatuses[project.path] = .checking
        }

        do {
            let apiClient = CLIBridgeAPIClient(serverURL: serverURL)
            let cliProjects = try await apiClient.fetchProjects()

            // Extract git statuses and branch names from cli-bridge response
            for cliProject in cliProjects {
                if let git = cliProject.git {
                    gitStatuses[cliProject.path] = git.toGitStatus
                    projectCache.updateGitStatus(for: cliProject.path, status: git.toGitStatus, branchName: git.branch)
                    if let branch = git.branch {
                        branchNames[cliProject.path] = branch
                    }
                }
            }
        } catch {
            log.error("[Git] Failed to fetch git statuses from API: \(error)")
            gitRefreshError = "Failed to refresh git status: \(error.localizedDescription)"
            showGitRefreshError = true
        }

        isCheckingGitStatus = false
    }

    /// Refresh git status for a single project via cli-bridge API
    func refreshGitStatus(for project: Project, serverURL: String) async {
        gitStatuses[project.path] = .checking

        do {
            let apiClient = CLIBridgeAPIClient(serverURL: serverURL)
            let cliProjects = try await apiClient.fetchProjects()

            if let cliProject = cliProjects.first(where: { $0.path == project.path }),
               let git = cliProject.git {
                gitStatuses[project.path] = git.toGitStatus
                projectCache.updateGitStatus(for: project.path, status: git.toGitStatus, branchName: git.branch)
                if let branch = git.branch {
                    branchNames[project.path] = branch
                }
            } else {
                gitStatuses[project.path] = .notGitRepo
            }
        } catch {
            log.error("[Git] Failed to refresh git status for \(project.path): \(error)")
            gitStatuses[project.path] = .error(error.localizedDescription)
        }
    }

    // MARK: - Multi-Repo (Monorepo) Support

    /// Discover sub-repos for all projects in parallel
    func discoverAllSubRepos(serverURL: String, projects: [Project]) async {
        // Filter to only projects with subrepo discovery enabled (opt-in, default off)
        let enabledProjects = projects.filter { projectSettingsStore.isSubrepoDiscoveryEnabled(for: $0.path) }

        guard !enabledProjects.isEmpty else {
            log.debug("[MultiRepo] No projects have subrepo discovery enabled, skipping")
            return
        }

        log.debug("[MultiRepo] Discovering sub-repos for \(enabledProjects.count) projects")
        let apiClient = CLIBridgeAPIClient(serverURL: serverURL)

        // Mark enabled projects as scanning
        for project in enabledProjects {
            multiRepoStatuses[project.path] = MultiRepoStatus(isScanning: true)
        }

        // Discover in parallel using TaskGroup
        await withTaskGroup(of: (String, [SubRepo]?).self) { group in
            for project in enabledProjects {
                group.addTask {
                    do {
                        let subRepoInfos = try await apiClient.discoverSubRepos(projectPath: project.path)
                        let subRepos = subRepoInfos.map { info in
                            SubRepo(
                                relativePath: info.relativePath,
                                fullPath: "\(project.path)/\(info.relativePath)",
                                status: info.git.toGitStatus
                            )
                        }
                        return (project.path, subRepos)
                    } catch {
                        log.error("[MultiRepo] Failed to discover sub-repos for \(project.path): \(error)")
                        return (project.path, nil)
                    }
                }
            }

            // Collect results
            for await (projectPath, subRepos) in group {
                if let subRepos = subRepos {
                    multiRepoStatuses[projectPath] = MultiRepoStatus(subRepos: subRepos)
                } else {
                    multiRepoStatuses[projectPath] = MultiRepoStatus()
                }
            }
        }
    }

    /// Refresh all sub-repos for a project
    func refreshAllSubRepos(project: Project, serverURL: String) async {
        let apiClient = CLIBridgeAPIClient(serverURL: serverURL)

        if var status = multiRepoStatuses[project.path] {
            status.isScanning = true
            multiRepoStatuses[project.path] = status
        }

        do {
            let subRepoInfos = try await apiClient.discoverSubRepos(projectPath: project.path)
            let subRepos = subRepoInfos.map { info in
                SubRepo(
                    relativePath: info.relativePath,
                    fullPath: "\(project.path)/\(info.relativePath)",
                    status: info.git.toGitStatus
                )
            }

            multiRepoStatuses[project.path] = MultiRepoStatus(subRepos: subRepos)
        } catch {
            log.error("[MultiRepo] Failed to refresh sub-repos for \(project.path): \(error)")
            if var status = multiRepoStatuses[project.path] {
                status.isScanning = false
                multiRepoStatuses[project.path] = status
            }
        }
    }

    /// Pull a single sub-repo
    func pullSubRepo(project: Project, subRepo: SubRepo, serverURL: String) async {
        let apiClient = CLIBridgeAPIClient(serverURL: serverURL)

        do {
            let _ = try await apiClient.pullSubRepo(
                projectPath: project.path,
                relativePath: subRepo.relativePath
            )
            // Refresh status after pull
            await refreshAllSubRepos(project: project, serverURL: serverURL)
        } catch {
            log.error("[MultiRepo] Failed to pull sub-repo \(subRepo.relativePath): \(error)")
        }
    }

    /// Pull all sub-repos that are behind
    func pullAllBehindSubRepos(project: Project, serverURL: String) async {
        guard let multiRepoStatus = multiRepoStatuses[project.path] else { return }

        let behindSubRepos = multiRepoStatus.subRepos.filter { subRepo in
            if case .behind = subRepo.status { return true }
            return false
        }

        for subRepo in behindSubRepos {
            await pullSubRepo(project: project, subRepo: subRepo, serverURL: serverURL)
        }
    }

    /// Toggle project expansion in multi-repo view
    func toggleExpansion(for projectPath: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedProjects.contains(projectPath) {
                expandedProjects.remove(projectPath)
            } else {
                expandedProjects.insert(projectPath)
            }
        }
    }

    /// Save current state to project cache
    func saveToCache() {
        // Git statuses and branch names are saved via projectCache.updateGitStatus
        // which is called during refresh operations
    }
}
