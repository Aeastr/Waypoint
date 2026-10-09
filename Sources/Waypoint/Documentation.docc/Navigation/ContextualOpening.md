# Choose how a detail opens

Reuse an existing parent context, or open a detail directly or through its parent.

## Define the policy in the app

``ContextRouter`` is an opt-in stack and sheet router. Its named contexts describe
the parent pages the app actually displays, rather than individual lazy rows or
views that most recently appeared. Both opening policies push into an existing
matching context. They differ only when that context is absent:

| Policy | Missing Classes context | Existing Classes context |
| --- | --- | --- |
| `.direct(.classDetail(id))` | Class detail is the sheet's root, with no Classes page underneath | Push detail into the Classes stack |
| `.throughParent(.classes)` | Classes is the sheet's root, with class detail on its stack; Back returns to Classes | Push detail into the Classes stack |

```swift
enum AppContext: Hashable { case classes }
enum Destination: Hashable { case classDetail(Int) }
enum SheetRoute: Hashable, Identifiable {
    case classes, classDetail(Int)
    var id: Self { self }
}

typealias AppRouter = ContextRouter<AppContext, Destination, SheetRoute>
```

Own one root instance in app view state. Define one of these policies in the
app's route handler so callers only need to request a class:

```swift
@MainActor
func openClass(_ id: Int, using router: AppRouter) {
    router.open(
        .classDetail(id),
        in: .classes,
        ifNeeded: .throughParent(.classes)
    )
}
```

For direct presentation instead, replace the fallback with
`.direct(.classDetail(id))`. The app must supply a sheet route that constructs the
requested class; Waypoint cannot infer a view from the destination value.

To open the Classes list by itself, call
`router.present(.classes, context: .classes)`. If Classes is already the root of
an app-owned stack, initialize that stack's router with `context: .classes`.

## Connect each sheet's own stack

Bind a context router's `path` to its `NavigationStack`. Bind `presentedSheet` to
`sheet(item:)`. Each sheet receives its own router and root route:

```swift
@Bindable var router = router

NavigationStack(path: $router.path) {
    // Construct this context's root and register Destination detail views.
}
.sheet(item: $router.presentedSheet) { sheet in
    // Construct sheet.root using a host whose NavigationStack binds to
    // sheet.router.path. That host also binds sheet.router.presentedSheet
    // if it supports further sheets.
}
```

Keep the sheet router supplied by the presentation instead of creating a new one
inside `body`. Its path changes when an app-wide call opens another class.
Navigating within Classes preserves the owning `ContextSheet.id`, so opening
Class 2 from Class 1 does not replace or dismiss the Classes sheet. The existing
path becomes `[classDetail(1), classDetail(2)]`.

An app-wide overlay should call `openClass` using the same root instance. The
router searches the child-sheet chain for the deepest matching context. A sheet
control can call with its own child router to restrict resolution to that subtree.
If sheets cover the matching Classes context, those descendant requests are
cleared so its updated stack can become visible; the owning Classes sheet stays.
If no matching context exists, the fallback replaces the receiving router's sheet.

Interactive dismissal must clear the bound `presentedSheet`. A dismissed child
then stops participating in resolution, even if other code retains its router.
A direct class-detail sheet is unnamed: it does not pretend the absent Classes
parent is part of its navigation stack.

## Scope and transitions

This API manages one requested stack/sheet hierarchy. It does not discover window
focus, select tabs, or replace the existing `Router` and `TabRouter` APIs. An app
with multiple windows owns a coordinator per window and selects the receiving
instance for external actions. Separate-window presentation remains app-owned.

The parent policy initializes the parent context's path with the detail, giving
it the correct Back destination. It does not promise an animation that first
shows the parent and then pushes the detail. Likewise, clearing a covering sheet
and updating a path happens synchronously; the host owns visible transition
sequencing. Unit tests verify routing state, not SwiftUI presentation completion.
