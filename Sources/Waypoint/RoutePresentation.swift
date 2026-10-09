import SwiftUI
#if os(iOS)
import UIKit
#endif

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

    /// Request a separate scene, initially placed prominently above its source.
    ///
    /// The app must register this user activity type and configure the receiving
    /// UIKit scene. This is not a SwiftUI `WindowGroup` identifier. On supported
    /// iPad configurations, the scene can be dragged into an independent window.
    case prominentWindow(activityType: String)
}

/// A semantic route that decides how it should be presented on the current platform.
public protocol PresentationRoute: Identifiable {
    /// The presentation mechanism to use when a router receives this route.
    ///
    /// The default is ``RoutePresentationStyle/sheet``. Implement this property
    /// to choose a window identifier or adapt to the current platform. The inherited
    /// `Identifiable` identity is used by SwiftUI's item-based sheet presentation.
    var presentationStyle: RoutePresentationStyle { get }

    /// Adds content identifiers or restoration data to a prominent scene request.
    /// The app receives this activity in its scene connection options.
    @MainActor func configureWindowActivity(_ activity: NSUserActivity)
}

public extension PresentationRoute {
    /// Routes are sheets unless an app opts into another presentation style.
    var presentationStyle: RoutePresentationStyle { .sheet }

    /// The default activity carries no app-specific payload.
    @MainActor func configureWindowActivity(_ activity: NSUserActivity) {}
}

/// A request waiting to be forwarded to the platform scene system.
public struct WindowPresentation<Route: PresentationRoute>: Identifiable {
    /// A fresh identity for each request, including repeated requests for one route.
    public let id: UUID
    /// The destination identifier: a SwiftUI scene ID for `.window`, or a user
    /// activity type for `.prominentWindow`.
    /// See ``presentationStyle`` to distinguish them.
    public let windowID: String
    /// The mechanism used to activate the destination scene.
    public let presentationStyle: RoutePresentationStyle
    /// The original route, retained for the app to inspect before forwarding.
    ///
    /// Regular windows forward only their ID. Prominent windows use
    /// `configureWindowActivity(_:)` to encode app-owned scene content.
    public let route: Route

    init(windowID: String, route: Route) {
        self.id = UUID()
        self.presentationStyle = route.presentationStyle
        self.windowID = windowID
        self.route = route
    }
}

private struct RouterWindowPresenter<Route: PresentationRoute>: ViewModifier {
    @Binding var request: WindowPresentation<Route>?
    @Environment(\.openWindow) private var openWindow
    var onError: (Error) -> Void
    #if os(iOS)
    @State private var anchor = UIView(frame: .zero)
    #endif

    func body(content: Content) -> some View {
        content
            #if os(iOS)
            .background(WindowSceneAnchor(view: anchor).allowsHitTesting(false))
            #endif
            .onChange(of: request?.id) { _, _ in
                guard let request else { return }
                self.request = nil
                switch request.presentationStyle {
                case .window:
                    openWindow(id: request.windowID)
                case .prominentWindow(let activityType):
                    #if os(iOS)
                    guard UIApplication.shared.supportsMultipleScenes else {
                        onError(RouterWindowError.multipleWindowsUnavailable)
                        return
                    }
                    guard let scene = anchor.window?.windowScene else {
                        onError(RouterWindowError.sourceSceneUnavailable)
                        return
                    }
                    let activity = NSUserActivity(activityType: activityType)
                    request.route.configureWindowActivity(activity)
                    let options = UIWindowScene.ActivationRequestOptions()
                    options.requestingScene = scene
                    options.placement = .prominent()
                    UIApplication.shared.requestSceneSessionActivation(
                        nil, userActivity: activity, options: options,
                        errorHandler: onError
                    )
                    #else
                    onError(RouterWindowError.multipleWindowsUnavailable)
                    #endif
                case .sheet:
                    break
                }
            }
    }
}

public extension View {
    /// Forwards subsequent window requests to SwiftUI or UIKit scene activation.
    ///
    /// Install before requesting a window; pending requests on attachment are not
    /// processed. Regular windows forward only their ID to `openWindow(id:)`.
    /// Prominent windows encode an activity using the route's configuration hook
    /// and request a separate UIKit scene. The binding clears before dispatch;
    /// this does not confirm visibility or close an opened scene.
    /// See <doc:WindowRouting> for required app-owned scene integration.
    /// - Parameters:
    ///   - request: The router's pending window request binding.
    ///   - onError: Prominent-scene preflight or UIKit activation errors. Regular
    ///     SwiftUI window activation does not supply error callbacks.
    func routerWindowPresenter<Route: PresentationRoute>(
        request: Binding<WindowPresentation<Route>?>,
        onError: @escaping (Error) -> Void = { _ in }
    ) -> some View {
        modifier(RouterWindowPresenter(request: request, onError: onError))
    }
}

/// Errors detected before a prominent window request reaches UIKit.
public enum RouterWindowError: Error, Equatable {
    /// The current platform or app configuration cannot open multiple scenes.
    case multipleWindowsUnavailable
    /// The presenter is not attached to an originating window scene.
    case sourceSceneUnavailable
}

#if os(iOS)
private struct WindowSceneAnchor: UIViewRepresentable {
    let view: UIView
    func makeUIView(context: Context) -> UIView { view }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

private struct WindowSceneDragSurface: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.addInteraction(UIWindowSceneDragInteraction())
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

public extension View {
    /// Makes this view a system drag surface for its containing window scene.
    ///
    /// Apply to a dedicated visible grabber in a prominent scene, rather than
    /// the whole editor or a button. UIKit owns dragging and window placement.
    /// This does not turn a SwiftUI sheet into a separate scene.
    func routerWindowDragHandle() -> some View {
        overlay(WindowSceneDragSurface())
    }
}
#endif
