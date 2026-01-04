# Localization


- Use String Catalogs (`.xcstrings`) for all user-facing text.
- Prefer `LocalizedStringResource` in SwiftUI.
- Use keys with a stable namespace: `feature.section.key`.
- Handle plurals via String Catalog variants.

```swift
Text("settings.connection.title")

Text(String.localizedStringWithFormat(
    NSLocalizedString("sessions.count", comment: ""),
    count
))
```

---
