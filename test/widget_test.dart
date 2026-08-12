import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:weaview_flutter/src/app/app_version.dart';
import 'package:weaview_flutter/src/app/services/personalization_service.dart';
import 'package:weaview_flutter/src/app/weaview_app.dart';
import 'package:weaview_flutter/src/app/weaview_state.dart';
import 'package:weaview_flutter/src/core/app_utils.dart';
import 'package:weaview_flutter/src/data/ai/ai_gateway.dart';
import 'package:weaview_flutter/src/domain/models.dart';
import 'package:weaview_flutter/src/features/chat/chat_home.dart';
import 'package:weaview_flutter/src/features/chat/sections/chat_input_dock.dart';
import 'package:weaview_flutter/src/features/chat/sections/chat_model_dropdown.dart';
import 'package:weaview_flutter/src/features/chat/workspace_overlays.dart';
import 'package:weaview_flutter/src/features/settings/settings_sheet.dart';

void main() {
  test('derives the current stable version from pubspec text', () {
    final version = parseAppVersionInfo(
      'name: weaview_flutter\nversion: 1.0.30+32',
    );

    expect(version?.tag, 'v1.0.30');
    expect(version?.display, 'Weaview v1.0.30');
    expect(version?.full, '1.0.30+32');
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
      expect(
        providers
            .firstWhere((provider) => provider.name == 'Gemini')
            .models
            .map((model) => model.id),
        containsAll(geminiImageModels.map((model) => model.id)),
      );
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

  test('loads legacy string memories into structured memory items', () async {
    SharedPreferences.setMockInitialValues({
      'ai_memories': ['偏好简洁回复'],
    });
    final state = WeaviewState();

    await state.load();

    expect(state.memoryItems, hasLength(1));
    final item = state.memoryItems.single;
    expect(item.content, '偏好简洁回复');
    expect(item.enabled, isTrue);
    expect(item.source, '旧版记忆');
    expect(state.memories, contains('偏好简洁回复'));
    state.dispose();
  });

  test('exports structured memory cards with legacy compatibility', () async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();

    await state.load();
    state.addMemory('偏好简洁回复');
    final id = state.memoryItems.single.id;
    state.toggleMemoryPinned(id);
    state.setMemoryEnabled(id, false);

    final exported = jsonDecode(state.exportJson()) as Map<String, dynamic>;
    final memoryItems = exported['ai_memory_items'] as List<dynamic>;
    final legacyMemories = exported['ai_memories'] as List<dynamic>;

    expect(legacyMemories, contains('偏好简洁回复'));
    expect(memoryItems, hasLength(1));
    final memory = memoryItems.single as Map<String, dynamic>;
    expect(memory['content'], '偏好简洁回复');
    expect(memory['pinned'], isTrue);
    expect(memory['enabled'], isFalse);
    expect(memory['source'], '手动添加');
    state.dispose();
  });

  test('model comparison messages survive JSON roundtrip', () {
    final message = ChatMessage.modelComparison(
      results: const [
        ModelComparisonResult(
          id: 'comparison_openai',
          provider: 'OpenAI',
          model: 'gpt-test',
          content: '第一版回答',
          reasoning: '第一版思考',
          elapsedMs: 120,
        ),
        ModelComparisonResult(
          id: 'comparison_deepseek',
          provider: 'DeepSeek',
          model: 'deepseek-test',
          error: '模型不可用',
          loading: false,
          elapsedMs: 240,
        ),
      ],
    );

    final restored = ChatMessage.fromJson(message.toJson());

    expect(restored.isModelComparison, isTrue);
    expect(restored.comparisonResults, hasLength(2));
    expect(restored.comparisonResults.first.provider, 'OpenAI');
    expect(restored.comparisonResults.first.content, '第一版回答');
    expect(restored.comparisonResults.first.reasoning, '第一版思考');
    expect(restored.comparisonResults.last.error, '模型不可用');
  });

  test('exports backup without removed work card storage', () async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();

    await state.load();
    state.currentSessionId = 'session_root';
    state.messages
      ..add(ChatMessage.user('写一个发布文案'))
      ..add(
        ChatMessage.modelComparison(
          results: const [
            ModelComparisonResult(
              id: 'comparison_openai',
              provider: 'OpenAI',
              model: 'gpt-test',
              content: '开放版文案',
              elapsedMs: 100,
            ),
            ModelComparisonResult(
              id: 'comparison_kimi',
              provider: 'Kimi',
              model: 'kimi-test',
              content: '克制版文案',
              elapsedMs: 150,
            ),
          ],
        ),
      );

    final exported = jsonDecode(state.exportJson()) as Map<String, dynamic>;
    expect(exported.containsKey('work_cards'), isFalse);
    expect(exported['chat_sessions'], isA<List<dynamic>>());
    expect(exported['token_usage_records'], isA<List<dynamic>>());
    state.dispose();
  });

  test('exports and clears token usage records', () async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();

    await state.load();
    state.tokenUsageRecords = [
      TokenUsageRecord.create(
        provider: 'OpenAI',
        model: 'gpt-test',
        source: 'chat',
        sessionId: 'session_usage',
        promptTokens: 100,
        completionTokens: 40,
        estimatedCostUsd: 0.0009,
      ),
    ];

    final exported = jsonDecode(state.exportJson()) as Map<String, dynamic>;
    final usage = exported['token_usage_records'] as List<dynamic>;
    expect(usage, hasLength(1));
    expect(usage.single, isA<Map<String, dynamic>>());
    expect(state.totalTokenUsage, 140);
    expect(state.totalEstimatedCostUsd, closeTo(0.0009, 0.00001));

    state.clearTokenUsageRecords();

    expect(state.tokenUsageRecords, isEmpty);
    state.dispose();
  });

  testWidgets('usage statistics overlay renders token and cost summary', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();

    await state.load();
    state.tokenUsageRecords = [
      TokenUsageRecord.create(
        provider: 'OpenAI',
        model: 'gpt-test',
        source: 'comparison',
        sessionId: 'session_usage',
        promptTokens: 1200,
        completionTokens: 300,
        estimatedCostUsd: 0.0042,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              UsageStatsOverlay(state: state, open: true, onClose: () {}),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('用量统计'), findsOneWidget);
    expect(find.text('输入'), findsOneWidget);
    expect(find.text('输出'), findsOneWidget);
    expect(find.text('花费'), findsOneWidget);
    expect(find.byKey(const Key('usage-activity-heatmap')), findsNothing);
    expect(find.byKey(const Key('usage-token-trend')), findsOneWidget);
    expect(find.byKey(const Key('usage-model-donut')), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('多模型对照'), findsOneWidget);
    expect(find.text('OpenAI · gpt-test'), findsWidgets);
    state.dispose();
  });

  test('disabled memories stay out of the system prompt', () {
    final service = PersonalizationService();
    service.memories = ['保留偏好', '隐藏记忆'];
    final hiddenId = service.memoryItems.last.id;
    service.setMemoryEnabled(hiddenId, false, null);

    final prompt = service.expandedSystemPrompt(
      chatSessions: const [],
      searchConfig: const SearchConfig(active: 'tavily', keys: {}),
      appearanceDirective: '',
    );

    expect(prompt, contains('保留偏好'));
    expect(prompt, isNot(contains('隐藏记忆')));
  });

  testWidgets('memory management shows structured memory metadata', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'ai_memories': ['偏好简洁回复'],
    });
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

    await tester.drag(find.byType(ListView).last, const Offset(0, -520));
    await tester.pumpAndSettle();
    final memoryEntry = find.text('记忆管理');
    await tester.tap(memoryEntry);
    await tester.pumpAndSettle();

    expect(find.text('偏好简洁回复'), findsOneWidget);
    expect(find.text('旧版记忆'), findsOneWidget);
    expect(find.text('参与上下文'), findsOneWidget);
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
      imageCount: 4,
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
    expect(state.messages.last.imageCount, 4);
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

  test(
    'image generation follow-up treats additive edits as image context',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'weaview-add-edit-',
      );
      final previous = File('${tempDir.path}/previous.png');
      await previous.writeAsBytes(base64Decode(_png1x1));
      SharedPreferences.setMockInitialValues({});
      final state = WeaviewState();

      try {
        await state.load();
        state.messages
          ..add(ChatMessage.user('生成一个蓝色机器人'))
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
          '给它添加一顶帽子',
        );

        expect(prepared['attachmentPaths'], previous.path);
        expect(prepared['prompt'], contains('上一轮图像处理上下文'));
      } finally {
        state.dispose();
        await tempDir.delete(recursive: true);
      }
    },
  );

  test('editing a user message replaces the original branch', () async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();

    await state.load();
    state.messages
      ..add(ChatMessage.user('旧问题'))
      ..add(ChatMessage.model('旧回答'))
      ..add(ChatMessage.user('后续问题'));

    await state.replaceUserMessageAndSubmit(0, '新问题');

    expect(state.messages.first.role, 'user');
    expect(state.messages.first.content, '新问题');
    expect(state.messages, hasLength(2));
    expect(
      state.messages.map((message) => message.content),
      isNot(contains('旧回答')),
    );
    expect(
      state.messages.map((message) => message.content),
      isNot(contains('后续问题')),
    );
    state.dispose();
  });

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

  test(
    'disabled providers stay out of model selection and clear assignments',
    () async {
      SharedPreferences.setMockInitialValues({});
      final state = WeaviewState();

      await state.load();
      state.saveProviders([
        AiProvider.defaults().first.copyWith(
          apiKey: 'key',
          status: '使用中',
          current: true,
          models: const [
            AiModel(id: 'gpt-test', name: 'gpt-test', capabilities: ['chat']),
          ],
        ),
        AiProvider.defaults()[2].copyWith(
          apiKey: 'deep-key',
          status: '已连接',
          models: const [
            AiModel(
              id: 'deepseek-test',
              name: 'deepseek-test',
              capabilities: ['chat'],
            ),
          ],
        ),
      ]);
      state.saveModelAssignment(
        'chat',
        const ModelAssignment(
          provider: 'OpenAI',
          model: 'gpt-test',
          prompt: '',
        ),
      );

      state.setProviderEnabled('OpenAI', false);

      final openai = state.providers.firstWhere((p) => p.name == 'OpenAI');
      expect(openai.enabled, isFalse);
      expect(openai.current, isFalse);
      expect(openai.status, '已禁用');
      expect(state.modelAssignments['chat']?.provider, isEmpty);
      expect(
        state.enabledModelProviders.map((p) => p.name),
        isNot(contains('OpenAI')),
      );
      state.dispose();
    },
  );

  test(
    'imports backups by merging data and preserving masked secrets',
    () async {
      SharedPreferences.setMockInitialValues({});
      final state = WeaviewState();

      await state.load();
      state.saveProviders([
        AiProvider.defaults().first.copyWith(
          apiKey: 'local-secret',
          status: '已连接',
        ),
      ]);

      final result = await state.importBackupJson(
        jsonEncode({
          'ai_memories': ['偏好简洁回复'],
          'ai_providers': [
            {
              'name': 'OpenAI',
              'status': '已连接',
              'current': true,
              'enabled': true,
              'colorHex': '#10B981',
              'apiKey': '***',
              'baseUrl': 'https://api.openai.com/v1',
              'models': [
                {
                  'id': 'gpt-test',
                  'name': 'gpt-test',
                  'capabilities': ['chat'],
                },
              ],
            },
          ],
        }),
      );

      final openai = state.providers.firstWhere((p) => p.name == 'OpenAI');
      expect(result.memories, 1);
      expect(result.providers, 1);
      expect(state.memories, contains('偏好简洁回复'));
      expect(openai.apiKey, 'local-secret');
      expect(openai.models.map((m) => m.id), contains('gpt-test'));
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
                onSelectModel: (_, _) {},
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
            webSearchEnabled: false,
            imageGenerationMode: false,
            comparisonMode: false,
            dockExpanded: false,
            pendingAttachments: const [],
            onToggleExpanded: () {},
            onToggleWebSearch: () {},
            onToggleComparison: () {},
            onConfigureComparison: () {},
            onSubmit: () async {},
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
    expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
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

  testWidgets('provider detail omits set-current action', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();

    await state.load();
    final defaults = AiProvider.defaults();
    state.saveProviders([
      defaults
          .firstWhere((p) => p.name == 'OpenAI')
          .copyWith(
            apiKey: 'openai-key',
            status: '已连接',
            current: false,
            models: const [
              AiModel(id: 'gpt-test', name: 'gpt-test', capabilities: ['chat']),
            ],
          ),
      defaults
          .firstWhere((p) => p.name == 'DeepSeek')
          .copyWith(
            apiKey: 'deep-key',
            status: '使用中',
            current: true,
            models: const [
              AiModel(
                id: 'deepseek-test',
                name: 'deepseek-test',
                capabilities: ['chat'],
              ),
            ],
          ),
    ]);
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
    await tester.tap(find.text('OpenAI').first);
    await tester.pumpAndSettle();
    expect(find.text('设为当前'), findsNothing);
    await tester.tap(find.text('保存配置'));
    await tester.pumpAndSettle();

    final openai = state.providers.firstWhere((p) => p.name == 'OpenAI');
    final deepSeek = state.providers.firstWhere((p) => p.name == 'DeepSeek');
    expect(openai.enabled, isTrue);
    expect(openai.current, isFalse);
    expect(openai.status, '已连接');
    expect(deepSeek.current, isTrue);
    state.dispose();
  });

  testWidgets('disabling current provider from detail clears assignments', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();

    await state.load();
    final defaults = AiProvider.defaults();
    state.saveProviders([
      defaults
          .firstWhere((p) => p.name == 'OpenAI')
          .copyWith(
            apiKey: 'openai-key',
            status: '使用中',
            current: true,
            models: const [
              AiModel(id: 'gpt-test', name: 'gpt-test', capabilities: ['chat']),
            ],
          ),
      defaults
          .firstWhere((p) => p.name == 'DeepSeek')
          .copyWith(
            apiKey: 'deep-key',
            status: '已连接',
            current: false,
            models: const [
              AiModel(
                id: 'deepseek-test',
                name: 'deepseek-test',
                capabilities: ['chat'],
              ),
            ],
          ),
    ]);
    state.saveModelAssignment(
      'chat',
      const ModelAssignment(provider: 'OpenAI', model: 'gpt-test', prompt: ''),
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
    await tester.tap(find.text('OpenAI').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('禁用提供商'));
    await tester.pumpAndSettle();

    final openai = state.providers.firstWhere((p) => p.name == 'OpenAI');
    final deepSeek = state.providers.firstWhere((p) => p.name == 'DeepSeek');
    expect(openai.enabled, isFalse);
    expect(openai.current, isFalse);
    expect(openai.status, '已禁用');
    expect(deepSeek.current, isTrue);
    expect(state.modelAssignments['chat']?.provider, isEmpty);
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

  test('conversation branches keep parent graph metadata', () async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();

    await state.load();
    state.currentSessionId = 'session_root';
    state.messages
      ..add(ChatMessage.user('根问题'))
      ..add(ChatMessage.model('根回答'))
      ..add(ChatMessage.user('继续追问'));
    state.chatSessions.add(
      ChatSession(
        id: 'session_root',
        title: '根会话',
        updatedAt: 1,
        messages: state.messages.map((message) => message.copy()).toList(),
      ),
    );

    state.createBranchAt(1);

    final branch = state.chatSessions.firstWhere(
      (session) => session.id == state.currentSessionId,
    );
    expect(branch.parentId, 'session_root');
    expect(branch.branchedAtIndex, 1);
    expect(branch.messages, hasLength(2));
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

  test('open-ended background requests stay in the poetic palette', () async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();

    await state.load();
    state.applyAiTheme({
      'backgroundColor': '#FF0000',
      'isDark': false,
    }, userPrompt: '换个背景');

    expect(colorToHex(state.backgroundOverride!), '#F6F1FF');

    state.applyAiTheme({
      'backgroundColor': '#DC2626',
      'isDark': false,
    }, userPrompt: '再换个背景');

    expect(colorToHex(state.backgroundOverride!), '#F1F6F4');
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
