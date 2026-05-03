# 织境 Flutter

这是从根目录 AI Studio / React 原型迁移出的 Flutter 移动端工程。React 版本保留为视觉与交互参考，Flutter 版本位于 `weaview_flutter/`。

## 运行

```bash
flutter pub get
flutter run
```

如需直接用环境注入 Gemini Key：

```bash
flutter run --dart-define=GEMINI_API_KEY=your_key
```

也可以在 App 内进入「设置 > 提供商 > Gemini」配置 API Key。Key 仅保存在本机 SharedPreferences 中。

## 验证

已在本机执行：

```bash
flutter analyze
flutter test
flutter build apk --debug
flutter run -d c1ac6e2 --debug --no-resident
```

Windows 路径包含中文时，Android Gradle/Kotlin 需要 `android.overridePathCheck=true` 且关闭 Kotlin 增量编译；这些配置已写入 `android/gradle.properties`。
