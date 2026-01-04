# Spacing & Layout


### Base Grid (4pt)

| Token | Value | Use |
|-------|-------|-----|
| `xxs` | 2pt | Minimal gaps |
| `xs` | 4pt | Tight spacing |
| `sm` | 6pt | Small gaps |
| `md` | 8pt | Standard spacing |
| `lg` | 12pt | Comfortable spacing |
| `xl` | 16pt | Section breaks |
| `xxl` | 24pt | Major sections |
| `xxxl` | 32pt | Page margins |

### Component-Specific

| Token | Value | Use |
|-------|-------|-----|
| `cardPadding` | 12pt | Inside cards |
| `cardGap` | 8pt | Between cards |
| `listRowPadding` | 16pt | List row sides |
| `sheetPadding` | 20pt | Sheet margins |
| `sidebarWidth` | 280-400pt | Sidebar column |

### Safe Areas

```swift
// Respect safe areas
VStack {
    content
}
.safeAreaPadding()

// Custom bottom padding for input
.safeAreaInset(edge: .bottom) {
    InputView()
}
```

### ToolbarSpacer (iOS 26)

Use `ToolbarSpacer` for precise toolbar layout without invisible spacer views:

```swift
.toolbar {
    ToolbarItem(placement: .primaryAction) {
        Button("Send", systemImage: "arrow.up.circle.fill", action: send)
    }

    ToolbarSpacer(.fixed, width: 16)

    ToolbarItem(placement: .primaryAction) {
        Menu {
            // Options
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
}
```

**Spacer Types:**
| Type | Use |
|------|-----|
| `.fixed` | Exact pixel spacing |
| `.flexible` | Expands to fill available space |

### listSectionMargins (iOS 26)

Control list section margins without custom modifiers:

```swift
List {
    Section("Messages") {
        ForEach(messages) { message in
            MessageRow(message: message)
        }
    }
    .listSectionMargins(.horizontal, 16)
    .listSectionMargins(.vertical, 8)

    Section("Tools") {
        // ...
    }
    .listSectionMargins(.all, 12)
}
```

### scrollIndicatorsFlash (iOS 26)

Flash scroll indicators to draw attention to scrollable content:

```swift
ScrollView {
    LazyVStack {
        ForEach(messages) { message in
            MessageCard(message: message)
        }
    }
}
.scrollIndicatorsFlash(trigger: newMessageCount)
```

Use when:
- New content arrives while user is scrolled up
- Content length changes significantly
- User needs awareness of scrollable area

---
