import FanBarShared
import SwiftUI

extension CompatibilityCapability {
    var title: String {
        switch self {
        case .cpuTemperature: fanBarText("CPU 温度", "CPU temperature")
        case .gpuTemperature: fanBarText("GPU 温度", "GPU temperature")
        case .ssdTemperature: fanBarText("SSD 温度", "SSD temperature")
        case .batteryTemperature: fanBarText("电池温度", "Battery temperature")
        case .fanReadings: fanBarText("风扇转速", "Fan speed readings")
        case .manualControl: fanBarText("手动调速", "Manual fan control")
        case .smartCooling: fanBarText("智能温控", "Smart cooling")
        }
    }
}

extension CompatibilityStatus {
    var title: String {
        switch self {
        case .notApplicable: fanBarText("正常（无内置电池）", "Normal (no built-in battery)")
        case .available: fanBarText("已验证可读取", "Reading verified")
        case .notDetected: fanBarText("本次未检测到", "Not detected this time")
        case .temporarilyUnavailable: fanBarText("暂时不可用", "Temporarily unavailable")
        case .requiresAuthorization: fanBarText("需要授权", "Authorization required")
        case .unverified: fanBarText("尚未验证", "Not yet verified")
        case .requestSucceeded: fanBarText("请求已成功", "Request succeeded")
        case .requestFailed: fanBarText("请求失败", "Request failed")
        }
    }

    var symbol: String {
        switch self {
        case .available, .requestSucceeded, .notApplicable: "checkmark.circle"
        case .requiresAuthorization: "lock"
        case .temporarilyUnavailable, .requestFailed: "exclamationmark.circle"
        case .notDetected, .unverified: "questionmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .available, .requestSucceeded, .notApplicable: .green
        case .requiresAuthorization, .temporarilyUnavailable, .requestFailed: .orange
        case .notDetected, .unverified: .secondary
        }
    }
}

extension CompatibilityResult {
    var detail: String {
        switch reasonCode {
        case "NO_BUILT_IN_BATTERY":
            fanBarText("本机没有内置电池，无需检测电池温度。", "This Mac has no built-in battery; battery temperature testing is not needed.")
        case "SENSOR_READ_SUCCEEDED":
            fanBarText("本次已获取有效读数。", "A valid reading was obtained this time.")
        case "SENSOR_NOT_DETECTED":
            fanBarText("当前没有可用读数，不代表机型不支持。", "No current reading; this does not establish incompatibility.")
        case "FAN_READ_SUCCEEDED":
            fanBarText("本次已读取风扇转速与范围。", "Fan speeds and ranges were read this time.")
        case "NO_FANS_REPORTED":
            fanBarText("硬件接口报告零个风扇，不据此判断物理配置。", "The interface reports zero fans; physical configuration is not inferred.")
        case "FAN_READ_FAILED":
            fanBarText("风扇读取失败，可以重试；不能据此判断机型不支持。", "Fan reading failed. Retry; this does not establish incompatibility.")
        case "SMC_CONNECTION_FAILED":
            fanBarText("无法连接硬件读取接口，请重试。", "Unable to connect to the hardware interface. Retry.")
        case "HELPER_MISSING":
            fanBarText("应用包缺少控制服务，请重新安装已签名的 FanBar。", "The control service is missing. Reinstall the signed FanBar app.")
        case "HELPER_AUTHORIZATION_REQUIRED":
            fanBarText("启用并批准控制服务后，可继续验证控制能力。", "Enable and approve the service to continue verifying control.")
        case "NO_CURRENT_FAN_EVIDENCE":
            fanBarText("没有当前风扇读数，暂时无法判断控制能力。", "Without current fan readings, control capability cannot be determined.")
        case "NO_CURVE_SENSOR_EVIDENCE":
            fanBarText("当前没有可用于温控的温度读数。", "No temperature reading is currently available for curve control.")
        case "CONTROL_REQUEST_SUCCEEDED":
            fanBarText("最近一次控制请求已被接受，不代表实际转速已验证。", "The latest control request was accepted; physical RPM is not verified.")
        case "CONTROL_REQUEST_FAILED":
            fanBarText("最近一次控制请求失败，不据此判断机型不支持。", "The latest control request failed; incompatibility is not inferred.")
        default:
            fanBarText("尚无控制操作结果，可点击“重新检测”。", "No control result yet. Click Check Again to test.")
        }
    }
}

extension CompatibilitySnapshot {
    var summary: String {
        let temperatureAvailable = results.contains {
            [.cpuTemperature, .gpuTemperature, .ssdTemperature, .batteryTemperature].contains($0.capability)
                && $0.status == .available
        }
        if fanCount == 0 {
            return fanBarText("硬件接口未报告风扇，控制能力尚未验证", "No fans reported; control is not yet verified")
        }
        if fanCount == nil {
            return temperatureAvailable
                ? fanBarText("温度监测可用，风扇读取暂时失败", "Temperature monitoring available; fan reading failed")
                : fanBarText("本次未获取有效读数，请重新检测", "No valid readings this time. Retry detection")
        }
        if results.contains(where: { $0.status == .requiresAuthorization }) {
            return temperatureAvailable
                ? fanBarText("温度与风扇可读取，控制需要授权", "Temperatures and fans readable; control needs authorization")
                : fanBarText("风扇可读取，控制需要授权", "Fans readable; control needs authorization")
        }
        return temperatureAvailable
            ? fanBarText("温度与风扇可读取，请查看各项控制结果", "Temperatures and fans readable; review control results")
            : fanBarText("风扇可读取，请查看各项检测结果", "Fans readable; review individual results")
    }
}
