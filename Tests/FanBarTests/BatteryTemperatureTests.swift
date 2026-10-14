// Missing sensor or collection evidence is intentionally distinct from false.
// swiftlint:disable discouraged_optional_boolean
import XCTest
@testable import FanBar

final class BatteryTemperatureTests: XCTestCase {
    func testNoBuiltInBatteryIsNormalAndUnknownPresenceStaysUnknown() {
        let device = CompatibilityDevice.current(helperVersion: "test")
        let states: [Bool?] = [false, true, nil]
        for present in states {
            let thermal = ThermalReading(sampledAt: Date(), cpuCelsius: 50, gpuCelsius: 45, hasBuiltInBattery: present)
            let observation = CompatibilityObservation(sampledAt: Date(), thermal: thermal, fanCount: 1, connectionFailed: false)
            let snapshot = CompatibilitySnapshot.make(device: device, observation: observation,
                helperState: .enabled, manualEvidence: .unverified, curveEvidence: .unverified)
            let result = snapshot.results.first { $0.capability == .batteryTemperature }
            XCTAssertEqual(result?.status, present == false ? .notApplicable : .notDetected)
        }
    }

    func testModelIdentifierHasReadableName() {
        let device = CompatibilityDevice(modelIdentifier: "Mac16,10",
            processor: "Apple M4", macOSVersion: "27.0.0", appVersion: "0.5.1",
            helperVersion: "26")
        XCTAssertEqual(device.displayName, "Mac mini · M4")
    }

    func testRegistryTemperatureIsConvertedFromCentiDegrees() {
        let result = BatteryTemperatureResolver.resolve(smcValues: [40], smartBattery: { 2875 }, batteryPack: { nil })
        XCTAssertEqual(result, 28.75)
    }

    func testNewBatteryPackSourceIsReadWhenLegacyPropertyIsMissing() {
        let result = BatteryTemperatureResolver.resolve(smcValues: [], smartBattery: { nil }, batteryPack: { 3210 })
        XCTAssertEqual(result, 32.1)
    }

    func testSMCRemainsFallbackAndInvalidValuesAreIgnored() {
        let result = BatteryTemperatureResolver.resolve(smcValues: [30, 34, .nan], smartBattery: { 0 }, batteryPack: { .infinity })
        XCTAssertEqual(result, 32)
        XCTAssertNil(BatteryTemperatureResolver.resolve(smcValues: [], smartBattery: { nil }, batteryPack: { nil }))
    }

    func testBatteryTemperatureMarksCompatibilityAvailable() {
        let device = CompatibilityDevice.current(helperVersion: "test")
        let observation = CompatibilityObservation(sampledAt: Date(), thermal: ThermalReading(sampledAt: Date(),
            cpuCelsius: 50, gpuCelsius: 45, batteryCelsius: 32.1), fanCount: 1, connectionFailed: false)
        let snapshot = CompatibilitySnapshot.make(device: device, observation: observation,
            helperState: .enabled, manualEvidence: .unverified, curveEvidence: .unverified)
        XCTAssertEqual(snapshot.results.first { $0.capability == .batteryTemperature }?.status, .available)
    }
}

// swiftlint:enable discouraged_optional_boolean
