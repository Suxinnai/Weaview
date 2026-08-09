import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/weaview_state.dart';
import '../../domain/token_usage_record.dart';
import '../../shared/widgets/shared_widgets.dart';

class UsageStatsCharts extends StatelessWidget {
  const UsageStatsCharts({
    super.key,
    required this.state,
    required this.days,
    required this.rangeLabel,
  });

  final WeaviewState state;
  final List<DailyTokenUsage> days;
  final String rangeLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChartTitle(state: state, title: '每日用量趋势', caption: rangeLabel),
        const SizedBox(height: 10),
        UsageTrendChart(state: state, days: days),
      ],
    );
  }
}

class DailyTokenUsage {
  const DailyTokenUsage({
    required this.date,
    required this.tokens,
    required this.calls,
  });

  final DateTime date;
  final int tokens;
  final int calls;
}

class ModelTokenUsage {
  const ModelTokenUsage({
    required this.provider,
    required this.model,
    required this.tokens,
  });

  final String provider;
  final String model;
  final int tokens;
}

List<DailyTokenUsage> aggregateDailyTokenUsage(
  List<TokenUsageRecord> records, {
  required int days,
  DateTime? now,
}) {
  assert(days > 0);
  final todayValue = now ?? DateTime.now();
  final today = DateTime(todayValue.year, todayValue.month, todayValue.day);
  final start = today.subtract(Duration(days: days - 1));
  final buckets = <DateTime, ({int tokens, int calls})>{};
  for (final record in records) {
    final timestamp = DateTime.fromMillisecondsSinceEpoch(record.createdAt);
    final day = DateTime(timestamp.year, timestamp.month, timestamp.day);
    if (day.isBefore(start) || day.isAfter(today)) continue;
    final current = buckets[day] ?? (tokens: 0, calls: 0);
    buckets[day] = (
      tokens: current.tokens + record.totalTokens,
      calls: current.calls + 1,
    );
  }
  return List.generate(days, (index) {
    final day = start.add(Duration(days: index));
    final value = buckets[day] ?? (tokens: 0, calls: 0);
    return DailyTokenUsage(date: day, tokens: value.tokens, calls: value.calls);
  });
}

List<ModelTokenUsage> aggregateModelTokenUsage(
  List<TokenUsageRecord> records, {
  int maxSlices = 5,
}) {
  final buckets = <String, ({String provider, String model, int tokens})>{};
  for (final record in records) {
    final key = '${record.provider}\u0000${record.model}';
    final current = buckets[key];
    buckets[key] = (
      provider: record.provider,
      model: record.model,
      tokens: (current?.tokens ?? 0) + record.totalTokens,
    );
  }
  final sorted = buckets.values.toList()
    ..sort((a, b) => b.tokens.compareTo(a.tokens));
  if (sorted.length <= maxSlices) {
    return [
      for (final item in sorted)
        ModelTokenUsage(
          provider: item.provider,
          model: item.model,
          tokens: item.tokens,
        ),
    ];
  }
  final visibleCount = math.max(1, maxSlices - 1);
  final visible = sorted.take(visibleCount);
  final otherTokens = sorted
      .skip(visibleCount)
      .fold(0, (sum, item) => sum + item.tokens);
  return [
    for (final item in visible)
      ModelTokenUsage(
        provider: item.provider,
        model: item.model,
        tokens: item.tokens,
      ),
    ModelTokenUsage(provider: '', model: '其他模型', tokens: otherTokens),
  ];
}

int usageHeatmapColumnCount(List<DailyTokenUsage> days) {
  if (days.isEmpty) return 0;
  final startWeekdayOffset = days.first.date.weekday % 7;
  return ((days.length + startWeekdayOffset) / 7).ceil();
}

class UsageTrendChart extends StatelessWidget {
  const UsageTrendChart({super.key, required this.state, required this.days});

  final WeaviewState state;
  final List<DailyTokenUsage> days;

  @override
  Widget build(BuildContext context) {
    final totalTokens = days.fold(0, (sum, day) => sum + day.tokens);
    final totalCalls = days.fold(0, (sum, day) => sum + day.calls);
    final peakTokens = days.fold(0, (max, day) => math.max(max, day.tokens));
    final activeDays = days.where((day) => day.tokens > 0).length;
    final labels = _trendAxisLabels(days);
    return KeyedSubtree(
      key: const Key('usage-token-trend'),
      child: CardShell(
        state: state,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _MiniMetric(
                    state: state,
                    label: '累计 Token',
                    value: _formatTokenCount(totalTokens),
                  ),
                ),
                Expanded(
                  child: _MiniMetric(
                    state: state,
                    label: '请求次数',
                    value: '$totalCalls',
                    alignEnd: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MiniMetric(
                    state: state,
                    label: '活跃天数',
                    value: '$activeDays',
                  ),
                ),
                Expanded(
                  child: _MiniMetric(
                    state: state,
                    label: '单日峰值',
                    value: _formatTokenCount(peakTokens),
                    alignEnd: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Semantics(
              label: '用量趋势折线图，累计 $totalTokens token，请求 $totalCalls 次',
              child: SizedBox(
                height: 188,
                width: double.infinity,
                child: CustomPaint(
                  painter: _TrendPainter(
                    days: days,
                    accent: state.accents[0],
                    grid: state.text(context).withValues(alpha: 0.08),
                    text: state.text(context).withValues(alpha: 0.42),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  labels.$1,
                  style: state.textStyle(context, size: 10.5, opacity: 0.4),
                ),
                const Spacer(),
                Text(
                  labels.$2,
                  style: state.textStyle(context, size: 10.5, opacity: 0.4),
                ),
                const Spacer(),
                Text(
                  labels.$3,
                  style: state.textStyle(context, size: 10.5, opacity: 0.4),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartTitle extends StatelessWidget {
  const _ChartTitle({
    required this.state,
    required this.title,
    required this.caption,
  });

  final WeaviewState state;
  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: state
                .textStyle(
                  context,
                  size: 11.5,
                  weight: FontWeight.w700,
                  opacity: 0.5,
                )
                .copyWith(letterSpacing: 1.2),
          ),
        ),
        Text(
          caption,
          style: state.textStyle(context, size: 10.5, opacity: 0.36),
        ),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.state,
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final WeaviewState state;
  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: state.textStyle(context, size: 16, weight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(label, style: state.textStyle(context, size: 10.5, opacity: 0.42)),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({
    required this.days,
    required this.accent,
    required this.grid,
    required this.text,
  });

  final List<DailyTokenUsage> days;
  final Color accent;
  final Color grid;
  final Color text;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPadding = 38.0;
    const topPadding = 8.0;
    const bottomPadding = 24.0;
    final chartWidth = math.max(0.0, size.width - leftPadding);
    final chartHeight = math.max(0.0, size.height - topPadding - bottomPadding);
    final chartRect = Rect.fromLTWH(
      leftPadding,
      topPadding,
      chartWidth,
      chartHeight,
    );
    final maxTokens = math.max(
      1,
      days.fold(0, (max, day) => math.max(max, day.tokens)),
    );
    final labelPainter = TextPainter(textDirection: TextDirection.ltr);
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final ratio = i / 4;
      final y = chartRect.bottom - ratio * chartRect.height;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
      final labelValue = ((maxTokens * ratio) / 1000).toStringAsFixed(
        maxTokens >= 10000 ? 0 : 1,
      );
      labelPainter.text = TextSpan(
        text: ratio == 0
            ? '0'
            : maxTokens >= 1000
            ? '${labelValue}K'
            : '${(maxTokens * ratio).round()}',
        style: TextStyle(color: text, fontSize: 10.5),
      );
      labelPainter.layout();
      labelPainter.paint(canvas, Offset(0, y - labelPainter.height / 2));
    }

    if (days.isEmpty) return;

    final path = Path();
    for (var i = 0; i < days.length; i++) {
      final x = days.length == 1
          ? chartRect.center.dx
          : chartRect.left + chartRect.width * i / (days.length - 1);
      final y =
          chartRect.bottom -
          (days[i].tokens / maxTokens) * math.max(1.0, chartRect.height - 8);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(chartRect.right, chartRect.bottom)
      ..lineTo(chartRect.left, chartRect.bottom)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: 0.24),
            accent.withValues(alpha: 0.03),
          ],
        ).createShader(chartRect),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = accent
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    for (var i = 0; i < days.length; i++) {
      final x = days.length == 1
          ? chartRect.center.dx
          : chartRect.left + chartRect.width * i / (days.length - 1);
      final y =
          chartRect.bottom -
          (days[i].tokens / maxTokens) * math.max(1.0, chartRect.height - 8);
      if (i != 0 && i != days.length - 1 && days[i].tokens <= 0) continue;
      canvas.drawCircle(Offset(x, y), 2.5, Paint()..color = accent);
      canvas.drawCircle(
        Offset(x, y),
        5,
        Paint()..color = accent.withValues(alpha: 0.14),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.days != days ||
      oldDelegate.accent != accent ||
      oldDelegate.grid != grid ||
      oldDelegate.text != text;
}

(String, String, String) _trendAxisLabels(List<DailyTokenUsage> days) {
  if (days.isEmpty) return ('--', '--', '--');
  final middle = days[(days.length - 1) ~/ 2].date;
  return (
    _formatAxisDate(days.first.date),
    _formatAxisDate(middle),
    _formatAxisDate(days.last.date),
  );
}

String _formatAxisDate(DateTime date) {
  return '${date.month}/${date.day}';
}

String _formatTokenCount(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(2)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}
