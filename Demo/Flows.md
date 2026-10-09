# Test flows and recording plan

Run each flow as a test before recording it. A planned flow is not evidence that
the behavior works. Record the tested app revision, platform, result, and any
limitations alongside the video.

The [validation record](Validation.md) describes earlier checks. This document
defines repeatable scenarios for future test and recording runs.

## Implemented recording set

[All 17 scripted iPhone takes](../Resources/Recordings/README.md) now have passing
UI assertions, complete media decoding, and timestamped frame review. See the
[validation record](Validation.md#continuous-scripted-iphone-recordings--2026-10-09)
for run provenance and the two diagnostic-visibility retakes. The reusable
commands are in [the demo guide](README.md#scripted-recordings).

## Scripted recording implementation plan

Produce B01–B10, C01–C06 and W04 as continuous, repeatable UI scripts on a regular iPhone. Use the existing demo screens and this document’s flow assertions. Deliver MP4s, a playback gallery, and a per-flow result manifest in `Resources/Recordings`.

### 1. Establish the UI runner

Add a `WaypointDemoUITests` XCUITest target and include it in the shared demo scheme. Give the existing controls stable accessibility identifiers for tabs, navigation actions, presentation actions, Close, root controls, class pickers, and visible routing diagnostics. Scope queries to the active sheet or navigation host when labels repeat.

Implement shared steps for tapping a visible control, selecting a tab or picker value, replacing text, navigating Back, closing a sheet, and checking visible state. Scroll the appropriate list until the requested element is hittable, using a bounded number of gestures and a timeout. Capture a screenshot, accessibility hierarchy, flow ID, and failed step when an assertion fails.

Each script launches the app into a known state and uses its actual controls. Check both the destination content and relevant route diagnostics after each action. Keep normal animations enabled. Use state-based waits for readiness and a configurable presentation hold, initially 0.7 seconds after important transitions and 1.2 seconds for the final result. Tune these values by reviewing the pilot recording.

### 2. Synchronize capture with the running script

Create a host-side command that selects an explicit simulator UUID, runs one flow or a named set, and coordinates capture with the UI test. Build the app and test runner once, then reuse those products for compatible runs.

Use a readiness handshake after launch and initial-state checks. The host starts recording and acknowledges that frames are arriving; the UI test then executes the complete sequence. A completion event carries the flow result and final hold. The host finalizes the capture and records its outcome. Apply timeouts and cleanup to every handshake. A failed step produces a failed take with its diagnostics.

Reuse Preview Output Renderer’s continuous simulator capture/export implementation and its media validation where practical. Its current capture command accepts a fixed duration; the pilot must establish an event-driven start/stop integration for flow completion. Keep the capture adapter separate from Waypoint’s routing implementation. Save monotonic timestamps for flow steps and capture boundaries so setup time can be trimmed precisely.

### 3. Prove the workflow with B07

Run **Open local Classes → Class 3 → Inspector → Local Classes → Close**. This pilot exercises real scrolling, a navigation push, replacement from a detail, and dismissal.

First run the script with state assertions. Then capture the same script twice and review both complete clips. Check that controls are visibly reached, each transition is readable, the returned Classes list is at its root, and the final presenter is correct. Compare step timing to identify unexpected pauses. Exercise one deliberately missing-element failure to check diagnostics and capture finalization.

### 4. Prove editor input with W04

Run the existing editor fallback flow through text replacement, Review draft, Back, dismissal/reopening, and repeated unavailable-window probes. Check the exact draft text and ID, retained text after reopening, visible error result, and cleared pending request. Set the root panel to its compact state through its control so the result remains readable.

### 5. Script the remaining flows

Implement the remaining B and C scenarios with the same helpers. Keep each flow’s assertions beside its action sequence. Add checks for independent tab paths, stable Classes sheet identity, parent/child dismissal, direct fallback, and the root override destination as specified below.

For C02, choose the behavior the clip should demonstrate: the current initialized parent/detail stack, or a separately implemented and validated staged presentation followed by a push. Record the current behavior accurately while treating an animation change as its own implementation decision.

### 6. Record and review the set

Record all 17 flows from one recorded source snapshot and compatible build. Use the regular iPhone target with Xcode 27.1; select the installed runtime that supports that device and include its exact version in the manifest. The previous regular iPhone pass used iOS 27.0.

Store existing review takes under `Resources/Recordings/ReviewTakes` and new candidates in a dated run directory. Each run contains the videos, playback gallery, source identity, device/runtime/toolchain, flow outcomes, step timestamps, and useful failure evidence. Keep compiled outputs in the task-owned build directory.

Review every complete candidate for visible actions, pacing, transitions, readable results, and clean capture boundaries. Check media decoding, dimensions, cadence, and gallery links. Promote reviewed clips to the main gallery. Trim setup and completion using recorded boundaries; investigate long internal pauses in the runner before the next take.

The first implementation milestone is a repeatable, fully reviewed B07 recording. W04 is the second milestone; the full set follows once both are reliable.

## Prepare a run

1. Build the intended revision and install it on a dedicated simulator.
2. Record the Git commit, any uncommitted changes, Xcode version, simulator model,
   and OS version. A recording of an edited checkout does not validate its commit
   alone.
3. Start each flow with a fresh app launch, Home selected, empty navigation paths,
   and no sheet. For flows requiring a detail, navigate there as the setup step.
4. Check the expected state after each action. For tab flows, inspect the selected
   tab and both paths; for sheet flows, inspect the presenting path after dismissal.
5. Mark a flow ready to record only after its checks pass on the recording target.
   If the app changes, rerun affected flows before recording them.

Use short, deliberate pauses to make transitions readable. Interaction scripts
should wait for the expected screen instead of assuming an animation finishes
after a fixed delay. Keep one behavior per video, starting from a known state and
ending with its result visible.

## What these checks cover

Test Waypoint's path mutations, context lookup, presentation identity, and state
preservation, plus the demo's bindings and view construction. Use a small number
of running-app checks to verify that those connections produce the intended UI.
The sheet-replacement and dismissal-control regressions recorded in
[Validation.md](Validation.md) are concrete examples of demo integration bugs.

SwiftUI owns ordinary gestures, sheet animation, and adaptive presentation. Do
not expand this into a framework gesture or animation test suite. Verify our
binding after a completed dismissal; cancelled swipe progress is not a router
test. Inspect visible sequencing only where the app deliberately coordinates it
or the video is intended to demonstrate it.

Each flow below is a recording candidate, not a requirement to exhaust every
combination of tabs, details, device sizes, and standard SwiftUI interactions.
Repeat across distinct router hosts where their wiring differs. Local sheet
navigation in B08 is a useful demonstration and setup for B07; it does not need
its own exhaustive router regression coverage.

## Current demo flows

The main Open Classes sheet actions use contextual routing (C01–C06). For B05–B10,
use **Open local Classes sheet** from Home or Library, or open Inspector in
Single Stack and choose **Local Classes** at the bottom. These baseline class
links use SwiftUI `NavigationLink`. Their bottom Local Classes, Inspector, and
Utility controls replace the single sheet request on iOS rather than nesting.

### B01 — Push, push, and return

- **Actions:** Home → Push detail → Push another detail → system Back → Return
  to root.
- **Pass:** Detail 1 and Detail 2 appear in order. Back leaves exactly Detail 1 in
  Home's path; returning to root empties it. Library stays at its root.
- **Recording:** `b01-stack-navigation.mp4`.
- **Additional test:** Repeat with explicit Pop and in Single Stack. Replace the
  path with two details, then use Back to verify both destinations exist.

### B02 — Switch tab, then push

- **Actions:** From Home, tap Switch to Library, then push.
- **Pass:** Library is selected and its path contains Detail 1. Home's path stays
  empty. Separately inspect whether the recording shows the desired transition.
- **Recording:** `b02-switch-then-push.mp4`.
- **Additional test:** Run Push in Library, then switch from a fresh launch. Both
  orders must reach the same state. Statement order alone does not establish two
  visible animation phases; do not describe a combined transition as sequential.

### B03 — Preserve independent histories

- **Actions:** Push Detail 1 in Home → select Library → push Detail 1 and Detail 2
  there → switch between Home and Library.
- **Pass:** Home returns to Detail 1; Library returns to Detail 2 with Detail 1
  underneath. Switching tabs does not mutate either path.
- **Recording:** `b03-independent-tab-history.mp4`.

### B04 — Prepare an unselected tab

- **Actions:** From Home, tap Prepare Library without switching → select Library
  → Back → select Home → Clear Library history → select Library.
- **Pass:** Preparation leaves Home selected. Library initially opens at Detail 2;
  Back reveals Detail 1. Clearing its history leaves Home selected and Library
  subsequently opens at its root.
- **Recording:** `b04-background-tab-routing.mp4`.

### B05 — Present and dismiss a sheet

- **Actions:** Home → Push detail → Open Classes sheet → Close.
- **Pass:** Classes appears, then dismissal returns to Home's original Detail 1.
  The sheet request is cleared and the presenting path is unchanged.
- **Recording:** `b05-sheet-round-trip.mp4`.
- **Additional test:** Repeat from Home root, Library root/detail, and Single
  Stack root/detail. Single Stack detail exposes Inspector; use its Classes
  control to reach Classes.

### B06 — Replace an open sheet

- **Actions:** Open Classes → bottom Inspector control → bottom Classes control
  → Close.
- **Pass:** Inspector replaces Classes, then Classes returns at its root. There
  is one sheet presentation, not a nested sheet. Dismissal restores the presenter.
- **Recording:** `b06-sheet-replacement.mp4`.
- **Additional test:** Open Inspector directly from Home and Library, dismiss it,
  and reopen it.

### B07 — Replace a sheet from its detail

- **Actions:** Open Classes → Class 3 → bottom Inspector control → bottom Classes
  control → Close.
- **Pass:** Inspector becomes visible immediately after the transition; the old
  Class 3 detail does not cover it. Returning to Classes shows the list, not the
  old detail. The presenting app path stays unchanged.
- **Recording:** `b07-replace-sheet-from-detail.mp4`.
- **Additional test:** From Class 3, request Classes again instead. The same-route
  request should preserve Class 3 in this demo.

### B08 — Navigate locally inside a sheet

- **Actions:** Open Classes → Class 3 → Back → Class 3 → Close.
- **Pass:** Back returns to the class list. Close is available from the detail and
  dismisses the whole sheet without changing the presenting path.
- **Recording:** `b08-local-sheet-navigation.mp4`.
- **Label accurately:** This demonstrates app-owned SwiftUI navigation within a
  Waypoint-presented sheet, not contextual router navigation.

### B09 — Dismiss and reopen

- **Actions:** Open Classes → Class 3 → Close → reopen Classes → Close.
- **Pass:** Reopening shows the class list with no stale detail or presentation
  state. Both dismissals clear the sheet request.
- **Recording:** `b09-dismiss-and-reopen.mp4`.
- **Binding integration check:** On iOS, complete one standard swipe dismissal,
  verify the sheet request is cleared, and reopen Classes. This checks the demo's
  binding, not SwiftUI's gesture implementation. An automation drag that produces
  no dismissal leaves that check unverified; it is not evidence of a router bug.

### B10 — Replace a sheet with Utility

- **Actions:** Open Classes → Class 3 → bottom Utility control → Close on iOS.
- **Pass on iOS:** Utility replaces Classes as the sheet content. Close returns to
  the original presenter with its path intact.
- **Recording:** `b10-sheet-to-utility-ios.mp4`.
- **macOS companion test:** Utility opens as a separate window and Classes
  dismisses. Close Utility and request it again. A cleared pending request does
  not mean the window has closed.

## Integrated contextual flows

Use the existing main Classes actions and the shared bottom controls. No extra
tab is needed. Reset before each flow. Choose Class 3 and Through Classes or
Direct detail in the bottom pickers before Open class. Root override is the
in-app external-style trigger; it selects Library and opens Detail 99 after
sheet dismissal. Sheet ID and Class path show identity and path preservation.
See Validation.md for observed results. Unedited regular iPhone review takes are
available in [Resources/Recordings](../Resources/Recordings/README.md).

| ID / video | Actions | Required result |
| --- | --- | --- |
| C01 / `c01-router-push-in-sheet.mp4` | Open Classes → use a router-driven Class 3 action → Back | The Classes context receives the push; the root app path stays unchanged. Back returns to Classes. The main Class buttons call the context router; baseline Local Classes remains available separately. |
| C02 / `c02-open-class-through-parent.mp4` | From Home with no sheet, request Class 3 through its parent → Back | The sheet contains Classes with Class 3 above it; Back reveals Classes. For the desired showcase animation, separately verify that Classes visibly appears before the push. Initializing a path with Class 3 does not establish that animation. |
| C03 / `c03-open-class-directly.mp4` | From Home with no sheet, request Class 3 directly → dismiss | Class 3 is the sheet root, with no Classes page underneath. Dismissal restores Home. |
| C04 / `c04-reuse-existing-context.mp4` | Open Classes → request Class 3 through the router → request Class 4 | The existing Classes context and sheet identity survive; details are pushed there rather than opening a duplicate Classes sheet. |
| C05 / `c05-nested-sheet.mp4` | Classes → Class 3 → present a child sheet → dismiss the child → dismiss Classes | Dismissing the child reveals Class 3; dismissing Classes restores the app presenter. This is separate from baseline sheet replacement. |
| C06 / `c06-external-root-override.mp4` | Leave Classes open at Class 3 → invoke an external-style root navigation action | Classes dismisses, the requested tab/root destination becomes visible, and obsolete sheet contexts do not intercept the action. Use a demo trigger first; test a real Shortcut separately before claiming Shortcut integration. |

For contextual reuse, also test when another sheet covers the requested parent,
when the target context is missing, and after the user has dismissed it. Record
the expected policy explicitly rather than letting view appearance choose it.

## Additional coverage after reviewing ownership

The following cases refine the recording flows. They are planned checks, not
newly observed results. The integrated controls support the contextual cases below.

| Case | Scope and assertion |
| --- | --- |
| Repeated requests | State test: the current `navigate` and matching-context `open` operations append on each call, including the same destination twice. Assert that behavior and sheet identity preservation. There is no debounce policy to test. Repeated window requests should have distinct request IDs. |
| Select another tab with a sheet requested | State test: changing `selectedTab` must preserve the shared sheet request and both tab paths. No need to interact with a covered tab bar; this is a router invariant. |
| Parent covered by a child sheet | Context state test plus one UI flow: routing to the parent clears its covering sheet and pushes into the parent, preserving its identity and previous path. This exercises `ContextRouter.open`, not generic SwiftUI dismissal. |
| Two matching named contexts | Context state test: the deepest matching context receives the destination; the shallower context's path remains unchanged. This tests the router's documented lookup rule. |
| Both policies with a parent already open | Context state test: direct and through-parent policies both reuse the matching context. The fallback difference applies only when no matching parent exists. |
| Change the class ID | State test the distinct destination values and perform one UI check that Class 4 renders Class 4's content after Class 3. This checks app destination construction and identity, not SwiftUI rendering generally. |
| Open an offscreen class | One contextual UI flow: an app-wide action requests a class whose row has not been visited. It reaches the correct context and destination without requiring that row to register itself. No need to test the lazy container's loading behavior separately. |
| Route after dismissing Classes | Context state test: dismissing removes the sheet from the root hierarchy; a subsequent root request uses its chosen missing-context fallback rather than reusing the dismissed context. |

### Cases excluded or conditional

- **Cancelled swipe dismissal:** Excluded from router regression coverage.
  Waypoint does not handle gesture progress or clear contexts on partial drags.
- **Dismissal during a pending action:** Router mutations are synchronous on the main actor. The demo queues one root
  action while a top-level sheet dismisses and disables its root controls until
  that action runs. Verify the requested destination after dismissal; no
  cancellation or overlapping-request policy is supplied by Waypoint.
- **Cold launch, background delivery, and real Shortcuts:** App integration work,
  not behavior supplied by Waypoint. C06 can demonstrate a root action while a
  sheet is open. Add lifecycle delivery tests when that delivery code exists.
- **Multiple windows:** Include the per-window ownership flows below. These
  routers do not themselves select an active window; an app-wide request needs
  an explicit target-selection policy.
- **iPad:** Run one representative navigation/sheet flow to check the demo's own
  controls, content sizing, and dismissal access in a regular-width layout. The
  router's expected path and context state is the same as on iPhone. Additional
  coverage is warranted if the app introduces a distinct iPad navigation host;
  standard SwiftUI adaptive sheet behavior does not need separate regression tests.

## Open another window through the router

The requested feature is an in-app router action that opens another app window.
Waypoint already has the mechanism: a presentation route returns `.window(id:)`,
and `.routerWindowPresenter` forwards that ID to SwiftUI's `openWindow` action.
The app registers the matching scene. The current demo exposes its Utility window
on macOS; it needs a matching window route and control for the intended iPad/Duo
demonstration. Supporting multiple scene instances alone is not this test.

| ID / video | Actions | Required result |
| --- | --- | --- |
| W01 / `w01-open-window-from-router.mp4` | From the app's root, invoke a router action to open another registered app window | The bridge forwards the correct scene ID and the requested window appears on the supported target. Record the result of invoking the action, not merely two windows that were opened manually. |
| W02 / `w02-sheet-to-window.mp4` | Open Classes at a class detail → invoke the window-opening route | The existing presentation policy clears the sheet request and opens the registered window. The app's presenting navigation path remains intact. |

For another main app window, register an identified `WindowGroup` and use its ID
in the route. The existing bridge forwards only the scene ID; opening a new
window at a specific class would additionally require destination-data delivery.
Do not claim that capability from an ID-only window request. A forwarded request
is also distinct from the observed appearance of the new window.

Use Device Hub for the iPhone Duo setup and interactions. Prefer the unfolded
Duo for showcase recordings, confirming its unfolded state and actual windowing
capabilities before the run. Device Hub identifies this device as a simulator;
using Device Hub as the interaction frontend does not require replacing the
simulator-display capture backend. Identify its exact device UUID and verify
that the capture includes the full unfolded display and the newly opened window
for W01/W02. Use an iPad target for window-opening checks if the selected Duo runtime
does not expose multiple app windows. No multi-window or unfolded-device result
is claimed by this plan.

### Prominent scene / detachable editor

#### W04 — regular iPhone fallback and activation error

Video: `w04-iphone-editor-fallback.mp4`. Start on a regular, non-folding iPhone
with Home selected and no sheet open. This is the first scenario to run; it does
not require a Duo or iPad. A simulator is sufficient for initial checking.

| Step | Action | Required result |
| --- | --- | --- |
| 1 | Home → Presentations → Detachable editor test | Multiple windows reads Unavailable; Editor presentation reads Sheet fallback. |
| 2 | Tap Open editor sheet | Editor appears as a sheet with draft ID `iphone-test-draft` owned by the scenario. There is no window-detachment handle. |
| 3 | Replace Draft text with `iPhone routing check` → Review draft | The editor's Waypoint router pushes Review draft, showing the same draft ID and edited text. The underlying Home navigation remains in the test scenario. |
| 4 | Use Back | The editor shows the edited text. |
| 5 | Close → Open editor sheet | The sheet reopens at its editor root with `iPhone routing check` retained by the app-owned scenario state. |
| 6 | Close → Verify unavailable-window error | Activation result becomes Multiple windows unavailable and Pending request becomes None. No editor sheet or new window opens. This step deliberately requests `.prominentWindow` rather than selecting the sheet fallback. |
| 7 | Repeat Verify unavailable-window error → Open editor sheet | The error is handled again, and the fallback editor remains usable with the same text. |

Capture the editor flow and visible activation result in one separate clip.
Leaving the scenario and opening it again may reset its app-owned draft; persistence
across relaunches is outside this test. On a target that reports multiple windows
as Available, the unavailable-window probe is disabled: use W03 after a receiving
editor scene is integrated instead. Do not mark W03 passed from this iPhone test.

#### W03 — detachable scene on a multiwindow target

W03 / `w03-detachable-editor.mp4` requires an app-owned editor scene registered
for a `.prominentWindow(activityType:)` route; the current demo does not yet
register that receiving scene. This flow is **pending integration and device
validation**, not a claim of working UI.

- Open an editor through the router on a target supporting multiple scenes.
- Confirm the expected content ID and originating scene reach the new scene.
- Edit a value, then drag its dedicated `.routerWindowDragHandle()` to move the
  scene into a separate window where the OS supports this behavior.
- Confirm the same draft and unsaved edit remain visible, and route within the
  moved scene to verify its app-owned router remains usable.
- Close the editor using its scene close action; confirm the originating app
  window remains usable and its navigation path is preserved.
- Exercise the app's sheet fallback on a target without multiple scenes. Check
  that unsupported activation and UIKit errors reach the presenter's error handler.

The assertions concern request dispatch, content delivery, state continuity, and
app scene integration. Do not separately test UIKit's drag recognizer mechanics.

### Recording infrastructure

Keep capture concerns out of the router test matrix. Before using an automated
flow runner, verify its recording-start synchronization, failed-step reporting,
and capture finalization once. A failed flow must not be marked passed just
because a video exported. Use Preview Output Renderer's existing capture/export
checks rather than duplicating them in Waypoint. Review each final clip for
complete transitions and readable pacing.

## Test and recording record

Copy this table into the run's validation notes. Leave results pending until
observed; recording readiness follows the test result, not the other way around.

| Flow ID | Revision / edits | Device / OS | Test result and evidence | Recording status / file |
| --- | --- | --- | --- | --- |
| B01 | Pending | Pending | Not run in this record | Not recorded |

Keep state-correctness checks separate from animation checks. A unit test can
establish routing state, but only the running UI can establish the visible
presentation and ordering shown in a recording.

## Capture after testing

Use the dedicated simulator's UUID, not `booted`, when other simulators may be
running. For example, from a terminal:

```sh
xcrun simctl io SIMULATOR_UUID recordVideo --codec=h264 b01-stack-navigation.mp4
```

Start capture, run the prepared interaction sequence, leave the final state
visible briefly, and stop capture with Control-C so the video finalizes. Review
the complete clip for wrong starting state, missed interactions, interrupted
transitions, and unrelated overlays before marking it ready to share. Store reviewable recordings in `Resources/Recordings` inside this repository.
Keep disposable capture and build outputs outside the source tree.
