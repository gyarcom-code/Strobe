# Strobe

Empty SwiftUI scaffold for the Strobe iOS app. No features yet — just a blank
`Color(.systemBackground)` screen wired up through a standard `@main App`
entry point, ready to build on.

- **Bundle identifier:** `com.gyarcom.Strobe` (default placeholder — change
  `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` when you have a real one).
- **Minimum iOS version:** 18.0.
- **UI framework:** SwiftUI, `App` lifecycle (no Storyboards/UIKit).

## Getting started

The `.xcodeproj` is generated from `project.yml` via
[XcodeGen](https://github.com/yonaskolb/XcodeGen) and is committed for
convenience. If you change `project.yml`, regenerate it before opening:

```sh
brew install xcodegen   # if you don't have it yet
xcodegen generate
open Strobe.xcodeproj
```

## Project layout

```
Strobe/
  project.yml                     # XcodeGen project spec
  Sources/Strobe/
    StrobeApp.swift                # @main App entry point
    ContentView.swift              # blank root view
    Info.plist                     # target's Info.plist (INFOPLIST_FILE)
  .gitignore
  README.md
```
