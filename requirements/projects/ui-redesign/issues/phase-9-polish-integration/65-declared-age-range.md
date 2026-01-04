---
number: 65
title: DeclaredAgeRange
phase: phase-9-polish-integration
status: pending
completed_by: null
completed_at: null
verified_by: null
verified_at: null
commit: null
spot_checked: false
blocked_reason: null
---

# Issue 65: DeclaredAgeRange

**Phase:** 9 (Polish & Integration)
**Priority:** Medium
**Status:** Not Started
**Depends On:** 49 (Privacy Manifest)
**Target:** iOS 26.2, Xcode 26.2, Swift 6.2.1

## Goal

Implement Texas SB 2420 and similar age declaration requirements by configuring the app's `DeclaredAgeRange` in the privacy manifest and ensuring age-appropriate content handling.

## Scope

- In scope:
  - DeclaredAgeRange configuration in Info.plist
  - Privacy manifest age declaration
  - App Store age rating alignment
  - Content filtering based on age declaration
  - Parental gate for sensitive features
- Out of scope:
  - Age verification (ID check, face scan)
  - COPPA compliance for under-13 users
  - Regional age law variations beyond Texas
  - Parental controls integration

## Non-goals

- User age collection
- Age-based feature restrictions
- Marketing to minors

## Dependencies

- Issue #49 (Privacy Manifest) for base privacy configuration

## Touch Set

- Files to create:
  - `CodingBridge/Core/AgeCompliance.swift`
- Files to modify:
  - `CodingBridge/Info.plist` (add DeclaredAgeRange)
  - `CodingBridge/PrivacyInfo.xcprivacy` (age declaration)

---

## Background

### Texas SB 2420 (Securing Children Online through Parental Empowerment Act)

Requires apps to:
1. Declare intended age range for users
2. Implement parental consent mechanisms for minors
3. Provide age-appropriate content
4. Not collect data from known minors without consent

### App Store Age Ratings

| Rating | Ages | Content |
|--------|------|---------|
| 4+ | All ages | No objectionable content |
| 9+ | 9 and up | Mild content |
| 12+ | 12 and up | Moderate content |
| 17+ | 17 and up | Mature content |

**CodingBridge Target Rating:** 4+ (developer tool, no user content)

---

## Configuration

### Info.plist

```xml
<key>DeclaredAgeRange</key>
<dict>
    <key>MinimumAge</key>
    <integer>4</integer>
    <key>MaximumAge</key>
    <integer>0</integer> <!-- 0 = no maximum -->
    <key>DefaultAge</key>
    <integer>18</integer>
</dict>

<key>ITSAppUsesNonExemptEncryption</key>
<false/>

<key>UIRequiredDeviceCapabilities</key>
<array>
    <string>arm64</string>
</array>
```

### PrivacyInfo.xcprivacy

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <!-- Existing API declarations -->
    </array>

    <key>NSPrivacyDeclaredAgeRange</key>
    <dict>
        <key>NSPrivacyAgeRangeMinimum</key>
        <integer>4</integer>
        <key>NSPrivacyAgeRangeMaximum</key>
        <integer>0</integer>
        <key>NSPrivacyDefaultUserAge</key>
        <integer>18</integer>
        <key>NSPrivacyAgeRangeIntent</key>
        <string>General Audience</string>
    </dict>

    <key>NSPrivacyCollectedDataTypes</key>
    <array>
        <!-- No data collected from minors -->
    </array>
</dict>
</plist>
```

---

## Age Compliance Implementation

### AgeCompliance

```swift
import Foundation

/// Manages age compliance for regulatory requirements.
///
/// Implements Texas SB 2420 and similar state regulations
/// requiring apps to declare intended user age range.
enum AgeCompliance {
    /// Declared minimum age for app usage.
    static let minimumAge = 4

    /// Declared maximum age (0 = no maximum).
    static let maximumAge = 0

    /// Default assumed age for users.
    static let defaultAge = 18

    /// Age rating for App Store.
    static let appStoreRating = "4+"

    /// Whether the app is intended for general audiences.
    static let isGeneralAudience = true

    /// Content categories present in app.
    static let contentCategories: Set<ContentCategory> = [
        .developerTools,
        .productivity,
    ]

    /// Check if feature requires parental gate.
    static func requiresParentalGate(_ feature: Feature) -> Bool {
        switch feature {
        case .inAppPurchase:
            return true
        case .externalLinks:
            return false  // Links to documentation only
        case .userGeneratedContent:
            return false  // User's own code, not shared
        case .socialFeatures:
            return false  // No social features
        case .accountCreation:
            return false  // Uses existing Claude account
        }
    }

    /// Age-appropriate content filtering.
    static func filterContent(_ content: String) -> String {
        // CodingBridge doesn't host user content, so no filtering needed
        // Claude's responses are already moderated by Anthropic
        return content
    }

    enum ContentCategory {
        case developerTools
        case productivity
        case education
        case entertainment
    }

    enum Feature {
        case inAppPurchase
        case externalLinks
        case userGeneratedContent
        case socialFeatures
        case accountCreation
    }
}
```

---

## App Store Configuration

### App Store Connect Settings

| Setting | Value |
|---------|-------|
| Age Rating | 4+ |
| Made for Kids | No |
| Age Rating Override | None |

### Content Declarations

| Category | Present | Description |
|----------|---------|-------------|
| Violence | None | N/A |
| Sexual Content | None | N/A |
| Profanity | None | N/A |
| Drugs | None | N/A |
| Gambling | None | N/A |
| Horror | None | N/A |
| Mature Content | None | N/A |
| Alcohol/Tobacco | None | N/A |

### App Privacy

| Data Type | Collected | Linked | Tracking |
|-----------|-----------|--------|----------|
| Usage Data | Yes | No | No |
| Diagnostics | Yes | No | No |
| User Content | No | No | No |
| Identifiers | No | No | No |

---

## Parental Gate (If Required)

### ParentalGate

```swift
import SwiftUI

/// Simple parental gate for age-restricted actions.
///
/// Uses a math problem that young children typically cannot solve
/// but doesn't require actual age verification.
struct ParentalGate: View {
    @Environment(\.dismiss) var dismiss
    @State private var answer = ""
    @State private var problem = MathProblem.generate()
    @State private var attempts = 0

    let onSuccess: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Parental Verification")
                .font(.title2)
                .fontWeight(.bold)

            Text("Please solve this problem to continue:")
                .foregroundStyle(.secondary)

            Text(problem.question)
                .font(.title)
                .fontWeight(.medium)

            TextField("Answer", text: $answer)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
                .multilineTextAlignment(.center)

            Button("Verify") {
                verify()
            }
            .buttonStyle(.borderedProminent)
            .disabled(answer.isEmpty)

            if attempts > 0 {
                Text("Incorrect. Please try again.")
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.borderless)
        }
        .padding()
    }

    private func verify() {
        if Int(answer) == problem.answer {
            onSuccess()
            dismiss()
        } else {
            attempts += 1
            problem = MathProblem.generate()
            answer = ""
        }
    }

    struct MathProblem {
        let question: String
        let answer: Int

        static func generate() -> MathProblem {
            let a = Int.random(in: 10...20)
            let b = Int.random(in: 10...20)
            let operation = Bool.random()

            if operation {
                return MathProblem(
                    question: "\(a) + \(b) = ?",
                    answer: a + b
                )
            } else {
                let larger = max(a, b)
                let smaller = min(a, b)
                return MathProblem(
                    question: "\(larger) - \(smaller) = ?",
                    answer: larger - smaller
                )
            }
        }
    }
}
```

---

## Compliance Checklist

### Development

- [ ] DeclaredAgeRange in Info.plist
- [ ] Privacy manifest age declaration
- [ ] Content categories documented
- [ ] No data collection from minors
- [ ] Parental gate for purchases (if any)

### App Store Submission

- [ ] Age rating questionnaire completed
- [ ] Made for Kids set to No
- [ ] Privacy labels accurate
- [ ] Content declarations accurate
- [ ] EULA mentions age requirements

### Documentation

- [ ] Privacy policy mentions age requirements
- [ ] Terms of service mentions age requirements
- [ ] Support documentation age-appropriate

---

## Regional Considerations

| Region | Regulation | Requirement |
|--------|------------|-------------|
| Texas | SB 2420 | Age declaration, parental consent |
| California | AADC | Age-appropriate design |
| EU | GDPR | Parental consent under 16 |
| UK | Age Appropriate Design Code | Design for children |

### Implementation Notes

CodingBridge is a developer tool primarily used by adults. The 4+ rating reflects:
1. No objectionable content in the app itself
2. Claude's responses are moderated by Anthropic
3. No user-generated content sharing
4. No social features
5. No in-app purchases (currently)

---

## Edge Cases

- **User claims to be minor**: App continues to function, no data collection changes
- **In-app purchase added later**: Implement parental gate
- **Social features added later**: Re-evaluate age rating
- **AI generates concerning content**: Handled by Claude's content policy

## Acceptance Criteria

- [ ] DeclaredAgeRange configured in Info.plist
- [ ] Privacy manifest includes age declaration
- [ ] App Store age rating matches declaration
- [ ] No unnecessary parental gates
- [ ] Documentation updated for compliance
- [ ] Build passes App Store validation

## Testing

```swift
class AgeComplianceTests: XCTestCase {
    func testAgeRangeConfiguration() {
        XCTAssertEqual(AgeCompliance.minimumAge, 4)
        XCTAssertEqual(AgeCompliance.maximumAge, 0)
        XCTAssertEqual(AgeCompliance.appStoreRating, "4+")
    }

    func testParentalGateNotRequired() {
        // Most features don't require parental gate
        XCTAssertFalse(AgeCompliance.requiresParentalGate(.externalLinks))
        XCTAssertFalse(AgeCompliance.requiresParentalGate(.userGeneratedContent))
        XCTAssertFalse(AgeCompliance.requiresParentalGate(.socialFeatures))
    }

    func testParentalGateMathProblem() {
        let problem = ParentalGate.MathProblem.generate()

        // Verify answer is correct
        if problem.question.contains("+") {
            let components = problem.question.components(separatedBy: " ")
            let a = Int(components[0])!
            let b = Int(components[2])!
            XCTAssertEqual(problem.answer, a + b)
        }
    }

    func testInfoPlistConfiguration() {
        guard let plistPath = Bundle.main.path(forResource: "Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: plistPath),
              let ageRange = plist["DeclaredAgeRange"] as? [String: Any] else {
            XCTFail("DeclaredAgeRange not found in Info.plist")
            return
        }

        XCTAssertEqual(ageRange["MinimumAge"] as? Int, 4)
    }
}
```
