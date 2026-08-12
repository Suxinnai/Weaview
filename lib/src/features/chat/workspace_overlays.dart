import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/weaview_state.dart';
import '../../domain/models.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'usage_stats_charts.dart';


class UsageStatsOverlay extends StatelessWidget {
  const UsageStatsOverlay({
    super.key,
    required this.state,
    required this.open,
    required this.onClose,
  });

  final WeaviewState state;
  final bool open;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final allRecords = state.sortedTokenUsageRecords;
    var window = '30d';

    return _WorkspacePanel(
      state: state,
      open: open,
      title: '用量统计',
      subtitle: '本地估算的 token 与花费',
      icon: Icons.payments_outlined,
      onClose: onClose,
      child: StatefulBuilder(
        builder: (context, setLocalState) {
          final usageWindow = _UsageWindow.fromRecords(allRecords, window);
          final records = usageWindow.filter(allRecords);
          final promptTokens = records.fold(
            0,
            (sum, item) => sum + item.promptTokens,
          );
          final completionTokens = records.fold(
            0,
            (sum, item) => sum + item.completionTokens,
          );
          final totalCost = records.fold(
            0.0,
            (sum, item) => sum + item.estimatedCostUsd,
          );
          final providerUsage = _usageByProvider(records);
          final daily = aggregateDailyTokenUsage(
            records,
            days: usageWindow.days,
            now: usageWindow.end,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            physics: const BouncingScrollPhysics(),
            children: [
              CardShell(
                state: state,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedPills(
                      state: state,
                      value: window,
                      items: const {'7d': '7 天', '30d': '30 天', 'all': '全部'},
                      onChanged: (value) => setLocalState(() => window = value),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      usageWindow.label,
                      style: state.textStyle(
                        context,
                        size: 12.5,
                        opacity: 0.48,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _UsageHero(
                state: state,
                requestCount: records.length,
                promptTokens: promptTokens,
                completionTokens: completionTokens,
                costUsd: totalCost,
              ),
              const SizedBox(height: 14),
              if (!state.loaded)
                KeyedSubtree(
                  key: const Key('usage-stats-loading'),
                  child: CardShell(
                    state: state,
                    padding: const EdgeInsets.symmetric(vertical: 34),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: state.accents[0],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '正在加载用量统计',
                            style: state.textStyle(
                              context,
                              size: 12,
                              opacity: 0.48,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (records.isEmpty)
                _PanelEmptyState(
                  state: state,
                  icon: Icons.query_stats_rounded,
                  title: '当前时间范围暂无记录',
                  body: allRecords.isEmpty
                      ? '完成一次普通聊天、联网聊天、翻译或多模型对照后，这里会显示估算 token 与花费。'
                      : '切换到更长的时间范围，可以查看更早的本地用量记录。',
                )
              else ...[
                UsageStatsCharts(
                  state: state,
                  days: daily,
                  rangeLabel: usageWindow.shortLabel,
                ),
                const SizedBox(height: 20),
                _SectionTitle(state: state, label: '按提供商'),
                const SizedBox(height: 10),
                for (var i = 0; i < providerUsage.length; i++) ...[
                  _UsageProviderRow(state: state, item: providerUsage[i]),
                  if (i != providerUsage.length - 1) const SizedBox(height: 10),
                ],
                const SizedBox(height: 20),
                _SectionTitle(state: state, label: '最近调用'),
                const SizedBox(height: 10),
                for (var i = 0; i < records.take(8).length; i++) ...[
                  _UsageRecordTile(state: state, record: records[i]),
                  if (i != math.min(records.length, 8) - 1)
                    const SizedBox(height: 10),
                ],
                const SizedBox(height: 12),
                SoftButton(
                  state: state,
                  label: '清空用量统计',
                  icon: Icons.delete_sweep_outlined,
                  danger: true,
                  onTap: state.clearTokenUsageRecords,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _WorkspacePanel extends StatelessWidget {
  const _WorkspacePanel({
    required this.state,
    required this.open,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onClose,
    required this.child,
  });

  final WeaviewState state;
  final bool open;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scrim = Colors.black.withValues(
      alpha: state.isDark(context) ? 0.46 : 0.14,
    );
    return IgnorePointer(
      ignoring: !open,
      child: Stack(
        children: [
          AnimatedOpacity(
            opacity: open ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: GestureDetector(
              onTap: onClose,
              child: Container(color: scrim),
            ),
          ),
          Positioned.fill(
            child: AnimatedSlide(
              offset: open ? Offset.zero : const Offset(0, 0.05),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: open ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      color: state.layer(context).withValues(alpha: 0.96),
                      child: SafeArea(
                        bottom: false,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                14,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _WorkspaceTopButton(
                                    state: state,
                                    icon: Icons.arrow_back_rounded,
                                    onTap: onClose,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: state.accents[0]
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Icon(
                                                  icon,
                                                  size: 17,
                                                  color: state.accents[0],
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  title,
                                                  style: state.textStyle(
                                                    context,
                                                    size: 18,
                                                    weight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            subtitle.trim().isEmpty
                                                ? ' '
                                                : subtitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: state.textStyle(
                                              context,
                                              size: 12.5,
                                              opacity: 0.48,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Divider(
                              height: 1,
                              color: state
                                  .text(context)
                                  .withValues(alpha: 0.06),
                            ),
                            Expanded(child: child),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceTopButton extends StatelessWidget {
  const _WorkspaceTopButton({
    required this.state,
    required this.icon,
    required this.onTap,
  });

  final WeaviewState state;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: state.text(context).withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: state.text(context).withValues(alpha: 0.08),
            ),
          ),
          child: Icon(
            icon,
            size: 22,
            color: state.text(context).withValues(alpha: 0.84),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.state, required this.label});

  final WeaviewState state;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: state
          .textStyle(context, size: 11.5, weight: FontWeight.w700, opacity: 0.5)
          .copyWith(letterSpacing: 1.2),
    );
  }
}

class _PanelEmptyState extends StatelessWidget {
  const _PanelEmptyState({
    required this.state,
    required this.icon,
    required this.title,
    required this.body,
  });

  final WeaviewState state;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return CardShell(
      state: state,
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: state.text(context).withValues(alpha: 0.055),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 28,
                color: state.text(context).withValues(alpha: 0.34),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: state.textStyle(
                context,
                size: 16,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: state.textStyle(
                context,
                size: 13,
                opacity: 0.52,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageHero extends StatelessWidget {
  const _UsageHero({
    required this.state,
    required this.requestCount,
    required this.promptTokens,
    required this.completionTokens,
    required this.costUsd,
  });

  final WeaviewState state;
  final int requestCount;
  final int promptTokens;
  final int completionTokens;
  final double costUsd;

  @override
  Widget build(BuildContext context) {
    return CardShell(
      state: state,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _UsageMetricCell(
                  state: state,
                  label: '请求',
                  value: '$requestCount',
                ),
              ),
              _VerticalDivider(state: state),
              Expanded(
                child: _UsageMetricCell(
                  state: state,
                  label: '输入',
                  value: _formatTokenCount(promptTokens),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(
              height: 1,
              color: state.text(context).withValues(alpha: 0.06),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _UsageMetricCell(
                  state: state,
                  label: '输出',
                  value: _formatTokenCount(completionTokens),
                ),
              ),
              _VerticalDivider(state: state),
              Expanded(
                child: _UsageMetricCell(
                  state: state,
                  label: '花费',
                  value: _formatUsd(costUsd),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UsageMetricCell extends StatelessWidget {
  const _UsageMetricCell({
    required this.state,
    required this.label,
    required this.value,
  });

  final WeaviewState state;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: state.textStyle(context, size: 11.5, opacity: 0.42)),
        const SizedBox(height: 6),
        Text(
          value,
          style: state.textStyle(context, size: 23, weight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider({required this.state});

  final WeaviewState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 42,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: state.text(context).withValues(alpha: 0.06),
    );
  }
}

class _UsageProviderSummary {
  const _UsageProviderSummary({
    required this.provider,
    required this.tokens,
    required this.calls,
    required this.costUsd,
    required this.share,
  });

  final String provider;
  final int tokens;
  final int calls;
  final double costUsd;
  final double share;
}

class _UsageProviderRow extends StatelessWidget {
  const _UsageProviderRow({required this.state, required this.item});

  final WeaviewState state;
  final _UsageProviderSummary item;

  @override
  Widget build(BuildContext context) {
    return CardShell(
      state: state,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: state.accents[0].withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  _providerInitial(item.provider),
                  style: state.textStyle(
                    context,
                    size: 14,
                    weight: FontWeight.w500,
                    opacity: 0.9,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.provider,
                      style: state.textStyle(
                        context,
                        size: 13,
                        weight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.calls} 次调用 · ${_formatTokenCount(item.tokens)} token',
                      style: state.textStyle(
                        context,
                        size: 11.5,
                        opacity: 0.46,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(item.share * 100).toStringAsFixed(item.share < 0.1 ? 1 : 0)}%',
                style: state.textStyle(
                  context,
                  size: 13,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: item.share,
              minHeight: 6,
              backgroundColor: state.text(context).withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(state.accents[0]),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '估算花费 ${_formatUsd(item.costUsd)}',
            style: state.textStyle(context, size: 11.5, opacity: 0.46),
          ),
        ],
      ),
    );
  }
}

class _UsageRecordTile extends StatelessWidget {
  const _UsageRecordTile({required this.state, required this.record});

  final WeaviewState state;
  final TokenUsageRecord record;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: state.text(context).withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: state.text(context).withValues(alpha: 0.04)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: state.accents[0].withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _sourceIcon(record.source),
              size: 18,
              color: state.accents[0],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _sourceLabel(record.source),
                        style: state.textStyle(
                          context,
                          size: 13,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      _formatDateTime(record.createdAt, short: true),
                      style: state.textStyle(
                        context,
                        size: 10.5,
                        opacity: 0.42,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${record.provider} · ${record.model}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: state.textStyle(context, size: 11.5, opacity: 0.46),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTokenCount(record.totalTokens),
                style: state.textStyle(
                  context,
                  size: 12.5,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatUsd(record.estimatedCostUsd),
                style: state.textStyle(context, size: 11, opacity: 0.46),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UsageWindow {
  const _UsageWindow({
    required this.start,
    required this.end,
    required this.days,
  });

  final DateTime start;
  final DateTime end;
  final int days;

  static _UsageWindow fromRecords(List<TokenUsageRecord> records, String key) {
    final nowValue = DateTime.now();
    final today = DateTime(nowValue.year, nowValue.month, nowValue.day);
    final end = today;
    final earliest = records.isNotEmpty
        ? DateTime.fromMillisecondsSinceEpoch(records.last.createdAt)
        : today;
    final earliestDay = DateTime(earliest.year, earliest.month, earliest.day);

    final start = switch (key) {
      '7d' => end.subtract(const Duration(days: 6)),
      '30d' => end.subtract(const Duration(days: 29)),
      _ => earliestDay,
    };
    final safeStart = start.isAfter(end) ? end : start;
    return _UsageWindow(
      start: safeStart,
      end: end,
      days: end.difference(safeStart).inDays + 1,
    );
  }

  List<TokenUsageRecord> filter(List<TokenUsageRecord> records) {
    final startMillis = start.millisecondsSinceEpoch;
    final endMillis = end.add(const Duration(days: 1)).millisecondsSinceEpoch;
    return records
        .where(
          (record) =>
              record.createdAt >= startMillis && record.createdAt < endMillis,
        )
        .toList();
  }

  String get label => '${_formatDate(start)} — ${_formatDate(end)}';

  String get shortLabel => days <= 31 ? label : '$days 天';
}

List<_UsageProviderSummary> _usageByProvider(List<TokenUsageRecord> records) {
  final totalTokens = records.fold(0, (sum, item) => sum + item.totalTokens);
  final buckets = <String, ({int tokens, int calls, double costUsd})>{};
  for (final record in records) {
    final key = record.provider.trim().isEmpty
        ? 'Unknown'
        : record.provider.trim();
    final current = buckets[key] ?? (tokens: 0, calls: 0, costUsd: 0.0);
    buckets[key] = (
      tokens: current.tokens + record.totalTokens,
      calls: current.calls + 1,
      costUsd: current.costUsd + record.estimatedCostUsd,
    );
  }
  final items = [
    for (final entry in buckets.entries)
      _UsageProviderSummary(
        provider: entry.key,
        tokens: entry.value.tokens,
        calls: entry.value.calls,
        costUsd: entry.value.costUsd,
        share: totalTokens <= 0 ? 0 : entry.value.tokens / totalTokens,
      ),
  ]..sort((a, b) => b.tokens.compareTo(a.tokens));
  return items;
}

String _providerInitial(String provider) {
  final trimmed = provider.trim();
  return trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
}

String _formatTokenCount(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(2)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}

String _formatUsd(double value) {
  if (value <= 0) return r'$0.0000';
  if (value < 0.01) return '\$${value.toStringAsFixed(4)}';
  if (value < 1) return '\$${value.toStringAsFixed(3)}';
  return '\$${value.toStringAsFixed(2)}';
}

String _sourceLabel(String source) {
  return switch (source) {
    'chat_web' => '联网聊天',
    'comparison' => '多模型对照',
    'suggest' => '追问建议',
    'translate' => '翻译',
    _ => '普通聊天',
  };
}

IconData _sourceIcon(String source) {
  return switch (source) {
    'chat_web' => Icons.travel_explore_rounded,
    'comparison' => Icons.view_column_rounded,
    'suggest' => Icons.lightbulb_outline_rounded,
    'translate' => Icons.translate_rounded,
    _ => Icons.chat_bubble_outline_rounded,
  };
}

String _formatDate(DateTime date) {
  return '${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)}';
}

String _formatDateTime(int milliseconds, {bool short = false}) {
  final time = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  final date = short
      ? '${_twoDigits(time.month)}-${_twoDigits(time.day)}'
      : '${time.year}-${_twoDigits(time.month)}-${_twoDigits(time.day)}';
  return '$date ${_twoDigits(time.hour)}:${_twoDigits(time.minute)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
