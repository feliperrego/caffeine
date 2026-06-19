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
