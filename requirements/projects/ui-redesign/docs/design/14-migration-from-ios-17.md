# Migration from iOS 17


| Before (iOS 17) | After (iOS 26) |
|-----------------|----------------|
| `.background(.ultraThinMaterial)` | `.glassEffect()` |
| `.background(.regularMaterial)` | `.glassEffect()` |
| `.background(.thickMaterial)` | `.glassEffect()` |
| `.background(.bar)` | Remove (automatic) |
| Custom nav bar backgrounds | Remove (automatic) |
| UIKit haptics | `.sensoryFeedback()` |

**Important**: Do not mix old material effects with Liquid Glass. Use one system consistently.

---
