# FanBar compatibility report service

Cloudflare Workers + D1，服务地址 `https://report.getfanbar.com`。严格字段接收、报告幂等重试、私有／自愿公开、管理员审核、公开兼容性矩阵、撤回和 90 天清理。没有自动诊断日志上传、账号系统或崩溃监控。

- `/`：无需账号的公开兼容性页。
- `/admin/`：管理员审核页，独立管理密钥或 Cloudflare Access 验证。
- `/privacy.html`：公开字段、处理与保留规则。
- `/report-schema.json`：严格的上传 Schema。
- `/withdraw.html`：凭报告编号和独立凭证撤回。
- `/report.html?id=UUID`：自愿公开且审核通过的单份报告。

源码在本目录，协议在 `../../contracts`；处理规则详见 [PRIVACY.md](PRIVACY.md)。

## 本地开发

Node 24+。安装后复制 `.dev.vars.example` 为 `.dev.vars`，为 LIMIT_SALT 和 ADMIN_TOKEN 生成两个独立的随机 32 字节 base64url 值（各 43 字符）；文件不得提交。

```sh
npm ci
npm run db:local
npm run dev
```

打开 `http://localhost:8787`。后台输入本地 ADMIN_TOKEN，浏览器只在内存中保存。开发和生产必须用不同密钥。原始数据库不会预置报告或验证记录。

```sh
npm run check
npm test
npm run dry-run
```

`wrangler types --include-runtime=false --strict-vars=false` 从配置生成绑定类型；`@cloudflare/workers-types` 提供运行时类型。Vitest 在真实 Workers 模拟运行时执行 D1 测试。Schema 和规则示例由 `npm run schema` 生成，CI 检查漂移。

Swift 调试运行可设置 `FANBAR_COMPATIBILITY_SERVICE_URL=http://127.0.0.1:8787`。只在 DEBUG 支持 loopback HTTP；正式客户端从 `App/Info.plist` 的 `FanBarCompatibilityServiceURL` 读取 HTTPS 地址。打开预览不会联网，点击准备上报才获取规则。

## 生产部署

1. `npx wrangler login`，确认当前账号管理 `getfanbar.com`。
2. 创建 D1 `fanbar-compatibility`，把实际 UUID 写入 `wrangler.jsonc` 的 production D1 绑定。开发绑定只用于本地模拟。
3. 为生产 LIMIT_SALT 和 ADMIN_TOKEN 生成两个独立随机值，用 `wrangler secret bulk` 或交互式 `secret put` 保存；不要把值放进参数、源码或普通日志。
4. 应用迁移、干运行、部署：

```sh
npx wrangler d1 migrations apply fanbar-compatibility --env production --remote
npm run dry-run
npm run deploy
```

Custom Domain 固定为 `report.getfanbar.com`；workers.dev 和预览 URL 关闭。生产服务不开放其他子域名。定时清理每天 UTC 03:17 执行。

如果不希望使用独立管理密钥，可配置 `ACCESS_TEAM_DOMAIN=https://YOUR-TEAM.cloudflareaccess.com`、`ACCESS_AUD`，并在 Access 设置只允许维护者访问 `/admin*` 和 `/api/admin/*`。后端仍会验证 JWT，而非只相信网关头部。没有任何有效管理员认证时接口返回 403。不要把 Access 对整个域名设为强制登录，否则会阻断匿名上报和公开查询。

### API

| 方法与路径 | 行为 |
| --- | --- |
| GET /api/policy | 当前规则版本、服务 origin、字段白名单、90 天在线与最多 30 天恢复点说明 |
| POST /api/reports | 提交严格 JSON；必须带三个确认／凭证头 |
| GET /api/reports/:id/receipt | 凭所属报告 credential 查询回执 |
| DELETE /api/reports/:id | 凭所属 credential 撤回 |
| GET /api/reports/:id | 只返回用户选择公开且审核通过的报告 |
| GET /api/compatibility?model=Mac14,13 | 经过审核的有效社区状态分布＋独立实测 |
| GET /api/admin/reports | 管理列表；status/model/appVersion/offset 筛选 |
| GET /api/admin/reports/:id | 管理详情，不返回内部哈希 |
| PUT /api/admin/reports/:id/review | pending/approved/rejected，附标准理由 |
| POST /api/admin/verifications | 独立实测，附版本、日期、能力、依据 |
| DELETE /api/admin/verifications/:id | 撤下错误的实测结论 |

POST 使用预览中的报告 JSON 作为原始 body，不添加隐藏设备字段：

- `Authorization: Bearer <每份报告独立 43 字符 credential>`
- `X-FanBar-Policy-Version: 2026-10-13`
- `X-FanBar-Publish-Report: 0`（或用户选择的 1）

撤回凭证由客户端在发送前生成并保存到本机钥匙串；不是服务端管理员密钥。管理网页使用独立 ADMIN_TOKEN，管理修改同时检查同源 Origin 和 `X-FanBar-Admin: 1`。

## 运维与恢复

D1 Time Travel 是平台自带恢复机制，不建立无限期原始报告备份。恢复期间关闭上报与公开服务，保留恢复前有效撤回信息；无法核对撤回历史时仅迁移独立实测记录，不把旧原始报告恢复后直接公开。详见 PRIVACY.md。

更换管理密钥后，旧网页会话失效；定期检查数据库使用量、固定错误事件和 Cron 清理。不要启用完整请求日志。公开统计不是设备覆盖率，未审核报告不计入，用户撤回后不计入，过期报告不计入。
