import XCTest
@testable import FanBar

final class PanelThermalTests: XCTestCase {
    func testEachPartHasItsOwnLimits() {
        XCTAssertEqual(ThermalLevel(celsius: nil, part: .cpu), .normal)
        XCTAssertEqual(ThermalLevel(celsius: 84.9, part: .cpu), .normal)
        XCTAssertEqual(ThermalLevel(celsius: 85, part: .cpu), .warm)
        XCTAssertEqual(ThermalLevel(celsius: 95, part: .gpu), .hot)

        XCTAssertEqual(ThermalLevel(celsius: 64.9, part: .ssd), .normal)
        XCTAssertEqual(ThermalLevel(celsius: 65, part: .ssd), .warm)
        XCTAssertEqual(ThermalLevel(celsius: 75, part: .ssd), .hot)

        XCTAssertEqual(ThermalLevel(celsius: 39.9, part: .battery), .normal)
        XCTAssertEqual(ThermalLevel(celsius: 40, part: .battery), .warm)
        XCTAssertEqual(ThermalLevel(celsius: 45, part: .battery), .hot)
    }

    func testDisplayCPUPrefersHottestCoreAndFallsBackToAverage() {
        let withHottest = ThermalReading(sampledAt: Date(), cpuCelsius: 62, gpuCelsius: nil, cpuHottestCelsius: 74)
        XCTAssertEqual(withHottest.cpuDisplayCelsius, 74)
        // Control input stays the average.
        XCTAssertEqual(withHottest.cpuCelsius, 62)

        let legacy = ThermalReading(sampledAt: Date(), cpuCelsius: 62, gpuCelsius: nil)
        XCTAssertEqual(legacy.cpuDisplayCelsius, 62)
    }

    func testHistorySavedBeforeHottestCoreStillDecodes() throws {
        let json = #"[{"sampledAt":0,"cpuCelsius":55,"gpuCelsius":50}]"#
        let decoded = try JSONDecoder().decode([ThermalReading].self, from: Data(json.utf8))
        XCTAssertNil(decoded.first?.cpuHottestCelsius)
        XCTAssertEqual(decoded.first?.cpuDisplayCelsius, 55)
    }

    func testFocusIsHottestChipWhenEverythingIsNormal() {
        let reading = ThermalReading(
            sampledAt: Date(),
            cpuCelsius: 60,
            gpuCelsius: 66,
            ssdCelsius: 44,
            batteryCelsius: 33,
            cpuHottestCelsius: 71
        )
        let focus = ThermalFocus.from(reading)
        XCTAssertEqual(focus?.part, .cpu)
        XCTAssertEqual(focus?.celsius, 71)
        XCTAssertEqual(focus?.isAlert, false)
    }

    func testWarmBatteryLeadsEvenWhenChipsAreHotter() {
        let reading = ThermalReading(
            sampledAt: Date(),
            cpuCelsius: 67,
            gpuCelsius: 60,
            ssdCelsius: 44,
            batteryCelsius: 43
        )
        let focus = ThermalFocus.from(reading)
        XCTAssertEqual(focus?.part, .battery)
        XCTAssertEqual(focus?.level, .warm)
    }

    func testHotterLevelWinsBetweenTwoAlerts() {
        let reading = ThermalReading(
            sampledAt: Date(),
            cpuCelsius: 80,
            gpuCelsius: nil,
            ssdCelsius: 76,
            cpuHottestCelsius: 88
        )
        // CPU 88 °C is warm; SSD 76 °C is hot.
        let focus = ThermalFocus.from(reading)
        XCTAssertEqual(focus?.part, .ssd)
        XCTAssertEqual(focus?.level, .hot)
    }

    func testFocusIsNilWithoutSensors() {
        XCTAssertNil(ThermalFocus.from(nil))
        XCTAssertNil(ThermalFocus.from(ThermalReading(sampledAt: Date(), cpuCelsius: nil, gpuCelsius: nil)))
    }

    func testTrendComparesWithReadingOneSpanAgo() throws {
        let end = Date(timeIntervalSince1970: 100_000)
        let history = stride(from: 900.0, through: 0, by: -60).map { secondsAgo in
            // 1 °C cooler per minute back in time.
            ThermalReading(
                sampledAt: end.addingTimeInterval(-secondsAgo),
                cpuCelsius: 70 - secondsAgo / 60,
                gpuCelsius: nil
            )
        }
        let focus = try XCTUnwrap(ThermalFocus.from(history.last))
        let trend = try XCTUnwrap(focus.trend(in: history, span: 600))

        XCTAssertEqual(trend.delta, 10, accuracy: 1e-9)
        XCTAssertEqual(trend.minutes, 10)
    }

    func testTrendReportsRealAgeWhenHistoryIsShort() throws {
        let end = Date(timeIntervalSince1970: 100_000)
        let history = [
            ThermalReading(sampledAt: end.addingTimeInterval(-180), cpuCelsius: 60, gpuCelsius: nil),
            ThermalReading(sampledAt: end, cpuCelsius: 63, gpuCelsius: nil)
        ]
        let focus = try XCTUnwrap(ThermalFocus.from(history.last))
        let trend = try XCTUnwrap(focus.trend(in: history, span: 1_800))

        XCTAssertEqual(trend.delta, 3, accuracy: 1e-9)
        XCTAssertEqual(trend.minutes, 3)
    }

    func testNoTrendUnderOneMinuteOfHistory() throws {
        let end = Date(timeIntervalSince1970: 100_000)
        let history = [
            ThermalReading(sampledAt: end.addingTimeInterval(-30), cpuCelsius: 60, gpuCelsius: nil),
            ThermalReading(sampledAt: end, cpuCelsius: 63, gpuCelsius: nil)
        ]
        let focus = try XCTUnwrap(ThermalFocus.from(history.last))
        XCTAssertNil(focus.trend(in: history, span: 600))
    }
}
