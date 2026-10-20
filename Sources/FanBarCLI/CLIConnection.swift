import AppKit
import Darwin
import FanBarShared
import Foundation

enum CLIConnectionError: Error, Equatable {
    case notRunning
    case appNotFound
    case launchFailed
    /// The app runs but nothing answers: an older FanBar without CLI support.
    case notAccepting
    case transport

    var message: String {
        switch self {
        case .notRunning: "FanBar is not running. Start it, or run without --no-launch."
        case .appNotFound: "Could not find FanBar.app. Install it in /Applications and try again."
        case .launchFailed: "Could not start FanBar.app."
        case .notAccepting: "FanBar is running but does not accept fanbar commands. Update FanBar and try again."
        case .transport: "Lost the connection to FanBar."
        }
    }
}

/// Finds or starts FanBar.app, then exchanges one request with it.
enum CLIConnection {
    /// Long enough for the slowest fan write the app may wait on.
    private static let replyTimeoutSeconds = 150
    /// A cold start includes the helper status check and first sensor read.
    private static let launchConnectTimeout: TimeInterval = 20
    private static let runningConnectTimeout: TimeInterval = 2

    static func send(_ request: FanBarCLIRequest, noLaunch: Bool) -> Result<FanBarCLIResponse, CLIConnectionError> {
        let path = FanBarCLIContract.socketURL().path
        var timeout = runningConnectTimeout
        if !isAppRunning {
            if noLaunch { return .failure(.notRunning) }
            guard let app = locateApp() else { return .failure(.appNotFound) }
            guard launch(app) else { return .failure(.launchFailed) }
            timeout = launchConnectTimeout
        }
        guard let descriptor = connect(path, timeout: timeout) else { return .failure(.notAccepting) }
        defer { close(descriptor) }
        guard let body = try? FanBarCLIContract.makeEncoder().encode(request),
              FanBarCLISocket.writeMessage(body, to: descriptor),
              let reply = FanBarCLISocket.readMessage(from: descriptor),
              let response = try? FanBarCLIContract.makeDecoder().decode(FanBarCLIResponse.self, from: reply) else {
            return .failure(.transport)
        }
        return .success(response)
    }

    private static var isAppRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: FanBarService.appBundleID).isEmpty
    }

    /// Prefers the app this tool ships inside (`FanBar.app/Contents/Helpers/fanbar`,
    /// reached through a Homebrew symlink or not), then whatever Launch Services knows.
    static func locateApp() -> URL? {
        if let enclosing = enclosingApp(of: executableURL()) { return enclosing }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: FanBarService.appBundleID)
    }

    static func enclosingApp(of executable: URL?) -> URL? {
        guard let executable else { return nil }
        let app = executable.resolvingSymlinksInPath()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        // Read the plist directly: `Bundle(url:)` caches whatever it first saw at a path.
        let info = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist"))
        guard app.pathExtension == "app",
              info?["CFBundleIdentifier"] as? String == FanBarService.appBundleID else { return nil }
        return app
    }

    private static func executableURL() -> URL? {
        var size: UInt32 = 0
        _ = _NSGetExecutablePath(nil, &size)
        var buffer = [CChar](repeating: 0, count: Int(size))
        guard _NSGetExecutablePath(&buffer, &size) == 0 else { return nil }
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        guard let path = String(bytes: bytes, encoding: .utf8) else { return nil }
        return URL(fileURLWithPath: path)
    }

    /// `open -g` starts the app without stealing focus from the terminal.
    private static func launch(_ app: URL) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-g", app.path]
        do {
            try process.run()
        } catch {
            return false
        }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    /// Retries until the app's listener is up or the timeout passes.
    private static func connect(_ path: String, timeout: TimeInterval) -> Int32? {
        guard var address = FanBarCLISocket.address(for: path) else { return nil }
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
            guard descriptor >= 0 else { return nil }
            let connected = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) == 0
                }
            }
            if connected {
                var enabled: Int32 = 1
                setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &enabled, socklen_t(MemoryLayout<Int32>.size))
                var wait = timeval(tv_sec: replyTimeoutSeconds, tv_usec: 0)
                setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &wait, socklen_t(MemoryLayout<timeval>.size))
                return descriptor
            }
            close(descriptor)
            usleep(200_000)
        } while Date() < deadline
        return nil
    }

    static var appVersion: String {
        locateApp().flatMap { Bundle(url: $0)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String }
            ?? "unknown"
    }
}
