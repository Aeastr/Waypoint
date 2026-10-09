import SwiftUI
import Waypoint

private enum WindowLabDestination: Hashable { case review }

private enum WindowLabPresentation: String, PresentationRoute {
    case editor, unavailableWindowProbe
    var id: String { rawValue }

    var presentationStyle: RoutePresentationStyle {
        switch self {
        case .editor: .sheet
        case .unavailableWindowProbe:
            .prominentWindow(activityType: "world.aethers.WaypointDemo.editDraft")
        }
    }

    @MainActor
    func configureWindowActivity(_ activity: NSUserActivity) {
        activity.targetContentIdentifier = "iphone-test-draft"
        activity.userInfo = ["draftID": "iphone-test-draft"]
    }
}

/// Exercises the editor fallback and window activation error on a regular iPhone.
struct ProminentWindowLab: View {
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
    @State private var router = Router<WindowLabDestination, WindowLabPresentation>()
    @State private var draft = "A draft to keep while moving between views."
    @State private var result = "Not requested"

    var body: some View {
        @Bindable var router = router

        List {
            Section {
                LabeledContent("Multiple windows", value: supportsMultipleWindows ? "Available" : "Unavailable")
                LabeledContent("Editor presentation", value: "Sheet fallback")
            } header: {
                Text("Detachable editor · iPhone scenario")
            } footer: {
                Text("The editor opens as a sheet on a regular iPhone.")
            }

            Section("Try the editor") {
                Button("Open editor sheet") { router.present(.editor) }
                    .accessibilityIdentifier("windowLab.openEditor")
                LabeledContent("Draft ID", value: "iphone-test-draft")
                Text(draft)
                    .accessibilityIdentifier("windowLab.savedDraft")
            }

            Section {
                Button("Verify unavailable-window error") {
                    result = "Waiting for presenter"
                    router.present(.unavailableWindowProbe)
                }
                .disabled(supportsMultipleWindows)
                .accessibilityIdentifier("windowLab.probe")
                LabeledContent("Activation result", value: result)
                    .accessibilityIdentifier("windowLab.result")
                LabeledContent("Pending request", value: router.presentedWindow == nil ? "None" : "Waiting")
                    .accessibilityIdentifier("windowLab.pending")
            } header: {
                Text("Prominent-window request")
            } footer: {
                Text("On a regular iPhone, the presenter reports Multiple windows unavailable and clears the pending request. Use the probe to exercise the error handler.")
            }
        }
        .navigationTitle("Detachable editor test")
        .sheet(item: $router.presentedSheet) { _ in
            WindowLabEditor(draft: $draft, dismiss: router.dismissSheet)
        }
        .routerWindowPresenter(request: $router.presentedWindow) { error in
            if let error = error as? RouterWindowError {
                switch error {
                case .multipleWindowsUnavailable: result = "Multiple windows unavailable"
                case .sourceSceneUnavailable: result = "Source scene unavailable"
                }
            } else {
                result = error.localizedDescription
            }
        }
    }
}

private struct WindowLabEditor: View {
    @Binding var draft: String
    let dismiss: () -> Void
    @State private var router = Router<WindowLabDestination, WindowLabPresentation>()

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            Form {
                Section {
                    TextField("Draft text", text: $draft, axis: .vertical)
                        .accessibilityIdentifier("windowLab.draftText")
                    Button("Review draft") { router.navigate(to: .review) }
                        .accessibilityIdentifier("windowLab.review")
                } header: {
                    Text("Draft")
                } footer: {
                    Text("The app keeps this draft in the testing view. Closing and reopening the sheet preserves the text while this scenario remains open.")
                }
            }
            .navigationTitle("Editor · sheet fallback")
            .navigationDestination(for: WindowLabDestination.self) { _ in
                List {
                    LabeledContent("Draft ID", value: "iphone-test-draft")
                    Text(draft)
                }
                .navigationTitle("Review draft")
                .toolbar { closeButton }
            }
            .toolbar { closeButton }
        }
    }

    private var closeButton: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Close", systemImage: "xmark", action: dismiss)
                .labelStyle(.iconOnly)
                .accessibilityIdentifier("windowLab.closeEditor")
        }
    }
}
