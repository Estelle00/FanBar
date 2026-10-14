// Localization keys and user-facing paragraphs remain intact for catalog extraction.
// swiftlint:disable line_length
import AppKit
import FanBarShared
import SwiftUI

@MainActor
struct DiagnosticUploadView: View {
    @ObservedObject var controller: FanController
    @Environment(\.presentationMode) private var presentationMode
    @State private var report: DiagnosticReport?
    @State private var policy: DiagnosticPolicy?
    @State private var receipt: CompatibilitySavedReceipt?
    @State private var history: [CompatibilitySavedReceipt] = []
    @State private var consent = false
    @State private var busy = false
    @State private var error: String?
    private let store = CompatibilityReceiptStore(service: "local.fanbar.diagnostics.receipts")

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(fanBarText("上传诊断日志", "Upload diagnostic logs")).font(.title2.weight(.semibold))
                Text(fanBarText("帮助排查温度缺失和传感器读取问题。收集过程只读取信息，不会调整风扇。",
                    "Help investigate missing temperatures and sensor failures. Collection only reads information and does not adjust fans."))
                    .font(.subheadline).foregroundColor(.secondary)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let report {
                        SettingsChrome.settingsCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(report.device.displayName).font(.headline)
                                Text("\(report.device.modelIdentifier) · macOS \(report.device.macOSVersion)")
                                Text("FanBar \(report.device.appVersion) · Helper \(report.device.helperVersion)")
                                Text(fanBarText("包含：设备版本、最近一分钟采样、传感器探测、数据格式与原始字节、备用来源结果和错误码。",
                                    "Includes device versions, recent samples (up to one minute), sensor probes, data formats and raw bytes, fallback results, and error codes."))
                                Text(fanBarText("不包含：序列号、用户名、文件路径、进程列表或系统日志。",
                                    "Excludes serial numbers, usernames, file paths, process lists, and system logs."))
                                    .foregroundColor(.secondary)
                            }.font(.caption).padding(16)
                        }
                        Text(fanBarText("还包含最近 24 小时内有界保留的启动、授权、XPC 与控制事件，以及脱敏崩溃摘要。确认上传前，文件仅保存在本机。",
                            "Also includes bounded launch, approval, XPC, and control events from the last 24 hours and sanitized crash summaries. Files stay local until you confirm upload."))
                            .font(.caption).foregroundColor(.secondary)
                        Text(fanBarText("FanBar 无法打开时，可运行附带的 FanBar-Diagnostics.command，无需启动应用即可导出诊断。",
                            "If FanBar cannot open, run the supplied FanBar-Diagnostics.command to export diagnostics without starting the app."))
                            .font(.caption).foregroundColor(.secondary)
                        DisclosureGroup(fanBarText("查看日志详情", "View log details")) {
                            Text((try? report.jsonData()).flatMap { String(data: $0, encoding: .utf8) } ?? "")
                                .font(.system(size: 10, design: .monospaced)).textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                        }.font(.caption)
                    } else {
                        ProgressView(fanBarText("正在收集诊断信息…", "Collecting diagnostics…"))
                    }
                    if let response = receipt?.response {
                        Text(fanBarText("上传成功，请将诊断编号提供给开发者。", "Uploaded. Share the diagnostic ID with the developer.")).font(.headline)
                        Text(response.reportID).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                        Button(fanBarText("复制诊断编号", "Copy diagnostic ID")) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(response.reportID, forType: .string)
                        }
                    } else {
                        Text(fanBarText("日志仅管理员可见，不会公开或计入兼容性统计；在线保留 90 天，可在下方撤回。",
                            "Logs are visible only to administrators, excluded from public compatibility statistics, and retained online for 90 days. Withdraw them below."))
                            .font(.caption).foregroundColor(.secondary)
                        Text(fanBarText("云平台历史恢复点最长还可能保留 30 天；Cloudflare 会处理传输所需的网络元数据。",
                            "Cloud restore points may retain data for up to 30 more days. Cloudflare processes network metadata to deliver the service."))
                            .font(.caption).foregroundColor(.secondary)
                        if let configuration = CompatibilityServiceConfiguration.current {
                            Link(fanBarText("收集与处理规则", "Collection and processing rules"),
                                destination: configuration.url(path: "privacy.html"))
                                .font(.caption)
                        }
                        Toggle(fanBarText("我同意上传本次诊断日志供排查问题",
                            "I agree to upload these diagnostic logs for troubleshooting"),
                            isOn: $consent)
                            .font(.caption).disabled(busy)
                        if policy == nil {
                            Button(fanBarText("获取上传规则", "Fetch upload rules")) { Task { await loadPolicy() } }.disabled(busy)
                        }
                    }
                    if !history.isEmpty {
                        DisclosureGroup(fanBarText("诊断上传记录与撤回", "Diagnostic history and withdrawal")) {
                            ForEach(history) { item in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.reportID).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                                    HStack {
                                        Text(item.createdAt, style: .date).font(.caption).foregroundColor(.secondary)
                                        Spacer()
                                        if item.response == nil {
                                            Button(fanBarText("重试上传", "Retry upload")) { Task { await send(item) } }
                                        }
                                        Button(fanBarText("撤回", "Withdraw")) { Task { await withdraw(item) } }
                                    }
                                }.padding(.vertical, 8)
                            }
                        }.font(.caption).disabled(busy)
                    }
                    if let error { Text(error).font(.caption).foregroundColor(.orange) }
                }
            }
            Divider()
            HStack {
                Button(fanBarText("导出日志…", "Export logs…"), action: export).disabled(report == nil || busy)
                Spacer()
                Button(fanBarText("关闭", "Close")) { presentationMode.wrappedValue.dismiss() }
                    .keyboardShortcut(.cancelAction).disabled(busy)
                if receipt?.response == nil {
                    Button(busy ? fanBarText("正在上传…", "Uploading…") : fanBarText("确认上传", "Confirm upload")) {
                        Task { await submit() }
                    }.disabled(!consent || report == nil || policy == nil || busy)
                }
            }
        }
        .padding(24).frame(width: 560, height: 600)
        .interactiveDismissDisabled(busy)
        .task {
            // Yield once so the collection state can render before hardware probes.
            await Task.yield()
            report = controller.collectDiagnosticReport()
            do { history = try store.receipts() } catch { self.error = CompatibilityServiceError.credentialStorage.message }
            await loadPolicy()
        }
    }

    private func service(for url: URL? = nil) throws -> CompatibilityReportService {
        if let url {
            guard let configuration = CompatibilityServiceConfiguration(url: url) else { throw CompatibilityServiceError.notConfigured }
            return CompatibilityReportService(configuration: configuration)
        }
        guard let configuration = CompatibilityServiceConfiguration.current else { throw CompatibilityServiceError.notConfigured }
        return CompatibilityReportService(configuration: configuration)
    }

    private func loadPolicy() async {
        do { policy = try await service().diagnosticPolicy(); error = nil } catch { self.error = (error as? CompatibilityServiceError ?? .network).message }
    }

    private func submit() async {
        guard consent, policy != nil, let report else { return }
        do {
            if receipt == nil {
                let client = try service()
                let pending = CompatibilitySavedReceipt(reportID: report.diagnosticID, serviceURL: client.configuration.baseURL,
                    deletionToken: try CompatibilitySavedReceipt.makeToken(), reportData: try report.jsonData(),
                    publishReport: false, policyVersion: DiagnosticPolicy.supportedVersion, createdAt: Date())
                try store.save(pending) // Persist the retry/deletion credential before any network write.
                receipt = pending
                history = try store.receipts()
            }
            if let receipt { await send(receipt) }
        } catch { self.error = (error as? CompatibilityServiceError ?? .invalidReport).message }
    }

    private func send(_ item: CompatibilitySavedReceipt) async {
        busy = true
        defer { busy = false }
        do {
            let client = try service(for: item.serviceURL)
            _ = try await client.diagnosticPolicy()
            var updated = item
            updated.response = try await client.submitDiagnostic(item)
            try store.save(updated)
            if receipt?.reportID == item.reportID { receipt = updated }
            history = try store.receipts()
            error = nil
        } catch { self.error = (error as? CompatibilityServiceError ?? .network).message }
    }

    private func withdraw(_ item: CompatibilitySavedReceipt) async {
        busy = true
        defer { busy = false }
        do {
            try await service(for: item.serviceURL).withdrawDiagnostic(item)
            try store.remove(reportID: item.reportID)
            history = try store.receipts()
            // Never reuse a withdrawn ID, including requests that timed out before withdrawal.
            if receipt?.reportID == item.reportID {
                receipt = nil
                report = controller.collectDiagnosticReport()
                consent = false
            }
            error = nil
        } catch { self.error = (error as? CompatibilityServiceError ?? .network).message }
    }

    private func export() {
        guard let report, let data = try? report.jsonData() else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "FanBar-diagnostics-\(report.diagnosticID).json"
        panel.allowedContentTypes = [.json]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do { try data.write(to: url, options: .atomic) } catch { self.error = fanBarText("无法保存报告，请选择其他位置后重试。",
                "Unable to save. Choose another location and retry.") }
        }
    }
}

// swiftlint:enable line_length
