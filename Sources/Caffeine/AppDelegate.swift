import AppKit
import CaffeineCore

@MainActor
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
