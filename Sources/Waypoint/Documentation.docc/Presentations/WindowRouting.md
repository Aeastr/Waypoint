# Route to a registered window

Forward a semantic route to an app-owned SwiftUI scene by identifier.

## Overview

This macOS example registers a settings window, keeps a router in the main view,
and installs the bridge before the button can issue a request. In an existing
app, merge the scene and view into your existing app entry point.

```swift
import SwiftUI
import Waypoint

enum WindowDestination: Hashable { case detail }
enum WindowRoute: String, PresentationRoute {
    case settings
    var id: String { rawValue }

    var presentationStyle: RoutePresentationStyle {
        #if os(macOS)
        .window(id: "settings")
        #else
        .sheet
        #endif
    }
}

#if os(macOS)
@main
struct WindowExampleApp: App {
    var body: some Scene {
        WindowGroup { WindowRootView() }
        WindowGroup(id: "settings") { Text("Settings") }
    }
}
#endif

@MainActor
struct WindowRootView: View {
    @State private var router = Router<WindowDestination, WindowRoute>()

    var body: some View {
        @Bindable var router = router

        Button("Settings") { router.present(.settings) }
            .sheet(item: $router.presentedSheet) { _ in Text("Settings") }
            .routerWindowPresenter(request: $router.presentedWindow)
    }
}
```

The registered ID must exactly match the route's window ID. Choose `.sheet` on
platforms where your app does not provide the requested window experience.

The bridge observes changes to the request's UUID, calls `openWindow(id:)`, then
clears the binding. It does not process an already pending request when first
attached. Keep it installed before issuing requests. Each call to `present`
creates a fresh UUID, even for repeated requests for the same route; pending
requests can be replaced before the bridge observes them.

The request retains the original route for inspection, but the bridge sends only
the scene identifier. Supply shared app state or an app-owned value-based scene
integration if the destination needs payload data. SwiftUI controls window
creation and reuse; Waypoint does not confirm that a window appeared or report
an error if it did not. A cleared request confirms forwarding only. Clearing a
request or dismissing a sheet does not close an existing window.
