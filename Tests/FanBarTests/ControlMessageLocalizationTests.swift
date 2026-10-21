import FanBarShared
import XCTest
@testable import FanBar

private struct LocalizedControlTestError: LocalizedError {
    var errorDescription: String? {
        fanBarText("控制服务更新失败，请重新打开 FanBar", "Control service update failed; reopen FanBar")
    }
}

@MainActor
final class ControlMessageLocalizationTests: XCTestCase {
    func testRejectedOperationUpdatesBothFeedbackAndStatusWithoutRepeatingIt() throws {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: FanBarLanguage.preferenceKey)
        defer { defaults.set(saved, forKey: FanBarLanguage.preferenceKey) }
        defaults.set(FanBarLanguage.french.rawValue, forKey: FanBarLanguage.preferenceKey)
        let source = FakeFanReadingSource()
        let controller = FanController(notificationCenter: nil, widgetSnapshotDestination: .disabled,
                                       makeReadingSource: { source }, readUsage: { SystemUsage() }, refreshInterval: nil)
        // Rejected before any helper request, so this never adjusts real fans.
        controller.setCustomFixedRPM(-1)
        let feedback = try XCTUnwrap(controller.modeActionFeedback)
        let french = feedback.message
        for language in [FanBarLanguage.japanese, .english, .chinese, .traditionalChinese, .russian, .french] {
            defaults.set(language.rawValue, forKey: FanBarLanguage.preferenceKey)
            let expected = fanBarText("转速超出风扇支持的范围", "That RPM is outside the fans' supported range")
            XCTAssertEqual(feedback.message, expected)
            XCTAssertEqual(controller.message, expected)
            XCTAssertEqual(controller.modeActionFeedback?.kind, .failure)
            XCTAssertEqual(controller.mode, .automatic)
            XCTAssertFalse(controller.isBusy)
            if language != .french { XCTAssertNotEqual(feedback.message, french) }
        }
    }

    func testFormattedProgressKeepsTheOriginalOperationValues() {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: FanBarLanguage.preferenceKey)
        defer { defaults.set(saved, forKey: FanBarLanguage.preferenceKey) }
        defaults.set(FanBarLanguage.french.rawValue, forKey: FanBarLanguage.preferenceKey)
        let target = 3456
        let feedback = FanController.ModeActionFeedback(kind: .inProgress, localizedMessage: LocalizedControlText {
            fanBarFormat("正在切换到 %d RPM…", "Switching to %d RPM…", target)
        })
        for language in [FanBarLanguage.japanese, .english, .chinese, .traditionalChinese, .russian, .french] {
            defaults.set(language.rawValue, forKey: FanBarLanguage.preferenceKey)
            XCTAssertEqual(feedback.message, fanBarFormat("正在切换到 %d RPM…", "Switching to %d RPM…", target))
            XCTAssertEqual(feedback.kind, .inProgress)
            XCTAssertFalse(feedback.offersHelperSettings)
        }
    }

    func testCompatibilityResultRetranslatesBothSummaryAndErrorDetail() {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: FanBarLanguage.preferenceKey)
        defer { defaults.set(saved, forKey: FanBarLanguage.preferenceKey) }
        defaults.set(FanBarLanguage.french.rawValue, forKey: FanBarLanguage.preferenceKey)
        var result = CompatibilityControlTestResult(restored: false)
        result.restoreFailure = LocalizedControlTestError()
        result.restoreError = result.restoreFailure?.localizedDescription
        let cached = LocalizedControlText { [result] in FanController.compatibilityControlMessage(for: result) }
        let french = cached.text
        for language in [FanBarLanguage.japanese, .english, .chinese, .traditionalChinese, .russian, .french] {
            defaults.set(language.rawValue, forKey: FanBarLanguage.preferenceKey)
            XCTAssertEqual(cached.text, fanBarFormat(
                "恢复系统控制失败：%@。请点击“恢复系统控制”重试。",
                "Restoring system control failed: %@. Retry Restore System Control.",
                LocalizedControlTestError().localizedDescription
            ))
            if language != .french { XCTAssertNotEqual(cached.text, french) }
        }
    }
}
