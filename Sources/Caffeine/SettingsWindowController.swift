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
