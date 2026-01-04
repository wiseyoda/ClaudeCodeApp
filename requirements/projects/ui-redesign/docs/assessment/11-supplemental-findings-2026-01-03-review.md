# Supplemental Findings (2026-01-03 Review)


### Additional Swift 6.2.1 Features to Consider

The project could leverage these Swift 6.2.1 features not currently specified:

| Feature | Potential Use |
|---------|---------------|
| **~Copyable types** | Guaranteed cleanup for resources (WebSocket connections, file handles) |
| **Typed throws** | More explicit error handling (e.g., `throws(NetworkError)`) |
| **Improved async testing** | Already mentioned in README, ensure test framework uses it |

### Unmapped Existing Files

These files from the current codebase have no clear owner in the redesign:

| File | Current Purpose | Recommendation |
|------|-----------------|----------------|
| `SpeechManager.swift` | Voice input | Add to Issue #26 (Chat View) or create Issue #59 |
| `HealthMonitorService.swift` | Backend connectivity | Add to Issue #00 or create monitoring issue |
| `OfflineActionQueue.swift` | Queue for offline | Add to Issue #53 (Offline Mode) |
| `BackgroundManager.swift` | Background tasks | Add to ../build/README.md capabilities |

### Missing Platform Features

| Feature | Gap | Recommendation |
|---------|-----|----------------|
| **State Restoration** | No `NSUserActivity` handling | Add to Issue #43 or new issue |
| **Rich Notifications** | Inline reply actions not specified | Add to Issue #20 |
| **Share Extension** | Could share code/conversations | Consider Issue #60 if desired |

### Suggested Deep Link Schema

Add to Issue #43:

```
codingbridge://project/{encoded-path}
codingbridge://session/{encoded-path}/{sessionId}
codingbridge://settings
codingbridge://terminal
```

### Recommended Execution Order

For optimal agent execution, the following strict order is recommended for Phase 0:

```
Issue #00 (Data Normalization)    ← Critical foundation, do first
    ↓
Issue #10 (@Observable Migration)  ← Unlocks all state management
    ↓
Issue #01 (Design Tokens)          ← Needed for all UI work
    ↓
Issue #17 (Liquid Glass)           ← Visual foundation
    ↓
Issue #40 (Testing Strategy)       ← Expand before implementation
    ↓
Issues #44, #45, #46 (Debug, Flags, i18n) ← Can parallelize
```

### Testing Strategy Expansion Needed

Issue #40 is only ~75 lines. Expand with:

- [ ] Snapshot testing strategy (accept/reject flow)
- [ ] Network mocking approach (`URLProtocol` or library)
- [ ] Test data factory patterns (`Message.mock()`, `Project.mock()`)
- [ ] CI integration requirements (GitHub Actions / Xcode Cloud)
- [ ] Coverage enforcement mechanism (fail build if <80%)

### Error Recovery Details Needed

Add to ../architecture/data/README.md:

```swift
// WebSocket reconnection
let backoff = ExponentialBackoff(
    initial: 1.0,      // 1 second
    multiplier: 2.0,   // Double each attempt
    maxDelay: 30.0,    // Cap at 30 seconds
    jitter: 0.1        // ±10% randomization
)

// REST retry policy
struct RetryPolicy {
    let idempotentMethods: Set<HTTPMethod> = [.GET, .HEAD, .PUT, .DELETE]
    let maxAttempts = 3
    let retryStatusCodes: Set<Int> = [408, 429, 500, 502, 503, 504]
}
```

### Numeric Scoring Summary

| Criterion | Score | Notes |
|-----------|-------|-------|
| iOS 26.2 Tech Adoption | 9.5/10 | Near-perfect, minor gaps (Rich Text, DeclaredAgeRange) |
| Swift Coding Standards | 9/10 | Modern patterns, missing ~Copyable/typed throws |
| Production Readiness | 8/10 | Testing thin, observability missing |
| Agent-Friendliness | 9.5/10 | Exceptional structure, clear dependencies |
| Completeness | 8.5/10 | Some unmapped files, missing platform features |
| **Overall** | **9/10** | **Ready to execute with minor gaps** |

---
