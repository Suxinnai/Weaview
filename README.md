# 织境 Weaview

织境是一个以 Flutter 为核心的 AI 对话应用，面向希望自主管理模型提供商、对话记忆、联网搜索和移动端交互体验的用户与开发者。

## 简介

织境提供一个可本地配置的多模型聊天环境。它不内置任何真实 API Key，所有模型服务、搜索服务和语音服务凭据都需要用户在 App 设置中显式配置。

主要能力包括：

- 多提供商 AI 对话，支持 OpenAI 兼容接口与 Gemini 等 provider。
- 主对话、标题总结、后续建议、翻译等角色模型独立分配。
- 工具模型可独立分配，用于人物画像补全和长期记忆整理。
- 流式输出、思考状态、思考链解析与折叠展示。
- 会话历史、会话分支、长期记忆、参考历史记忆和本地数据管理。
- 图片/文件附件入口、消息复制、编辑、删除、重试、翻译。
- Tavily 联网搜索配置入口。
- Flutter 移动端 UI，包含 Android 原生语音识别 fallback。

## Features

- 支持自定义 AI provider、Base URL、API Key 和模型列表。
- 支持 provider 拖拽排序、长按显示删除控制和预设 provider 安全合并。
- 支持 OpenAI-compatible `/v1/chat/completions` 流式响应。
- 支持 Gemini `generateContent` 显式 provider 接入。
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

- Flutter SDK：建议 `3.41.9` 或满足 `weaview_flutter/pubspec.yaml` 中 Dart `sdk: ^3.11.5` 的稳定版本
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
cd Weaview/weaview_flutter
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
| TTS Provider | 语音合成服务配置 | 系统 TTS |

安全约定：

- 不要提交真实 API Key、访问令牌、SharedPreferences 导出文件或本地截图。
- Gemini 没有隐藏的 build-time Key fallback；需要像其他 provider 一样在设置中显式配置。

## 运行

开发运行：

```bash
cd weaview_flutter
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
├── weaview_flutter/                 # Flutter App 主工程
│   ├── lib/main.dart                # App 入口
│   ├── lib/src/app/                 # 应用装配、状态、偏好设置、主题守卫
│   │   └── prompt_appearance_intent.dart # 本地聊天外观提示解析
│   ├── lib/src/core/                # 通用工具函数与扩展
│   ├── lib/src/data/                # AI provider、搜索、流解析等外部服务接入
│   ├── lib/src/domain/              # 领域模型
│   ├── lib/src/features/            # chat / history / settings 功能界面
│   ├── lib/src/shared/              # 共享组件和 view model
│   └── test/                        # 单元测试与 widget 测试
├── CHANGELOG.md
├── CONTRIBUTING.md
├── LICENSE
└── README.md
```

## 测试

```bash
cd weaview_flutter
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
cd weaview_flutter
flutter build apk --debug
```

Android release：

```bash
cd weaview_flutter
flutter build apk --release --split-per-abi
```

iOS 需要在 macOS + Xcode 环境下配置签名后构建：

```bash
cd weaview_flutter
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
