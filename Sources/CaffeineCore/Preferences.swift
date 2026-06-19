import Foundation

public final class Preferences {
    private let defaults: UserDefaults
    private let modeKey = "caffeinateMode"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var mode: CaffeinateMode {
        get {
            guard let raw = defaults.string(forKey: modeKey),
                  let mode = CaffeinateMode(rawValue: raw) else {
                return .displayOnly
            }
            return mode
        }
        set {
            defaults.set(newValue.rawValue, forKey: modeKey)
        }
    }
}
