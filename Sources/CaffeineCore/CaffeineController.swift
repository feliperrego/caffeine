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
