# Responsive Layout Helpers


### AdaptiveStack

```swift
struct AdaptiveStack<Content: View>: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        if sizeClass == .compact {
            VStack(spacing: spacing, content: content)
        } else {
            HStack(spacing: spacing, content: content)
        }
    }
}
```

### ResponsiveGrid

```swift
struct ResponsiveGrid<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let minWidth: CGFloat
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: minWidth), spacing: 16)],
            spacing: 16
        ) {
            ForEach(items) { item in
                content(item)
            }
        }
    }
}
```

---
