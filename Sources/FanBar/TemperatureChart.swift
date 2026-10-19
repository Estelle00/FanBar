import FanBarShared
import SwiftUI

/// Formats the chart's x-axis as wall-clock hour:minute. `mm:ss` would drop
/// the hour, so a window ending at 17:09 must still read `16:59  17:04  17:09`
/// when it crosses an hour boundary.
enum TemperatureChartTimeAxis {
    /// The window shown when the chart opens.
    static let historyDuration: TimeInterval = 10 * 60

    /// Longest window the chart can show. Samples older than this are dropped.
    static let retainedDuration: TimeInterval = 60 * 60

    /// Allow scheduling jitter around the two-second cadence without drawing a gap.
    static let maximumContinuousGap: TimeInterval = 5
    /// Short missing intervals may be bridged with a dashed line, never a filled area.
    /// Longer interruptions (sleep/restarts) remain disconnected.
    static let maximumSampleGap: TimeInterval = 15

    static func missingIntervals(dates: [Date], values: [Double?]) -> [ClosedRange<Int>] {
        guard dates.count == values.count else { return [] }
        var result: [ClosedRange<Int>] = []
        var previous: Int?
        for index in values.indices {
            guard let value = values[index], value.isFinite else { continue }
            if let previous {
                let elapsed = dates[index].timeIntervalSince(dates[previous])
                if elapsed > 0, elapsed <= maximumSampleGap,
                   index > previous + 1 || elapsed > maximumContinuousGap {
                    result.append(previous...index)
                }
            }
            previous = index
        }
        return result
    }

    /// Splits sample dates into runs of consecutive indices that are close
    /// enough in time to be drawn and smoothed as one continuous curve.
    static func segments(for dates: [Date]) -> [ClosedRange<Int>] {
        guard !dates.isEmpty else { return [] }

        var result: [ClosedRange<Int>] = []
        var start = dates.startIndex

        for index in dates.indices.dropFirst()
            where dates[index].timeIntervalSince(dates[index - 1]) > maximumContinuousGap {
            result.append(start...(index - 1))
            start = index
        }
        result.append(start...(dates.endIndex - 1))
        return result
    }

    /// The x-axis always spans the selected window ending at the newest sample
    /// (or now while no sample exists), so the axis stays predictable across
    /// app launches.
    static func displayRange(
        lastSample: Date?,
        duration: TimeInterval = historyDuration,
        now: Date = Date()
    ) -> ClosedRange<Date> {
        let end = lastSample ?? now
        return end.addingTimeInterval(-duration)...end
    }

    static func tickDates(in timeRange: ClosedRange<Date>) -> [Date] {
        let start = timeRange.lowerBound
        let end = timeRange.upperBound
        let midpoint = start.addingTimeInterval(end.timeIntervalSince(start) / 2)
        return [start, midpoint, end]
    }

    static func labels(
        in timeRange: ClosedRange<Date>,
        timeZone: TimeZone = .current
    ) -> [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "H:mm"
        return tickDates(in: timeRange).map { formatter.string(from: $0) }
    }
}

enum TemperatureChartScale {
    static func domain(alertThreshold: Double) -> ClosedRange<Double> {
        let threshold = ThermalAlertSettings.clampedThreshold(alertThreshold)
        return 20...max(100, threshold + 5)
    }
}

enum TemperatureHistoryStore {
    static let preferenceKey = "fanbar.temperatureHistory"

    static func load(
        from defaults: UserDefaults = .standard,
        now: Date = Date()
    ) -> [ThermalReading] {
        guard let data = defaults.data(forKey: preferenceKey),
              let decoded = try? JSONDecoder().decode([ThermalReading].self, from: data) else {
            return []
        }
        let cutoff = now.addingTimeInterval(-TemperatureChartTimeAxis.retainedDuration)
        return decoded.filter { $0.sampledAt >= cutoff }
    }

    static func save(_ samples: [ThermalReading], to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(samples) else { return }
        defaults.set(data, forKey: preferenceKey)
    }
}

/// Time windows the trace can show. Raw values are seconds, so `duration` is the window length.
enum TemperatureChartRange: TimeInterval, CaseIterable, Identifiable {
    case tenMinutes = 600
    case thirtyMinutes = 1800
    case oneHour = 3600

    var id: TimeInterval { rawValue }

    var duration: TimeInterval { rawValue }

    /// Short labels for the compact segmented control.
    var title: String {
        switch self {
        case .tenMinutes: fanBarText("10 分", "10m")
        case .thirtyMinutes: fanBarText("30 分", "30m")
        case .oneHour: fanBarText("1 时", "1h")
        }
    }
}

/// CPU (hottest core), GPU, SSD, and battery temperature over the selected
/// window, with a reference line at the configured high-temperature alert threshold. The legend doubles as the
/// current reading and toggles each series. Drawn with SwiftUI paths so it
/// works on macOS 11 without Charts.framework.
struct TemperatureChart: View {
    static let historyDuration = TemperatureChartTimeAxis.historyDuration

    /// Everything the controller retains, newest last. `samples` narrows it to the selected window.
    let allSamples: [ThermalReading]
    let alertThreshold: Double
    @Binding var range: TemperatureChartRange

    @State private var hiddenSeries: Set<TemperatureSeries> = []
    @Environment(\.colorScheme) private var colorScheme

    init(samples: [ThermalReading], range: Binding<TemperatureChartRange>, alertThreshold: Double) {
        self.alertThreshold = ThermalAlertSettings.clampedThreshold(alertThreshold)
        allSamples = samples
        _range = range
    }

    private var palette: PanelPalette { PanelPalette(colorScheme: colorScheme) }

    /// The newest sample always stays inside the window, so the legend and axis
    /// keep their values when the user switches to a shorter range.
    private var samples: [ThermalReading] {
        guard let newest = allSamples.last else { return [] }
        let start = newest.sampledAt.addingTimeInterval(-range.duration)
        return allSamples.filter { $0.sampledAt >= start }
    }

    private var latest: ThermalReading? { samples.last }

    private var drawnSeries: [TemperatureSeries] {
        TemperatureSeries.allCases.filter { series in
            !hiddenSeries.contains(series) && samples.contains { $0[keyPath: series.keyPath] != nil }
        }
    }

    /// CPU, GPU, and SSD always have a legend slot (greyed when a sensor is
    /// missing); the battery appears only on Macs that have one.
    private var legendSeries: [TemperatureSeries] {
        TemperatureSeries.allCases.filter { series in
            series != .battery || allSamples.contains { $0.batteryCelsius != nil }
        }
    }

    private var timeRange: ClosedRange<Date> {
        TemperatureChartTimeAxis.displayRange(lastSample: latest?.sampledAt, duration: range.duration)
    }

    private let smoothingRadius = 3

    private var sampleSegments: [ClosedRange<Int>] {
        TemperatureChartTimeAxis.segments(for: samples.map(\.sampledAt))
    }

    /// Applies a short low-pass window only to the rendered trace. The raw
    /// readings remain the source of the legend and control logic. The window
    /// never reaches across a break, so a resumed trace cannot drag the
    /// pre-break readings toward it.
    private var chartSamples: [ThermalReading] {
        let samples = samples
        guard samples.count > smoothingRadius * 2 else { return samples }

        return sampleSegments.flatMap { segment in
            segment.map { index in
                ThermalReading(
                    sampledAt: samples[index].sampledAt,
                    cpuCelsius: smoothedValue(samples, at: index, within: segment, keyPath: \.cpuCelsius),
                    gpuCelsius: smoothedValue(samples, at: index, within: segment, keyPath: \.gpuCelsius),
                    ssdCelsius: smoothedValue(samples, at: index, within: segment, keyPath: \.ssdCelsius),
                    batteryCelsius: smoothedValue(samples, at: index, within: segment, keyPath: \.batteryCelsius),
                    cpuHottestCelsius: smoothedValue(samples, at: index, within: segment, keyPath: \.cpuHottestCelsius)
                )
            }
        }
    }

    private func smoothedValue(
        _ samples: [ThermalReading],
        at index: Int,
        within segment: ClosedRange<Int>,
        keyPath: KeyPath<ThermalReading, Double?>
    ) -> Double? {
        // Smoothing must not turn an absent sensor reading into a measured value.
        guard let current = samples[index][keyPath: keyPath], current.isFinite else { return nil }
        let lowerBound = max(segment.lowerBound, index - smoothingRadius)
        let upperBound = min(segment.upperBound, index + smoothingRadius)
        let values = (lowerBound...upperBound).compactMap { samples[$0][keyPath: keyPath] }.filter { $0.isFinite }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text(fanBarText("温度", "Temperature"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(palette.secondaryText)

                Spacer()

                PanelSegmentedControl(
                    options: TemperatureChartRange.allCases.map { ($0, $0.title) },
                    selection: range,
                    compact: true
                ) { range = $0 }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(fanBarText("温度曲线时长", "Temperature window"))
            }

            legend
                .padding(.top, 8)
                .padding(.bottom, 4)
                .padding(.leading, -6)

            if samples.isEmpty {
                Text(fanBarText("正在读取温度", "Reading temperature"))
                    .font(.system(size: 11))
                    .foregroundColor(palette.tertiaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 76)
            } else {
                TemperaturePlot(
                    samples: chartSamples,
                    series: drawnSeries,
                    timeRange: timeRange,
                    palette: palette,
                    warningLine: alertThreshold
                )
                .frame(height: 76)
                .accessibilityLabel(fanBarText("温度曲线", "Temperature trends"))
            }

            axisLabels
                .padding(.top, 5)
        }
    }

    private var legend: some View {
        HStack(spacing: 2) {
            ForEach(legendSeries) { series in
                legendItem(series)
            }
            Spacer(minLength: 0)
            // Four series fill the row; the "Now" caption yields to the battery.
            if legendSeries.count < 4 {
                Text(fanBarText("现在", "Now"))
                    .font(.system(size: 10.5))
                    .foregroundColor(palette.tertiaryText)
            }
        }
    }

    private func legendItem(_ series: TemperatureSeries) -> some View {
        let value = latest?[keyPath: series.keyPath]
        let isShown = !hiddenSeries.contains(series)
        return Button {
            if hiddenSeries.contains(series) {
                hiddenSeries.remove(series)
            } else {
                hiddenSeries.insert(series)
            }
        } label: {
            HStack(spacing: 5) {
                Capsule()
                    .fill(series.color(in: palette))
                    .frame(width: 8, height: 2)
                Text(series.title)
                    .foregroundColor(palette.secondaryText)
                Text(value.map { "\(Int($0.rounded()))°" } ?? "—")
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            .font(.system(size: 11).monospacedDigit())
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
            .opacity(value == nil ? 0.45 : isShown ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .disabled(value == nil)
        .help(value == nil ? fanBarText("传感器不可用", "Sensor unavailable") : "")
        .accessibilityAddTraits(isShown ? .isSelected : [])
    }

    private var axisLabels: some View {
        let labels = TemperatureChartTimeAxis.labels(in: timeRange)
        return HStack {
            Text(labels[0])
            Spacer()
            Text(labels[1])
            Spacer()
            Text(fanBarText("现在", "Now"))
        }
        .font(.system(size: 9.5).monospacedDigit())
        .foregroundColor(palette.tertiaryText)
        .padding(.trailing, TemperaturePlot.axisWidth)
    }
}

private enum TemperatureSeries: String, CaseIterable, Identifiable {
    case cpu
    case gpu
    case ssd
    case battery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cpu: fanBarText("CPU 最高", "CPU highest")
        case .gpu: "GPU"
        case .ssd: fanBarText("SSD", "SSD")
        case .battery: fanBarText("电池", "Battery")
        }
    }

    func color(in palette: PanelPalette) -> Color {
        switch self {
        case .cpu: palette.cpu
        case .gpu: palette.gpu
        case .ssd: palette.ssd
        case .battery: palette.battery
        }
    }

    var keyPath: KeyPath<ThermalReading, Double?> {
        switch self {
        case .cpu: \.cpuDisplayCelsius
        case .gpu: \.gpuCelsius
        case .ssd: \.ssdCelsius
        case .battery: \.batteryCelsius
        }
    }
}

private struct TemperaturePlot: View {
    let samples: [ThermalReading]
    let series: [TemperatureSeries]
    let timeRange: ClosedRange<Date>
    let palette: PanelPalette

    /// Room on the right for the warning, 60°, and 40° labels.
    static let axisWidth: CGFloat = 26
    /// Starts at 20 °C so a cool battery stays visible above the baseline.
    let warningLine: Double
    private var domain: ClosedRange<Double> { TemperatureChartScale.domain(alertThreshold: warningLine) }
    private var gridTicks: [Double] { [60, 40].filter { abs($0 - warningLine) > 5 } }

    var body: some View {
        GeometryReader { proxy in
            let plot = CGRect(x: 0, y: 0, width: max(1, proxy.size.width - Self.axisWidth), height: proxy.size.height)

            ZStack(alignment: .topLeading) {
                ForEach(gridTicks, id: \.self) { tick in
                    gridLine(at: tick, in: plot)
                        .stroke(palette.hairline, lineWidth: 1)
                }
                gridLine(at: warningLine, in: plot)
                    .stroke(palette.warm.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))

                ForEach(series) { series in
                    let values = samples.map { $0[keyPath: series.keyPath] }
                    areaPath(values: values, in: plot)
                        .fill(LinearGradient(
                            colors: [series.color(in: palette).opacity(0.10), series.color(in: palette).opacity(0)],
                            startPoint: .top, endPoint: .bottom
                        ))
                    missingIntervalPath(values: values, in: plot)
                        .stroke(
                            series.color(in: palette).opacity(0.35),
                            style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [3, 3])
                        )
                    curvePath(values: values, in: plot)
                        .stroke(
                            series.color(in: palette),
                            style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
                        )
                        .shadow(color: series.color(in: palette).opacity(0.22), radius: 2, y: 2)
                }

                axisLabel("\(Int(warningLine))°", at: warningLine, in: plot, color: palette.warm)
                ForEach(gridTicks, id: \.self) { tick in
                    axisLabel("\(Int(tick))°", at: tick, in: plot, color: palette.tertiaryText)
                }
            }
        }
    }

    private func axisLabel(_ text: String, at value: Double, in plot: CGRect, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9.5).monospacedDigit())
            .foregroundColor(color)
            .frame(width: Self.axisWidth - 4, alignment: .leading)
            .position(x: plot.maxX + 4 + (Self.axisWidth - 4) / 2, y: yPosition(value, in: plot))
    }

    private func gridLine(at value: Double, in plot: CGRect) -> Path {
        Path { path in
            let y = yPosition(value, in: plot)
            path.move(to: CGPoint(x: plot.minX, y: y))
            path.addLine(to: CGPoint(x: plot.maxX, y: y))
        }
    }

    private func yPosition(_ value: Double, in rect: CGRect) -> CGFloat {
        let domain = self.domain
        let clamped = min(domain.upperBound, max(domain.lowerBound, value))
        let fraction = (clamped - domain.lowerBound) / (domain.upperBound - domain.lowerBound)
        return rect.maxY - CGFloat(fraction) * rect.height
    }

    /// Splits a series into drawable runs: a missing value or a gap in time ends a run.
    private func runs(values: [Double?], in rect: CGRect) -> [[CGPoint]] {
        let firstDate = timeRange.lowerBound
        let timeSpan = max(timeRange.upperBound.timeIntervalSince(firstDate), 1)
        var result: [[CGPoint]] = []
        var current: [CGPoint] = []

        for (index, value) in values.enumerated() {
            let date = samples[index].sampledAt
            if index > 0,
               date.timeIntervalSince(samples[index - 1].sampledAt) > TemperatureChartTimeAxis.maximumContinuousGap {
                if !current.isEmpty { result.append(current) }
                current = []
            }
            guard let value, value.isFinite else {
                if !current.isEmpty { result.append(current) }
                current = []
                continue
            }
            let position = min(1, max(0, date.timeIntervalSince(firstDate) / timeSpan))
            current.append(CGPoint(x: rect.minX + CGFloat(position) * rect.width, y: yPosition(value, in: rect)))
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    private func missingIntervalPath(values: [Double?], in rect: CGRect) -> Path {
        let dates = samples.map(\.sampledAt)
        let intervals = TemperatureChartTimeAxis.missingIntervals(dates: dates, values: values)
        let span = max(timeRange.upperBound.timeIntervalSince(timeRange.lowerBound), 1)
        return Path { path in
            for interval in intervals {
                guard let start = values[interval.lowerBound], let end = values[interval.upperBound] else { continue }
                let startX = dates[interval.lowerBound].timeIntervalSince(timeRange.lowerBound) / span
                let endX = dates[interval.upperBound].timeIntervalSince(timeRange.lowerBound) / span
                path.move(to: CGPoint(x: rect.minX + CGFloat(startX) * rect.width, y: yPosition(start, in: rect)))
                path.addLine(to: CGPoint(x: rect.minX + CGFloat(endX) * rect.width, y: yPosition(end, in: rect)))
            }
        }
    }

    private func curvePath(values: [Double?], in rect: CGRect) -> Path {
        var path = Path()
        for run in runs(values: values, in: rect) {
            appendSmoothRun(run, to: &path)
        }
        return path
    }

    private func areaPath(values: [Double?], in rect: CGRect) -> Path {
        var path = Path()
        for run in runs(values: values, in: rect) where run.count > 1 {
            var line = Path()
            appendSmoothRun(run, to: &line)
            path.addPath(line)
            path.addLine(to: CGPoint(x: run[run.count - 1].x, y: rect.maxY))
            path.addLine(to: CGPoint(x: run[0].x, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }

    private func appendSmoothRun(_ points: [CGPoint], to path: inout Path) {
        guard let first = points.first else { return }
        path.move(to: first)
        guard points.count > 1 else {
            path.addLine(to: first)
            return
        }
        for index in 0..<(points.count - 1) {
            let p0 = index > 0 ? points[index - 1] : points[index]
            let p1 = points[index]
            let p2 = points[index + 1]
            let p3 = index + 2 < points.count ? points[index + 2] : p2
            let control1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let control2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: control1, control2: control2)
        }
    }
}
