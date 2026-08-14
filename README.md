# 织境 Weaview

织境是一个以 Flutter 为核心的 AI 对话应用，面向希望自主管理模型提供商、对话记忆、联网搜索和移动端交互体验的用户与开发者。

## 简介

织境提供一个可本地配置的多模型聊天环境。它不内置任何真实 API Key，所有模型服务、搜索服务和语音服务凭据都需要用户在 App 设置中显式配置。

Latest stable / 最新正式版：`v2.0.4`

主要能力包括：

- 多提供商 AI 对话，支持 OpenAI 兼容接口与 Gemini 等 provider。
- 主对话、标题总结、后续建议、翻译等角色模型独立分配。
- 工具模型可独立分配，用于人物画像补全和长期记忆整理。
- 流式输出、思考状态、思考链解析与折叠展示。
- 生图对话模式支持一次输出 1–6 张图片，并按官方协议接入 OpenAI / GPT Image、Gemini / Nano Banana、Grok Imagine、Seedream、Recraft、Stability AI、FLUX、Ideogram，以及 Replicate 上的 Imagen、Qwen Image 等主流模型。
- 会话历史、会话分支、长期记忆、参考历史记忆和本地数据管理。
- 图片/文件附件入口、消息复制、编辑、删除、重试、翻译。
- Tavily 联网搜索配置入口。
- 手动启用的 TTS 服务配置，支持系统 TTS fallback 与远程 TTS provider。
- Flutter 移动端 UI，保留 TTS 播报并移除语音输入入口。

English summary:

- Weaview is a Flutter AI chat app with configurable providers, role-based model assignment, streaming chat, memory, search, translation, image generation, TTS, and mobile-first interaction design.
- API keys are never bundled. Configure AI, search, image, and TTS providers explicitly inside the app settings.

## Features

- 支持自定义 AI provider、Base URL、API Key 和模型列表。
- 支持 provider 拖拽排序、长按显示删除控制和预设 provider 安全合并。
- 支持 OpenAI-compatible `/v1/chat/completions` 流式响应。
- 支持 OpenAI-compatible `/v1/images/generations`、OpenAI Responses image tool、Gemini `generateContent`、火山方舟、Stability、BFL、Ideogram 与 Replicate 官方生图协议。
- 支持 Gemini `generateContent` 显式 provider 接入，内置 `gemini-3.1-flash-lite-image`、`gemini-3.1-flash-image`、`gemini-3-pro-image` 和 `gemini-2.5-flash-image` 四个稳定生图型号。
- 支持 PhotoStack 风格的多图结果卡组、全屏翻页预览（玻璃顶栏与缩略图导轨）和逐张保存。
- 支持从屏幕左边缘向右滑动打开侧边栏。
- 设置页采用“通用 / 提供商 / 默认模型 / 扩展服务 / 数据管理 / 关于织境”六入口结构；昵称和强调色可直接修改，低频设置按需展开，并遵循系统的减少动态效果偏好。
- 支持小米 MiMo `mimo-v2-tts` 流式 TTS 返回的 PCM16 音频，并自动封装为 WAV 播放。
- 支持 AI 生成主题指令的安全守卫，限制模型只能修改允许的聊天外观字段。
- 支持本地自然语言外观指令解析：直接输入「换一个紫色背景」即可即时生效，无需模型往返，并以自然语言确认结果。
- 支持人物画像、助手昵称、用户资料和工具模型辅助整理。
- 支持 Markdown、代码块、公式块、思考链、翻译块等富文本消息渲染。
- 支持本地持久化，不要求后端服务；Android API Key 由 Android Keystore 加密保护。
- ZIP 备份会携带仍存在且满足大小限制的会话附件，导入时恢复到应用私有目录。
- 支持 Flutter 单元测试与 widget 测试。

## 技术栈

- Language: Dart
- Framework: Flutter
- State: `ChangeNotifier`
- Persistence: `shared_preferences`
- Network: `http`
- Markdown: `flutter_markdown_plus`
- Media/File: `image_picker`, `file_picker`, `mime`
- TTS: Android system TTS plus OpenAI-compatible remote speech providers
- Font: 内置霞鹜文楷（LXGW WenKai）子集用于诗意标题，正文使用系统无衬线字体
- Test: `flutter_test`

## 环境要求

- Flutter SDK：建议 `3.41.9` 或满足根目录 `pubspec.yaml` 中 Dart `sdk: ^3.11.5` 的稳定版本
- Dart SDK：`3.11.5` 或兼容版本，随 Flutter SDK 安装
- Android Studio（仅保留 Android 宿主工程；Flutter 3.41.9 默认最低 Android 7.0 / API 24）
- Git

可用以下命令检查环境：

```bash
flutter doctor
```

## 安装

```bash
git clone https://github.com/Suxinnai/Weaview.git
cd Weaview
flutter pub get
```

## 配置

织境不需要 `.env` 文件。请在 App 内进入「设置 > 提供商」配置模型服务。

常用配置项：

| 配置 | 说明 | 默认值 |
|---|---|---|
| AI Provider API Key | 模型服务 API Key，仅保存在本机；Android 上使用 Keystore 加密 | 无 |
| Base URL | OpenAI 兼容服务地址，例如 `https://api.openai.com/v1` | 按 provider 预设 |
| 模型 | 主对话、标题、建议、翻译、工具和生图角色分别分配，并校验模型能力 | 未分配 |
| Tavily API Key | 联网搜索服务 Key | 无 |
| TTS Provider | 语音合成服务配置，可手动启用系统或远程 TTS | 未启用 |
| Image Model | 生图模型，用于对话式生图 | 未分配 |
| Image Count | 单次生图输出数量，可选 1–4 张 | 1 张 |

安全约定：

- 不要提交真实 API Key、访问令牌、SharedPreferences 导出文件或本地截图。
- Gemini 没有隐藏的 build-time Key fallback；需要像其他 provider 一样在设置中显式配置。
- Base URL 支持 HTTP 与 HTTPS；使用 HTTP 时应用会显示明文传输警告，建议仅在可信网络中使用。
- JSON/ZIP 备份会屏蔽 API Key，不会导出可用凭据。

## 运行

开发运行：

```bash
flutter run
```

指定设备：

```bash
flutter devices
flutter run -d <device-id>
```

## 使用示例

1. 启动 App。
2. 打开「设置 > 提供商」，配置一个 OpenAI 兼容 provider 或 Gemini provider。
3. 打开「设置 > 模型」，为「主对话模型」和「生图模型」选择 provider 与模型。
4. 按需为标题、建议、翻译、人物画像和记忆整理等辅助角色分别选择兼容模型。
5. 返回聊天页，输入消息并发送。
6. 长按消息可编辑、删除或从当前消息创建分支。
7. 如需联网搜索，先在「设置 > 扩展服务」配置 Tavily，再在输入栏启用联网搜索。
8. 如需语音播报，在「设置 > 扩展服务」手动启用系统 TTS 或远程 TTS provider。
9. 如需生图，选择已配置的生图模型后直接在输入框中描述图片需求并发送。

OpenAI 兼容 provider 通常需要：

```text
Base URL: https://api.example.com/v1
Models API: GET /models
Chat API: POST /chat/completions
```

## 项目结构

```text
.
├── .github/                         # Issue/PR 模板与 CI
├── android/                         # Flutter Android 宿主工程源码，不是 APK 产物
├── assets/                          # App 图标与 provider 图标资源
├── lib/main.dart                    # App 入口
├── lib/src/app/                     # 应用装配、状态、偏好设置与安全凭据桥接
│   ├── services/                    # 会话、提供商、个性化与主题服务
│   └── prompt_appearance_intent.dart # 本地聊天外观提示解析
├── lib/src/core/                    # 通用工具函数与扩展
├── lib/src/data/                    # AI provider、搜索、流解析等外部服务接入
├── lib/src/domain/                  # 领域模型
├── lib/src/features/                # chat / history / settings 功能界面
├── lib/src/shared/                  # 共享组件和 view model
├── test/                            # 单元测试与 widget 测试
├── CHANGELOG.md
├── CONTRIBUTING.md
├── LICENSE
├── pubspec.yaml
└── README.md
```

说明：当前仓库保留 Android 宿主工程源码，用于编译、权限、原生能力和签名配置；iOS 宿主工程已移除。真正的 `.apk`、`.aab` 等包产物已在 `.gitignore` 中忽略，只通过 GitHub Releases 发布。

## 测试

```bash
flutter analyze
flutter test
```

运行指定测试：

```bash
flutter test test/model_config_resolver_test.dart
```

## 常用命令

| 命令 | 说明 |
|---|---|
| `flutter pub get` | 安装 Flutter 依赖 |
| `flutter run` | 启动开发环境 |
| `flutter analyze` | 静态分析 |
| `flutter test` | 运行测试 |
| `flutter build apk --debug` | 构建 Android debug 包 |
| `flutter build apk --release --split-per-abi` | 构建 Android release 分 ABI 包 |

## 构建与部署

预览 APK 可在 [GitHub Releases](https://github.com/Suxinnai/Weaview/releases) 下载。Release 构建不会回退到调试签名；缺少正式签名配置时会直接失败。

Android debug：

```bash
flutter build apk --debug
```

Android release：

```bash
export WEAVIEW_KEYSTORE_PATH=/absolute/path/to/weaview-release.jks
export WEAVIEW_KEYSTORE_PASSWORD='your-store-password'
export WEAVIEW_KEY_ALIAS='your-key-alias'
export WEAVIEW_KEY_PASSWORD='your-key-password'
flutter build apk --release --split-per-abi
```

GitHub Actions 的 `Android Release Build` 工作流需要配置同名密码/别名 Secret，以及 Base64 编码的 `WEAVIEW_RELEASE_KEYSTORE_BASE64`。这些值只注入构建环境，不写入仓库。

当前仓库不包含后端服务，也不提供 Docker 部署。

## API / Provider 说明

本项目本身不暴露 HTTP API。它作为客户端调用外部 AI/search provider：

| Provider 类型 | 接口 | 说明 |
|---|---|---|
| OpenAI-compatible | `GET /models` | 拉取模型列表 |
| Gemini native | `GET /v1beta/models` | 拉取 Gemini 模型列表并合并内置生图型号 |
| OpenAI-compatible | `POST /chat/completions` | 对话与流式输出 |
| Gemini | `POST /v1beta/models/{model}:generateContent` | Gemini 对话生成 |
| Tavily | Search API | 联网搜索 |
| OpenAI-compatible image | `POST /images/generations` | GPT Image、Grok Imagine、Recraft 等兼容服务 |
| OpenAI Responses-compatible | `POST /responses` | OpenAI 图片模型的 fallback 生图路径 |
| Gemini native image | `POST /v1beta/models/{model}:generateContent` | Gemini / Nano Banana 原生生图，使用 `responseModalities` |
| 火山方舟 image | `POST /api/v3/images/generations` | Seedream 5.0 / 4.0，支持参考图 |
| Stability AI | `POST /v2beta/stable-image/generate/*` | Stable Image Ultra / Core / SD 3.5 |
| Black Forest Labs | `POST /v1/{model}` + polling | FLUX.2 / FLUX 1.1，支持多参考图 |
| Ideogram | `POST /v1/ideogram-v*/generate` | Ideogram 4 / 3 官方 multipart 接口 |
| Replicate official models | `POST /v1/models/{owner}/{model}/predictions` | Imagen、Qwen Image、FLUX、Seedream、Recraft 等官方模型 |
| OpenAI Speech-compatible | `POST /audio/speech` | 远程语音合成 |
| Xiaomi MiMo TTS | `POST /chat/completions` | 流式 PCM16 语音合成 |

## Latest Release Notes / 最新更新日志

### v2.0.2

中文：

- 模型选择器升级为带高斯模糊的玻璃态界面，提供商、主题、关于页与设置层级同步精简。
- 新增翻译与标题生成默认模型配置，分支会话支持嵌套显示和分别折叠。
- 修复单图缺失，并以 PhotoStack 风格呈现多图结果。
- Android 凭据、备份导入和网络传输策略全面加固。

English:

- Upgraded the model picker to a Gaussian-blur glass interface and simplified providers, themes, About, and settings navigation.
- Added default translation and title-generation models plus independently collapsible nested conversation branches.
- Fixed missing single-image output and introduced PhotoStack-style multi-image results.
- Hardened Android credentials, backup import, and network transport policy.

完整历史见 [`docs/releases/v2.0.2.md`](./docs/releases/v2.0.2.md) 与 [`CHANGELOG.md`](./CHANGELOG.md)。

## 贡献指南

欢迎提交 Issue 或 Pull Request。开发流程：

1. Fork 本仓库。
2. 创建分支：`git checkout -b feature/your-change`。
3. 修改代码并运行 `flutter analyze`、`flutter test`。
4. 提交代码：`git commit -m "feat: describe your change"`。
5. 发起 Pull Request，并填写 PR 模板。

更多细节见 [CONTRIBUTING.md](./CONTRIBUTING.md)。

## Changelog

详见 [CHANGELOG.md](./CHANGELOG.md)。

## License

本项目基于 [MIT License](./LICENSE) 开源。
