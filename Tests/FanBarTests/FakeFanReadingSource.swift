import Foundation
@testable import FanBar

/// Fixed fan and temperature readings, so FanController and the menu can run
/// on CI runners (VMs) that expose no SMC fans.
final class FakeFanReadingSource: FanReadingSource {
    var readings: [FanReading]
    var cpuCelsius: Double?
    var error: Error?

    init(
        readings: [FanReading] = [
            FanReading(index: 0, minimumRPM: 1_200, currentRPM: 1_850, maximumRPM: 6_000, isManual: false),
            FanReading(index: 1, minimumRPM: 1_300, currentRPM: 1_900, maximumRPM: 6_500, isManual: false),
        ],
        cpuCelsius: Double? = 52
    ) {
        self.readings = readings
        self.cpuCelsius = cpuCelsius
    }

    func fans() throws -> [FanReading] {
        if let error { throw error }
        return readings
    }

    func thermalReading(at date: Date) -> ThermalReading {
        ThermalReading(sampledAt: date, cpuCelsius: cpuCelsius, gpuCelsius: cpuCelsius.map { $0 - 4 })
    }
}
