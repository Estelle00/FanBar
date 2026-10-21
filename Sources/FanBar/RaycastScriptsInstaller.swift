import AppKit
import Darwin
import FanBarShared
import Foundation

/// Hands the bundled Raycast Script Commands to Raycast with as few steps as
/// Raycast allows. Raycast has no way for another app to add a script
/// directory, so FanBar copies the scripts to a stable folder, puts that path
/// on the clipboard and opens Raycast; the user adds the folder once.
///
/// The folder lives outside the bundle so it survives app updates, and is
/// refreshed from the bundle at every launch once set up, so scripts update
/// with the app.
@MainActor
final class RaycastScriptsInstaller: ObservableObject {
    enum State: Equatable {
        /// This build has no bundled scripts (e.g. `swift run`).
        case unavailable
        case raycastMissing
        case ready
        /// Scripts were copied; Raycast still needs the folder once.
        case copied
    }

    static let shared = RaycastScriptsInstaller()
    nonisolated static let raycastBundleID = "com.raycast.macos"
    nonisolated static let downloadURL = URL(string: "https://www.raycast.com")!

    @Published private(set) var state: State = .unavailable
    @Published private(set) var failure: String?

    let destinationURL: URL
    private let sourceURL: URL?
    private let isRaycastInstalled: () -> Bool
    private let copyToPasteboard: (String) -> Void
    private let openRaycast: () -> Void

    init(
        sourceURL: URL? = Bundle.main.resourceURL?.appendingPathComponent("Raycast", isDirectory: true),
        destinationURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/FanBar/Raycast", isDirectory: true),
        isRaycastInstalled: @escaping () -> Bool = {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: RaycastScriptsInstaller.raycastBundleID) != nil
        },
        copyToPasteboard: @escaping (String) -> Void = { text in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        },
        openRaycast: @escaping () -> Void = {
            guard let url = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: RaycastScriptsInstaller.raycastBundleID
            ) else { return }
            NSWorkspace.shared.open(url)
        }
    ) {
        self.sourceURL = sourceURL
        self.destinationURL = destinationURL
        self.isRaycastInstalled = isRaycastInstalled
        self.copyToPasteboard = copyToPasteboard
        self.openRaycast = openRaycast
        refresh()
    }

    private var bundledScripts: [URL] {
        guard let sourceURL else { return [] }
        return ((try? FileManager.default.contentsOfDirectory(at: sourceURL, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "sh" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func refresh() {
        if bundledScripts.isEmpty {
            state = .unavailable
        } else if !isRaycastInstalled() {
            state = .raycastMissing
        } else {
            state = FileManager.default.fileExists(atPath: destinationURL.path) ? .copied : .ready
        }
    }

    /// Copies the scripts, puts the folder path on the clipboard, opens Raycast.
    func setUp() {
        failure = nil
        do {
            try copyScripts()
        } catch {
            failure = fanBarFormat(
                "无法准备 Raycast 脚本：%@",
                "Could not prepare the Raycast scripts: %@",
                error.localizedDescription
            )
            refresh()
            return
        }
        copyToPasteboard(destinationURL.path)
        openRaycast()
        refresh()
    }

    /// At launch: once the user has set up Raycast, keep the copy in step with
    /// this app version. Does nothing before the first setup.
    func syncIfSetUp() {
        guard FileManager.default.fileExists(atPath: destinationURL.path), !bundledScripts.isEmpty else { return }
        try? copyScripts()
    }

    func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([destinationURL])
    }

    private func copyScripts() throws {
        let manager = FileManager.default
        try manager.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        let bundled = bundledScripts
        // Scripts dropped from a newer build must not linger as dead commands.
        let bundledNames = Set(bundled.map(\.lastPathComponent))
        for existing in (try? manager.contentsOfDirectory(at: destinationURL, includingPropertiesForKeys: nil)) ?? []
            where existing.pathExtension == "sh" && existing.lastPathComponent.hasPrefix("fanbar-")
            && !bundledNames.contains(existing.lastPathComponent) {
            try manager.removeItem(at: existing)
        }
        for script in bundled {
            let target = destinationURL.appendingPathComponent(script.lastPathComponent)
            if manager.fileExists(atPath: target.path) {
                try manager.removeItem(at: target)
            }
            try manager.copyItem(at: script, to: target)
            try manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: target.path)
            // A downloaded app's files can carry quarantine; Raycast runs these directly.
            removexattr(target.path, "com.apple.quarantine", 0)
        }
    }
}
