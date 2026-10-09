import Foundation
import Observation

/// How to open a destination when its named parent context is absent.
public enum ContextOpeningPolicy<Sheet: Identifiable> {
    /// Present the destination itself as the sheet's root.
    ///
    /// The supplied sheet value must describe that destination. This does not
    /// create the missing parent context or put a parent page below the detail.
    case direct(Sheet)

    /// Present the parent as the sheet's root and put the destination on its stack.
    ///
    /// Back returns to the parent page. The supplied sheet value describes the
    /// parent, while the destination passed to `open` describes its detail.
    case throughParent(Sheet)
}

/// A sheet and its independently owned navigation context.
@MainActor
public struct ContextSheet<Context: Hashable, Destination: Hashable, Sheet: Identifiable>: Identifiable {
    /// Stable while navigating inside this presentation; new for a replacement.
    public let id: UUID
    /// The root view the app should construct for this sheet.
    public let root: Sheet
    /// Bind this router's path to the sheet's own navigation stack.
    public let router: ContextRouter<Context, Destination, Sheet>

    fileprivate init(root: Sheet, router: ContextRouter<Context, Destination, Sheet>) {
        self.id = UUID()
        self.root = root
        self.router = router
    }
}

/// Routes into named contexts within one app-owned stack and sheet hierarchy.
///
/// An opt-in companion to `Router` and `TabRouter`. Call `open` on the same root
/// instance from app-wide controls or on a child instance from within a sheet.
/// Matching uses the requested sheet hierarchy, without view-appearance tracking.
/// This type owns sheet state only; separate windows and tab selection remain
/// app-owned. See <doc:ContextualOpening>.
@MainActor
@Observable
public final class ContextRouter<Context: Hashable, Destination: Hashable, Sheet: Identifiable> {
    /// The named parent page at this stack's root, if any.
    public let context: Context?
    /// Destinations above this stack's root. Bind to `NavigationStack(path:)`.
    public var path: [Destination]
    /// Bind to `sheet(item:)`; interactive dismissal clears this property.
    public var presentedSheet: ContextSheet<Context, Destination, Sheet>?

    /// Creates a context. An unnamed root cannot satisfy a named-parent request.
    public init(context: Context? = nil, path: [Destination] = []) {
        self.context = context
        self.path = path
    }

    /// Opens a detail in the deepest matching context, or applies the fallback.
    ///
    /// Both policies reuse an existing matching context, preserving its owning
    /// sheet identity and prior path. Any sheets above that context are cleared
    /// so the target stack can become visible. If no match exists, the fallback
    /// replaces this router's sheet. A direct fallback creates an unnamed stack;
    /// a parent fallback creates the named context with the detail on its path.
    ///
    /// State changes are synchronous. The app owns view construction, dismissal
    /// transitions, and animation sequencing; this does not confirm visible UI.
    /// - Returns: The router that received the destination or new sheet root.
    @discardableResult
    public func open(
        _ destination: Destination,
        in context: Context,
        ifNeeded policy: ContextOpeningPolicy<Sheet>
    ) -> ContextRouter<Context, Destination, Sheet> {
        if let existing = matchingContext(context) {
            existing.presentedSheet = nil
            existing.path.append(destination)
            return existing
        }

        switch policy {
        case .direct(let sheet):
            return present(sheet)
        case .throughParent(let sheet):
            let child = ContextRouter(context: context, path: [destination])
            presentedSheet = ContextSheet(root: sheet, router: child)
            return child
        }
    }

    /// Presents a new sheet context, replacing this router's existing sheet.
    /// - Returns: The child router owned by the new presentation.
    @discardableResult
    public func present(_ sheet: Sheet, context: Context? = nil) -> ContextRouter<Context, Destination, Sheet> {
        let child = ContextRouter(context: context)
        presentedSheet = ContextSheet(root: sheet, router: child)
        return child
    }

    /// Clears this router's sheet and the navigation hierarchy it owns.
    public func dismissSheet() {
        presentedSheet = nil
    }

    private func matchingContext(_ context: Context) -> ContextRouter<Context, Destination, Sheet>? {
        if let child = presentedSheet?.router.matchingContext(context) {
            return child
        }
        return self.context == context ? self : nil
    }
}
