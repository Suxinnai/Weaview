import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weaview_flutter/src/app/weaview_state.dart';
import 'package:weaview_flutter/src/domain/token_usage_record.dart';
import 'package:weaview_flutter/src/features/chat/usage_stats_charts.dart';
import 'package:weaview_flutter/src/features/chat/workspace_overlays.dart';

void main() {
  test(
    'daily usage aggregation fills gaps and ignores out-of-range records',
    () {
      final now = DateTime(2026, 6, 19, 15);
      final records = [
        _record(
          id: 'today-a',
          model: 'model-a',
          tokens: 120,
          createdAt: DateTime(2026, 6, 19, 10),
        ),
        _record(
          id: 'today-b',
          model: 'model-b',
          tokens: 80,
          createdAt: DateTime(2026, 6, 19, 14),
        ),
        _record(
          id: 'old',
          model: 'model-a',
          tokens: 999,
          createdAt: DateTime(2026, 6, 10),
        ),
      ];

      final days = aggregateDailyTokenUsage(records, days: 3, now: now);

      expect(days.map((day) => day.tokens), [0, 0, 200]);
      expect(days.last.calls, 2);
      expect(days.last.date, DateTime(2026, 6, 19));
    },
  );

  test('model aggregation keeps top models and groups the remainder', () {
    final records = [
      _record(id: 'a', model: 'alpha', tokens: 500),
      _record(id: 'b', model: 'beta', tokens: 400),
      _record(id: 'c', model: 'gamma', tokens: 300),
      _record(id: 'd', model: 'delta', tokens: 200),
      _record(id: 'e', model: 'epsilon', tokens: 100),
      _record(id: 'f', model: 'zeta', tokens: 50),
    ];

    final slices = aggregateModelTokenUsage(records, maxSlices: 5);

    expect(slices, hasLength(5));
    expect(slices.first.model, 'alpha');
    expect(slices.last.model, '其他模型');
    expect(slices.last.tokens, 150);
  });

  test('heatmap column count retains trailing days for non-Sunday start', () {
    final days = List.generate(
      84,
      (index) => DailyTokenUsage(
        date: DateTime(2026, 3, 30).add(Duration(days: index)), // Monday.
        tokens: index,
        calls: 1,
      ),
    );

    expect(usageHeatmapColumnCount(days), 13);
  });

  testWidgets('usage overlay renders heatmap, line and donut charts', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final state = WeaviewState();
    await state.load();
    state.tokenUsageRecords = [
      _record(id: 'one', model: 'alpha', tokens: 600),
      _record(id: 'two', model: 'beta', tokens: 400),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UsageStatsOverlay(state: state, open: true, onClose: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('usage-activity-heatmap')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('usage-token-trend')),
      250,
    );
    expect(find.byKey(const Key('usage-token-trend')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('usage-model-donut')),
      250,
    );
    expect(find.byKey(const Key('usage-model-donut')), findsOneWidget);
    expect(find.text('alpha'), findsOneWidget);

    state.dispose();
  });

  testWidgets('usage overlay exposes loading and empty states', (tester) async {
    final loadingState = WeaviewState();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UsageStatsOverlay(
            state: loadingState,
            open: true,
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('usage-stats-loading')), findsOneWidget);
    expect(find.text('正在加载用量统计'), findsOneWidget);
    loadingState.dispose();

    SharedPreferences.setMockInitialValues({});
    final emptyState = WeaviewState();
    await emptyState.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UsageStatsOverlay(
            state: emptyState,
            open: true,
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('暂无用量记录'), findsOneWidget);
    expect(find.byKey(const Key('usage-activity-heatmap')), findsNothing);
    emptyState.dispose();
  });
}

TokenUsageRecord _record({
  required String id,
  required String model,
  required int tokens,
  DateTime? createdAt,
}) {
  final promptTokens = tokens * 2 ~/ 3;
  return TokenUsageRecord(
    id: id,
    provider: 'provider',
    model: model,
    source: 'chat',
    sessionId: 'session',
    promptTokens: promptTokens,
    completionTokens: tokens - promptTokens,
    totalTokens: tokens,
    estimatedCostUsd: tokens / 1000000,
    createdAt: (createdAt ?? DateTime.now()).millisecondsSinceEpoch,
  );
}
