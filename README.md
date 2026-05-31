# 👀 SwiftEyes

A lightweight macOS menu bar app that displays a pair of googly eyes that follow your mouse cursor, blink when you click, and provide quick utilities.

Inspired by [Googly Eyes](https://sindresorhus.com/googly-eyes) by Sindre Sorhus.

[中文文档](README_CN.md)

![macOS 13+](https://img.shields.io/badge/macOS-13.0+-blue)

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
- **Minimal resources** — ~0% CPU when idle, ~55MB memory (Release build)

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
| ↳ 当前路径 / Copy Path | Show & copy Finder's front window path |
| ↳ 在此打开终端 | Open terminal at Finder path |
| ↳ 防睡眠: 开启/关闭 | Toggle sleep prevention |
| ↳ 设置 | Open settings window |
| ↳ 退出 | Quit app |

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
| ![Left Button Clicked](docs/Left%20Button%20Clicked.png) | ![Prevent Sleep](docs/Prevent%20Sleep.png) | ![Setting](docs/Setting.png) |

## Settings

| Setting | Default | Range |
|---------|---------|-------|
| Eye size | 11 | 6–18 |
| Pupil size | 5 | 2–10 |
| Eye gap | 6 | 0–20 |
| Terminal app | Terminal.app | Any .app path |
| Launch at login | Off | On/Off |

## Architecture

```
Sources/SwiftEyes/
├── SwiftEyesApp.swift              # @main entry + AppDelegate
├── StatusBar/
│   └── StatusBarController.swift   # NSStatusItem + NSHostingView + context menu
├── Views/
│   ├── GooglyEyesView.swift        # NSView-based eye drawing (Core Graphics)
│   ├── SettingsView.swift          # SwiftUI settings form
│   └── SettingsWindowController.swift  # NSWindow management
└── Services/
    ├── EyesConfig.swift            # ObservableObject for eye parameters
    ├── EyesState.swift             # Blink & active state (global monitors)
    ├── MouseTracker.swift          # Global mouse tracking (throttled)
    ├── TerminalLauncher.swift      # Finder path + terminal launch
    └── SleepPreventer.swift        # IOKit IOPMAssertion
```

### Key Design Decisions

- **NSView drawing** instead of SwiftUI Canvas — avoids SwiftUI re-render overhead; `needsDisplay` triggered only on actual state change
- **Mouse tracking throttled at ~12fps** with change deduplication — minimizes CPU usage
- **IOKit assertion** held only while sleep prevention is active; released immediately on toggle off
- **AppleScript** for Finder path executed only on user action, never polled
- **`NSApp.setActivationPolicy(.regular)`** temporarily when settings window opens, `.accessory` when closed — keeps the app out of the Dock while allowing settings to come to front

## License

[MIT](LICENSE)
