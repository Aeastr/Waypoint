# Present sheets and windows

Give semantic routes a presentation style and connect them to SwiftUI.

@Options {
    @TopicsVisualStyle(detailedGrid)
}

## Overview

Conform a route to ``Waypoint/PresentationRoute`` and supply its identity.
The default style is ``Waypoint/RoutePresentationStyle/sheet``. Bind your router's
`presentedSheet` to `sheet(item:)` and construct the sheet content in the closure.
`dismissSheet()` clears this route; user dismissal also updates the binding.

Calling `present` with a sheet route clears a pending window request. Calling it
with a window route clears the sheet route and creates a fresh window request.
These state changes do not close existing windows or establish that a new
presentation is visible. Direct assignment to either public property bypasses
this mutual-clearing behavior; use `present` when you need it.

Presentation calls are synchronous main-actor state changes. Waypoint does not
queue multiple requests, throw presentation errors, issue built-in warnings, or
provide completion callbacks. A later request can replace an earlier pending
request before SwiftUI processes it. The app decides which platform uses which
style and registers any required scenes. See <doc:WindowRouting> for scene setup
and the forwarding contract.

## Topics

### Define Presentation Routes

- ``Waypoint/PresentationRoute``
- ``Waypoint/RoutePresentationStyle``

### Open a Window

- <doc:WindowRouting>
- ``Waypoint/WindowPresentation``
- ``SwiftUI/View/routerWindowPresenter(request:)``
