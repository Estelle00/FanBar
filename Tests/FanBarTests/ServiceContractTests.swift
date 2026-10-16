import FanBarShared
import Foundation
import XCTest

/// The Worker regenerates contracts/service-constants.json from its source and fails its
/// `--check` on drift; this test closes the loop for the native client, whose strict policy
/// validation would otherwise reject every upload after a server-only change.
final class ServiceContractTests: XCTestCase {
    private struct Constants: Decodable {
        struct Compatibility: Decodable {
            let policyVersion: String
            let retentionDays: Int
            let maximumReportBytes: Int
        }

        struct Diagnostics: Decodable {
            let policyVersion: String
            let retentionDays: Int
            let maximumBytes: Int
        }

        let compatibility: Compatibility
        let diagnostics: Diagnostics
    }

    func testClientConstantsMatchServiceContract() throws {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("contracts/service-constants.json")
        let contract = try JSONDecoder().decode(Constants.self, from: Data(contentsOf: file))

        XCTAssertEqual(ServiceContract.Compatibility.policyVersion, contract.compatibility.policyVersion)
        XCTAssertEqual(ServiceContract.Compatibility.retentionDays, contract.compatibility.retentionDays)
        XCTAssertEqual(ServiceContract.Compatibility.maximumReportBytes, contract.compatibility.maximumReportBytes)
        XCTAssertEqual(ServiceContract.Diagnostics.policyVersion, contract.diagnostics.policyVersion)
        XCTAssertEqual(ServiceContract.Diagnostics.retentionDays, contract.diagnostics.retentionDays)
        XCTAssertEqual(ServiceContract.Diagnostics.maximumBytes, contract.diagnostics.maximumBytes)
    }
}
