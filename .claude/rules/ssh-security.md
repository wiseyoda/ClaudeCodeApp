# SSH Security Rules

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
