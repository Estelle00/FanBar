# FanBar 安全吗？Mac 风扇控制 Helper 能做什么、不能做什么

规范页面：https://getfanbar.com/zh/is-fanbar-safe · 已对照源码核实于 2026-10-15 · 由 FanBar 维护者撰写。

**简短回答：安全。** 在你开启手动控制之前，FanBar 只读取传感器。开启之后，一个开源的小型 Helper 只在每个风扇的硬件上下限之内设置目标转速，不做其他任何事。每个版本都使用 Developer ID 签名并经过 Apple 公证。

## FanBar 会损坏风扇或让 Mac 过热吗？

- **转速始终在硬件范围内。** Helper 读取每个风扇报告的最低和最高转速，并把所有目标值限制在这个范围内。唯一有意的例外：温度曲线最低温一段可以请求 0 RPM 静止，与 Apple Silicon Mac 在低温时自己的做法一致。
- **不改动 macOS 的过热保护。** FanBar 只写入风扇模式和目标转速；macOS 降频和硬件临界温度关机照常工作。
- **在 root 边界拒绝异常输入。** 负数或非有限的转速值、超出 0–100% 的曲线比例都会被拒绝，即使来自被篡改的客户端。
- **可选的高温提醒**：CPU 或 GPU 达到 90 °C 时通知。

以下情况 FanBar 会把控制权交还 macOS：选择「自动」或定时预设到期（15 分钟、30 分钟、1 小时）；退出 FanBar 或最后一个连接 Helper 的 App 断开；Helper 退出；多风扇写入中任意一个失败（整机回滚）。

长时间全速运行主要带来噪音和额外磨损。日常使用建议选择「自动」或温度曲线。

## 特权 Helper 能做什么、不能做什么

`FanBar.app → 签名 XPC → FanBarHelper（root）→ AppleSMC 风扇键`

在 macOS 上修改风扇转速需要以 root 身份访问 AppleSMC，读取温度则不需要。只有在你开启手动控制并在 macOS 中批准后，才会安装 Helper。

Helper 可以：

- 读取风扇数量、当前转速，以及每个风扇的最低和最高转速
- 设置目标转速、预设或曲线比例，均限制在风扇范围之内
- 恢复 macOS 自动风扇控制

Helper 不能：

- 写入任意 SMC 键（接口中没有通用写入）
- 执行命令、读取文件或访问网络（相关代码根本不存在）
- 接受其他 App 的指令（只接受与 FanBar 同一 Apple 开发者团队签名的客户端）
- 在 FanBar 断开后继续保持手动控制

## 亲自验证

1. 确认 Apple 公证：运行 `spctl -a -vv /Applications/FanBar.app`，应显示 `accepted` 和 `source=Notarized Developer ID`，签名者为 `Developer ID Application: JiangLin He (64S5F787T9)`。
2. 阅读以 root 运行的代码：
   - https://github.com/helson-lin/FanBar/blob/main/Sources/FanBarHelper/FanBarHelperService.swift
   - https://github.com/helson-lin/FanBar/blob/main/Sources/FanBarHelper/SMCFanDriver.swift
   - https://github.com/helson-lin/FanBar/blob/main/Sources/FanBarShared/FanCoolingTarget.swift
3. 网络：App 没有账号、广告或统计。每天一次通过 Sparkle 向 GitHub Releases 检查更新（更新须通过 Apple 公证与 FanBar 的 EdDSA 签名校验）；兼容性报告只有在你查看并确认后才会发送。

## 如何关闭或移除

- **交还 macOS 控制：** 在菜单栏弹窗中选择「自动」。
- **停用 Helper（macOS 13+）：** 系统设置 → 通用 → 登录项与扩展 → 在「允许在后台」中关闭 FanBar。
- **完全卸载（Homebrew）：** 先退出 FanBar，再运行 `brew uninstall --cask --zap helson-lin/fanbar/fanbar`，会同时卸载 Helper。

## 常见问题

**FanBar 安全吗？** 安全。默认只读取温度和风扇转速，由 macOS 管理散热。手动控制需要你明确批准签名 Helper，它只能在硬件范围内设置目标转速。FanBar 以 GPL-3.0 开源，每个版本都经过 Apple 公证。

**FanBar 会损坏 Mac 的风扇吗？** 目标值被限制在每个风扇报告的最低和最高转速之间，无法超出额定范围。唯一例外是温度曲线最低温一段有意的 0 RPM 静止，与 Apple Silicon Mac 自己的做法一致。

**风扇设错了会让 Mac 过热吗？** FanBar 不改动 macOS 散热管理；macOS 仍会降频，硬件仍会在临界温度关机。可选 90 °C 高温提醒。

**为什么需要管理员批准？** macOS 只允许 root 进程通过 AppleSMC 修改风扇转速。只有开启手动控制时才会请求批准，监控不需要。

**会收集我的数据吗？** 不会。App 没有账号、统计或广告，只有每天一次更新检查，以及你主动选择发送的、不含序列号等唯一标识的兼容性报告。

**FanBar 是病毒或恶意软件吗？** 不是。它使用 Developer ID 签名、经过 Apple 公证，完整源码（含特权 Helper）公开在 GitHub。

- 下载：https://github.com/helson-lin/FanBar/releases/latest
- 源码：https://github.com/helson-lin/FanBar
