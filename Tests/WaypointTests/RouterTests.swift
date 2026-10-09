import XCTest
@testable import Waypoint

@MainActor
final class RouterTests: XCTestCase {
    func testPresentationRouteChoosesSheetOrWindow() {
        let router = Router<Route, Presentation>()

        router.present(.editor)
        XCTAssertEqual(router.presentedSheet, .editor)

        router.present(.settings)
        XCTAssertNil(router.presentedSheet)
        XCTAssertEqual(router.presentedWindow?.windowID, "settings")
        XCTAssertEqual(router.presentedWindow?.route, .settings)
    }

    func testStackReplacementAndPoppingPreserveSheet() {
        let router = Router<Route, Presentation>()
        router.present(.editor)
        router.navigate(to: .detail)
        router.replacePath(with: [.detail, .detail])
        XCTAssertEqual(router.pop(), .detail)
        XCTAssertEqual(router.path, [.detail])
        router.popToRoot()
        XCTAssertTrue(router.path.isEmpty)
        XCTAssertNil(router.pop())
        XCTAssertEqual(router.presentedSheet, .editor)
    }

    func testTabNavigationPreservesSelectionAndIndependentPaths() {
        let router = TabRouter<Tab, Route, Presentation>(initialTab: .home)
        router.navigate(to: .detail)
        router.replacePath(with: [.detail, .detail], in: .library)
        XCTAssertEqual(router.selectedTab, .home)
        XCTAssertEqual(router[.home], [.detail])
        XCTAssertEqual(router[.library], [.detail, .detail])

        router.selectedTab = .library
        XCTAssertEqual(router.selectedPath, [.detail, .detail])
        XCTAssertEqual(router.pop(), .detail)
        router.popToRoot(in: .home)
        XCTAssertEqual(router.selectedTab, .library)
        XCTAssertTrue(router[.home].isEmpty)
        XCTAssertEqual(router[.library], [.detail])
        router.selectedPath = []
        XCTAssertNil(router.pop())
    }

    func testTabRouterPresentationReplacementDoesNotChangePaths() {
        let router = TabRouter<Tab, Route, Presentation>(
            initialTab: .home, paths: [.home: [.detail]]
        )
        router.present(.editor)
        XCTAssertEqual(router.presentedSheet, .editor)
        router.present(.settings)
        XCTAssertNil(router.presentedSheet)
        XCTAssertEqual(router.presentedWindow?.windowID, "settings")
        let firstRequestID = router.presentedWindow?.id
        router.present(.settings)
        XCTAssertNotEqual(router.presentedWindow?.id, firstRequestID)
        router.dismissSheet()
        XCTAssertNotNil(router.presentedWindow)
        router.present(.editor)
        XCTAssertNil(router.presentedWindow)
        XCTAssertEqual(router.presentedSheet, .editor)
        router.dismissSheet()
        XCTAssertNil(router.presentedSheet)
        XCTAssertEqual(router[.home], [.detail])
        XCTAssertEqual(router.selectedTab, .home)
    }

    func testRouterRepeatedWindowRequestsAndSheetReplacement() {
        let router = Router<Route, Presentation>()
        router.present(.settings)
        let firstRequestID = router.presentedWindow?.id
        router.present(.settings)
        XCTAssertNotEqual(router.presentedWindow?.id, firstRequestID)
        router.dismissSheet()
        XCTAssertNotNil(router.presentedWindow)
        router.present(.editor)
        XCTAssertNil(router.presentedWindow)
        XCTAssertEqual(router.presentedSheet, .editor)
        router.dismissSheet()
        XCTAssertNil(router.presentedSheet)
    }
}

private enum Tab: Hashable { case home, library }
private enum Route: Hashable { case detail }

private enum Presentation: String, PresentationRoute {
    case editor
    case settings

    var id: String { rawValue }
    var presentationStyle: RoutePresentationStyle {
        self == .settings ? .window(id: "settings") : .sheet
    }
}
