import 'dart:math' as math;

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

class ImageGenerationPanel extends StatefulWidget {
  const ImageGenerationPanel({super.key, required this.state});

  final WeaviewState state;

  @override
  State<ImageGenerationPanel> createState() => _ImageGenerationPanelState();
}

class _ImageGenerationPanelState extends State<ImageGenerationPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final dark = state.isDark(context);
    final text = state.text(context);
    return Container(
      width: math.min(MediaQuery.sizeOf(context).width - 92, 284),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: state.layer(context).withValues(alpha: dark ? 0.34 : 0.52),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: text.withValues(alpha: dark ? 0.08 : 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.16 : 0.045),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '正在生成图片',
            style: state.textStyle(
              context,
              size: 13.5,
              weight: FontWeight.w700,
              opacity: 0.66,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '正在细化画面，请稍候。',
            style: state.textStyle(context, size: 12.5, opacity: 0.46),
          ),
          const SizedBox(height: 14),
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _ImageGenerationPainter(
                      progress: _controller.value,
                      dotColor: text,
                      accent: state.accents[0],
                      background: state.background(context),
                      dark: dark,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageGenerationPainter extends CustomPainter {
  const _ImageGenerationPainter({
    required this.progress,
    required this.dotColor,
    required this.accent,
    required this.background,
    required this.dark,
  });

  final double progress;
  final Color dotColor;
  final Color accent;
  final Color background;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(background, Colors.white, dark ? 0.06 : 0.70)!,
          Color.lerp(background, accent, dark ? 0.16 : 0.10)!,
          Color.lerp(background, Colors.black, dark ? 0.05 : 0.025)!,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, fill);

    final dotPaint = Paint();
    final spacing = size.width / 14;
    final sweep = progress * 2 - 0.25;
    for (var y = 1; y < 14; y++) {
      for (var x = 1; x < 14; x++) {
        final nx = x / 14;
        final ny = y / 14;
        final diagonal = (nx + ny) / 2;
        final distance = (diagonal - sweep).abs();
        final wave = (1 - distance * 4.2).clamp(0.0, 1.0);
        final base = dark ? 0.18 : 0.16;
        final alpha = base + wave * (dark ? 0.50 : 0.34);
        final radius = 0.9 + wave * 1.1;
        dotPaint.color = Color.lerp(
          dotColor,
          accent,
          wave * 0.55,
        )!.withValues(alpha: alpha);
        canvas.drawCircle(Offset(x * spacing, y * spacing), radius, dotPaint);
      }
    }

    final highlight = Paint()
      ..shader = RadialGradient(
        center: Alignment(-0.45 + progress * 0.9, -0.2),
        radius: 0.72,
        colors: [
          accent.withValues(alpha: dark ? 0.18 : 0.16),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, highlight);
  }

  @override
  bool shouldRepaint(covariant _ImageGenerationPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.dotColor != dotColor ||
        oldDelegate.accent != accent ||
        oldDelegate.background != background ||
        oldDelegate.dark != dark;
  }
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
