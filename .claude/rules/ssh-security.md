# SSH Security Rules

## Shell Variable Expansion

ALWAYS use `$HOME` instead of `~` and double quotes for paths:

```swift
// CORRECT: $HOME with double quotes allows shell expansion
let sessionFile = "$HOME/.claude/projects/\(encodedPath)/\(sessionId).jsonl"
let command = "rm -f \"\(sessionFile)\""

// WRONG: ~ with single quotes - tilde won't expand!
let sessionFile = "~/.claude/projects/\(encodedPath)/\(sessionId).jsonl"
let command = "rm -f '\(sessionFile)'"  // File not found!

// WRONG: $HOME with single quotes - variable won't expand!
let command = "rm -f '$HOME/path/file'"  // Literally looks for "$HOME/path/file"
```

**Why this matters:**
- `~` expansion only works in specific shell contexts (not inside quotes)
- Single quotes (`'...'`) prevent ALL shell expansion including `$HOME`
- Double quotes (`"..."`) allow variable expansion while still quoting the path
- Failures are silent - commands succeed but operate on wrong paths

## Command Injection Prevention

ALWAYS escape user-provided paths before passing to SSH commands:

```swift
// CORRECT: Escape single quotes for shell
func escapePath(_ path: String) -> String {
    return path.replacingOccurrences(of: "'", with: "'\\''")
}

let safe = escapePath(userPath)
let command = "cat '\(safe)'"

// WRONG: Direct interpolation
let command = "cat \(userPath)" // Command injection!
```

## Vulnerable Locations (Known Issues)

These lines in `SSHManager.swift` have unescaped paths:
- Line 700: `listFiles()`
- Line 747: `readFile()`
- Line 856: `deleteFile()`
- Line 879: `createDirectory()`
- Line 946: `executeGitCommand()`

## Credential Storage

```swift
// WRONG: UserDefaults for passwords
@AppStorage("sshPassword") var password = "" // Insecure!

// CORRECT: Use Keychain
KeychainHelper.save(password, forKey: "ssh-password")
let password = KeychainHelper.load(forKey: "ssh-password")
```
