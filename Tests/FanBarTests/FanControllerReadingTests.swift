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

    func testEachRefreshSamplesUsageOnceAcrossFanReadFailuresAndRecovery() {
        let source = FakeFanReadingSource()
        source.error = SMCError.unsupportedKey("FNum", -1)
        var samples = 0
        let controller = FanController(
            notificationCenter: nil,
            widgetSnapshotDestination: .disabled,
            makeReadingSource: { source },
            readUsage: {
                samples += 1
                return SystemUsage(cpuFraction: 0.4, gpuFraction: 0.2)
            }
        )
        XCTAssertEqual(samples, 1)
        for tick in 1...3 {
            controller.refresh()
            XCTAssertEqual(samples, tick + 1)
            XCTAssertEqual(controller.cpuHistory.count, tick + 1)
            XCTAssertEqual(controller.gpuHistory.count, tick + 1)
        }
        source.error = nil
        controller.refresh()
        XCTAssertTrue(controller.isAvailable)
        XCTAssertEqual(samples, 5)
        XCTAssertEqual(controller.cpuHistory.count, 5)
        XCTAssertEqual(controller.gpuHistory.count, 5)
    }

    func testEmptyFanListSamplesUsageOnceAndKeepsTheConnection() {
        let source = FakeFanReadingSource(readings: [])
        var connections = 0
        var samples = 0
        let controller = FanController(
            notificationCenter: nil,
            widgetSnapshotDestination: .disabled,
            makeReadingSource: {
                connections += 1
                return source
            },
            readUsage: {
                samples += 1
                return SystemUsage(cpuFraction: Double(samples) / 100, cpuCoreFractions: [0.2, 0.6], gpuFraction: 0.3)
            }
        )
        let count = FanController.usageHistorySampleCount + 3
        for tick in 2...count {
            controller.refresh()
            XCTAssertEqual(samples, tick)
            XCTAssertEqual(controller.cpuHistory.count, min(tick, FanController.usageHistorySampleCount))
            XCTAssertEqual(controller.gpuHistory.count, min(tick, FanController.usageHistorySampleCount))
            XCTAssertEqual(controller.usage.cpuCoreFractions, [0.2, 0.6])
        }
        XCTAssertTrue(controller.isAvailable)
        XCTAssertTrue(controller.fans.isEmpty)
        XCTAssertEqual(connections, 1)
        let expected = (4...count).map { Double($0) / 100 }
        XCTAssertEqual(controller.cpuHistory, expected, "history must contain one sample per tick, in order")
    }

    func testUnavailableSMCStillSamplesUsageOncePerRefreshAndRecovers() {
        let source = FakeFanReadingSource(readings: [])
        var unavailable = true
        var samples = 0
        let controller = FanController(
            notificationCenter: nil,
            widgetSnapshotDestination: .disabled,
            makeReadingSource: {
                if unavailable { throw SMCError.unavailable(-1) }
                return source
            },
            readUsage: {
                samples += 1
                return SystemUsage(cpuFraction: 0.4, gpuFraction: 0.2)
            }
        )
        for tick in 2...4 {
            controller.refresh()
            XCTAssertFalse(controller.isAvailable)
            XCTAssertEqual(samples, tick)
            XCTAssertEqual(controller.cpuHistory.count, tick)
            XCTAssertEqual(controller.gpuHistory.count, tick)
        }
        unavailable = false
        controller.refresh()
        XCTAssertTrue(controller.isAvailable)
        XCTAssertEqual(samples, 5)
        XCTAssertEqual(controller.cpuHistory.count, 5)
        XCTAssertEqual(controller.gpuHistory.count, 5)
    }
}
