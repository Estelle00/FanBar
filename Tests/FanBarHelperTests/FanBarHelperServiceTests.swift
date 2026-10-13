import FanBarShared
import XCTest
@testable import FanBarHelper

final class FanBarHelperServiceTests: XCTestCase {
    private final class DriverFactory: @unchecked Sendable {
        let smc: FakeSMC
        var error: Error?
        private(set) var created = 0

        init(smc: FakeSMC = .appleSilicon()) {
            self.smc = smc
        }

        func make() throws -> SMCFanDriver {
            if let error { throw error }
            created += 1
            return SMCFanDriver(store: smc)
        }
    }

    private final class Box<Value>: @unchecked Sendable {
        var value: Value?
    }

    private func makeService(_ factory: DriverFactory) -> FanBarHelperService {
        FanBarHelperService(makeDriver: factory.make)
    }

    /// Calls a write-style XPC method and waits for its reply.
    private func write(
        _ call: (@escaping @Sendable (Bool, String?) -> Void) -> Void
    ) -> (ok: Bool, message: String?) {
        let replied = expectation(description: "reply")
        let box = Box<(Bool, String?)>()
        call { ok, message in
            box.value = (ok, message)
            replied.fulfill()
        }
        wait(for: [replied], timeout: 5)
        return box.value ?? (false, "no reply")
    }

    private func fanCount(_ service: FanBarHelperService) -> (ok: Bool, count: Int) {
        let replied = expectation(description: "fan count")
        let box = Box<(Bool, Int)>()
        service.getFanCount { ok, count, _ in
            box.value = (ok, count)
            replied.fulfill()
        }
        wait(for: [replied], timeout: 5)
        return box.value ?? (false, 0)
    }

    // MARK: Input validation happens before any hardware access

    func testNonFiniteOrNegativeRPMIsRejected() {
        let factory = DriverFactory()
        let service = makeService(factory)

        for rpm: Float in [.nan, .infinity, -1] {
            XCTAssertFalse(write { service.setAllFans(rpm: rpm, reply: $0) }.ok, "\(rpm)")
        }
        XCTAssertEqual(factory.created, 0)
    }

    func testCoolingFractionMustBeWithinZeroAndOne() {
        let factory = DriverFactory()
        let service = makeService(factory)

        for fraction: Float in [.nan, -0.01, 1.01] {
            XCTAssertFalse(write { service.setCoolingFraction(fraction, reply: $0) }.ok, "\(fraction)")
        }
        XCTAssertEqual(factory.created, 0)

        XCTAssertTrue(write { service.setCoolingFraction(1, reply: $0) }.ok)
        XCTAssertEqual(factory.smc.rpm("F0Tg"), 6_000)
    }

    func testUnknownCoolingPresetIsRejected() {
        let factory = DriverFactory()
        let service = makeService(factory)

        XCTAssertFalse(write { service.setCoolingPreset(99, reply: $0) }.ok)
        XCTAssertEqual(factory.created, 0)

        XCTAssertTrue(write { service.setCoolingPreset(FanCoolingPreset.silent.rawValue, reply: $0) }.ok)
        XCTAssertEqual(factory.smc.bytes("F0md"), [1])
    }

    // MARK: Driver lifecycle and errors

    func testDriverIsCreatedLazilyAndReused() {
        let factory = DriverFactory()
        let service = makeService(factory)
        XCTAssertEqual(factory.created, 0)

        XCTAssertTrue(write { service.setAllFans(rpm: 3_000, reply: $0) }.ok)
        XCTAssertTrue(write { service.setAllFansToEightyPercent(reply: $0) }.ok)
        XCTAssertEqual(fanCount(service).count, 2)
        XCTAssertEqual(factory.created, 1)
    }

    func testDriverCreationFailureIsReportedToTheClient() {
        let factory = DriverFactory()
        factory.error = FanHardwareError.unavailable(-3)
        let service = makeService(factory)

        let result = write { service.setAllFans(rpm: 3_000, reply: $0) }
        XCTAssertFalse(result.ok)
        XCTAssertEqual(result.message, FanHardwareError.unavailable(-3).localizedDescription)
        XCTAssertFalse(fanCount(service).ok)
    }

    func testHardwareWriteFailureIsReportedToTheClient() {
        let factory = DriverFactory()
        factory.smc.failWrites(to: "F0Tg", code: -9)
        let service = makeService(factory)

        let result = write { service.setAllFans(rpm: 3_000, reply: $0) }
        XCTAssertFalse(result.ok)
        XCTAssertEqual(result.message, FanHardwareError.operation("F0Tg", -9).localizedDescription)
    }

    func testGetFanReturnsReadingAndRejectsUnknownIndex() {
        let factory = DriverFactory()
        let service = makeService(factory)
        factory.smc.set("F1md", bytes: [1])

        let found = expectation(description: "fan 1")
        let missing = expectation(description: "fan 5")
        struct Reading {
            let ok: Bool
            let actual, minimum, maximum: Float
            let isManual: Bool
        }
        let reading = Box<Reading>()
        let missingOK = Box<Bool>()
        service.getFan(1) { ok, actual, minimum, maximum, isManual, _ in
            reading.value = Reading(ok: ok, actual: actual, minimum: minimum, maximum: maximum, isManual: isManual)
            found.fulfill()
        }
        service.getFan(5) { ok, _, _, _, _, _ in
            missingOK.value = ok
            missing.fulfill()
        }
        wait(for: [found, missing], timeout: 5)

        XCTAssertEqual(reading.value?.ok, true)
        XCTAssertEqual(reading.value?.actual, 1_600)
        XCTAssertEqual(reading.value?.minimum, 1_300)
        XCTAssertEqual(reading.value?.maximum, 6_500)
        XCTAssertEqual(reading.value?.isManual, true)
        XCTAssertEqual(missingOK.value, false)
    }

    // MARK: Handing control back to macOS

    func testLastClientDisconnectRestoresAutomatic() {
        let factory = DriverFactory()
        let service = makeService(factory)
        service.clientDidConnect()
        service.clientDidConnect()
        XCTAssertTrue(write { service.setAllFans(rpm: 3_000, reply: $0) }.ok)

        service.clientDidDisconnect()
        _ = fanCount(service) // Drains the serial hardware queue.
        XCTAssertEqual(factory.smc.bytes("F0md"), [1], "Another client is still connected")

        service.clientDidDisconnect()
        _ = fanCount(service)
        XCTAssertEqual(factory.smc.bytes("F0md"), [0])
        XCTAssertEqual(factory.smc.bytes("F1md"), [0])
        XCTAssertEqual(factory.smc.rpm("F0Tg"), 0)
    }

    func testDisconnectWithoutDriverDoesNotOpenTheSMC() {
        let factory = DriverFactory()
        let service = makeService(factory)
        service.clientDidConnect()
        service.clientDidDisconnect()
        // Extra invalidations must not drive the count negative.
        service.clientDidDisconnect()

        let replied = expectation(description: "drain")
        service.setCoolingPreset(99) { _, _ in replied.fulfill() }
        wait(for: [replied], timeout: 5)
        XCTAssertEqual(factory.created, 0)
    }

    func testShutdownRestoresAutomaticAndDropsTheDriver() {
        let factory = DriverFactory()
        let service = makeService(factory)
        XCTAssertTrue(write { service.setAllFans(rpm: 3_000, reply: $0) }.ok)

        service.restoreForShutdown()

        XCTAssertEqual(factory.smc.bytes("F0md"), [0])
        XCTAssertEqual(factory.smc.rpm("F0Tg"), 0)
        _ = fanCount(service)
        XCTAssertEqual(factory.created, 2)
    }

    // MARK: Client authorization

    func testClientRequirementFailsClosedWithoutTeam() {
        XCTAssertNil(FanBarHelperService.clientRequirementText(teamID: nil))
        XCTAssertNil(FanBarHelperService.clientRequirementText(teamID: ""))
    }

    func testClientRequirementPinsAppIdentifierAndTeam() throws {
        let requirement = try XCTUnwrap(FanBarHelperService.clientRequirementText(teamID: "ABCDE12345"))

        XCTAssertTrue(requirement.hasPrefix("anchor apple generic and "))
        XCTAssertTrue(requirement.contains("identifier \"\(FanBarService.appBundleID)\""))
        XCTAssertTrue(requirement.contains("certificate leaf[subject.OU] = \"ABCDE12345\""))
    }
}
