# 织境 Weaview

织境是一款以 Flutter 移动端为核心的 AI 对话应用，目标是提供高质量的多模型对话、记忆、搜索、翻译与语音输入体验。

当前主工程位于 [`weaview_flutter/`](./weaview_flutter)。早期 Google AI Studio / React 原型文件已移除，仓库现在只保留可继续维护和交付的 Flutter App。

## 功能概览

- 多供应商模型配置，支持 OpenAI 兼容接口、Gemini 及内置供应商预设。
- 主对话、标题总结、聊天建议、翻译等角色模型可独立分配。
- 流式输出、思考动画、思考链默认折叠并支持展开查看。
- 对话历史、新建对话、复制、重试、翻译、附件与图片上传入口。
- Tavily 网络搜索配置入口。
- 记忆管理、全局记忆、参考历史记忆开关。
- 独立设置页面，包含通用、提供商、默认模型、扩展服务、数据管理等配置。
- Android 原生语音识别 fallback，用于补足 Flutter 语音插件不可用的场景。
- Android / iOS 启动图标已替换为织境图标。

## 项目结构

```text
.
├── weaview_flutter/             # Flutter 移动端主工程
│   ├── lib/main.dart            # App 入口与全局常量
│   ├── lib/src/ai_gateway.dart  # AI、搜索、流式解析与模型拉取
│   ├── lib/src/app_state.dart   # 应用状态与持久化
│   ├── lib/src/chat_home.dart   # 聊天主界面
│   ├── lib/src/message_widgets.dart
│   ├── lib/src/models.dart
│   ├── lib/src/settings_sheet.dart
│   ├── lib/src/sidebar_overlay.dart
│   └── test/widget_test.dart
└── README.md
```

## Flutter 开发

进入 Flutter 工程：

```bash
cd weaview_flutter
flutter pub get
flutter run
```

如需通过启动参数注入 Gemini Key：

```bash
flutter run --dart-define=GEMINI_API_KEY=your_key
```

也可以在 App 内进入「设置 > 提供商」配置各类 API Key。密钥只应保存在本机运行环境中，不应提交到仓库。

## 构建

Debug 包：

```bash
cd weaview_flutter
flutter build apk --debug
```

Release 分 ABI 包：

```bash
cd weaview_flutter
flutter build apk --release --split-per-abi
```

Release 分 ABI 后，Android 包体积会明显低于 debug / universal 包。首次看到 200MB 以上通常是 debug 包或通用包体积，不代表最终分发体积。

## 测试与检查

```bash
cd weaview_flutter
flutter analyze
flutter test
```

最近一次验证包含：

- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`
- `flutter build apk --release --split-per-abi`
- Android 真机聊天、流式输出、思考链、翻译、设置返回、输入框键盘适配等流程

## 配置说明

- 提供商配置支持自定义 Base URL 与 API Key。
- OpenAI 兼容服务需要提供 `/v1/models` 与 `/v1/chat/completions`。
- 搜索服务当前主要接入 Tavily。
- 语音输入依赖设备上的系统语音服务；如果 Google 语音服务不可用或设备网络不可达，App 会给出提示，但无法绕过系统服务限制。

## 注意事项

- 不要提交真实 API Key、访问令牌、SharedPreferences 导出文件或本地测试截图。
- `build/`、`.dart_tool/`、`.omx/` 等本地生成目录已在 `.gitignore` 中排除。
- Windows 路径包含中文时，Android Gradle/Kotlin 相关兼容配置已写入 `weaview_flutter/android/gradle.properties`。
