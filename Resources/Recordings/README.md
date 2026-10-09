# Scripted iPhone recordings

17 scripted routing flows · iPhone 18 Pro · iOS 27.0

Open [the playback gallery](https://aeastr.github.io/Waypoint/), or select a clip:

- [B01 — Push, push, and return](https://github.com/Aeastr/Waypoint/releases/download/demo-recordings-2026-10-09/b01-stack-navigation.mp4) · 15.9s
  Push two Home details, go Back to Detail 1, then return to the root. The visible path follows each navigation step.
- [B02 — Switch tab, then push](https://github.com/Aeastr/Waypoint/releases/download/demo-recordings-2026-10-09/b02-switch-then-push.mp4) · 5.8s
  Select Library and open Detail 1 through a single app action, while Home keeps its empty path.
- [B03 — Independent tab histories](https://github.com/Aeastr/Waypoint/releases/download/demo-recordings-2026-10-09/b03-independent-tab-history.mp4) · 16.6s
  Build different stacks in Home and Library, then switch between them. Each tab returns to its own detail.
- [B04 — Prepare an unselected tab](https://github.com/Aeastr/Waypoint/releases/download/demo-recordings-2026-10-09/b04-background-tab-routing.mp4) · 23.2s
  Prepare Library’s stack from Home, visit its details, then clear its history and return to Library’s root.
- [B05 — Present and dismiss a sheet](https://github.com/Aeastr/Waypoint/releases/download/demo-recordings-2026-10-09/b05-sheet-round-trip.mp4) · 6.7s
  Open contextual Classes above Home Detail 1, then close the sheet and return to the same Home detail.
- [B06 — Replace an open sheet](https://github.com/Aeastr/Waypoint/releases/download/demo-recordings-2026-10-09/b06-sheet-replacement.mp4) · 13.4s
  Replace local Classes with Inspector, return to the Classes list, then dismiss the sheet.
- [B07 — Replace a sheet from its detail](https://github.com/Aeastr/Waypoint/releases/download/demo-recordings-2026-10-09/b07-replace-sheet-from-detail.mp4) · 15.6s
  Open Class 3 inside local Classes, replace the sheet with Inspector, then return to Classes at its list root.
- [B08 — Local navigation inside a sheet](https://github.com/Aeastr/Waypoint/releases/download/demo-recordings-2026-10-09/b08-local-sheet-navigation.mp4) · 13.9s
  Use app-owned SwiftUI navigation to open Class 3, go Back, open it again, and close the Waypoint-presented sheet.
- [B09 — Dismiss and reopen](https://github.com/Aeastr/Waypoint/releases/download/demo-recordings-2026-10-09/b09-dismiss-and-reopen.mp4) · 14.6s
  Close local Classes from Class 3, then reopen the sheet. The reopened sheet starts at the Classes list.
- [B10 — Replace a sheet with Utility](https://github.com/Aeastr/Waypoint/releases/download/demo-recordings-2026-10-09/b10-sheet-to-utility-ios.mp4) · 11.5s
  Request Utility from a local Class 3 detail. Utility replaces the sheet content on iPhone; closing it returns to Home.
- [C01 — Router-driven navigation in a sheet](https://github.com/Aeastr/Waypoint/releases/download/demo-recordings-2026-10-09/c01-router-push-in-sheet.mp4) · 11.9s
  Push Class 3 through the Classes context router, then go Back. The sheet keeps the same identity as its path changes.
- [C02 — Open a class through its parent](https://github.com/Aeastr/Waypoint/releases/download/demo-recordings-2026-10-09/c02-open-class-through-parent.mp4) · 7.0s
  Request Class 3 from Home. The sheet opens with an initialized Classes → Class 3 stack, and Back reveals the Classes list.
- [C03 — Open a class directly](https://github.com/Aeastr/Waypoint/releases/download/demo-recordings-2026-10-09/c03-open-class-directly.mp4) · 10.7s
  Choose Direct detail and request Class 3. It opens as the sheet’s root page; closing it returns to Home.
- [C04 — Reuse the existing context](https://github.com/Aeastr/Waypoint/releases/download/demo-recordings-2026-10-09/c04-reuse-existing-context.mp4) · 17.5s
  Open Classes, then request Class 3 and Class 4 through the root controls. Both pushes use the same sheet identity and context.
- [C05 — Present a nested sheet](https://github.com/Aeastr/Waypoint/releases/download/demo-recordings-2026-10-09/c05-nested-sheet.mp4) · 21.9s
  Present a child Inspector from Class 3. Close the child to reveal the same Class 3 stack, then close Classes to return to Home.
- [C06 — Route through the root override](https://github.com/Aeastr/Waypoint/releases/download/demo-recordings-2026-10-09/c06-external-root-override.mp4) · 11.1s
  Invoke the demo’s root override while Class 3 is open. Classes dismisses, Library becomes selected, and Detail 99 appears.
- [W04 — Editor fallback on iPhone](https://github.com/Aeastr/Waypoint/releases/download/demo-recordings-2026-10-09/w04-iphone-editor-fallback.mp4) · 50.4s
  Edit a draft in the sheet fallback, review it, and reopen it with the text retained. Repeat the unavailable-window request and check that its pending state clears.

[Run manifest](manifest.json) · [Step timestamps](steps.jsonl)
