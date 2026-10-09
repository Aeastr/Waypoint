# Route into SettingsKit

Select a settings tab with Waypoint and open a group with SettingsKit.

## Overview

Add both Waypoint and SettingsKit to the app target. Waypoint's generic destination
type can carry a `SettingsNavigationRequest`, so no package-level adapter is needed.
The app parses links or other actions, Waypoint selects the tab and stores the
request, and SettingsKit resolves the destination within its settings hierarchy.

## Carry a settings request

Define the app's routes and router:

```swift
import SwiftUI
import Waypoint
import SettingsKit

enum AppTab: Hashable { case home, settings }
enum AppDestination: Hashable {
    case settings(SettingsNavigationRequest)
}
enum AppPresentation: String, PresentationRoute {
    case help
    var id: String { rawValue }
}

typealias AppRouter = TabRouter<AppTab, AppDestination, AppPresentation>
```

From a button or an app-owned deep-link handler, create a fresh request and select
the settings tab. Use the unique, localized group titles from the root destination
to the requested page; inline sections are traversed automatically.

```swift
let request = SettingsNavigationRequest(groupTitles: ["General", "About"])
router.replacePath(with: [.settings(request)], in: .settings)
router.selectedTab = .settings
```

The titles above are examples: they must match the app's actual settings groups.
Create a fresh request for each action, including repeated visits to the same page.

## Hand off to the settings view

In the root view, own `router` in `@State` and bind `router.selectedTab` to the
`TabView` selection, as shown in <doc:TabNavigation>. Extract the pending request:

```swift
private var settingsNavigationRequest: SettingsNavigationRequest? {
    guard case .settings(let request)? = router[.settings].last else { return nil }
    return request
}
```

Use this content for the Settings tab, where `settings` is the app's
`SettingsContainer` and `settingsNavigationFailed` is a Boolean view state used to
show recovery UI:

```swift
SettingsView(
    container: settings,
    navigationRequest: settingsNavigationRequest
) { request, succeeded in
    guard router[.settings].last == .settings(request) else { return }
    router.popToRoot(in: .settings)
    settingsNavigationFailed = !succeeded
}
```

SettingsKit owns navigation inside this tab. Here the settings path stores a
one-shot handoff request; do not also bind that path to a `NavigationStack` around
`SettingsView`. Other tabs can continue binding their paths to their own stacks.

Consume the request on either success or failure so it does not remain pending.
The equality check prevents an older callback from clearing a newer request.
SettingsKit reports failure when a group title is missing or ambiguous; use the
result to show an app-appropriate message or recovery action. Clearing the Waypoint
path consumes the request; it does not reset SettingsKit's internal navigation.
