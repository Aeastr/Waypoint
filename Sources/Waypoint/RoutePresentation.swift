import SwiftUI

/// The platform presentation mechanism for a semantic presentation route.
public enum RoutePresentationStyle: Equatable, Sendable {
    /// Present the route in the current scene as a sheet.
    case sheet

    /// Request the scene registered with `WindowGroup(id:)`.
    ///
    /// The bridge forwards only this identifier, not the route payload. The app
    /// must register the scene and select this style on platforms that support it.
    /// - Parameter id: The exact identifier registered by the app's scene.
    case window(id: String)
}

/// A semantic route that decides how it should be presented on the current platform.
public protocol PresentationRoute: Identifiable {
    /// The presentation mechanism to use when a router receives this route.
    ///
    /// The default is ``RoutePresentationStyle/sheet``. Implement this property
    /// to choose a window identifier or adapt to the current platform. The inherited
    /// `Identifiable` identity is used by SwiftUI's item-based sheet presentation.
    var presentationStyle: RoutePresentationStyle { get }
}

public extension PresentationRoute {
    /// Routes are sheets unless an app opts into another presentation style.
    var presentationStyle: RoutePresentationStyle { .sheet }
}

/// A request waiting to be forwarded to SwiftUI's `openWindow` action.
public struct WindowPresentation<Route: PresentationRoute>: Identifiable {
    /// A fresh identity for each request, including repeated requests for one route.
    public let id: UUID
    /// The app-registered scene identifier forwarded to `openWindow(id:)`.
    public let windowID: String
    /// The original route, retained for the app to inspect before forwarding.
    ///
    /// The built-in bridge does not send this value to the destination scene.
    public let route: Route

    init(windowID: String, route: Route) {
        self.id = UUID()
        self.windowID = windowID
        self.route = route
    }
}

private struct RouterWindowPresenter<Route: PresentationRoute>: ViewModifier {
    @Binding var request: WindowPresentation<Route>?
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.onChange(of: request?.id) { _, _ in
            guard let request else { return }
            openWindow(id: request.windowID)
            self.request = nil
        }
    }
}

public extension View {
    /// Forwards subsequent window request changes to SwiftUI's `openWindow` action.
    ///
    /// Install this modifier before requesting a window. It observes request
    /// identity changes without processing an already pending request on attachment.
    /// After calling `openWindow(id:)`, it clears the binding. This acknowledges
    /// forwarding only; no success result, error, or callback confirms a visible
    /// window. The route payload is not forwarded, and clearing the binding does
    /// not close an opened window. See <doc:WindowRouting>.
    /// - Parameter request: The router's pending window request binding.
    /// - Returns: A view that forwards new window requests while installed.
    func routerWindowPresenter<Route: PresentationRoute>(
        request: Binding<WindowPresentation<Route>?>
    ) -> some View {
        modifier(RouterWindowPresenter(request: request))
    }
}
