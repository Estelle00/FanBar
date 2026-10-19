import Testing
@testable import FanBar

struct CPUSensorSelectionTests {
    @Test(arguments: ["Apple M4", "Apple M4 Pro", "Apple M4 Max"])
    func m4ExcludesOtherGenerationMeasurements(processor: String) {
        let keys = Set(SMCClient.cpuTemperatureCandidates(for: processor))
        #expect(keys == Set([
            "Te05", "Te0S", "Te09", "Te0H",
            "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0V", "Tp0Y", "Tp0b", "Tp0e"
        ]))
        // Readable older/newer-generation keys must not inflate the maximum.
        let readings = ["Te05": 70.0, "Tp01": 89.0, "Tp00": 94.0, "Tf04": 96.0, "TC0P": 92.0]
        let selected = readings.filter { keys.contains($0.key) }.map(\.value)
        #expect(selected.max() == 89)
        #expect(selected.reduce(0, +) / Double(selected.count) == 79.5)
    }

    @Test(arguments: ["Apple M1", "Apple M3", "Apple M5", "Intel Core i7", "unknown", "Apple M40"])
    func otherProcessorsKeepExistingFallback(processor: String) {
        let keys = SMCClient.cpuTemperatureCandidates(for: processor)
        #expect(keys.contains("TC0D"))
        #expect(keys.contains("Tf04"))
        #expect(keys.contains("Tp00"))
    }

    @Test func intelProbesPerCoreKeysFirst() {
        let keys = SMCClient.cpuTemperatureCandidates(for: "Intel(R) Core(TM) i5-8257U CPU @ 1.40GHz")
        #expect(Array(keys.prefix(5)) == ["TC0C", "TC1C", "TC2C", "TC3C", "TC4C"])
        #expect(keys.contains("TC0P"))
        #expect(!SMCClient.cpuTemperatureCandidates(for: "Apple M1").contains("TC1C"))
    }

    @Test func perCoreKeysReplacePackageAndProximityKeys() {
        // MacBookPro16,3 diagnostic: TC0P (42.3 °C) pulled the average below every core.
        let readable = ["TC1C", "TC2C", "TC3C", "TC4C", "TC0E", "TC0F", "TC0P"]
        #expect(SMCClient.preferredCPUKeys(readable) == ["TC1C", "TC2C", "TC3C", "TC4C"])
    }

    @Test func keysWithoutPerCoreSensorsAreKept() {
        #expect(SMCClient.preferredCPUKeys(["TC0D", "TC0P"]) == ["TC0D", "TC0P"])
        #expect(SMCClient.preferredCPUKeys(["Tp01", "Tp05"]) == ["Tp01", "Tp05"])
    }
}
