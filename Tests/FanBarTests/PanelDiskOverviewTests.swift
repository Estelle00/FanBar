import FanBarShared
import SwiftUI
import XCTest
@testable import FanBar

@MainActor
final class PanelDiskOverviewTests: XCTestCase {
    private let gibibyte: UInt64 = 1_073_741_824

    private func disk(_ id: String, total: UInt64, free: UInt64) -> DiskVolumeUsage {
        DiskVolumeUsage(
            id: id, name: id == "/" ? "Macintosh HD" : "External",
            isInternal: id == "/", usedBytes: (total - free) * gibibyte, totalBytes: total * gibibyte
        )
    }

    private func panel(_ disks: [DiskVolumeUsage]) -> PanelResourceList {
        PanelResourceList(
            usage: SystemUsage(disks: disks), thermal: nil, cpuHistory: [], gpuHistory: [],
            animates: false, expanded: .constant(nil)
        )
    }

    func testStartupDiskFullWarningSurvivesLargeExternalVolume() {
        let external = disk("/Volumes/Archive", total: 8192, free: 8000)
        for free: UInt64 in [1, 10] {
            let startup = disk("/", total: 512, free: free)
            for volumes in [[startup, external], [external, startup]] {
                let view = panel(volumes)
                XCTAssertEqual(view.diskLevel, .critical)
                XCTAssertEqual(view.freeDiskBytes, free * gibibyte)
                XCTAssertEqual(view.diskTotalBytes, 512 * gibibyte)
                XCTAssertEqual(view.diskFraction ?? -1, Double(512 - free) / 512, accuracy: 1e-9)
                XCTAssertEqual(view.diskTitle, fanBarText("启动盘", "Startup disk"))
            }
        }
    }

    func testStartupDiskLowSpaceUsesAbsoluteAndPercentageThresholds() {
        let external = disk("/Volumes/Archive", total: 8192, free: 8000)
        for (total, free): (UInt64, UInt64) in [(512, 12), (1024, 50)] {
            let view = panel([external, disk("/", total: total, free: free)])
            XCTAssertEqual(view.diskLevel, .elevated)
            XCTAssertEqual(view.freeDiskBytes, free * gibibyte)
            XCTAssertEqual(view.diskTotalBytes, total * gibibyte)
        }
    }

    func testHealthyStartupDiskIsNotReplacedByFullExternalVolume() {
        let view = panel([
            disk("/Volumes/Small", total: 100, free: 1),
            disk("/", total: 512, free: 200)
        ])
        XCTAssertEqual(view.diskLevel, .normal)
        XCTAssertEqual(view.freeDiskBytes, 200 * gibibyte)
        XCTAssertEqual(view.diskTotalBytes, 512 * gibibyte)
    }

    func testMissingStartupDiskDoesNotBorrowOtherVolumesCapacity() {
        var data = disk("/System/Volumes/Data", total: 512, free: 200)
        data.isInternal = true
        for volumes in [[], [disk("/Volumes/Archive", total: 8192, free: 8000)], [data]] {
            let view = panel(volumes)
            XCTAssertNil(view.freeDiskBytes)
            XCTAssertNil(view.diskTotalBytes)
            XCTAssertNil(view.diskFraction)
            XCTAssertEqual(view.diskLevel, .normal)
        }
    }

    func testFreeSpaceThresholdBoundaries() {
        let cases: [((UInt64, UInt64), ResourceLevel)] = [
            ((4, 100), .critical), ((5, 100), .elevated),
            ((19, 100), .elevated), ((20, 100), .normal),
            ((19, 1000), .critical), ((20, 1000), .elevated),
            ((99, 1000), .elevated), ((100, 1000), .normal)
        ]
        for ((free, total), expected) in cases {
            XCTAssertEqual(panel([disk("/", total: total, free: free)]).diskLevel, expected)
        }
    }
}
