# Target Platform

- iOS 26.2+ / iPadOS 26.2+ / Xcode 26.2+ (see build config for exact settings)
- No backwards compatibility; full adoption of latest platform APIs

Build configuration is the source of truth: [docs/build/README.md](../build/README.md).

## iOS 26.2 Features Adopted

| Feature | Version | Usage |
|---------|---------|-------|
| Liquid Glass | 26.0 | All cards, sheets, toolbars, sidebars |
| Liquid Glass Intensity | 26.2 | Respects user's slider preference |
| ToolbarSpacer | 26.0 | Precise toolbar layout control |
| Rich Text Editing | 26.0 | AttributedString in TextEditor |
| navigationSubtitle | 26.0 | Two-line navigation titles |
| listSectionMargins | 26.0 | Precise list margin control |
| scrollIndicatorsFlash | 26.0 | Visual feedback on new content |
| Quicker Menu Animations | 26.2 | Updated spring timing for menus |
| Swift 6.2.1 Async Testing | 26.1.1 | Improved async test support |
| SwiftUI Instruments | 26.1.1 | "Skipped Update" markers |

## Compliance

Texas SB 2420 (effective January 1, 2026): If distributing in Texas, implement the DeclaredAgeRange API for age verification.
