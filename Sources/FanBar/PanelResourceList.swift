import FanBarShared
import SwiftUI

// MARK: - Resources

/// Compact resource cards; only disk has a disclosure for its volume list.
struct PanelResourceList: View {
    enum Resource: Hashable {
        case cpu
        case memory
        case gpu
        case disk
    }

    let usage: SystemUsage
    let thermal: ThermalReading?
    let cpuHistory: [Double]
    let gpuHistory: [Double]
    let animates: Bool

    @Binding var expanded: Resource?
    @Environment(\.colorScheme) private var colorScheme

    private var palette: PanelPalette { PanelPalette(colorScheme: colorScheme) }

    var body: some View {
        VStack(spacing: 6) {
            cards
            if expanded == .disk {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(fanBarText("磁盘", "Disk"))
                            .font(.system(size: 11, weight: .medium))
                        Spacer()
                        Button {
                            setExpanded(nil)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .medium))
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(fanBarText("关闭", "Close"))
                    }
                    diskDetail
                        .font(.system(size: 10))
                        .foregroundColor(palette.secondaryText)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PanelCardBackground())
            }
        }
    }

    private func setExpanded(_ resource: Resource?) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { expanded = resource }
    }

    private var cards: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
            row(
                .cpu,
                title: "CPU",
                value: percent(usage.cpuFraction),
                meta: temperatureText(thermal?.cpuDisplayCelsius)
            ) {
                CoreGroups(fractions: usage.cpuCoreFractions, kinds: usage.cpuCoreKinds,
                           coreCount: usage.cpuCoreCount, palette: palette)
            }
            row(
                .memory,
                title: fanBarText("内存", "Memory"),
                value: percent(usage.memoryFraction),
                meta: usage.memory.map(memoryMeta) ?? "—"
            ) {
                VStack(spacing: 5) {
                    MemoryBar(memory: usage.memory, palette: palette).frame(height: 10)
                    HStack(spacing: 5) {
                        memoryKey(palette.memoryApp, fanBarText("应用", "App"))
                        memoryKey(palette.memoryCache, fanBarText("缓存", "Cache"))
                        memoryKey(palette.memoryCompressed, fanBarText("压缩", "Comp."))
                        memoryKey(palette.well, fanBarText("空闲", "Free"))
                    }
                }
            }
            row(.gpu, title: "GPU", value: percent(usage.gpuFraction), meta: temperatureText(thermal?.gpuCelsius)) {
                SegmentedUsageBar(fraction: usage.gpuFraction, color: palette.gpu, palette: palette)
            }
            row(.disk, title: fanBarText("磁盘", "Disk"), value: percent(usage.diskFraction), meta: diskMeta) {
                CapacityBar(fraction: usage.diskFraction, color: palette.ssd, palette: palette)
            }
        }
    }

    // MARK: Rows

    private func row(
        _ resource: Resource,
        title: String,
        value: String,
        meta: String,
        @ViewBuilder viz: () -> some View
    ) -> some View {
        let isOpen = resource == .disk && expanded == .disk
        let content = VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Circle().fill(resourceColor(resource)).frame(width: 7, height: 7)
                Text(title).font(.system(size: 11, weight: .medium))
                Spacer(minLength: 0)
                if resource == .disk, usage.disks.count > 1 {
                    Text("\(usage.disks.count)")
                        .font(.system(size: 9).monospacedDigit())
                        .foregroundColor(palette.secondaryText)
                }
                if resource == .disk {
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(palette.secondaryText)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value)
                    .font(.system(size: 25, weight: .semibold).monospacedDigit())
                    .foregroundColor(.primary)
                Text(meta)
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundColor(palette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            viz().frame(height: resource == .cpu ? 42 : 30)
            if resource != .cpu {
                resourceSummary(resource)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        return Group {
            if resource == .disk {
                Button {
                    setExpanded(isOpen ? nil : .disk)
                } label: { content }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOpen ? .isSelected : [])
            } else {
                content.accessibilityElement(children: .combine)
            }
        }
        .accessibilityLabel(title)
        .accessibilityValue("\(value), \(meta)")
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PanelCardBackground())
    }

    private func resourceSummary(_ resource: Resource) -> some View {
        Text(summary(for: resource))
            .font(.system(size: 9).monospacedDigit())
            .foregroundColor(palette.secondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private func summary(for resource: Resource) -> String {
        switch resource {
        case .cpu: return ""
        case .memory:
            guard let memory = usage.memory else { return "—" }
            return fanBarFormat("压缩 %@", "Compressed %@", PanelByteFormat.compact(memory.compressedBytes))
                + " · " + (memory.swapUsedBytes.map {
                    fanBarFormat("交换 %@", "Swap %@", PanelByteFormat.compact($0))
                } ?? "—")
        case .gpu:
            let cores = usage.gpuCoreCount.map { fanBarFormat("%d 核", "%d cores", $0) } ?? "—"
            let memory = usage.gpuMemoryInUseBytes.map {
                fanBarFormat("显存占用 %@", "Memory in use %@", PanelByteFormat.compact($0))
            } ?? "—"
            return cores + " · " + memory
        case .disk:
            let internalCount = usage.disks.filter(\.isInternal).count
            return fanBarFormat("内置 %d · 外置 %d", "Internal %d · External %d",
                                internalCount, usage.disks.count - internalCount)
        }
    }

    private func resourceColor(_ resource: Resource) -> Color {
        switch resource {
        case .cpu: palette.cpu
        case .memory: palette.battery
        case .gpu: palette.gpu
        case .disk: palette.ssd
        }
    }

    private func memoryKey(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 2) {
            Circle().fill(color).frame(width: 4, height: 4)
            Text(title).font(.system(size: 8)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .foregroundColor(palette.secondaryText)
    }

    private var diskDetail: some View {
        VStack(spacing: 9) {
            ForEach(usage.disks) { disk in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(disk.name)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 4)
                        Text(PanelByteFormat.diskPair(used: disk.usedBytes, total: disk.totalBytes))
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundColor(palette.secondaryText)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    CapacityBar(fraction: disk.fraction, color: palette.ssd, palette: palette)
                        .frame(height: 8)
                }
            }
        }
    }

    private func percent(_ fraction: Double?) -> String {
        fraction.map { "\(Int(($0 * 100).rounded()))%" } ?? "—"
    }

    private func temperatureText(_ celsius: Double?) -> String {
        celsius.map { "\(Int($0.rounded()))°C" } ?? "—"
    }

    /// "8.4 / 16 GB": used to a tenth, installed memory as the whole number Apple sells.
    private func memoryMeta(_ memory: MemoryBreakdown) -> String {
        String(
            format: "%.1f / %.0f GB",
            Double(memory.usedBytes) / PanelByteFormat.gibibyte,
            Double(memory.totalBytes) / PanelByteFormat.gibibyte
        )
    }

    private var diskMeta: String {
        guard let used = usage.diskUsedBytes, let total = usage.diskTotalBytes else { return "—" }
        return PanelByteFormat.diskPair(used: used, total: total)
    }
}

/// A full-width row that highlights on hover and stays highlighted while open.
private struct ResourceRowButton<Label: View>: View {
    let isOpen: Bool
    let palette: PanelPalette
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            label()
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isOpen || isHovered ? palette.well : Color.clear)
                )
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isOpen ? .isSelected : [])
    }
}

// MARK: - Visualizations

/// A 60-second trend line with a light fill, newest on the right.
private struct Sparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let points = linePoints(in: proxy.size)
            if points.count > 1 {
                ZStack {
                    Path { path in
                        path.move(to: CGPoint(x: points[0].x, y: proxy.size.height))
                        points.forEach { path.addLine(to: $0) }
                        path.addLine(to: CGPoint(x: points[points.count - 1].x, y: proxy.size.height))
                        path.closeSubpath()
                    }
                    .fill(color.opacity(0.14))

                    Path { path in path.addLines(points) }
                        .stroke(color, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// Right-aligned, so a minute that is still filling grows in from the right.
    private func linePoints(in size: CGSize) -> [CGPoint] {
        let capacity = max(FanController.usageHistorySampleCount - 1, 1)
        let recent = values.suffix(capacity + 1)
        let step = size.width / CGFloat(capacity)
        let offset = CGFloat(max(capacity - (recent.count - 1), 0)) * step
        return recent.enumerated().map { index, value in
            CGPoint(
                x: offset + CGFloat(index) * step,
                y: size.height - CGFloat(min(1, max(0, value))) * (size.height - 1) - 0.5
            )
        }
    }
}

/// App, compressed, and cached memory on one bar; the rest is free.
private struct MemoryBar: View {
    let memory: MemoryBreakdown?
    let palette: PanelPalette

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 1) {
                if let memory, memory.totalBytes > 0 {
                    let total = Double(memory.totalBytes)
                    segment(Double(memory.appBytes) / total, palette.memoryApp, width: proxy.size.width)
                    segment(Double(memory.cachedBytes) / total, palette.memoryCache, width: proxy.size.width)
                    segment(Double(memory.compressedBytes) / total, palette.memoryCompressed, width: proxy.size.width)
                }
                Spacer(minLength: 0)
            }
            .frame(height: 8)
            .background(palette.well)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .frame(maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }

    private func segment(_ fraction: Double, _ color: Color, width: CGFloat) -> some View {
        Rectangle()
            .fill(LinearGradient(colors: [color.opacity(0.72), color], startPoint: .top, endPoint: .bottom))
            .frame(width: max(0, CGFloat(fraction) * width - 1))
    }
}

/// One filled capacity bar.
private struct CapacityBar: View {
    let fraction: Double?
    let color: Color
    let palette: PanelPalette

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                palette.well
                LinearGradient(colors: [color.opacity(0.75), color], startPoint: .leading, endPoint: .trailing)
                    .frame(width: CGFloat(min(1, max(0, fraction ?? 0))) * proxy.size.width)
            }
            .frame(height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .frame(maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }
}

/// Per-core load bars, grouped into performance and efficiency clusters by
/// position and a label underneath. Height is the only encoding of load.
private struct CoreGroups: View {
    let fractions: [Double]
    let kinds: [CPUCoreKind]
    let coreCount: Int?
    let palette: PanelPalette

    private struct CoreGroup: Identifiable {
        var id: String { title }
        var title: String
        var loads: [Double]
    }

    private var groups: [CoreGroup] {
        let placeholderCount = coreCount ?? (kinds.isEmpty ? ProcessInfo.processInfo.activeProcessorCount : kinds.count)
        let loads = fractions.isEmpty ? Array(repeating: 0, count: placeholderCount) : fractions
        guard kinds.count == loads.count, Set(kinds.map { $0 == .performance }).count > 1 else {
            return [CoreGroup(title: fanBarFormat("%d 核", "%d cores", loads.count), loads: loads)]
        }
        let performance = zip(kinds, loads).filter { $0.0 == .performance }.map(\.1)
        let efficiency = zip(kinds, loads).filter { $0.0 == .efficiency }.map(\.1)
        return [
            CoreGroup(title: fanBarFormat("性能 ×%d", "Performance ×%d", performance.count), loads: performance),
            CoreGroup(title: fanBarFormat("能效 ×%d", "Efficiency ×%d", efficiency.count), loads: efficiency)
        ]
    }

    var body: some View {
        let groups = groups
        let total = max(groups.reduce(0) { $0 + $1.loads.count }, 1)
        // Mac Pro and Ultra chips have 24+ cores; tighter gaps keep each bar readable.
        let barSpacing: CGFloat = total > 16 ? 1 : 3
        GeometryReader { proxy in
            let available = proxy.size.width - CGFloat(groups.count - 1) * 10
            HStack(alignment: .top, spacing: 10) {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: barSpacing) {
                            ForEach(Array(group.loads.enumerated()), id: \.offset) { _, load in
                                ZStack(alignment: .bottom) {
                                    RoundedRectangle(cornerRadius: 2).fill(palette.well)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(palette.cpu)
                                        .frame(height: max(2, 24 * CGFloat(min(1, max(0, load)))))
                                }
                                .frame(height: 24)
                            }
                        }
                        Rectangle()
                            .fill(palette.hairline)
                            .frame(height: 1)
                        Text(group.title)
                            .font(.system(size: 10))
                            .foregroundColor(palette.tertiaryText)
                            .lineLimit(1)
                    }
                    .frame(width: available * CGFloat(group.loads.count) / CGFloat(total))
                }
            }
        }
        .frame(height: 42)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(fanBarText("每核 CPU 使用率", "CPU usage per core"))
        .accessibilityValue(fractions.map { "\(Int(($0 * 100).rounded()))%" }.joined(separator: ", "))
    }
}

/// Segments encode total GPU occupancy, never fabricated per-core readings.
private struct SegmentedUsageBar: View {
    let fraction: Double?
    let color: Color
    let palette: PanelPalette

    var body: some View {
        GeometryReader { proxy in
            let count = 8
            let spacing: CGFloat = 2
            let width = max(0, (proxy.size.width - CGFloat(count - 1) * spacing) / CGFloat(count))
            HStack(spacing: spacing) {
                ForEach(0..<count, id: \.self) { index in
                    let fill = min(1, max(0, (fraction ?? 0) * Double(count) - Double(index)))
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(palette.well)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(LinearGradient(colors: [color.opacity(0.7), color],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(width: width * CGFloat(fill))
                    }
                    .frame(width: width, height: 9)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }
}
