import XCTest
@testable import CaffeineCore

@MainActor
final class CaffeineControllerTests: XCTestCase {
    func testStartLaunchesWithCorrectArguments() {
        let fake = FakeCaffeinateProcess()
        let controller = CaffeineController(mode: .displayOnly, processFactory: { fake })
        controller.start(preset: .minutes15)
        XCTAssertTrue(controller.isActive)
        XCTAssertEqual(controller.activePreset, .minutes15)
        XCTAssertEqual(controller.remainingSeconds, 900)
        XCTAssertEqual(fake.launchedArguments, ["-d", "-t", "900"])
    }

    func testStopTerminatesAndResets() {
        let fake = FakeCaffeinateProcess()
        let controller = CaffeineController(processFactory: { fake })
        controller.start(preset: .hour1)
        controller.stop()
        XCTAssertFalse(controller.isActive)
        XCTAssertNil(controller.activePreset)
        XCTAssertNil(controller.remainingSeconds)
        XCTAssertTrue(fake.terminateCalled)
    }

    func testTickDecrementsRemaining() {
        let controller = CaffeineController(processFactory: { FakeCaffeinateProcess() })
        controller.start(preset: .minutes15)
        controller.tick()
        XCTAssertEqual(controller.remainingSeconds, 899)
    }

    func testTickAutoStopsWhenTimeElapses() {
        let controller = CaffeineController(processFactory: { FakeCaffeinateProcess() })
        controller.start(preset: .minutes15)
        for _ in 0..<900 { controller.tick() }
        XCTAssertFalse(controller.isActive)
        XCTAssertNil(controller.remainingSeconds)
    }

    func testInfinitePresetHasNoCountdown() {
        let controller = CaffeineController(processFactory: { FakeCaffeinateProcess() })
        controller.start(preset: .infinite)
        XCTAssertNil(controller.remainingSeconds)
        controller.tick()
        XCTAssertTrue(controller.isActive)
        XCTAssertNil(controller.remainingSeconds)
    }

    func testToggleSamePresetStops() {
        let controller = CaffeineController(processFactory: { FakeCaffeinateProcess() })
        controller.toggle(preset: .minutes30)
        XCTAssertTrue(controller.isActive)
        controller.toggle(preset: .minutes30)
        XCTAssertFalse(controller.isActive)
    }

    func testToggleDifferentPresetSwitches() {
        let controller = CaffeineController(processFactory: { FakeCaffeinateProcess() })
        controller.toggle(preset: .minutes15)
        controller.toggle(preset: .hour1)
        XCTAssertTrue(controller.isActive)
        XCTAssertEqual(controller.activePreset, .hour1)
    }

    func testExternalExitResetsState() {
        let controller = CaffeineController(processFactory: { FakeCaffeinateProcess() })
        controller.start(preset: .hour1)
        controller.handleProcessExit()
        XCTAssertFalse(controller.isActive)
        XCTAssertNil(controller.activePreset)
    }

    func testStateChangeCallbackFires() {
        let controller = CaffeineController(processFactory: { FakeCaffeinateProcess() })
        var count = 0
        controller.onStateChange = { count += 1 }
        controller.start(preset: .minutes15)
        XCTAssertGreaterThan(count, 0)
    }

    func testHandleProcessExitIsIdempotent() {
        let controller = CaffeineController(processFactory: { FakeCaffeinateProcess() })
        var count = 0
        controller.start(preset: .minutes15)
        controller.onStateChange = { count += 1 }
        controller.handleProcessExit()
        XCTAssertFalse(controller.isActive)
        let countAfterFirstExit = count
        XCTAssertGreaterThan(countAfterFirstExit, 0)
        controller.handleProcessExit()
        XCTAssertEqual(count, countAfterFirstExit)
        XCTAssertFalse(controller.isActive)
    }

    func testTerminationHandlerHopResetsStateAsynchronously() async {
        let fake = FakeCaffeinateProcess()
        let controller = CaffeineController(processFactory: { fake })
        controller.start(preset: .minutes15)
        XCTAssertTrue(controller.isActive)

        fake.simulateExit()

        var iterations = 0
        while controller.isActive && iterations < 1000 {
            await Task.yield()
            iterations += 1
        }

        XCTAssertFalse(controller.isActive)
    }

    func testTogglingDifferentPresetTerminatesPreviousProcess() {
        var fakes: [FakeCaffeinateProcess] = []
        let controller = CaffeineController(processFactory: {
            let f = FakeCaffeinateProcess()
            fakes.append(f)
            return f
        })
        controller.toggle(preset: .minutes15)
        controller.toggle(preset: .hour1)
        XCTAssertEqual(fakes.count, 2)
        XCTAssertTrue(fakes[0].terminateCalled)
    }
}
