# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Strobe is an iOS SwiftUI app that turns the device flashlight into a
strobe light: pick a frequency (1–50 Hz) and toggle it on/off.

## Commands

The `.xcodeproj` is generated from `project.yml` via [XcodeGen](https://github.com/yonaskolb/XcodeGen)
and is committed. **After changing `project.yml` or adding/removing files
under `Sources/Strobe/`, regenerate it before building:**

```sh
xcodegen generate
```

Build for the simulator:

```sh
xcodebuild -project Strobe.xcodeproj -scheme Strobe -destination 'generic/platform=iOS Simulator' build
```

Build, install, and launch on a connected physical device (needed to
actually test the torch — the Simulator has no flashlight, so
`isTorchAvailable` is always `false` there):

```sh
xcrun devicectl list devices   # get the device id
xcodebuild -project Strobe.xcodeproj -scheme Strobe -destination 'id=<DEVICE_ID>' -allowProvisioningUpdates -derivedDataPath build_device build
xcrun devicectl device install app --device <DEVICE_ID> "build_device/Build/Products/Debug-iphoneos/Strobe.app"
xcrun devicectl device process launch --device <DEVICE_ID> com.gyarcom.Strobe
```

There is no test target in this project.

### Code signing gotcha

`project.yml` pins `DEVELOPMENT_TEAM: 6RWV5L4XXV` (personal team) with
`CODE_SIGN_STYLE: Automatic`. Device builds fail with `No Account for
Team "..."` if Xcode's account/profile cache has gone stale (this
happens after `xcodegen generate` rewrites the `.xcodeproj`, or after
Xcode is restarted) — even though `xcodebuild -allowProvisioningUpdates`
is passed. When that happens, the fix is to open the project in Xcode.app
and trigger a build from the GUI (Product ▸ Run) once; that refreshes the
provisioning profile in `~/Library/Developer/Xcode/UserData/Provisioning
Profiles/`, after which `xcodebuild` from the CLI works again.

## Architecture

All app code lives in `Sources/Strobe/`, referenced from `project.yml`
as the target's source path (no Xcode groups to keep in sync manually —
just add files to the folder and re-run `xcodegen generate`).

- **`StrobeController.swift`** — the entire flashlight/timing model, as
  an `ObservableObject`. This is the only place that touches
  `AVCaptureDevice`. All torch hardware calls (`lockForConfiguration`,
  `torchMode`) are serialized on a single private `DispatchQueue`
  (`queue`) via a `DispatchSourceTimer`, not `Timer`, to minimize
  jitter. `@Published` properties (`isStrobing`, `frequencyHz`,
  `isTorchAvailable`, `errorMessage`) are the only state `ContentView`
  reads; UI-facing mutations of them are dispatched back to the main
  thread.
  - `frequencyHz` has a `didSet` that calls `restartTimer()` live
    whenever the value changes while `isStrobing` is true — the picker
    is never disabled, changing it while strobing retunes the running
    timer immediately instead of requiring a stop/start cycle.
  - `start()`/`restartTimer()`/`stop()` are the only entry points that
    touch the timer; `restartTimer()` is shared by both the initial
    start and live frequency changes to keep that logic in one place.
  - Frequency N Hz means N full on/off cycles/sec, i.e. the timer fires
    every `1 / (2N)` seconds. Above ~10–15 Hz this is best-effort:
    `AVCaptureDevice.torchMode` switching latency means the real-world
    flicker rate can drift from the requested value — the UI does not
    claim precision.
  - No camera usage description is needed in `Info.plist`: this only
    calls `AVCaptureDevice` torch APIs, never starts an
    `AVCaptureSession`, so it doesn't trigger the camera permission
    prompt.

- **`ContentView.swift`** — single-screen UI. Background/button colors
  are a hard swap between black (off) and mustard (`Color.mustard`,
  on) driven by `strobeController.isStrobing`, with
  `.preferredColorScheme` pinned to `.dark`/`.light` per state (not the
  system setting) so native controls like the wheel `Picker` stay
  readable against whichever color is currently the background. Torch
  is force-stopped via `.onChange(of: scenePhase)` when the app
  backgrounds.

- **`Color+Mustard.swift`** — the one custom brand color (`#E1AD01`),
  fixed regardless of system light/dark mode.

- **`Assets.xcassets/AppIcon.appiconset`** — single 1024×1024 source
  image (`AppIcon.jpeg`), using the modern single-size app icon format
  (Xcode generates all needed sizes at build time). The source image
  file also lives at the repo root (`IconStrobe.jpeg`) — when it
  changes, copy it into the appiconset and rebuild:
  ```sh
  cp IconStrobe.jpeg Sources/Strobe/Assets.xcassets/AppIcon.appiconset/AppIcon.jpeg
  ```

- **`Info.plist`** — hand-written (not Xcode-generated;
  `GENERATE_INFOPLIST_FILE: NO` / `INFOPLIST_FILE` in `project.yml`
  points at it), so new keys must be added here directly.
