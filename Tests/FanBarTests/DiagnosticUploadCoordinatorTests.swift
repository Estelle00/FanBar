import AppKit
import Foundation
import SwiftUI
import XCTest
@testable import FanBar

@MainActor
private final class MemoryDiagnosticReceipts: CompatibilityReceiptStoring {
    var items: [CompatibilitySavedReceipt] = []
    var refusesWrites = false

    func save(_ receipt: CompatibilitySavedReceipt) throws {
        if refusesWrites { throw CompatibilityServiceError.credentialStorage }
        items.removeAll { $0.reportID == receipt.reportID }
        items.append(receipt)
    }

    func receipts() throws -> [CompatibilitySavedReceipt] {
        items.sorted { $0.createdAt > $1.createdAt }
    }

    func remove(reportID: String) throws {
        items.removeAll { $0.reportID == reportID }
    }
}

@MainActor
private final class StubDiagnosticService: DiagnosticUploadServing {
    let configuration: CompatibilityServiceConfiguration
    let store: MemoryDiagnosticReceipts
    var policyError: CompatibilityServiceError?
    var failNextSubmission = false
    var failWithdrawal = false
    var submissions: [CompatibilitySavedReceipt] = []
    var withdrawals: [String] = []
    var credentialWasSavedBeforeSend = false

    init(configuration: CompatibilityServiceConfiguration, store: MemoryDiagnosticReceipts) {
        self.configuration = configuration
        self.store = store
    }

    func diagnosticPolicy() async throws -> DiagnosticPolicy {
        if let policyError { throw policyError }
        return DiagnosticPolicy(version: DiagnosticPolicy.supportedVersion,
                                serviceOrigin: "https://report.getfanbar.com", retentionDays: 90, maximumBytes: 262_144)
    }

    func submitDiagnostic(_ receipt: CompatibilitySavedReceipt) async throws -> CompatibilitySubmissionResponse {
        credentialWasSavedBeforeSend = store.items.contains { $0.deletionToken == receipt.deletionToken }
        submissions.append(receipt)
        if failNextSubmission {
            failNextSubmission = false
            throw CompatibilityServiceError.network
        }
        return CompatibilitySubmissionResponse(
            reportID: receipt.reportID, status: "received", receivedAt: "2026-10-15T00:00:00Z",
            expiresAt: "2027-01-13T00:00:00Z", publishReport: false, policyVersion: DiagnosticPolicy.supportedVersion
        )
    }

    func withdrawDiagnostic(_ receipt: CompatibilitySavedReceipt) async throws {
        if failWithdrawal { throw CompatibilityServiceError.network }
        withdrawals.append(receipt.reportID)
    }
}

/// Holds the fakes the coordinator's closures capture, so tests never capture `self`.
@MainActor
private final class UploadFixture {
    let store = MemoryDiagnosticReceipts()
    let service: StubDiagnosticService
    var serviceURLs: [URL?] = []
    var collections = 0
    var runningHelper = DiagnosticRunningHelper(nil)

    init() throws {
        let configuration = try XCTUnwrap(CompatibilityServiceConfiguration(
            url: try XCTUnwrap(URL(string: "https://report.getfanbar.com"))
        ))
        service = StubDiagnosticService(configuration: configuration, store: store)
    }

    func makeReport() -> DiagnosticReport {
        collections += 1
        var report = DiagnosticReport(
            diagnosticID: UUID().uuidString.lowercased(), capturedAt: "2026-10-15T00:00:00Z",
            device: CompatibilityDevice(modelIdentifier: "Mac16,10", processor: "Apple M4",
                                        macOSVersion: "27.0.0", appVersion: "0.6.0", helperVersion: "27"),
            helperState: "enabled", probes: []
        )
        report.runningHelper = runningHelper
        return report
    }

    func makeCoordinator() -> DiagnosticUploadCoordinator {
        DiagnosticUploadCoordinator(
            collect: { [self] in makeReport() },
            makeService: { [self] url in
                serviceURLs.append(url)
                return service
            },
            store: store
        )
    }
}

@MainActor
final class DiagnosticUploadCoordinatorTests: XCTestCase {
    func testPreparationCollectsAndLoadsRulesButNeverSends() async throws {
        let fixture = try UploadFixture()
        let model = fixture.makeCoordinator()
        await model.prepare()
        XCTAssertNotNil(model.report)
        XCTAssertNotNil(model.policy)
        XCTAssertNil(model.error)
        XCTAssertFalse(model.canSubmit, "Consent must be given explicitly")
        XCTAssertTrue(fixture.service.submissions.isEmpty)
        XCTAssertTrue(fixture.store.items.isEmpty)
    }

    func testUploadRequiresConsentAndAValidatedPolicy() async throws {
        let fixture = try UploadFixture()
        let model = fixture.makeCoordinator()
        await model.prepare()
        await model.submit()
        XCTAssertTrue(fixture.service.submissions.isEmpty)

        fixture.service.policyError = .policyChanged
        let stale = fixture.makeCoordinator()
        await stale.prepare()
        stale.consent = true
        XCTAssertNil(stale.policy)
        XCTAssertFalse(stale.canSubmit)
        XCTAssertEqual(stale.error, CompatibilityServiceError.policyChanged.message)
        await stale.submit()
        XCTAssertTrue(fixture.service.submissions.isEmpty)
        XCTAssertTrue(fixture.store.items.isEmpty)
    }

    func testCredentialIsSavedBeforeSendingAndUploadHappensOnce() async throws {
        let fixture = try UploadFixture()
        let model = fixture.makeCoordinator()
        await model.prepare()
        model.consent = true
        await model.submit()
        XCTAssertTrue(fixture.service.credentialWasSavedBeforeSend)
        let receipt = try XCTUnwrap(model.receipt)
        XCTAssertEqual(receipt.reportID, model.report?.diagnosticID)
        XCTAssertFalse(receipt.publishReport)
        XCTAssertNotNil(receipt.response)
        XCTAssertEqual(model.history.map(\.reportID), [receipt.reportID])
        XCTAssertNotNil(fixture.store.items.first?.response)
        XCTAssertFalse(model.canSubmit)
        await model.submit()
        XCTAssertEqual(fixture.service.submissions.count, 1)
        // The uploaded body is exactly the previewed report, and carries no credential.
        let body = try XCTUnwrap(String(data: receipt.reportData, encoding: .utf8))
        XCTAssertFalse(body.contains(receipt.deletionToken))
    }

    func testLostResponseKeepsTheCredentialAndRetryReusesTheSameIdentity() async throws {
        let fixture = try UploadFixture()
        let model = fixture.makeCoordinator()
        await model.prepare()
        model.consent = true
        fixture.service.failNextSubmission = true
        await model.submit()
        XCTAssertEqual(model.error, CompatibilityServiceError.network.message)
        let pending = try XCTUnwrap(model.receipt)
        XCTAssertNil(pending.response)
        XCTAssertEqual(fixture.store.items.map(\.reportID), [pending.reportID], "A possibly delivered upload stays withdrawable")

        await model.send(try XCTUnwrap(model.history.first))
        XCTAssertEqual(fixture.service.submissions.count, 2)
        XCTAssertEqual(Set(fixture.service.submissions.map(\.reportID)), [pending.reportID])
        XCTAssertEqual(Set(fixture.service.submissions.map(\.deletionToken)), [pending.deletionToken])
        XCTAssertNotNil(model.receipt?.response)
        XCTAssertNil(model.error)
    }

    func testCredentialStorageFailurePreventsUpload() async throws {
        let fixture = try UploadFixture()
        let model = fixture.makeCoordinator()
        await model.prepare()
        model.consent = true
        fixture.store.refusesWrites = true
        await model.submit()
        XCTAssertTrue(fixture.service.submissions.isEmpty)
        XCTAssertNil(model.receipt)
        XCTAssertEqual(model.error, CompatibilityServiceError.credentialStorage.message)
    }

    func testWithdrawingTheCurrentUploadNeverReusesItsID() async throws {
        let fixture = try UploadFixture()
        let model = fixture.makeCoordinator()
        await model.prepare()
        model.consent = true
        await model.submit()
        let uploaded = try XCTUnwrap(model.receipt)

        await model.withdraw(uploaded)
        XCTAssertEqual(fixture.service.withdrawals, [uploaded.reportID])
        XCTAssertTrue(fixture.store.items.isEmpty)
        XCTAssertTrue(model.history.isEmpty)
        XCTAssertNil(model.receipt)
        XCTAssertFalse(model.consent, "A new report needs fresh consent")
        XCTAssertEqual(fixture.collections, 2)
        XCTAssertNotEqual(model.report?.diagnosticID, uploaded.reportID)
        XCTAssertFalse(model.busy)
    }

    func testFailedWithdrawalKeepsTheCredential() async throws {
        let fixture = try UploadFixture()
        let model = fixture.makeCoordinator()
        await model.prepare()
        model.consent = true
        await model.submit()
        let uploaded = try XCTUnwrap(model.receipt)
        fixture.service.failWithdrawal = true
        await model.withdraw(uploaded)
        XCTAssertEqual(fixture.store.items.map(\.reportID), [uploaded.reportID])
        XCTAssertEqual(model.receipt?.reportID, uploaded.reportID)
        XCTAssertEqual(model.error, CompatibilityServiceError.network.message)
    }

    func testHistoryItemsAreSentToTheServiceTheyWereCreatedFor() async throws {
        let fixture = try UploadFixture()
        let model = fixture.makeCoordinator()
        await model.prepare()
        let other = try XCTUnwrap(URL(string: "https://staging.getfanbar.com"))
        let item = CompatibilitySavedReceipt(
            reportID: UUID().uuidString.lowercased(), serviceURL: other, deletionToken: try CompatibilitySavedReceipt.makeToken(),
            reportData: Data("{}".utf8), publishReport: false, policyVersion: DiagnosticPolicy.supportedVersion, createdAt: Date()
        )
        try fixture.store.save(item)
        fixture.serviceURLs = []
        await model.withdraw(item)
        XCTAssertEqual(fixture.serviceURLs, [other])
        XCTAssertEqual(fixture.service.withdrawals, [item.reportID])
    }

    func testLiveServiceRejectsUnsafeHistoryDestinations() throws {
        let insecure = try XCTUnwrap(URL(string: "http://report.example.com"))
        XCTAssertThrowsError(try DiagnosticUploadCoordinator.liveService(for: insecure))
        let secure = try XCTUnwrap(URL(string: "https://report.getfanbar.com"))
        XCTAssertEqual(try DiagnosticUploadCoordinator.liveService(for: secure).configuration.baseURL, secure)
    }

    func testStaleHelperIsFlaggedOnlyForAReportedMismatch() async throws {
        let fixture = try UploadFixture()
        let cases: [(HelperBuildQuery?, String?)] = [
            (.reported("26"), "26"), (.reported("27"), nil), (.noReply, nil), (.connectionFailed(4097), nil), (nil, nil),
        ]
        for (query, expected) in cases {
            fixture.runningHelper = DiagnosticRunningHelper(query)
            let model = fixture.makeCoordinator()
            await model.prepare()
            XCTAssertEqual(model.staleHelperBuild, expected, "\(String(describing: query))")
        }
    }

    func testSheetRendersEveryStateWithoutUploading() async throws {
        let fixture = try UploadFixture()
        let controller = FanController(notificationCenter: nil, widgetSnapshotDestination: .disabled,
                                       makeReadingSource: { FakeFanReadingSource() })
        fixture.runningHelper = DiagnosticRunningHelper(.reported("26"))
        let model = fixture.makeCoordinator()
        func render() {
            let host = NSHostingView(rootView: DiagnosticUploadView(controller: controller, model: model))
            host.frame = NSRect(x: 0, y: 0, width: 560, height: 600)
            host.layoutSubtreeIfNeeded()
            XCTAssertEqual(host.bounds.width, 560, accuracy: 0.5)
        }
        render() // Collecting
        await model.prepare()
        render() // Preview with a stale-helper warning
        XCTAssertTrue(fixture.service.submissions.isEmpty)
        model.consent = true
        await model.submit()
        render() // Uploaded, with history
        XCTAssertEqual(fixture.service.submissions.count, 1)
        XCTAssertEqual(controller.mode, .automatic)
    }
}
