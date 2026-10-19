import Foundation

/// SF Symbol names that need a fallback on older macOS. FanBar supports macOS 11,
/// and an unknown name renders as nothing, so each newer symbol pairs with one
/// that exists there.
enum FanBarSymbols {
    /// Fan blades: `fan` is macOS 14+, `fanblades` macOS 12+.
    static var fan: String {
        if #available(macOS 14.0, *) { return "fan" }
        return fanBlades
    }

    /// Bare blades for the spinning glyph; `wind` stands in on macOS 11.
    static var fanBlades: String {
        if #available(macOS 12.0, *) { return "fanblades" }
        return "wind"
    }

    /// "No fan data": `fan.slash` is macOS 14+.
    static var fanSlash: String {
        if #available(macOS 14.0, *) { return "fan.slash" }
        return "exclamationmark.triangle"
    }

    /// Half-filled circle for Balanced: the `.filled` spelling is macOS 12+.
    static var balanced: String {
        if #available(macOS 12.0, *) { return "circle.lefthalf.filled" }
        return "circle.lefthalf.fill"
    }

    /// Gauge for Performance: macOS 14+; `speedometer` is available everywhere.
    static var gauge: String {
        if #available(macOS 14.0, *) { return "gauge.with.dots.needle.67percent" }
        return "speedometer"
    }
}
