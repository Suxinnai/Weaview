import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:weaview_flutter/src/app/app_constants.dart';
import 'package:weaview_flutter/src/app/weaview_app.dart';
import 'package:weaview_flutter/src/app/weaview_state.dart';
import 'package:weaview_flutter/src/core/app_utils.dart';
import 'package:weaview_flutter/src/data/ai/ai_gateway.dart';
import 'package:weaview_flutter/src/domain/models.dart';
import 'package:weaview_flutter/src/features/chat/chat_home.dart';
import 'package:weaview_flutter/src/features/chat/sections/chat_input_dock.dart';
import 'package:weaview_flutter/src/features/chat/sections/chat_model_dropdown.dart';
import 'package:weaview_flutter/src/features/settings/settings_sheet.dart';

void main() {
  test('exposes the current stable version in app constants', () {
    expect(appVersionTag, 'v1.0.26');
    expect(appVersionDisplay, contains('v1.0.26'));
  });

  testWidgets('renders the Weaview chat shell', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const WeaviewApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('今天，你想编织什么梦境？'), findsOneWidget);
    expect(find.text('新梦境'), findsOneWidget);
    expect(find.text('编织'), findsOneWidget);
  });

  testWidgets('renders rich AI markdown code, formula, and table blocks', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();

    await state.load();
    state.messages.add(
      ChatMessage.model(r'''```dart
void main() {}
```

$$E = mc^2$$

| 字段 | 说明 |
| --- | --- |
| 状态 | 正常 |'''),
    );

    await tester.pumpWidget(MaterialApp(home: WeaviewHome(state: state)));
    await tester.pump();

    expect(find.text('DART'), findsOneWidget);
    expect(find.text('void main() {}'), findsOneWidget);
    expect(find.text('公式'), findsOneWidget);
    expect(find.text('E = mc^2'), findsOneWidget);
    expect(find.text('表格'), findsOneWidget);
    expect(find.text('字段'), findsOneWidget);
    expect(find.text('状态'), findsOneWidget);
    state.dispose();
  });

  testWidgets('keeps AI prose regular-weight and justified', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();

    await state.load();
    state.fontWeightMood = 'bold';
    state.messages.add(
      ChatMessage.model(
        '这是一段用于验证正文层级的普通文本，它需要保持常规字重并支持两端对齐，不能被全局加粗设置误伤。**重点**只应该略微更醒目。',
      ),
    );

    await tester.pumpWidget(MaterialApp(home: WeaviewHome(state: state)));
    await tester.pump();

    final paragraph = tester.widget<SelectableText>(
      find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText &&
            widget.textSpan?.toPlainText().contains('正文层级') == true,
      ),
    );
    expect(paragraph.textAlign, TextAlign.justify);
    final rootStyle = paragraph.textSpan!.style!;
    expect(rootStyle.fontWeight, FontWeight.w400);
    final strongSpan = paragraph.textSpan!.children!
        .whereType<TextSpan>()
        .firstWhere((span) => span.text == '重点');
    expect(strongSpan.style!.fontWeight, FontWeight.w600);
    state.dispose();
  });

  test('keeps role model assignments explicit by default', () {
    final assignments = ModelAssignment.defaults();

    for (final assignment in assignments.values) {
      expect(assignment.provider, isEmpty);
      expect(assignment.model, isEmpty);
    }
    expect(assignments.keys, contains('tool'));
  });

  test(
    'ships expected provider presets without enabling Gemini implicitly',
    () {
      final providers = AiProvider.defaults();
      final names = providers.map((provider) => provider.name).toSet();
      final urls = {
        for (final provider in providers) provider.name: provider.baseUrl,
      };

      expect(names, containsAll(['OpenAI', 'Gemini', 'DeepSeek', 'Kimi']));
      expect(providers.where((provider) => provider.current), isEmpty);
      expect(urls['OpenAI'], 'https://api.openai.com/v1');
      expect(urls['Gemini'], contains('/openai'));
      expect(urls['DeepSeek'], 'https://api.deepseek.com');
      expect(urls['Kimi'], 'https://api.moonshot.cn/v1');
    },
  );

  test('keeps TTS disabled until a service is manually selected', () async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();

    await state.load();

    expect(state.activeTtsId, isEmpty);
    expect(state.ttsEnabled, isFalse);
    expect(
      state.ttsProviders.map((provider) => provider.id),
      contains('openai'),
    );
    expect(
      state.ttsProviders
          .firstWhere((provider) => provider.id == 'openai')
          .baseUrl,
      'https://api.openai.com/v1',
    );
    final xiaomi = state.ttsProviders.firstWhere(
      (provider) => provider.id == 'xiaomi',
    );
    expect(xiaomi.type, 'xiaomi');
    expect(xiaomi.baseUrl, 'https://api.xiaomimimo.com/v1');
    expect(xiaomi.model, 'mimo-v2-tts');
    expect(xiaomi.voice, 'default_en');
    state.dispose();
  });

  test('fills existing Xiaomi TTS config from official preset', () async {
    SharedPreferences.setMockInitialValues({
      'ai_tts_providers':
          '[{"id":"xiaomi","type":"custom","name":"Xiaomi MiMo TTS","apiKey":"","baseUrl":"","model":"","voice":""}]',
    });
    final state = WeaviewState();

    await state.load();

    final xiaomi = state.ttsProviders.firstWhere(
      (provider) => provider.id == 'xiaomi',
    );
    expect(xiaomi.type, 'xiaomi');
    expect(xiaomi.baseUrl, 'https://api.xiaomimimo.com/v1');
    expect(xiaomi.model, 'mimo-v2-tts');
    expect(xiaomi.voice, 'default_en');
    state.dispose();
  });

  test('merges saved TTS providers with new built-in defaults', () async {
    SharedPreferences.setMockInitialValues({
      'ai_active_tts_id': 'legacy',
      'ai_tts_providers':
          '[{"id":"legacy","type":"openai","name":"Legacy TTS","apiKey":"key","baseUrl":"https://tts.example/v1","model":"tts","voice":"alloy"}]',
    });
    final state = WeaviewState();

    await state.load();

    expect(state.activeTtsId, 'legacy');
    expect(
      state.ttsProviders.map((provider) => provider.id),
      contains('openai'),
    );
    expect(
      state.ttsProviders.map((provider) => provider.id),
      contains('legacy'),
    );
    state.dispose();
  });

  test('starts with no seeded user memories', () async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();

    await state.load();

    expect(state.memories, isEmpty);
    state.dispose();
  });

  test('merges saved providers with built-in provider presets', () async {
    SharedPreferences.setMockInitialValues({
      'ai_providers':
          '{"name":"Custom","status":"已连接","current":true,"colorHex":"#10B981","apiKey":"x","baseUrl":"https://example.invalid/v1","models":[]}',
    });
    final state = WeaviewState();

    await state.load();

    final names = state.providers.map((provider) => provider.name).toSet();
    expect(names, containsAll(['Custom', 'Gemini', 'DeepSeek', 'OpenAI']));
    state.dispose();
  });

  test('fills saved built-in provider base URLs from presets', () async {
    SharedPreferences.setMockInitialValues({
      'ai_providers':
          '[{"name":"OpenAI","status":"未配置","current":false,"colorHex":"#10B981","apiKey":"","baseUrl":"","models":[]}]',
    });
    final state = WeaviewState();

    await state.load();

    final openai = state.providers.firstWhere(
      (provider) => provider.name == 'OpenAI',
    );
    expect(openai.baseUrl, 'https://api.openai.com/v1');
    state.dispose();
  });

  test('deduplicates saved provider models by id', () async {
    SharedPreferences.setMockInitialValues({
      'ai_providers':
          '[{"name":"Custom","status":"已连接","current":true,"colorHex":"#10B981","apiKey":"x","baseUrl":"https://example.invalid/v1","models":[{"id":"same/model","name":"same/model","capabilities":["chat"]},{"id":"same/model","name":"same/model","capabilities":["chat","reason"]}]}]',
    });
    final state = WeaviewState();

    await state.load();

    final custom = state.providers.firstWhere((item) => item.name == 'Custom');
    expect(custom.models, hasLength(1));
    expect(custom.models.single.id, 'same/model');
    state.dispose();
  });

  test('image generation keeps attachments on the user message', () async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();

    await state.load();
    await state.submitImageGeneration(
      '参考这张图生成',
      attachments: const [
        MessageAttachment(
          path: '/tmp/reference.png',
          name: 'reference.png',
          mimeType: 'image/png',
          kind: 'image',
          size: 12,
        ),
      ],
    );

    expect(state.messages.first.role, 'user');
    expect(state.messages.first.attachments.single.name, 'reference.png');
    expect(state.messages.last.content, contains('生图模型'));
    state.dispose();
  });

  test(
    'retrying image replies does not apply chat appearance intents',
    () async {
      SharedPreferences.setMockInitialValues({});
      final state = WeaviewState();

      await state.load();
      state.messages
        ..add(ChatMessage.user('背景改成黑色'))
        ..add(
          ChatMessage.model('')
            ..attachments = const [
              MessageAttachment(
                path: '/tmp/generated.png',
                name: 'generated.png',
                mimeType: 'image/png',
                kind: 'image',
                size: 12,
              ),
            ],
        );

      await state.retryMessageAt(1);

      expect(state.backgroundOverride, isNull);
      expect(state.messages.first.role, 'user');
      expect(state.messages.first.content, '背景改成黑色');
      expect(state.messages.last.content, contains('生图模型'));
      state.dispose();
    },
  );

  test(
    'image generation follow-up reuses previous generated and source images',
    () async {
      SharedPreferences.setMockInitialValues({});
      final tempDir = await Directory.systemTemp.createTemp(
        'weaview-follow-up-',
      );
      final original = File('${tempDir.path}/original.png');
      final previous = File('${tempDir.path}/previous.png');
      await original.writeAsBytes([0x89, 0x50, 0x4E, 0x47]);
      await previous.writeAsBytes([0x89, 0x50, 0x4E, 0x47]);
      final state = WeaviewState();

      await state.load();
      state.messages
        ..add(
          ChatMessage.user(
            '把这张图做成手绘注解',
            attachments: [
              MessageAttachment(
                path: original.path,
                name: 'original.png',
                mimeType: 'image/png',
                kind: 'image',
                size: await original.length(),
              ),
            ],
          ),
        )
        ..add(
          ChatMessage.model('')
            ..attachments = [
              MessageAttachment(
                path: previous.path,
                name: 'previous.png',
                mimeType: 'image/png',
                kind: 'image',
                size: await previous.length(),
              ),
            ],
        );
      await state.submitImageGeneration('图片比例我要原比例的');

      final user = state.messages.lastWhere(
        (message) => message.role == 'user',
      );
      expect(user.attachments.map((item) => item.path), [
        previous.path,
        original.path,
      ]);
      expect(state.messages.last.content, contains('生图模型'));
      state.dispose();
      await tempDir.delete(recursive: true);
    },
  );

  test(
    'image generation follow-up derives landscape size from source image',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('weaview-aspect-');
      final original = File('${tempDir.path}/original.png');
      final previous = File('${tempDir.path}/previous.png');
      final png = base64Decode(_png16x9);
      await original.writeAsBytes(png);
      await previous.writeAsBytes(base64Decode(_png1x1));
      SharedPreferences.setMockInitialValues({});
      final state = WeaviewState();

      try {
        await state.load();
        state.messages
          ..add(
            ChatMessage.user(
              '把这张图做成手绘注解',
              attachments: [
                MessageAttachment(
                  path: original.path,
                  name: 'original.png',
                  mimeType: 'image/png',
                  kind: 'image',
                  size: await original.length(),
                ),
              ],
            ),
          )
          ..add(
            ChatMessage.model('')
              ..attachments = [
                MessageAttachment(
                  path: previous.path,
                  name: 'previous.png',
                  mimeType: 'image/png',
                  kind: 'image',
                  size: await previous.length(),
                ),
              ],
          );

        final prepared = await state.debugPrepareImageGenerationRequest(
          '图片比例我要原比例的',
        );

        expect(prepared['size'], '1536x1024');
        expect(prepared['prompt'], contains('严格使用 16:9 画幅生成'));
        expect(
          prepared['attachmentPaths'],
          '${previous.path}|${original.path}',
        );
      } finally {
        state.dispose();
        await tempDir.delete(recursive: true);
      }
    },
  );

  test('reorders providers and keeps order in state', () async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();

    await state.load();
    final first = state.providers.first.name;
    final second = state.providers[1].name;

    state.reorderProvider(0, 2);

    expect(state.providers[0].name, second);
    expect(state.providers[1].name, first);
    state.dispose();
  });

  test('exports local data as a zip archive', () async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();

    await state.load();
    state.messages.add(ChatMessage.user('导出测试'));
    final bytes = state.exportZipBytes();

    expect(bytes.take(4).toList(), [0x50, 0x4B, 0x03, 0x04]);
    expect(String.fromCharCodes(bytes), contains('weaview-export.json'));
    state.dispose();
  });

  test('pins and deletes history sessions predictably', () async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();

    await state.load();
    state.chatSessions
      ..add(
        ChatSession(id: 'old', title: '旧梦境', updatedAt: 1, messages: const []),
      )
      ..add(
        ChatSession(id: 'new', title: '新梦境', updatedAt: 2, messages: const []),
      );

    state.togglePinSession('old');

    expect(state.chatSessions.first.id, 'old');
    expect(state.chatSessions.first.pinned, isTrue);

    state.deleteSession('old');

    expect(state.chatSessions.map((s) => s.id), isNot(contains('old')));
    state.dispose();
  });

  test(
    'chat model list only exposes configured providers with models',
    () async {
      SharedPreferences.setMockInitialValues({});
      final state = WeaviewState();

      await state.load();
      state.saveProviders([
        AiProvider.defaults().first.copyWith(
          apiKey: 'key',
          status: '已连接',
          models: const [
            AiModel(id: 'gpt-test', name: 'gpt-test', capabilities: ['chat']),
          ],
        ),
        AiProvider.defaults()[1].copyWith(
          models: const [
            AiModel(
              id: 'gemini-test',
              name: 'gemini-test',
              capabilities: ['chat'],
            ),
          ],
        ),
      ]);

      expect(state.enabledModelProviders.map((p) => p.name), ['OpenAI']);
      state.dispose();
    },
  );

  testWidgets('chat model picker displays saved model capabilities', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();
    final search = TextEditingController();

    await state.load();
    state.saveProviders([
      AiProvider.defaults().first.copyWith(
        apiKey: 'key',
        status: '使用中',
        current: true,
        models: const [
          AiModel(
            id: 'custom-vision-tool',
            name: 'custom-vision-tool',
            capabilities: ['chat', 'vision', 'tool', 'reason'],
          ),
        ],
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              ChatModelDropdown(
                state: state,
                modelSearchController: search,
                open: true,
                imageGenerationMode: false,
                onClose: () {},
                onOpenSettings: () {},
                onSearchChanged: () {},
                onSelectModel: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('custom-vision-tool'), findsOneWidget);
    expect(find.text('视觉'), findsOneWidget);
    expect(find.text('工具'), findsOneWidget);
    expect(find.text('推理'), findsOneWidget);

    search.dispose();
    state.dispose();
  });

  testWidgets('long composer text hides inline web search and shows expand', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();
    final controller = TextEditingController(text: '第一行\n第二行\n第三行\n第四行继续输入');
    final focusNode = FocusNode();

    await state.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInputDock(
            state: state,
            inputController: controller,
            inputFocusNode: focusNode,
            wave: const AlwaysStoppedAnimation<double>(0),
            recording: false,
            webSearchEnabled: false,
            imageGenerationMode: false,
            dockExpanded: false,
            pendingAttachments: const [],
            onToggleExpanded: () {},
            onToggleWebSearch: () {},
            onSubmit: () async {},
            onToggleRecording: () async {},
            onPickChatImages: () async {},
            onPickChatFiles: () async {},
            onRemoveAttachment: (_) {},
            onTextChanged: () {},
            onHeightChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.public_rounded), findsNothing);
    expect(find.byIcon(Icons.open_in_full_rounded), findsOneWidget);

    focusNode.dispose();
    controller.dispose();
    state.dispose();
  });

  testWidgets(
    'provider cards reveal delete on long press and hide on blank tap',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final state = WeaviewState();

      await state.load();
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsSheet(
            state: state,
            open: true,
            onClose: () {},
            onPickAvatar: (_) async {},
            showSnack: (_) {},
          ),
        ),
      );

      await tester.tap(find.text('提供商'));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('OpenAI'));
      await tester.pumpAndSettle();

      final sheetState = tester.state<SettingsSheetState>(
        find.byType(SettingsSheet),
      );
      expect(sheetState.providerDeleteTarget, 'OpenAI');
      expect(
        find.byKey(const ValueKey('provider_delete_OpenAI')),
        findsOneWidget,
      );

      await tester.tap(find.text('模型提供商'));
      await tester.pumpAndSettle();

      expect(sheetState.providerDeleteTarget, isNull);
      expect(
        find.byKey(const ValueKey('provider_delete_OpenAI')),
        findsNothing,
      );
      state.dispose();
    },
  );

  testWidgets('provider cards mark assigned providers as selected', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();

    await state.load();
    state.saveModelAssignment(
      'image',
      const ModelAssignment(
        provider: 'OpenAI',
        model: 'gpt-image-2',
        prompt: '',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsSheet(
          state: state,
          open: true,
          onClose: () {},
          onPickAvatar: (_) async {},
          showSnack: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('提供商'));
    await tester.pumpAndSettle();

    expect(find.text('已选择'), findsOneWidget);
    state.dispose();
  });

  test('creates conversation branch from selected message', () async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();

    await state.load();
    state.messages
      ..add(ChatMessage.user('原始问题'))
      ..add(ChatMessage.model('原始回答'))
      ..add(ChatMessage.user('后续问题'));

    state.createBranchAt(1);

    expect(state.currentSessionId, startsWith('branch_'));
    expect(state.messages, hasLength(2));
    expect(state.chatSessions.first.title, startsWith('分支'));
    state.dispose();
  });

  test('loads assistant name and user profile preferences', () async {
    SharedPreferences.setMockInitialValues({
      'assistant_name': '沐灵',
      'user_profile': '用户正在开发 Flutter AI 助手。',
    });
    final state = WeaviewState();

    await state.load();

    expect(state.assistantName, '沐灵');
    expect(state.userProfile, contains('Flutter'));
    state.dispose();
  });

  test('keeps user display name in the user profile context', () async {
    SharedPreferences.setMockInitialValues({'user_name': '沐灵'});
    final state = WeaviewState();

    await state.load();

    expect(state.userProfile, contains('用户称呼：沐灵'));

    state.updateUserProfile('用户偏好简洁直接的回答。');
    state.updateUserName('星野');

    expect(state.userProfile, contains('用户称呼：星野'));
    expect(state.userProfile, contains('用户偏好简洁直接的回答。'));
    expect(state.userProfile, isNot(contains('沐灵')));
    state.dispose();
  });

  test('parses OpenAI compatible stream content and reasoning deltas', () {
    final content = AiGateway.parseOpenAiStreamData(
      '{"choices":[{"delta":{"content":"你好"}}]}',
    );
    final reasoning = AiGateway.parseOpenAiStreamData(
      '{"choices":[{"delta":{"reasoning_content":"正在分析"}}]}',
    );

    expect(content.contentDelta, '你好');
    expect(content.reasoningDelta, isEmpty);
    expect(reasoning.contentDelta, isEmpty);
    expect(reasoning.reasoningDelta, '正在分析');
  });

  test(
    'AI theme reset clears overrides and contrast guard fixes text',
    () async {
      SharedPreferences.setMockInitialValues({});
      final state = WeaviewState();

      await state.load();
      state.applyAiTheme({
        'backgroundColor': '#FFFFFF',
        'textColor': '#FFFFFF',
      });

      expect(colorToHex(state.backgroundOverride!), '#FFFFFF');
      expect(colorToHex(state.textOverride!), isNot('#FFFFFF'));

      state.applyAiTheme({'resetTheme': true});

      expect(state.backgroundOverride, isNull);
      expect(state.textOverride, isNull);
      expect(state.fontMood, 'sans');
      expect(state.fontStyleMood, 'normal');
      expect(state.fontWeightMood, 'normal');
      expect(state.bubbleStyle, 'minimal');
      expect(state.messageAlignment, 'left');
      expect(state.themeMode, ThemeMode.system);
      state.dispose();
    },
  );

  testWidgets('custom dark AI theme drives dark chrome surfaces', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();

    await state.load();
    state.applyAiTheme({'backgroundColor': '#1A1A2E', 'textColor': '#E5E7EB'});

    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(state.isDark(capturedContext), isTrue);
    expect(state.layer(capturedContext).computeLuminance(), lessThan(0.2));
    expect(state.text(capturedContext).computeLuminance(), greaterThan(0.5));
    state.dispose();
  });

  testWidgets(
    'theme text stays readable when a stale override is low contrast',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final state = WeaviewState();

      await state.load();
      state.backgroundOverride = const Color(0xFFFFFFFF);
      state.textOverride = const Color(0xFFFFFFFF);

      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(colorToHex(state.text(capturedContext)), '#2C3E50');
      state.dispose();
    },
  );

  test('AI theme applies chat bubble style controls', () async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();

    await state.load();
    state.applyAiTheme({
      'bubbleStyle': 'glass',
      'bubbleOpacity': 0.4,
      'bubbleColor': '#3366FF',
      'messageAlignment': 'center',
      'fontStyle': 'italic',
      'fontWeight': 'bold',
    });

    expect(state.bubbleStyle, 'glass');
    expect(state.assistantBubbleOpacity, 0.4);
    expect(state.userBubbleOpacity, 0.4);
    expect(colorToHex(state.assistantBubbleOverride!), '#3366FF');
    expect(colorToHex(state.userBubbleOverride!), '#3366FF');
    expect(state.messageAlignment, 'center');
    expect(state.fontStyleMood, 'italic');
    expect(state.fontWeightMood, 'bold');
    state.dispose();
  });

  test('chat style prompt applies pink text locally', () async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();

    await state.load();
    await state.submitMessage('字体颜色改成粉色');

    expect(state.textOverride, isNotNull);
    expect(colorToHex(state.textOverride!), '#C9226C');
    state.dispose();
  });

  test('chat style prompt can remove bubbles locally', () async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();

    await state.load();
    await state.submitMessage('对话气泡透明度调整为0');

    expect(state.bubbleStyle, 'none');
    expect(state.assistantBubbleOpacity, 0);
    expect(state.userBubbleOpacity, 0);
    state.dispose();
  });

  test('bubble removal request cannot rewrite the global theme', () async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();

    await state.load();
    state.applyAiTheme({
      'resetTheme': true,
      'backgroundColor': '#000000',
      'textColor': '#FFFFFF',
      'fontFamily': 'serif',
      'messageAlignment': 'center',
      'bubbleStyle': 'solid',
      'bubbleColor': '#FF0000',
    }, userPrompt: '去掉气泡');

    expect(state.backgroundOverride, isNull);
    expect(state.textOverride, isNull);
    expect(state.fontMood, 'sans');
    expect(state.messageAlignment, 'left');
    expect(state.bubbleStyle, 'none');
    expect(state.assistantBubbleOpacity, 0);
    expect(state.userBubbleOpacity, 0);
    expect(state.assistantBubbleOverride, isNull);
    expect(state.userBubbleOverride, isNull);
    state.dispose();
  });

  test('bubble style request only changes bubble fields', () async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();

    await state.load();
    state.applyAiTheme({
      'backgroundColor': '#000000',
      'textColor': '#FFFFFF',
      'fontFamily': 'serif',
      'bubbleStyle': 'glass',
      'bubbleOpacity': 0.25,
    }, userPrompt: '把气泡改成透明一点');

    expect(state.backgroundOverride, isNull);
    expect(state.textOverride, isNull);
    expect(state.fontMood, 'sans');
    expect(state.bubbleStyle, 'glass');
    expect(state.assistantBubbleOpacity, 0.25);
    expect(state.userBubbleOpacity, 0.25);
    state.dispose();
  });

  test('font style request only changes font fields', () async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();

    await state.load();
    state.applyAiTheme({
      'backgroundColor': '#000000',
      'bubbleStyle': 'solid',
      'fontFamily': 'serif',
      'fontStyle': 'italic',
      'fontWeight': 'bold',
    }, userPrompt: '把字体改成斜体加粗的衬线字体');

    expect(state.backgroundOverride, isNull);
    expect(state.bubbleStyle, 'minimal');
    expect(state.fontMood, 'serif');
    expect(state.fontStyleMood, 'italic');
    expect(state.fontWeightMood, 'bold');
    state.dispose();
  });

  test('background style request only changes background fields', () async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();

    await state.load();
    state.applyAiTheme({
      'backgroundColor': '#000000',
      'textColor': '#FFFFFF',
      'bubbleStyle': 'solid',
      'fontStyle': 'italic',
    }, userPrompt: '把背景改成黑色');

    expect(colorToHex(state.backgroundOverride!), '#000000');
    expect(state.textOverride, isNull);
    expect(state.bubbleStyle, 'minimal');
    expect(state.fontStyleMood, 'normal');
    state.dispose();
  });

  test('manual light theme clears stale AI background overrides', () async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();

    await state.load();
    state.applyAiTheme({'backgroundColor': '#000000'});

    expect(colorToHex(state.backgroundOverride!), '#000000');
    expect(state.themeMode, ThemeMode.dark);

    state.setThemeModeValue(ThemeMode.light);

    expect(state.themeMode, ThemeMode.light);
    expect(state.effectiveThemeMode, ThemeMode.light);
    expect(state.backgroundOverride, isNull);
    expect(state.textOverride, isNull);
    state.dispose();
  });

  test('loading manual light theme ignores stale dark AI background', () async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': 'light',
      'theme_background': '#000000',
      'theme_text': '#FFFFFF',
    });
    final state = WeaviewState();

    await state.load();

    expect(state.themeMode, ThemeMode.light);
    expect(state.effectiveThemeMode, ThemeMode.light);
    expect(state.backgroundOverride, isNull);
    expect(state.textOverride, isNull);
    state.dispose();
  });
}

const _png16x9 =
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAJCAYAAAA7KqwyAAAAE0lEQVR4nGP4TyFgGDVg1AAgAAC2ij3f20IaMgAAAABJRU5ErkJggg==';
const _png1x1 =
    'iVBORw0KGgoAAAANSUhEUgAAAAkAAAAJCAYAAADgkQYQAAAAEUlEQVR4nGP4TwRgGFVElCIA9NJCzAnd59wAAAAASUVORK5CYII=';
