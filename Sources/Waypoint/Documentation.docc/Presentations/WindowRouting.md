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

For `.window(id:)`, the bridge observes changes to the request's UUID, consumes
the request by clearing the binding, and calls `openWindow(id:)`. It does not process an already pending request when first
attached. Keep it installed before issuing requests. Each call to `present`
creates a fresh UUID, even for repeated requests for the same route; pending
requests can be replaced before the bridge observes them.

For regular windows, the request retains the original route for inspection, but the bridge sends only
the scene identifier. Supply shared app state or an app-owned value-based scene
integration if the destination needs payload data. SwiftUI controls window
creation and reuse; Waypoint does not confirm that a window appeared or report
an error if it did not. A cleared request confirms consumption only. Clearing a
request or dismissing a sheet does not close an existing window.


## Open a detachable, sheet-like scene on iPad

Use `.prominentWindow(activityType:)` to request a **separate scene** with prominent
placement. On supported iPad windowing configurations, it initially appears above
the originating window and can be moved into its own window. This does not convert
an existing `.sheet` into a scene. The system chooses the final placement and
available gestures; do not assume identical presentation on every device or OS.

```swift
enum EditorRoute: PresentationRoute {
    case draft(UUID)

    var id: UUID {
        switch self { case .draft(let id): id }
    }
    var presentationStyle: RoutePresentationStyle {
        .prominentWindow(activityType: "com.example.app.editDraft")
    }
    @MainActor
    func configureWindowActivity(_ activity: NSUserActivity) {
        activity.title = "Edit draft"
        activity.targetContentIdentifier = id.uuidString
        activity.userInfo = ["draftID": id.uuidString]
    }
}
```

Call `router.present(.draft(draftID))` and install the same window presenter in
the originating view:

```swift
.routerWindowPresenter(request: $router.presentedWindow) { error in
    // Display or record the activation failure in your app.
    activationError = error.localizedDescription
}
```

The bridge obtains the requesting `UIWindowScene` from its own view, rather than
choosing an arbitrary connected scene. It creates an `NSUserActivity`, calls the
route's configuration hook, and requests a new scene with `options.placement =
.prominent()`. The router clears its ordinary sheet request as it does for other
window routes. Each request asks for a new scene; Waypoint does not deduplicate
existing editors by content identifier.

### Register and receive the activity

This path uses **UIKit scene configuration**, not `WindowGroup(id:)` lookup.
Merely declaring a SwiftUI window with the same string is insufficient. In your
app's scene integration:

1. Enable `UIApplicationSupportsMultipleScenes` in `UIApplicationSceneManifest`.
2. Include `com.example.app.editDraft` in the `NSUserActivityTypes` array.
3. In `application(_:configurationForConnecting:options:)`, recognize that
   activity type and return a configuration with your editor scene delegate.
4. In that delegate's `scene(_:willConnectTo:options:)`, decode the activity and
   create the editor's window. SwiftUI editor content can use `UIHostingController`.
5. Restore the editor from your persistent draft model. Persist its scene activity
   through `stateRestorationActivity(for:)` if you support scene restoration.

For example, the editor branch of an app delegate can return:

```swift
let configuration = UISceneConfiguration(name: "Draft editor", sessionRole: connectingSceneSession.role)
configuration.delegateClass = DraftSceneDelegate.self
return configuration
```

The scene delegate reads the activity from
`connectionOptions.userActivities.first ?? session.stateRestorationActivity`,
validates the `draftID`, and opens that draft. Provide an app-owned close button
that requests destruction of **this scene session**, rather than dismissing a
SwiftUI sheet. The app owns scene creation, restoration, draft storage, and close
behavior; Waypoint owns the originating routing request.

### Supply a window drag handle

On iOS, a dedicated grabber can opt into UIKit's window-scene dragging interaction:

```swift
Capsule()
    .fill(.secondary)
    .frame(width: 36, height: 5)
    .padding(12)
    .routerWindowDragHandle()
    .accessibilityLabel("Move editor window")
```

Place this inside the editor scene. Do not apply it across editable content or
buttons. Moving the window moves the same scene: the editor should retain its
model and state rather than recreate a draft. The modifier attaches
`UIWindowSceneDragInteraction`; it does not implement its own drag recognizer.

Prominent requests report `RouterWindowError` when multiple scenes are unavailable
or the presenter has no source scene, and forward UIKit activation errors to
`onError`. On macOS this UIKit presentation is unavailable; choose `.window(id:)`
in the route there. On iPhone or configurations without multiple scenes, choose
`.sheet` as your app's fallback before issuing the request. The default error
handler ignores errors, so install one when failure needs to be visible. Clearing
the request acknowledges consumption, not that a window appeared. It does not close
a scene or wait for an existing sheet's dismissal animation.

See Apple's [multiwindow sample](https://developer.apple.com/documentation/uikit/supporting-multiple-windows-on-ipad)
for scene registration and restoration, and
[window-scene placement](https://developer.apple.com/documentation/uikit/uiwindowsceneplacement-swift.protocol)
for system placement behavior.


### Test the regular iPhone fallback in Waypoint Lab

In the testing app, open **Home → Presentations → Detachable editor test** on a
regular iPhone. The scenario explicitly presents its editor as a sheet. Edit the
draft, choose Review draft to push through the editor's router, go Back, Close,
and reopen. The app-owned draft text should remain while the scenario is open.

After closing the sheet, choose **Verify unavailable-window error**. This action
deliberately issues a prominent-window request. Expect **Multiple windows
unavailable** from the presenter's error handler and **Pending request: None**.
Repeat the request, then verify that the fallback editor can still open.

This scenario verifies fallback navigation, app-owned draft retention, and the
prominent-window preflight error path. It does not verify receiving-scene content
delivery or detachment: those need a registered editor scene on a multiwindow
target. The testing app disables the error probe when multiple windows are
available because this scenario has no receiving editor scene.
