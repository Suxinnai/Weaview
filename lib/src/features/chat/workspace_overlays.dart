import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/weaview_state.dart';
import '../../domain/models.dart';
import '../../shared/widgets/shared_widgets.dart';

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
    return _WorkspacePanel(
      state: state,
      open: open,
      title: '编织板',
      subtitle: '把好回复沉淀成可复用作品片段',
      icon: Icons.dashboard_customize_outlined,
      onClose: onClose,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        physics: const BouncingScrollPhysics(),
        children: [
          _WorkspaceSummary(
            state: state,
            items: [
              _SummaryMetric(label: '作品卡', value: '${cards.length}'),
              _SummaryMetric(label: '对照卡', value: '$comparisonCount'),
              _SummaryMetric(
                label: '置顶',
                value: '${cards.where((card) => card.pinned).length}',
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (cards.isEmpty)
            _PanelEmptyState(
              state: state,
              icon: Icons.workspace_premium_outlined,
              title: '还没有作品卡',
              body: '在任意回复的更多菜单中选择「存为作品卡」，把片段沉淀为可复用作品。',
            )
          else
            for (var i = 0; i < cards.length; i++) ...[
              _WorkCardTile(state: state, card: cards[i]),
              if (i != cards.length - 1) const SizedBox(height: 12),
            ],
        ],
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
    final roots = sessions
        .where(
          (session) =>
              session.parentId.trim().isEmpty ||
              !ids.contains(session.parentId),
        )
        .toList();
    final branchCount = sessions
        .where((session) => session.parentId.trim().isNotEmpty)
        .length;

    void selectSession(ChatSession session) {
      state.selectSession(session);
      onClose();
    }

    return _WorkspacePanel(
      state: state,
      open: open,
      title: '分支图谱',
      subtitle: '查看会话如何从关键消息继续分叉',
      icon: Icons.account_tree_outlined,
      onClose: onClose,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
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
          if (sessions.isEmpty)
            _PanelEmptyState(
              state: state,
              icon: Icons.account_tree_outlined,
              title: '暂无会话节点',
              body: '从消息操作中创建分支后，这里会显示它和原会话的关系。',
            )
          else
            for (final root in roots)
              _BranchGroup(
                state: state,
                root: root,
                childrenByParent: childrenByParent,
                onSelectSession: selectSession,
              ),
        ],
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
    final records = state.sortedTokenUsageRecords;
    final promptTokens = records.fold(
      0,
      (sum, item) => sum + item.promptTokens,
    );
    final completionTokens = records.fold(
      0,
      (sum, item) => sum + item.completionTokens,
    );
    final byModel = _usageByModel(records);
    return _WorkspacePanel(
      state: state,
      open: open,
      title: '用量统计',
      subtitle: 'Token 与花费为本地估算值',
      icon: Icons.payments_outlined,
      onClose: onClose,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        physics: const BouncingScrollPhysics(),
        children: [
          _UsageHero(
            state: state,
            totalTokens: state.totalTokenUsage,
            costUsd: state.totalEstimatedCostUsd,
          ),
          const SizedBox(height: 12),
          _WorkspaceSummary(
            state: state,
            items: [
              _SummaryMetric(
                label: '输入',
                value: _formatTokenCount(promptTokens),
              ),
              _SummaryMetric(
                label: '输出',
                value: _formatTokenCount(completionTokens),
              ),
              _SummaryMetric(label: '调用', value: '${records.length}'),
            ],
          ),
          const SizedBox(height: 14),
          if (records.isEmpty)
            _PanelEmptyState(
              state: state,
              icon: Icons.query_stats_rounded,
              title: '暂无用量记录',
              body: '完成一次普通聊天、联网聊天、翻译或多模型对照后，这里会显示估算 token 与花费。',
            )
          else ...[
            _SectionTitle(state: state, label: '按模型汇总'),
            const SizedBox(height: 10),
            for (final item in byModel.take(6)) ...[
              _UsageModelRow(state: state, item: item),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
            _SectionTitle(state: state, label: '最近调用'),
            const SizedBox(height: 10),
            for (final record in records.take(8)) ...[
              _UsageRecordTile(state: state, record: record),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
            SoftButton(
              state: state,
              label: '清空用量统计',
              icon: Icons.delete_sweep_outlined,
              danger: true,
              onTap: state.clearTokenUsageRecords,
            ),
          ],
        ],
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
    final width = math.min(430.0, MediaQuery.sizeOf(context).width);
    return IgnorePointer(
      ignoring: !open,
      child: Stack(
        children: [
          AnimatedOpacity(
            opacity: open ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: GestureDetector(
              onTap: onClose,
              child: Container(
                color: Colors.black.withValues(
                  alpha: state.isDark(context) ? 0.46 : 0.18,
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            top: 0,
            right: open ? 0 : -width,
            bottom: 0,
            width: width,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                bottomLeft: Radius.circular(28),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  color: state.layer(context).withValues(alpha: 0.94),
                  child: SafeArea(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: state.accents[0].withValues(
                                    alpha: 0.14,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  icon,
                                  size: 19,
                                  color: state.accents[0],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: state.textStyle(
                                        context,
                                        size: 18,
                                        weight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: state.textStyle(
                                        context,
                                        size: 12,
                                        opacity: 0.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconCircleButton(
                                icon: Icons.close_rounded,
                                onTap: onClose,
                                color: state.text(context),
                              ),
                            ],
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: state.text(context).withValues(alpha: 0.06),
                        ),
                        Expanded(child: child),
                      ],
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
                color: state.text(context).withValues(alpha: 0.045),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: state.text(context).withValues(alpha: 0.045),
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
                      size: 17,
                      weight: FontWeight.w700,
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

class _UsageHero extends StatelessWidget {
  const _UsageHero({
    required this.state,
    required this.totalTokens,
    required this.costUsd,
  });

  final WeaviewState state;
  final int totalTokens;
  final double costUsd;

  @override
  Widget build(BuildContext context) {
    return CardShell(
      state: state,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: state.accents[0].withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.query_stats_rounded,
              color: state.accents[0],
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatTokenCount(totalTokens),
                  style: state.textStyle(
                    context,
                    size: 24,
                    weight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '累计 token',
                  style: state.textStyle(context, size: 12, opacity: 0.48),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatUsd(costUsd),
                style: state.textStyle(
                  context,
                  size: 17,
                  weight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '估算花费',
                style: state.textStyle(context, size: 12, opacity: 0.48),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UsageModelSummary {
  const _UsageModelSummary({
    required this.provider,
    required this.model,
    required this.tokens,
    required this.costUsd,
    required this.calls,
  });

  final String provider;
  final String model;
  final int tokens;
  final double costUsd;
  final int calls;
}

class _UsageModelRow extends StatelessWidget {
  const _UsageModelRow({required this.state, required this.item});

  final WeaviewState state;
  final _UsageModelSummary item;

  @override
  Widget build(BuildContext context) {
    return CardShell(
      state: state,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Icon(Icons.memory_rounded, size: 18, color: state.accents[0]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.provider} · ${item.model}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: state.textStyle(
                    context,
                    size: 13.5,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.calls} 次调用 · ${_formatTokenCount(item.tokens)}',
                  style: state.textStyle(context, size: 11.5, opacity: 0.46),
                ),
              ],
            ),
          ),
          Text(
            _formatUsd(item.costUsd),
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
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(_sourceIcon(record.source), size: 18, color: state.accents[0]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _sourceLabel(record.source),
                  style: state.textStyle(
                    context,
                    size: 13,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${record.provider} · ${record.model}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: state.textStyle(context, size: 11.5, opacity: 0.44),
                ),
              ],
            ),
          ),
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
              const SizedBox(height: 3),
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

List<_UsageModelSummary> _usageByModel(List<TokenUsageRecord> records) {
  final buckets = <String, _MutableUsageBucket>{};
  for (final record in records) {
    final key = '${record.provider}|${record.model}';
    final bucket = buckets.putIfAbsent(
      key,
      () => _MutableUsageBucket(record.provider, record.model),
    );
    bucket
      ..tokens += record.totalTokens
      ..costUsd += record.estimatedCostUsd
      ..calls += 1;
  }
  final items = [
    for (final bucket in buckets.values)
      _UsageModelSummary(
        provider: bucket.provider,
        model: bucket.model,
        tokens: bucket.tokens,
        costUsd: bucket.costUsd,
        calls: bucket.calls,
      ),
  ]..sort((a, b) => b.tokens.compareTo(a.tokens));
  return items;
}

class _MutableUsageBucket {
  _MutableUsageBucket(this.provider, this.model);

  final String provider;
  final String model;
  int tokens = 0;
  double costUsd = 0;
  int calls = 0;
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

class _WorkCardTile extends StatelessWidget {
  const _WorkCardTile({required this.state, required this.card});

  final WeaviewState state;
  final WorkCard card;

  @override
  Widget build(BuildContext context) {
    return CardShell(
      state: state,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                card.kind == 'comparison'
                    ? Icons.view_column_rounded
                    : Icons.article_outlined,
                size: 18,
                color: state.accents[0],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  card.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: state.textStyle(
                    context,
                    size: 14.5,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
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
          const SizedBox(height: 10),
          Text(
            card.body,
            maxLines: 7,
            overflow: TextOverflow.ellipsis,
            style: state.textStyle(context, size: 13.2, height: 1.52),
          ),
          if (card.sourceSessionTitle.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '来源：${card.sourceSessionTitle}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: state.textStyle(context, size: 11.5, opacity: 0.44),
            ),
          ],
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
    required this.onSelectSession,
  });

  final WeaviewState state;
  final ChatSession root;
  final Map<String, List<ChatSession>> childrenByParent;
  final ValueChanged<ChatSession> onSelectSession;

  @override
  Widget build(BuildContext context) {
    final children = childrenByParent[root.id] ?? const <ChatSession>[];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: CardShell(
        state: state,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BranchNode(
              state: state,
              session: root,
              root: true,
              onTap: () => onSelectSession(root),
            ),
            if (children.isEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '暂无分支',
                style: state.textStyle(context, size: 12, opacity: 0.42),
              ),
            ] else ...[
              const SizedBox(height: 12),
              for (final child in children)
                Padding(
                  padding: const EdgeInsets.only(left: 14, bottom: 10),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: state.accents[0].withValues(alpha: 0.28),
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: _BranchTree(
                        state: state,
                        session: child,
                        childrenByParent: childrenByParent,
                        onSelectSession: onSelectSession,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BranchTree extends StatelessWidget {
  const _BranchTree({
    required this.state,
    required this.session,
    required this.childrenByParent,
    required this.onSelectSession,
  });

  final WeaviewState state;
  final ChatSession session;
  final Map<String, List<ChatSession>> childrenByParent;
  final ValueChanged<ChatSession> onSelectSession;

  @override
  Widget build(BuildContext context) {
    final children = childrenByParent[session.id] ?? const <ChatSession>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BranchNode(
          state: state,
          session: session,
          onTap: () => onSelectSession(session),
        ),
        if (children.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final child in children)
            Padding(
              padding: const EdgeInsets.only(left: 14, bottom: 10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: state.accents[0].withValues(alpha: 0.18),
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: _BranchTree(
                    state: state,
                    session: child,
                    childrenByParent: childrenByParent,
                    onSelectSession: onSelectSession,
                  ),
                ),
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
    required this.onTap,
    this.root = false,
  });

  final WeaviewState state;
  final ChatSession session;
  final VoidCallback onTap;
  final bool root;

  @override
  Widget build(BuildContext context) {
    final selected = session.id == state.currentSessionId;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: selected
                    ? state.accents[0].withValues(alpha: 0.22)
                    : root
                    ? state.accents[0].withValues(alpha: 0.16)
                    : state.text(context).withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                selected
                    ? Icons.check_circle_rounded
                    : root
                    ? Icons.radio_button_checked_rounded
                    : Icons.call_split_rounded,
                size: 15,
                color: root || selected
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
                      size: root ? 14.2 : 13.4,
                      weight: root || selected
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                  if (!root && session.branchedAtIndex >= 0)
                    Text(
                      '从第 ${session.branchedAtIndex + 1} 条消息分出',
                      style: state.textStyle(
                        context,
                        size: 11.5,
                        opacity: 0.42,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
