import XCTest
@testable import FanBar

@MainActor
final class FanControllerReadingTests: XCTestCase {
    private func makeController(
        _ makeSource: @escaping () throws -> FanReadingSource
    ) -> FanController {
        FanController(
            notificationCenter: nil,
            widgetSnapshotDestination: .disabled,
            makeReadingSource: makeSource
        )
    }

    func testRefreshPublishesFanAndTemperatureReadings() {
        let source = FakeFanReadingSource()
        let controller = makeController { source }

        controller.refresh()

        XCTAssertTrue(controller.isAvailable)
        XCTAssertEqual(controller.fans.map(\.currentRPM), [1_850, 1_900])
        XCTAssertEqual(controller.temperatureHistory.last?.cpuCelsius, 52)
    }

    func testReadFailureMarksUnavailableAndReconnectsOnNextRefresh() {
        let source = FakeFanReadingSource()
        var connections = 0
        let controller = makeController {
            connections += 1
            return source
        }
        XCTAssertTrue(controller.isAvailable)
        XCTAssertEqual(connections, 1)

        let failure = SMCError.unsupportedKey("FNum", -1)
        source.error = failure
        controller.refresh()
        XCTAssertFalse(controller.isAvailable)
        XCTAssertEqual(controller.message, failure.localizedDescription)

        // The stale connection was dropped, so the next tick opens a new one.
        source.error = nil
        controller.refresh()
        XCTAssertEqual(connections, 2)
        XCTAssertTrue(controller.isAvailable)
    }

    func testUnavailableSMCIsReportedWithoutCrashing() {
        let failure = SMCError.unavailable(-1)
        let controller = makeController { throw failure }

        controller.refresh()

        XCTAssertFalse(controller.isAvailable)
        XCTAssertEqual(controller.message, failure.localizedDescription)
        XCTAssertEqual(controller.fans.count, 0)
    }
}
