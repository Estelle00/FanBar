import AppKit

/// Spins the status-item icon briefly when something worth noticing happens:
/// a mode switch, or a fan speed change large enough to matter. Otherwise the
/// icon stays still.
///
/// The controller calls `update(rpm:on:style:isManual:)` with the average RPM on
/// every change. A noticeable change in that reading starts a few seconds of
/// rotation at a matching speed, then the icon coasts to rest. A continuous
/// spin cost several percent of CPU: every frame makes AppKit re-snapshot the
/// status item for each display's menu bar. A failed mode switch can still
/// flash the icon via `flashFailure()`.
///
/// The status item is pure AppKit (macOS 11 target), so SF Symbol effects are
/// unavailable; rotation is produced by pre-rendering quantized frames of the
/// template glyph. The timer only runs while an animation is active.
@MainActor
final class MenuBarIconAnimator {
    private enum Phase {
        case idle
        case spinning
        case coasting
        case blinking
    }

    /// Called whenever the animation fully stops so the owner can restore the
    /// authoritative icon for the current mode.
    var onFinish: (() -> Void)?

    private weak var button: NSButton?
    private var timer: Timer?
    private var phase: Phase = .idle
    private var style = MenuBarIconStyle.defaultStyle
    private var isManual = false
    private var angle = 0.0
    private var angularVelocity = 0.0
    private var targetVelocity = 0.0
    private var lastTick = Date()
    private var blinkAccumulator = 0.0
    private var blinkRemaining = 0
    private var frameCache: [String: NSImage] = [:]
    private var trigger = SpinTrigger()
    private var lastRPM = 0.0
    private var burstEndsAt = Date.distantPast

    /// How long a burst spins at full speed before coasting to rest.
    static let burstDuration: TimeInterval = 3
    /// Lowest speed for a switch acknowledgement, so it reads as motion even
    /// when the fans are slow or stopped.
    private static let minimumBurstVelocity = 0.18 * 360

    private let frameQuantum = 15.0 // 24 cached frames per full turn
    private let blinkInterval = 0.12
    /// Degrees per second squared used when the fans stop, so the icon slows
    /// down like a rotor spinning down instead of freezing in place.
    private let spinDownDeceleration = 260.0
    /// Readings arrive every two seconds; smoothing avoids velocity jumps.
    private let velocitySmoothing = 4.0

    var isAnimating: Bool {
        phase != .idle
    }

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Records the live fan reading. The icon stays still unless the reading
    /// moved noticeably since the last burst; then it spins for a few seconds
    /// at the matching speed and coasts to rest. Called on every controller
    /// change, usually with an unchanged reading.
    func update(rpm: Double, on button: NSButton, style: MenuBarIconStyle, isManual: Bool) {
        self.button = button
        if self.style != style || self.isManual != isManual {
            self.style = style
            self.isManual = isManual
            frameCache.removeAll()
        }
        lastRPM = rpm
        let isNotableChange = trigger.registerReading(rpm)

        guard !reduceMotion else {
            if phase != .idle { stop() }
            return
        }

        let target = Self.perceptualVelocity(forRPM: rpm)
        if isNotableChange {
            startBurst(velocity: target)
        } else if phase == .spinning, target > 0 {
            // Keep the speed honest while a burst is already running.
            targetVelocity = target
        }
    }

    /// Spins briefly to acknowledge a mode switch, then coasts to rest.
    func playSwitchBurst() {
        guard !reduceMotion, button != nil else { return }
        startBurst(velocity: max(Self.perceptualVelocity(forRPM: lastRPM), Self.minimumBurstVelocity))
    }

    /// Starts or extends a burst. A running blink keeps the icon until it ends.
    private func startBurst(velocity: Double) {
        guard velocity > 0, phase != .blinking else { return }
        burstEndsAt = Date().addingTimeInterval(Self.burstDuration)
        targetVelocity = velocity
        if phase == .idle {
            angularVelocity = velocity * 0.35 // gentle spin-up from rest
            lastTick = Date()
        }
        phase = .spinning
        startTimerIfNeeded()
    }

    /// Flashes the icon to signal a failed switch, then restores the state
    /// that matches the live fan readings.
    func flashFailure() {
        guard !reduceMotion else { return }
        phase = .blinking
        blinkAccumulator = 0
        blinkRemaining = 4 // two dim/bright cycles
        lastTick = Date()
        startTimerIfNeeded()
    }

    /// Stops immediately and asks the owner to restore the authoritative icon.
    func stop() {
        guard phase != .idle else { return }
        phase = .idle
        timer?.invalidate()
        timer = nil
        onFinish?()
    }

    private func startTimerIfNeeded() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        guard let button else {
            stop()
            return
        }
        let now = Date()
        // Clamp delayed frames so a busy run loop cannot cause a visible jump.
        let delta = min(max(now.timeIntervalSince(lastTick), 0), 0.1)
        lastTick = now

        switch phase {
        case .idle:
            break
        case .spinning:
            if reduceMotion {
                stop()
                return
            }
            if now >= burstEndsAt {
                phase = .coasting
            }
            let smoothing = min(delta * velocitySmoothing, 1)
            angularVelocity += (targetVelocity - angularVelocity) * smoothing
            angle = (angle + angularVelocity * delta).truncatingRemainder(dividingBy: 360)
            show(frame(at: angle, alpha: 1), on: button)
        case .coasting:
            angularVelocity = max(angularVelocity - spinDownDeceleration * delta, 0)
            guard angularVelocity > 0 else {
                stop()
                return
            }
            angle = (angle + angularVelocity * delta).truncatingRemainder(dividingBy: 360)
            show(frame(at: angle, alpha: 1), on: button)
        case .blinking:
            blinkAccumulator += delta
            guard blinkAccumulator >= blinkInterval else { return }
            blinkAccumulator = 0
            blinkRemaining -= 1
            guard blinkRemaining > 0 else {
                stop()
                return
            }
            let dimmed = blinkRemaining % 2 == 1
            show(frame(at: 0, alpha: dimmed ? 0.3 : 1), on: button)
        }
    }

    /// Frames are quantized, so most ticks resolve to the image already shown.
    /// Every assignment makes AppKit re-snapshot the status item for each
    /// menu bar replicant, so only swap when the frame actually changes.
    private func show(_ image: NSImage, on button: NSButton) {
        guard button.image !== image else { return }
        button.image = image
    }

    /// Real fan RPM is too fast to render directly without aliasing. Reuses
    /// the perceptual scale from FanRotorView so the menu bar and the panel
    /// rotor feel like the same machine.
    private static func perceptualVelocity(forRPM rpm: Double) -> Double {
        guard rpm > 1 else { return 0 }
        return min(max(rpm / 5_000, 0.18), 1.15) * 360
    }

    /// Returns the un-rotated, full-opacity icon image — intended for the
    /// static status bar item when the animator is idle. Shares the same
    /// rendering path as the animated frames so the sizes are pixel-identical.
    static func staticIcon(style: MenuBarIconStyle, isManual: Bool) -> NSImage {
        style.image(isManual: isManual)
    }

    // MARK: - Render

    /// Returns a cached template frame for the quantized angle and alpha.
    private func frame(at angle: Double, alpha: CGFloat) -> NSImage {
        let quantized = (angle / frameQuantum).rounded() * frameQuantum
        let key = "\(Int(quantized))-\(Int(alpha * 100))"
        if let cached = frameCache[key] { return cached }
        let rendered = style.image(isManual: isManual, degrees: quantized, alpha: alpha)
        frameCache[key] = rendered
        return rendered
    }
}

/// Decides when a fan reading differs enough from the last burst to spin again.
struct SpinTrigger {
    /// Smaller changes are sensor noise or slow drift, not news.
    static let absoluteThreshold = 250.0
    static let relativeThreshold = 0.15

    private(set) var referenceRPM: Double?

    /// The first reading only sets the baseline, so launching FanBar does not
    /// spin the icon. The baseline moves only when a burst fires, so slow drift
    /// still triggers once it adds up.
    mutating func registerReading(_ rpm: Double) -> Bool {
        guard let reference = referenceRPM else {
            referenceRPM = rpm
            return false
        }
        let threshold = max(Self.absoluteThreshold, reference * Self.relativeThreshold)
        guard abs(rpm - reference) >= threshold else { return false }
        referenceRPM = rpm
        return true
    }
}
