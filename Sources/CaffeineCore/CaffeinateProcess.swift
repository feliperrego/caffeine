public protocol CaffeinateProcess: AnyObject {
    var isRunning: Bool { get }
    func launch(arguments: [String], terminationHandler: @escaping @Sendable () -> Void)
    func terminate()
}
