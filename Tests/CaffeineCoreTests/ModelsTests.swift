import XCTest
@testable import CaffeineCore

final class ModelsTests: XCTestCase {
    func testDisplayOnlyFlags() {
        XCTAssertEqual(CaffeinateMode.displayOnly.flags, ["-d"])
    }

    func testDisplaySystemFlags() {
        XCTAssertEqual(CaffeinateMode.displaySystem.flags, ["-d", "-i"])
    }

    func testPresetSeconds() {
        XCTAssertEqual(CaffeinatePreset.minutes15.seconds, 900)
        XCTAssertEqual(CaffeinatePreset.minutes30.seconds, 1800)
        XCTAssertEqual(CaffeinatePreset.hour1.seconds, 3600)
        XCTAssertNil(CaffeinatePreset.infinite.seconds)
    }

    func testPresetTitles() {
        XCTAssertEqual(CaffeinatePreset.minutes15.title, "15 minutes")
        XCTAssertEqual(CaffeinatePreset.infinite.title, "Infinite")
    }

    func testAllPresetsCovered() {
        XCTAssertEqual(CaffeinatePreset.allCases.count, 4)
    }
}
