import XCTest

/// Runs the demo's documented flows with actual UI events and observable-state checks.
@MainActor
final class RecordingFlows: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "world.aethers.WaypointDemo")
    private var events: URL?
    private var flow = ""
    private var recording = false
    private let holdSeconds = 0.7
    private enum FlowError: Error { case failed(String) }

    private func log(_ kind: String, _ detail: String = "") {
        guard let events else { return }
        let object: [String: Any] = ["flow": flow, "kind": kind, "detail": detail,
            "uptime": ProcessInfo.processInfo.systemUptime, "time": Date().timeIntervalSince1970]
        guard let data = try? JSONSerialization.data(withJSONObject: object) else { return }
        if !FileManager.default.fileExists(atPath: events.path) { FileManager.default.createFile(atPath: events.path, contents: nil) }
        if let handle = try? FileHandle(forWritingTo: events) {
            handle.seekToEndOfFile(); handle.write(data); handle.write(Data([10])); try? handle.close()
        }
    }

    private func fail(_ message: String, file: StaticString = #filePath, line: UInt = #line) throws -> Never {
        XCTFail(message, file: file, line: line)
        throw FlowError.failed(message)
    }

    private func run(_ name: String, actions: () throws -> Void) throws {
        continueAfterFailure = true
        flow = name
        let environment = ProcessInfo.processInfo.environment
        recording = environment["WAYPOINT_CAPTURE"] == "1"
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WaypointCapture/" + (environment["WAYPOINT_RUN_ID"] ?? "checks"))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        events = folder.appendingPathComponent(name + ".jsonl")
        app.terminate(); app.launch()
        try expect("Waypoint · Home")
        log("ready")
        if recording {
            let ack = folder.appendingPathComponent(name + ".capture-started")
            let deadline = Date().addingTimeInterval(40)
            while !FileManager.default.fileExists(atPath: ack.path) {
                guard Date() < deadline else { try fail("Capture acknowledgement timed out") }
                Thread.sleep(forTimeInterval: 0.05)
            }
        }
        log("flow-start")
        do {
            try actions()
            if recording { Thread.sleep(forTimeInterval: 1.2) }
            log("passed")
        } catch {
            log("failed", String(describing: error))
            let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.lifetime = .keepAlways; add(screenshot)
            let hierarchy = XCTAttachment(string: app.debugDescription); hierarchy.lifetime = .keepAlways; add(hierarchy)
            try? app.debugDescription.write(to: folder.appendingPathComponent(name + ".failure.txt"), atomically: true, encoding: .utf8)
            throw error
        }
    }

    private func visible(_ query: XCUIElementQuery) -> XCUIElement? {
        query.allElementsBoundByIndex.last { $0.isHittable }
    }

    private func query(_ key: String) -> XCUIElementQuery {
        let predicate = NSPredicate(format: "identifier == %@ OR label == %@", key, key)
        if key == "classes-sheet-state" || key.hasPrefix("state.") || key == "root.lastAction" || ["windowLab.result", "windowLab.pending"].contains(key) {
            return app.staticTexts.matching(predicate)
        }
        return app.buttons.matching(predicate)
    }

    private func element(_ key: String, scroll: Bool = true) throws -> XCUIElement {
        let panelControl = key.hasPrefix("root.") || key == "classes-sheet-state" || key.hasSuffix(".close") || key == "windowLab.closeEditor" || ["baseline.classes", "baseline.inspector", "baseline.utility", "Home", "Library"].contains(key)
        for attempt in 0...7 {
            let matches = query(key).allElementsBoundByIndex
            if panelControl, let value = matches.last(where: { $0.isHittable }) { return value }
            let top = app.navigationBars.allElementsBoundByIndex.last?.frame.maxY ?? 0
            let panel = visible(app.buttons.matching(identifier: "root.collapse"))
            let bottom = panel.map { $0.frame.minY - 26 } ?? app.frame.maxY
            if let value = matches.last(where: {
                let frame = $0.frame
                return frame.midY >= top && frame.midY <= bottom && frame.height > 0 && $0.isHittable
            }) { return value }
            guard scroll && attempt < 7, let container = visible(app.collectionViews) ?? visible(app.tables) ?? visible(app.scrollViews) else { break }
            log("scroll", key)
            if let candidate = matches.first, candidate.frame.minY < top {
                container.swipeDown(velocity: .slow)
            } else { container.swipeUp(velocity: .slow) }
        }
        try fail("Visible control not found: \(key)")
    }

    private func tap(_ key: String, scroll: Bool = true) throws {
        let control = try element(key, scroll: scroll)
        log("tap", key); control.tap()
        if recording { Thread.sleep(forTimeInterval: holdSeconds) }
    }

    private func expect(_ text: String, timeout: TimeInterval = 5) throws {
        let matches = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@ OR value == %@ OR label ENDSWITH %@ OR label BEGINSWITH %@", text, text, ", " + text, text + ", "))
        let predicate = NSPredicate { _, _ in !matches.allElementsBoundByIndex.filter { $0.isHittable }.isEmpty }
        guard XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: timeout) == .completed else {
            try fail("Expected screen content: \(text)")
        }
        log("checked", text)
    }

    private func state(_ id: String, contains text: String) throws {
        if query(id).count == 0 {
            if id.hasPrefix("state."), let collapse = visible(app.buttons.matching(identifier: "root.collapse")), collapse.label == "Collapse root controls" {
                log("tap", "root.collapse"); collapse.tap()
                if recording { Thread.sleep(forTimeInterval: holdSeconds) }
            }
            _ = try element(id)
        }
        let values = query(id).allElementsBoundByIndex
        guard values.contains(where: { ($0.label + " " + String(describing: $0.value ?? "")).contains(text) }) else {
            try fail("\(id) expected \(text), got \(values.map { $0.label })")
        }
        log("checked", id + " = " + text)
    }

    private func back() throws {
        let bars = app.navigationBars.allElementsBoundByIndex.filter { $0.exists && $0.isHittable }
        guard let button = bars.reversed().compactMap({ bar in
            bar.buttons.allElementsBoundByIndex.first { $0.isHittable && ($0.identifier == "BackButton" || $0.label == "Back" || $0.label == "Classes" || $0.label == "Editor · sheet fallback" || $0.label.hasPrefix("Detail ") || $0.label.hasPrefix("Waypoint")) }
        }).first else { try fail("Navigation Back button not found") }
        log("tap", "system Back"); button.tap()
        if recording { Thread.sleep(forTimeInterval: holdSeconds) }
    }

    private func screen(_ title: String) throws {
        let bar = app.navigationBars[title]
        guard bar.waitForExistence(timeout: 5), bar.isHittable else { try fail("Expected active navigation screen: \(title)") }
        log("checked", "screen " + title)
    }
    private func listed(_ key: String) throws {
        _ = try element(key, scroll: false); log("checked", key)
        if recording { Thread.sleep(forTimeInterval: holdSeconds) }
    }
    private func local() throws { try tap("baseline.open"); try expect("Classes") }
    private func contextual() throws { try tap("Open Classes sheet"); try state("classes-sheet-state", contains: "Depth 0") }
    private func identity() throws -> String {
        let value = try element("classes-sheet-state", scroll: false).label
        guard let depth = value.range(of: " · Depth") else { try fail("Missing context identity") }
        return String(value[..<depth.lowerBound])
    }
    private func same(_ id: String, depth: Int) throws {
        try state("classes-sheet-state", contains: id + " · Depth \(depth)")
    }
    private func picker(_ id: String, _ option: String) throws {
        try tap(id, scroll: false)
        guard let item = visible(app.menuItems.matching(NSPredicate(format: "label == %@", option))) ?? visible(app.buttons.matching(NSPredicate(format: "label == %@", option))) else { try fail("Picker option missing: \(option)") }
        log("tap", "picker " + option); item.tap()
        if recording { Thread.sleep(forTimeInterval: holdSeconds) }
        try state(id, contains: option)
    }

    func testB01() throws { try run("B01") {
        try tap("Push detail"); try expect("Home detail 1")
        try tap("Push another detail"); try expect("Home detail 2")
        try back(); try state("state.home", contains: "Detail 1")
        try tap("Return to root"); try expect("Waypoint · Home"); try state("state.home", contains: "Root")
    } }
    func testB02() throws { try run("B02") {
        try tap("Switch to Library, then push"); try expect("Library detail 1")
        try state("state.tab", contains: "Library"); try state("state.home", contains: "Root")
    } }
    func testB03() throws { try run("B03") {
        try tap("Push detail"); try expect("Home detail 1"); try tap("Library", scroll: false)
        try tap("Push detail"); try tap("Push another detail"); try expect("Library detail 2")
        try tap("Home", scroll: false); try expect("Home detail 1")
        try state("state.library", contains: "Detail 1 → Detail 2")
        try tap("Library", scroll: false); try expect("Library detail 2")
    } }
    func testB04() throws { try run("B04") {
        try tap("Prepare Library without switching"); try expect("Waypoint · Home")
        try tap("Library", scroll: false); try expect("Library detail 2"); try back(); try expect("Library detail 1")
        try tap("Home", scroll: false); try tap("Clear Library history")
        try tap("Library", scroll: false); try expect("Waypoint · Library"); try state("state.library", contains: "Root")
    } }
    func testB05() throws { try run("B05") {
        try tap("Push detail"); try contextual(); try tap("context.close", scroll: false)
        try expect("Home detail 1"); try state("state.home", contains: "Detail 1")
    } }
    func testB06() throws { try run("B06") {
        try local(); try tap("baseline.inspector", scroll: false); try expect("inspector"); try screen("Inspector")
        try tap("baseline.classes", scroll: false); try expect("Class 1")
        try tap("baseline.close", scroll: false); try expect("Waypoint · Home")
    } }
    func testB07() throws { try run("B07") {
        try local(); try tap("baseline.class.3"); try expect("Class 3 detail")
        try tap("baseline.inspector", scroll: false); try expect("inspector"); try screen("Inspector")
        try tap("baseline.classes", scroll: false); try listed("baseline.class.1")
        try tap("baseline.close", scroll: false); try expect("Waypoint · Home")
    } }
    func testB08() throws { try run("B08") {
        try local(); try tap("baseline.class.3"); try expect("Class 3 detail")
        try back(); try tap("baseline.class.3"); try expect("Class 3 detail")
        try tap("baseline.close", scroll: false); try expect("Waypoint · Home")
    } }
    func testB09() throws { try run("B09") {
        try local(); try tap("baseline.class.3"); try expect("Class 3 detail")
        try tap("baseline.close", scroll: false); try local(); try listed("baseline.class.1")
        try tap("baseline.close", scroll: false); try expect("Waypoint · Home")
    } }
    func testB10() throws { try run("B10") {
        try local(); try tap("baseline.class.3"); try expect("Class 3 detail")
        try tap("baseline.utility", scroll: false); try screen("Utility")
        try tap("baseline.close", scroll: false); try expect("Waypoint · Home")
    } }
    func testC01() throws { try run("C01") {
        try contextual(); let id = try identity(); try tap("context.class.3"); try expect("Stack depth")
        try same(id, depth: 1); try screen("Class 3"); try back(); try same(id, depth: 0); try tap("context.close", scroll: false)
    } }
    func testC02() throws { try run("C02") {
        try tap("root.open", scroll: false); try expect("Root opened Class 3 · Through Classes")
        try state("classes-sheet-state", contains: "Depth 1"); try screen("Class 3"); try back(); try state("classes-sheet-state", contains: "Depth 0")
        try listed("context.class.1")
    } }
    func testC03() throws { try run("C03") {
        try picker("root.fallback", "Direct detail"); try tap("root.open", scroll: false)
        try expect("Root opened Class 3 · Direct detail"); try screen("Class 3"); try state("classes-sheet-state", contains: "Depth 0")
        guard !app.buttons["BackButton"].exists else { try fail("Direct detail unexpectedly has a parent") }
        try tap("context.close", scroll: false); try expect("Waypoint · Home")
    } }
    func testC04() throws { try run("C04") {
        try contextual(); let id = try identity(); try tap("root.open", scroll: false); try same(id, depth: 1)
        try picker("root.class", "Class 4"); try tap("root.open", scroll: false)
        try same(id, depth: 2); try screen("Class 4")
    } }
    func testC05() throws { try run("C05") {
        try contextual(); let id = try identity(); try tap("context.class.3"); try same(id, depth: 1)
        try tap("Present child sheet"); try expect("Child Inspector")
        try tap("context.close", scroll: false); try same(id, depth: 1); try screen("Class 3")
        try tap("context.close", scroll: false); try expect("Waypoint · Home")
    } }
    func testC06() throws { try run("C06") {
        try contextual(); try tap("context.class.3"); try tap("root.override", scroll: false)
        try expect("Library detail 99"); try state("state.tab", contains: "Library")
        try state("state.home", contains: "Root"); try state("state.library", contains: "Detail 99")
    } }
    func testW04() throws { try run("W04") {
        try tap("Detachable editor test"); try tap("root.collapse", scroll: false)
        try expect("Unavailable"); try expect("Sheet fallback"); try tap("windowLab.openEditor")
        let field = app.textViews.firstMatch.exists ? app.textViews.firstMatch : app.textFields.firstMatch
        guard field.waitForExistence(timeout: 5) else { try fail("Draft text input missing") }
        field.tap(); field.press(forDuration: 1)
        for _ in 0..<3 {
            if app.menuItems["Select All"].exists { break }
            if app.buttons["Previous Page"].isHittable { app.buttons["Previous Page"].tap() }
            else { break }
        }
        let selectAll = app.menuItems["Select All"]
        guard selectAll.waitForExistence(timeout: 3) else { try fail("Text selection menu missing Select All") }
        selectAll.tap(); field.typeText("iPhone routing check")
        log("typed", "iPhone routing check"); try tap("windowLab.review")
        try screen("Review draft"); try expect("iphone-test-draft"); try expect("iPhone routing check"); try back(); try expect("iPhone routing check")
        try tap("windowLab.closeEditor", scroll: false); try tap("windowLab.openEditor")
        try expect("iPhone routing check"); try tap("windowLab.closeEditor", scroll: false)
        try tap("windowLab.probe"); try expect("Multiple windows unavailable"); try state("windowLab.pending", contains: "None")
        try tap("windowLab.probe"); try expect("Multiple windows unavailable")
        try tap("windowLab.openEditor"); try expect("iPhone routing check")
        try tap("windowLab.closeEditor", scroll: false); try expect("Multiple windows unavailable"); try state("windowLab.pending", contains: "None")
    } }
    func testFailureProbe() throws {
        guard ProcessInfo.processInfo.environment["WAYPOINT_FAILURE_PROBE"] == "1" else { throw XCTSkip("Opt-in capture failure diagnostic") }
        try run("FAILURE") { try tap("deliberately-missing-control", scroll: false) }
    }
}

