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
    @State private var router = DemoTabRouter(initialTab: .home)

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
                .tabItem {
                    Label(tab.rawValue, systemImage: tab == .home ? "house" : "books.vertical")
                }
                .tag(tab)
            }

            SingleStackLab()
                .tabItem { Label("Single Stack", systemImage: "square.stack") }
                .tag(DemoTab.singleStack)
        }
        .environment(router)
        .sheet(item: $router.presentedSheet) { presentation in
            DemoSheet(presentation: presentation, dismiss: router.dismissSheet)
        }
        .routerWindowPresenter(request: $router.presentedWindow)
    }
}

struct TabControls: View {
    let tab: DemoTab
    @Environment(DemoTabRouter.self) private var router

    private var otherTab: DemoTab { tab == .home ? .library : .home }

    var body: some View {
        List {
            Section("Navigation") {
                Button("Push detail") { router.navigate(to: .detail(1), in: tab) }
                Button("Replace this path with two details") {
                    router.replacePath(with: [.detail(1), .detail(2)], in: tab)
                }
                Button("Push in \(otherTab.rawValue) and switch") {
                    router.navigate(to: .detail(router[otherTab].count + 1), in: otherTab)
                    router.selectedTab = otherTab
                }
                Button("Prepare \(otherTab.rawValue) without switching") {
                    router.replacePath(with: [.detail(1), .detail(2)], in: otherTab)
                }
                Button("Clear \(otherTab.rawValue) history") {
                    router.popToRoot(in: otherTab)
                }
            }

            Section("Presentations") {
                Button("Open Classes sheet") { router.present(.classes) }
                Button("Open Inspector sheet") { router.present(.inspector) }
                Button("Open Utility") { router.present(.utility) }
                Text("Utility opens a separate window on macOS and a sheet on iOS.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Live router state") {
                RouterState(router: router)
            }

            Section("Try this") {
                Text("Push a detail in each tab, then switch tabs. Each tab keeps its own history. Preparing another tab's path should leave the selected tab unchanged.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Waypoint · \(tab.rawValue)")
    }
}

struct DetailView: View {
    let number: Int
    let tab: DemoTab
    @Environment(DemoTabRouter.self) private var router

    var body: some View {
        List {
            Section("\(tab.rawValue) detail \(number)") {
                Button("Push another detail") { router.navigate(to: .detail(number + 1), in: tab) }
                Button("Pop") { router.pop(in: tab) }
                Button("Return to root") { router.popToRoot(in: tab) }
                Button("Open Classes sheet") { router.present(.classes) }
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
        LabeledContent("Home path", value: describe(router[.home]))
        LabeledContent("Library path", value: describe(router[.library]))
        LabeledContent("Sheet", value: router.presentedSheet?.rawValue ?? "None")
        LabeledContent("Pending window", value: router.presentedWindow?.windowID ?? "None")
    }

    private func describe(_ path: [DemoDestination]) -> String {
        path.isEmpty ? "Root" : path.map {
            switch $0 { case .detail(let number): "Detail \(number)" }
        }.joined(separator: " → ")
    }
}

struct SingleStackLab: View {
    @State private var router = DemoStackRouter()

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            List {
                Section("Standalone Router") {
                    Text("This tab uses Router instead of TabRouter. Its state is independent of the tab router.")
                        .foregroundStyle(.secondary)
                    Button("Push detail") { router.navigate(to: .detail(1)) }
                    Button("Replace path with two details") {
                        router.replacePath(with: [.detail(1), .detail(2)])
                    }
                    Button("Open Classes sheet") { router.present(.classes) }
                    Button("Open Utility") { router.present(.utility) }
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
        .sheet(item: $router.presentedSheet) { presentation in
            DemoSheet(presentation: presentation, dismiss: router.dismissSheet)
        }
        .routerWindowPresenter(request: $router.presentedWindow)
    }
}

struct DemoSheet: View {
    let presentation: DemoPresentation
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
                                }
                            }
                        } footer: {
                            Text("This sheet owns a local navigation stack. The presenting router's path stays independent; automatic routing into sheets is not part of this baseline.")
                        }
                    }
                case .inspector:
                    List {
                        Text("Dismiss with Done or the platform's dismissal gesture, then reopen to check that the route binding resets.")
                        Text("Sheet route: \(presentation.rawValue)")
                    }
                case .utility:
                    UtilityView()
                }
            }
            .navigationTitle(presentation.rawValue.capitalized)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: dismiss)
                }
            }
        }
        .frame(minWidth: 320, minHeight: 320)
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
