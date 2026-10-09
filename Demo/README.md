# Waypoint Lab

An iOS 17+ and macOS 14+ app for testing Waypoint's routing APIs.
It links the local package at `..` and has no external dependencies.

See the [validation record](Validation.md) for completed checks and remaining gaps.

Use the [test flows and recording plan](Flows.md) for step-by-step scenarios,
pass criteria, and separate video plans. Test each flow before recording it.

Open `WaypointDemo.xcodeproj`, choose the shared **WaypointDemo** scheme, select
**My Mac** or an iOS simulator, and run. Use Xcode with Swift 6.2 or later. To run
on an iPhone or iPad, select your own development team under Signing & Capabilities.

## Manual checks

- **Stacks:** Push several details, use the system Back control, pop explicitly,
  return to root, and replace a path with two details. The live state should match.
- **Tabs:** Push in Home and Library, then switch between them. Each history should
  survive. Compare “Switch … then push” with “Push … then switch”; both orders are
  supported, with selection first as the primary example. Prepare Library's path
  from Home without switching, then visit Library.
  Clear the other tab's history and confirm only that path resets.
- **Standalone router:** Use Single Stack to exercise `Router` independently of
  `TabRouter`. Push, replace, pop, and return to root there too.
- **Contextual Classes:** Use Open Classes sheet from Home, Library, or Single
  Stack. Class buttons call that sheet's Waypoint context router. Push, go Back,
  present a child sheet, and close it to reveal the same Classes stack.
- **Root requests:** The shared controls at the bottom of the window and every
  sheet call the same window-owned root entry point. Choose a class and fallback,
  then Open class. Through Classes supplies a Classes Back destination; Direct
  detail has no parent when Classes is absent. Both reuse an existing Classes
  context. Sheet ID and path depth make reuse visible. Request an offscreen class
  to check that routing does not depend on a list row appearing first.
- **Root override:** From Classes or its child sheet, use Root override. The demo
  waits for top-level dismissal, selects Library, then replaces its path with
  Detail 99. Reset returns the main window to Home with empty paths. These are
  in-app stand-ins for external requests; no Shortcut delivery is implemented.
- **Baseline sheets:** Open Inspector or Open local Classes sheet to exercise the
  single-sheet presentation API. Its bottom Local Classes, Inspector,
  and Utility controls replace the current request. Local Classes retains its
  app-owned NavigationLinks. A changed route resets local navigation; requesting
  the same route preserves it. Root Open class also works from these sheets,
  waiting for dismissal before presenting contextual Classes.
- **Sheet to Utility:** From a baseline sheet, request Utility. On macOS the sheet
  dismisses and Utility opens as a window; on iOS Utility replaces the sheet.
- **Detachable editor on a regular iPhone:** Home → Presentations → Detachable
  editor test. Open the sheet fallback, edit its text, Review draft, go Back,
  Close, and reopen. The text should persist while the scenario remains open.
  Close it, then Verify unavailable-window error. Expect Multiple windows
  unavailable and Pending request None; repeat the request, then reopen the editor.
  See W04 in [the flow plan](Flows.md). This tests the fallback and prominent-window
  error path; detaching into a separate window requires the separate W03 setup.
- **Windows:** On macOS, open Utility from a root or detail, close it, and request
  it again. A cleared pending window request means it was forwarded, not that the
  window closed. On iOS, Utility should appear as a sheet instead.

The app has three tabs: Home, Library, and Single Stack. Their Classes actions
use contextual routing.

Each app window owns its own `DemoSession`. Context lookup uses the router's
sheet hierarchy; tab selection, window targeting, and transition sequencing
remain app-owned. SettingsKit composition is documented in the package's
integration guide and is not a demo dependency.

The baseline sheet keys its local `NavigationStack` with `.id(presentation.id)`
so a changed route resets local navigation. Contextual sheets instead keep their
own stable presentation ID and router path while reused.

## Command-line builds

```sh
xcodebuild -project Demo/WaypointDemo.xcodeproj -scheme WaypointDemo \
  -destination 'platform=macOS' -derivedDataPath /tmp/waypoint-demo-derived-data \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild -project Demo/WaypointDemo.xcodeproj -scheme WaypointDemo \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/waypoint-demo-derived-data CODE_SIGNING_ALLOWED=NO build
```

Run these from the package root with a compatible Xcode selected. The project
includes a shared scheme and requires no project generator.

Watch the [17 scripted iPhone flows](https://github.com/Aeastr/Waypoint/releases/tag/demo-recordings-2026-10-09)
or open the [HTML gallery](../Resources/Recordings/index.html) locally. Optimized
videos are hosted as GitHub Release assets.
Local captures and validation artifacts are kept in `Resources/Recordings`.

## Scripted recordings

The UI test runner executes the flows in [Flows.md](Flows.md). The capture
coordinator waits for the runner's starting-state check, acknowledges recording
readiness, then finalizes the video after the flow's result and final hold.

From the repository root, build and record the complete set on an explicit regular
iPhone simulator:

```sh
python3 Demo/Scripts/record-flows.py --build --simulator SIMULATOR_UUID --flows all
```

Use `--check` for state assertions, `--flows B07,W04` for a selected pair, or
`--flows all` for the 17-flow set. `--output PATH` selects a new run directory;
the default is a dated directory under `Resources/Recordings`. Each checkout
uses a project-specific temporary build directory.
`--build-directory PATH` selects a reusable build directory. `--xcode PATH` selects
the Xcode application; the default is `/Applications/Xcode 27.1-1.app`.

Each run records its source snapshot and hashes, device, runtime, toolchain,
step timestamps, UI-test result bundle, and per-flow status. Failed steps retain
a screenshot and accessibility hierarchy in the result bundle. Run
`--flows FAILURE` to exercise the deliberately missing-control diagnostic.

Generate the playback index for a run:

```sh
python3 Demo/Scripts/publish-recordings.py Resources/Recordings/RUN_DIRECTORY
```

`Demo/Scripts/ValidateRecordings.swift` decodes each MP4 and generates timestamped
frames and media metadata for review. Compile it with the selected Xcode's
`swiftc -parse-as-library`, then pass the run's MP4 paths. Review the complete
flow timeline and important transitions before promoting clips to the main gallery.
