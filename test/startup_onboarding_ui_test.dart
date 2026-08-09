import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:weaview_flutter/src/app/weaview_app.dart';
import 'package:weaview_flutter/src/app/weaview_state.dart';
import 'package:weaview_flutter/src/domain/models.dart';
import 'package:weaview_flutter/src/features/chat/chat_home.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('app shows startup gate before state finishes loading', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const WeaviewApp());

    expect(find.text('Weaview 正在准备中'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('今天，你想编织什么梦境？'), findsOneWidget);
  });

  testWidgets('empty chat stays minimal when no model exists', (
    WidgetTester tester,
  ) async {
    final state = WeaviewState();
    await state.load();

    await tester.pumpWidget(MaterialApp(home: WeaviewHome(state: state)));
    await tester.pumpAndSettle();

    expect(find.text('先配置一个模型'), findsNothing);
    expect(find.textContaining('对话、修图或批量生成'), findsNothing);
    expect(find.text('今天，你想编织什么梦境？'), findsOneWidget);
    state.dispose();
  });

  testWidgets(
    'empty chat hides setup card for a chat-capable multimodal model',
    (WidgetTester tester) async {
      final state = WeaviewState();
      await state.load();
      state.saveProviders([
        ...state.providers.where((provider) => provider.name != 'OpenAI'),
        state.providers
            .firstWhere((provider) => provider.name == 'OpenAI')
            .copyWith(
              enabled: true,
              current: true,
              apiKey: 'openai-key',
              status: '使用中',
              models: const [
                AiModel(
                  id: 'multimodal-image-editor',
                  name: 'multimodal-image-editor',
                  capabilities: ['chat', 'image'],
                ),
              ],
            ),
      ]);
      state.saveModelAssignment(
        'chat',
        const ModelAssignment(
          provider: 'OpenAI',
          model: 'multimodal-image-editor',
          prompt: '',
        ),
      );

      await tester.pumpWidget(MaterialApp(home: WeaviewHome(state: state)));
      await tester.pumpAndSettle();

      expect(find.text('先配置一个聊天模型'), findsNothing);
      expect(find.text('今天，你想编织什么梦境？'), findsOneWidget);
      state.dispose();
    },
  );

  testWidgets('empty home does not show first-entry action prompts', (
    WidgetTester tester,
  ) async {
    final state = WeaviewState();
    await state.load();
    final gemini = state.providers.firstWhere(
      (provider) => provider.name == 'Gemini',
    );
    state.saveProviders([
      ...state.providers.where((provider) => provider.name != 'Gemini'),
      gemini.copyWith(
        enabled: true,
        current: true,
        apiKey: 'gemini-key',
        status: '使用中',
        models: [
          ...gemini.models,
          const AiModel(
            id: 'gemini-2.5-pro',
            name: 'gemini-2.5-pro',
            capabilities: ['chat'],
          ),
        ],
      ),
    ]);
    state.saveModelAssignment(
      'chat',
      const ModelAssignment(
        provider: 'Gemini',
        model: 'gemini-2.5-pro',
        prompt: '',
      ),
    );
    state.saveModelAssignment(
      'image',
      const ModelAssignment(
        provider: 'Gemini',
        model: 'gemini-3.1-flash-image',
        prompt: '',
      ),
    );

    await tester.pumpWidget(MaterialApp(home: WeaviewHome(state: state)));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, '生成图片'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, '开始对话'), findsNothing);
    expect(find.text('今天，你想编织什么梦境？'), findsOneWidget);
    state.dispose();
  });
}
