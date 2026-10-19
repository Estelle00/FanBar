import AppKit

/// Keeps the status-item icon rotating while the physical fans are running.
///
/// The controller calls `update(rpm:on:style:isManual:)` with the average RPM on
/// every change; the icon spins at a perceptual speed mapped from that reading
/// and coasts to a stop once the fans halt. A mode switch spins it briefly
/// even when the fans are stopped, and a failed switch flashes it via
/// `flashFailure()`.
///
/// Every frame swap makes AppKit re-snapshot the status item for each
/// display's menu bar, so frames are quantized and only swapped on change.
/// Swaps dominate the cost: on a Mac mini M4 with two displays, a 30 Hz
/// timer and 15° frames cost about 6% CPU while spinning, a 10 Hz timer and
/// 30° frames about 3%, against 1.6% with the icon still. Rotating a layer
/// with Core Animation is nearly free but only animates the main display's
/// menu bar; the others keep a still snapshot.
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
    private var lastRPM = 0.0
    private var burstEndsAt = Date.distantPast

    /// How long a switch burst spins before coasting to rest when the fans
    /// themselves are stopped.
    static let burstDuration: TimeInterval = 3
    /// Lowest speed for a switch acknowledgement, so it reads as motion even
    /// when the fans are slow or stopped.
    private static let minimumBurstVelocity = 0.18 * 360

    private let frameQuantum = 30.0 // 12 cached frames per full turn
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

    /// Follows the live fan reading: spins while the fans run, coasts to a
    /// stop when they halt. Called on every controller change, usually with an
    /// unchanged reading.
    func update(rpm: Double, on button: NSButton, style: MenuBarIconStyle, isManual: Bool) {
        self.button = button
        if self.style != style || self.isManual != isManual {
            self.style = style
            self.isManual = isManual
            frameCache.removeAll()
        }
        lastRPM = rpm

        guard !reduceMotion else {
            if phase != .idle { stop() }
            return
        }

        // Running fans keep the icon spinning (and revive a coast) for as long
        // as they run. Stopped fans let `tick` coast once any burst has ended.
        let target = Self.perceptualVelocity(forRPM: rpm)
        guard target > 0, phase != .blinking else { return }
        targetVelocity = target
        if phase == .idle {
            angularVelocity = target * 0.35 // gentle spin-up from rest
            lastTick = Date()
        }
        phase = .spinning
        startTimerIfNeeded()
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
        let timer = Timer(timeInterval: 1.0 / 10.0, repeats: true) { [weak self] _ in
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
        // Clamp delayed frames so a busy run loop cannot cause a visible jump;
        // the bound sits above the 10 Hz tick so on-time frames are not slowed.
        let delta = min(max(now.timeIntervalSince(lastTick), 0), 0.25)
        lastTick = now

        switch phase {
        case .idle:
            break
        case .spinning:
            if reduceMotion {
                stop()
                return
            }
            if now >= burstEndsAt, Self.perceptualVelocity(forRPM: lastRPM) <= 0 {
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
