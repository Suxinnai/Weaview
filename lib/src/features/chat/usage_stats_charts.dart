import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/weaview_state.dart';
import '../../domain/token_usage_record.dart';
import '../../shared/widgets/shared_widgets.dart';

class UsageStatsCharts extends StatelessWidget {
  const UsageStatsCharts({
    super.key,
    required this.state,
    required this.records,
  });

  final WeaviewState state;
  final List<TokenUsageRecord> records;

  @override
  Widget build(BuildContext context) {
    final daily = aggregateDailyTokenUsage(records, days: 84);
    final trend = daily.sublist(daily.length - math.min(14, daily.length));
    final models = aggregateModelTokenUsage(records);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChartTitle(state: state, title: '活跃热力图', caption: '最近 12 周'),
        const SizedBox(height: 10),
        UsageActivityHeatmap(state: state, days: daily),
        const SizedBox(height: 18),
        _ChartTitle(state: state, title: 'Token 趋势', caption: '最近 14 天'),
        const SizedBox(height: 10),
        UsageTrendChart(state: state, days: trend),
        const SizedBox(height: 18),
        _ChartTitle(state: state, title: '模型占比', caption: '按 Token'),
        const SizedBox(height: 10),
        UsageModelDonutChart(state: state, slices: models),
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

class UsageActivityHeatmap extends StatelessWidget {
  const UsageActivityHeatmap({
    super.key,
    required this.state,
    required this.days,
  });

  final WeaviewState state;
  final List<DailyTokenUsage> days;

  @override
  Widget build(BuildContext context) {
    final maxTokens = days.fold(0, (max, day) => math.max(max, day.tokens));
    final activeDays = days.where((day) => day.tokens > 0).length;
    return KeyedSubtree(
      key: const Key('usage-activity-heatmap'),
      child: CardShell(
        state: state,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$activeDays 个活跃日 · ${_formatTokenCount(days.fold(0, (sum, day) => sum + day.tokens))} Token',
              style: state.textStyle(
                context,
                size: 12.5,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              label: '最近十二周用量热力图，共 $activeDays 个活跃日',
              child: SizedBox(
                height: 94,
                width: double.infinity,
                child: CustomPaint(
                  painter: _HeatmapPainter(
                    days: days,
                    maxTokens: maxTokens,
                    accent: state.accents[0],
                    empty: state.text(context).withValues(alpha: 0.06),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '少',
                  style: state.textStyle(context, size: 10, opacity: 0.4),
                ),
                const SizedBox(width: 5),
                for (var level = 0; level < 5; level++) ...[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: level == 0
                          ? state.text(context).withValues(alpha: 0.06)
                          : state.accents[0].withValues(alpha: 0.2 * level),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  const SizedBox(width: 3),
                ],
                Text(
                  '多',
                  style: state.textStyle(context, size: 10, opacity: 0.4),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class UsageTrendChart extends StatelessWidget {
  const UsageTrendChart({super.key, required this.state, required this.days});

  final WeaviewState state;
  final List<DailyTokenUsage> days;

  @override
  Widget build(BuildContext context) {
    final total = days.fold(0, (sum, day) => sum + day.tokens);
    final peak = days.fold(0, (max, day) => math.max(max, day.tokens));
    return KeyedSubtree(
      key: const Key('usage-token-trend'),
      child: CardShell(
        state: state,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _MiniMetric(
                    state: state,
                    label: '14 天合计',
                    value: _formatTokenCount(total),
                  ),
                ),
                _MiniMetric(
                  state: state,
                  label: '单日峰值',
                  value: _formatTokenCount(peak),
                  alignEnd: true,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Semantics(
              label: '最近十四天 Token 折线图，合计 $total，单日峰值 $peak',
              child: SizedBox(
                height: 112,
                width: double.infinity,
                child: CustomPaint(
                  painter: _TrendPainter(
                    days: days,
                    accent: state.accents[0],
                    grid: state.text(context).withValues(alpha: 0.07),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UsageModelDonutChart extends StatelessWidget {
  const UsageModelDonutChart({
    super.key,
    required this.state,
    required this.slices,
  });

  final WeaviewState state;
  final List<ModelTokenUsage> slices;

  static const _palette = [
    Color(0xFF54C6B3),
    Color(0xFF7E8CE0),
    Color(0xFFF1B65A),
    Color(0xFFE37C91),
    Color(0xFF8CBF66),
  ];

  @override
  Widget build(BuildContext context) {
    final total = slices.fold(0, (sum, slice) => sum + slice.tokens);
    return KeyedSubtree(
      key: const Key('usage-model-donut'),
      child: CardShell(
        state: state,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          children: [
            Semantics(
              label: '模型 Token 占比环形图，共 $total Token',
              child: SizedBox.square(
                dimension: 116,
                child: CustomPaint(
                  painter: _DonutPainter(slices: slices, colors: _palette),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTokenCount(total),
                          style: state.textStyle(
                            context,
                            size: 16,
                            weight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Token',
                          style: state.textStyle(
                            context,
                            size: 9.5,
                            opacity: 0.42,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                children: [
                  for (var i = 0; i < slices.length; i++) ...[
                    _DonutLegendRow(
                      state: state,
                      slice: slices[i],
                      color: _palette[i % _palette.length],
                      total: total,
                    ),
                    if (i != slices.length - 1) const SizedBox(height: 8),
                  ],
                ],
              ),
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
          style: state.textStyle(context, size: 15, weight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(label, style: state.textStyle(context, size: 10.5, opacity: 0.42)),
      ],
    );
  }
}

class _DonutLegendRow extends StatelessWidget {
  const _DonutLegendRow({
    required this.state,
    required this.slice,
    required this.color,
    required this.total,
  });

  final WeaviewState state;
  final ModelTokenUsage slice;
  final Color color;
  final int total;

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0 : (slice.tokens / total * 100).round();
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            slice.model,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: state.textStyle(
              context,
              size: 10.5,
              weight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$percent%',
          style: state.textStyle(
            context,
            size: 10.5,
            weight: FontWeight.w700,
            opacity: 0.58,
          ),
        ),
      ],
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  const _HeatmapPainter({
    required this.days,
    required this.maxTokens,
    required this.accent,
    required this.empty,
  });

  final List<DailyTokenUsage> days;
  final int maxTokens;
  final Color accent;
  final Color empty;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;
    const rows = 7;
    final columns = usageHeatmapColumnCount(days);
    const gap = 3.0;
    final cell = math.min(
      (size.width - gap * (columns - 1)) / columns,
      (size.height - gap * (rows - 1)) / rows,
    );
    final xOffset = size.width - (cell * columns + gap * (columns - 1));
    final startWeekdayOffset = days.first.date.weekday % 7;
    for (var i = 0; i < days.length; i++) {
      final position = i + startWeekdayOffset;
      final column = position ~/ rows;
      final row = position % rows;
      if (column >= columns) break;
      final value = days[i].tokens;
      final normalized = maxTokens == 0 ? 0.0 : value / maxTokens;
      final alpha = value == 0 ? 0.0 : 0.2 + math.sqrt(normalized) * 0.8;
      final paint = Paint()
        ..color = value == 0 ? empty : accent.withValues(alpha: alpha);
      final rect = Rect.fromLTWH(
        xOffset + column * (cell + gap),
        row * (cell + gap),
        cell,
        cell,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2.5)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) =>
      oldDelegate.days != days ||
      oldDelegate.maxTokens != maxTokens ||
      oldDelegate.accent != accent ||
      oldDelegate.empty != empty;
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({
    required this.days,
    required this.accent,
    required this.grid,
  });

  final List<DailyTokenUsage> days;
  final Color accent;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    if (days.isEmpty) return;
    final maxTokens = math.max(
      1,
      days.fold(0, (max, day) => math.max(max, day.tokens)),
    );
    final path = Path();
    for (var i = 0; i < days.length; i++) {
      final x = days.length == 1
          ? size.width / 2
          : size.width * i / (days.length - 1);
      final y =
          size.height - (days[i].tokens / maxTokens) * (size.height - 8) - 4;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [accent.withValues(alpha: 0.22), accent.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = accent
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.days != days ||
      oldDelegate.accent != accent ||
      oldDelegate.grid != grid;
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.slices, required this.colors});

  final List<ModelTokenUsage> slices;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold(0, (sum, slice) => sum + slice.tokens);
    if (total <= 0) return;
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const gap = 0.035;
    var start = -math.pi / 2;
    for (var i = 0; i < slices.length; i++) {
      final sweep = slices[i].tokens / total * math.pi * 2;
      canvas.drawArc(
        rect,
        start + gap / 2,
        math.max(0, sweep - gap),
        false,
        Paint()
          ..color = colors[i % colors.length]
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.slices != slices || oldDelegate.colors != colors;
}

String _formatTokenCount(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(2)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}
