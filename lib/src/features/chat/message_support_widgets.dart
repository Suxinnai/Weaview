import 'package:flutter/material.dart';

import '../../app/weaview_state.dart';

class TranslationBlock extends StatelessWidget {
  const TranslationBlock({
    super.key,
    required this.state,
    required this.text,
    this.alignRight = false,
  });

  final WeaviewState state;
  final String text;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.74,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: state.text(context).withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: state.accents[0].withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: alignRight
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            '译文',
            style: state
                .textStyle(
                  context,
                  size: 11,
                  weight: FontWeight.w800,
                  opacity: 0.45,
                )
                .copyWith(letterSpacing: 1.2),
          ),
          const SizedBox(height: 5),
          Text(
            text.trim(),
            style: state.textStyle(context, size: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class MessageActionBar extends StatelessWidget {
  const MessageActionBar({
    super.key,
    required this.state,
    required this.isModel,
    required this.hasText,
    required this.onCopy,
    required this.onRetry,
    required this.onEdit,
    required this.onTranslate,
    required this.onBranch,
    required this.onDelete,
    required this.onSpeak,
  });

  final WeaviewState state;
  final bool isModel;
  final bool hasText;
  final VoidCallback onCopy;
  final VoidCallback onRetry;
  final VoidCallback onEdit;
  final VoidCallback onTranslate;
  final VoidCallback onBranch;
  final VoidCallback onDelete;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    if (!hasText) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: isModel ? WrapAlignment.start : WrapAlignment.end,
      children: [
        _MessageIconAction(
          state: state,
          icon: Icons.content_copy_rounded,
          tooltip: '复制',
          onTap: onCopy,
        ),
        _MessageIconAction(
          state: state,
          icon: Icons.refresh_rounded,
          tooltip: '重试',
          onTap: onRetry,
        ),
        _MessageIconAction(
          state: state,
          icon: Icons.edit_outlined,
          tooltip: '编辑',
          onTap: onEdit,
        ),
        _MessageIconAction(
          state: state,
          icon: Icons.volume_up_outlined,
          tooltip: '朗读',
          onTap: onSpeak,
        ),
        _MessageMoreAction(
          state: state,
          onTranslate: onTranslate,
          onBranch: onBranch,
          onDelete: onDelete,
        ),
      ],
    );
  }
}

class _MessageIconAction extends StatelessWidget {
  const _MessageIconAction({
    required this.state,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final WeaviewState state;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = state.isDark(context);
    final text = state.text(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: state.layer(context).withValues(alpha: dark ? 0.62 : 0.74),
        shape: const CircleBorder(),
        elevation: dark ? 0 : 4,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, size: 16.5, color: text.withValues(alpha: 0.62)),
          ),
        ),
      ),
    );
  }
}

class _MessageMoreAction extends StatelessWidget {
  const _MessageMoreAction({
    required this.state,
    required this.onTranslate,
    required this.onBranch,
    required this.onDelete,
  });

  final WeaviewState state;
  final VoidCallback onTranslate;
  final VoidCallback onBranch;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return _MessageIconAction(
      state: state,
      icon: Icons.more_vert_rounded,
      tooltip: '更多',
      onTap: () async {
        final box = context.findRenderObject() as RenderBox?;
        final overlay =
            Navigator.of(context).overlay?.context.findRenderObject()
                as RenderBox?;
        if (box == null || overlay == null) return;
        final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
        final bottomRight = box.localToGlobal(
          box.size.bottomRight(Offset.zero),
          ancestor: overlay,
        );
        final selected = await showMenu<String>(
          context: context,
          color: state.layer(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          position: RelativeRect.fromRect(
            Rect.fromPoints(topLeft, bottomRight),
            Offset.zero & overlay.size,
          ),
          items: const [
            PopupMenuItem(
              value: 'translate',
              child: Row(
                children: [
                  Icon(Icons.translate_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('翻译'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'branch',
              child: Row(
                children: [
                  Icon(Icons.call_split_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('创建分支'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('删除'),
                ],
              ),
            ),
          ],
        );
        if (selected == 'translate') onTranslate();
        if (selected == 'branch') onBranch();
        if (selected == 'delete') onDelete();
      },
    );
  }
}

class ReasoningPanel extends StatefulWidget {
  const ReasoningPanel({
    super.key,
    required this.state,
    required this.reasoning,
    required this.thinking,
  });

  final WeaviewState state;
  final String reasoning;
  final bool thinking;

  @override
  State<ReasoningPanel> createState() => _ReasoningPanelState();
}

class _ReasoningPanelState extends State<ReasoningPanel> {
  bool expanded = false;
  bool autoExpanded = false;

  @override
  void initState() {
    super.initState();
    expanded = widget.thinking;
    autoExpanded = widget.thinking;
  }

  @override
  void didUpdateWidget(covariant ReasoningPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.thinking && !oldWidget.thinking) {
      expanded = true;
      autoExpanded = true;
    }
    if (!widget.thinking && oldWidget.thinking && autoExpanded) {
      expanded = false;
      autoExpanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasReasoning = widget.reasoning.trim().isNotEmpty;
    return Material(
      color: widget.state.text(context).withValues(alpha: 0.045),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: hasReasoning
            ? () => setState(() {
                autoExpanded = false;
                expanded = !expanded;
              })
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.state.accents[0].withValues(alpha: 0.28),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  widget.thinking
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: widget.state.accents[0],
                          ),
                        )
                      : Icon(
                          Icons.psychology_alt_outlined,
                          size: 16,
                          color: widget.state
                              .text(context)
                              .withValues(alpha: 0.52),
                        ),
                  const SizedBox(width: 8),
                  Text(
                    widget.thinking ? '正在思考' : '思考链',
                    style: widget.state.textStyle(
                      context,
                      size: 12.5,
                      weight: FontWeight.w700,
                      opacity: 0.62,
                    ),
                  ),
                  if (hasReasoning) ...[
                    const SizedBox(width: 6),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 17,
                      color: widget.state.text(context).withValues(alpha: 0.42),
                    ),
                  ],
                ],
              ),
              if (expanded && hasReasoning)
                Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Text(
                    widget.reasoning.trim(),
                    style: widget.state.textStyle(
                      context,
                      size: 12.5,
                      height: 1.55,
                      opacity: 0.58,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
