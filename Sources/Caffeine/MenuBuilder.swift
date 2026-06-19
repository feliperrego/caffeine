import AppKit
import CaffeineCore

@MainActor
final class MenuBuilder: NSObject {
    let menu = NSMenu()

    private let controller: CaffeineController
    private let preferences: Preferences
    private let countdownItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var presetItems: [(preset: CaffeinatePreset, item: NSMenuItem)] = []
    private var settingsWindow: SettingsWindowController?

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
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(preferences: preferences, controller: controller)
        }
        settingsWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
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
