import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:weaview_flutter/src/app/weaview_app.dart';
import 'package:weaview_flutter/src/app/weaview_state.dart';
import 'package:weaview_flutter/src/core/app_utils.dart';
import 'package:weaview_flutter/src/data/ai/ai_gateway.dart';
import 'package:weaview_flutter/src/domain/models.dart';
import 'package:weaview_flutter/src/features/chat/chat_home.dart';
import 'package:weaview_flutter/src/features/settings/settings_sheet.dart';

void main() {
  testWidgets('renders the Weaview chat shell', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const WeaviewApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('今天，你想编织什么梦境？'), findsOneWidget);
    expect(find.text('新梦境'), findsOneWidget);
    expect(find.text('编织'), findsOneWidget);
  });

  testWidgets('renders rich AI markdown code and formula blocks', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();

    await state.load();
    state.messages.add(
      ChatMessage.model(r'''```dart
void main() {}
```

$$E = mc^2$$'''),
    );

    await tester.pumpWidget(MaterialApp(home: WeaviewHome(state: state)));
    await tester.pump();

    expect(find.text('DART'), findsOneWidget);
    expect(find.text('void main() {}'), findsOneWidget);
    expect(find.text('公式'), findsOneWidget);
    expect(find.text('E = mc^2'), findsOneWidget);
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

      expect(names, containsAll(['OpenAI', 'Gemini', 'DeepSeek', 'Kimi']));
      expect(providers.where((provider) => provider.current), isEmpty);
    },
  );

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
