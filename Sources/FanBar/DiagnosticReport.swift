// Missing sensor or collection evidence is intentionally distinct from false.
// swiftlint:disable discouraged_optional_boolean
import FanBarShared
import Foundation

/// Only allowlisted sensor metadata; no arbitrary system log messages or device identifiers.
struct DiagnosticProbe: Codable, Equatable {
    let sensor: String
    let key: String?
    let result: String
    var value: Double?
    var code: Int32?
    var source: String?
    var stage: String?
    var dataType: String?
    var dataSize: Int?
    var rawBytes: String?
    var recognized: Bool?
}

struct DiagnosticReport: Encodable {
    let schemaVersion = 1
    let diagnosticID: String
    let capturedAt: String
    let device: CompatibilityDevice
    let helperState: String
    var thermal: ThermalReading?
    var fanCount: Int?
    var connectionErrorCode: Int32?
    var probes: [DiagnosticProbe]
    var recentSamples: [DiagnosticSample]?
    var discovery: DiagnosticDiscovery?
    var runtimeEvents: [RuntimeDiagnosticEvent]?
    var crashes: [DiagnosticCrashSummary]?
    var helperLogAvailable: Bool?
    var runtimeContext: DiagnosticRuntimeContext?
    var crashLogAvailable: Bool?
    var helperStateSource: String?

    func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}

struct DiagnosticSample: Codable {
    let sampledAt: Date
    let thermal: ThermalReading?
    let fanCount: Int?
    let errorCode: Int32?
    let stage: String
}

struct DiagnosticDiscovery: Codable {
    var reportedKeyCount: Int?
    var temperatureKeys: [String] = []
    var scannedKeyCount = 0
    var truncated = false
    var errorCode: Int32?
}

// swiftlint:enable discouraged_optional_boolean
