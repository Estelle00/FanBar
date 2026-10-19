import AppKit
import XCTest
@testable import FanBar

@MainActor
final class MenuBarIconAnimatorTests: XCTestCase {
    private func makeAnimator() throws -> (MenuBarIconAnimator, NSButton) {
        try XCTSkipIf(
            NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
            "Reduce Motion keeps the icon still"
        )
        return (MenuBarIconAnimator(), NSButton())
    }

    private func runMainLoop(for seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    /// Regression: a steady reading used to spin only for a short burst and
    /// then leave the icon still while the fans kept running.
    func testSteadyRunningFansKeepSpinningPastBurst() throws {
        let (animator, button) = try makeAnimator()
        let wait = MenuBarIconAnimator.burstDuration + 1.5
        var elapsed = 0.0
        while elapsed < wait {
            animator.update(rpm: 1_850, on: button, style: .defaultStyle, isManual: false)
            runMainLoop(for: 0.5)
            elapsed += 0.5
        }
        XCTAssertTrue(animator.isAnimating)
        animator.stop()
    }

    func testFirstRunningReadingStartsSpinning() throws {
        let (animator, button) = try makeAnimator()
        animator.update(rpm: 1_850, on: button, style: .defaultStyle, isManual: false)
        XCTAssertTrue(animator.isAnimating)
        animator.stop()
    }

    func testStoppedFansStayStill() throws {
        let (animator, button) = try makeAnimator()
        animator.update(rpm: 0, on: button, style: .defaultStyle, isManual: false)
        XCTAssertFalse(animator.isAnimating)
    }

    func testStoppingFansCoastToRestAndRunningFansResume() throws {
        let (animator, button) = try makeAnimator()
        animator.update(rpm: 1_850, on: button, style: .defaultStyle, isManual: false)
        animator.update(rpm: 0, on: button, style: .defaultStyle, isManual: false)
        runMainLoop(for: 2)
        XCTAssertFalse(animator.isAnimating)

        animator.update(rpm: 1_850, on: button, style: .defaultStyle, isManual: false)
        XCTAssertTrue(animator.isAnimating)
        animator.stop()
    }
}
