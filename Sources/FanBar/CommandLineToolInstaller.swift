import AppKit
import FanBarShared
import Foundation

/// Links `/usr/local/bin/fanbar` to the CLI inside this app, like VS Code's
/// "Install 'code' command". The link points into the bundle, so Sparkle
/// updates the tool with the app and nothing is ever copied out.
///
/// Only links FanBar made are replaced or removed: a `fanbar` that is a
/// regular file, or a link into something other than a FanBar bundle, belongs
/// to someone else and is left alone.
@MainActor
final class CommandLineToolInstaller: ObservableObject {
    enum State: Equatable {
        /// This build has no `Contents/Helpers/fanbar` (e.g. `swift run`).
        case unavailable
        /// Running from a disk image or a translocated copy; a link would dangle.
        case needsMove
        case notInstalled
        case installed
        /// Links to another FanBar copy, e.g. one that was moved or replaced.
        case linkedElsewhere
        /// The path is taken by something FanBar did not create.
        case blocked
    }

    static let shared = CommandLineToolInstaller()
    nonisolated static let linkURL = URL(fileURLWithPath: "/usr/local/bin/fanbar")
    nonisolated static let toolRelativePath = "Contents/Helpers/fanbar"

    @Published private(set) var state: State = .unavailable
    @Published private(set) var failure: String?
    @Published private(set) var isWorking = false

    private let appURL: URL
    private let linkURL: URL

    init(appURL: URL = Bundle.main.bundleURL, linkURL: URL = CommandLineToolInstaller.linkURL) {
        self.appURL = appURL
        self.linkURL = linkURL
        refresh()
    }

    private var toolURL: URL { appURL.appendingPathComponent(Self.toolRelativePath) }

    func refresh() {
        state = Self.state(toolURL: toolURL, linkURL: linkURL)
    }

    func install() {
        guard [.notInstalled, .linkedElsewhere].contains(state) else { return }
        perform(
            shell: "/bin/mkdir -p \(Self.quoted(linkURL.deletingLastPathComponent().path)) && " +
                "/bin/ln -sfn \(Self.quoted(toolURL.path)) \(Self.quoted(linkURL.path))",
            prompt: fanBarText(
                "FanBar 想在 /usr/local/bin 中安装 fanbar 命令。",
                "FanBar wants to install the fanbar command in /usr/local/bin."
            ),
            failure: { fanBarFormat("无法安装命令行工具：%@", "Could not install the command-line tool: %@", $0) },
            directly: { [linkURL, toolURL] in
                let manager = FileManager.default
                try manager.createDirectory(at: linkURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                if (try? manager.destinationOfSymbolicLink(atPath: linkURL.path)) != nil {
                    try manager.removeItem(at: linkURL)
                }
                try manager.createSymbolicLink(at: linkURL, withDestinationURL: toolURL)
            }
        )
    }

    func uninstall() {
        // Refuse anything that is not one of our links, even if the UI is stale.
        refresh()
        guard [.installed, .linkedElsewhere].contains(state) else { return }
        perform(
            shell: "/bin/rm -f \(Self.quoted(linkURL.path))",
            prompt: fanBarText(
                "FanBar 想从 /usr/local/bin 中移除 fanbar 命令。",
                "FanBar wants to remove the fanbar command from /usr/local/bin."
            ),
            failure: { fanBarFormat("无法移除命令行工具：%@", "Could not remove the command-line tool: %@", $0) },
            directly: { [linkURL] in try FileManager.default.removeItem(at: linkURL) }
        )
    }

    /// Tries without privileges first: Intel Homebrew leaves `/usr/local/bin`
    /// owned by the user. Otherwise asks once for an administrator password.
    private func perform(
        shell: String,
        prompt: String,
        failure failureMessage: @escaping (String) -> String,
        directly: @escaping () throws -> Void
    ) {
        failure = nil
        isWorking = true
        // Let the button show its working state before the password sheet blocks.
        DispatchQueue.main.async { [self] in
            defer {
                isWorking = false
                refresh()
            }
            if (try? directly()) != nil { return }
            let source = "do shell script \(Self.appleScriptString(shell)) " +
                "with prompt \(Self.appleScriptString(prompt)) with administrator privileges"
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
            guard let error else { return }
            // -128: the user cancelled the password prompt; nothing to report.
            if error[NSAppleScript.errorNumber] as? Int == -128 { return }
            let detail = error[NSAppleScript.errorMessage] as? String ?? "\(error)"
            failure = failureMessage(detail)
        }
    }

    // MARK: - Pure helpers

    nonisolated static func state(
        toolURL: URL,
        linkURL: URL,
        fileManager: FileManager = .default
    ) -> State {
        guard fileManager.isExecutableFile(atPath: toolURL.path) else { return .unavailable }
        let appPath = toolURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path
        if appPath.hasPrefix("/Volumes/") || appPath.contains("/AppTranslocation/") {
            return .needsMove
        }
        guard let destination = try? fileManager.destinationOfSymbolicLink(atPath: linkURL.path) else {
            // No link: free unless a regular file or directory sits there.
            return fileManager.fileExists(atPath: linkURL.path) ? .blocked : .notInstalled
        }
        let resolved = URL(fileURLWithPath: destination, relativeTo: linkURL.deletingLastPathComponent())
            .standardizedFileURL.path
        if resolved == toolURL.standardizedFileURL.path { return .installed }
        return resolved.hasSuffix(".app/\(toolRelativePath)") ? .linkedElsewhere : .blocked
    }

    nonisolated static func quoted(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    nonisolated static func appleScriptString(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
