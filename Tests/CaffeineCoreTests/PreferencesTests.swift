import XCTest
@testable import CaffeineCore

final class PreferencesTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    }

    func testDefaultModeIsDisplayOnly() {
        let prefs = Preferences(defaults: freshDefaults())
        XCTAssertEqual(prefs.mode, .displayOnly)
    }

    func testModePersists() {
        let defaults = freshDefaults()
        let prefs = Preferences(defaults: defaults)
        prefs.mode = .displaySystem
        XCTAssertEqual(Preferences(defaults: defaults).mode, .displaySystem)
    }
}
