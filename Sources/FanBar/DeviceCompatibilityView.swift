import AppKit
import FanBarShared
import SwiftUI
import UniformTypeIdentifiers

/// Shared by settings, onboarding and attention states. Closing returns to its source.
struct DeviceCompatibilityView: View {
    @ObservedObject var controller: FanController
    @Environment(\.presentationMode) private var presentationMode
    @State private var reportData: Data?
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
        .sheet(isPresented: Binding(
            get: { reportData != nil },
            set: { if !$0 { reportData = nil } }
        )) {
            if let data = reportData { CompatibilityReportPreview(data: data) }
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
                        fanBarText("检测在本机完成，设备信息未上传。", "Checked on this Mac. Device information has not been uploaded."),
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
                    reportData = try CompatibilityReport(snapshot: snapshot).jsonData()
                    reportError = nil
                } catch {
                    reportError = fanBarText("无法生成报告，请重试。", "Unable to create the report. Please retry.")
                }
            }
            .buttonStyle(.plain).foregroundColor(.accentColor)
            Text(fanBarText("可保存本地报告；此版本不提供上传。", "Save a local report. Upload is not available in this version."))
                .font(.caption).foregroundColor(.secondary)
            if let reportError { Text(reportError).font(.caption).foregroundColor(.orange) }
        }
    }
}

struct CompatibilityReportPreview: View {
    let data: Data
    @Environment(\.presentationMode) private var presentationMode
    @State private var saveError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(fanBarText("兼容性报告预览", "Compatibility Report Preview")).font(.headline)
            Text(fanBarText(
                "仅包含机型、处理器、系统与软件版本、能力状态和随机报告编号。不包含序列号、设备唯一标识、用户名、文件路径、进程列表或温度历史。",
                "Only model, processor, versions, capability states and report ID. No personal identifiers, logs or temperature history."
            ))
            .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            ScrollView {
                Text(String(data: data, encoding: .utf8) ?? "")
                    .font(.system(size: 11, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
            }
            .frame(height: 240).background(Color(NSColor.textBackgroundColor)).cornerRadius(8)
            Text(fanBarText(
                "保存不会上传。自行分享文件时，接收方可以看到以上内容。",
                "Saving does not upload. If you share the file, the recipient can see these contents."
            ))
                .font(.caption).foregroundColor(.secondary)
            if let saveError { Text(saveError).font(.caption).foregroundColor(.orange) }
            HStack {
                Button(fanBarText("取消", "Cancel")) { presentationMode.wrappedValue.dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(fanBarText("保存到本地…", "Save locally…"), action: saveLocally)
            }
        }
        .padding(24).frame(width: 510)
    }

    private func saveLocally() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "FanBar-compatibility.json"
        panel.allowedContentTypes = [.json]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url, options: .atomic)
                presentationMode.wrappedValue.dismiss()
            } catch {
                saveError = fanBarText("无法保存报告，请选择其他位置后重试。", "Unable to save. Choose another location and retry.")
            }
        }
    }
}
