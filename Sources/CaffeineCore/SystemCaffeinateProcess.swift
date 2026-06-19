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
        // `-w <ownPID>` ties the subprocess lifetime to this app's process so a crash,
        // SIGKILL, or force-quit (which skips applicationWillTerminate) can't orphan caffeinate.
        let finalArgs = arguments + ["-w", String(ProcessInfo.processInfo.processIdentifier)]
        process.arguments = finalArgs
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
