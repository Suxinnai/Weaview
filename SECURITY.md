# Security Policy

## 支持范围

当前 `main` 分支接受安全修复。

## 报告安全问题

如果你发现安全问题，请不要在公开 Issue 中粘贴真实 API Key、token、用户数据、日志或截图。

建议报告内容：

- 影响范围。
- 复现步骤。
- 预期结果与实际结果。
- 是否涉及用户凭据、本地持久化数据或第三方 provider 调用。

在没有私有安全报告通道前，请先提交一个不包含敏感细节的 Issue，说明“需要维护者私下沟通安全问题”。

## 凭据处理原则

- 项目不应内置真实 API Key。
- Android 端 API Key 必须通过 Keystore 加密存储，不得写入普通 SharedPreferences 字段。
- provider 支持 HTTP 与 HTTPS；HTTP 为兼容选项，界面必须明确提示 API Key 与对话内容可能被明文传输。
- 数据备份必须屏蔽 API Key，并限制压缩包条目、解压大小和附件大小。
- 本地配置和导出数据不应提交到仓库。
- PR 中新增 provider 接入时，必须说明密钥来源、存储位置和调用边界。
