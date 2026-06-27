import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:weaview_flutter/src/app/weaview_state.dart';
import 'package:weaview_flutter/src/domain/models.dart';
import 'package:weaview_flutter/src/features/chat/comparison_model_picker.dart';
import 'package:weaview_flutter/src/features/chat/message_widgets.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('comparison options include all configured chat models', () {
    final state = WeaviewState();
    state.providers = [
      const AiProvider(
        name: 'Provider',
        status: '已配置',
        current: true,
        color: Colors.blue,
        apiKey: 'test-key',
        models: [
          AiModel(id: 'chat-1', name: 'chat-1'),
          AiModel(id: 'chat-2', name: 'chat-2'),
          AiModel(id: 'chat-3', name: 'chat-3'),
          AiModel(id: 'chat-4', name: 'chat-4'),
          AiModel(id: 'chat-5', name: 'chat-5'),
          AiModel(id: 'chat-6', name: 'chat-6'),
          AiModel(
            id: 'image-only',
            name: 'image-only',
            capabilities: ['image'],
          ),
        ],
      ),
    ];

    expect(state.comparisonModelOptions, hasLength(6));
    expect(
      state.comparisonModelOptions.map((option) => option.model),
      containsAll(['chat-1', 'chat-6']),
    );
    state.dispose();
  });

  testWidgets('comparison picker enforces the five-model maximum', (
    tester,
  ) async {
    final state = WeaviewState();
    final options = [
      for (var i = 1; i <= 6; i++)
        ModelAssignment(provider: 'Provider', model: 'model-$i', prompt: ''),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ComparisonModelPicker(
            state: state,
            options: options,
            initialSelection: options.take(2).toList(),
          ),
        ),
      ),
    );

    for (final model in ['model-3', 'model-4', 'model-5', 'model-6']) {
      await tester.tap(find.text(model));
      await tester.pump();
    }

    expect(find.text('已选择 5/5'), findsOneWidget);
    expect(find.text('最多选择 5 个模型'), findsOneWidget);
    state.dispose();
  });

  testWidgets('comparison picker requires at least two models', (tester) async {
    final state = WeaviewState();
    final options = [
      const ModelAssignment(provider: 'A', model: 'one', prompt: ''),
      const ModelAssignment(provider: 'B', model: 'two', prompt: ''),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ComparisonModelPicker(
            state: state,
            options: options,
            initialSelection: options.take(1).toList(),
          ),
        ),
      ),
    );

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('comparison-selection-confirm')),
    );
    expect(button.onPressed, isNull);
    state.dispose();
  });

  testWidgets(
    'comparison main card strips reasoning, renders Markdown and switches',
    (tester) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = WeaviewState();
      final results = [
        const ModelComparisonResult(
          id: 'one',
          provider: 'Alpha',
          model: 'model-a',
          content: '<think>分析过程</think>\n## 结论\n\n**Python** 更适合初学者。',
          reasoning: '单独保存的思考',
          elapsedMs: 120,
        ),
        const ModelComparisonResult(
          id: 'two',
          provider: 'Beta',
          model: 'model-b',
          content: '- JavaScript\n- Scratch',
          elapsedMs: 180,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ModelComparisonPanel(state: state, results: results),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('## 结论'), findsNothing);
      expect(find.text('**Python** 更适合初学者。'), findsNothing);
      expect(find.textContaining('<think>'), findsNothing);
      expect(find.text('分析过程'), findsNothing);
      expect(find.text('单独保存的思考'), findsNothing);
      expect(find.text('思考链'), findsOneWidget);
      expect(find.text('结论'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.byKey(const Key('comparison-model-chip-0')), findsNothing);
      expect(find.byKey(const Key('comparison-model-chip-1')), findsNothing);

      await tester.fling(
        find.byKey(const Key('comparison-card-swipe-zone')),
        const Offset(-520, 0),
        1200,
      );
      await tester.pumpAndSettle();

      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.text('Beta'), findsWidgets);
      expect(find.text('JavaScript'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.fling(
        find.byKey(const Key('comparison-card-swipe-zone')),
        const Offset(520, 0),
        1200,
      );
      await tester.pumpAndSettle();

      expect(find.text('1 / 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
      state.dispose();
    },
  );

  testWidgets('comparison card hides legacy think blocks from answer text', (
    tester,
  ) async {
    final state = WeaviewState();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModelComparisonPanel(
            state: state,
            results: const [
              ModelComparisonResult(
                id: 'legacy',
                provider: 'Legacy',
                model: 'model',
                content: '<think>内部推理</think>\n最终回答',
                elapsedMs: 80,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('最终回答'), findsOneWidget);
    expect(find.text('内部推理'), findsNothing);
    expect(find.textContaining('<think>'), findsNothing);
    expect(find.text('思考链'), findsOneWidget);
    state.dispose();
  });

  testWidgets('comparison card shows error state independently', (
    tester,
  ) async {
    final state = WeaviewState();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModelComparisonPanel(
            state: state,
            results: const [
              ModelComparisonResult(
                id: 'ok',
                provider: 'Alpha',
                model: 'model-a',
                content: '正常回答',
                elapsedMs: 80,
              ),
              ModelComparisonResult(
                id: 'bad',
                provider: 'Beta',
                model: 'model-b',
                error: '模型不可用',
                elapsedMs: 90,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.fling(
      find.byKey(const Key('comparison-card-swipe-zone')),
      const Offset(-520, 0),
      1200,
    );
    await tester.pumpAndSettle();

    expect(find.text('模型不可用'), findsOneWidget);
    expect(find.text('异常'), findsWidgets);
    expect(tester.takeException(), isNull);
    state.dispose();
  });

  testWidgets('comparison cards fit a short viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = WeaviewState();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ModelComparisonPanel(
              state: state,
              results: const [
                ModelComparisonResult(
                  id: 'one',
                  provider: 'Alpha',
                  model: 'model-a',
                  content: '简短回答',
                ),
                ModelComparisonResult(
                  id: 'two',
                  provider: 'Beta',
                  model: 'model-b',
                  content: '另一个回答',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('comparison-page-view')), findsOneWidget);
    expect(find.byKey(const Key('comparison-model-chip-0')), findsNothing);
    expect(tester.takeException(), isNull);
    state.dispose();
  });
}
