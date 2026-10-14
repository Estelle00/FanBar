import FanBarShared
import Foundation

// Independent executable: never initializes SwiftUI, the updater, or fan controls.
let executable = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let appURL = executable.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let bundle = Bundle(url: appURL) ?? .main
let context = DiagnosticRuntimeContext.current(bundle: bundle)
let journal = RuntimeDiagnostics(url: RuntimeDiagnostics.defaultURL)
let helper = RuntimeDiagnostics.helperEvents()
let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601
let events = try JSONSerialization.jsonObject(with: encoder.encode(journal.snapshot() + helper.events))
let crashes = try JSONSerialization.jsonObject(with: encoder.encode(DiagnosticCrashReader.summaries()))
let runtime = try JSONSerialization.jsonObject(with: encoder.encode(context))
let system = ProcessInfo.processInfo.operatingSystemVersion
let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
let lastStatus = journal.snapshot().last { $0.component == .service && $0.action == .status }
let helperState = lastStatus?.outcome.rawValue ?? "unavailable"
let helperStateSource = lastStatus == nil ? "unavailable" : "lastRecorded"
let data: [String: Any] = [
    "schemaVersion": 1, "diagnosticID": UUID().uuidString.lowercased(),
    "capturedAt": ISO8601DateFormatter().string(from: Date()),
    "device": ["modelIdentifier": DiagnosticRuntimeContext.systemString("hw.model"),
               "processor": DiagnosticRuntimeContext.systemString("machdep.cpu.brand_string"),
               "macOSVersion": "\(system.majorVersion).\(system.minorVersion).\(system.patchVersion)",
               "appVersion": version, "helperVersion": context.appBuild],
    "helperState": helperState, "helperStateSource": helperStateSource, "probes": [], "runtimeEvents": events,
    "crashes": crashes, "crashLogAvailable": DiagnosticCrashReader.available,
        "helperLogAvailable": helper.available, "runtimeContext": runtime,
]
let output: URL
if let index = CommandLine.arguments.firstIndex(of: "--output"), CommandLine.arguments.indices.contains(index + 1) {
    output = URL(fileURLWithPath: CommandLine.arguments[index + 1])
} else {
    output = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Desktop/FanBar-diagnostics-\(Int(Date().timeIntervalSince1970)).json")
}

do {
    let bytes = try JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys])
    guard bytes.count <= 262144 else { throw NSError(domain: "FanBarDiagnostics", code: 1) }
    try bytes.write(to: output, options: .atomic)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: output.path)
    print("诊断已导出 / Diagnostics exported: \(output.path)")
    print("文件仅保存在本机，未上传。请检查后再提供给开发者。 / Saved locally; nothing uploaded. Review before sharing.")
} catch {
    fputs("无法导出诊断，请检查保存目录权限。 / Export failed. Check destination permissions.\n", stderr)
    exit(1)
}
