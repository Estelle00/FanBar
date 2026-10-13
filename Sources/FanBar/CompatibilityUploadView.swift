import AppKit
import FanBarShared
import SwiftUI
import UniformTypeIdentifiers

extension CompatibilityServiceError {
    var message: String {
        switch self {
        case .notConfigured: fanBarText("上报服务尚未配置，可先保存本地报告。", "Reporting is not configured. You can save a local report.")
        case .invalidReport: fanBarText("报告内容无效，请重新检测并生成报告。", "Invalid report. Check this Mac again and create a new report.")
        case .consentRequired: fanBarText("请先确认本次提交。", "Confirm this submission first.")
        case .credentialStorage: fanBarText("无法保存撤回凭证，请检查钥匙串后重试。", "Unable to save the withdrawal credential. Check Keychain and retry.")
        case .policyChanged: fanBarText("服务规则已变化，请更新 FanBar 后再上报。", "Service rules changed. Update FanBar before reporting.")
        case .rateLimited: fanBarText("提交过于频繁，请稍后重试。", "Too many submissions. Please retry later.")
        case .reportConflict: fanBarText("报告编号或提交内容冲突，请生成新报告。", "Report ID or content conflicts. Create a new report.")
        case .network: fanBarText(
            "无法连接服务。提交超时时，报告可能已收到；重试不会重复计数。",
            "Connection failed. A timed-out report may have arrived; retrying does not count it twice."
        )
        case .server: fanBarText("服务暂时无法处理请求，请稍后重试。", "The service cannot process this request right now. Retry later.")
        }
    }
}

struct CompatibilityReportPreview: View {
    let data: Data
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var upload: CompatibilityUploadCoordinator
    @State private var saveError: String?
    @State private var consent = false
    @State private var publishReport = false

    init(data: Data, coordinator: CompatibilityUploadCoordinator? = nil) {
        self.data = data
        _upload = StateObject(wrappedValue: coordinator ?? CompatibilityUploadCoordinator(data: data))
        _publishReport = State(initialValue: coordinator?.receipt?.publishReport ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(fanBarText("兼容性报告预览", "Compatibility Report Preview"))
                .font(.headline).padding(.bottom, 16)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(fanBarText(
                        "仅包含机型、处理器、系统与软件版本、能力状态和随机报告编号。不包含序列号、设备唯一标识、用户名、文件路径、进程列表或温度历史。",
                        "Only model, chip, versions, capability states and report ID. No personal identifiers, logs or temperatures."
                    ))
                    .font(.caption).foregroundColor(.secondary)
                    Text(String(data: data, encoding: .utf8) ?? "")
                        .font(.system(size: 11, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                        .background(Color(NSColor.textBackgroundColor)).cornerRadius(8)
                    uploadOptions
                    if let error = upload.error { Text(error.message).font(.caption).foregroundColor(.orange) }
                    if let saveError { Text(saveError).font(.caption).foregroundColor(.orange) }
                }
            }
            Divider().padding(.vertical, 14)
            HStack(spacing: 12) {
                Button(fanBarText("完成", "Done")) { presentationMode.wrappedValue.dismiss() }
                    .keyboardShortcut(.cancelAction).disabled(upload.isSending)
                Spacer()
                Button(fanBarText("保存到本地…", "Save locally…"), action: saveLocally)
                if upload.configuration != nil, upload.receipt?.response == nil {
                    Button(upload.isSending
                        ? fanBarText("正在上报…", "Submitting…")
                        : fanBarText("确认上报", "Confirm submission")) {
                        Task { await upload.submit(consent: consent, publishReport: publishReport) }
                    }
                    .disabled(!consent || upload.policy == nil || upload.isSending)
                }
            }
        }
        .padding(24).frame(width: 510, height: 550)
    }

    @ViewBuilder
    private var uploadOptions: some View {
        if let response = upload.receipt?.response {
            VStack(alignment: .leading, spacing: 5) {
                Label(fanBarText("报告已收到，公开结果以审核状态为准。", "Report received. Publication depends on review."), systemImage: "checkmark.circle")
                    .foregroundColor(.green)
                Text(response.reportID).font(.system(size: 11, design: .monospaced))
                Text(fanBarText(
                    "撤回凭证已保存在本机钥匙串，可在上报记录中撤回。",
                    "The withdrawal credential is in this Mac’s Keychain. Withdraw from submitted reports."
                ))
                    .font(.caption).foregroundColor(.secondary)
            }
        } else if let configuration = upload.configuration {
            VStack(alignment: .leading, spacing: 10) {
                Text(configuration.baseURL.absoluteString).font(.caption).foregroundColor(.secondary)
                if let policy = upload.policy {
                    Text(fanBarText(
                        "报告在线保留 90 天。审核后贡献公开统计；原始报告默认私有。Cloudflare 会处理传输所需的网络元数据。",
                        "90 days online. Reviewed reports feed public counts; raw reports stay private. Cloudflare handles network data."
                    ))
                    .font(.caption).foregroundColor(.secondary)
                    HStack {
                        Link(fanBarText("收集与处理规则", "Collection and processing rules"), destination: configuration.url(path: "privacy.html"))
                        Text(policy.version).foregroundColor(.secondary)
                    }.font(.caption)
                    Toggle(fanBarText("同时公开这份报告，审核后供其他用户查阅", "Also publish this report after review"), isOn: $publishReport)
                        .font(.caption).disabled(upload.isSending || upload.receipt != nil)
                    Text(fanBarText("罕见机型与版本组合可能具有辨识度。", "Rare model and version combinations may be identifiable."))
                        .font(.caption2).foregroundColor(.secondary)
                    Toggle(fanBarText("我同意按以上规则提交本次报告", "I agree to submit this report under these rules"), isOn: $consent)
                        .font(.caption).disabled(upload.isSending)
                } else {
                    Text(fanBarText(
                        "检测和本地保存不联网。准备上报时，只连接服务获取规则，不发送设备信息。",
                        "Detection and local saving stay offline. Preparing submission fetches rules without sending device information."
                    ))
                        .font(.caption).foregroundColor(.secondary)
                    Button(upload.isLoading
                        ? fanBarText("正在获取规则…", "Fetching rules…")
                        : fanBarText("准备上报 · 查看规则", "Prepare submission · review rules")) {
                        Task { await upload.loadPolicy() }
                    }.disabled(upload.isLoading)
                }
            }
        } else {
            Text(CompatibilityServiceError.notConfigured.message).font(.caption).foregroundColor(.secondary)
        }
    }

    private func saveLocally() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "FanBar-compatibility.json"
        panel.allowedContentTypes = [.json]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                saveError = fanBarText("无法保存报告，请选择其他位置后重试。", "Unable to save. Choose another location and retry.")
            }
        }
    }
}
