import Observation
import SwiftUI
import Waypoint

enum DemoContext: Hashable { case classes }
enum ClassDestination: Hashable { case detail(Int) }
enum ClassSheet: Hashable, Identifiable {
    case classes, detail(Int), inspector
    var id: Self { self }
}
enum ClassFallback: String, CaseIterable, Identifiable {
    case throughParent = "Through Classes"
    case direct = "Direct detail"
    var id: Self { self }
}
typealias ClassesRouter = ContextRouter<DemoContext, ClassDestination, ClassSheet>
typealias ClassesSheet = ContextSheet<DemoContext, ClassDestination, ClassSheet>

/// One session per app window. Every testing overlay calls this same root entry point.
@MainActor
@Observable
final class DemoSession {
    let tabs = DemoTabRouter(initialTab: .home)
    let single = DemoStackRouter()
    let classes = ClassesRouter()
    var classNumber = 3
    var fallback = ClassFallback.throughParent
    var lastAction = "Ready"
    private var pending: RootAction?
    var isWaitingForDismissal: Bool { pending != nil }

    private enum RootAction {
        case showClasses, open(Int, ClassFallback), overrideRoot, reset
    }

    func showClasses() { route(.showClasses) }
    func openSelectedClass() { route(.open(classNumber, fallback)) }
    func overrideRoot() { route(.overrideRoot) }
    func reset() { route(.reset) }

    func openClass(_ number: Int, from router: ClassesRouter) {
        withAnimation {
            router.open(.detail(number), in: .classes, ifNeeded: policy(for: number, fallback: fallback))
        }
        lastAction = "Local router opened Class \(number)"
    }

    /// Called only after a top-level SwiftUI sheet has finished dismissing.
    func sheetDidDismiss() {
        guard let action = pending else { return }
        pending = nil
        perform(action)
    }

    private func route(_ action: RootAction) {
        guard pending == nil else { return }
        // Baseline and contextual presenters must not race to open different sheets.
        if tabs.presentedSheet != nil || single.presentedSheet != nil {
            pending = action
            tabs.dismissSheet()
            single.dismissSheet()
            return
        }
        switch action {
        case .overrideRoot, .reset:
            if classes.presentedSheet != nil {
                pending = action
                classes.dismissSheet()
                return
            }
        default: break
        }
        perform(action)
    }

    private func perform(_ action: RootAction) {
        switch action {
        case .showClasses:
            classes.present(.classes, context: .classes)
            lastAction = "Presented Classes"
        case .open(let number, let fallback):
            let previousID = classes.presentedSheet?.id
            withAnimation {
                classes.open(.detail(number), in: .classes, ifNeeded: policy(for: number, fallback: fallback))
            }
            let reused = previousID != nil && previousID == classes.presentedSheet?.id
            lastAction = "Root opened Class \(number) · \(reused ? "reused sheet" : fallback.rawValue)"
        case .overrideRoot:
            classes.path.removeAll()
            tabs.selectedTab = .library
            tabs.replacePath(with: [.detail(99)], in: .library)
            lastAction = "Root override → Library detail 99"
        case .reset:
            classes.path.removeAll()
            tabs.popToRoot(in: .home)
            tabs.popToRoot(in: .library)
            single.popToRoot()
            tabs.dismissSheet()
            tabs.presentedWindow = nil
            single.dismissSheet()
            single.presentedWindow = nil
            tabs.selectedTab = .home
            classNumber = 3
            fallback = .throughParent
            lastAction = "Reset to Home"
        }
    }

    private func policy(for number: Int, fallback: ClassFallback) -> ContextOpeningPolicy<ClassSheet> {
        switch fallback {
        case .throughParent: .throughParent(.classes)
        case .direct: .direct(.detail(number))
        }
    }
}

/// Repeated in each presented surface so the root entry point stays reachable.
struct RootRoutingControls: View {
    @Environment(DemoSession.self) private var session
    @State private var isExpanded = true

    var body: some View {
        @Bindable var session = session
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label("Root routing", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button(isExpanded ? "Collapse root controls" : "Expand root controls",
                       systemImage: isExpanded ? "chevron.down" : "chevron.up") {
                    withAnimation { isExpanded.toggle() }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .accessibilityIdentifier("root.collapse")
                Button("Reset", systemImage: "arrow.counterclockwise", action: session.reset)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help("Reset to Home")
            }
            if isExpanded {
                HStack(spacing: 12) {
                    Picker("Class", selection: $session.classNumber) {
                        ForEach(1...12, id: \.self) { Text("Class \($0)").tag($0) }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("root.class")
                    Picker("Fallback", selection: $session.fallback) {
                        ForEach(ClassFallback.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("root.fallback")
                    Spacer(minLength: 0)
                }
                .labelsHidden()
                .font(.subheadline)
                HStack(spacing: 12) {
                    Button("Open class", systemImage: "arrow.turn.down.right", action: session.openSelectedClass)
                        .modifier(RoutingPrimaryButton())
                        .accessibilityIdentifier("root.open")
                    Button("Root override", systemImage: "arrow.uturn.backward", action: session.overrideRoot)
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("root.override")
                }
                .font(.subheadline.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.lastAction)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("root.lastAction")
                    if let sheet = session.classes.presentedSheet {
                        Text("Sheet \(sheet.id.uuidString.suffix(8)) · Depth \(sheet.router.path.count)")
                            .monospacedDigit()
                            .foregroundStyle(.tertiary)
                            .accessibilityIdentifier("classes-sheet-state")
                    }
                }
                .font(.caption)
            }
        }
        .disabled(session.isWaitingForDismissal)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(RoutingPanelBackground())
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

private struct RoutingPanelBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, macOS 26, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: 24))
        } else {
            content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        }
    }
}

private struct RoutingPrimaryButton: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, macOS 26, *) {
            content.buttonStyle(.glassProminent).buttonBorderShape(.capsule)
        } else {
            content.buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
        }
    }
}

struct ClassesSheetHost: View {
    let sheet: ClassesSheet
    let dismiss: () -> Void
    @Environment(DemoSession.self) private var session

    var body: some View {
        @Bindable var router = sheet.router
        NavigationStack(path: $router.path) {
            Group {
                switch sheet.root {
                case .classes:
                    List {
                        Section {
                            ForEach(1...12, id: \.self) { number in
                                Button("Class \(number)") { session.openClass(number, from: router) }
                                    .accessibilityIdentifier("context.class.\(number)")
                            }
                        } header: {
                            Text("Classes")
                        } footer: {
                            Text("Class buttons call this sheet's router. The controls below call the app's root router and should reuse this same Classes sheet.")
                        }
                        Section {
                            Button("Present child sheet") { router.present(.inspector) }
                        } footer: {
                            Text("The child sheet owns another router. Closing it reveals the existing Classes stack.")
                        }
                    }
                    .navigationTitle("Classes")
                case .detail(let number):
                    ClassDetail(number: number, router: router)
                case .inspector:
                    List {
                        Section {
                            LabeledContent("Sheet", value: "Child Inspector")
                            Button("Present another child sheet") { router.present(.inspector) }
                        } footer: {
                            Text("Use Open class below to route back into Classes, removing only sheets that cover it. Root override dismisses the whole hierarchy.")
                        }
                    }
                    .navigationTitle("Child Inspector")
                }
            }
            .toolbar { closeToolbar }
            .navigationDestination(for: ClassDestination.self) { destination in
                switch destination {
                case .detail(let number):
                    ClassDetail(number: number, router: router)
                        .toolbar { closeToolbar }
                }
            }
        }
        .id(sheet.id)
        .sheet(item: $router.presentedSheet) { child in
            ClassesSheetHost(sheet: child, dismiss: router.dismissSheet)
        }
        .safeAreaInset(edge: .bottom) { RootRoutingControls() }
        .frame(minWidth: 360, minHeight: 400)
    }

    private var closeToolbar: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Close", systemImage: "xmark", action: dismiss)
                .labelStyle(.iconOnly)
                .accessibilityIdentifier("context.close")
        }
    }
}

struct ClassDetail: View {
    let number: Int
    let router: ClassesRouter
    var body: some View {
        List {
            Section {
                LabeledContent("Class", value: "\(number)")
                LabeledContent("Stack depth", value: "\(router.path.count)")
                Button("Push next class") {
                    withAnimation { router.path.append(.detail(number + 1)) }
                }
                Button("Present child sheet") { router.present(.inspector) }
            } footer: {
                Text("Back follows this sheet's navigation stack. A directly presented detail has no Classes page beneath it. Close dismisses this sheet.")
            }
        }
        .navigationTitle("Class \(number)")
    }
}
