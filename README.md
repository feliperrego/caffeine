# Caffeine

A macOS menubar app to manage the `caffeinate` command — keep your Mac awake
with preset timers (15 min, 30 min, 1 hour, Infinite).

## Build

Requires Swift 6 toolchain (Command Line Tools is enough — no full Xcode).

```bash
./build.sh
open Caffeine.app
```

To install, drag `Caffeine.app` into `/Applications`.

## Features

- Preset timers with visible countdown
- State-aware menubar icon
- Configurable keep-awake mode (display only / display + system) in Settings
- Launch at login

## Development

```bash
swift test      # run unit tests
swift run Caffeine   # run without bundling
```

## Known limitations

- The app uses the default system app icon in Finder / Login Items (no custom
  `.icns` bundled yet). The menubar icon itself is an SF Symbol and works.
- Changing the keep-awake mode in Settings applies to the next activation; if
  a timer is already running, the current session keeps the mode it started
  with.
