import Foundation
import XCTest
@testable import FanBar

@MainActor
final class DiagnosticReportTests: XCTestCase {
    func testCollectionIncludesMissingSensorsWithoutChangingControl() async throws {
        let source = FakeFanReadingSource()
        let controller = FanController(notificationCenter: nil, widgetSnapshotDestination: .disabled,
                                       makeReadingSource: { source }, makeDiagnosticSource: { FakeFanReadingSource() })
        let before = controller.mode
        let report = await controller.collectDiagnosticReport()
        XCTAssertEqual(controller.mode, before)
        XCTAssertNotNil(report.thermal)
        XCTAssertNotNil(report.fanCount)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: report.jsonData()) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["schemaVersion",
            "diagnosticID", "capturedAt", "device", "helperState", "thermal",
            "fanCount", "probes", "recentSamples", "runtimeEvents", "crashes",
            "runtimeContext", "helperLogAvailable", "crashLogAvailable",
            "helperStateSource", "runningHelper"])
        let thermal = try XCTUnwrap(object["thermal"] as? [String: Any])
        XCTAssertNotNil(thermal["sampledAt"] as? String)
        let another = await controller.collectDiagnosticReport()
        XCTAssertNotEqual(report.diagnosticID, another.diagnosticID)
    }

    func testConnectionFailuresRemainDiagnosableWithoutExceptionText() async {
        let controller = FanController(notificationCenter: nil, widgetSnapshotDestination: .disabled,
                                       makeReadingSource: { throw SMCError.unavailable(-536870203) },
                                       makeDiagnosticSource: { throw SMCError.unavailable(-536870203) })
        let report = await controller.collectDiagnosticReport()
        XCTAssertEqual(report.connectionErrorCode, -536870203)
        XCTAssertNil(report.thermal)
        XCTAssertTrue(report.probes.isEmpty)
    }

    func testCollectionDoesNotBlockTheMainActor() async {
        let controller = FanController(notificationCenter: nil, widgetSnapshotDestination: .disabled,
                                       makeReadingSource: { FakeFanReadingSource() },
                                       makeDiagnosticSource: {
                                           XCTAssertFalse(Thread.isMainThread)
                                           Thread.sleep(forTimeInterval: 0.3)
                                           return FakeFanReadingSource()
                                       })
        let collection = Task { await controller.collectDiagnosticReport() }
        // A main-actor job queued behind the collection must run while the slow source is read,
        // not after it; the old synchronous collection held the main actor for the whole read.
        let mainActorTurn = await Task { @MainActor in Date() }.value
        let report = await collection.value
        XCTAssertGreaterThan(Date().timeIntervalSince(mainActorTurn), 0.2)
        XCTAssertNotNil(report.fanCount)
    }

    func testReadOnlySensorProbeOnLocalMac() throws {
        guard ProcessInfo.processInfo.environment["FANBAR_READ_ONLY_DIAGNOSTIC_CHECK"] == "1" else {
            throw XCTSkip("Opt-in read-only hardware probe")
        }
        let source = try SMCClient()
        let probes = source.diagnosticProbes()
        let discovery = try XCTUnwrap(source.diagnosticDiscovery)
        if discovery.errorCode == nil, discovery.scannedKeyCount == discovery.reportedKeyCount {
            XCTAssertFalse(discovery.truncated, "A complete scan is not truncated, even when probes are capped")
        }
        XCTAssertFalse(probes.isEmpty)
        XCTAssertLessThanOrEqual(probes.count, 256)
        XCTAssertTrue(probes.contains { $0.source == "embeddedNVMe" })
        XCTAssertTrue(probes.contains { $0.source == "smartBattery" })
        let available = probes.filter { $0.source == "smc" && $0.result == "available" }
        XCTAssertTrue(available.allSatisfy { $0.dataType != nil && $0.rawBytes != nil })
        let report = DiagnosticReport(diagnosticID: UUID().uuidString.lowercased(),
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            device: CompatibilityDevice.current(helperVersion: "26"), helperState: "enabled",
            probes: probes, discovery: discovery)
        XCTAssertLessThan(try report.jsonData().count, 131072)
        print("Diagnostic probe: entries=\(probes.count), scanned=\(discovery.scannedKeyCount)/\(discovery.reportedKeyCount ?? -1), "
            + "truncated=\(discovery.truncated), probesTruncated=\(discovery.probesTruncated)")
    }

    func testDiagnosticClientRoundTripAgainstLocalWorker() async throws {
        guard let value = ProcessInfo.processInfo.environment["FANBAR_COMPATIBILITY_TEST_SERVICE_URL"],
              let url = URL(string: value) else { throw XCTSkip("Requires a local Worker") }
        XCTAssertTrue(["localhost", "127.0.0.1"].contains(url.host ?? ""))
        let config = try XCTUnwrap(CompatibilityServiceConfiguration(url: url, allowsLocalDevelopment: true))
        let client = CompatibilityReportService(configuration: config)
        let policy = try await client.diagnosticPolicy()
        let report = DiagnosticReport(diagnosticID: UUID().uuidString.lowercased(),
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            device: CompatibilityDevice(modelIdentifier: "TestMac1,1",
                processor: "Synthetic test", macOSVersion: "15.0.0", appVersion: "1.0",
                helperVersion: "26"),
            helperState: "enabled", thermal: ThermalReading(sampledAt: Date(), cpuCelsius: 42, gpuCelsius: nil, hasBuiltInBattery: false),
            fanCount: 1, probes: [DiagnosticProbe(sensor: "gpu", key: "Tg05", result: "readFailed", code: -1)])
        let receipt = CompatibilitySavedReceipt(reportID: report.diagnosticID, serviceURL: url,
            deletionToken: try CompatibilitySavedReceipt.makeToken(), reportData: try report.jsonData(),
            publishReport: false, policyVersion: policy.version, createdAt: Date())
        let result = try await client.submitDiagnostic(receipt)
        XCTAssertFalse(result.publishReport)
        XCTAssertEqual(result.reportID, report.diagnosticID)
        let retry = try await client.submitDiagnostic(receipt)
        XCTAssertEqual(result, retry)
        try await client.withdrawDiagnostic(receipt)
        try await client.withdrawDiagnostic(receipt)
    }

    func testRunningHelperIsQueriedOnlyWhenTheHelperIsEnabled() async {
        final class Counter: @unchecked Sendable { var calls = 0 }
        let counter = Counter()
        let query: @Sendable () async -> HelperBuildQuery = {
            counter.calls += 1
            return .reported("26")
        }
        for state in [FanController.HelperState.requiresApproval, .notRegistered, .unavailable] {
            let result = await FanController.runningHelper(state: state, query: query)
            XCTAssertEqual(result.status, "notQueried")
        }
        XCTAssertEqual(counter.calls, 0, "A helper that is not enabled is never queried")
        let enabled = await FanController.runningHelper(state: .enabled, query: query)
        XCTAssertEqual(enabled, DiagnosticRunningHelper(.reported("26")))
        XCTAssertEqual(counter.calls, 1)
    }

    func testRunningHelperStatusesEncodeWithoutFreeFormText() throws {
        let encode = { (value: DiagnosticRunningHelper) throws -> [String: Any] in
            try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
        }
        XCTAssertEqual(try encode(DiagnosticRunningHelper(.reported("26"))) as NSDictionary, ["status": "reported", "build": "26"])
        XCTAssertEqual(try encode(DiagnosticRunningHelper(.noReply)) as NSDictionary, ["status": "noReply"])
        XCTAssertEqual(try encode(DiagnosticRunningHelper(.connectionFailed(4097))) as NSDictionary,
                       ["status": "connectionFailed", "code": 4097])
        XCTAssertEqual(try encode(DiagnosticRunningHelper(nil)) as NSDictionary, ["status": "notQueried"])
    }

    func testCollectedReportCarriesTheRunningHelperField() async throws {
        let controller = FanController(notificationCenter: nil, widgetSnapshotDestination: .disabled,
                                       makeReadingSource: { FakeFanReadingSource() },
                                       makeDiagnosticSource: { FakeFanReadingSource() },
                                       queryRunningHelperBuild: { .reported("1") })
        let report = await controller.collectDiagnosticReport()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: report.jsonData()) as? [String: Any])
        // Tests have no registered helper, so the query is skipped and recorded as such.
        XCTAssertEqual((object["runningHelper"] as? [String: Any])?["status"] as? String, "notQueried")
    }
}
