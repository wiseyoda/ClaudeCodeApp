import Foundation

// MARK: - SSHManager Git Operations Extension

extension SSHManager {
    // MARK: - Git Status

    /// Check if a path is a git repository
    func isGitRepo(_ path: String) async throws -> Bool {
        guard let client = client, isConnected else {
            throw SSHError.notConnected
        }

        let cmd = "cd \(shellEscapePath(path)) && git rev-parse --is-inside-work-tree 2>/dev/null"
        let result = try await client.execute(cmd)
        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return output == "true"
    }

    /// Check git status for a project path
    /// Returns a GitStatus enum indicating the sync state
    static func parseGitStatus(isGitResult: String, statusOutput: String, revListOutput: String) -> GitStatus {
        let isGit = isGitResult.trimmingCharacters(in: .whitespacesAndNewlines)
        if isGit != "true" {
            return .notGitRepo
        }

        let hasUncommittedChanges = !statusOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let trimmedRevList = revListOutput.trimmingCharacters(in: .whitespacesAndNewlines)

        var aheadCount = 0
        var behindCount = 0

        let parts = trimmedRevList.split(separator: "\t")
        if parts.count == 2 {
            aheadCount = Int(parts[0]) ?? 0
            behindCount = Int(parts[1]) ?? 0
        }

        if hasUncommittedChanges {
            if aheadCount > 0 {
                return .dirtyAndAhead
            }
            return .dirty
        }

        if aheadCount > 0 && behindCount > 0 {
            return .diverged
        }

        if aheadCount > 0 {
            return .ahead(aheadCount)
        }

        if behindCount > 0 {
            return .behind(behindCount)
        }

        return .clean
    }

    func checkGitStatus(_ path: String) async throws -> GitStatus {
        guard let client = client, isConnected else {
            throw SSHError.notConnected
        }

        // First check if it's a git repo
        // Use `|| echo "false"` to ensure command succeeds even if not a git repo
        let escapedPath = shellEscapePath(path)
        let isGitCmd = "cd \(escapedPath) && git rev-parse --is-inside-work-tree 2>/dev/null || echo 'false'"
        let isGitResult = try await client.execute(isGitCmd)
        let isGitOutput = isGitResult.output

        // Check for uncommitted changes (including untracked files)
        // Use `|| true` to ensure command succeeds even on git errors
        let statusCmd = "cd \(escapedPath) && git status --porcelain 2>/dev/null || true"
        let statusResult = try await client.execute(statusCmd)
        let statusOutput = statusResult.output

        // Fetch remote to get accurate ahead/behind (non-blocking, with timeout)
        _ = try? await client.execute("cd \(escapedPath) && timeout 5s git fetch --quiet 2>/dev/null || true")

        // Check ahead/behind status relative to upstream
        // Use `|| echo ""` to handle repos without upstream configured (returns empty string)
        let revListCmd = "cd \(escapedPath) && git rev-list --left-right --count HEAD...@{upstream} 2>/dev/null || echo ''"
        let revListResult = try await client.execute(revListCmd)
        let revListOutput = revListResult.output

        return Self.parseGitStatus(
            isGitResult: isGitOutput,
            statusOutput: statusOutput,
            revListOutput: revListOutput
        )
    }

    /// Check git status with auto-connect
    /// Returns .unknown for connection failures (SSH not configured) to avoid showing errors
    /// Returns .error only for actual git command failures after successful connection
    func checkGitStatusWithAutoConnect(_ path: String, settings: AppSettings) async -> GitStatus {
        // Try to connect if not already connected
        if !isConnected {
            do {
                try await autoConnect(settings: settings)
            } catch {
                // Connection failure is expected when SSH is not configured (e.g., iOS Simulator)
                // Silently return .unknown instead of showing an error
                log.debug("SSH connection not available for git status check: \(error.localizedDescription)")
                return .unknown
            }
        }

        // Now try to check git status (we have a connection)
        do {
            return try await checkGitStatus(path)
        } catch {
            // This is an actual git command failure, report it
            log.error("Failed to check git status for \(path): \(error)")
            return .error(error.localizedDescription)
        }
    }

    // MARK: - Git Pull

    /// Pull latest changes from remote (fast-forward only)
    /// Returns true if successful, false otherwise
    func gitPull(_ path: String) async throws -> Bool {
        guard let client = client, isConnected else {
            throw SSHError.notConnected
        }

        let cmd = "cd \(shellEscapePath(path)) && git pull --ff-only 2>&1"
        let result = try await client.execute(cmd)
        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for success indicators
        if output.contains("Already up to date") || output.contains("Fast-forward") {
            log.info("Git pull successful for \(path)")
            return true
        }

        // Check for failure indicators
        if output.contains("fatal:") || output.contains("error:") {
            log.warning("Git pull failed for \(path): \(output)")
            return false
        }

        return true
    }

    /// Pull with auto-connect
    func gitPullWithAutoConnect(_ path: String, settings: AppSettings) async -> Bool {
        do {
            if !isConnected {
                try await autoConnect(settings: settings)
            }
            return try await gitPull(path)
        } catch {
            log.error("Failed to git pull for \(path): \(error)")
            return false
        }
    }

    // MARK: - Git Diff

    /// Get git diff summary for dirty repos
    func getGitDiffSummary(_ path: String) async throws -> String {
        guard let client = client, isConnected else {
            throw SSHError.notConnected
        }

        // Get a summary of changes: modified files, untracked files, staged changes
        let escapedPath = shellEscapePath(path)
        let cmd = """
        cd \(escapedPath) && echo "=== Git Status ===" && git status --short && \
        echo "" && echo "=== Recent Commits (unpushed) ===" && \
        git log --oneline @{upstream}..HEAD 2>/dev/null || echo "(no upstream)" && \
        echo "" && echo "=== Diff Stats ===" && git diff --stat 2>/dev/null
        """

        let result = try await client.execute(cmd)
        return result.output
    }

    // MARK: - Multi-Repo Discovery

    /// Discover nested git repositories within a project directory
    /// Scans up to maxDepth levels deep for subdirectories containing .git folders
    /// - Parameters:
    ///   - basePath: The root project path to scan
    ///   - maxDepth: Maximum depth to scan (default 2)
    /// - Returns: Array of relative paths to directories containing .git
    func discoverSubRepos(_ basePath: String, maxDepth: Int = 2) async throws -> [String] {
        guard let client = client, isConnected else {
            throw SSHError.notConnected
        }

        let escapedPath = shellEscapePath(basePath)

        // Use find to locate .git entries, then extract parent paths
        // -mindepth 2 excludes the root .git folder (depth 1 would be ./.git)
        // Git submodules use a .git FILE (not directory) that points to the actual repo,
        // so we need to find both -type d (regular repos) and -type f (submodules)
        // Output format: ./packages/api (relative paths)
        let cmd = """
        cd \(escapedPath) && find . -mindepth 2 -maxdepth \(maxDepth + 1) -name '.git' \\( -type d -o -type f \\) 2>/dev/null | \
        sed 's|/\\.git$||' | \
        sed 's|^\\./||' | \
        sort
        """

        let result = try await client.execute(cmd)
        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !output.isEmpty else {
            return []
        }

        // Parse output: one relative path per line
        return output
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Discover nested git repositories with auto-connect
    func discoverSubReposWithAutoConnect(_ basePath: String, maxDepth: Int = 2, settings: AppSettings) async -> [String] {
        do {
            if !isConnected {
                try await autoConnect(settings: settings)
            }
            return try await discoverSubRepos(basePath, maxDepth: maxDepth)
        } catch {
            log.error("Failed to discover sub-repos in \(basePath): \(error)")
            return []
        }
    }

    // MARK: - Multi-Repo Status

    /// Check git status for multiple sub-repositories sequentially
    /// Note: Sequential execution is used because the Citadel SSH library doesn't handle
    /// concurrent executeCommand calls reliably - running multiple git status checks
    /// in parallel causes channel/connection errors for most of the requests.
    /// - Parameters:
    ///   - basePath: The root project path
    ///   - subRepoPaths: Array of relative paths to sub-repos
    /// - Returns: Dictionary mapping relative path to GitStatus
    func checkMultiRepoStatus(_ basePath: String, subRepoPaths: [String]) async -> [String: GitStatus] {
        guard isConnected else {
            return Dictionary(uniqueKeysWithValues: subRepoPaths.map { ($0, GitStatus.unknown) })
        }

        // Check sub-repos sequentially to avoid SSH channel conflicts
        // Each checkGitStatus runs multiple SSH commands, and concurrent execution
        // causes most checks to fail with connection errors
        var results: [String: GitStatus] = [:]
        for relativePath in subRepoPaths {
            let fullPath = (basePath as NSString).appendingPathComponent(relativePath)
            do {
                let status = try await self.checkGitStatus(fullPath)
                results[relativePath] = status
            } catch {
                results[relativePath] = .error(error.localizedDescription)
            }
        }
        return results
    }

    /// Check git status for multiple sub-repositories with auto-connect
    func checkMultiRepoStatusWithAutoConnect(
        _ basePath: String,
        subRepoPaths: [String],
        settings: AppSettings
    ) async -> [String: GitStatus] {
        do {
            if !isConnected {
                try await autoConnect(settings: settings)
            }
            return await checkMultiRepoStatus(basePath, subRepoPaths: subRepoPaths)
        } catch {
            log.error("Failed to check multi-repo status for \(basePath): \(error)")
            return Dictionary(uniqueKeysWithValues: subRepoPaths.map { ($0, GitStatus.unknown) })
        }
    }

    // MARK: - Sub-Repo Pull

    /// Pull a specific sub-repository
    func pullSubRepo(_ basePath: String, relativePath: String, settings: AppSettings) async -> Bool {
        let fullPath = (basePath as NSString).appendingPathComponent(relativePath)
        return await gitPullWithAutoConnect(fullPath, settings: settings)
    }

    /// Pull all sub-repositories that are behind
    /// Note: Sequential execution to avoid SSH channel conflicts (see checkMultiRepoStatus)
    /// - Returns: Dictionary of relativePath -> success/failure
    func pullAllBehindSubRepos(
        _ basePath: String,
        subRepos: [SubRepo],
        settings: AppSettings
    ) async -> [String: Bool] {
        let behindRepos = subRepos.filter { $0.status.canAutoPull }

        // Pull repos sequentially to avoid SSH channel conflicts
        var results: [String: Bool] = [:]
        for subRepo in behindRepos {
            let success = await self.pullSubRepo(basePath, relativePath: subRepo.relativePath, settings: settings)
            results[subRepo.relativePath] = success
        }
        return results
    }
}
