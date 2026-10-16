// Missing sensor or collection evidence is intentionally distinct from false.
// swiftlint:disable discouraged_optional_boolean
import Darwin
import Foundation

/// A deliberately narrow inventory. Never query serials, UUIDs, users or host names.
struct CompatibilityDevice: Codable, Equatable {
    let modelIdentifier: String
    let processor: String
    let macOSVersion: String
    let appVersion: String
    let helperVersion: String

    static func current(helperVersion: String) -> Self {
        let system = ProcessInfo.processInfo.operatingSystemVersion
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
        return Self(
            modelIdentifier: systemString("hw.model") ?? "unknown",
            processor: systemString("machdep.cpu.brand_string") ?? architecture,
            macOSVersion: "\(system.majorVersion).\(system.minorVersion).\(system.patchVersion)",
            appVersion: version,
            helperVersion: helperVersion
        )
    }

    var displayName: String {
        Self.modelNames[modelIdentifier] ?? modelIdentifier
    }

    private static let modelNames: [String: String] = {
        guard let url = Bundle.module.url(forResource: "mac-model-names", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let names = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return names
    }()

    private static var architecture: String {
        #if arch(arm64)
        "Apple Silicon"
        #else
        "Intel"
        #endif
    }

    private static func systemString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0, size < 1024 else { return nil }
        var bytes = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &bytes, &size, nil, 0) == 0 else { return nil }
        let contents = bytes.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(bytes: contents, encoding: .utf8)
    }
}

enum CompatibilityStatus: String, Codable {
    case available
    case notApplicable
    case notDetected
    case temporarilyUnavailable
    case requiresAuthorization
    case unverified
    case requestSucceeded
    case requestFailed

    /// A hands-on confirmation may accompany an untested control (used on an earlier
    /// version, for example), but never a result showing control could not run here.
    /// The compatibility service rejects any other combination.
    var acceptsHandsOnConfirmation: Bool {
        self == .requestSucceeded || self == .unverified
    }
}

enum CompatibilityCapability: String, CaseIterable, Codable, Identifiable {
    case cpuTemperature
    case gpuTemperature
    case ssdTemperature
    case batteryTemperature
    case fanReadings
    case manualControl
    case smartCooling

    var id: String { rawValue }
}

struct CompatibilityResult: Codable, Equatable, Identifiable {
    let capability: CompatibilityCapability
    let status: CompatibilityStatus
    let reasonCode: String
    var userConfirmedWorking: Bool?
    var id: CompatibilityCapability { capability }
}

/// One fresh sample; missing values never inherit earlier successful readings.
struct CompatibilityObservation: Equatable {
    let sampledAt: Date
    let thermal: ThermalReading?
    let fanCount: Int?
    let connectionFailed: Bool
}

/// A successful helper reply is evidence of a request, not proof of physical RPM.
enum CompatibilityControlEvidence: String, Codable {
    case unverified
    case requestSucceeded
    case requestFailed
}

struct CompatibilitySnapshot: Equatable {
    let device: CompatibilityDevice
    let checkedAt: Date
    let fanCount: Int?
    let curveSensor: FanCurveSensor
    let results: [CompatibilityResult]

    // Bounded orchestration is covered by failure, cancellation, and restoration tests.
    // swiftlint:disable:next function_body_length
    static func make(
        device: CompatibilityDevice,
        observation: CompatibilityObservation,
        helperState: FanController.HelperState,
        manualEvidence: CompatibilityControlEvidence,
        curveEvidence: CompatibilityControlEvidence,
        curveSensor: FanCurveSensor = .maxChip
    ) -> Self {
        let thermal = observation.thermal
        let readings: [(CompatibilityCapability, Double?)] = [
            (.cpuTemperature, thermal?.cpuCelsius),
            (.gpuTemperature, thermal?.gpuCelsius),
            (.ssdTemperature, thermal?.ssdCelsius),
            (.batteryTemperature, thermal?.batteryCelsius),
        ]
        var results = readings.map { capability, value in
            if capability == .batteryTemperature, thermal?.hasBuiltInBattery == false {
                return CompatibilityResult(capability: capability, status: .notApplicable, reasonCode: "NO_BUILT_IN_BATTERY")
            }
            return CompatibilityResult(
                capability: capability,
                status: value.map { $0.isFinite && (10...120).contains($0) } == true
                    ? .available : observation.connectionFailed ? .temporarilyUnavailable : .notDetected,
                reasonCode: value.map { $0.isFinite && (10...120).contains($0) } == true
                    ? "SENSOR_READ_SUCCEEDED" : observation.connectionFailed ? "SMC_CONNECTION_FAILED" : "SENSOR_NOT_DETECTED"
            )
        }
        results.append(CompatibilityResult(
            capability: .fanReadings,
            status: observation.fanCount.map { $0 > 0 ? .available : .notDetected } ?? .temporarilyUnavailable,
            reasonCode: observation.fanCount.map { $0 > 0 ? "FAN_READ_SUCCEEDED" : "NO_FANS_REPORTED" }
                ?? (observation.connectionFailed ? "SMC_CONNECTION_FAILED" : "FAN_READ_FAILED")
        ))
        for (capability, evidence) in [
            (CompatibilityCapability.manualControl, manualEvidence),
            (.smartCooling, curveEvidence),
        ] {
            let status: CompatibilityStatus
            let reason: String
            if helperState == .unavailable {
                status = .temporarilyUnavailable
                reason = "HELPER_MISSING"
            } else if helperState != .enabled {
                status = .requiresAuthorization
                reason = "HELPER_AUTHORIZATION_REQUIRED"
            } else if observation.fanCount == nil || observation.fanCount == 0 {
                status = .unverified
                reason = "NO_CURRENT_FAN_EVIDENCE"
            } else if capability == .smartCooling,
                      !hasCurveTemperature(curveSensor, results: results) {
                status = .unverified
                reason = "NO_CURVE_SENSOR_EVIDENCE"
            } else {
                switch evidence {
                case .unverified:
                    status = .unverified
                    reason = "CONTROL_NOT_ATTEMPTED"
                case .requestSucceeded:
                    status = .requestSucceeded
                    reason = "CONTROL_REQUEST_SUCCEEDED"
                case .requestFailed:
                    status = .requestFailed
                    reason = "CONTROL_REQUEST_FAILED"
                }
            }
            results.append(CompatibilityResult(capability: capability, status: status, reasonCode: reason))
        }
        return Self(
            device: device, checkedAt: observation.sampledAt, fanCount: observation.fanCount,
            curveSensor: curveSensor, results: results
        )
    }

    private static func hasCurveTemperature(_ sensor: FanCurveSensor, results: [CompatibilityResult]) -> Bool {
        let required: [CompatibilityCapability]
        switch sensor {
        case .maxChip: required = [.cpuTemperature, .gpuTemperature]
        case .cpu: required = [.cpuTemperature]
        case .gpu: required = [.gpuTemperature]
        case .ssd: required = [.ssdTemperature]
        }
        return results.contains { required.contains($0.capability) && $0.status == .available }
    }
}

/// Closed schema: export cannot accidentally include arbitrary logs or hardware identifiers.
struct CompatibilityReport: Codable {
    let schemaVersion: Int
    let reportID: UUID
    let device: CompatibilityDevice
    let fanCount: Int?
    var capabilities: [CompatibilityResult]
    let selectedTemperatureSource: FanCurveSensor

    init(snapshot: CompatibilitySnapshot) {
        schemaVersion = 1
        reportID = UUID()
        device = snapshot.device
        fanCount = snapshot.fanCount
        capabilities = snapshot.results
        selectedTemperatureSource = snapshot.curveSensor
    }

    func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}

struct CompatibilityRecord: Codable, Equatable {
    let device: CompatibilityDevice
    let verifiedOn: String
    let source: String
    let notes: String
}

struct CompatibilityCatalog: Codable {
    let schemaVersion: Int
    let records: [CompatibilityRecord]

    static func load() -> Self {
        guard let url = Bundle.module.url(forResource: "compatibility", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(Self.self, from: data),
              catalog.schemaVersion == 1 else {
            return Self(schemaVersion: 1, records: [])
        }
        return catalog
    }

    /// Exact model/OS/app/helper versions prevent a nearby record implying support.
    func matching(_ device: CompatibilityDevice) -> [CompatibilityRecord] {
        records.filter {
            $0.device.modelIdentifier == device.modelIdentifier
                && $0.device.macOSVersion == device.macOSVersion
                && $0.device.appVersion == device.appVersion
                && $0.device.helperVersion == device.helperVersion
        }
    }
}

// swiftlint:enable discouraged_optional_boolean
