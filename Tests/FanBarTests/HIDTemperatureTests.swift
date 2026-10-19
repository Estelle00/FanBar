import Testing
@testable import FanBar

struct HIDTemperatureTests {
    private let m1 = [
        HIDTemperature(name: "pACC MTR Temp Sensor0", celsius: 52),
        HIDTemperature(name: "pACC MTR Temp Sensor1", celsius: 54),
        HIDTemperature(name: "eACC MTR Temp Sensor0", celsius: 44),
        HIDTemperature(name: "GPU MTR Temp Sensor1", celsius: 40),
        HIDTemperature(name: "GPU MTR Temp Sensor4", celsius: -40),
        HIDTemperature(name: "PMU tdie1", celsius: 60),
        HIDTemperature(name: "NAND CH0 temp", celsius: 35),
        HIDTemperature(name: "gas gauge battery", celsius: 30),
        HIDTemperature(name: "PMU tcal", celsius: nil),
    ]

    @Test func coreSensorsDriveCPUAndOutOfRangeValuesAreDropped() {
        #expect(HIDTemperatureSelector.cpu(m1) == [52, 54, 44])
        #expect(HIDTemperatureSelector.gpu(m1) == [40])
    }

    @Test func dieSensorsStandInOnlyWithoutCoreSensors() {
        let dieOnly = m1.filter { !$0.name.contains("ACC") }
        #expect(HIDTemperatureSelector.cpu(dieOnly) == [60])
        #expect(HIDTemperatureSelector.cpu([]) == [])
    }

    @Test func probesCarryLabelsAndCategories() {
        let probes = SMCClient.hidProbes(m1 + [HIDTemperature(name: "/Users/me", celsius: 30)])
        #expect(probes.count == m1.count)
        let byName = Dictionary(uniqueKeysWithValues: probes.map { ($0.name ?? "", $0) })
        #expect(byName["pACC MTR Temp Sensor0"]?.sensor == "cpu")
        #expect(byName["GPU MTR Temp Sensor4"]?.result == "outOfRange")
        #expect(byName["NAND CH0 temp"]?.sensor == "ssd")
        #expect(byName["gas gauge battery"]?.recognized == false)
        #expect(byName["PMU tcal"]?.result == "readFailed")
        #expect(probes.allSatisfy { $0.key == nil && $0.source == "hid" && $0.stage == "readEvent" })
    }

    @Test func missingHIDServicesAreReported() {
        let probes = SMCClient.hidProbes(nil)
        #expect(probes.map(\.result) == ["serviceMissing"])
    }

    @Test func probeCountStaysUnderServerLimit() {
        let many = (0..<100).map { HIDTemperature(name: "PMU tdev\($0)", celsius: 40) }
        // 240 SMC + 2 SSD + 2 battery fallbacks + 64 HID stays within the 320 cap.
        #expect(SMCClient.hidProbes(many).count == 64)
    }
}
