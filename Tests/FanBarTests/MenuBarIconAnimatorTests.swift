import AppKit
import XCTest
@testable import FanBar

@MainActor
final class MenuBarIconAnimatorTests: XCTestCase {
    /// Reduce Motion is fixed off so the host's accessibility settings,
    /// such as a CI runner's, cannot skip these tests.
    private func makeAnimator(reduceMotion: Bool = false) -> (MenuBarIconAnimator, NSButton) {
        (MenuBarIconAnimator(reduceMotion: { reduceMotion }), NSButton())
    }

    private func runMainLoop(for seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    /// Regression: a steady reading used to spin only for a short burst and
    /// then leave the icon still while the fans kept running.
    func testSteadyRunningFansKeepSpinningPastBurst() {
        let (animator, button) = makeAnimator()
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

    func testFirstRunningReadingStartsSpinning() {
        let (animator, button) = makeAnimator()
        animator.update(rpm: 1_850, on: button, style: .defaultStyle, isManual: false)
        XCTAssertTrue(animator.isAnimating)
        animator.stop()
    }

    func testStoppedFansStayStill() {
        let (animator, button) = makeAnimator()
        animator.update(rpm: 0, on: button, style: .defaultStyle, isManual: false)
        XCTAssertFalse(animator.isAnimating)
    }

    func testStoppingFansCoastToRestAndRunningFansResume() {
        let (animator, button) = makeAnimator()
        animator.update(rpm: 1_850, on: button, style: .defaultStyle, isManual: false)
        animator.update(rpm: 0, on: button, style: .defaultStyle, isManual: false)
        runMainLoop(for: 2)
        XCTAssertFalse(animator.isAnimating)

        animator.update(rpm: 1_850, on: button, style: .defaultStyle, isManual: false)
        XCTAssertTrue(animator.isAnimating)
        animator.stop()
    }

    func testReduceMotionKeepsRunningFansStill() {
        let (animator, button) = makeAnimator(reduceMotion: true)
        animator.update(rpm: 1_850, on: button, style: .defaultStyle, isManual: false)
        XCTAssertFalse(animator.isAnimating)
        animator.playSwitchBurst()
        XCTAssertFalse(animator.isAnimating)
    }

    /// A switch spins the icon even with the fans stopped, then it coasts
    /// to rest once the burst ends.
    func testSwitchBurstWithStoppedFansCoastsToRest() {
        let (animator, button) = makeAnimator()
        animator.update(rpm: 0, on: button, style: .defaultStyle, isManual: false)
        animator.playSwitchBurst()
        XCTAssertTrue(animator.isAnimating)
        runMainLoop(for: MenuBarIconAnimator.burstDuration + 1.5)
        XCTAssertFalse(animator.isAnimating)
    }
}
