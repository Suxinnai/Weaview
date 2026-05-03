part of '../main.dart';

class _ProviderModel {
  const _ProviderModel({required this.provider, required this.model});

  final AiProvider provider;
  final AiModel model;
}

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({
    required this.state,
    required this.message,
    required this.assistantAvatar,
    required this.userAvatar,
    required this.onCopy,
    required this.onRetry,
    required this.onTranslate,
    required this.onDownloadAttachment,
  });

  final WeaviewState state;
  final ChatMessage message;
  final String assistantAvatar;
  final String userAvatar;
  final VoidCallback onCopy;
  final VoidCallback onRetry;
  final VoidCallback onTranslate;
  final ValueChanged<MessageAttachment> onDownloadAttachment;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _actionsVisible = false;

  void _toggleActions() {
    setState(() => _actionsVisible = !_actionsVisible);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final message = widget.message;
    final isUser = message.role == 'user';
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;
    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _toggleActions,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: state.isDark(context)
                            ? Colors.white.withValues(alpha: 0.055)
                            : _accentMint.withValues(alpha: 0.12),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(25),
                          topRight: Radius.circular(8),
                          bottomLeft: Radius.circular(25),
                          bottomRight: Radius.circular(25),
                        ),
                        border: Border.all(
                          color: state.isDark(context)
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.white.withValues(alpha: 0.9),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (message.attachments.isNotEmpty) ...[
                            _MessageAttachmentGrid(
                              state: state,
                              attachments: message.attachments,
                              onDownload: widget.onDownloadAttachment,
                            ),
                            if (message.content.trim().isNotEmpty)
                              const SizedBox(height: 10),
                          ],
                          if (message.content.trim().isNotEmpty)
                            Text(
                              message.content,
                              style: state.textStyle(
                                context,
                                size: 14.5,
                                height: 1.55,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                    child: _actionsVisible
                        ? Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _MessageActionBar(
                              state: state,
                              isModel: false,
                              hasText: message.content.trim().isNotEmpty,
                              onCopy: widget.onCopy,
                              onRetry: widget.onRetry,
                              onTranslate: widget.onTranslate,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  if (message.translation.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _TranslationBlock(
                      state: state,
                      text: message.translation,
                      alignRight: true,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _AvatarDot(
                value: widget.userAvatar,
                fallbackIcon: Icons.person_outline_rounded,
                imageSize: 28,
                accent: state.accents[1],
              ),
            ),
          ],
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 9),
            child: _AvatarDot(
              value: widget.assistantAvatar,
              fallbackIcon: Icons.auto_awesome_rounded,
              imageSize: 28,
              accent: state.accents[0],
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerUp: (_) {
                  if (!message.isThinking) _toggleActions();
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.reasoning.trim().isNotEmpty ||
                        message.isThinking) ...[
                      _ReasoningPanel(
                        state: state,
                        reasoning: message.reasoning,
                        thinking: message.isThinking,
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (message.content.trim().isEmpty && message.isThinking)
                      _ThinkingDots(state: state)
                    else
                      MarkdownBody(
                        data: message.content.isEmpty ? ' ' : message.content,
                        selectable: true,
                        styleSheet:
                            MarkdownStyleSheet.fromTheme(
                              Theme.of(context),
                            ).copyWith(
                              p: state.textStyle(
                                context,
                                size: 15,
                                height: 1.78,
                              ),
                              h1: state.textStyle(
                                context,
                                size: 24,
                                weight: FontWeight.w600,
                              ),
                              h2: state.textStyle(
                                context,
                                size: 21,
                                weight: FontWeight.w600,
                              ),
                              h3: state.textStyle(
                                context,
                                size: 18,
                                weight: FontWeight.w600,
                              ),
                              listBullet: state.textStyle(
                                context,
                                size: 15,
                                height: 1.6,
                              ),
                              code: state
                                  .textStyle(context, size: 13)
                                  .copyWith(
                                    backgroundColor: state
                                        .text(context)
                                        .withValues(alpha: 0.06),
                                    fontFamily: 'monospace',
                                  ),
                              codeblockDecoration: BoxDecoration(
                                color: state
                                    .text(context)
                                    .withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              blockquoteDecoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: state.accents[0].withValues(
                                      alpha: 0.8,
                                    ),
                                    width: 3,
                                  ),
                                ),
                              ),
                            ),
                      ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOut,
                      child: _actionsVisible
                          ? Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _MessageActionBar(
                                state: state,
                                isModel: true,
                                hasText: message.content.trim().isNotEmpty,
                                onCopy: widget.onCopy,
                                onRetry: widget.onRetry,
                                onTranslate: widget.onTranslate,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    if (message.translation.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _TranslationBlock(
                        state: state,
                        text: message.translation,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TranslationBlock extends StatelessWidget {
  const _TranslationBlock({
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

class _MessageActionBar extends StatelessWidget {
  const _MessageActionBar({
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

class _ReasoningPanel extends StatefulWidget {
  const _ReasoningPanel({
    required this.state,
    required this.reasoning,
    required this.thinking,
  });

  final WeaviewState state;
  final String reasoning;
  final bool thinking;

  @override
  State<_ReasoningPanel> createState() => _ReasoningPanelState();
}

class _ReasoningPanelState extends State<_ReasoningPanel> {
  bool expanded = false;
  bool autoExpanded = false;

  @override
  void initState() {
    super.initState();
    expanded = widget.thinking;
    autoExpanded = widget.thinking;
  }

  @override
  void didUpdateWidget(covariant _ReasoningPanel oldWidget) {
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

class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots({required this.state});

  final WeaviewState state;

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 5),
                decoration: BoxDecoration(
                  color: widget.state
                      .text(context)
                      .withValues(
                        alpha:
                            0.25 +
                            0.45 *
                                ((math.sin(controller.value * math.pi * 2 + i) +
                                        1) /
                                    2),
                      ),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        );
      },
    );
  }
}
