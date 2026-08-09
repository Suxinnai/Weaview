import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/weaview_state.dart';
import '../../domain/models.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'usage_stats_charts.dart';

class WorkBoardOverlay extends StatelessWidget {
  const WorkBoardOverlay({
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
    final cards = state.sortedWorkCards;
    final comparisonCount = cards
        .where((card) => card.kind == 'comparison')
        .length;
    final pinnedCount = cards.where((card) => card.pinned).length;
    final sourceSessions = cards
        .where((card) => card.sourceSessionTitle.trim().isNotEmpty)
        .map((card) => card.sourceSessionTitle.trim())
        .toSet()
        .length;
    var filter = 'all';

    return _WorkspacePanel(
      state: state,
      open: open,
      title: '工作台',
      subtitle: '作品片段与对照结果',
      icon: Icons.dashboard_customize_outlined,
      onClose: onClose,
      child: StatefulBuilder(
        builder: (context, setLocalState) {
          final visibleCards = switch (filter) {
            'pinned' => cards.where((card) => card.pinned).toList(),
            'comparison' =>
              cards.where((card) => card.kind == 'comparison').toList(),
            _ => cards,
          };

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            physics: const BouncingScrollPhysics(),
            children: [
              _WorkspaceSummary(
                state: state,
                items: [
                  _SummaryMetric(label: '作品片段', value: '${cards.length}'),
                  _SummaryMetric(label: '对照结果', value: '$comparisonCount'),
                  _SummaryMetric(label: '来源会话', value: '$sourceSessions'),
                ],
              ),
              const SizedBox(height: 14),
              CardShell(
                state: state,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedPills(
                      state: state,
                      value: filter,
                      items: const {
                        'all': '全部',
                        'pinned': '置顶',
                        'comparison': '对照',
                      },
                      onChanged: (value) => setLocalState(() => filter = value),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '这里收集你从对话中沉淀下来的可复用内容，保留来源会话，方便继续整理与复用。',
                      style: state.textStyle(
                        context,
                        size: 12.5,
                        opacity: 0.5,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _MetaPill(
                          state: state,
                          icon: Icons.push_pin_outlined,
                          label: '已置顶 $pinnedCount',
                        ),
                        const SizedBox(width: 8),
                        _MetaPill(
                          state: state,
                          icon: Icons.auto_awesome_mosaic_outlined,
                          label: '支持文本/对照',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (visibleCards.isEmpty)
                _PanelEmptyState(
                  state: state,
                  icon: Icons.workspace_premium_outlined,
                  title: filter == 'pinned' ? '还没有置顶内容' : '还没有作品片段',
                  body: filter == 'comparison'
                      ? '完成一次多模型对照后，可将结果保存为作品片段。'
                      : '在任意回复的更多菜单中选择「存为作品卡」，把可复用内容沉淀下来。',
                )
              else ...[
                _SectionTitle(
                  state: state,
                  label: filter == 'comparison' ? '对照结果' : '最近沉淀',
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < visibleCards.length; i++) ...[
                  _WorkCardTile(state: state, card: visibleCards[i]),
                  if (i != visibleCards.length - 1) const SizedBox(height: 12),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class BranchGraphOverlay extends StatelessWidget {
  const BranchGraphOverlay({
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
    final sessions = state.chatSessions;
    final ids = sessions.map((session) => session.id).toSet();
    final childrenByParent = <String, List<ChatSession>>{};
    for (final session in sessions) {
      if (session.parentId.trim().isEmpty) continue;
      childrenByParent.putIfAbsent(session.parentId, () => []).add(session);
    }
    for (final children in childrenByParent.values) {
      children.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    final roots =
        sessions
            .where(
              (session) =>
                  session.parentId.trim().isEmpty ||
                  !ids.contains(session.parentId),
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final branchCount = sessions
        .where((session) => session.parentId.trim().isNotEmpty)
        .length;
    final initialSelectedId =
        state.currentSessionId ??
        (roots.isNotEmpty
            ? roots.first.id
            : (sessions.isNotEmpty ? sessions.first.id : ''));
    var selectedSessionId = initialSelectedId;
    var filter = 'all';

    void openSession(ChatSession session) {
      state.selectSession(session);
      onClose();
    }

    return _WorkspacePanel(
      state: state,
      open: open,
      title: '分支图谱',
      subtitle: state.currentSessionTitle,
      icon: Icons.account_tree_outlined,
      onClose: onClose,
      child: StatefulBuilder(
        builder: (context, setLocalState) {
          final selectedSession =
              _sessionById(sessions, selectedSessionId) ??
              (sessions.isNotEmpty ? sessions.first : null);
          final visibleRoots = filter == 'branched'
              ? roots
                    .where(
                      (root) =>
                          (childrenByParent[root.id] ?? const []).isNotEmpty,
                    )
                    .toList()
              : roots;

          if (selectedSession == null) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              physics: const BouncingScrollPhysics(),
              children: [
                _WorkspaceSummary(
                  state: state,
                  items: [
                    _SummaryMetric(label: '会话', value: '${sessions.length}'),
                    _SummaryMetric(label: '根节点', value: '${roots.length}'),
                    _SummaryMetric(label: '分支', value: '$branchCount'),
                  ],
                ),
                const SizedBox(height: 14),
                _PanelEmptyState(
                  state: state,
                  icon: Icons.account_tree_outlined,
                  title: '暂无会话节点',
                  body: '从消息操作中创建分支后，这里会显示它和原会话的关系。',
                ),
              ],
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _WorkspaceSummary(
                      state: state,
                      items: [
                        _SummaryMetric(
                          label: '会话',
                          value: '${sessions.length}',
                        ),
                        _SummaryMetric(label: '根节点', value: '${roots.length}'),
                        _SummaryMetric(label: '分支', value: '$branchCount'),
                      ],
                    ),
                    const SizedBox(height: 14),
                    CardShell(
                      state: state,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SegmentedPills(
                            state: state,
                            value: filter,
                            items: const {'all': '全部会话', 'branched': '仅看有分支'},
                            onChanged: (value) =>
                                setLocalState(() => filter = value),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _MetaPill(
                                  state: state,
                                  icon: Icons.my_location_outlined,
                                  label: state.currentSessionTitle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              _CompactActionButton(
                                state: state,
                                icon: Icons.near_me_rounded,
                                label: '定位当前',
                                onTap: () => setLocalState(() {
                                  selectedSessionId =
                                      state.currentSessionId ??
                                      selectedSessionId;
                                }),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (visibleRoots.isEmpty)
                      _PanelEmptyState(
                        state: state,
                        icon: Icons.call_split_rounded,
                        title: '当前没有分支结构',
                        body: '继续从已有消息分叉后，这里会显示不同会话之间的继承关系。',
                      )
                    else ...[
                      _SectionTitle(state: state, label: '会话结构'),
                      const SizedBox(height: 10),
                      for (var i = 0; i < visibleRoots.length; i++) ...[
                        _BranchGroup(
                          state: state,
                          root: visibleRoots[i],
                          childrenByParent: childrenByParent,
                          currentSessionId: state.currentSessionId,
                          selectedSessionId: selectedSessionId,
                          onFocusSession: (session) => setLocalState(() {
                            selectedSessionId = session.id;
                          }),
                        ),
                        if (i != visibleRoots.length - 1)
                          const SizedBox(height: 12),
                      ],
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: _BranchSelectionDetail(
                  state: state,
                  session: selectedSession,
                  childrenByParent: childrenByParent,
                  isCurrent: selectedSession.id == state.currentSessionId,
                  onOpenSession: () => openSession(selectedSession),
                  onFocusCurrent: () => setLocalState(() {
                    selectedSessionId =
                        state.currentSessionId ?? selectedSessionId;
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

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

class _SummaryMetric {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;
}

class _WorkspaceSummary extends StatelessWidget {
  const _WorkspaceSummary({required this.state, required this.items});

  final WeaviewState state;
  final List<_SummaryMetric> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: state.text(context).withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: state.text(context).withValues(alpha: 0.05),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    items[i].value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: state.textStyle(
                      context,
                      size: 18,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    items[i].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: state.textStyle(context, size: 11.5, opacity: 0.46),
                  ),
                ],
              ),
            ),
          ),
          if (i != items.length - 1) const SizedBox(width: 8),
        ],
      ],
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

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.state,
    required this.icon,
    required this.label,
  });

  final WeaviewState state;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: state.accents[0].withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: state.accents[0]),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: state.textStyle(
                context,
                size: 11.5,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactActionButton extends StatelessWidget {
  const _CompactActionButton({
    required this.state,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final WeaviewState state;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: state.text(context).withValues(alpha: 0.045),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 16, color: state.accents[0]),
              const SizedBox(width: 6),
              Text(
                label,
                style: state.textStyle(
                  context,
                  size: 12.5,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
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
          style: state.textStyle(context, size: 24, weight: FontWeight.w800),
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
                    weight: FontWeight.w800,
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
                        size: 13.5,
                        weight: FontWeight.w700,
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

class _WorkCardTile extends StatelessWidget {
  const _WorkCardTile({required this.state, required this.card});

  final WeaviewState state;
  final WorkCard card;

  @override
  Widget build(BuildContext context) {
    final kindIcon = card.kind == 'comparison'
        ? Icons.view_column_rounded
        : Icons.article_outlined;
    final kindLabel = card.kind == 'comparison' ? '对照结果' : '作品片段';
    return CardShell(
      state: state,
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: state.accents[0].withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(kindIcon, size: 19, color: state.accents[0]),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: state.textStyle(
                        context,
                        size: 14.5,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetaPill(
                          state: state,
                          icon: kindIcon,
                          label: kindLabel,
                        ),
                        if (card.pinned)
                          _MetaPill(
                            state: state,
                            icon: Icons.push_pin_rounded,
                            label: '已置顶',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  TinyIcon(
                    icon: card.pinned
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                    color: card.pinned ? state.accents[0] : state.text(context),
                    onTap: () => state.toggleWorkCardPinned(card.id),
                  ),
                  TinyIcon(
                    icon: Icons.delete_outline_rounded,
                    color: Colors.red,
                    onTap: () => state.deleteWorkCard(card.id),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            card.body,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: state.textStyle(context, size: 13.2, height: 1.6),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              if (card.sourceSessionTitle.trim().isNotEmpty)
                Text(
                  '来源：${card.sourceSessionTitle}',
                  style: state.textStyle(context, size: 11.5, opacity: 0.44),
                ),
              Text(
                _formatDateTime(card.updatedAt, short: true),
                style: state.textStyle(context, size: 11.5, opacity: 0.44),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BranchGroup extends StatelessWidget {
  const _BranchGroup({
    required this.state,
    required this.root,
    required this.childrenByParent,
    required this.currentSessionId,
    required this.selectedSessionId,
    required this.onFocusSession,
  });

  final WeaviewState state;
  final ChatSession root;
  final Map<String, List<ChatSession>> childrenByParent;
  final String? currentSessionId;
  final String selectedSessionId;
  final ValueChanged<ChatSession> onFocusSession;

  @override
  Widget build(BuildContext context) {
    final children = childrenByParent[root.id] ?? const <ChatSession>[];
    return CardShell(
      state: state,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BranchNode(
            state: state,
            session: root,
            currentSessionId: currentSessionId,
            selectedSessionId: selectedSessionId,
            childCount: children.length,
            descendantCount: _descendantCount(root.id, childrenByParent),
            root: true,
            onTap: () => onFocusSession(root),
          ),
          if (children.isEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '这个会话还没有继续分叉。',
              style: state.textStyle(context, size: 12, opacity: 0.42),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.only(left: 18),
              padding: const EdgeInsets.only(left: 16),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: state.accents[0].withValues(alpha: 0.16),
                  ),
                ),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    _BranchTree(
                      state: state,
                      session: children[i],
                      childrenByParent: childrenByParent,
                      currentSessionId: currentSessionId,
                      selectedSessionId: selectedSessionId,
                      depth: 1,
                      onFocusSession: onFocusSession,
                    ),
                    if (i != children.length - 1) const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BranchTree extends StatelessWidget {
  const _BranchTree({
    required this.state,
    required this.session,
    required this.childrenByParent,
    required this.currentSessionId,
    required this.selectedSessionId,
    required this.depth,
    required this.onFocusSession,
  });

  final WeaviewState state;
  final ChatSession session;
  final Map<String, List<ChatSession>> childrenByParent;
  final String? currentSessionId;
  final String selectedSessionId;
  final int depth;
  final ValueChanged<ChatSession> onFocusSession;

  @override
  Widget build(BuildContext context) {
    final children = childrenByParent[session.id] ?? const <ChatSession>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BranchNode(
          state: state,
          session: session,
          currentSessionId: currentSessionId,
          selectedSessionId: selectedSessionId,
          childCount: children.length,
          descendantCount: _descendantCount(session.id, childrenByParent),
          depth: depth,
          onTap: () => onFocusSession(session),
        ),
        if (children.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            margin: const EdgeInsets.only(left: 18),
            padding: const EdgeInsets.only(left: 16),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: state.accents[0].withValues(
                    alpha: math.max(0.08, 0.16 - depth * 0.02),
                  ),
                ),
              ),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  _BranchTree(
                    state: state,
                    session: children[i],
                    childrenByParent: childrenByParent,
                    currentSessionId: currentSessionId,
                    selectedSessionId: selectedSessionId,
                    depth: depth + 1,
                    onFocusSession: onFocusSession,
                  ),
                  if (i != children.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _BranchNode extends StatelessWidget {
  const _BranchNode({
    required this.state,
    required this.session,
    required this.currentSessionId,
    required this.selectedSessionId,
    required this.childCount,
    required this.descendantCount,
    required this.onTap,
    this.root = false,
    this.depth = 0,
  });

  final WeaviewState state;
  final ChatSession session;
  final String? currentSessionId;
  final String selectedSessionId;
  final int childCount;
  final int descendantCount;
  final VoidCallback onTap;
  final bool root;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final isCurrent = session.id == currentSessionId;
    final isSelected = session.id == selectedSessionId;
    final modelMessages = session.messages
        .where((item) => item.role == 'model')
        .length;
    final background = isSelected
        ? state.accents[0].withValues(alpha: 0.1)
        : state.text(context).withValues(alpha: 0.03);
    final border = isSelected
        ? state.accents[0].withValues(alpha: 0.4)
        : state.text(context).withValues(alpha: 0.05);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isCurrent || isSelected
                          ? state.accents[0].withValues(alpha: 0.16)
                          : state.text(context).withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCurrent
                          ? Icons.radio_button_checked_rounded
                          : root
                          ? Icons.account_tree_outlined
                          : Icons.call_split_rounded,
                      size: 17,
                      color: isCurrent || isSelected
                          ? state.accents[0]
                          : state.text(context).withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: state.textStyle(
                            context,
                            size: root ? 14.8 : 13.8,
                            weight: isSelected || root
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _sessionPreview(session),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: state.textStyle(
                            context,
                            size: 11.8,
                            opacity: 0.48,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (isCurrent)
                    _MetaPill(
                      state: state,
                      icon: Icons.my_location,
                      label: '当前会话',
                    ),
                  if (root)
                    _MetaPill(
                      state: state,
                      icon: Icons.account_tree_outlined,
                      label: '根节点',
                    ),
                  if (!root && session.branchedAtIndex >= 0)
                    _MetaPill(
                      state: state,
                      icon: Icons.alt_route_rounded,
                      label: '第 ${session.branchedAtIndex + 1} 条消息后分出',
                    ),
                  _MetaPill(
                    state: state,
                    icon: Icons.chat_bubble_outline_rounded,
                    label: '${session.messages.length} 条消息',
                  ),
                  _MetaPill(
                    state: state,
                    icon: Icons.smart_toy_outlined,
                    label: '$modelMessages 条模型回复',
                  ),
                  if (childCount > 0)
                    _MetaPill(
                      state: state,
                      icon: Icons.fork_right_rounded,
                      label: '$descendantCount 个后续节点',
                    ),
                  _MetaPill(
                    state: state,
                    icon: Icons.schedule_rounded,
                    label: _formatDateTime(session.updatedAt, short: true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BranchSelectionDetail extends StatelessWidget {
  const _BranchSelectionDetail({
    required this.state,
    required this.session,
    required this.childrenByParent,
    required this.isCurrent,
    required this.onOpenSession,
    required this.onFocusCurrent,
  });

  final WeaviewState state;
  final ChatSession session;
  final Map<String, List<ChatSession>> childrenByParent;
  final bool isCurrent;
  final VoidCallback onOpenSession;
  final VoidCallback onFocusCurrent;

  @override
  Widget build(BuildContext context) {
    final modelMessages = session.messages
        .where((item) => item.role == 'model')
        .length;
    return CardShell(
      state: state,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (isCurrent)
                _MetaPill(
                  state: state,
                  icon: Icons.my_location_rounded,
                  label: '当前节点',
                ),
              if (!isCurrent)
                _MetaPill(
                  state: state,
                  icon: Icons.visibility_outlined,
                  label: '已选中节点',
                ),
              if (session.parentId.trim().isNotEmpty)
                _MetaPill(
                  state: state,
                  icon: Icons.call_split_rounded,
                  label: '分支节点',
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            session.title,
            style: state.textStyle(context, size: 18, weight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            _sessionPreview(session),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: state.textStyle(
              context,
              size: 13.2,
              opacity: 0.56,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _DetailMetric(
                  state: state,
                  label: '更新时间',
                  value: _formatDateTime(session.updatedAt),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DetailMetric(
                  state: state,
                  label: '消息数量',
                  value: '${session.messages.length}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DetailMetric(
                  state: state,
                  label: '模型回复',
                  value: '$modelMessages',
                ),
              ),
            ],
          ),
          if ((childrenByParent[session.id] ?? const []).isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '后续分支 ${_descendantCount(session.id, childrenByParent)} 个',
              style: state.textStyle(context, size: 11.5, opacity: 0.46),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SoftButton(
                  state: state,
                  label: '打开会话',
                  icon: Icons.chat_bubble_outline_rounded,
                  accent: true,
                  onTap: onOpenSession,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SoftButton(
                  state: state,
                  label: '定位当前',
                  icon: Icons.my_location_outlined,
                  onTap: onFocusCurrent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({
    required this.state,
    required this.label,
    required this.value,
  });

  final WeaviewState state;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: state.text(context).withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: state.textStyle(context, size: 10.5, opacity: 0.42),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: state.textStyle(
              context,
              size: 12.5,
              weight: FontWeight.w700,
            ),
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

ChatSession? _sessionById(List<ChatSession> sessions, String? id) {
  if (id == null || id.trim().isEmpty) return null;
  for (final session in sessions) {
    if (session.id == id) return session;
  }
  return null;
}

int _descendantCount(
  String sessionId,
  Map<String, List<ChatSession>> childrenByParent,
) {
  final children = childrenByParent[sessionId] ?? const <ChatSession>[];
  var total = children.length;
  for (final child in children) {
    total += _descendantCount(child.id, childrenByParent);
  }
  return total;
}

String _sessionPreview(ChatSession session) {
  for (final message in session.messages.reversed) {
    final content = message.content.trim();
    if (content.isNotEmpty) return content;
  }
  return '继续在这个节点延展对话内容。';
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
