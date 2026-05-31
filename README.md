# 👀 SwiftEyes

A lightweight macOS menu bar app that displays a pair of googly eyes that follow your mouse cursor, blink when you click, and provide quick utilities.

Inspired by [Googly Eyes](https://sindresorhus.com/googly-eyes) by Sindre Sorhus.

[中文文档](README_CN.md)

<img src="docs/Icon.png" width="128">

![macOS 13+](https://img.shields.io/badge/macOS-13.0+-blue)

![Normal1](docs/Normal1.png) ![Normal2](docs/Normal2.png) ![Normal3](docs/Normal3.png)

## Features

- **Eyes follow mouse** — Each eye independently tracks the mouse cursor; when the cursor is between the eyes, they go cross-eyed 👀
- **Blink on click** — Left-click anywhere → left eye blinks; right-click → right eye blinks. Hold to keep closed, release to open
- **Left eye → Open Terminal** — Click the left eye to launch your preferred terminal at the Finder's current window path
- **Right eye → Prevent Sleep** — Click the right eye to toggle macOS sleep prevention (highlighted with a red glow when active)
- **Context menu** — Right-click the menu bar icon for:
  - Current Finder path display & copy
  - Open terminal here
  - Toggle sleep prevention
  - Settings
  - Quit
- **Configurable** — Adjust eye size, pupil size, and eye gap via Settings
- **Launch at Login** — Enable auto-start in Settings (requires .app bundle)
- **Minimal resources** — ~0% CPU when idle

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15+ (for .app bundle build)
- Swift 5.9+ / SPM (for bare binary build)

## Build & Run

### Option 1: SPM (Quick Test, No App Bundle)

```bash
git clone https://github.com/WHYBBE/SwiftEyes.git
cd SwiftEyes
swift build -c release
.build/release/SwiftEyes
```

> ⚠️ SPM produces a bare binary without an app bundle. Launch-at-login and Finder path access via Apple Events will not work in this mode.

### Option 2: Xcode (Full .app Bundle, Recommended)

```bash
cd SwiftEyes
open SwiftEyes.xcodeproj
```

Build & run from Xcode (⌘R). Or from the command line:

```bash
xcodebuild -project SwiftEyes.xcodeproj -scheme SwiftEyes -configuration Release -derivedDataPath .build/xcode build
open .build/xcode/Build/Products/Release/SwiftEyes.app
```

To install:

```bash
cp -r .build/xcode/Build/Products/Release/SwiftEyes.app /Applications/
```

## Usage

| Action | Effect |
|--------|--------|
| Move mouse | Pupils follow cursor direction |
| Left-click (anywhere) | Left eye blinks (hold to keep closed) |
| Right-click (anywhere) | Right eye blinks (hold to keep closed) |
| Click left eye area on menu bar | Toggle: open terminal at Finder path |
| Click right eye area on menu bar | Toggle: prevent Mac from sleeping |
| Right-click menu bar icon | Context menu |
| **Context menu** | |
| ↳ Current Path / Copy Path | Show & copy Finder's front window path |
| ↳ Open Terminal Here | Open terminal at Finder path |
| ↳ Prevent Sleep: On/Off | Toggle sleep prevention |
| ↳ Settings | Open settings window |
| ↳ Quit | Quit app |

## Visual Indicators

| State | Left Eye | Right Eye |
|-------|----------|-----------|
| Default | Black pupil, white highlight | Black pupil, white highlight |
| Active (terminal opened) | — | — |
| Active (sleep prevention ON) | — | Red pupil + red glow + red highlight |

> The left eye is a one-shot action (open terminal), so it has no persistent active state. The right eye shows a red glow while sleep prevention is active.

### Screenshots

| Left-click blink | Prevent sleep (red glow) | Settings |
|---|---|---|
| ![Left Button Clicked](docs/Left%20Button%20Clicked.png) | ![Prevent Sleep](docs/Prevent%20Sleep.png) | ![Setting](docs/Setting-en.png) |

## Settings

| Setting | Default | Range |
|---------|---------|-------|
| Eye size | 11 | 6–18 |
| Pupil size | 5 | 2–10 |
| Eye gap | 6 | 0–20 |
| Terminal app | Terminal.app | Any .app path |
| Language | 中文 | 中文 / English |
| Launch at login | Off | On/Off |

## Architecture

```
Sources/SwiftEyes/
├── SwiftEyesApp.swift              # @main entry + AppDelegate
├── Assets.xcassets/               # App icon & asset catalog
├── StatusBar/
│   └── StatusBarController.swift   # NSStatusItem + GooglyEyesNSView + context menu
├── Views/
│   ├── GooglyEyesView.swift        # NSView-based eye drawing (Core Graphics)
│   ├── SettingsView.swift          # SwiftUI settings form
│   └── SettingsWindowController.swift  # NSWindow management
└── Services/
    ├── EyesConfig.swift            # ObservableObject for eye parameters
    ├── EyesState.swift             # Blink & active state (global monitors)
    ├── MouseTracker.swift          # Global mouse tracking (throttled)
    ├── TerminalLauncher.swift      # Finder path + terminal launch
    ├── SleepPreventer.swift        # IOKit IOPMAssertion
    └── L10n.swift                  # Localization (Chinese / English)
```

### Key Design Decisions

- **NSView + Core Graphics** — Direct drawing via `NSView.draw()` with `needsDisplay`, no SwiftUI diffing or hosting layer overhead
- **Throttled mouse tracking** — Global `NSEvent` monitor at ~12fps with offset deduplication; `onOffsetChanged` callback triggers redraw only when pupil position actually changes
- **No Combine in hot path** — `MouseTracker` and `EyesState` use plain properties + callbacks instead of `@Published`/`ObservableObject`, eliminating Combine pipeline overhead per frame
- **Coalesced layout updates** — `scheduleUpdateEyeCenters()` batches same-runloop coordinate recalculations when dragging settings sliders
- **IOKit assertion** — `IOPMAssertionCreateWithName` held only while sleep prevention is active; released immediately on toggle off
- **Cached AppleScript** — Finder path result cached with 2-second TTL; AppleScript never executed on idle
- **Static CGColor constants** — Eye colors pre-converted to `CGColor` once, avoiding per-frame `NSColor.cgColor` bridging
- **`NSApp.setActivationPolicy(.regular)`** temporarily when settings window opens, `.accessory` when closed — keeps the app out of the Dock while allowing settings to come to front
- **L10n dictionary** — In-memory translation table keyed by language code, no .strings files; `language` persisted via UserDefaults

## License

[MIT](LICENSE)
