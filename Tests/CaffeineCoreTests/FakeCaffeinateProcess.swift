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
