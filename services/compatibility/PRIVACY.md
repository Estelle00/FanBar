# FanBar 兼容性报告：字段和处理规则

规则版本：2026-10-13。运营者：FanBar 项目维护者。服务地址：https://report.getfanbar.com。

本机检测与导出默认离线；客户端只在用户点击“上传报告”或“准备上报”后获取服务规则，勾选单次同意并点击提交后才发送报告。无需用户账号。

## 可上传字段

严格的机器可读定义位于 [`../../contracts/compatibility-report.schema.json`](../../contracts/compatibility-report.schema.json)，由 `src/schema.ts` 生成；CI 检查漂移。

| 字段 | 用途 |
| --- | --- |
| schemaVersion | 协议版本，当前必须是 1 |
| reportID | 每份报告独立随机 UUID，供幂等重试和查询；不是设备 ID |
| device.modelIdentifier | 机型标识，例如 Mac14,13 |
| device.processor | 处理器名称或架构类别 |
| device.macOSVersion / appVersion / helperVersion | 分别定位版本组合 |
| fanCount | 如可获取，硬件接口报告的 0–8 个风扇 |
| capabilities | 七项能力各一条：能力枚举、状态枚举、标准原因码 |
| capabilities[].userConfirmedWorking | 可选；仅用于手动调速与智能温控，用户主动勾选确认本机实际使用可用时为 true，不修改自动检测结果，不等同于开发者验证；仅可附在 requestSucceeded 或 unverified 结果上，控制请求失败或 Helper 未授权／缺失时拒绝 |
| selectedTemperatureSource | 当前所选温控来源：maxChip / cpu / gpu / ssd |

额外请求头：`X-FanBar-Policy-Version` 确认规则版本；`X-FanBar-Publish-Report` 明确选择是否公开单份报告（0 / 1）；`Authorization: Bearer …` 是每份报告独立的撤回凭证。请求头不并入公开报告。

服务器补充接收时间、到期时间、审核状态和选择公开与否。数据库仅保存撤回凭证的 SHA-256 哈希，明文凭证不记录到数据库、源码、客户端配置、日志或 URL。客户端在发送前把凭证和待确认记录保存到本机非同步钥匙串，之后更新回执。

不接收序列号、硬件 UUID、用户名、主机名、路径、进程列表、温度历史、原始诊断日志、邮箱或联系方式。额外字段直接拒绝，不静默剥离。

## 校验与防重复

- 请求体最大 16 KiB，实际按流累计字节，不只相信 Content-Length。
- 严格根对象、设备对象、能力对象白名单；字段类型、字符串长度、枚举及原因码受约束。
- 必须七项能力各出现一次；传感器、风扇和控制的原因码不能混用，状态必须匹配原因。
- `notApplicable` / `NO_BUILT_IN_BATTERY` 仅用于系统明确报告没有内置电池的电池温度项；它不等于传感器读取失败。
- 零风扇与读取失败分开；读不到风扇不能被当成“确认无风扇”。
- 报告编号相同且凭证、内容和公开选择相同则返回同一回执，不新增统计。发生冲突返回 409，不覆盖原报告。
- 暂时错误不会在后台自动重发。用户主动重试保留原报告编号、原凭证、原公开选择；重新打开待确认记录也能重试。

## 公开边界

1. 单份报告默认私有。用户选择公开且管理员审核通过后，`GET /api/reports/:id` 才返回其固定字段；公开接收时间精确到日期。
2. 审核通过的有效报告（包含原始报告私有的报告）贡献公开的机型／版本／能力汇总。提交时明确告知这一用途。
3. 汇总只展示报告数、能力状态分布、更新时间；不含报告 ID、处理器原始字符串、凭证或用户标识。
4. 没有稳定设备 ID，因此报告数不能称为独立设备数或覆盖用户比例。有人可重复创建新报告，审核只能排除明显重复，不能保证身份级去重。
5. 社区报告不是开发者验证。控制请求被接受不是物理转速被验证。开发者实测单独维护，必须有机型、版本、具体能力、日期、公开依据和说明。
6. 同一组合有不同结果时保留分布，不采用多数票推导“完整支持”。罕见机型／版本组合仍可能具有辨识度。

## 网络元数据、限流和管理员

Cloudflare 会处理传输与安全所需的网络地址等元数据，不宣称“绝对匿名”。D1 不保存原始 IP。应用使用服务器秘密作为 HMAC 密钥，对日期与网络地址生成每日变化的摘要，只送入短期限流器，不保存到报告库或日志，不作为设备标识。共享网络可能触发共享限额；限流是按 Cloudflare 位置的尽力保护，不是全球严格配额。

写请求每分钟 10 次、读请求每分钟 200 次（每个 Cloudflare 位置）；不同环境使用独立命名空间。公开查询每次最多 20 个最近版本组合，可按机型过滤。

管理员接口需要独立 256 位随机管理密钥（服务端 secret），或已配置的 Cloudflare Access JWT 签名、issuer、audience 验证。管理网页只是公开的登录界面，未认证不能获取报告。管理密钥仅在页面内存中使用，不写入浏览器持久存储。修改接口另要求同源 Origin 和自定义请求头；不允许跨域 CORS。

审核记录只保存操作目标、管理员身份（独立密钥时为固定角色；Access 时为身份提供方 subject）、动作、标准理由和时间。审核接口不返回凭证哈希或内容哈希。

后台的审核提示（结果冲突、疑似重复、新机型、实测候选）只由已保存的报告内容、版本组合和接收时间推导，不使用设备标识、网络地址或限流数据。“疑似重复”仅表示同一版本组合下除报告编号外内容完全相同、且相隔不到 10 分钟提交，不能证明来自同一台设备。这些提示不会自动改变审核状态或公开内容。

应用日志只输出无负载的固定错误类别；禁用 Workers invocation logs。不要额外配置抓取完整请求的 Logpush、调试日志或第三方埋点。

## 保留、撤回、备份

报告保留 90 天，到期立即停止 API 查询和统计，每日定时物理清理（在线库最多额外约一天）。原始报告审核记录同样不长期保留。独立开发者验证记录长期保留，直到更正或撤下；仍在发布的验证记录，其审核记录随之保留。

拥有凭证可 DELETE 对应报告：在线报告和相关审核记录删除，汇总实时排除。删除操作保留由报告编号和凭证共同派生的私有删除标记 90 天，防止同一凭证的迟到请求重新写入；其他凭证产生的标记不会阻止报告所有者提交或撤回。标记不含原始编号、明文凭证或报告内容。已经不存在或过期的报告返回 204；不存在的私有报告与错误凭证不通过公开查询暴露详情。

撤回凭证只能删除自己的随机报告，不是管理员密钥。用户可以显式保存撤回凭证文件；该文件含密钥，不能作为普通报告公开分享。

D1 Time Travel 历史恢复点保留 7 天（Workers Free）或 30 天（Workers Paid）；在线删除不会立即清除这些历史副本。参考 [Cloudflare 官方说明](https://developers.cloudflare.com/d1/reference/time-travel/)。本项目不增加无限期外部原始报告备份。历史恢复只能在维护窗口进行，恢复后先清理到期报告并重新审查公开状态；无法核对撤回记录时不得直接恢复原始报告对外服务，应只迁移独立开发者验证数据。公开下载与第三方副本无法追回。

规则更新需要更新版本及客户端支持版本，再取得新提交的同意；不能悄悄复用旧同意扩大收集范围。

## Opt-in diagnostic logs (diagnostics-2026-10-14)

A separate `/api/diagnostics` endpoint accepts only schema version, random diagnostic ID,
capture time, the same allowlisted device/version inventory, helper state, one current
thermal sample and battery-presence flag, fan count, connection error code, and up to
256 structured sensor probes (sensor category, four-character key, outcome, numeric
value/error code). It rejects extra fields and bodies larger than 64 KiB. It never
accepts arbitrary system logs. Collection is read-only and requires separate upload consent.
Diagnostics are always private, visible only through authenticated administrator APIs,
and never enter public records or compatibility counts. Online retention is 90 days,
with daily cleanup and up to 30 additional days in historical restore points. The client
stores retry/deletion receipts in a separate non-synchronizing Keychain namespace.
Deletion uses a per-diagnostic bearer credential; only its SHA-256 hash is stored in D1.
Private hashed withdrawal markers block delayed upload resurrection for 90 days.
Existing compatibility report collection rules remain unchanged.

### Diagnostic evidence revision (diagnostics-2026-10-14-v2)

The diagnostic-only body limit is now 128 KiB. Optional evidence adds up to 30 samples
from the preceding minute (sample time, thermal values, fan count, numeric failure code,
and sample/connect/fanRead stage); SMC data type, length, and at most eight raw bytes
per temperature key; recognized/unrecognized key flags; and bounded discovery statistics
(reported count, scanned count, truncation, numeric failure). Enumeration inspects at most
4096 key names or 1.5 seconds, uploads only alphanumeric T-prefixed temperature-key
names/values, and caps the combined probes at 256. It does not upload other SMC inventory.
SSD and battery fallback probes include their fixed source name and outcome/stage.
These are explicit opt-in diagnostics, not additions to compatibility reports.

### Runtime diagnostics revision (diagnostics-2026-10-14-v3)

The diagnostic-only limit is 256 KiB. Structured runtime evidence adds up to 320 events:
256 bounded app events retained locally for up to 24 hours (32 launch markers plus 224
operations), and up to 64 Helper events available in the product's own unified-log
subsystem over the preceding 10 minutes. Only fixed component/action/outcome enums,
random session/request IDs, timestamps, numeric error codes, command parameters,
durations, fan index/mode are included. No arbitrary exception descriptions are stored.
App journals use a private local directory and mode 0600 files; no upload occurs until consent.
Helper log access failures are explicitly flagged, not interpreted as helper absence.

Diagnostic uploads use a stricter keyed per-address limiter (2 per minute) than reports, and
the service stops accepting new diagnostics after 200 in 24 hours or 5,000 stored, answering
503 `DIAGNOSTIC_CAPACITY_REACHED`. Retries of an already stored diagnostic still succeed.

Up to 3 recent (7-day) FanBar/Helper .ips crash files are read locally (2 MiB input limit
each). Only file modification time, fixed process/exception/signal/termination categories,
termination code, and up to 20 fixed image names and relative offsets survive extraction.
Usernames, paths, incident/device UUIDs, arbitrary messages, symbols, and complete crash
reports are excluded. Directory readability is flagged separately. Missing shutdown
markers are "previousExitUnknown", not proof of a crash. Runtime context adds app build,
OS build, architecture, coarse bundle location and bundled-helper presence (no paths).
The separately signed FanBarDiagnostics executable and companion .command launcher can
export the same sanitized evidence without loading the app UI, registering a daemon,
changing fan control, or uploading anything.

### Diagnostics revision (diagnostics-2026-10-15-v4)

Adds `runningHelper`: whether the running Helper daemon answered a read-only build query
(`reported`, `noReply`, `connectionFailed`, or `notQueried` when the Helper is not enabled), its
build token, and a numeric connection error code. It is compared with `device.helperVersion`, the
build bundled in the app, to detect a stale daemon left running after an update. The query uses a
separate short-lived connection and never changes fan control.

Helper events now cover the last 24 hours for failures, rejections and lifecycle markers
(startup, shutdown, recovery, authorization) and the last 10 minutes for everything else, still
bounded to 64 events. `discovery.truncated` now means only that the SMC key scan stopped early;
`discovery.probesTruncated` means the scan finished but some unrecognized keys were left out of
the probe list.
