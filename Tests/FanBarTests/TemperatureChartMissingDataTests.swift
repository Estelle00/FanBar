import XCTest
@testable import FanBar

final class TemperatureChartMissingDataTests: XCTestCase {
    private func bridges(_ seconds: [Double], _ values: [Double?]) -> [ClosedRange<Int>] {
        TemperatureChartTimeAxis.missingIntervals(
            dates: seconds.map { Date(timeIntervalSince1970: $0) }, values: values
        )
    }

    func testNormalCadenceAndSmallTimerJitterStaySolid() {
        XCTAssertTrue(bridges([0, 2, 4, 8], [60, 61, 62, 63]).isEmpty)
    }

    func testShortSensorAbsenceGetsOneBridgeBetweenRealReadings() {
        XCTAssertEqual(bridges([0, 2, 4, 6], [60, nil, nil, 64]), [0...3])
        XCTAssertEqual(bridges([0, 2, 4], [60, .nan, 64]), [0...2])
    }

    func testShortSamplingPauseIsDashedAndNotSmoothedAcross() {
        XCTAssertEqual(bridges([0, 2, 10, 12], [60, 61, 64, 65]), [1...2])
        let dates = [0.0, 2, 10, 12].map { Date(timeIntervalSince1970: $0) }
        XCTAssertEqual(TemperatureChartTimeAxis.segments(for: dates), [0...1, 2...3])
    }

    func testLongInterruptionsStayDisconnectedIncludingFrequentMissingSamples() {
        XCTAssertTrue(bridges([0, 20], [60, 64]).isEmpty)
        XCTAssertTrue(bridges([0, 8, 16], [60, nil, 64]).isEmpty)
        XCTAssertEqual(bridges([0, 15], [60, 64]), [0...1])
        XCTAssertTrue(bridges([0, 15.1], [60, 64]).isEmpty)
    }

    func testNoExtrapolationAtEdgesOrWithoutReadings() {
        XCTAssertTrue(bridges([0, 2, 4], [nil, 60, nil]).isEmpty)
        XCTAssertTrue(bridges([0, 2], [nil, nil]).isEmpty)
        XCTAssertTrue(bridges([], []).isEmpty)
        XCTAssertTrue(bridges([0], []).isEmpty)
    }
}
