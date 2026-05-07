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
    return Row(
      mainAxisSize: MainAxisSize.min,
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
        PopupMenuButton<String>(
          tooltip: '更多',
          padding: EdgeInsets.zero,
          icon: Icon(
            Icons.more_vert_rounded,
            size: 18,
            color: state.text(context).withValues(alpha: 0.62),
          ),
          color: state.layer(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onSelected: (value) {
            if (value == 'translate') onTranslate();
            if (value == 'branch') onBranch();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (context) => const [
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
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Material(
          color: state.text(context).withValues(alpha: 0.045),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 34,
              height: 34,
              child: Icon(
                icon,
                size: 17,
                color: state.text(context).withValues(alpha: 0.62),
              ),
            ),
          ),
        ),
      ),
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
