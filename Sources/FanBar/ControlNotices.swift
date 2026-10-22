import FanBarShared
import Foundation
import UserNotifications

/// A manual mode FanBar can turn back on after handing the fans to macOS.
enum ResumableMode: Equatable {
    case preset(CoolingPresetID)
    case fixed(Int)
}

/// Why FanBar returned the fans to macOS without the user asking.
enum HandBackReason: Equatable {
    case timer
    case missingTemperature(FanCurveSensor)
}

/// Something FanBar did, or is about to do, on its own. The panel shows it
/// under the mode strip; with the panel closed it becomes a notification.
enum ControlNotice: Equatable {
    /// The last minute of a timed manual session.
    case handBackSoon(mode: ResumableMode, duration: FanController.AutomaticRestoreDuration, deadline: Date)
    /// Control went back to macOS. `duration` is the session's, reused by "Turn on again".
    case handedBack(
        mode: ResumableMode,
        reason: HandBackReason,
        duration: FanController.AutomaticRestoreDuration,
        at: Date
    )

    /// A hand-back note stops being news after an hour.
    static let handedBackLifetime: TimeInterval = 3_600

    func isExpired(at date: Date) -> Bool {
        switch self {
        case .handBackSoon(_, _, let deadline):
            return date >= deadline
        case .handedBack(_, _, _, let at):
            return date.timeIntervalSince(at) >= Self.handedBackLifetime
        }
    }
}

/// When the one-minute warning before a timed hand-back goes out.
enum HandBackWarning {
    static let lead: TimeInterval = 60
    /// Closer to the deadline than this, the warning and the hand-back would
    /// arrive together, so only the hand-back is announced.
    static let minimumNotice: TimeInterval = 10

    /// Seconds from now until the warning, or nil when there is no time for one.
    static func delay(untilDeadline remaining: TimeInterval) -> TimeInterval? {
        guard remaining >= minimumNotice else { return nil }
        return max(0, remaining - lead)
    }
}

/// The name of the mode being handed back, as the user picked it.
@MainActor
enum ControlNoticeText {
    static func modeName(_ mode: ResumableMode, controller: FanController) -> String {
        switch mode {
        case .preset(let id): controller.presetTitle(for: id)
        case .fixed: fanBarText("固定转速", "Fixed speed")
        }
    }

    /// Shown under the mode strip; `countdown` is the remaining "m:ss".
    static func panelMessage(_ notice: ControlNotice, controller: FanController, countdown: String) -> String {
        switch notice {
        case .handBackSoon(let mode, _, _):
            return fanBarFormat(
                "%@将在 %@ 后交回 macOS",
                "%@ hands back to macOS in %@",
                modeName(mode, controller: controller),
                countdown
            )
        case .handedBack(let mode, .timer, let duration, _):
            return fanBarFormat(
                "%@到了，%@已交回 macOS",
                "After %@, %@ handed back to macOS",
                duration.title,
                modeName(mode, controller: controller)
            )
        case .handedBack(let mode, .missingTemperature(let sensor), _, _):
            return fanBarFormat(
                "读不到 %@ 温度，%@已交回 macOS",
                "Couldn't read the %@ temperature; %@ handed back to macOS",
                sensor.shortName,
                modeName(mode, controller: controller)
            )
        }
    }

    static func notificationContent(
        for notice: ControlNotice,
        controller: FanController
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.threadIdentifier = HandBackNotification.threadIdentifier
        switch notice {
        case .handBackSoon(let mode, let duration, _):
            content.title = fanBarFormat(
                "%@将在 1 分钟后交回 macOS",
                "%@ hands back to macOS in 1 minute",
                modeName(mode, controller: controller)
            )
            content.body = fanBarFormat("%@定时快到了。", "The timer you set for %@ is almost up.", duration.title)
            content.categoryIdentifier = HandBackNotification.soonCategory
        case .handedBack(let mode, .timer, let duration, _):
            content.title = fanBarFormat(
                "%@已交回 macOS",
                "%@ handed back to macOS",
                modeName(mode, controller: controller)
            )
            content.body = fanBarFormat(
                "%@定时结束，风扇现在由 macOS 调节。",
                "The timer you set for %@ ended; macOS now controls the fans.",
                duration.title
            )
            content.categoryIdentifier = HandBackNotification.endedCategory
        case .handedBack(let mode, .missingTemperature(let sensor), _, _):
            content.title = fanBarFormat(
                "读不到 %@ 温度，%@已交回 macOS",
                "Couldn't read the %@ temperature; %@ handed back to macOS",
                sensor.shortName,
                modeName(mode, controller: controller)
            )
            content.body = fanBarText(
                "为了安全，风扇已交回 macOS 调节。",
                "For safety, macOS now controls the fans."
            )
            content.categoryIdentifier = HandBackNotification.missingTemperatureCategory
        }
        return content
    }
}

/// Identifiers for hand-back notifications and their buttons.
enum HandBackNotification {
    static let threadIdentifier = "fanbar.hand-back"
    /// One delivered request per stage, so a re-sent warning replaces the old one.
    static let soonIdentifier = "fanbar.hand-back.soon"
    static let endedIdentifier = "fanbar.hand-back.ended"

    static let soonCategory = "fanbar.hand-back.soon"
    static let endedCategory = "fanbar.hand-back.ended"
    static let missingTemperatureCategory = "fanbar.hand-back.missing-temperature"

    static let keepSameAction = "fanbar.hand-back.keep-same"
    static let keepOnAction = "fanbar.hand-back.keep-on"
    static let turnOnAgainAction = "fanbar.hand-back.turn-on-again"

    static let remindersEnabledKey = "fanbar.handBackRemindersEnabled"

    /// Off only when the user turned it off; new installs remind.
    static var remindersEnabled: Bool {
        UserDefaults.standard.object(forKey: remindersEnabledKey) as? Bool ?? true
    }

    /// Button titles follow the language at registration; FanBar registers
    /// again whenever it builds a notification, so a language change is picked up.
    static func categories(sessionDuration: FanController.AutomaticRestoreDuration) -> Set<UNNotificationCategory> {
        let keepSame = UNNotificationAction(
            identifier: keepSameAction,
            title: fanBarFormat("再保持 %@", "Keep %@ more", sessionDuration.title)
        )
        let keepOn = UNNotificationAction(identifier: keepOnAction, title: fanBarText("一直保持", "Keep on"))
        let turnOnAgain = UNNotificationAction(
            identifier: turnOnAgainAction,
            title: fanBarText("重新开启", "Turn on again")
        )
        let retry = UNNotificationAction(identifier: turnOnAgainAction, title: fanBarText("重试", "Try again"))
        return [
            UNNotificationCategory(identifier: soonCategory, actions: [keepSame, keepOn], intentIdentifiers: []),
            UNNotificationCategory(identifier: endedCategory, actions: [turnOnAgain], intentIdentifiers: []),
            UNNotificationCategory(identifier: missingTemperatureCategory, actions: [retry], intentIdentifiers: []),
        ]
    }
}

extension FanCurveSensor {
    /// The bare sensor name for sentences such as "Couldn't read the CPU temperature".
    var shortName: String {
        switch self {
        case .maxChip: "CPU/GPU"
        case .cpu: "CPU"
        case .gpu: "GPU"
        case .ssd: "SSD"
        }
    }
}

extension HelperClientError {
    /// Manual control can never work on a Mac whose SMC has no fan mode key.
    /// A current helper says so with a structured code; an older one only in a
    /// message that names those keys in every language.
    var indicatesMissingFanModeKey: Bool {
        if let failure { return failure.code == .modeKeyMissing }
        return message.contains("F0Md/F0md")
    }
}
