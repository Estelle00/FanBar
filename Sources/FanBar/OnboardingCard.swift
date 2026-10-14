import AppKit
import FanBarShared
import SwiftUI

enum OnboardingPreferences {
    static let completionKey = "fanbar.onboarding.v1.completed"

    static var hasCompleted: Bool {
        UserDefaults.standard.bool(forKey: completionKey)
    }

    static func complete() {
        UserDefaults.standard.set(true, forKey: completionKey)
    }
}

/// The first screen FanBar shows. It explains the unusual menu-bar-only app
/// model before handing the user directly into the real popover.
struct OnboardingCard: View {
    static let width: CGFloat = 580
    static let height: CGFloat = 560

    @ObservedObject var controller: FanController
    let onOpenMenu: () -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    statusBarIllustration
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(fanBarText("FanBar 已经在运行", "FanBar is running"))
                            .font(.system(size: 27, weight: .semibold))

                        Text(fanBarText(
                            "它常驻在屏幕顶部的菜单栏，不会显示在程序坞中。",
                            "It lives in the menu bar at the top of your screen and does not appear in the Dock."
                        ))
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    featuresCard

                    if controller.helperState != .enabled {
                        controlServiceNotice
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }

            Divider()

            HStack {
                Button(fanBarText("稍后", "Not now"), action: onDismiss)
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button(action: onOpenMenu) {
                    HStack(spacing: 7) {
                        Text(fanBarText("打开菜单栏面板", "Open menu bar panel"))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                .fanBarPrimaryButton()
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: Self.width, height: Self.height)
        .background(Color(NSColor.windowBackgroundColor))
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 8)
        .onAppear {
            if reduceMotion {
                isVisible = true
            } else {
                withAnimation(.easeOut(duration: 0.28)) {
                    isVisible = true
                }
            }
        }
    }

    private var statusBarIllustration: some View {
        VStack(spacing: 11) {
            ZStack(alignment: .trailing) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.055))

                HStack(spacing: 13) {
                    Image(systemName: "wifi")
                    Image(systemName: "battery.100")
                    Image(systemName: "fan")
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.accentColor.opacity(0.13))
                        )
                }
                .font(.system(size: 13, weight: .medium))
                .padding(.trailing, 13)
            }
            .frame(width: 280, height: 46)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(fanBarText(
                "屏幕顶部菜单栏中的 FanBar 风扇图标",
                "The FanBar fan icon in the menu bar at the top of the screen"
            ))

            HStack(spacing: 6) {
                Text(fanBarText("在这里找到", "Find it here"))
                Image(systemName: "arrow.up")
            }
            .font(.caption.weight(.medium))
            .foregroundColor(.accentColor)
        }
    }

    private var featuresCard: some View {
        SettingsChrome.settingsCard {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 20) {
                    onboardingFeature(
                        icon: "gauge.with.dots.needle.67percent",
                        title: fanBarText("查看实时状态", "Check live status"),
                        detail: fanBarText("温度、风扇转速与当前模式", "Temperature, fan speed, and current mode")
                    )

                    onboardingFeature(
                        icon: "slider.horizontal.3",
                        title: fanBarText("按需调整散热", "Adjust cooling"),
                        detail: fanBarText("日常使用可保持系统自动管理", "Keep automatic control for everyday use")
                    )
                }
                .padding(20)

                SettingsChrome.rowDivider
                Button {
                    CompatibilityWindowPresenter.shared.show(controller: controller)
                } label: {
                    HStack(spacing: 10) {
                        SettingsRowText(
                            title: fanBarText("本机能力检测", "This Mac’s capabilities"),
                            detail: controller.compatibilitySnapshot?.summary
                                ?? fanBarText("查看本机可用功能；检测不会上传信息。", "Check available features; no device information is uploaded.")
                        )
                        Spacer(minLength: 8)
                        Text(fanBarText("查看详情", "Details"))
                            .font(.caption)
                            .foregroundColor(.accentColor)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var controlServiceNotice: some View {
        let state = controller.helperState
        return HStack(alignment: .top, spacing: 10) {
            featureIcon(state.symbolName, tint: state.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(fanBarText("按需调整散热需要一次性授权", "Adjusting cooling needs one-time permission"))
                    .font(.system(size: 13, weight: .semibold))
                Text(state.noticeDetail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let actionTitle = state.actionTitle {
                Button(actionTitle, action: controller.performHelperAction)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .fixedSize()
            }
        }
        .padding(16)
        .background(state.tint.opacity(0.08))
        .accessibilityElement(children: .contain)
    }

    private func onboardingFeature(
        icon: String,
        title: String,
        detail: String
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            featureIcon(icon, tint: .accentColor)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A tinted icon chip. Echoes the fan icon's own chip in the illustration
    /// above, so the card below reads as a continuation of it, not a
    /// separate, flatter block bolted onto the same window.
    private func featureIcon(_ systemName: String, tint: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(tint)
            .frame(width: 26, height: 26)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(tint.opacity(0.13))
            )
            .accessibilityHidden(true)
    }
}
