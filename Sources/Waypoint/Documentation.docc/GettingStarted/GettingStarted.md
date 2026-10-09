# Integrate with SwiftUI

Own a router and connect its state to your app's navigation and presentation views.

@Options {
    @TopicsVisualStyle(detailedGrid)
}

## Overview

Add the local Waypoint package and link its library product to your app target.
Import `SwiftUI` and `Waypoint` where you define your integration.

Choose a `Hashable` destination type and an `Identifiable` presentation type that
conforms to ``Waypoint/PresentationRoute``. Use stable identities for semantic
sheet routes. Presentation routes default to sheets; override their style only
when you need a different mechanism.

Own ``Waypoint/Router`` in a root view's `@State`. Create a local `@Bindable`
reference inside `body` to obtain bindings for `NavigationStack(path:)` and
`sheet(item:)`. The README contains a complete single-stack example.
Keep the owning view's identity stable to retain its router across body updates.
Pass that same router to child views that need to initiate navigation.

There is no periodic lifecycle work to run. SwiftUI updates the bindings when
users navigate back or dismiss a sheet. Install the window presenter before
issuing window requests, as described in <doc:WindowRouting>.

Router state is main-actor isolated and held in memory. For restoration, the app
must encode its own route representation, recover it, and supply initial paths
or replace the current paths. Waypoint provides no persistence or recovery store.

## Topics

### Own Routing State

- ``Waypoint/Router``
- ``Waypoint/PresentationRoute``

### Continue Integration

- <doc:Navigation>
- <doc:Presentations>
