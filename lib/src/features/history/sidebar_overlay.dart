// ignore_for_file: use_key_in_widget_constructors

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/weaview_state.dart';
import '../../domain/models.dart';
import '../../shared/widgets/shared_widgets.dart';

class SidebarOverlay extends StatelessWidget {
  const SidebarOverlay({
    required this.state,
    required this.open,
    required this.onClose,
    required this.onSettings,
    required this.onUsageStats,
  });

  final WeaviewState state;
  final bool open;
  final VoidCallback onClose;
  final VoidCallback onSettings;
  final VoidCallback onUsageStats;

  @override
  Widget build(BuildContext context) {
    final width = math.min(286.0, MediaQuery.sizeOf(context).width * 0.84);
    final groupedSessions = _groupSessionsByDate(state.chatSessions);
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
                  alpha: state.isDark(context) ? 0.42 : 0.12,
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            top: 0,
            bottom: 0,
            left: open ? 0 : -width,
            width: width,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: Container(
                  decoration: BoxDecoration(
                    color: state.layer(context).withValues(alpha: 0.92),
                    border: Border(
                      right: BorderSide(
                        color: state.text(context).withValues(alpha: 0.07),
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.20),
                        blurRadius: 36,
                        offset: const Offset(16, 0),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 20, 14, 14),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: state.accents[0],
                                    width: 0.8,
                                  ),
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: state.accents,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '织境',
                                style: state
                                    .poeticTextStyle(
                                      context,
                                      size: 15,
                                      weight: FontWeight.w500,
                                      opacity: 0.86,
                                    )
                                    .copyWith(letterSpacing: 4),
                              ),
                              const Spacer(),
                              IconCircleButton(
                                icon: Icons.close_rounded,
                                onTap: onClose,
                                color: state.text(context),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: state.accents[0].withValues(
                                alpha: 0.16,
                              ),
                              foregroundColor: state.text(context),
                              elevation: 0,
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            onPressed: () {
                              state.newSession();
                              onClose();
                            },
                            icon: const Icon(Icons.add_rounded, size: 19),
                            label: const Text('新的织梦'),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: _SidebarModeButton(
                            state: state,
                            icon: Icons.payments_outlined,
                            label: '用量统计',
                            subtitle: _formatSidebarCost(
                              state.totalEstimatedCostUsd,
                            ),
                            onTap: onUsageStats,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                          child: _SidebarModeButton(
                            state: state,
                            icon: Icons.settings_outlined,
                            label: '设置',
                            subtitle: '提供商、模型与偏好',
                            onTap: onSettings,
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(14, 24, 14, 12),
                            physics: const BouncingScrollPhysics(),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '最近对话',
                                        style: state
                                            .textStyle(
                                              context,
                                              size: 10,
                                              weight: FontWeight.w700,
                                              opacity: 0.36,
                                            )
                                            .copyWith(letterSpacing: 1.8),
                                      ),
                                    ),
                                    Icon(
                                      Icons.search_rounded,
                                      size: 20,
                                      color: state
                                          .text(context)
                                          .withValues(alpha: 0.56),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (state.chatSessions.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Text(
                                    '暂无历史记录',
                                    textAlign: TextAlign.center,
                                    style: state.textStyle(
                                      context,
                                      size: 12,
                                      opacity: 0.4,
                                    ),
                                  ),
                                )
                              else
                                for (final entry
                                    in groupedSessions.entries) ...[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      10,
                                      12,
                                      6,
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          entry.key,
                                          style: state
                                              .textStyle(
                                                context,
                                                size: 10,
                                                weight: FontWeight.w700,
                                                opacity: 0.36,
                                              )
                                              .copyWith(letterSpacing: 1.6),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '${entry.value.length}',
                                          style: state.textStyle(
                                            context,
                                            size: 10,
                                            weight: FontWeight.w600,
                                            opacity: 0.28,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  for (final session in entry.value)
                                    _HistoryListTile(
                                      state: state,
                                      session: session,
                                      selected:
                                          session.id == state.currentSessionId,
                                      onTap: () {
                                        state.selectSession(session);
                                        onClose();
                                      },
                                      onMore: (tileContext) =>
                                          _showHistoryActions(
                                            context,
                                            tileContext,
                                            session,
                                          ),
                                    ),
                                ],
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: state
                                  .text(context)
                                  .withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                AvatarDot(
                                  value: state.userAvatar,
                                  fallbackIcon: Icons.person_outline_rounded,
                                  imageSize: 42,
                                  accent: state.accents[0],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        state.userName,
                                        overflow: TextOverflow.ellipsis,
                                        style: state.textStyle(
                                          context,
                                          size: 13,
                                          weight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Pro Plan · 已同步',
                                        style: state.textStyle(
                                          context,
                                          size: 10.5,
                                          opacity: 0.46,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconCircleButton(
                                  icon: Icons.settings_outlined,
                                  onTap: onSettings,
                                  color: state.text(context),
                                  size: 34,
                                  opacity: 0.62,
                                ),
                              ],
                            ),
                          ),
                        ),
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

  Future<void> _showHistoryActions(
    BuildContext context,
    BuildContext tileContext,
    ChatSession session,
  ) async {
    final tileBox = tileContext.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final overlaySize = overlay?.size ?? MediaQuery.sizeOf(context);
    final tileSize = tileBox?.size ?? Size.zero;
    final tileOffset =
        tileBox?.localToGlobal(Offset.zero, ancestor: overlay) ?? Offset.zero;
    const menuWidth = 222.0;
    final menuHeight = session.pinned ? 156.0 : 156.0;
    final left = math
        .min(tileOffset.dx + 10, overlaySize.width - menuWidth - 10)
        .clamp(10.0, overlaySize.width - menuWidth - 10);
    final top = math
        .min(
          tileOffset.dy + tileSize.height - 2,
          overlaySize.height - menuHeight - 12,
        )
        .clamp(10.0, overlaySize.height - menuHeight - 12);
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        left,
        top,
        overlaySize.width - left - menuWidth,
        overlaySize.height - top,
      ),
      color: state.layer(context),
      elevation: 12,
      constraints: const BoxConstraints(
        minWidth: menuWidth,
        maxWidth: menuWidth,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      items: [
        _historyMenuItem(
          context,
          value: 'pin',
          icon: session.pinned
              ? Icons.push_pin_outlined
              : Icons.push_pin_rounded,
          label: session.pinned ? '取消置顶梦境' : '置顶梦境',
        ),
        _historyMenuItem(
          context,
          value: 'title',
          icon: Icons.auto_fix_high_rounded,
          label: '重新生成标题',
        ),
        _historyMenuItem(
          context,
          value: 'delete',
          icon: Icons.delete_outline_rounded,
          label: '删除梦境',
          danger: true,
        ),
      ],
    );
    if (!context.mounted || action == null) return;
    if (action == 'pin') {
      state.togglePinSession(session.id);
      return;
    }
    if (action == 'title') {
      try {
        final changed = await state.regenerateSessionTitle(session.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(changed ? '标题已重新生成。' : '请先配置标题总结模型。')),
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error.toString().replaceFirst('Exception: ', '')),
            ),
          );
        }
      }
      return;
    }
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('删除梦境'),
          content: Text('确定删除「${session.title}」吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除'),
            ),
          ],
        ),
      );
      if (confirmed == true) state.deleteSession(session.id);
    }
  }

  PopupMenuItem<String> _historyMenuItem(
    BuildContext context, {
    required String value,
    required IconData icon,
    required String label,
    bool danger = false,
  }) {
    final color = danger ? Colors.redAccent : state.text(context);
    return PopupMenuItem<String>(
      value: value,
      height: 48,
      child: Row(
        children: [
          Icon(
            icon,
            size: 19,
            color: color.withValues(alpha: danger ? 0.92 : 0.7),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: state
                .textStyle(context, size: 14, weight: FontWeight.w600)
                .copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _SidebarModeButton extends StatelessWidget {
  const _SidebarModeButton({
    required this.state,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final WeaviewState state;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final text = state.text(context);
    return Material(
      color: text.withValues(alpha: 0.045),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          child: Row(
            children: [
              Icon(icon, size: 17, color: text.withValues(alpha: 0.62)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: state.textStyle(
                    context,
                    size: 13,
                    weight: FontWeight.w500,
                    opacity: 0.8,
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 8),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: state.textStyle(
                    context,
                    size: 11,
                    weight: FontWeight.w500,
                    opacity: 0.4,
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: text.withValues(alpha: 0.32),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryListTile extends StatelessWidget {
  const _HistoryListTile({
    required this.state,
    required this.session,
    required this.selected,
    required this.onTap,
    required this.onMore,
  });

  final WeaviewState state;
  final ChatSession session;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<BuildContext> onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? state.text(context).withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          onLongPress: () => onMore(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 10, 6, 10),
            child: Row(
              children: [
                if (session.pinned) ...[
                  Icon(
                    Icons.push_pin_rounded,
                    size: 14,
                    color: state.accents[0].withValues(alpha: 0.72),
                  ),
                  const SizedBox(width: 7),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: state.textStyle(
                          context,
                          size: 13.5,
                          weight: selected ? FontWeight.w600 : FontWeight.w400,
                          opacity: selected ? 1 : 0.72,
                          height: 1.22,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatUpdatedTime(session.updatedAt),
                        style: state.textStyle(
                          context,
                          size: 10,
                          weight: FontWeight.w600,
                          opacity: 0.32,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '更多操作',
                  onPressed: () => onMore(context),
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: state.text(context).withValues(alpha: 0.42),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatSidebarCost(double value) {
  if (value <= 0) return r'$0';
  if (value < 0.01) return '\$${value.toStringAsFixed(4)}';
  if (value < 1) return '\$${value.toStringAsFixed(3)}';
  return '\$${value.toStringAsFixed(2)}';
}

Map<String, List<ChatSession>> _groupSessionsByDate(
  List<ChatSession> sessions,
) {
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final startOfYesterday = startOfToday.subtract(const Duration(days: 1));
  final groups = <String, List<ChatSession>>{'今天': [], '昨天': [], '更早': []};
  for (final session in sessions) {
    final updated = DateTime.fromMillisecondsSinceEpoch(session.updatedAt);
    if (!updated.isBefore(startOfToday)) {
      groups['今天']!.add(session);
    } else if (!updated.isBefore(startOfYesterday)) {
      groups['昨天']!.add(session);
    } else {
      groups['更早']!.add(session);
    }
  }
  groups.removeWhere((_, value) => value.isEmpty);
  return groups;
}

String _formatUpdatedTime(int timestamp) {
  final updated = DateTime.fromMillisecondsSinceEpoch(timestamp);
  final hh = updated.hour.toString().padLeft(2, '0');
  final mm = updated.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}
