import AppKit
import XCTest
@testable import FanBar

final class ThermalAlertSoundTests: XCTestCase {
    func testStoredValueRoundTrips() {
        for sound in [ThermalAlertSound.silent, .system("Glass"), .system("Sosumi")] {
            XCTAssertEqual(ThermalAlertSound(storedValue: sound.storedValue), sound)
        }
        XCTAssertNil(ThermalAlertSound.notificationDefault.storedValue)
    }

    func testUnsetOrUnknownValueKeepsNotificationDefault() {
        XCTAssertEqual(ThermalAlertSound(storedValue: nil), .notificationDefault)
        XCTAssertEqual(ThermalAlertSound(storedValue: "NotARealSound"), .notificationDefault)
    }

    func testDefaultSoundRidesOnTheNotification() {
        var played: [String] = []
        let sound = ThermalAlertSound.notificationDefault.deliver { played.append($0); return true }
        XCTAssertEqual(sound, .default)
        XCTAssertTrue(played.isEmpty)
        XCTAssertNil(ThermalAlertSound.notificationDefault.systemSoundName)
    }

    func testSilentPlaysNothing() {
        var played: [String] = []
        XCTAssertNil(ThermalAlertSound.silent.deliver { played.append($0); return true })
        XCTAssertTrue(played.isEmpty)
        XCTAssertNil(ThermalAlertSound.silent.systemSoundName)
    }

    /// FanBar plays a system sound itself, so the notification stays silent
    /// instead of sounding twice.
    func testSystemSoundIsPlayedDirectly() {
        var played: [String] = []
        XCTAssertNil(ThermalAlertSound.system("Ping").deliver { played.append($0); return true })
        XCTAssertEqual(played, ["Ping"])
        XCTAssertEqual(ThermalAlertSound.system("Ping").systemSoundName, "Ping")
    }

    /// A sound file a future macOS drops must not leave the alert silent.
    func testUnplayableSystemSoundFallsBackToNotificationSound() {
        XCTAssertEqual(ThermalAlertSound.system("Ping").deliver { _ in false }, .default)
    }

    func testSettingReadsStoredValue() {
        let key = ThermalAlertSettings.soundKey
        let saved = UserDefaults.standard.object(forKey: key)
        defer {
            if let saved {
                UserDefaults.standard.set(saved, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        UserDefaults.standard.removeObject(forKey: key)
        XCTAssertEqual(ThermalAlertSettings.sound, .notificationDefault)
        UserDefaults.standard.set("none", forKey: key)
        XCTAssertEqual(ThermalAlertSettings.sound, .silent)
        UserDefaults.standard.set("Glass", forKey: key)
        XCTAssertEqual(ThermalAlertSettings.sound, .system("Glass"))
        // A non-string value written by something else is ignored.
        UserDefaults.standard.set(42, forKey: key)
        XCTAssertEqual(ThermalAlertSettings.sound, .notificationDefault)
    }

    func testListedSystemSoundsExist() {
        for name in ThermalAlertSound.systemSoundNames {
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: "/System/Library/Sounds/\(name).aiff"),
                name
            )
            // The player loads sounds by name, not by path.
            XCTAssertNotNil(NSSound(named: NSSound.Name(name)), name)
        }
    }

    func testGateSoundsOncePerCooldownWindow() {
        var gate = ThermalAlertSoundGate(cooldown: 120)
        let start = Date(timeIntervalSinceReferenceDate: 0)
        XCTAssertTrue(gate.allowsSound(at: start))
        XCTAssertFalse(gate.allowsSound(at: start.addingTimeInterval(4)))
        XCTAssertFalse(gate.allowsSound(at: start.addingTimeInterval(119)))
        XCTAssertTrue(gate.allowsSound(at: start.addingTimeInterval(120)))
        // A muted alert does not extend the window.
        XCTAssertFalse(gate.allowsSound(at: start.addingTimeInterval(200)))
        XCTAssertTrue(gate.allowsSound(at: start.addingTimeInterval(240)))
    }

    func testClockSetBackwardsDoesNotMuteAlerts() {
        var gate = ThermalAlertSoundGate(cooldown: 120)
        let start = Date(timeIntervalSinceReferenceDate: 10_000)
        XCTAssertTrue(gate.allowsSound(at: start))
        // Without the guard the next sound would wait until the clock
        // passed `start` again, an hour later.
        XCTAssertTrue(gate.allowsSound(at: start.addingTimeInterval(-3600)))
        XCTAssertFalse(gate.allowsSound(at: start.addingTimeInterval(-3590)))
    }

    func testResetEndsTheCooldown() {
        var gate = ThermalAlertSoundGate(cooldown: 120)
        let start = Date(timeIntervalSinceReferenceDate: 0)
        XCTAssertTrue(gate.allowsSound(at: start))
        gate.reset()
        XCTAssertNil(gate.lastSoundDate)
        XCTAssertTrue(gate.allowsSound(at: start.addingTimeInterval(1)))
    }

    /// A temperature hovering at the threshold starts a new episode on every
    /// crossing; only the first crossing in the window should sound.
    func testHoveringTemperatureSoundsOnce() {
        var monitor = ThermalAlertMonitor(thresholdCelsius: 90)
        var gate = ThermalAlertSoundGate(cooldown: 120)
        let start = Date(timeIntervalSinceReferenceDate: 0)
        var sounds = 0
        for step in 0..<20 {
            let celsius = step.isMultiple(of: 2) ? 90.5 : 89.5
            let reading = ThermalReading(sampledAt: start, cpuCelsius: celsius, gpuCelsius: nil)
            let alerts = monitor.alerts(for: reading)
            if !alerts.isEmpty, gate.allowsSound(at: start.addingTimeInterval(Double(step) * 2)) {
                sounds += 1
            }
        }
        XCTAssertEqual(sounds, 1)
    }
}
