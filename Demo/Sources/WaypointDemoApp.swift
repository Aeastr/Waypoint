import SwiftUI
import Waypoint

enum DemoTab: String, CaseIterable, Hashable {
    case home = "Home"
    case library = "Library"
    case singleStack = "Single Stack"
}

enum DemoDestination: Hashable {
    case detail(Int)
}

enum DemoPresentation: String, PresentationRoute {
    case classes, inspector, utility

    var id: String { rawValue }

    var presentationStyle: RoutePresentationStyle {
        #if os(macOS)
        if self == .utility { return .window(id: "utility") }
        #endif
        return .sheet
    }
}

typealias DemoTabRouter = TabRouter<DemoTab, DemoDestination, DemoPresentation>
typealias DemoStackRouter = Router<DemoDestination, DemoPresentation>

@main
struct WaypointDemoApp: App {
    var body: some Scene {
        WindowGroup {
            TabLab()
                .frame(minWidth: 360, minHeight: 500)
        }

        #if os(macOS)
        Window("Utility", id: "utility") {
            UtilityView()
                .frame(minWidth: 320, minHeight: 240)
        }
        #endif
    }
}

struct TabLab: View {
    @State private var session = DemoSession()
    private var router: DemoTabRouter { session.tabs }

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {
            ForEach([DemoTab.home, .library], id: \.self) { tab in
                NavigationStack(path: $router[tab]) {
                    TabControls(tab: tab)
                        .navigationDestination(for: DemoDestination.self) { destination in
                            switch destination {
                            case .detail(let number):
                                DetailView(number: number, tab: tab)
                            }
                        }
                }
                .safeAreaInset(edge: .bottom) { RootRoutingControls() }
                .tabItem {
                    Label(tab.rawValue, systemImage: tab == .home ? "house" : "books.vertical")
                }
                .tag(tab)
            }

            SingleStackLab()
                .safeAreaInset(edge: .bottom) { RootRoutingControls() }
                .tabItem { Label("Single Stack", systemImage: "square.stack") }
                .tag(DemoTab.singleStack)
        }
        .environment(router)
        .sheet(item: $router.presentedSheet, onDismiss: session.sheetDidDismiss) { presentation in
            DemoSheet(presentation: presentation, present: router.present, dismiss: router.dismissSheet)
        }
        .routerWindowPresenter(request: $router.presentedWindow)
        .sheet(item: Bindable(session.classes).presentedSheet, onDismiss: session.sheetDidDismiss) { sheet in
            ClassesSheetHost(sheet: sheet, dismiss: session.classes.dismissSheet)
        }
        .environment(session)
    }
}

struct TabControls: View {
    @Environment(DemoSession.self) private var session
    let tab: DemoTab
    @Environment(DemoTabRouter.self) private var router

    private var otherTab: DemoTab { tab == .home ? .library : .home }

    var body: some View {
        List {
            Section {
                Button("Push detail") { router.navigate(to: .detail(1), in: tab) }
                Button("Replace this path with two details") {
                    router.replacePath(with: [.detail(1), .detail(2)], in: tab)
                }
                Button("Switch to \(otherTab.rawValue), then push") {
                    router.selectedTab = otherTab
                    router.navigate(to: .detail(router[otherTab].count + 1), in: otherTab)
                }
                Button("Push in \(otherTab.rawValue), then switch") {
                    router.navigate(to: .detail(router[otherTab].count + 1), in: otherTab)
                    router.selectedTab = otherTab
                }
                Button("Prepare \(otherTab.rawValue) without switching") {
                    router.replacePath(with: [.detail(1), .detail(2)], in: otherTab)
                }
                Button("Clear \(otherTab.rawValue) history") {
                    router.popToRoot(in: otherTab)
                }
            } header: {
                Text("Navigation")
            } footer: {
                Text("Push a detail in each tab, then switch tabs. Each tab keeps its own history. Preparing another tab's path should leave the selected tab unchanged.")
            }

            Section {
                Button("Open Classes sheet", action: session.showClasses)
                Button("Open Inspector sheet") { router.present(.inspector) }
                Button("Open local Classes sheet") { router.present(.classes) }
                    .accessibilityIdentifier("baseline.open")
                Button("Open Utility") { router.present(.utility) }
                NavigationLink("Detachable editor test") { ProminentWindowLab() }
            } header: {
                Text("Presentations")
            } footer: {
                Text("Classes uses contextual routing. Local Classes keeps the simpler navigation example for comparison. Utility opens a separate window on macOS and a sheet on iOS.")
            }

            Section("Live router state") {
                RouterState(router: router)
            }

        }
        .navigationTitle("Waypoint · \(tab.rawValue)")
    }
}

struct DetailView: View {
    @Environment(DemoSession.self) private var session
    let number: Int
    let tab: DemoTab
    @Environment(DemoTabRouter.self) private var router

    var body: some View {
        List {
            Section("\(tab.rawValue) detail \(number)") {
                Button("Push another detail") { router.navigate(to: .detail(number + 1), in: tab) }
                Button("Pop") { router.pop(in: tab) }
                Button("Return to root") { router.popToRoot(in: tab) }
                Button("Open Classes sheet", action: session.showClasses)
                Button("Open Utility") { router.present(.utility) }
            }
            Section("Live router state") {
                RouterState(router: router)
            }
        }
        .navigationTitle("Detail \(number)")
    }
}

struct RouterState: View {
    let router: DemoTabRouter

    var body: some View {
        LabeledContent("Selected tab", value: router.selectedTab.rawValue)
            .accessibilityIdentifier("state.tab")
        LabeledContent("Home path", value: describe(router[.home]))
            .accessibilityIdentifier("state.home")
        LabeledContent("Library path", value: describe(router[.library]))
            .accessibilityIdentifier("state.library")
        LabeledContent("Sheet", value: router.presentedSheet?.rawValue ?? "None")
            .accessibilityIdentifier("state.sheet")
        LabeledContent("Pending window", value: router.presentedWindow?.windowID ?? "None")
    }

    private func describe(_ path: [DemoDestination]) -> String {
        path.isEmpty ? "Root" : path.map {
            switch $0 { case .detail(let number): "Detail \(number)" }
        }.joined(separator: " → ")
    }
}

struct SingleStackLab: View {
    @Environment(DemoSession.self) private var session
    private var router: DemoStackRouter { session.single }

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            List {
                Section {
                    Button("Push detail") { router.navigate(to: .detail(1)) }
                    Button("Replace path with two details") {
                        router.replacePath(with: [.detail(1), .detail(2)])
                    }
                    Button("Open Classes sheet", action: session.showClasses)
                    Button("Open Utility") { router.present(.utility) }
                } header: {
                    Text("Standalone Router")
                } footer: {
                    Text("This tab uses Router instead of TabRouter. Its state is independent of the tab router.")
                }
            }
            .navigationTitle("Single Stack")
            .navigationDestination(for: DemoDestination.self) { destination in
                switch destination {
                case .detail(let number):
                    List {
                        Button("Push another detail") { router.navigate(to: .detail(number + 1)) }
                        Button("Pop") { router.pop() }
                        Button("Return to root") { router.popToRoot() }
                        Button("Open Inspector sheet") { router.present(.inspector) }
                        LabeledContent("Path depth", value: "\(router.path.count)")
                    }
                    .navigationTitle("Detail \(number)")
                }
            }
        }
        .sheet(item: $router.presentedSheet, onDismiss: session.sheetDidDismiss) { presentation in
            DemoSheet(presentation: presentation, present: router.present, dismiss: router.dismissSheet)
        }
        .routerWindowPresenter(request: $router.presentedWindow)
    }
}

struct DemoSheet: View {
    let presentation: DemoPresentation
    let present: (DemoPresentation) -> Void
    let dismiss: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                switch presentation {
                case .classes:
                    List {
                        Section {
                            ForEach(1...12, id: \.self) { number in
                                NavigationLink("Class \(number)") {
                                    Text("Class \(number) detail")
                                        .navigationTitle("Class \(number)")
                                        .toolbar { dismissalToolbar }
                                }
                                .accessibilityIdentifier("baseline.class.\(number)")
                            }
                        } footer: {
                            Text("The class links use this sheet’s local navigation stack. The presenting router keeps its own path.")
                        }
                    }
                case .inspector:
                    List {
                        Section {
                            LabeledContent("Sheet route", value: presentation.rawValue)
                        } footer: {
                            Text("Dismiss with the Close button or the platform's dismissal gesture, then reopen to check that the route binding resets.")
                        }
                    }
                case .utility:
                    UtilityView()
                }
            }
            .navigationTitle(presentation.rawValue.capitalized)
            .toolbar { dismissalToolbar }
        }
        .id(presentation.id)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                HStack {
                    Button("Local Classes") { present(.classes) }.accessibilityIdentifier("baseline.classes")
                    Button("Inspector") { present(.inspector) }.accessibilityIdentifier("baseline.inspector")
                    Button("Utility") { present(.utility) }.accessibilityIdentifier("baseline.utility")
                }
                .buttonStyle(.bordered)
                .padding()
                RootRoutingControls()
            }
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
        .frame(minWidth: 320, minHeight: 320)
    }

    private var dismissalToolbar: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Close", systemImage: "xmark", action: dismiss)
                .labelStyle(.iconOnly)
                .accessibilityIdentifier("baseline.close")
        }
    }
}

struct UtilityView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "macwindow")
                .font(.largeTitle)
            Text("Utility")
                .font(.title)
            Text("On macOS, this scene receives the window ID. Waypoint does not forward the route payload or close an opened window when its pending request clears.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }
}
