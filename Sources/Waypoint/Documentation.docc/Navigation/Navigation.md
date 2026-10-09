# Manage stacks and tabs

Push destinations, return to a root, and retain an independent stack for each tab.

@Options {
    @TopicsVisualStyle(detailedGrid)
}

## Overview

With a ``Waypoint/Router``, bind `path` to `NavigationStack(path:)` and register
`navigationDestination(for:)` for your destination type. Call `navigate(to:)` to
append one destination, `pop()` to remove the last destination, or `popToRoot()`
to clear the stack. `pop()` returns `nil` when the stack is empty.
`replacePath(with:)` replaces all destinations above the root.
These operations do not change presentation routes.

Use ``Waypoint/TabRouter`` when each tab needs its own history. Its subscript
reads and writes a particular tab's path independently of `selectedTab`.
Selecting a tab preserves all stored paths. Passing a tab to a navigation
operation updates that stack without switching selection; omit it to use the
current tab. See <doc:TabNavigation> for a complete view integration.

## Topics

### Route a Single Stack

- ``Waypoint/Router``

### Route Multiple Tabs

- <doc:TabNavigation>
- ``Waypoint/TabRouter``

### Integrate with SettingsKit

- <doc:SettingsKitIntegration>
