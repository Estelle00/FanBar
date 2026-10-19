import XCTest
@testable import FanBar

final class TemperatureChartScaleTests: XCTestCase {
    func testScaleKeepsConfiguredAlertLineInsidePlotAtEverySupportedThreshold() {
        for threshold in stride(from: 60.0, through: 105, by: 1) {
            let domain = TemperatureChartScale.domain(alertThreshold: threshold)
            XCTAssertEqual(domain.lowerBound, 20)
            XCTAssertTrue(domain.contains(threshold))
            XCTAssertGreaterThanOrEqual(domain.upperBound - threshold, 5)
        }
    }

    func testUsualThresholdRetainsScaleAndMaximumThresholdHasHeadroom() {
        XCTAssertEqual(TemperatureChartScale.domain(alertThreshold: 90), 20...100)
        XCTAssertEqual(TemperatureChartScale.domain(alertThreshold: 105), 20...110)
    }
}
