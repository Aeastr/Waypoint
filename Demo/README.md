# Waypoint Lab

A small iOS 17+ and macOS 14+ app for exercising Waypoint's current public API.
It links the local package at `..` and has no external dependencies.

Open `WaypointDemo.xcodeproj`, choose the shared **WaypointDemo** scheme, select
**My Mac** or an iOS simulator, and run. Use Xcode with Swift 6.2 or later. To run
on an iPhone or iPad, select your own development team under Signing & Capabilities.

## Manual checks

- **Stacks:** Push several details, use the system Back control, pop explicitly,
  return to root, and replace a path with two details. The live state should match.
- **Tabs:** Push in Home and Library, then switch between them. Each history should
  survive. Prepare Library's path from Home without switching, then visit Library.
  Clear the other tab's history and confirm only that path resets.
- **Standalone router:** Use Single Stack to exercise `Router` independently of
  `TabRouter`. Push, replace, pop, and return to root there too.
- **Sheets:** Open Classes from a root or a detail. Push a class using its local
  navigation stack, go back, and dismiss with Done. On iOS, also swipe to dismiss.
  Reopen the same sheet and open Inspector afterward; the root stack should remain.
- **Windows:** On macOS, open Utility from a root or detail, close it, and request
  it again. A cleared pending window request means it was forwarded, not that the
  window closed. On iOS, Utility should appear as a sheet instead.

The Classes sheet deliberately uses an app-owned navigation stack. This baseline
does not implement automatic routing into the active sheet or window. SettingsKit
composition is documented in the package's integration guide; it is not a demo
dependency.

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
