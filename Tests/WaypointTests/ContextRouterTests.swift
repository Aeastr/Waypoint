import XCTest
@testable import Waypoint

@MainActor
final class ContextRouterTests: XCTestCase {
    private typealias TestRouter = ContextRouter<Context, Destination, Sheet>

    func testDirectFallbackPresentsDetailWithoutInventingParent() {
        let root = TestRouter(path: [.classDetail(99)])
        let child = root.open(.classDetail(2), in: .classes, ifNeeded: .direct(.classDetail(2)))

        XCTAssertEqual(root.presentedSheet?.root, .classDetail(2))
        XCTAssertTrue(root.presentedSheet?.router === child)
        XCTAssertNil(child.context)
        XCTAssertTrue(child.path.isEmpty)
        XCTAssertEqual(root.path, [.classDetail(99)])
    }

    func testParentFallbackProvidesClassesAsBackDestination() {
        let root = TestRouter()
        let child = root.open(.classDetail(2), in: .classes, ifNeeded: .throughParent(.classes))

        XCTAssertEqual(root.presentedSheet?.root, .classes)
        XCTAssertEqual(child.context, .classes)
        XCTAssertEqual(child.path, [.classDetail(2)])
        XCTAssertEqual(child.path.popLast(), .classDetail(2))
        XCTAssertTrue(child.path.isEmpty)
        XCTAssertEqual(root.presentedSheet?.root, .classes)
    }

    func testBothPoliciesReuseExistingClassesSheetWithoutChangingItsIdentity() {
        for policy in [ContextOpeningPolicy<Sheet>.direct(.classDetail(2)), .throughParent(.classes)] {
            let root = TestRouter()
            let classes = root.present(.classes, context: .classes)
            classes.path = [.classDetail(1)]
            let sheetID = root.presentedSheet?.id

            let destination = root.open(.classDetail(2), in: .classes, ifNeeded: policy)

            XCTAssertTrue(destination === classes)
            XCTAssertEqual(root.presentedSheet?.id, sheetID)
            XCTAssertEqual(root.presentedSheet?.root, .classes)
            XCTAssertEqual(classes.path, [.classDetail(1), .classDetail(2)])
        }
    }

    func testClassesAtAppRootReceivesPushWithoutPresentingSheet() {
        let root = TestRouter(context: .classes)
        root.open(.classDetail(2), in: .classes, ifNeeded: .direct(.classDetail(2)))

        XCTAssertEqual(root.path, [.classDetail(2)])
        XCTAssertNil(root.presentedSheet)
    }

    func testDeepestMatchingContextReceivesPush() {
        let root = TestRouter(context: .classes)
        let child = root.present(.classes, context: .classes)
        root.open(.classDetail(2), in: .classes, ifNeeded: .throughParent(.classes))

        XCTAssertTrue(root.path.isEmpty)
        XCTAssertEqual(child.path, [.classDetail(2)])
    }

    func testRoutingToClassesDismissesOnlyItsDescendantSheets() {
        let root = TestRouter()
        let classes = root.present(.classes, context: .classes)
        classes.present(.inspector)
        let sheetID = root.presentedSheet?.id

        root.open(.classDetail(2), in: .classes, ifNeeded: .throughParent(.classes))

        XCTAssertEqual(root.presentedSheet?.id, sheetID)
        XCTAssertNil(classes.presentedSheet)
        XCTAssertEqual(classes.path, [.classDetail(2)])
    }

    func testUnrelatedSheetIsReplacedWhenParentIsAbsent() {
        let root = TestRouter()
        root.present(.inspector)
        let previousID = root.presentedSheet?.id
        root.open(.classDetail(2), in: .classes, ifNeeded: .throughParent(.classes))

        XCTAssertNotEqual(root.presentedSheet?.id, previousID)
        XCTAssertEqual(root.presentedSheet?.root, .classes)
        XCTAssertEqual(root.presentedSheet?.router.path, [.classDetail(2)])
    }

    func testDismissalRemovesParentContextFromFutureResolution() {
        let root = TestRouter()
        let oldClasses = root.present(.classes, context: .classes)
        root.dismissSheet()
        let newClasses = root.open(.classDetail(2), in: .classes, ifNeeded: .throughParent(.classes))

        XCTAssertFalse(oldClasses === newClasses)
        XCTAssertTrue(oldClasses.path.isEmpty)
        XCTAssertEqual(newClasses.path, [.classDetail(2)])
    }

    func testCallInsideClassesContextUsesItsOwnStack() {
        let root = TestRouter()
        let classes = root.present(.classes, context: .classes)
        classes.open(.classDetail(2), in: .classes, ifNeeded: .direct(.classDetail(2)))

        XCTAssertEqual(classes.path, [.classDetail(2)])
        XCTAssertNil(classes.presentedSheet)
        XCTAssertEqual(root.presentedSheet?.root, .classes)
    }
}

private enum Context: Hashable { case classes }
private enum Destination: Hashable { case classDetail(Int) }
private enum Sheet: Hashable, Identifiable {
    case classes, classDetail(Int), inspector
    var id: Self { self }
}
