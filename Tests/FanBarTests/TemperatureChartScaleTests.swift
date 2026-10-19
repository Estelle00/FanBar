import XCTest
@testable import FanBar

final class TemperatureChartScaleTests: XCTestCase {
    func testFittedRangeHugsReadingsOnWholeTens() {
        XCTAssertEqual(TemperatureChartScale.fitted(to: [33, 59, 65]), 20...70)
        XCTAssertEqual(TemperatureChartScale.fitted(to: [41, 44]), 30...70)
        XCTAssertEqual(TemperatureChartScale.fitted(to: []), 20...100)
    }

    func testTicksWidenOnTallRanges() {
        XCTAssertEqual(TemperatureChartScale.ticks(in: 30...70), [30, 40, 50, 60, 70])
        XCTAssertEqual(TemperatureChartScale.ticks(in: 20...100), [20, 40, 60, 80, 100])
    }
}
