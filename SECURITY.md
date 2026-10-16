# Security policy

## Supported versions

Security fixes target the latest stable release listed in [GitHub Releases](https://github.com/helson-lin/FanBar/releases/latest). Older releases and development snapshots do not receive separate security backports. Reports about older versions are still welcome; include whether the problem reproduces on the latest stable release or current `main`.

## Report a vulnerability privately

Use GitHub's [Report a vulnerability](https://github.com/helson-lin/FanBar/security/advisories/new) form. If that channel is unavailable, email the maintainer at [jarinhe@proton.me](mailto:jarinhe@proton.me) with the subject `FanBar security report`.

Do not put exploit details, credentials, personal data, or unreleased fixes in a public issue or pull request. Ordinary crashes, missing sensors, and installation questions can use the [normal support channels](SUPPORT.md) unless they have a security impact.

A useful report includes:

- The affected app version and build, macOS version, Mac model/chip, and installation source.
- The affected component, such as the app, privileged helper/XPC, updater, widget, or compatibility report service.
- Reproduction steps or a minimal proof of concept, required permissions, expected behavior, and actual behavior.
- The potential impact and any workaround you have verified.
- Redacted logs or screenshots only when needed. Remove usernames, serial numbers, file paths, access tokens, report withdrawal credentials, and other identifying information.

If a secret was exposed, revoke or rotate it; do not send a live secret as proof. Use your own device and test data for reproduction, and do not access or alter other users' reports or disrupt the production service.

## What happens next

The maintainer will review the report, may request more information, and coordinate a fix and disclosure when appropriate. Please keep details private while a report is being assessed. This is a volunteer-maintained project: there is no guaranteed response or fix deadline and no paid bug bounty program. Reporter credit will be discussed before public disclosure; anonymous reports are welcome.

## 中文说明

安全修复面向最新稳定版，旧版本问题仍可报告。请优先使用 GitHub 的 [私密漏洞报告](https://github.com/helson-lin/FanBar/security/advisories/new)，不可用时发送到 [jarinhe@proton.me](mailto:jarinhe@proton.me)。不要在公开 Issue 或 PR 中发布漏洞利用细节、密钥或个人数据。请提供受影响版本、复现步骤与影响范围；普通使用问题请查看 [支持指引](SUPPORT.md)。
