import Observation

/// Coordinates a navigation stack and platform-adaptive presentation routes.
///
/// Own the router in SwiftUI state and bind ``path`` and ``presentedSheet`` to
/// their corresponding presentation modifiers. All access is main-actor isolated.
/// Routes remain in memory; the app supplies views and any persistence.
/// See <doc:GettingStarted> for integration.
@MainActor
@Observable
public final class Router<Destination: Hashable, Presentation: PresentationRoute> {
    /// The destinations above the stack's root, in presentation order.
    ///
    /// Bind this array to `NavigationStack(path:)` so interactive pops update it.
    public var path: [Destination]
    /// The route bound to `sheet(item:)`, or `nil` when no sheet is requested.
    ///
    /// SwiftUI can clear this binding when the user dismisses the sheet.
    public var presentedSheet: Presentation?
    /// The pending window request, consumed by the window presenter before dispatch.
    ///
    /// This is not a record of open windows. Setting it to `nil` does not close one.
    public var presentedWindow: WindowPresentation<Presentation>?

    /// Creates a router with an initial stack and no requested presentation.
    /// - Parameter path: Destinations above the root; defaults to an empty stack.
    public init(path: [Destination] = []) {
        self.path = path
    }

    /// Appends a destination to the navigation stack.
    /// - Parameter destination: The destination whose view the app will construct.
    public func navigate(to destination: Destination) { path.append(destination) }
    /// Replaces the complete stack above the root.
    /// - Parameter path: The new ordered destinations; an empty array returns to root.
    public func replacePath(with path: [Destination]) { self.path = path }

    /// Removes the last destination, if one exists.
    /// - Returns: The removed destination, or `nil` if the stack was empty.
    @discardableResult
    public func pop() -> Destination? { path.popLast() }

    /// Removes all destinations above the root without changing presentations.
    public func popToRoot() { path.removeAll() }

    /// Records a semantic route using its current presentation style.
    ///
    /// A sheet route clears any pending window request; a window route clears the
    /// sheet and creates a new request identity, even for the same route. Existing
    /// windows are not closed. Recording a request does not confirm presentation.
    /// - Parameter presentation: The route defining the style and any window ID.
    public func present(_ presentation: Presentation) {
        switch presentation.presentationStyle {
        case .sheet:
            presentedWindow = nil
            presentedSheet = presentation
        case .window(let id), .prominentWindow(let id):
            presentedSheet = nil
            presentedWindow = WindowPresentation(windowID: id, route: presentation)
        }
    }

    /// Clears the sheet route without changing pending or already opened windows.
    public func dismissSheet() { presentedSheet = nil }
}

/// Coordinates a selected tab, an independent stack per tab, and adaptive presentations.
///
/// Bind ``selectedTab`` to the app's tab selection and each tab's stack through
/// the subscript. Presentations are shared across tabs. All access is main-actor
/// isolated; the app owns views and persistence. See <doc:Navigation>.
@MainActor
@Observable
public final class TabRouter<Tab: Hashable, Destination: Hashable, Presentation: PresentationRoute> {
    /// The selected tab. Changing it preserves every tab's navigation stack.
    public var selectedTab: Tab
    /// The route bound to `sheet(item:)`, or `nil` when no sheet is requested.
    ///
    /// SwiftUI can clear this binding when the user dismisses the sheet.
    public var presentedSheet: Presentation?
    /// The pending window request, consumed by the window presenter before dispatch.
    ///
    /// This is not a record of open windows. Setting it to `nil` does not close one.
    public var presentedWindow: WindowPresentation<Presentation>?
    private var paths: [Tab: [Destination]]

    /// Creates a router with independent initial paths and no presentation.
    /// - Parameters:
    ///   - initialTab: The initially selected tab.
    ///   - paths: Initial destinations by tab; omitted tabs start at their root.
    public init(initialTab: Tab, paths: [Tab: [Destination]] = [:]) {
        self.selectedTab = initialTab
        self.paths = paths
    }

    /// Reads or replaces a tab's destinations without selecting that tab.
    ///
    /// A tab without a stored path returns an empty array. Assigning an empty
    /// array removes its stored path. Bind this subscript to the tab's stack.
    /// - Parameter tab: The tab whose stack is accessed.
    public subscript(tab: Tab) -> [Destination] {
        get { paths[tab, default: []] }
        set {
            if newValue.isEmpty { paths.removeValue(forKey: tab) }
            else { paths[tab] = newValue }
        }
    }

    /// The destinations of the currently selected tab.
    ///
    /// Reads and writes resolve against the selection at the time of access.
    public var selectedPath: [Destination] {
        get { self[selectedTab] }
        set { self[selectedTab] = newValue }
    }

    /// Appends a destination to a tab's stack without changing selection.
    /// - Parameters:
    ///   - destination: The destination whose view the app will construct.
    ///   - tab: The target tab, or `nil` to use the current selection.
    public func navigate(to destination: Destination, in tab: Tab? = nil) {
        paths[tab ?? selectedTab, default: []].append(destination)
    }

    /// Replaces a tab's stack without changing selection or presentations.
    /// - Parameters:
    ///   - path: The new destinations; an empty array returns that tab to root.
    ///   - tab: The target tab, or `nil` to use the current selection.
    public func replacePath(with path: [Destination], in tab: Tab? = nil) {
        self[tab ?? selectedTab] = path
    }

    /// Removes the last destination from a tab without changing selection.
    /// - Parameter tab: The target tab, or `nil` to use the current selection.
    /// - Returns: The removed destination, or `nil` when that stack is empty.
    @discardableResult
    public func pop(in tab: Tab? = nil) -> Destination? {
        let tab = tab ?? selectedTab
        guard var path = paths[tab], let destination = path.popLast() else { return nil }
        self[tab] = path
        return destination
    }

    /// Clears a tab's stack without changing selection or presentations.
    /// - Parameter tab: The target tab, or `nil` to use the current selection.
    public func popToRoot(in tab: Tab? = nil) { self[tab ?? selectedTab] = [] }

    /// Records a semantic route using its current presentation style.
    ///
    /// A sheet route clears any pending window request; a window route clears the
    /// sheet and creates a new request identity, even for the same route. Existing
    /// windows are not closed. Recording a request does not confirm presentation.
    /// - Parameter presentation: The route defining the style and any window ID.
    public func present(_ presentation: Presentation) {
        switch presentation.presentationStyle {
        case .sheet:
            presentedWindow = nil
            presentedSheet = presentation
        case .window(let id), .prominentWindow(let id):
            presentedSheet = nil
            presentedWindow = WindowPresentation(windowID: id, route: presentation)
        }
    }

    /// Clears the sheet route without changing pending or already opened windows.
    public func dismissSheet() { presentedSheet = nil }
}
