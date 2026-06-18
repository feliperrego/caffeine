import XCTest
@testable import CaffeineCore

final class CaffeinateArgumentsTests: XCTestCase {
    func testTimedDisplayOnly() {
        let args = caffeinateArguments(mode: .displayOnly, preset: .minutes15)
        XCTAssertEqual(args, ["-d", "-t", "900"])
    }

    func testTimedDisplaySystem() {
        let args = caffeinateArguments(mode: .displaySystem, preset: .hour1)
        XCTAssertEqual(args, ["-d", "-i", "-t", "3600"])
    }

    func testInfiniteHasNoTimeFlag() {
        let args = caffeinateArguments(mode: .displayOnly, preset: .infinite)
        XCTAssertEqual(args, ["-d"])
    }
}
