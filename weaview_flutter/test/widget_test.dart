import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:weaview_flutter/main.dart';

void main() {
  testWidgets('renders the Weaview chat shell', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const WeaviewApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('今天，你想编织什么梦境？'), findsOneWidget);
    expect(find.text('新梦境'), findsOneWidget);
    expect(find.text('编织'), findsOneWidget);
  });

  test('keeps role model assignments explicit by default', () {
    final assignments = ModelAssignment.defaults();

    for (final assignment in assignments.values) {
      expect(assignment.provider, isEmpty);
      expect(assignment.model, isEmpty);
    }
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
}
