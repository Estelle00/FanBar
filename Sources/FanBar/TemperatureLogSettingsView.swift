import AppKit
import FanBarShared
import SwiftUI

/// The Log settings pane: a CSV file of temperatures and fan speeds, modeled on TG Pro's Log tab.
struct TemperatureLogSettingsView: View {
    @ObservedObject var controller: FanController

    @AppStorage(TemperatureLogPreferences.enabledKey)
    private var enabled = false
    @AppStorage(TemperatureLogPreferences.intervalKey)
    private var intervalSeconds = TemperatureLogPreferences.defaultIntervalSeconds
    @AppStorage(TemperatureLogPreferences.directoryKey)
    private var directoryPath = ""
    @AppStorage(TemperatureLogPreferences.newLogPolicyKey)
    private var newLogPolicyRawValue = TemperatureLogPreferences.defaultPolicy.rawValue
    @AppStorage(TemperatureLogPreferences.logTemperaturesKey)
    private var logTemperatures = true
    @AppStorage(TemperatureLogPreferences.logFanSpeedsKey)
    private var logFanSpeeds = true

    private var settings: TemperatureLogSettings { TemperatureLogSettings.current() }

    private var newLogPolicy: Binding<TemperatureLogPreferences.NewLogPolicy> {
        Binding(
            get: { TemperatureLogPreferences.NewLogPolicy(rawValue: newLogPolicyRawValue) ?? TemperatureLogPreferences.defaultPolicy },
            set: { newLogPolicyRawValue = $0.rawValue }
        )
    }

    var body: some View {
        SettingsSection(
            title: fanBarText("温度日志", "Temperature Log"),
            footer: fanBarText(
                "开启后，FanBar 会按间隔把温度和风扇转速追加到 CSV 文件，数据只保存在本机。",
                "When enabled, FanBar appends temperatures and fan speeds to a CSV file at the chosen interval. The data stays on this Mac."
            )
        ) {
            Toggle(isOn: $enabled) {
                SettingsRowText(title: fanBarText("启用日志", "Enable logging"), detail: statusText)
            }
            .toggleStyle(.switch)
            .settingsRow()

            SettingsChrome.rowDivider

            HStack {
                SettingsRowText(title: fanBarText("文件位置", "Location"), detail: locationText)
                Spacer(minLength: 8)
                Button(fanBarText("在访达中显示", "Reveal in Finder"), action: revealInFinder)
                Button(fanBarText("选择文件夹…", "Choose Folder…"), action: chooseFolder)
            }
            .settingsRow()

            SettingsChrome.rowDivider

            HStack {
                SettingsRowText(
                    title: fanBarText("采样间隔", "Sampling interval"),
                    detail: fanBarText("间隔越短，文件越大。", "Shorter intervals make larger files.")
                )
                Spacer(minLength: 8)
                Picker("", selection: $intervalSeconds) {
                    ForEach(TemperatureLogPreferences.intervalOptions, id: \.self) { seconds in
                        Text(fanBarFormat("%d 秒", "%d s", seconds)).tag(seconds)
                    }
                }
                .labelsHidden()
                .frame(width: 120)
            }
            .settingsRow()
        }

        SettingsSection(title: fanBarText("记录内容", "Logged Data")) {
            Toggle(isOn: $logTemperatures) {
                SettingsRowText(title: fanBarText("温度", "Temperatures"))
            }
            .toggleStyle(.checkbox)
            .settingsRow()

            SettingsChrome.rowDivider

            Toggle(isOn: $logFanSpeeds) {
                SettingsRowText(title: fanBarText("风扇转速和模式", "Fan speeds and mode"))
            }
            .toggleStyle(.checkbox)
            .settingsRow()
        }

        SettingsSection(
            title: fanBarText("新建日志", "Create New Log"),
            footer: fanBarText(
                "更改任何日志选项都会立即新建文件，表头和数据列保持一致。",
                "Changing any log option starts a new file right away, so each file's header matches its rows."
            )
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Picker("", selection: newLogPolicy) {
                    Text(fanBarText("从不（持续追加到同一文件）", "Never (keep appending to one file)"))
                        .tag(TemperatureLogPreferences.NewLogPolicy.never)
                    Text(fanBarText("每次启动应用", "On app startup"))
                        .tag(TemperatureLogPreferences.NewLogPolicy.onStartup)
                    Text(fanBarText("每天午夜（每天一个文件）", "Every day at midnight (one file per day)"))
                        .tag(TemperatureLogPreferences.NewLogPolicy.daily)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }
            .settingsRow()
        }
    }

    private var statusText: String {
        guard enabled else { return fanBarText("已关闭", "Off") }
        switch controller.temperatureLog.status {
        case .idle:
            return fanBarText("等待第一条记录", "Waiting for the first sample")
        case .recording(let fileName):
            return fanBarFormat("正在写入：%@", "Writing to %@", fileName)
        case .failed:
            return fanBarText("写入失败，请检查文件夹权限。", "Writing failed. Check the folder’s permissions.")
        }
    }

    private var locationText: String {
        let directory = settings.directory
        let folder = (directory.path as NSString).abbreviatingWithTildeInPath
        if case .recording(let fileName) = controller.temperatureLog.status {
            return "\(folder)/\(fileName)"
        }
        return folder
    }

    private func revealInFinder() {
        if case .recording(let fileName) = controller.temperatureLog.status {
            let file = settings.directory.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: file.path) {
                NSWorkspace.shared.activateFileViewerSelecting([file])
                return
            }
        }
        NSWorkspace.shared.open(settings.directory)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = fanBarText("选择", "Choose")
        // Non-modal: runModal() would stop the 2-second refresh timer, and with it curve control,
        // for as long as the panel stays open.
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            directoryPath = url.path
        }
    }
}
