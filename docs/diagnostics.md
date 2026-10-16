# 故障诊断

## 应用可以打开

进入「设置 → 设备兼容性 → 上传诊断日志」。先复现一次问题，再打开此窗口。
日志摘要会说明内容，详细数据默认折叠。勾选同意后才会发送；上传后把诊断编号提供给维护者。

日志包含最近一分钟温度采样、传感器格式/原始数值和备用来源、最近一天有界保留的启动/授权/XPC/控制事件，以及可读取的脱敏崩溃摘要。
单纯请求成功不代表实际风扇响应；应对照目标、回读、恢复结果和 Helper 事件。
旧日志无法补齐新证据。首次更新后需要重新复现，正常退出再重新打开可以验证跨启动记录。

## 应用打不开

运行发布包中与 FanBar.app 同目录的 `FanBar-Diagnostics.command`。
也可以右键 FanBar.app →「显示包内容」→ Contents → Resources → 双击 `ExportDiagnostics.command`。
这会单独运行签名的 FanBarDiagnostics 工具，不启动主界面、不注册控制服务、不调整风扇、不联网。
诊断 JSON 保存到桌面。检查后再通过你选定的渠道提供给维护者；不要在公开 issue 粘贴完整日志。

终端也可以指定保存位置：

```sh
/Applications/FanBar.app/Contents/MacOS/FanBarDiagnostics --output "$HOME/Desktop/FanBar-diagnostics.json"
```

如果系统阻止整个应用包执行，独立工具也可能被阻止，需要保留系统提示的原文用于排查。
未读到 Helper 日志或崩溃摘要不代表没有运行/崩溃；数据内有独立可用性标志。
`previousExitUnknown` 仅表示缺少正常退出记录，也可能由强制退出或关机造成。
崩溃摘要仅保留固定异常分类、终止码、模块名和相对偏移；完整 .ips、路径、设备/事件 UUID 和任意错误消息不上传。

## 后台

在「诊断日志」页按编号查询，先看运行事件时间线和崩溃摘要，再对照传感器数据。
客户端请求编号可关联发起/结果/超时；Helper 使用独立请求编号，按操作与时间对照，不能假设两者编号相同。
当前二进制无符号文件时，模块偏移只能缩小范围，精确崩溃定位还需对应构建的 dSYM。
`runningHelper` 是正在运行的 Helper 自报的 build：与 `device.helperVersion`（应用内置 build）不一致，说明更新后旧守护进程仍在运行，需要重新授权 Helper 或重启。
`noReply` 表示 Helper 早于版本查询或已无响应；`notQueried` 表示 Helper 未启用，采集时不会为此启动或注册 Helper。
Helper 的失败、拒绝和启动/关闭/恢复/授权事件取自最近 24 小时，其余 Helper 事件只取最近 10 分钟。
`discovery.truncated` 只表示 SMC 键扫描提前结束；`discovery.probesTruncated` 表示扫描完整、但部分未识别键没有附带读数探测。
