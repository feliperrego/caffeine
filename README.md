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
