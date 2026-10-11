# Demo validation — 9 October 2026

## Earlier baseline pass

Validated the working tree on `feat/nested-routing` after adding both tab-switch
orders, sheet replacement controls, navigation reset on a different sheet route,
and Done on class details. This covers the baseline router integration in the
demo. Contextual-routing source files appeared concurrently in the shared
checkout after the final build; those in-progress additions are outside this
validation record.

Subsequent footer layout and xmark Close-button edits received Swift syntax and
diff checks only. The runtime results below describe the preceding demo UI,
whose dismissal button was labeled Done.

## Build and package checks

Using Xcode 26.6:

- macOS Debug app build: passed.
- Generic iOS Simulator Debug app build: passed.
- `swift test`: all five tests passed. These cover stack replacement/popping,
  independent tab paths, presentation replacement, and repeated window request IDs.
- `git diff --check`: passed.

## Runtime checks

Native app on macOS 27.0 and an isolated iPhone 17 simulator running iOS 26.5:

| Scenario | macOS | iOS Simulator |
| --- | --- | --- |
| Classes from Home root and detail | Passed | Passed |
| Classes from Library root and detail | Passed | Passed |
| Classes from Single Stack root and detail (via Inspector at detail) | Passed | Passed |
| Inspector from Home and Library roots | Passed | Passed |
| Inspector via replacement from Classes | Passed | Passed |
| Inspector from Single Stack detail | Passed | Passed |
| Push a class within its sheet | Passed | Passed |
| Back within the sheet | Passed | Not repeated in this pass |
| Done from the sheet root and a class detail | Passed | Passed |
| Dismiss and reopen Classes | Passed | Passed |
| Replace Classes with Inspector while viewing a class detail | Passed | Passed |
| Request Classes again while viewing a class detail, preserving that detail | Passed | Passed |
| Replace Inspector with Classes, starting at its root | Passed | Passed |
| Utility from an open sheet | Opens a window and dismisses the sheet | Replaces the sheet |
| Presenting navigation path survives sheet dismissal/replacement | Passed | Passed |
| Switch tab, then push | Passed | Passed |
| Push in another tab, then switch | Passed | Passed |
| Prepare another tab's path without switching, then visit it | Passed | Not repeated in this pass |

“Passed” means the resulting UI state was observed. The tab checks establish the
destination and path state, not separate animation phases or animation timing.

## Fixes found during this pass

- Replacing Classes with Inspector from a class detail initially left that old
  detail visible. Keying the demo's local navigation stack by the presentation
  ID now resets it when the sheet route changes. Requesting the same route retains
  its local navigation.
- Done initially disappeared after pushing a class. The detail now supplies the
  dismissal toolbar as well as the root.

These fixes belong to the consuming demo. This validation work did not change
Waypoint's library API or routing implementation.

## Unverified cases and limits

- iOS swipe dismissal: several automated downward drag attempts did not dismiss
  the sheet. This result does not establish whether the limitation is in gesture
  automation or runtime behavior; it needs a manual gesture check. Done dismissal
  and subsequent reopening passed.
- Physical devices, iPad layouts, minimum supported OS versions, multiple main
  windows, rapid overlapping actions, and every possible route sequence were not
  tested. Missing scene IDs and window forwarding failures were not exercised.
- Nested sheet presentation and automatic context selection were not exercised.
  The baseline router replaces its one sheet request; this demo does not stack sheets.

The task-owned simulator device and disposable build outputs were cleaned up.
Small build/test logs were retained outside the repository.


## Contextual integration pass

The working tree on `feat/nested-routing` now integrates `ContextRouter` into
Home, Library, and Single Stack through their existing Classes actions. The
baseline Local Classes and Inspector examples remain available. There is no
additional tab. Earlier baseline results above describe that earlier UI only.

Xcode 26.6 macOS and generic iOS Simulator Debug builds passed. All 14 package
tests passed (five baseline and nine contextual tests). Contextual tests cover
both fallbacks, existing-context reuse and identity, deepest matching context,
covered-parent routing, unrelated-sheet replacement, dismissal, and local calls.

Observed runtime results on macOS 27.0 and an isolated iPhone 17 / iOS 26.5:

| Scenario | macOS | iPhone simulator |
| --- | --- | --- |
| Through Classes creates a detail with Classes as its Back destination | Passed | Passed |
| Local Class button uses its sheet router and preserves sheet identity | Passed | Passed |
| Root requests reuse the existing Classes ID and append to its path | Passed | Passed |
| Child dismissal reveals the existing detail | Passed | Passed |
| Routing into covered Classes clears the cover and preserves Classes ID/path | Passed | Passed |
| Root override from a child dismisses the hierarchy and opens Library detail 99 | Passed | Passed |
| Direct fallback when Classes is absent creates a detail root with empty path and no parent Back | Passed | Passed |
| Direct fallback also reuses an existing named Classes context | State tests | Passed |
| Root request for Class 12 without visiting its row | Not repeated | Passed |
| Two nested child sheets: closing the deepest leaves the first child open | Not repeated | Passed |
| Explicit local push from a directly presented detail | Not repeated | Passed |
| Dismissed Classes is not reused by a later direct request (new sheet ID) | Passed | Passed |
| Final root controls leave the original three tabs accessible | Passed | Passed |
| Open and dismiss contextual Classes from Single Stack | Passed | Passed |
| Classes above Home detail returns to the unchanged presenting path | Earlier baseline only | Passed |
| Root Open class from baseline Inspector waits for dismissal | Not repeated | Passed in Library and Single Stack |
| Single Stack detail path survives Inspector → contextual Classes → Close | Not repeated | Passed |
| Reset from contextual Classes returns to Home | Not repeated | Passed |

The demo queues one root action across top-level dismissal. Controls are disabled
while waiting. Root override selects Library before replacing its path. A real
Shortcut, cold-launch delivery, automatic focused-window selection, and staged
“present Classes, then animate a push” are not implemented or claimed. The
through-parent fallback initializes the detail path; Back behavior is verified,
not a separate presentation-then-push animation.

No recordings were made. Physical devices, iPad, minimum OS versions, multiple
main windows, and iOS swipe dismissal remain unverified in this integration pass.


## Glass controls and iOS 27.1 pass

Built the working tree with Xcode 27.1 (27A9269) against its iOS Simulator SDK.
The generic iOS Simulator Debug build and all 14 package tests passed. The
control panel now uses a rounded floating Liquid Glass surface, a prominent
capsule Open class button, compact Reset icon, and secondary diagnostic text.
iOS 17–25 and macOS 14–25 retain a rounded material fallback. That fallback and
the updated macOS appearance were not runtime-tested in this pass.

Runtime checks used a task-owned iPhone Duo simulator running iOS 27.1
(24A94401), through Xcode 27.1's Device Hub. The installed 27.1 runtime supports
Duo only. First boot reported a migration failure, but installation and launch
subsequently succeeded and the following results were observed:

- Glass panel displayed in folded and unfolded layouts; all original tabs stayed
  accessible. Functional checks below ran unfolded.
- Through Classes opened Class 3 at depth 1; Back revealed Classes at depth 0.
- The local Class 3 button pushed into the same sheet ID.
- A child sheet opened and its Close button revealed the original Class 3.
- Root Open class from a covering child removed the child and appended into the
  same Classes sheet (depth 2, same ID).
- Root override from a child dismissed the hierarchy and opened Library detail
  99 with Home's path unchanged.
- Direct fallback opened Class 3 as a sheet root at depth 0 with no parent Back.
- Reset from the direct sheet returned to Home.
- Switch to Library, then push selected Library at Detail 1.
- Single Stack pushed Detail 1 and opened baseline Inspector. Root Open class
  waited for Inspector dismissal and presented contextual Class 3. Closing it
  returned to Single Stack Detail 1 with path depth 1 intact.

No full macOS rebuild, physical-device test, iOS 27.0 run, animation-timing
assertion, swipe-dismissal check, or multi-window test was performed in this
pass. Disposable compiled outputs and the task-owned simulator were removed
following validation; small build/test logs were retained outside the repo.


## Regular iPhone recording review takes — 2026-10-09

[17 unedited clips and playback gallery](../Resources/Recordings/ReviewTakes/individual-iphone-20261009/README.md) are
stored in the repository. Capture used a dedicated iPhone 18 Pro simulator on
iOS 27.0 (24A434), with Xcode 27.1. The installed iOS 27.1 runtime supports Duo
only; this regular iPhone pass therefore used 27.0.

B01–B10, C01–C06 and W04 were exercised with UI state checks before recording.
The current iOS Simulator build and 16 package tests passed after adding a
collapse control to the glass panel so W04's error result remains readable.
All 17 copied MP4 files decoded to their ends at 1206 × 2622. Selected
timestamped frames were reviewed; full final-cut playback review is pending.

These are unedited review takes. UI actions were issued
individually through Device Hub, so tool round trips introduce idle gaps within
clips. Some clips are earlier first takes; see the per-file manifest. Future retakes should
run each entire flow continuously, including actual scrolling and control taps,
with expected-state checks, synchronized capture, and deliberate readable holds.

B05 uses contextual Classes above Home Detail 1; B06–B10 use baseline local
Classes. C02 opens a sheet with an initialized parent/detail stack. C06 uses an in-app
root navigation trigger. W04 verifies the editor sheet fallback, retained draft, and
unsupported-window error.


## Continuous scripted iPhone recordings — 2026-10-09

The [main gallery](../Resources/Recordings/README.md) contains 17 passing takes:
B01–B10, C01–C06 and W04. `RecordingFlows.swift` executes each sequence with
actual taps, bounded list scrolling, native text selection/input, destination
checks, and route-state assertions. Capture starts after launch readiness and
finishes after the result hold. The selected clips total 306.9 seconds.

Build-for-testing and the UI runs used Xcode 27.1 (27A9269), an iPhone 18 Pro
simulator, and iOS 27.0 (24A434). The main run passed 15 flows. B01 and B04 first
failed while locating root diagnostics beneath the floating panel; the UI helper
now collapses that panel and scrolls the diagnostic into view. Both targeted
retakes passed. Package and demo runtime source hashes match across the runs;
the retake build compiled only the changed UI-test target. Each selected clip
records its originating manifest and source snapshot.

All 17 selected MP4s decoded to completion at 1206 × 2622. One-second samples
and the final frame were inspected across every timeline for visible actions,
transitions, and readable final state. Per-clip decoded frame counts, durations,
and maximum frame gaps are in
[media-validation.json](../Resources/Recordings/media-validation.json).
The simulator capture uses variable frame cadence in static scenes.

The opt-in missing-control probe produced a failed result, screenshot,
accessibility hierarchy, and a finalized, decodable video. Its evidence is in
`Resources/Recordings/ReviewTakes/pilot-scripted-03`. Source snapshots, logs,
step timestamps, and XCTest result bundles remain beside the recordings.

Validation for this implementation comprised build-for-testing, the 17 UI flow
checks with two targeted retakes, the deliberate failure diagnostic, media
decoding/frame review, and gallery/source checks. Package unit tests were last
run in the earlier integration pass; this pass adds UI recording infrastructure.


After validation, the task-owned build directory, module caches, and dedicated
recording simulator were removed. The reusable runner rebuilds with `--build`.
Recordings and useful XCTest evidence are retained under `Resources/Recordings`;
earlier takes are collected in `ReviewTakes`.

Retained media and evidence total 906 MB in `Resources/Recordings`, including
636 MB of earlier takes and pilot diagnostics in `ReviewTakes`. These preserve
the existing recordings and the runner’s failure evidence for comparison.


## Optimized release recordings — 2026-10-09

The 17 gallery clips were downscaled through Clop’s lossless encoder preset to
804 × 1748. All optimized files decoded to completion; representative text and
presentation frames were inspected. Updated media dimensions, durations, frame
counts, and SHA-256 hashes are recorded in the gallery’s metadata.

The optimized videos are distributed as GitHub Release assets. The repository
tracks the gallery, its lightweight metadata, scripts, and source. Original
captures and detailed validation artifacts remain locally in the ignored
`Resources/Recordings` subdirectories. The unpublished commit was amended before
pushing so those local artifacts are excluded from the branch history.


## Hosted recording gallery — 2026-10-09

The gallery is published at https://aeastr.github.io/Waypoint/ from the
`gh-pages` branch. Example titles in the main README link to the corresponding
gallery section. GitHub Pages reports a successful build. The hosted page,
index navigation, and inline C02 playback were checked in the browser.
`deploy-gallery.py` updates the page and metadata through the GitHub CLI.


## Inline video delivery

The Pages workflow assembles the gallery with checksum-verified MP4s fetched
from the recordings release. The deployment artifact serves those videos at
`/Waypoint/videos/` with `Content-Type: video/mp4` and byte-range support.
The workflow completed successfully; B01 returned HTTP 206 for a two-byte range
request and played in the in-app browser. Safari playback verification remains
pending because the Mac was locked during that check.
