import AppleSMC
import Foundation

/// One Apple-vendor HID temperature sensor. `celsius` is nil when the service
/// did not answer; out-of-range values are kept so diagnostics can show them.
struct HIDTemperature: Equatable, Sendable {
    let name: String
    let celsius: Double?
}

enum HIDTemperatureReader {
    /// Apple Silicon exposes a few dozen of these; Intel builds return nil.
    static func all() -> [HIDTemperature]? {
        var sensors = [FanBarHIDTemperature](repeating: FanBarHIDTemperature(), count: 128)
        let count = Int(fanbar_hid_temperatures(nil, &sensors, Int32(sensors.count)))
        guard count >= 0 else { return nil }
        return sensors.prefix(count).map { sensor in
            var sensor = sensor
            let name = withUnsafeBytes(of: &sensor.name) { String(bytes: $0.prefix { $0 != 0 }, encoding: .utf8) } ?? ""
            return HIDTemperature(name: name, celsius: sensor.has_value != 0 && sensor.celsius.isFinite ? sensor.celsius : nil)
        }
    }
}

/// Sensor names follow the MIT-licensed exelban/Stats HID catalogue.
/// SMC keys stay the primary source; these fill in when SMC finds nothing,
/// as on an M1 MacBook Pro running macOS 27.
enum HIDTemperatureSelector {
    static let cpuCorePrefixes = ["pACC MTR Temp Sensor", "eACC MTR Temp Sensor"]
    /// Power-manager die sensors sit on the SoC itself. Stats files them under
    /// general sensors, so they stand in for the CPU only without core sensors
    /// (an M2 Max exposes PMU tdie/tdev but no MTR core sensors at all).
    static let cpuDiePrefix = "PMU tdie"
    static let gpuPrefix = "GPU MTR Temp Sensor"

    static func cpu(_ sensors: [HIDTemperature]) -> [Double] {
        let cores = values(sensors, prefixes: cpuCorePrefixes)
        return cores.isEmpty ? values(sensors, prefixes: [cpuDiePrefix]) : cores
    }

    static func gpu(_ sensors: [HIDTemperature]) -> [Double] {
        values(sensors, prefixes: [gpuPrefix])
    }

    /// Diagnostic category, matching the server's sensor enum.
    static func category(of name: String) -> String {
        if (cpuCorePrefixes + [cpuDiePrefix]).contains(where: name.hasPrefix) { return "cpu" }
        if name.hasPrefix(gpuPrefix) { return "gpu" }
        if name.hasPrefix("NAND CH") { return "ssd" }
        if name.hasPrefix("gas gauge battery") { return "battery" }
        return "unclassified"
    }

    /// Whether the app's own selection can use this sensor.
    static func isRecognized(_ name: String) -> Bool {
        (cpuCorePrefixes + [cpuDiePrefix, gpuPrefix, "NAND CH"]).contains(where: name.hasPrefix)
    }

    /// Product names are fixed hardware labels; anything else is never uploaded.
    static func isUploadableName(_ name: String) -> Bool {
        (1...48).contains(name.count) && name.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == " ") }
    }

    private static func values(_ sensors: [HIDTemperature], prefixes: [String]) -> [Double] {
        sensors.filter { sensor in prefixes.contains(where: sensor.name.hasPrefix) }
            .compactMap(\.celsius)
            .filter { (10...120).contains($0) }
    }
}
