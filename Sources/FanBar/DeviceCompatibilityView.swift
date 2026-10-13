import AppKit
import FanBarShared
import SwiftUI

/// Shared by settings, onboarding and attention states. Closing returns to its source.
struct DeviceCompatibilityView: View {
    @ObservedObject var controller: FanController
    @Environment(\.presentationMode) private var presentationMode
    @State private var presentation: CompatibilityPresentation?
    @State private var reportError: String?
    private let catalog = CompatibilityCatalog.load()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(fanBarText("设备兼容性", "Device Compatibility"))
                    .font(.headline)
                Spacer()
                Button(fanBarText("完成", "Done")) { presentationMode.wrappedValue.dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: SettingsChrome.sectionSpacing) {
                    if let snapshot = controller.compatibilitySnapshot {
                        summary(snapshot)
                        capabilities(snapshot)
                        helperAction
                        records(snapshot)
                        reportAction(snapshot)
                    } else {
                        Text(fanBarText("尚未检测。", "Not yet checked."))
                        Button(fanBarText("开始检测", "Check now"), action: controller.detectCompatibility)
                    }
                }
                .padding(24)
            }
        }
        .frame(width: SettingsChrome.contentWidth, height: 570)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear { controller.detectCompatibility() }
        .sheet(item: $presentation) { item in
            switch item {
            case .report(let data): CompatibilityReportPreview(data: data)
            case .receipts: CompatibilityReceiptsView()
            }
        }
    }

    private func summary(_ snapshot: CompatibilitySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Text(snapshot.summary).font(.system(size: 18, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 16)
                Button(fanBarText("重新检测", "Check again"), action: controller.detectCompatibility)
            }
            SettingsChrome.settingsCard {
                VStack(alignment: .leading, spacing: 5) {
                    Text(snapshot.device.modelIdentifier).font(.headline)
                    Text(snapshot.device.processor).foregroundColor(.secondary)
                    Text("macOS \(snapshot.device.macOSVersion) · FanBar \(snapshot.device.appVersion)")
                        .font(.caption).foregroundColor(.secondary)
                    Label(
                        fanBarText("检测在本机完成，不会自动上传设备信息。", "Checks run locally. Device information is not automatically uploaded."),
                        systemImage: "checkmark.shield"
                    )
                    .font(.caption).foregroundColor(.secondary).padding(.top, 5)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func capabilities(_ snapshot: CompatibilitySnapshot) -> some View {
        SettingsSection(
            title: fanBarText("当前可用能力", "Current Capabilities"),
            footer: fanBarText(
                "缺少读数或一次失败不代表机型不支持。检测只读，不会改变风扇转速。控制请求结果仅来自本次运行。",
                "Missing readings do not establish incompatibility. Checks are read-only; control evidence is session-only."
            )
        ) {
            ForEach(snapshot.results) { result in
                if result.id != snapshot.results.first?.id { SettingsChrome.rowDivider }
                HStack(alignment: .top, spacing: 16) {
                    SettingsRowText(title: result.capability.title, detail: result.detail)
                    Spacer(minLength: 8)
                    Label(result.status.title, systemImage: result.status.symbol)
                        .font(.caption).foregroundColor(result.status.tint)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .settingsRow()
                .accessibilityElement(children: .combine)
            }
            SettingsChrome.rowDivider
            HStack {
                Text(fanBarText("温度来源", "Temperature source")).foregroundColor(.secondary)
                Spacer()
                Text(snapshot.curveSensor.title).foregroundColor(.secondary)
            }
            .font(.caption).settingsRow()
            SettingsChrome.rowDivider
            HStack {
                Text(fanBarText("最近检测", "Last checked")).foregroundColor(.secondary)
                Spacer()
                Text(snapshot.checkedAt, style: .time).monospacedDigit().foregroundColor(.secondary)
            }
            .font(.caption).settingsRow()
        }
    }

    @ViewBuilder
    private var helperAction: some View {
        if controller.helperState != .enabled {
            SettingsChrome.settingsCard {
                HStack(spacing: 12) {
                    Image(systemName: controller.helperState.symbolName).foregroundColor(controller.helperState.tint)
                    SettingsRowText(title: controller.helperState.noticeTitle, detail: controller.helperState.noticeDetail)
                    Spacer()
                    if let title = controller.helperState.actionTitle {
                        Button(title, action: controller.performHelperAction)
                    }
                }
                .settingsRow()
            }
        }
    }

    private func records(_ snapshot: CompatibilitySnapshot) -> some View {
        let matching = catalog.matching(snapshot.device)
        return SettingsSection(
            title: fanBarText("已验证机型记录", "Verified Model Records"),
            footer: fanBarText("列表随应用提供，在本机匹配，不发送机型查询。", "The catalog ships with the app and is matched locally.")
        ) {
            if matching.isEmpty {
                SettingsRowText(
                    title: fanBarText("此版本组合暂无已验证记录", "No verified record for this version combination"),
                    detail: fanBarText("没有记录不代表不支持，请参考本机检测结果。", "No record does not mean unsupported. Refer to this Mac’s results.")
                ).settingsRow()
            } else {
                ForEach(Array(matching.enumerated()), id: \.offset) { _, record in
                    SettingsRowText(title: record.notes, detail: "\(record.source) · \(record.verifiedOn)").settingsRow()
                }
            }
        }
    }

    private func reportAction(_ snapshot: CompatibilitySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(fanBarText("预览兼容性报告…", "Preview compatibility report…")) {
                do {
                    presentation = .report(try CompatibilityReport(snapshot: snapshot).jsonData())
                    reportError = nil
                } catch {
                    reportError = fanBarText("无法生成报告，请重试。", "Unable to create the report. Please retry.")
                }
            }
            .buttonStyle(.plain).foregroundColor(.accentColor)
            Text(fanBarText("发送前可预览全部内容；不上报也可正常使用。", "Preview all contents before sending. Reporting is optional."))
                .font(.caption).foregroundColor(.secondary)
            Button(fanBarText("上报记录与撤回…", "Submitted reports and withdrawal…")) {
                presentation = .receipts
            }
            .buttonStyle(.plain).foregroundColor(.accentColor)
            if let configuration = CompatibilityServiceConfiguration.current {
                Link(fanBarText("查看公开兼容性记录", "View public compatibility records"), destination: configuration.baseURL)
                    .font(.caption)
            }
            if let reportError { Text(reportError).font(.caption).foregroundColor(.orange) }
        }
    }
}

private enum CompatibilityPresentation: Identifiable {
    case report(Data)
    case receipts
    var id: String {
        switch self {
        case .report: "report"
        case .receipts: "receipts"
        }
    }
}
