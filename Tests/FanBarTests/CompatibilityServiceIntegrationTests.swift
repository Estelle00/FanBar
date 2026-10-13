import Foundation
import XCTest
@testable import FanBar

@MainActor
final class CompatibilityServiceIntegrationTests: XCTestCase {
    /// Uses only synthetic inventory and a local Worker/D1. No real machine data is sent.
    func testNativeClientRoundTripAgainstLocalWorker() async throws {
        guard let value = ProcessInfo.processInfo.environment["FANBAR_COMPATIBILITY_TEST_SERVICE_URL"],
              let url = URL(string: value) else {
            throw XCTSkip("Set FANBAR_COMPATIBILITY_TEST_SERVICE_URL to run the local Worker integration test")
        }
        XCTAssertTrue(["127.0.0.1", "localhost"].contains(url.host ?? ""))
        let configuration = try XCTUnwrap(CompatibilityServiceConfiguration(url: url, allowsLocalDevelopment: true))
        let service = CompatibilityReportService(configuration: configuration)
        let policy = try await service.policy()
        XCTAssertEqual(policy.version, CompatibilityServicePolicy.supportedVersion)
        let device = CompatibilityDevice(
            modelIdentifier: "TestMac1,1", processor: "Synthetic integration test", macOSVersion: "15.0.0",
            appVersion: "1.0", helperVersion: "10"
        )
        let observation = CompatibilityObservation(
            sampledAt: Date(), thermal: ThermalReading(sampledAt: Date(), cpuCelsius: 52, gpuCelsius: nil),
            fanCount: 2, connectionFailed: false
        )
        let snapshot = CompatibilitySnapshot.make(
            device: device, observation: observation, helperState: .enabled,
            manualEvidence: .unverified, curveEvidence: .unverified
        )
        let report = CompatibilityReport(snapshot: snapshot)
        let receipt = CompatibilitySavedReceipt(
            reportID: report.reportID.uuidString.lowercased(), serviceURL: configuration.baseURL,
            deletionToken: try CompatibilitySavedReceipt.makeToken(), reportData: try report.jsonData(),
            publishReport: false, policyVersion: policy.version, createdAt: Date()
        )
        let response = try await service.submit(receipt)
        XCTAssertEqual(response.reportID, receipt.reportID)
        XCTAssertFalse(response.publishReport)
        XCTAssertEqual(response.status, "pending")
        let retry = try await service.submit(receipt)
        XCTAssertEqual(retry, response)
        try await service.withdraw(receipt)
        try await service.withdraw(receipt)
    }
}
