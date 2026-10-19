import AppKit
import FanBarShared
import SwiftUI

// MARK: - Tokens

/// Semantic colors from docs/design/menu-panel-redesign-v2.html. One material,
/// one hairline, one raised selection; color is reserved for data.
struct PanelPalette {
    let colorScheme: ColorScheme

    private var isDark: Bool { colorScheme == .dark }

    private static func rgb(_ hex: UInt32, _ opacity: Double = 1) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// Laid over the popover's own blur.
    var surface: Color { isDark ? Self.rgb(0x24262A, 0.84) : Self.rgb(0xF6F7F9, 0.86) }
    var well: Color { isDark ? Color.white.opacity(0.07) : Self.rgb(0x141E2D, 0.055) }
    var raised: Color { isDark ? Self.rgb(0x4A4D53) : .white }
    var hairline: Color { isDark ? Color.white.opacity(0.09) : Self.rgb(0x141E2D, 0.09) }
    var secondaryText: Color { isDark ? Self.rgb(0xC2C8D8) : Self.rgb(0x5F6670) }
    var tertiaryText: Color { isDark ? Self.rgb(0xAEB7C8) : Self.rgb(0x626D80) }

    var accent: Color { isDark ? Self.rgb(0x5CC29F) : Self.rgb(0x1F7A62) }
    var warm: Color { isDark ? Self.rgb(0xF0995A) : Self.rgb(0xC8641C) }
    var hot: Color { isDark ? Self.rgb(0xF07070) : Self.rgb(0xC93A3A) }

    var cpu: Color { isDark ? Self.rgb(0xF0995A) : Self.rgb(0xE07A2F) }
    var gpu: Color { isDark ? Self.rgb(0x7AAEDB) : Self.rgb(0x4A86B8) }
    var ssd: Color { isDark ? Self.rgb(0x5CC29F) : Self.rgb(0x2F9A7A) }
    var battery: Color { isDark ? Self.rgb(0xB79CE0) : Self.rgb(0x8E6BBF) }
    var memoryApp: Color { gpu }
    var memoryCache: Color { isDark ? Self.rgb(0x8FCBCF) : Self.rgb(0x6FB3B8) }
    var memoryCompressed: Color { isDark ? Self.rgb(0xDDB46E) : Self.rgb(0xC99A4A) }

    var glyphGradient: LinearGradient {
        LinearGradient(
            colors: isDark ? [Self.rgb(0x5A5E65), Self.rgb(0x3A3D42)] : [Self.rgb(0xFDFDFE), Self.rgb(0xE4E7EB)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var glyphInk: Color { isDark ? Self.rgb(0xE6E8EB) : Self.rgb(0x3A4049) }

    func color(for level: ThermalLevel) -> Color {
        switch level {
        case .normal: accent
        case .warm: warm
        case .hot: hot
        }
    }
}

/// A part whose temperature the panel watches, each with its own limits. One
/// shared threshold would either nag about a normal CPU or stay silent about
/// a hot battery.
enum ThermalPart: CaseIterable, Equatable {
    case cpu
    case gpu
    case ssd
    case battery

    var name: String {
        switch self {
        case .cpu: "CPU"
        case .gpu: "GPU"
        case .ssd: "SSD"
        case .battery: fanBarText("电池", "Battery")
        }
    }

    /// CPU uses the hottest core, which is what throttling responds to.
    var keyPath: KeyPath<ThermalReading, Double?> {
        switch self {
        case .cpu: \.cpuDisplayCelsius
        case .gpu: \.gpuCelsius
        case .ssd: \.ssdCelsius
        case .battery: \.batteryCelsius
        }
    }

    /// Apple silicon and Intel CPUs and GPUs throttle near 100 °C; NVMe drives
    /// commonly slow down from 70–80 °C; lithium-ion cells age faster above 40 °C.
    var warmThreshold: Double {
        switch self {
        case .cpu, .gpu: 85
        case .ssd: 65
        case .battery: 40
        }
    }

    var hotThreshold: Double {
        switch self {
        case .cpu, .gpu: 95
        case .ssd: 75
        case .battery: 45
        }
    }

    /// Range of the hero's scale bar, wide enough to show normal and hot.
    var scale: ClosedRange<Double> {
        switch self {
        case .cpu, .gpu: 30...105
        case .ssd: 25...85
        case .battery: 20...50
        }
    }
}

/// How urgent a reading is for its part: the only thing besides data that earns color.
enum ThermalLevel: Int, Comparable {
    case normal
    case warm
    case hot

    init(celsius: Double?, part: ThermalPart) {
        guard let celsius else {
            self = .normal
            return
        }
        self = celsius >= part.hotThreshold ? .hot : celsius >= part.warmThreshold ? .warm : .normal
    }

    static func < (lhs: ThermalLevel, rhs: ThermalLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// The reading the panel leads with: the part that most needs attention, or
/// the hottest one when every part is within its limits.
struct ThermalFocus: Equatable {
    var part: ThermalPart
    var celsius: Double

    var level: ThermalLevel { ThermalLevel(celsius: celsius, part: part) }

    /// True when the focus is an alert rather than simply the warmest part.
    var isAlert: Bool { level > .normal }

    static func from(_ reading: ThermalReading?) -> ThermalFocus? {
        guard let reading else { return nil }
        let readings = ThermalPart.allCases.compactMap { part in
            reading[keyPath: part.keyPath].map { ThermalFocus(part: part, celsius: $0) }
        }
        // Most urgent first; among equals, the one closest to its hot limit.
        let mostUrgent = readings.max { lhs, rhs in
            if lhs.level != rhs.level { return lhs.level < rhs.level }
            return lhs.celsius / lhs.part.hotThreshold < rhs.celsius / rhs.part.hotThreshold
        }
        if let mostUrgent, mostUrgent.isAlert { return mostUrgent }
        // The battery runs far cooler than chips, so it never leads when all is normal.
        return readings.filter { $0.part != .battery }.max { $0.celsius < $1.celsius } ?? mostUrgent
    }

    /// Change against the reading about `span` ago. When history is shorter,
    /// compares with the oldest reading and reports its real age; under a
    /// minute of history there is no trend to show.
    func trend(in history: [ThermalReading], span: TimeInterval) -> (delta: Double, minutes: Int)? {
        guard let latest = history.last else { return nil }
        let keyPath = part.keyPath
        let target = latest.sampledAt.addingTimeInterval(-span)
        guard let past = history.first(where: { $0.sampledAt >= target && $0[keyPath: keyPath] != nil }),
              let pastValue = past[keyPath: keyPath] else { return nil }
        let age = latest.sampledAt.timeIntervalSince(past.sampledAt)
        guard age >= 60 else { return nil }
        return (celsius - pastValue, Int((age / 60).rounded()))
    }
}

/// A one-point rule in the panel's hairline color.
struct PanelDivider: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Rectangle()
            .fill(PanelPalette(colorScheme: colorScheme).hairline)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
}

/// Equal-width segments on a well, with one raised selection: the panel's only selected state.
struct PanelSegmentedControl<ID: Hashable>: View {
    let options: [(id: ID, title: String)]
    let selection: ID?
    var compact = false
    var systemImage: (ID) -> String? = { _ in nil }
    let onSelect: (ID) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var namespace

    var body: some View {
        let palette = PanelPalette(colorScheme: colorScheme)
        HStack(spacing: 2) {
            ForEach(options, id: \.id) { option in
                segment(option, selected: option.id == selection, palette: palette)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: compact ? 7 : 8, style: .continuous)
                .fill(palette.well)
        )
    }

    private func segment(_ option: (id: ID, title: String), selected: Bool, palette: PanelPalette) -> some View {
        let radius: CGFloat = compact ? 5 : 6
        return Button {
            onSelect(option.id)
        } label: {
            HStack(spacing: 4) {
                if let symbol = systemImage(option.id) {
                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .medium))
                        .accessibilityHidden(true)
                }
                Text(option.title)
            }
                .font(.system(size: compact ? 10.5 : 12, weight: .medium))
                .foregroundColor(selected ? .primary : palette.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.vertical, compact ? 2 : 8)
                .padding(.horizontal, compact ? 7 : 4)
                .frame(maxWidth: compact ? nil : .infinity)
                .background(
                    Group {
                        if selected {
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .fill(palette.raised)
                                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.12), radius: 1, y: 1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                                        .stroke(Color.black.opacity(colorScheme == .dark ? 0 : 0.08), lineWidth: 0.5)
                                )
                                .matchedGeometryEffect(id: "selection", in: namespace)
                        }
                    }
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Thermal hero

/// The hottest temperature, the panel's single large number, with the fans it drives beside it.
struct ThermalHero: View {
    let focus: ThermalFocus?
    let trend: (delta: Double, minutes: Int)?
    let fans: [FanReading]
    let targets: [Int?]

    @Environment(\.colorScheme) private var colorScheme

    private var palette: PanelPalette { PanelPalette(colorScheme: colorScheme) }
    private var level: ThermalLevel { focus?.level ?? .normal }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            temperature
                .frame(width: 116, alignment: .leading)

            VStack(alignment: .leading, spacing: 11) {
                ForEach(Array(fans.prefix(2).enumerated()), id: \.element.id) { position, fan in
                    FanMeter(
                        name: fans.count > 1
                            ? fanBarFormat("风扇 %d", "Fan %d", fan.index + 1)
                            : fanBarText("风扇", "Fan"),
                        fan: fan,
                        target: position < targets.count ? targets[position] : nil,
                        isHot: level == .hot
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var temperature: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(focusLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(palette.secondaryText)

            HStack(alignment: .top, spacing: 1) {
                Text(focus.map { "\(Int($0.celsius.rounded()))" } ?? "—")
                    .font(.system(size: 44, weight: .semibold).monospacedDigit())
                    .tracking(-1.5)
                    .foregroundColor(level == .normal ? .primary : palette.color(for: level))
                Text("°C")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(palette.secondaryText)
                    .padding(.top, 5)
            }
            .frame(height: 48)
            .accessibilityElement(children: .combine)

            trendLine
                .padding(.top, 2)

            TemperatureScale(celsius: focus?.celsius, part: focus?.part ?? .cpu, palette: palette)
                .padding(.top, 9)
        }
    }

    /// "最高 · CPU" while all is normal; "关注 · 电池" when a part passes its own limit.
    private var focusLabel: String {
        guard let focus else { return fanBarText("温度", "Temperature") }
        return focus.isAlert
            ? fanBarFormat("关注 · %@", "Attention · %@", focus.part.name)
            : fanBarFormat("最高 · %@", "Hottest · %@", focus.part.name)
    }

    @ViewBuilder private var trendLine: some View {
        if let trend {
            let rounded = Int(trend.delta.rounded())
            let arrow = rounded > 0 ? "↑" : rounded < 0 ? "↓" : "→"
            HStack(spacing: 4) {
                Text("\(arrow) \(abs(rounded))°")
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                Text(fanBarFormat("较 %d 分钟前", "vs %d min ago", trend.minutes))
                    .foregroundColor(palette.secondaryText)
            }
            .font(.system(size: 11).monospacedDigit())
            .lineLimit(1)
        } else {
            Text(" ")
                .font(.system(size: 11))
        }
    }
}

/// The part's own range on a cool-to-hot ramp, with ticks at the ends and at
/// its warning threshold, and a marker at the current reading.
private struct TemperatureScale: View {
    let celsius: Double?
    let part: ThermalPart
    let palette: PanelPalette

    private func position(_ value: Double) -> CGFloat {
        let range = part.scale
        return CGFloat(min(1, max(0, (value - range.lowerBound) / (range.upperBound - range.lowerBound))))
    }

    var body: some View {
        let warmStop = Double(position(part.warmThreshold))
        let hotStop = max(Double(position(part.hotThreshold)), warmStop + 0.01)
        VStack(spacing: 3) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(
                            stops: [
                                .init(color: palette.accent.opacity(0.45), location: 0),
                                .init(color: palette.warm.opacity(0.55), location: warmStop),
                                .init(color: palette.hot.opacity(0.7), location: min(1, hotStop))
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(height: 4)
                    if let celsius {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.primary)
                            .frame(width: 2, height: 10)
                            .offset(x: position(celsius) * proxy.size.width - 1)
                    }
                }
                .frame(height: 10)
            }
            .frame(height: 10)

            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    Text("\(Int(part.scale.lowerBound))")
                    Text("\(Int(part.warmThreshold))")
                        .fixedSize()
                        .frame(width: 30)
                        .offset(x: position(part.warmThreshold) * proxy.size.width - 15)
                    Text("\(Int(part.scale.upperBound))")
                        .frame(width: proxy.size.width, alignment: .trailing)
                }
            }
            .frame(height: 12)
            .font(.system(size: 9.5).monospacedDigit())
            .foregroundColor(palette.tertiaryText)
        }
        .accessibilityHidden(true)
    }
}

/// Live RPM on the fan's own range, with an accent tick at the target FanBar asks for.
private struct FanMeter: View {
    let name: String
    let fan: FanReading
    let target: Int?
    let isHot: Bool

    @Environment(\.colorScheme) private var colorScheme

    private var palette: PanelPalette { PanelPalette(colorScheme: colorScheme) }

    private func position(_ rpm: Int) -> CGFloat {
        let span = max(fan.maximumRPM - fan.minimumRPM, 1)
        return CGFloat(min(1, max(0, Double(rpm - fan.minimumRPM) / Double(span))))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                SpinningFanGlyph(rpm: fan.currentRPM)
                    .frame(width: 16, height: 16)
                    .foregroundColor(palette.secondaryText)
                Text(name)
                    .font(.system(size: 11))
                    .foregroundColor(palette.secondaryText)
                    .lineLimit(1)
                Spacer(minLength: 4)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(FanBarNumberFormatter.grouped(fan.currentRPM))
                        .font(.system(size: 15, weight: .semibold).monospacedDigit())
                    Text("rpm")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(palette.tertiaryText)
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(palette.well)
                        .frame(height: 4)
                    Capsule()
                        .fill(isHot ? palette.warm.opacity(0.8) : palette.secondaryText.opacity(0.55))
                        .frame(width: position(fan.currentRPM) * proxy.size.width, height: 4)
                    if let target {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(palette.accent)
                            .frame(width: 2, height: 10)
                            .offset(x: position(target) * proxy.size.width - 1)
                    }
                }
                .frame(height: 10)
            }
            .frame(height: 10)
            .padding(.leading, 23)
        }
        .help(fanBarFormat(
            "范围 %@–%@ RPM",
            "Range %@–%@ RPM",
            FanBarNumberFormatter.grouped(fan.minimumRPM),
            FanBarNumberFormatter.grouped(fan.maximumRPM)
        ))
        .accessibilityElement(children: .combine)
        .accessibilityValue(target.map {
            fanBarFormat("目标 %@ RPM", "Target %@ RPM", FanBarNumberFormatter.grouped($0))
        } ?? "")
    }
}

/// Turns at a speed derived from RPM, only while the panel is on screen and motion is allowed.
struct SpinningFanGlyph: View {
    let rpm: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isPanelVisible) private var isPanelVisible
    @AppStorage(PanelAnimationPreferences.preferenceKey)
    private var panelAnimationEnabled = true
    @State private var isSpinning = false

    private var shouldSpin: Bool {
        rpm > 0 && isPanelVisible && panelAnimationEnabled && !reduceMotion
    }

    /// One turn every 40 / (RPM / 60) seconds, so faster fans visibly turn faster.
    private var period: Double {
        min(max(60 / Double(max(rpm, 1)) * 40, 0.4), 4)
    }

    var body: some View {
        glyph
            .font(.system(size: 13))
            .rotationEffect(.degrees(isSpinning ? 360 : 0))
            .animation(
                isSpinning ? .linear(duration: period).repeatForever(autoreverses: false) : .default,
                value: isSpinning
            )
            .onAppear { isSpinning = shouldSpin }
            .onChange(of: shouldSpin) { isSpinning = $0 }
            .accessibilityHidden(true)
    }

    @ViewBuilder private var glyph: some View {
        if #available(macOS 13.0, *) {
            Image(systemName: "fanblades")
        } else {
            Image(systemName: "fan")
        }
    }
}

// MARK: - Formatting

/// Byte formatting tuned for the narrow panel.
enum PanelByteFormat {
    static let gibibyte = 1_073_741_824.0
    static let gigabyte = 1_000_000_000.0

    /// "128 / 358 GB" for disks, using decimal units like Finder.
    static func diskPair(used: UInt64, total: UInt64) -> String {
        let usedGB = FanBarNumberFormatter.grouped(Int((Double(used) / gigabyte).rounded()))
        let totalGB = FanBarNumberFormatter.grouped(Int((Double(total) / gigabyte).rounded()))
        return "\(usedGB) / \(totalGB) GB"
    }

    /// Short size such as "0 B", "512 MB", or "3.7 GB".
    static func compact(_ bytes: UInt64, unit: Double = gibibyte) -> String {
        let value = Double(bytes)
        if bytes == 0 { return "0 B" }
        if value >= unit { return String(format: "%.1f GB", value / unit) }
        return String(format: "%.0f MB", value / (unit / 1024))
    }

    static func diskGigabytes(_ bytes: UInt64) -> String {
        "\(FanBarNumberFormatter.grouped(Int((Double(bytes) / gigabyte).rounded()))) GB"
    }
}
