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
        case .displayOnly: return "Display only"
        case .displaySystem: return "Display + system"
        }
    }
}
