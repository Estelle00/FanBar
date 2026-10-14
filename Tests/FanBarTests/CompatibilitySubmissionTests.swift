import AppKit
import Foundation
import SwiftUI
import XCTest
@testable import FanBar

@MainActor
private final class MemoryCompatibilityReceipts: CompatibilityReceiptStoring {
    var items: [CompatibilitySavedReceipt] = []
    var refusesWrites = false
    func save(_ receipt: CompatibilitySavedReceipt) throws {
        if refusesWrites { throw CompatibilityServiceError.credentialStorage }
        items.removeAll { $0.reportID == receipt.reportID }
        items.append(receipt)
    }

    func receipts() throws -> [CompatibilitySavedReceipt] {
        items
    }

    func remove(reportID: String) throws {
        items.removeAll { $0.reportID == reportID }
    }
}

@MainActor
private final class StubCompatibilityService: CompatibilityReportServing {
    let servicePolicy: CompatibilityServicePolicy
    let store: MemoryCompatibilityReceipts
    var submissions: [CompatibilitySavedReceipt] = []
    var failNextSubmission = false
    var policyCalls = 0
    var credentialWasSavedBeforeSend = false

    init(policy: CompatibilityServicePolicy, store: MemoryCompatibilityReceipts) {
        servicePolicy = policy
        self.store = store
    }

    func policy() async throws -> CompatibilityServicePolicy {
        policyCalls += 1
        return servicePolicy
    }

    func submit(_ receipt: CompatibilitySavedReceipt) async throws -> CompatibilitySubmissionResponse {
        credentialWasSavedBeforeSend = store.items.contains { $0.deletionToken == receipt.deletionToken }
        submissions.append(receipt)
        if failNextSubmission {
            failNextSubmission = false
            throw CompatibilityServiceError.network
        }
        return CompatibilitySubmissionResponse(
            reportID: receipt.reportID, status: "pending", receivedAt: "2026-10-13T00:00:00Z",
            expiresAt: "2027-01-11T00:00:00Z", publishReport: receipt.publishReport,
            policyVersion: receipt.policyVersion
        )
    }

    func withdraw(_ receipt: CompatibilitySavedReceipt) async throws {}
}

@MainActor
final class CompatibilitySubmissionTests: XCTestCase {
    private func policy() throws -> CompatibilityServicePolicy {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("contracts/compatibility-policy.example.json"))
        return try JSONDecoder().decode(CompatibilityServicePolicy.self, from: data)
    }

    private func configuration() throws -> CompatibilityServiceConfiguration {
        try XCTUnwrap(CompatibilityServiceConfiguration(url: try XCTUnwrap(URL(string: "https://report.getfanbar.com"))))
    }

    private func reportData() throws -> Data {
        let controller = FanController(
            notificationCenter: nil, widgetSnapshotDestination: .disabled, makeReadingSource: { FakeFanReadingSource() }
        )
        return try CompatibilityReport(snapshot: XCTUnwrap(controller.compatibilitySnapshot)).jsonData()
    }

    func testPreviewDoesNotFetchPolicyOrSubmitAutomatically() throws {
        let store = MemoryCompatibilityReceipts()
        let service = StubCompatibilityService(policy: try policy(), store: store)
        _ = CompatibilityUploadCoordinator(data: try reportData(), configuration: try configuration(), api: service, store: store)
        XCTAssertEqual(service.policyCalls, 0)
        XCTAssertTrue(service.submissions.isEmpty)
        XCTAssertTrue(store.items.isEmpty)
    }

    func testSubmissionRequiresFreshConsentAndPolicy() async throws {
        let store = MemoryCompatibilityReceipts()
        let service = StubCompatibilityService(policy: try policy(), store: store)
        let upload = CompatibilityUploadCoordinator(data: try reportData(), configuration: try configuration(), api: service, store: store)
        await upload.submit(consent: false, publishReport: false)
        XCTAssertTrue(service.submissions.isEmpty)
        await upload.submit(consent: true, publishReport: false)
        XCTAssertTrue(service.submissions.isEmpty)
        await upload.loadPolicy()
        await upload.submit(consent: false, publishReport: false)
        XCTAssertTrue(service.submissions.isEmpty)
        XCTAssertTrue(store.items.isEmpty)
    }

    func testCredentialIsStoredBeforeSendingAndNotIncludedInReportBody() async throws {
        let store = MemoryCompatibilityReceipts()
        let service = StubCompatibilityService(policy: try policy(), store: store)
        let data = try reportData()
        let upload = CompatibilityUploadCoordinator(data: data, configuration: try configuration(), api: service, store: store)
        await upload.loadPolicy()
        await upload.submit(consent: true, publishReport: false)
        XCTAssertTrue(service.credentialWasSavedBeforeSend)
        let receipt = try XCTUnwrap(upload.receipt)
        XCTAssertNotNil(receipt.response)
        XCTAssertEqual(receipt.deletionToken.count, 43)
        XCTAssertEqual(receipt.reportData, data)
        XCTAssertFalse(receipt.publishReport)
        let request = CompatibilityReportService.submissionRequest(receipt)
        XCTAssertEqual(request.httpBody, data)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(receipt.deletionToken)")
        XCTAssertNil(request.url?.query)
        XCTAssertFalse(try XCTUnwrap(String(data: data, encoding: .utf8)).contains(receipt.deletionToken))
    }

    func testLostResponseRetryReusesIDCredentialAndPublicationChoice() async throws {
        let store = MemoryCompatibilityReceipts()
        let service = StubCompatibilityService(policy: try policy(), store: store)
        service.failNextSubmission = true
        let upload = CompatibilityUploadCoordinator(data: try reportData(), configuration: try configuration(), api: service, store: store)
        await upload.loadPolicy()
        await upload.submit(consent: true, publishReport: true)
        XCTAssertNil(upload.receipt?.response)
        XCTAssertEqual(store.items.count, 1)
        await upload.submit(consent: true, publishReport: false)
        XCTAssertEqual(service.submissions.count, 2)
        XCTAssertEqual(service.submissions[0].reportID, service.submissions[1].reportID)
        XCTAssertEqual(service.submissions[0].deletionToken, service.submissions[1].deletionToken)
        XCTAssertTrue(service.submissions[1].publishReport)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertNotNil(upload.receipt?.response)
    }

    func testStorageFailurePreventsUpload() async throws {
        let store = MemoryCompatibilityReceipts()
        store.refusesWrites = true
        let service = StubCompatibilityService(policy: try policy(), store: store)
        let upload = CompatibilityUploadCoordinator(data: try reportData(), configuration: try configuration(), api: service, store: store)
        await upload.loadPolicy()
        await upload.submit(consent: true, publishReport: false)
        XCTAssertTrue(service.submissions.isEmpty)
        XCTAssertNil(upload.receipt)
    }

    func testPendingReceiptCanResumeAfterReopeningWithoutChangingIdentity() async throws {
        let store = MemoryCompatibilityReceipts()
        let service = StubCompatibilityService(policy: try policy(), store: store)
        service.failNextSubmission = true
        let upload = CompatibilityUploadCoordinator(data: try reportData(), configuration: try configuration(), api: service, store: store)
        await upload.loadPolicy()
        await upload.submit(consent: true, publishReport: false)
        let saved = try XCTUnwrap(store.items.first)
        let resumed = CompatibilityUploadCoordinator(
            data: saved.reportData, configuration: try configuration(), api: service, store: store, receipt: saved
        )
        await resumed.loadPolicy()
        await resumed.submit(consent: true, publishReport: false)
        XCTAssertEqual(resumed.receipt?.reportID, saved.reportID)
        XCTAssertEqual(resumed.receipt?.deletionToken, saved.deletionToken)
        XCTAssertNotNil(resumed.receipt?.response)
    }

    func testConfigurationRejectsUnsafeDestinations() throws {
        for value in ["http://report.getfanbar.com", "https://user:secret@report.getfanbar.com",
            "https://report.getfanbar.com?token=secret"] {
            XCTAssertNil(CompatibilityServiceConfiguration(url: try XCTUnwrap(URL(string: value))))
        }
        let local = try XCTUnwrap(URL(string: "http://127.0.0.1:8787"))
        XCTAssertNil(CompatibilityServiceConfiguration(url: local))
        XCTAssertNotNil(CompatibilityServiceConfiguration(url: local, allowsLocalDevelopment: true))
        try policy().validate(for: configuration())
    }

    func testPreviewStatesStayBoundedAndNeverSendOnAppearance() async throws {
        let store = MemoryCompatibilityReceipts()
        let service = StubCompatibilityService(policy: try policy(), store: store)
        let data = try reportData()
        let upload = CompatibilityUploadCoordinator(data: data, configuration: try configuration(), api: service, store: store)
        let initial = fittedSize(CompatibilityReportPreview(data: data, coordinator: upload))
        XCTAssertEqual(initial.width, 510, accuracy: 0.5)
        XCTAssertEqual(initial.height, 550, accuracy: 0.5)
        XCTAssertEqual(service.policyCalls, 0)
        XCTAssertTrue(service.submissions.isEmpty)

        await upload.loadPolicy()
        let prepared = fittedSize(CompatibilityReportPreview(data: data, coordinator: upload))
        XCTAssertEqual(prepared, initial)
        XCTAssertTrue(service.submissions.isEmpty)
        await upload.submit(consent: true, publishReport: false)
        let received = fittedSize(CompatibilityReportPreview(data: data, coordinator: upload))
        XCTAssertEqual(received, initial)
        XCTAssertEqual(service.submissions.count, 1)

        let records = fittedSize(CompatibilityReceiptsView(store: store))
        XCTAssertEqual(records.width, 510, accuracy: 0.5)
        XCTAssertEqual(records.height, 450, accuracy: 0.5)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(service.submissions.count, 1)
    }

    func testUnconfirmedSubmissionIsVisibleWithoutDiscardingWithdrawalCredential() async throws {
        let store = MemoryCompatibilityReceipts()
        let service = StubCompatibilityService(policy: try policy(), store: store)
        service.failNextSubmission = true
        let data = try reportData()
        let upload = CompatibilityUploadCoordinator(data: data, configuration: try configuration(), api: service, store: store)
        await upload.loadPolicy()
        await upload.submit(consent: true, publishReport: true)
        let preview = fittedSize(CompatibilityReportPreview(data: data, coordinator: upload))
        XCTAssertEqual(preview.height, 550, accuracy: 0.5)
        let records = fittedSize(CompatibilityReceiptsView(store: store))
        XCTAssertEqual(records.height, 450, accuracy: 0.5)
        XCTAssertNotNil(store.items.first?.deletionToken)
        XCTAssertNil(store.items.first?.response)
        XCTAssertEqual(service.submissions.count, 1)
    }

    private func fittedSize(_ view: some View) -> NSSize {
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 510, height: 550)
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        host.layoutSubtreeIfNeeded()
        return host.fittingSize
    }

    func testUploadEntryLoadsRulesWithoutSendingUntilConfirmed() async throws {
        let store = MemoryCompatibilityReceipts()
        let service = StubCompatibilityService(policy: try policy(), store: store)
        let data = try reportData()
        let upload = CompatibilityUploadCoordinator(data: data, configuration: try configuration(), api: service, store: store)
        let host = NSHostingView(rootView: CompatibilityReportPreview(data: data, preparesSubmission: true, coordinator: upload))
        host.frame = NSRect(x: 0, y: 0, width: 510, height: 550)
        host.layoutSubtreeIfNeeded()
        for _ in 0..<10 {
            await Task.yield()
        }
        XCTAssertEqual(service.policyCalls, 1)
        XCTAssertNotNil(upload.policy)
        XCTAssertTrue(service.submissions.isEmpty)
        XCTAssertTrue(store.items.isEmpty)
    }

    func testHandsOnConfirmationChangesPreviewAndUploadWithoutReplacingDetection() async throws {
        let store = MemoryCompatibilityReceipts()
        let service = StubCompatibilityService(policy: try policy(), store: store)
        let upload = CompatibilityUploadCoordinator(data: try reportData(), configuration: try configuration(), api: service, store: store)
        let initial = try JSONDecoder().decode(CompatibilityReport.self, from: upload.data)
        XCTAssertFalse(upload.isUserConfirmedWorking(.manualControl))
        upload.setUserConfirmedWorking(.manualControl, confirmed: true)
        upload.setUserConfirmedWorking(.smartCooling, confirmed: true)
        upload.setUserConfirmedWorking(.cpuTemperature, confirmed: true)
        let confirmed = try JSONDecoder().decode(CompatibilityReport.self, from: upload.data)
        XCTAssertEqual(confirmed.reportID, initial.reportID)
        XCTAssertEqual(confirmed.capabilities.first { $0.capability == .manualControl }?.status,
            initial.capabilities.first { $0.capability == .manualControl }?.status)
        XCTAssertTrue(upload.isUserConfirmedWorking(.manualControl))
        XCTAssertFalse(upload.isUserConfirmedWorking(.cpuTemperature))
        await upload.loadPolicy()
        service.failNextSubmission = true
        await upload.submit(consent: true, publishReport: false)
        let sent = try XCTUnwrap(service.submissions.first?.reportData)
        XCTAssertEqual(sent, upload.data)
        upload.setUserConfirmedWorking(.manualControl, confirmed: false)
        XCTAssertTrue(upload.isUserConfirmedWorking(.manualControl))
        await upload.submit(consent: true, publishReport: false)
        XCTAssertEqual(service.submissions.last?.reportData, sent)
    }

    func testUncheckingConfirmationOmitsOptionalField() throws {
        let upload = CompatibilityUploadCoordinator(data: try reportData())
        upload.setUserConfirmedWorking(.manualControl, confirmed: true)
        upload.setUserConfirmedWorking(.manualControl, confirmed: false)
        XCTAssertFalse(upload.isUserConfirmedWorking(.manualControl))
        let json = try XCTUnwrap(String(bytes: upload.data, encoding: .utf8))
        XCTAssertFalse(json.contains("userConfirmedWorking"))
    }

    func testTokensAreIndependentPerReport() throws {
        let first = try CompatibilitySavedReceipt.makeToken()
        let second = try CompatibilitySavedReceipt.makeToken()
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(first.count, 43)
        XCTAssertTrue(first.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
    }
}
