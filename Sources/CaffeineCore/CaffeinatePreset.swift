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
