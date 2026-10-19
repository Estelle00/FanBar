import FanBarShared
import SwiftUI

/// Light appearance uses opaque white; dark appearance retains its native glass tint.
struct PanelGlassBackground: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        LinearGradient(
            colors: scheme == .dark
                ? [Color(red: 0.16, green: 0.18, blue: 0.23).opacity(reduceTransparency ? 1 : 0.91),
                   Color(red: 0.09, green: 0.11, blue: 0.16).opacity(reduceTransparency ? 1 : 0.94)]
                : [.white, .white],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}

struct PanelCardBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
            .fill(LinearGradient(
                colors: scheme == .dark
                    ? [Color.white.opacity(0.035), Color.white.opacity(0.035)]
                    : [Color.white.opacity(0.86), Color(red: 0.94, green: 0.95, blue: 0.97).opacity(0.65)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: scheme == .dark ? [.clear, .clear] : [.white.opacity(0.95), .white.opacity(0.15)],
                            startPoint: .top, endPoint: .bottom
                        ), lineWidth: 1
                    )
                    .padding(0.7)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(scheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.09), lineWidth: 0.7)
            )
            .shadow(color: .black.opacity(scheme == .dark ? 0.08 : 0.045), radius: 2, y: 1)
    }
}

struct PanelFanCard: View {
    let fan: FanReading
    let target: Int?
    var isSingleFan = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = PanelPalette(colorScheme: scheme)
        Group {
            if isSingleFan {
                singleFanContent(palette: palette)
            } else {
                multiFanContent(palette: palette)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(PanelCardBackground())
        .accessibilityElement(children: .combine)
    }

    private func singleFanContent(palette: PanelPalette) -> some View {
        VStack(spacing: 7) {
            HStack(spacing: 6) {
                SpinningFanGlyph(rpm: fan.currentRPM)
                    .frame(width: 16, height: 16)
                    .foregroundColor(palette.secondaryText)
                Text(fanBarFormat("风扇 %d", "Fan %d", fan.index + 1))
                    .font(.system(size: 11, weight: .medium))
                Spacer(minLength: 8)
                Text(FanBarNumberFormatter.grouped(fan.currentRPM))
                    .font(.system(size: 26, weight: .semibold).monospacedDigit())
                Text("RPM").font(.system(size: 9, weight: .medium))
            }
            HStack {
                Text(fanBarFormat("范围 %@–%@", "Range %@–%@",
                                  FanBarNumberFormatter.grouped(fan.minimumRPM),
                                  FanBarNumberFormatter.grouped(fan.maximumRPM)))
                Spacer(minLength: 8)
                Text(target.map { fanBarFormat("目标 %@ RPM", "Target %@ RPM", FanBarNumberFormatter.grouped($0)) }
                     ?? fanBarText("系统自动调节", "Managed by macOS"))
            }
            .font(.system(size: 10).monospacedDigit())
            .foregroundColor(palette.secondaryText)
        }
    }

    private func multiFanContent(palette: PanelPalette) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                SpinningFanGlyph(rpm: fan.currentRPM)
                    .frame(width: 16, height: 16)
                    .foregroundColor(palette.secondaryText)
                Text(fanBarFormat("风扇 %d", "Fan %d", fan.index + 1))
            }
            .font(.system(size: 11, weight: .medium))
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(FanBarNumberFormatter.grouped(fan.currentRPM))
                    .font(.system(size: 26, weight: .semibold).monospacedDigit())
                Text("RPM").font(.system(size: 9, weight: .medium))
            }
            .padding(.vertical, 2)
            Text(fanBarFormat("范围 %@–%@", "Range %@–%@",
                              FanBarNumberFormatter.grouped(fan.minimumRPM),
                              FanBarNumberFormatter.grouped(fan.maximumRPM)))
                .font(.system(size: 10).monospacedDigit())
                .foregroundColor(palette.secondaryText)
            Text(target.map { fanBarFormat("目标 %@ RPM", "Target %@ RPM", FanBarNumberFormatter.grouped($0)) }
                 ?? fanBarText("系统自动调节", "Managed by macOS"))
                .font(.system(size: 10).monospacedDigit())
                .foregroundColor(palette.secondaryText)
        }
    }
}
