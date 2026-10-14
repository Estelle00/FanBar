import FanBarShared
import Foundation
import XCTest

final class RuntimeDiagnosticsTests: XCTestCase {
    func testJournalPersistsBoundedEventsAndRetainsStartupMarkers() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("runtime.json")
        let journal = RuntimeDiagnostics(url: url)
        journal.beginLaunch()
        for value in 0..<270 {
            journal.record(.control, .curve, .succeeded, value: Double(value) / 270)
        }
        let reopened = RuntimeDiagnostics(url: url)
        XCTAssertLessThanOrEqual(reopened.snapshot().count, 256)
        XCTAssertTrue(reopened.snapshot().contains { $0.action == .startup })
        reopened.beginLaunch()
        XCTAssertTrue(reopened.snapshot().contains { $0.action == .previousExitUnknown })
        XCTAssertLessThan(try Data(contentsOf: url).count, 131072)
        let permissions = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int
        XCTAssertEqual(permissions, 0o600)
    }

    func testNormalShutdownIsNotReportedAsUnknownExitAndRequestIDsSurvive() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("events.json")
        let journal = RuntimeDiagnostics(url: url)
        journal.beginLaunch()
        let id = UUID().uuidString.lowercased()
        DiagnosticRequestContext.$id.withValue(id) { journal.record(.control, .fixedRPM, .started, value: 2000) }
        journal.record(.app, .shutdown, .succeeded)
        let reopened = RuntimeDiagnostics(url: url)
        reopened.beginLaunch()
        XCTAssertFalse(reopened.snapshot().contains { $0.action == .previousExitUnknown })
        XCTAssertEqual(reopened.snapshot().first { $0.action == .fixedRPM }?.requestID, id)
    }

    func testLegacyCrashSummaryAlsoDropsFreeFormText() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = ["Process: FanBar [123]", "Path: /Users/private/FanBar", "Exception Type: EXC_CRASH (SIGABRT)",
            "Termination Reason: Namespace DYLD, Code 1", ""].joined(separator: "\n")
        try Data(fixture.utf8)
            .write(to: root.appendingPathComponent("FanBar_test.crash"))
        let summary = try XCTUnwrap(DiagnosticCrashReader.summaries(directory: root).first)
        XCTAssertEqual(summary.exception, "EXC_CRASH")
        XCTAssertEqual(summary.terminationNamespace, "DYLD")
        XCTAssertEqual(summary.terminationCode, 1)
    }

    func testCrashSummaryRemovesIdentityPathsAndUntrustedImageNames() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let body: [String: Any] = ["procName": "FanBar", "procPath": "/Users/private-person/FanBar",
            "exception": ["type": "EXC_BAD_ACCESS", "signal": "SIGSEGV", "message": "private-person"],
            "termination": ["namespace": "CODESIGNING", "code": 2], "faultingThread": 0,
            "threads": [["frames": [["imageIndex": 0, "imageOffset": 123], ["imageIndex": 1, "imageOffset": 456]]]],
            "usedImages": [["name": "FanBar", "path": "/Users/private-person/FanBar"], ["name": "private-person.dylib"]]]
        var data = Data("{\"incident_id\":\"private-uuid\"}\n".utf8)
        data.append(try JSONSerialization.data(withJSONObject: body))
        try data.write(to: root.appendingPathComponent("FanBar-test.ips"))
        let summaries = DiagnosticCrashReader.summaries(directory: root)
        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries.first?.frames.map(\.image), ["FanBar", "other"])
        let text = try XCTUnwrap(String(bytes: JSONEncoder().encode(summaries), encoding: .utf8))
        XCTAssertFalse(text.contains("private-person"))
        XCTAssertFalse(text.contains("private-uuid"))
        XCTAssertFalse(text.contains("/Users/"))
    }
}
