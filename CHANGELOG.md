# Changelog

本项目遵循简洁的变更记录格式。正式版本发布时会在这里记录用户可见变更、迁移提示和破坏性调整。

## 1.0.4-preview.1 - 2026-05-07

### 中文

- 修复 AI 输出 `<tool_call name="sync_gen_images">` 伪工具调用时只显示文本、未继续执行生图的问题。
- 优化 AI 回复消息操作栏与更多菜单定位，复制、重试、编辑、翻译、创建分支和删除入口不再被底部输入栏遮挡。
- 新增 AI 回复正文内联编辑，点击编辑后可直接在当前 AI 回复位置修改内容并保存；用户消息编辑只预填底部输入框，不再额外弹出提示。
- 消息操作按钮改为回复下方的独立圆形按钮，保留更多菜单的稳定锚点定位。
- 小米 MiMo TTS 增加 PCM16 分块播放路径，流式音频片段会直接写入 Android `AudioTrack`，减少播放前长时间等待。
- 修复 Android 语音识别已授权但系统识别器仍返回缺少权限时的 fallback 路径。
- 减少聊天输入栏上方的多余留白，降低浅色主题下的小白条遮挡。

### English

- Fixed pseudo tool-call image prompts such as `<tool_call name="sync_gen_images">` being rendered as text instead of launching image generation.
- Reworked AI message actions and overflow-menu anchoring so copy, retry, edit, translate, branch, and delete controls remain accessible above the input dock.
- Added inline editing for AI replies directly inside the rendered assistant message. User-message editing now only pre-fills the bottom input without showing an extra toast.
- Changed message actions into separate circular buttons below the reply while keeping the overflow menu anchored to the tapped button.
- Added Xiaomi MiMo PCM16 chunk playback through Android `AudioTrack`, so streaming TTS chunks can start playback without waiting for the full response.
- Added an Android voice-recognition fallback for cases where microphone permission is granted but the platform recognizer still reports insufficient permissions.
- Reduced extra bottom chat padding to avoid the light strip above the floating input dock.

## 1.0.3-preview.1 - 2026-05-07

### 中文

- 新增生图对话模式，支持 OpenAI Responses API 与 Codex 兼容 `/v1/images/generations` 路由，并将生图请求超时时间提升到 300 秒。
- 优化底部输入栏为透明悬浮玻璃效果，收窄顶部对话栏，为聊天内容保留更多可视空间。
- 接入远程 TTS 服务配置，新增小米 MiMo `mimo-v2-tts` 流式语音合成适配，并保留系统 TTS fallback。
- 修复 Android 语音输入在缺少麦克风权限时只提示失败的问题：现在会触发系统授权弹窗，并在拒绝后提供跳转系统权限页的恢复入口。
- 更新 provider、TTS、Markdown、主题守卫、生图解析与聊天 UI 相关测试。

### English

- Added image-generation chat mode with OpenAI Responses API and Codex-compatible `/v1/images/generations` support, with image requests allowed to run for up to 300 seconds.
- Refined the chat chrome with a floating transparent input dock and a tighter header to leave more room for conversation content.
- Added remote TTS configuration support, including Xiaomi MiMo `mimo-v2-tts` streaming synthesis, while keeping system TTS fallback behavior.
- Fixed Android voice input recovery when microphone permission is missing: the app now triggers the system permission prompt and offers a shortcut to app permission settings after denial.
- Updated tests around providers, TTS, Markdown rendering, theme guards, image-generation parsing, and chat UI behavior.

## 1.0.2 - 2026-05-07

- 将 Flutter 工程从 `weaview_flutter/` 上移到仓库根目录，开发者 clone 后可直接运行 `flutter pub get`、`flutter run`。
- 明确 `android/` 与 `ios/` 是平台宿主源码目录，并通过 `.gitignore` 屏蔽 APK、IPA、AAB、xcarchive 等构建产物。
- 发布基于根目录 Flutter 工程结构的 Android 预览安装包。

## 1.0.1 - 2026-05-04

- 标准化开源项目文件：README、CONTRIBUTING、LICENSE、GitHub Issue/PR 模板和 Flutter CI。
- 保留 Flutter App 主工程，明确项目结构、运行方式、测试方式和贡献流程。
- 新增工具模型角色，用于人物画像补全和长期记忆整理。
- 支持消息编辑、删除和从指定消息创建会话分支。
- 支持 provider 拖拽排序、长按删除控制和本地配置持久化。
- 将本地聊天外观提示解析从 `WeaviewState` 拆分为纯 Dart 模块并补充单元测试。
- 更新 README，补充运行、配置、贡献和 GitHub Release 下载说明。

## 1.0.0

- Flutter 移动端初始版本。
- 支持多 provider 模型配置、聊天、历史、记忆、翻译、联网搜索配置和语音输入。
