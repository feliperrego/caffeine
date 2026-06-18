# Caffeine Menubar App — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menubar app that manages the `caffeinate` command with preset timers (15min, 30min, 1h, Infinite), state-aware icon, visible countdown, configurable keep-awake mode, and launch-at-login.

**Architecture:** Swift Package Manager workspace with a testable `CaffeineCore` library (models, controller, preferences, process abstraction) and a thin `Caffeine` executable (AppKit `NSStatusItem`/`NSMenu` glue). The keep-awake mechanism shells out to `/usr/bin/caffeinate` via `Foundation.Process`, abstracted behind a protocol so the controller is unit-testable. A `build.sh` packages the release binary into a `Caffeine.app` bundle.

**Tech Stack:** Swift 6.3 (Command Line Tools only — no full Xcode), AppKit, ServiceManagement (`SMAppService`), XCTest, Swift Package Manager.

## Global Constraints

- Target platform: `macOS 13` minimum (`SMAppService` requires macOS 13+). Dev machine is macOS 26.5.
- Build with Command Line Tools only — no `xcodebuild`, no `.xcodeproj`. Use `swift build` / `swift test`.
- Core logic lives in the `CaffeineCore` library target; the `Caffeine` executable target contains only AppKit glue + `main.swift`.
- All public core types declared `public`; controller and AppKit types are `@MainActor`.
- The `caffeinate` binary path is exactly `/usr/bin/caffeinate`.
- Preset titles (exact, English to match the reference UI): `"15 minutes"`, `"30 minutes"`, `"1 hour"`, `"Infinite"`.
- Mode titles (exact): `"Só a tela"` (`displayOnly`), `"Tela + sistema"` (`displaySystem`).
- Bundle identifier: `com.felipe.caffeine`. App name: `Caffeine`.
- Test framework: XCTest.

---

### Task 1: SPM scaffold + domain models

**Files:**
- Create: `Package.swift`
- Create: `Sources/CaffeineCore/CaffeinateMode.swift`
- Create: `Sources/CaffeineCore/CaffeinatePreset.swift`
- Test: `Tests/CaffeineCoreTests/ModelsTests.swift`

**Interfaces:**
- Produces:
  - `enum CaffeinateMode: String, CaseIterable, Sendable` with `var flags: [String]` and `var title: String`
  - `enum CaffeinatePreset: CaseIterable, Equatable, Sendable` with `var seconds: Int?` and `var title: String`

- [ ] **Step 1: Create `Package.swift`**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Caffeine",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "CaffeineCore"),
        .executableTarget(name: "Caffeine", dependencies: ["CaffeineCore"]),
        .testTarget(name: "CaffeineCoreTests", dependencies: ["CaffeineCore"]),
    ]
)
```

- [ ] **Step 2: Create the executable's `main.swift` placeholder so the package builds**

Create `Sources/Caffeine/main.swift`:

```swift
// Replaced with AppKit setup in Task 6.
print("Caffeine")
```

- [ ] **Step 3: Write the failing test**

Create `Tests/CaffeineCoreTests/ModelsTests.swift`:

```swift
import XCTest
@testable import CaffeineCore

final class ModelsTests: XCTestCase {
    func testDisplayOnlyFlags() {
        XCTAssertEqual(CaffeinateMode.displayOnly.flags, ["-d"])
    }

    func testDisplaySystemFlags() {
        XCTAssertEqual(CaffeinateMode.displaySystem.flags, ["-d", "-i"])
    }

    func testPresetSeconds() {
        XCTAssertEqual(CaffeinatePreset.minutes15.seconds, 900)
        XCTAssertEqual(CaffeinatePreset.minutes30.seconds, 1800)
        XCTAssertEqual(CaffeinatePreset.hour1.seconds, 3600)
        XCTAssertNil(CaffeinatePreset.infinite.seconds)
    }

    func testPresetTitles() {
        XCTAssertEqual(CaffeinatePreset.minutes15.title, "15 minutes")
        XCTAssertEqual(CaffeinatePreset.infinite.title, "Infinite")
    }

    func testAllPresetsCovered() {
        XCTAssertEqual(CaffeinatePreset.allCases.count, 4)
    }
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `swift test`
Expected: FAIL — `CaffeinateMode` / `CaffeinatePreset` not found (compile error).

- [ ] **Step 5: Implement `CaffeinateMode`**

Create `Sources/CaffeineCore/CaffeinateMode.swift`:

```swift
public enum CaffeinateMode: String, CaseIterable, Sendable {
    case displayOnly
    case displaySystem

    public var flags: [String] {
        switch self {
        case .displayOnly: return ["-d"]
        case .displaySystem: return ["-d", "-i"]
        }
    }

    public var title: String {
        switch self {
        case .displayOnly: return "Só a tela"
        case .displaySystem: return "Tela + sistema"
        }
    }
}
```

- [ ] **Step 6: Implement `CaffeinatePreset`**

Create `Sources/CaffeineCore/CaffeinatePreset.swift`:

```swift
public enum CaffeinatePreset: CaseIterable, Equatable, Sendable {
    case minutes15
    case minutes30
    case hour1
    case infinite

    public var seconds: Int? {
        switch self {
        case .minutes15: return 15 * 60
        case .minutes30: return 30 * 60
        case .hour1: return 60 * 60
        case .infinite: return nil
        }
    }

    public var title: String {
        switch self {
        case .minutes15: return "15 minutes"
        case .minutes30: return "30 minutes"
        case .hour1: return "1 hour"
        case .infinite: return "Infinite"
        }
    }
}
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `swift test`
Expected: PASS — all `ModelsTests` green, package builds.

- [ ] **Step 8: Add `.gitignore` and commit**

Create `.gitignore`:

```
.build/
*.app
.DS_Store
```

```bash
git add Package.swift Sources/ Tests/ .gitignore
git commit -m "feat: SPM scaffold with CaffeinateMode and CaffeinatePreset models"
```

---

### Task 2: caffeinate argument builder

**Files:**
- Create: `Sources/CaffeineCore/CaffeinateArguments.swift`
- Test: `Tests/CaffeineCoreTests/CaffeinateArgumentsTests.swift`

**Interfaces:**
- Consumes: `CaffeinateMode`, `CaffeinatePreset` (Task 1)
- Produces: `public func caffeinateArguments(mode: CaffeinateMode, preset: CaffeinatePreset) -> [String]`

- [ ] **Step 1: Write the failing test**

Create `Tests/CaffeineCoreTests/CaffeinateArgumentsTests.swift`:

```swift
import XCTest
@testable import CaffeineCore

final class CaffeinateArgumentsTests: XCTestCase {
    func testTimedDisplayOnly() {
        let args = caffeinateArguments(mode: .displayOnly, preset: .minutes15)
        XCTAssertEqual(args, ["-d", "-t", "900"])
    }

    func testTimedDisplaySystem() {
        let args = caffeinateArguments(mode: .displaySystem, preset: .hour1)
        XCTAssertEqual(args, ["-d", "-i", "-t", "3600"])
    }

    func testInfiniteHasNoTimeFlag() {
        let args = caffeinateArguments(mode: .displayOnly, preset: .infinite)
        XCTAssertEqual(args, ["-d"])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter CaffeinateArgumentsTests`
Expected: FAIL — `caffeinateArguments` not found.

- [ ] **Step 3: Implement the function**

Create `Sources/CaffeineCore/CaffeinateArguments.swift`:

```swift
public func caffeinateArguments(mode: CaffeinateMode, preset: CaffeinatePreset) -> [String] {
    var args = mode.flags
    if let seconds = preset.seconds {
        args.append("-t")
        args.append(String(seconds))
    }
    return args
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter CaffeinateArgumentsTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/CaffeineCore/CaffeinateArguments.swift Tests/CaffeineCoreTests/CaffeinateArgumentsTests.swift
git commit -m "feat: caffeinate argument builder"
```

---

### Task 3: Process abstraction + CaffeineController

**Files:**
- Create: `Sources/CaffeineCore/CaffeinateProcess.swift`
- Create: `Sources/CaffeineCore/CaffeineController.swift`
- Create: `Tests/CaffeineCoreTests/FakeCaffeinateProcess.swift`
- Test: `Tests/CaffeineCoreTests/CaffeineControllerTests.swift`

**Interfaces:**
- Consumes: `CaffeinateMode`, `CaffeinatePreset`, `caffeinateArguments` (Tasks 1–2)
- Produces:
  - `protocol CaffeinateProcess: AnyObject { var isRunning: Bool { get }; func launch(arguments: [String], terminationHandler: @escaping @Sendable () -> Void); func terminate() }`
  - `@MainActor final class CaffeineController` with:
    - `init(mode: CaffeinateMode = .displayOnly, processFactory: @escaping () -> CaffeinateProcess)`
    - `var mode: CaffeinateMode`
    - `var onStateChange: (() -> Void)?`
    - `private(set) var isActive: Bool`
    - `private(set) var activePreset: CaffeinatePreset?`
    - `private(set) var remainingSeconds: Int?`
    - `func start(preset: CaffeinatePreset)`, `func stop()`, `func toggle(preset: CaffeinatePreset)`, `func tick()`
    - `func handleProcessExit()` (internal — for external-termination handling)

- [ ] **Step 1: Create the process protocol**

Create `Sources/CaffeineCore/CaffeinateProcess.swift`:

```swift
public protocol CaffeinateProcess: AnyObject {
    var isRunning: Bool { get }
    func launch(arguments: [String], terminationHandler: @escaping @Sendable () -> Void)
    func terminate()
}
```

- [ ] **Step 2: Create the test fake**

Create `Tests/CaffeineCoreTests/FakeCaffeinateProcess.swift`:

```swift
import CaffeineCore

final class FakeCaffeinateProcess: CaffeinateProcess {
    private(set) var launchedArguments: [String]?
    private(set) var terminateCalled = false
    var isRunning = false
    private var handler: (() -> Void)?

    func launch(arguments: [String], terminationHandler: @escaping @Sendable () -> Void) {
        launchedArguments = arguments
        isRunning = true
        handler = terminationHandler
    }

    func terminate() {
        terminateCalled = true
        isRunning = false
    }

    func simulateExit() {
        isRunning = false
        handler?()
    }
}
```

- [ ] **Step 3: Write the failing test**

Create `Tests/CaffeineCoreTests/CaffeineControllerTests.swift`:

```swift
import XCTest
@testable import CaffeineCore

@MainActor
final class CaffeineControllerTests: XCTestCase {
    func testStartLaunchesWithCorrectArguments() {
        let fake = FakeCaffeinateProcess()
        let controller = CaffeineController(mode: .displayOnly, processFactory: { fake })
        controller.start(preset: .minutes15)
        XCTAssertTrue(controller.isActive)
        XCTAssertEqual(controller.activePreset, .minutes15)
        XCTAssertEqual(controller.remainingSeconds, 900)
        XCTAssertEqual(fake.launchedArguments, ["-d", "-t", "900"])
    }

    func testStopTerminatesAndResets() {
        let fake = FakeCaffeinateProcess()
        let controller = CaffeineController(processFactory: { fake })
        controller.start(preset: .hour1)
        controller.stop()
        XCTAssertFalse(controller.isActive)
        XCTAssertNil(controller.activePreset)
        XCTAssertNil(controller.remainingSeconds)
        XCTAssertTrue(fake.terminateCalled)
    }

    func testTickDecrementsRemaining() {
        let controller = CaffeineController(processFactory: { FakeCaffeinateProcess() })
        controller.start(preset: .minutes15)
        controller.tick()
        XCTAssertEqual(controller.remainingSeconds, 899)
    }

    func testTickAutoStopsWhenTimeElapses() {
        let controller = CaffeineController(processFactory: { FakeCaffeinateProcess() })
        controller.start(preset: .minutes15)
        for _ in 0..<900 { controller.tick() }
        XCTAssertFalse(controller.isActive)
        XCTAssertNil(controller.remainingSeconds)
    }

    func testInfinitePresetHasNoCountdown() {
        let controller = CaffeineController(processFactory: { FakeCaffeinateProcess() })
        controller.start(preset: .infinite)
        XCTAssertNil(controller.remainingSeconds)
        controller.tick()
        XCTAssertTrue(controller.isActive)
        XCTAssertNil(controller.remainingSeconds)
    }

    func testToggleSamePresetStops() {
        let controller = CaffeineController(processFactory: { FakeCaffeinateProcess() })
        controller.toggle(preset: .minutes30)
        XCTAssertTrue(controller.isActive)
        controller.toggle(preset: .minutes30)
        XCTAssertFalse(controller.isActive)
    }

    func testToggleDifferentPresetSwitches() {
        let controller = CaffeineController(processFactory: { FakeCaffeinateProcess() })
        controller.toggle(preset: .minutes15)
        controller.toggle(preset: .hour1)
        XCTAssertTrue(controller.isActive)
        XCTAssertEqual(controller.activePreset, .hour1)
    }

    func testExternalExitResetsState() {
        let controller = CaffeineController(processFactory: { FakeCaffeinateProcess() })
        controller.start(preset: .hour1)
        controller.handleProcessExit()
        XCTAssertFalse(controller.isActive)
        XCTAssertNil(controller.activePreset)
    }

    func testStateChangeCallbackFires() {
        let controller = CaffeineController(processFactory: { FakeCaffeinateProcess() })
        var count = 0
        controller.onStateChange = { count += 1 }
        controller.start(preset: .minutes15)
        XCTAssertGreaterThan(count, 0)
    }
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `swift test --filter CaffeineControllerTests`
Expected: FAIL — `CaffeineController` not found.

- [ ] **Step 5: Implement `CaffeineController`**

Create `Sources/CaffeineCore/CaffeineController.swift`:

```swift
import Foundation

@MainActor
public final class CaffeineController {
    public private(set) var isActive = false
    public private(set) var activePreset: CaffeinatePreset?
    public private(set) var remainingSeconds: Int?
    public var mode: CaffeinateMode
    public var onStateChange: (() -> Void)?

    private let processFactory: () -> CaffeinateProcess
    private var process: CaffeinateProcess?

    public init(mode: CaffeinateMode = .displayOnly,
                processFactory: @escaping () -> CaffeinateProcess) {
        self.mode = mode
        self.processFactory = processFactory
    }

    public func start(preset: CaffeinatePreset) {
        stop(notify: false)
        let process = processFactory()
        let args = caffeinateArguments(mode: mode, preset: preset)
        process.launch(arguments: args) { [weak self] in
            Task { @MainActor in self?.handleProcessExit() }
        }
        self.process = process
        isActive = true
        activePreset = preset
        remainingSeconds = preset.seconds
        notify()
    }

    public func stop() {
        stop(notify: true)
    }

    public func toggle(preset: CaffeinatePreset) {
        if isActive && activePreset == preset {
            stop()
        } else {
            start(preset: preset)
        }
    }

    public func tick() {
        guard isActive, let remaining = remainingSeconds else { return }
        let next = remaining - 1
        if next <= 0 {
            stop()
        } else {
            remainingSeconds = next
            notify()
        }
    }

    func handleProcessExit() {
        guard isActive else { return }
        process = nil
        resetState()
        notify()
    }

    private func stop(notify shouldNotify: Bool) {
        process?.terminate()
        process = nil
        resetState()
        if shouldNotify { notify() }
    }

    private func resetState() {
        isActive = false
        activePreset = nil
        remainingSeconds = nil
    }

    private func notify() {
        onStateChange?()
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `swift test --filter CaffeineControllerTests`
Expected: PASS — all controller tests green.

- [ ] **Step 7: Commit**

```bash
git add Sources/CaffeineCore/CaffeinateProcess.swift Sources/CaffeineCore/CaffeineController.swift Tests/CaffeineCoreTests/FakeCaffeinateProcess.swift Tests/CaffeineCoreTests/CaffeineControllerTests.swift
git commit -m "feat: CaffeineController with process abstraction and timer logic"
```

---

### Task 4: Preferences persistence

**Files:**
- Create: `Sources/CaffeineCore/Preferences.swift`
- Test: `Tests/CaffeineCoreTests/PreferencesTests.swift`

**Interfaces:**
- Consumes: `CaffeinateMode` (Task 1)
- Produces: `public final class Preferences` with `init(defaults: UserDefaults = .standard)` and `var mode: CaffeinateMode { get set }`

- [ ] **Step 1: Write the failing test**

Create `Tests/CaffeineCoreTests/PreferencesTests.swift`:

```swift
import XCTest
@testable import CaffeineCore

final class PreferencesTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    }

    func testDefaultModeIsDisplayOnly() {
        let prefs = Preferences(defaults: freshDefaults())
        XCTAssertEqual(prefs.mode, .displayOnly)
    }

    func testModePersists() {
        let defaults = freshDefaults()
        let prefs = Preferences(defaults: defaults)
        prefs.mode = .displaySystem
        XCTAssertEqual(Preferences(defaults: defaults).mode, .displaySystem)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter PreferencesTests`
Expected: FAIL — `Preferences` not found.

- [ ] **Step 3: Implement `Preferences`**

Create `Sources/CaffeineCore/Preferences.swift`:

```swift
import Foundation

public final class Preferences {
    private let defaults: UserDefaults
    private let modeKey = "caffeinateMode"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var mode: CaffeinateMode {
        get {
            guard let raw = defaults.string(forKey: modeKey),
                  let mode = CaffeinateMode(rawValue: raw) else {
                return .displayOnly
            }
            return mode
        }
        set {
            defaults.set(newValue.rawValue, forKey: modeKey)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter PreferencesTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/CaffeineCore/Preferences.swift Tests/CaffeineCoreTests/PreferencesTests.swift
git commit -m "feat: Preferences persistence via UserDefaults"
```

---

### Task 5: Real caffeinate process implementation

**Files:**
- Create: `Sources/CaffeineCore/SystemCaffeinateProcess.swift`

**Interfaces:**
- Consumes: `CaffeinateProcess` (Task 3)
- Produces: `public final class SystemCaffeinateProcess: CaffeinateProcess` with `public init()`

This task wraps `Foundation.Process`; it is validated by `swift build` (it spawns a real subprocess, so it is exercised manually in Task 8 rather than unit-tested).

- [ ] **Step 1: Implement `SystemCaffeinateProcess`**

Create `Sources/CaffeineCore/SystemCaffeinateProcess.swift`:

```swift
import Foundation

public final class SystemCaffeinateProcess: CaffeinateProcess {
    private var process: Process?

    public init() {}

    public var isRunning: Bool {
        process?.isRunning ?? false
    }

    public func launch(arguments: [String], terminationHandler: @escaping @Sendable () -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        process.arguments = arguments
        process.terminationHandler = { _ in terminationHandler() }
        do {
            try process.run()
            self.process = process
        } catch {
            terminationHandler()
        }
    }

    public func terminate() {
        guard let process, process.isRunning else { return }
        process.terminationHandler = nil
        process.terminate()
        self.process = nil
    }
}
```

- [ ] **Step 2: Verify it builds**

Run: `swift build`
Expected: build succeeds with no errors.

- [ ] **Step 3: Commit**

```bash
git add Sources/CaffeineCore/SystemCaffeinateProcess.swift
git commit -m "feat: SystemCaffeinateProcess wrapping Foundation.Process"
```

---

### Task 6: AppKit menubar glue

**Files:**
- Modify: `Sources/Caffeine/main.swift` (replace placeholder)
- Create: `Sources/Caffeine/AppDelegate.swift`
- Create: `Sources/Caffeine/StatusItemController.swift`
- Create: `Sources/Caffeine/MenuBuilder.swift`

**Interfaces:**
- Consumes: `CaffeineController`, `Preferences`, `SystemCaffeinateProcess`, `CaffeinatePreset` (Tasks 1–5)
- Produces: `@MainActor final class AppDelegate: NSObject, NSApplicationDelegate`; `@MainActor final class StatusItemController` with `init(controller:preferences:)` and `func refresh()`; `@MainActor final class MenuBuilder: NSObject` with `init(controller:preferences:)`, `let menu: NSMenu`, and `func update()`.

This task is validated by running the binary and observing the menubar (no unit tests for AppKit glue). `SettingsWindowController` is referenced by `MenuBuilder` but implemented in Task 7 — implement Tasks 6 and 7 together before the manual run, or temporarily stub the Settings menu item's action with a no-op and wire it in Task 7. This plan stubs it here and wires it in Task 7.

- [ ] **Step 1: Replace `main.swift`**

Replace the contents of `Sources/Caffeine/main.swift`:

```swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
```

- [ ] **Step 2: Create `AppDelegate`**

Create `Sources/Caffeine/AppDelegate.swift`:

```swift
import AppKit
import CaffeineCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences()
    private var controller: CaffeineController!
    private var statusController: StatusItemController!
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = CaffeineController(mode: preferences.mode,
                                        processFactory: { SystemCaffeinateProcess() })
        statusController = StatusItemController(controller: controller, preferences: preferences)
        controller.onStateChange = { [weak self] in
            guard let self else { return }
            self.statusController.refresh()
            self.updateTimer()
        }
        statusController.refresh()
    }

    private func updateTimer() {
        let needsTimer = controller.isActive && controller.remainingSeconds != nil
        if needsTimer, timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.controller.tick()
                }
            }
        } else if !needsTimer {
            timer?.invalidate()
            timer = nil
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.stop()
    }
}
```

- [ ] **Step 3: Create `StatusItemController`**

Create `Sources/Caffeine/StatusItemController.swift`:

```swift
import AppKit
import CaffeineCore

@MainActor
final class StatusItemController {
    private let statusItem: NSStatusItem
    private let controller: CaffeineController
    private let menuBuilder: MenuBuilder

    init(controller: CaffeineController, preferences: Preferences) {
        self.controller = controller
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.menuBuilder = MenuBuilder(controller: controller, preferences: preferences)
        self.statusItem.menu = menuBuilder.menu
    }

    func refresh() {
        updateIcon()
        menuBuilder.update()
    }

    private func updateIcon() {
        let symbol = controller.isActive ? "cup.and.saucer.fill" : "cup.and.saucer"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Caffeine")
        statusItem.button?.image = image
    }
}
```

- [ ] **Step 4: Create `MenuBuilder` (Settings action stubbed for now)**

Create `Sources/Caffeine/MenuBuilder.swift`:

```swift
import AppKit
import CaffeineCore

@MainActor
final class MenuBuilder: NSObject {
    let menu = NSMenu()

    private let controller: CaffeineController
    private let preferences: Preferences
    private let countdownItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var presetItems: [(preset: CaffeinatePreset, item: NSMenuItem)] = []

    init(controller: CaffeineController, preferences: Preferences) {
        self.controller = controller
        self.preferences = preferences
        super.init()
        build()
    }

    private func build() {
        countdownItem.isEnabled = false
        menu.addItem(countdownItem)
        menu.addItem(NSMenuItem.separator())

        for preset in CaffeinatePreset.allCases {
            let item = NSMenuItem(title: preset.title,
                                  action: #selector(selectPreset(_:)),
                                  keyEquivalent: "")
            item.target = self
            menu.addItem(item)
            presetItems.append((preset, item))
        }

        menu.addItem(NSMenuItem.separator())

        let settings = NSMenuItem(title: "Settings…",
                                  action: #selector(openSettings),
                                  keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let quit = NSMenuItem(title: "Quit",
                              action: #selector(quit),
                              keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        update()
    }

    func update() {
        if controller.isActive {
            if let remaining = controller.remainingSeconds {
                countdownItem.title = "Active — \(formatTime(remaining)) left"
            } else {
                countdownItem.title = "Active — Infinite"
            }
        } else {
            countdownItem.title = "Inactive"
        }

        for (preset, item) in presetItems {
            item.state = (controller.isActive && controller.activePreset == preset) ? .on : .off
        }
    }

    @objc private func selectPreset(_ sender: NSMenuItem) {
        guard let entry = presetItems.first(where: { $0.item == sender }) else { return }
        controller.toggle(preset: entry.preset)
    }

    @objc private func openSettings() {
        // Wired in Task 7.
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
```

- [ ] **Step 5: Build and run; observe the menubar**

Run:
```bash
swift build
swift run Caffeine
```
Expected: a cup icon appears in the menubar. Clicking it shows: "Inactive", the four presets, "Settings…", "Quit". Clicking "15 minutes" starts a countdown (icon fills, top item shows "Active — 14:59 left" counting down, "15 minutes" gets a checkmark). Clicking it again stops it. "Quit" exits. Confirm `pgrep caffeinate` shows a process while active and none after stopping/quitting:
```bash
pgrep -fl caffeinate
```

- [ ] **Step 6: Commit**

```bash
git add Sources/Caffeine/
git commit -m "feat: AppKit menubar UI with status item, menu, and countdown"
```

---

### Task 7: Settings window + launch at login

**Files:**
- Create: `Sources/Caffeine/LaunchAtLogin.swift`
- Create: `Sources/Caffeine/SettingsWindowController.swift`
- Modify: `Sources/Caffeine/MenuBuilder.swift` (wire up `openSettings`)

**Interfaces:**
- Consumes: `Preferences`, `CaffeineController`, `CaffeinateMode` (Tasks 1, 3, 4)
- Produces: `enum LaunchAtLogin { static var isEnabled: Bool { get set } }`; `@MainActor final class SettingsWindowController: NSWindowController` with `init(preferences:controller:)`.

Validated by running the app and exercising the Settings window.

- [ ] **Step 1: Create `LaunchAtLogin`**

Create `Sources/Caffeine/LaunchAtLogin.swift`:

```swift
import Foundation
import ServiceManagement

enum LaunchAtLogin {
    static var isEnabled: Bool {
        get {
            SMAppService.mainApp.status == .enabled
        }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("LaunchAtLogin error: \(error.localizedDescription)")
            }
        }
    }
}
```

- [ ] **Step 2: Create `SettingsWindowController`**

Create `Sources/Caffeine/SettingsWindowController.swift`:

```swift
import AppKit
import CaffeineCore

@MainActor
final class SettingsWindowController: NSWindowController {
    private let preferences: Preferences
    private let controller: CaffeineController
    private var modePopup: NSPopUpButton!
    private var launchCheckbox: NSButton!

    init(preferences: Preferences, controller: CaffeineController) {
        self.preferences = preferences
        self.controller = controller
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 160),
                              styleMask: [.titled, .closable],
                              backing: .buffered,
                              defer: false)
        window.title = "Caffeine Settings"
        window.center()
        super.init(window: window)
        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let modeLabel = NSTextField(labelWithString: "Keep awake:")
        modeLabel.frame = NSRect(x: 20, y: 110, width: 100, height: 24)
        content.addSubview(modeLabel)

        modePopup = NSPopUpButton(frame: NSRect(x: 120, y: 106, width: 210, height: 28))
        for mode in CaffeinateMode.allCases {
            modePopup.addItem(withTitle: mode.title)
        }
        modePopup.selectItem(at: CaffeinateMode.allCases.firstIndex(of: preferences.mode) ?? 0)
        modePopup.target = self
        modePopup.action = #selector(modeChanged)
        content.addSubview(modePopup)

        launchCheckbox = NSButton(checkboxWithTitle: "Launch at login",
                                  target: self,
                                  action: #selector(launchToggled))
        launchCheckbox.frame = NSRect(x: 20, y: 60, width: 250, height: 24)
        launchCheckbox.state = LaunchAtLogin.isEnabled ? .on : .off
        content.addSubview(launchCheckbox)
    }

    @objc private func modeChanged() {
        let mode = CaffeinateMode.allCases[modePopup.indexOfSelectedItem]
        preferences.mode = mode
        controller.mode = mode
    }

    @objc private func launchToggled() {
        LaunchAtLogin.isEnabled = (launchCheckbox.state == .on)
        launchCheckbox.state = LaunchAtLogin.isEnabled ? .on : .off
    }
}
```

- [ ] **Step 3: Wire up `openSettings` in `MenuBuilder`**

In `Sources/Caffeine/MenuBuilder.swift`, add a stored property next to the existing properties:

```swift
    private var settingsWindow: SettingsWindowController?
```

Replace the stubbed `openSettings` method body with:

```swift
    @objc private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(preferences: preferences, controller: controller)
        }
        settingsWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
```

- [ ] **Step 4: Build and run; exercise Settings**

Run:
```bash
swift build
swift run Caffeine
```
Expected: clicking "Settings…" opens a window with a "Keep awake" popup ("Só a tela" / "Tela + sistema") and a "Launch at login" checkbox. Changing the popup updates the active mode (start a timer afterward and confirm via `pgrep -fl caffeinate` that flags change between `-d` and `-d -i`). Note: `SMAppService` may report errors until the app runs as a signed `.app` bundle (Task 8) — toggling is exercised fully there.

- [ ] **Step 5: Commit**

```bash
git add Sources/Caffeine/LaunchAtLogin.swift Sources/Caffeine/SettingsWindowController.swift Sources/Caffeine/MenuBuilder.swift
git commit -m "feat: Settings window with mode selection and launch-at-login"
```

---

### Task 8: App bundle packaging

**Files:**
- Create: `Resources/Info.plist`
- Create: `build.sh`
- Create: `README.md`

**Interfaces:**
- Consumes: the full `Caffeine` executable target (Tasks 6–7)
- Produces: a runnable `Caffeine.app` bundle and a build script.

- [ ] **Step 1: Create `Info.plist`**

Create `Resources/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Caffeine</string>
    <key>CFBundleDisplayName</key>
    <string>Caffeine</string>
    <key>CFBundleIdentifier</key>
    <string>com.felipe.caffeine</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>Caffeine</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Caffeine</string>
</dict>
</plist>
```

- [ ] **Step 2: Create `build.sh`**

Create `build.sh`:

```bash
#!/bin/bash
set -euo pipefail

APP_NAME="Caffeine"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"

swift build -c release

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"

# Ad-hoc signature so SMAppService and the status item work on modern macOS.
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Built $APP_BUNDLE"
```

- [ ] **Step 3: Make it executable and run it**

Run:
```bash
chmod +x build.sh
./build.sh
```
Expected: prints "Built Caffeine.app"; a `Caffeine.app` directory exists with `Contents/MacOS/Caffeine`, `Contents/Info.plist`.

- [ ] **Step 4: Launch the bundled app and verify end-to-end**

Run:
```bash
open Caffeine.app
```
Expected: cup icon appears with no Dock icon (LSUIElement). Verify the full flow:
- Presets start/stop `caffeinate` (`pgrep -fl caffeinate`).
- Icon toggles filled/empty.
- Countdown updates each second.
- Settings: mode switch changes flags; "Launch at login" checkbox persists (check via `System Settings → General → Login Items`, or re-open Settings and confirm the checkbox stays on).
- Quit removes the icon and leaves no `caffeinate` process.

- [ ] **Step 5: Create `README.md`**

Create `README.md`:

```markdown
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
```

- [ ] **Step 6: Run the full test suite once more**

Run: `swift test`
Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add Resources/Info.plist build.sh README.md
git commit -m "feat: app bundle packaging with build script and docs"
```

---

## Self-Review Notes

**Spec coverage:**
- Timers predefinidos → Tasks 1, 3, 6 ✓
- Ícone muda de estado → Task 6 (`StatusItemController.updateIcon`) ✓
- Iniciar com o sistema → Task 7 (`LaunchAtLogin` + Settings checkbox) ✓
- Contagem regressiva visível → Tasks 3 (`tick`/`remainingSeconds`), 6 (`countdownItem`) ✓
- Modo configurável (tela / tela+sistema) → Tasks 1 (`CaffeinateMode`), 4 (`Preferences`), 7 (Settings popup) ✓
- Subprocess managed + killed on Quit → Tasks 3, 5 (`SystemCaffeinateProcess`), 6 (`applicationWillTerminate`) ✓
- Empacotamento .app via SPM (CLT only) → Task 8 ✓
- Testes do core via `swift test` → Tasks 1–4 ✓

**Type consistency:** `CaffeineController` API (`start`, `stop`, `toggle`, `tick`, `handleProcessExit`, `mode`, `onStateChange`, `isActive`, `activePreset`, `remainingSeconds`) is consistent across Tasks 3, 6, 7. `CaffeinateProcess` protocol (`isRunning`, `launch(arguments:terminationHandler:)`, `terminate`) matches between Tasks 3 (fake) and 5 (real). `Preferences.mode` consistent across Tasks 4, 6, 7. `CaffeinateMode.allCases`/`title`/`flags` and `CaffeinatePreset.allCases`/`title`/`seconds` consistent throughout.

**Placeholder scan:** No TBD/TODO. The only intentional stub (`openSettings` in Task 6) is explicitly called out and wired in Task 7 Step 3.
```
