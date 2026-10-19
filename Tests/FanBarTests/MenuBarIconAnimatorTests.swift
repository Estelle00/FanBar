import XCTest
@testable import FanBar

final class SpinTriggerTests: XCTestCase {
    func testFirstReadingOnlySetsBaseline() {
        var trigger = SpinTrigger()
        XCTAssertFalse(trigger.registerReading(1_850))
        XCTAssertEqual(trigger.referenceRPM, 1_850)
    }

    func testSmallChangesDoNotSpin() {
        var trigger = SpinTrigger()
        _ = trigger.registerReading(1_850)
        // 15% of 1,850 is about 278 RPM, above the 250 RPM floor.
        XCTAssertFalse(trigger.registerReading(2_100))
        XCTAssertFalse(trigger.registerReading(1_600))
        XCTAssertEqual(trigger.referenceRPM, 1_850)
    }

    func testNotableChangeSpinsAndMovesBaseline() {
        var trigger = SpinTrigger()
        _ = trigger.registerReading(1_850)
        XCTAssertTrue(trigger.registerReading(2_400))
        XCTAssertEqual(trigger.referenceRPM, 2_400)
        // The same reading again is no longer news.
        XCTAssertFalse(trigger.registerReading(2_400))
    }

    func testFansStartingFromRestSpin() {
        var trigger = SpinTrigger()
        _ = trigger.registerReading(0)
        // A stopped fan uses the 250 RPM floor, not 15% of zero.
        XCTAssertFalse(trigger.registerReading(200))
        XCTAssertTrue(trigger.registerReading(1_200))
    }

    func testSlowDriftTriggersOnceItAddsUp() {
        var trigger = SpinTrigger()
        _ = trigger.registerReading(2_000)
        XCTAssertFalse(trigger.registerReading(2_150))
        XCTAssertFalse(trigger.registerReading(2_250))
        // 2,000 × 15% = 300 RPM from the baseline.
        XCTAssertTrue(trigger.registerReading(2_300))
    }
}
