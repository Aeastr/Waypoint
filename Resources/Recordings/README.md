# Scripted iPhone recordings

17 scripted routing flows · iPhone 18 Pro · iOS 27.0

Open [the playback gallery](https://aeastr.github.io/Waypoint/), or select a clip:

- [B01 — Push, push, and return](https://aeastr.github.io/Waypoint/#B01) · 15.9s
  Push two Home details, go Back to Detail 1, then return to the root. The visible path follows each navigation step.
- [B02 — Switch tab, then push](https://aeastr.github.io/Waypoint/#B02) · 5.8s
  Select Library and open Detail 1 through a single app action, while Home keeps its empty path.
- [B03 — Independent tab histories](https://aeastr.github.io/Waypoint/#B03) · 16.6s
  Build different stacks in Home and Library, then switch between them. Each tab returns to its own detail.
- [B04 — Prepare an unselected tab](https://aeastr.github.io/Waypoint/#B04) · 23.2s
  Prepare Library’s stack from Home, visit its details, then clear its history and return to Library’s root.
- [B05 — Present and dismiss a sheet](https://aeastr.github.io/Waypoint/#B05) · 6.7s
  Open contextual Classes above Home Detail 1, then close the sheet and return to the same Home detail.
- [B06 — Replace an open sheet](https://aeastr.github.io/Waypoint/#B06) · 13.4s
  Replace local Classes with Inspector, return to the Classes list, then dismiss the sheet.
- [B07 — Replace a sheet from its detail](https://aeastr.github.io/Waypoint/#B07) · 15.6s
  Open Class 3 inside local Classes, replace the sheet with Inspector, then return to Classes at its list root.
- [B08 — Local navigation inside a sheet](https://aeastr.github.io/Waypoint/#B08) · 13.9s
  Use app-owned SwiftUI navigation to open Class 3, go Back, open it again, and close the Waypoint-presented sheet.
- [B09 — Dismiss and reopen](https://aeastr.github.io/Waypoint/#B09) · 14.6s
  Close local Classes from Class 3, then reopen the sheet. The reopened sheet starts at the Classes list.
- [B10 — Replace a sheet with Utility](https://aeastr.github.io/Waypoint/#B10) · 11.5s
  Request Utility from a local Class 3 detail. Utility replaces the sheet content on iPhone; closing it returns to Home.
- [C01 — Router-driven navigation in a sheet](https://aeastr.github.io/Waypoint/#C01) · 11.9s
  Push Class 3 through the Classes context router, then go Back. The sheet keeps the same identity as its path changes.
- [C02 — Open a class through its parent](https://aeastr.github.io/Waypoint/#C02) · 7.0s
  Request Class 3 from Home. The sheet opens with an initialized Classes → Class 3 stack, and Back reveals the Classes list.
- [C03 — Open a class directly](https://aeastr.github.io/Waypoint/#C03) · 10.7s
  Choose Direct detail and request Class 3. It opens as the sheet’s root page; closing it returns to Home.
- [C04 — Reuse the existing context](https://aeastr.github.io/Waypoint/#C04) · 17.5s
  Open Classes, then request Class 3 and Class 4 through the root controls. Both pushes use the same sheet identity and context.
- [C05 — Present a nested sheet](https://aeastr.github.io/Waypoint/#C05) · 21.9s
  Present a child Inspector from Class 3. Close the child to reveal the same Class 3 stack, then close Classes to return to Home.
- [C06 — Route through the root override](https://aeastr.github.io/Waypoint/#C06) · 11.1s
  Invoke the demo’s root override while Class 3 is open. Classes dismisses, Library becomes selected, and Detail 99 appears.
- [W04 — Editor fallback on iPhone](https://aeastr.github.io/Waypoint/#W04) · 50.4s
  Edit a draft in the sheet fallback, review it, and reopen it with the text retained. Repeat the unavailable-window request and check that its pending state clears.

[Run manifest](manifest.json) · [Step timestamps](steps.jsonl)
