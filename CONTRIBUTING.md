# Contributing to Weaview

感谢你愿意参与织境开发。这个项目欢迎 Issue、Bug report、功能建议和 Pull Request。

## 开发原则

- 必须保持用户凭据本地化，不提交真实 API Key、token、导出数据或截图。
- 必须优先复用现有目录结构与组件模式。
- 应当让改动可回滚、可 review，避免把无关重构混进功能 PR。
- 应当为纯逻辑改动补单元测试，为 UI 行为改动至少跑现有 widget test。
- 可选先开 Draft PR 讨论设计，再补实现。

## 本地开发

```bash
git clone https://github.com/Suxinnai/Weaview.git
cd Weaview
flutter pub get
flutter analyze
flutter test
```

## 分支与提交

推荐分支命名：

- `feature/<short-name>`
- `fix/<short-name>`
- `docs/<short-name>`
- `refactor/<short-name>`

提交信息建议使用简洁的 Conventional Commits 风格：

```text
feat: add provider model search
fix: preserve model assignment after provider edit
docs: update setup guide
refactor: split settings tab widgets
test: cover markdown segment parsing
```

## Pull Request 流程

1. Fork 本仓库。
2. 从 `main` 创建分支。
3. 完成改动并运行质量检查。
4. 推送到你的 fork。
5. 发起 PR，说明变更目的、验证方式和风险。

PR 合并前至少需要：

- `flutter analyze` 通过。
- `flutter test` 通过。
- 不包含真实密钥、个人数据和本地构建产物。
- 对用户可见行为的变化有说明。

## 代码结构约定

- `lib/src/app/`：应用装配、全局状态、偏好设置、主题守卫。
- `lib/src/core/`：纯工具函数和扩展。
- `lib/src/data/`：外部 provider、搜索、流解析等 I/O 边界。
- `lib/src/domain/`：领域模型和序列化。
- `lib/src/features/`：聊天、设置、历史等功能界面。
- `lib/src/shared/`：跨 feature 复用的 UI 和 view model。
- `android/`、`ios/`：Flutter 平台宿主工程源码，必须保留在仓库中；真正的 APK、IPA、AAB、xcarchive 等构建产物不得提交。

## 测试建议

- 纯函数、解析器、resolver：优先写单元测试。
- 状态变更：优先覆盖持久化、默认值、边界输入。
- UI：至少确保现有 widget test 不回归。

## 安全问题

如果你发现可能泄露用户 API Key、本地数据或远程调用凭据的问题，请不要公开贴出敏感细节。请先参考 [SECURITY.md](./SECURITY.md)。
