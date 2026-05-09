# 织境 Weaview

织境是一个以 Flutter 为核心的 AI 对话应用，面向希望自主管理模型提供商、对话记忆、联网搜索和移动端交互体验的用户与开发者。

## 简介

织境提供一个可本地配置的多模型聊天环境。它不内置任何真实 API Key，所有模型服务、搜索服务和语音服务凭据都需要用户在 App 设置中显式配置。

Latest stable / 最新正式版：`v1.0.11`

主要能力包括：

- 多提供商 AI 对话，支持 OpenAI 兼容接口与 Gemini 等 provider。
- 主对话、标题总结、后续建议、翻译等角色模型独立分配。
- 工具模型可独立分配，用于人物画像补全和长期记忆整理。
- 流式输出、思考状态、思考链解析与折叠展示。
- 生图对话模式，优先支持 OpenAI-compatible `/v1/images/generations`，对 OpenAI 图片模型保留 Responses image tool fallback，并支持 Gemini / Nano Banana 原生 `generateContent` 生图。
- 会话历史、会话分支、长期记忆、参考历史记忆和本地数据管理。
- 图片/文件附件入口、消息复制、编辑、删除、重试、翻译。
- Tavily 联网搜索配置入口。
- 手动启用的 TTS 服务配置，支持系统 TTS fallback 与远程 TTS provider。
- Flutter 移动端 UI，包含 Android 原生语音识别 fallback 与麦克风权限恢复引导。

English summary:

- Weaview is a Flutter AI chat app with configurable providers, role-based model assignment, streaming chat, memory, search, translation, image generation, TTS, and mobile-first interaction design.
- API keys are never bundled. Configure AI, search, image, and speech providers explicitly inside the app settings.
- Android voice input uses a native fallback and guides users to system microphone permissions when authorization is missing.

## Features

- 支持自定义 AI provider、Base URL、API Key 和模型列表。
- 支持 provider 拖拽排序、长按显示删除控制和预设 provider 安全合并。
- 支持 OpenAI-compatible `/v1/chat/completions` 流式响应。
- 支持 OpenAI-compatible `/v1/images/generations` 生图响应解析、OpenAI Responses image tool fallback，以及 Gemini 原生 `generateContent` 生图响应解析。
- 支持 Gemini `generateContent` 显式 provider 接入。
- 支持小米 MiMo `mimo-v2-tts` 流式 TTS 返回的 PCM16 音频，并自动封装为 WAV 播放。
- 支持 AI 生成主题指令的安全守卫，限制模型只能修改允许的聊天外观字段。
- 支持本地自然语言外观指令解析，聊天样式变更不必进入远端模型。
- 支持人物画像、助手昵称、用户资料和工具模型辅助整理。
- 支持 Markdown、代码块、公式块、思考链、翻译块等富文本消息渲染。
- 支持 SharedPreferences 本地持久化，不要求后端服务。
- 支持 Flutter 单元测试与 widget 测试。

## 技术栈

- Language: Dart
- Framework: Flutter
- State: `ChangeNotifier`
- Persistence: `shared_preferences`
- Network: `http`
- Markdown: `flutter_markdown_plus`
- Media/File: `image_picker`, `file_picker`, `mime`
- Speech: `speech_to_text` + Android native fallback
- Test: `flutter_test`

## 环境要求

- Flutter SDK：建议 `3.41.9` 或满足根目录 `pubspec.yaml` 中 Dart `sdk: ^3.11.5` 的稳定版本
- Dart SDK：`3.11.5` 或兼容版本，随 Flutter SDK 安装
- Android Studio / Xcode：按目标平台安装
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
| AI Provider API Key | 模型服务 API Key，仅保存在本机 SharedPreferences | 无 |
| Base URL | OpenAI 兼容服务地址，例如 `https://api.openai.com/v1` | 按 provider 预设 |
| 默认模型 | 主对话、标题总结、建议、翻译、工具任务各自使用的模型 | 未分配 |
| Tavily API Key | 联网搜索服务 Key | 无 |
| TTS Provider | 语音合成服务配置，可手动启用系统或远程 TTS | 未启用 |
| Image Model | 生图模型，用于对话式生图 | 未分配 |

安全约定：

- 不要提交真实 API Key、访问令牌、SharedPreferences 导出文件或本地截图。
- Gemini 没有隐藏的 build-time Key fallback；需要像其他 provider 一样在设置中显式配置。

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
3. 打开「设置 > 默认模型」，为「主对话模型」选择 provider 和模型。
4. 如需使用人物画像补全或记忆整理，继续为「工具模型」选择 provider 和模型。
5. 返回聊天页，输入消息并发送。
6. 长按消息可编辑、删除或从当前消息创建分支。
7. 如需联网搜索，先在「设置 > 扩展服务」配置 Tavily API Key，再在输入栏启用联网搜索。
8. 如需语音播报，先在「设置 > 扩展服务 > 语音服务」手动启用系统 TTS 或远程 TTS provider。
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
├── ios/                             # Flutter iOS 宿主工程源码，不是 IPA 产物
├── lib/main.dart                    # App 入口
├── lib/src/app/                     # 应用装配、状态、偏好设置、主题守卫
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

说明：`android/` 和 `ios/` 是 Flutter 项目必须提交的平台宿主源码，用于编译、权限、原生能力和签名配置；真正的 `.apk`、`.ipa`、`.aab`、`.xcarchive` 等包产物已在 `.gitignore` 中忽略，只通过 GitHub Releases 发布。

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

预览 APK 可在 [GitHub Releases](https://github.com/Suxinnai/Weaview/releases) 下载。当前 GitHub Release 包面向测试安装，仍使用仓库内 Android release 的调试签名配置，不等同于 Play Store 生产签名包。

Android debug：

```bash
flutter build apk --debug
```

Android release：

```bash
flutter build apk --release --split-per-abi
```

iOS 需要在 macOS + Xcode 环境下配置签名后构建：

```bash
flutter build ios
```

当前仓库不包含后端服务，也不提供 Docker 部署。

## API / Provider 说明

本项目本身不暴露 HTTP API。它作为客户端调用外部 AI/search provider：

| Provider 类型 | 接口 | 说明 |
|---|---|---|
| OpenAI-compatible | `GET /models` | 拉取模型列表 |
| OpenAI-compatible | `POST /chat/completions` | 对话与流式输出 |
| Gemini | `POST /v1beta/models/{model}:generateContent` | Gemini 对话生成 |
| Tavily | Search API | 联网搜索 |
| OpenAI-compatible image | `POST /images/generations` | 生图输出，适配 GPT Image、Imagen、Nano Banana、FLUX、Qwen Image、Grok Imagine 等模型 |
| OpenAI Responses-compatible | `POST /responses` | OpenAI 图片模型的 fallback 生图路径 |
| Gemini native image | `POST /v1beta/models/{model}:generateContent` | Gemini / Nano Banana 原生生图，使用 `responseModalities` |
| OpenAI Speech-compatible | `POST /audio/speech` | 远程语音合成 |
| Xiaomi MiMo TTS | `POST /chat/completions` | 流式 PCM16 语音合成 |

## Latest Release Notes / 最新更新日志

### v1.0.11

中文：

- 优化生图完成后的呈现效果，生成动画会更自然地过渡到图片附件。
- 移除聊天缩略图上的悬浮下载按钮，避免遮挡图片主体。
- 图片预览返回后不再自动弹出键盘。
- 图片预览界面支持长按保存到手机相册，Android 会保存到 `Pictures/Weaview`。

English:

- Improved the image-generation finish state so the loading animation transitions more naturally into the generated image attachment.
- Removed the floating download button from chat image thumbnails to avoid covering the image content.
- Prevented the keyboard from reopening after closing image preview.
- Added long-press save-to-gallery support in image preview; Android saves images to `Pictures/Weaview`.

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
