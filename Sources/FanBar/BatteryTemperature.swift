// Missing sensor or collection evidence is intentionally distinct from false.
// swiftlint:disable discouraged_optional_boolean
import Foundation
import IOKit

/// AppleSmartBattery and newer AppleSmartBatteryPack expose centi-degrees Celsius.
/// Read only the temperature property, never the battery's inventory or serial.
enum BatteryTemperatureReader {
    private static var servicePort: mach_port_t {
        if #available(macOS 12.0, *) { return kIOMainPortDefault }
        return 0
    }

    static func diagnosticProbes() -> [DiagnosticProbe] {
        [("smartBattery", "AppleSmartBattery", "Temperature"),
         ("batteryPack", "AppleSmartBatteryPack", "BatteryData")].map { source, name, property in
            let matching = source == "batteryPack" ? IOServiceNameMatching(name) : IOServiceMatching(name)
            let service = IOServiceGetMatchingService(servicePort, matching)
            guard service != 0 else {
                return DiagnosticProbe(sensor: "battery", key: nil, result: "serviceMissing", source: source, stage: "serviceMatch")
            }
            defer { IOObjectRelease(service) }
            guard let propertyValue = IORegistryEntryCreateCFProperty(service,
                property as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() else {
                return DiagnosticProbe(sensor: "battery", key: nil, result: "propertyMissing", source: source, stage: "propertyRead")
            }
            let number: NSNumber?
            if source == "batteryPack" {
                number = (propertyValue as? [String: Any])?["Temperature"] as? NSNumber
            } else { number = propertyValue as? NSNumber }
            guard let raw = number?.doubleValue, raw.isFinite else {
                return DiagnosticProbe(sensor: "battery", key: nil, result: "unsupportedFormat", source: source, stage: "decode")
            }
            let value = raw / 100
            return DiagnosticProbe(sensor: "battery", key: nil, result: (10...120).contains(value) ? "available" : "outOfRange",
                value: value, source: source, stage: "fallback")
        }
    }

    static func hasBuiltInBattery() -> Bool? {
        let service = IOServiceGetMatchingService(servicePort, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard let value = IORegistryEntryCreateCFProperty(service,
            "BatteryInstalled" as CFString, kCFAllocatorDefault, 0) else { return nil }
        return (value.takeRetainedValue() as? NSNumber)?.boolValue
    }

    static func smartBattery() -> Double? {
        let service = IOServiceGetMatchingService(servicePort, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard let value = IORegistryEntryCreateCFProperty(service, "Temperature" as CFString, kCFAllocatorDefault, 0) else { return nil }
        return (value.takeRetainedValue() as? NSNumber)?.doubleValue
    }

    static func batteryPack() -> Double? {
        let service = IOServiceGetMatchingService(servicePort, IOServiceNameMatching("AppleSmartBatteryPack"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard let value = IORegistryEntryCreateCFProperty(service, "BatteryData" as CFString, kCFAllocatorDefault, 0),
              let data = value.takeRetainedValue() as? [String: Any] else { return nil }
        return (data["Temperature"] as? NSNumber)?.doubleValue
    }
}

enum BatteryTemperatureResolver {
    static func resolve(smcValues: [Double], smartBattery: () -> Double?, batteryPack: () -> Double?) -> Double? {
        if let raw = smartBattery(), let celsius = valid(raw / 100) { return celsius }
        if let raw = batteryPack(), let celsius = valid(raw / 100) { return celsius }
        let validValues = smcValues.compactMap(valid)
        guard !validValues.isEmpty else { return nil }
        return validValues.reduce(0, +) / Double(validValues.count)
    }

    private static func valid(_ value: Double) -> Double? {
        value.isFinite && (10...120).contains(value) ? value : nil
    }
}

// swiftlint:enable discouraged_optional_boolean
