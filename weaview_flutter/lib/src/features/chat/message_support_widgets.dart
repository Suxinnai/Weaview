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
    required this.onTranslate,
  });

  final WeaviewState state;
  final bool isModel;
  final bool hasText;
  final VoidCallback onCopy;
  final VoidCallback onRetry;
  final VoidCallback onTranslate;

  @override
  Widget build(BuildContext context) {
    if (!hasText) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isModel)
          _MessageActionPill(
            state: state,
            icon: Icons.refresh_rounded,
            label: '重试',
            onTap: onRetry,
          ),
        _MessageActionPill(
          state: state,
          icon: Icons.content_copy_rounded,
          label: '复制',
          onTap: onCopy,
        ),
        _MessageActionPill(
          state: state,
          icon: Icons.translate_rounded,
          label: '翻译',
          onTap: onTranslate,
        ),
      ],
    );
  }
}

class _MessageActionPill extends StatelessWidget {
  const _MessageActionPill({
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
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: state.text(context).withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: state.text(context).withValues(alpha: 0.55),
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: state.textStyle(context, size: 11.5, opacity: 0.58),
                ),
              ],
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
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: expanded && hasReasoning
                    ? Padding(
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
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
