# Keep a separate stack per tab

Bind each tab to a fixed path so switching tabs preserves its navigation history.

## Overview

The root owns one router. Each tab creates a stack using the router's subscript;
buttons can update a specific stack and select its tab as separate actions.

```swift
import SwiftUI
import Waypoint

enum AppTab: Hashable { case home, library }
enum AppDestination: Hashable { case detail }
enum AppPresentation: String, PresentationRoute {
    case settings
    var id: String { rawValue }
}

@MainActor
struct TabsView: View {
    @State private var router =
        TabRouter<AppTab, AppDestination, AppPresentation>(initialTab: .home)

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {
            NavigationStack(path: $router[.home]) {
                Button("Open library detail") {
                    router.selectedTab = .library
                    router.navigate(to: .detail, in: .library)
                }
                .navigationDestination(for: AppDestination.self) { _ in
                    Text("Home detail")
                }
            }
            .tabItem { Label("Home", systemImage: "house") }
            .tag(AppTab.home)

            NavigationStack(path: $router[.library]) {
                Button("Show detail") { router.navigate(to: .detail) }
                    .navigationDestination(for: AppDestination.self) { _ in
                        Text("Library detail")
                    }
            }
            .tabItem { Label("Library", systemImage: "books.vertical") }
            .tag(AppTab.library)
        }
    }
}
```

Use `TabsView()` as the content of the main scene. Use a fixed tab subscript for
each stack; `selectedPath` instead resolves against whichever tab is selected at
access time. Missing paths read as empty, and assigning an empty path removes
its stored entry. Sheet and window properties belong to the shared router, so
switching tabs does not dismiss a presentation. Attach presentation modifiers to
the tab container when needed.

For a cross-tab action, select the target tab before pushing its destination, as
shown above. You can also prepare a tab's path before selecting it, or update its
path without selecting it at all. Waypoint applies these state changes
synchronously; statement order does not guarantee separate visible transitions.
The consuming app owns animation and transition sequencing.
