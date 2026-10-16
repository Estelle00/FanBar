import FanBarShared
import Foundation

/// Stable identity for any cooling preset. Built-in presets keep the helper's
/// closed `FanCoolingPreset`; user presets live only in the app and run
/// through the same curve path (`setCoolingFraction`), so the helper's
/// accepted inputs never grow.
enum CoolingPresetID: Hashable, Identifiable, Sendable {
    case builtIn(FanCoolingPreset)
    case custom(UUID)

    static let fallback = CoolingPresetID.builtIn(.balanced)

    var id: String { token }

    /// Persisted form: `builtin:2` or `custom:<uuid>`.
    var token: String {
        switch self {
        case .builtIn(let preset): "builtin:\(preset.rawValue)"
        case .custom(let id): "custom:\(id.uuidString)"
        }
    }

    init?(token: String) {
        let parts = token.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        switch parts[0] {
        case "builtin":
            guard let raw = Int(parts[1]), let preset = FanCoolingPreset(rawValue: raw) else { return nil }
            self = .builtIn(preset)
        case "custom":
            guard let id = UUID(uuidString: parts[1]) else { return nil }
            self = .custom(id)
        default:
            return nil
        }
    }

    var builtInPreset: FanCoolingPreset? {
        if case .builtIn(let preset) = self { return preset }
        return nil
    }

    var isBuiltIn: Bool { builtInPreset != nil }
}

/// Icons a user preset may use. A closed list of SF Symbols 2 names keeps
/// every choice drawable on the macOS 11 deployment target.
enum CustomPresetSymbol: String, Codable, CaseIterable, Identifiable, Sendable {
    case star
    case moon
    case leaf
    case headphones
    case gamecontroller
    case film
    case hammer
    case cpu
    case flame
    case snow
    case desktopcomputer
    case briefcase

    static let defaultSymbol = CustomPresetSymbol.star

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .star: "star.fill"
        case .moon: "moon.fill"
        case .leaf: "leaf.fill"
        case .headphones: "headphones"
        case .gamecontroller: "gamecontroller.fill"
        case .film: "film.fill"
        case .hammer: "hammer.fill"
        case .cpu: "cpu"
        case .flame: "flame.fill"
        case .snow: "snow"
        case .desktopcomputer: "desktopcomputer"
        case .briefcase: "briefcase.fill"
        }
    }

    var title: String {
        switch self {
        case .star: fanBarText("收藏", "Favorite")
        case .moon: fanBarText("夜间", "Night")
        case .leaf: fanBarText("节能", "Eco")
        case .headphones: fanBarText("会议", "Meetings")
        case .gamecontroller: fanBarText("游戏", "Gaming")
        case .film: fanBarText("剪辑", "Video editing")
        case .hammer: fanBarText("编译", "Building")
        case .cpu: fanBarText("计算", "Computing")
        case .flame: fanBarText("高温", "Hot")
        case .snow: fanBarText("冷却", "Cooling")
        case .desktopcomputer: fanBarText("外接显示器", "External display")
        case .briefcase: fanBarText("工作", "Work")
        }
    }
}

/// A user-named preset: a name, an icon and its own temperature curve.
struct CustomCoolingPreset: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var symbol: CustomPresetSymbol
    var curve: FanCurveProfile
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        symbol: CustomPresetSymbol,
        curve: FanCurveProfile,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.curve = curve.sanitized()
        self.createdAt = createdAt
    }
}

/// What every preset view needs, whether the preset is built in or custom.
struct CoolingPresetSummary: Identifiable, Equatable {
    let id: CoolingPresetID
    let title: String
    let systemImage: String

    var isBuiltIn: Bool { id.isBuiltIn }
}

/// Naming and count rules shared by the store, the controller and the UI.
enum CustomPresetRules {
    static let maximumCount = 6
    static let maximumNameLength = 16

    enum NameProblem: Equatable {
        case empty
        case tooLong
        case duplicate(String)

        var message: String {
            switch self {
            case .empty:
                fanBarText("请输入名称", "Enter a name")
            case .tooLong:
                fanBarFormat(
                    "名称最多 %d 个字符",
                    "Names can be up to %d characters",
                    CustomPresetRules.maximumNameLength
                )
            case .duplicate(let name):
                fanBarFormat(
                    "已有名为“%@”的预设",
                    "A preset named “%@” already exists",
                    name
                )
            }
        }
    }

    static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `takenNames` are every other preset's visible names, built-ins included.
    static func problem(with name: String, takenNames: [String]) -> NameProblem? {
        let trimmed = normalized(name)
        if trimmed.isEmpty { return .empty }
        if trimmed.count > maximumNameLength { return .tooLong }
        let lowered = trimmed.lowercased()
        if takenNames.contains(where: { $0.lowercased() == lowered }) {
            return .duplicate(trimmed)
        }
        return nil
    }

    /// The first free "Custom N".
    static func defaultName(takenNames: [String]) -> String {
        let taken = Set(takenNames.map { $0.lowercased() })
        var number = 1
        while true {
            let candidate = fanBarFormat("自定义 %d", "Custom %d", number)
            if !taken.contains(candidate.lowercased()) { return candidate }
            number += 1
        }
    }

    /// "Name Copy", then "Name Copy 2", … trimmed to fit the length limit.
    static func copyName(of name: String, takenNames: [String]) -> String {
        let taken = Set(takenNames.map { $0.lowercased() })
        let suffix = fanBarText(" 副本", " Copy")
        let base = String(name.prefix(maximumNameLength - suffix.count)) + suffix
        if !taken.contains(base.lowercased()) { return base }
        var number = 2
        while true {
            let tail = " \(number)"
            let candidate = String(base.prefix(maximumNameLength - tail.count)) + tail
            if !taken.contains(candidate.lowercased()) { return candidate }
            number += 1
        }
    }
}

/// Persists user presets as one versioned JSON payload.
enum CustomCoolingPresetStore {
    static let preferenceKey = "fanbar.customCoolingPresets.v1"

    private struct Payload: Codable {
        var version: Int
        var presets: [CustomCoolingPreset]
    }

    private struct LossyPreset: Decodable {
        let value: CustomCoolingPreset?

        init(from decoder: Decoder) throws {
            value = try? CustomCoolingPreset(from: decoder)
        }
    }

    private struct LossyPayload: Decodable {
        var presets: [LossyPreset]
    }

    /// Damaged entries are dropped one by one so a single bad record cannot
    /// hide the user's other presets.
    static func load(defaults: UserDefaults = .standard) -> [CustomCoolingPreset] {
        guard let data = defaults.data(forKey: preferenceKey),
              let payload = try? JSONDecoder().decode(LossyPayload.self, from: data) else {
            return []
        }
        var seen = Set<UUID>()
        var result: [CustomCoolingPreset] = []
        for preset in payload.presets.compactMap(\.value) where !seen.contains(preset.id) {
            let name = String(CustomPresetRules.normalized(preset.name).prefix(CustomPresetRules.maximumNameLength))
            guard !name.isEmpty else { continue }
            seen.insert(preset.id)
            var cleaned = preset
            cleaned.name = name
            cleaned.curve = preset.curve.sanitized()
            result.append(cleaned)
        }
        return Array(result.prefix(CustomPresetRules.maximumCount))
    }

    static func save(_ presets: [CustomCoolingPreset], defaults: UserDefaults = .standard) {
        do {
            let data = try JSONEncoder().encode(Payload(version: 1, presets: presets))
            defaults.set(data, forKey: preferenceKey)
        } catch {
            NSLog("FanBar: failed to save custom presets: %@", error.localizedDescription)
        }
    }
}
