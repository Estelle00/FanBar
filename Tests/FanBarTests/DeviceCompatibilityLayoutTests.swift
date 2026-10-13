import AppKit
import SwiftUI
import XCTest
@testable import FanBar

@MainActor
final class DeviceCompatibilityLayoutTests: XCTestCase {
    func testCapabilityStatesFitScrollableNativeWindowWithoutChangingControl() {
        for scenario in 0..<3 {
            let source = FakeFanReadingSource(readings: scenario == 1 ? [] : [
                FanReading(index: 0, minimumRPM: 1200, currentRPM: 1850, maximumRPM: 6000, isManual: false),
            ])
            if scenario == 2 { source.error = SMCError.unavailable(-1) }
            let controller = FanController(
                notificationCenter: nil, widgetSnapshotDestination: .disabled, makeReadingSource: { source }
            )
            let host = NSHostingView(rootView: DeviceCompatibilityView(controller: controller))
            host.frame = NSRect(x: 0, y: 0, width: 560, height: 570)
            host.layoutSubtreeIfNeeded()
            XCTAssertEqual(host.fittingSize.width, 560, accuracy: 0.5)
            XCTAssertEqual(host.fittingSize.height, 570, accuracy: 0.5)
            XCTAssertEqual(controller.mode, .automatic)
            XCTAssertNotNil(controller.compatibilitySnapshot)
        }
    }

    func testReportPreviewFitsNativeSettingsWidth() throws {
        let source = FakeFanReadingSource()
        let controller = FanController(
            notificationCenter: nil, widgetSnapshotDestination: .disabled, makeReadingSource: { source }
        )
        let snapshot = try XCTUnwrap(controller.compatibilitySnapshot)
        let data = try CompatibilityReport(snapshot: snapshot).jsonData()
        let host = NSHostingView(rootView: CompatibilityReportPreview(data: data))
        host.layoutSubtreeIfNeeded()
        XCTAssertEqual(host.fittingSize.width, 510, accuracy: 0.5)
        XCTAssertLessThan(host.fittingSize.height, 600)
    }
}
