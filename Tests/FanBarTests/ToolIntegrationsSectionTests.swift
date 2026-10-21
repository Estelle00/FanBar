import AppKit
import SwiftUI
import XCTest
@testable import FanBar

/// The General tab's Command Line & Automation section: present with either
/// tool, sized for what it holds, and absent from builds that ship neither.
@MainActor
final class ToolIntegrationsSectionTests: XCTestCase {
    private let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    /// A CLI installer whose app ships the tool, or one without it.
    private func makeTool(available: Bool) throws -> CommandLineToolInstaller {
        let app = root.appendingPathComponent("\(UUID().uuidString)/FanBar.app")
        if available {
            let tool = app.appendingPathComponent(CommandLineToolInstaller.toolRelativePath)
            try FileManager.default.createDirectory(at: tool.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("#!/bin/sh\n".utf8).write(to: tool)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tool.path)
        }
        return CommandLineToolInstaller(
            appURL: app,
            linkURL: root.appendingPathComponent("bin/fanbar"),
            readSearchPath: { nil }
        )
    }

    /// A Raycast installer with bundled scripts and Raycast present, or one without scripts.
    private func makeRaycast(available: Bool) throws -> RaycastScriptsInstaller {
        let source = root.appendingPathComponent("\(UUID().uuidString)/Raycast")
        if available {
            try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
            try Data("#!/bin/bash\n".utf8).write(to: source.appendingPathComponent("fanbar-auto.sh"))
        }
        return RaycastScriptsInstaller(
            sourceURL: source,
            destinationURL: root.appendingPathComponent("Support/Raycast"),
            isRaycastInstalled: { true },
            copyToPasteboard: { _ in },
            openRaycast: {}
        )
    }

    private func height(tool: Bool, raycast: Bool) throws -> CGFloat {
        let section = ToolIntegrationsSection(
            tool: try makeTool(available: tool),
            raycast: try makeRaycast(available: raycast)
        )
        let host = NSHostingView(rootView: VStack(spacing: 0) { section }.frame(width: 520))
        host.layoutSubtreeIfNeeded()
        return host.fittingSize.height
    }

    func testInstallerFixturesHaveTheIntendedStates() throws {
        XCTAssertEqual(try makeTool(available: true).state, .notInstalled)
        XCTAssertEqual(try makeTool(available: false).state, .unavailable)
        XCTAssertEqual(try makeRaycast(available: true).state, .ready)
        XCTAssertEqual(try makeRaycast(available: false).state, .unavailable)
    }

    func testSectionIsAbsentWhenTheBuildShipsNeitherTool() throws {
        XCTAssertEqual(try height(tool: false, raycast: false), 0, accuracy: 0.5)
    }

    func testSectionShowsWhicheverToolIsShipped() throws {
        let toolOnly = try height(tool: true, raycast: false)
        let raycastOnly = try height(tool: false, raycast: true)
        let both = try height(tool: true, raycast: true)
        // Header, card and footer come with even a single row.
        XCTAssertGreaterThan(toolOnly, 80)
        XCTAssertGreaterThan(raycastOnly, 80)
        // Both rows share one card: taller than either alone, but by one row,
        // not by a second header and footer.
        XCTAssertGreaterThan(both, max(toolOnly, raycastOnly))
        XCTAssertLessThan(both, toolOnly + raycastOnly)
    }
}
