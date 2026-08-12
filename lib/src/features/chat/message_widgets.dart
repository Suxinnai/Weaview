// ignore_for_file: use_key_in_widget_constructors

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../app/app_constants.dart';
import '../../app/weaview_state.dart';
import '../../data/ai/ai_response_parsers.dart';
import '../../domain/models.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'markdown_segments.dart';
import 'message_support_widgets.dart';

class MessageBubble extends StatefulWidget {
  const MessageBubble({
    required this.state,
    required this.message,
    required this.index,
    required this.assistantAvatar,
    required this.userAvatar,
    required this.onCopy,
    required this.onRetry,
    required this.onEdit,
    required this.onTranslate,
    required this.onBranch,
    required this.onDelete,
    required this.onSpeak,
    required this.onDownloadAttachment,
    this.onChooseModel,
  });

  final WeaviewState state;
  final ChatMessage message;
  final int index;
  final String assistantAvatar;
  final String userAvatar;
  final VoidCallback onCopy;
  final VoidCallback onRetry;
  final VoidCallback onEdit;
  final VoidCallback onTranslate;
  final VoidCallback onBranch;
  final VoidCallback onDelete;
  final VoidCallback onSpeak;
  final ValueChanged<MessageAttachment> onDownloadAttachment;
  final VoidCallback? onChooseModel;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  final GlobalKey _actionsKey = GlobalKey();
  bool _actionsVisible = false;
  bool _inlineEditing = false;
  TextEditingController? _inlineEditController;
  Offset? _assistantPointerDown;

  void _toggleActions() {
    final nextVisible = !_actionsVisible;
    setState(() => _actionsVisible = nextVisible);
    if (nextVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = _actionsKey.currentContext;
        if (context == null || !mounted) return;
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: 0.72,
          alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        );
      });
    }
  }

  void _startInlineEdit() {
    _inlineEditController?.dispose();
    _inlineEditController = TextEditingController(text: widget.message.content);
    setState(() {
      _actionsVisible = false;
      _inlineEditing = true;
    });
  }

  void _cancelInlineEdit() {
    setState(() => _inlineEditing = false);
  }

  void _saveInlineEdit() {
    final value = _inlineEditController?.text.trim() ?? '';
    if (value.isNotEmpty) {
      widget.state.editMessageAt(widget.index, value);
    }
    setState(() => _inlineEditing = false);
  }

  @override
  void dispose() {
    _inlineEditController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final message = widget.message;
    final isUser = message.role == 'user';
    final hasActionText =
        message.content.trim().isNotEmpty ||
        message.comparisonResults.any((result) => result.hasText);
    final conversationError = _ConversationError.fromMessage(message);
    final showMessageActions = hasActionText && conversationError == null;
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = isUser ? width * 0.82 : width - 58;
    final textAlign = _messageTextAlign(state);
    final assistantGeneratedImages = message.attachments
        .where((attachment) => attachment.isImage)
        .toList();
    final assistantOtherAttachments = message.attachments
        .where((attachment) => !attachment.isImage)
        .toList();
    final showsGeneratedImageGallery =
        !isUser &&
        message.activity == 'imageGeneration' &&
        assistantGeneratedImages.isNotEmpty;
    if (isUser) {
      return Align(
        alignment: _messageShellAlignment(state, isUser: true),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AvatarDot(
              value: widget.userAvatar,
              fallbackIcon: Icons.person_outline_rounded,
              imageSize: 28,
              accent: state.accents[1],
            ),
            const SizedBox(height: 6),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _toggleActions,
              child: Semantics(
                container: true,
                label: '用户消息',
                hint: hasActionText ? '轻触消息可以打开消息操作' : null,
                child: _StyledMessageSurface(
                  state: state,
                  isUser: true,
                  maxWidth: maxWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (message.attachments.isNotEmpty) ...[
                        MessageAttachmentGrid(
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
                          textAlign: textAlign,
                          style: state.personalizedTextStyle(
                            context,
                            size: 14,
                            height: 1.58,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (hasActionText)
              _ActionReveal(
                key: _actionsKey,
                visible: _actionsVisible,
                alignRight: true,
                child: MessageActionBar(
                  state: state,
                  isModel: false,
                  hasText: hasActionText,
                  onCopy: widget.onCopy,
                  onRetry: widget.onRetry,
                  onEdit: widget.onEdit,
                  onTranslate: widget.onTranslate,
                  onBranch: widget.onBranch,
                  onDelete: widget.onDelete,
                  onSpeak: widget.onSpeak,
                ),
              ),
            if (message.translation.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              TranslationBlock(
                state: state,
                text: message.translation,
                alignRight: true,
              ),
            ],
          ],
        ),
      );
    }

    final assistantContent = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) => _assistantPointerDown = event.position,
      onPointerCancel: (_) => _assistantPointerDown = null,
      onPointerUp: (event) {
        final start = _assistantPointerDown;
        _assistantPointerDown = null;
        if (start != null && (event.position - start).distance > 10) return;
        if (!message.isThinking && !_inlineEditing) {
          _toggleActions();
        }
      },
      child: Semantics(
        container: true,
        label: '助手消息',
        hint: showMessageActions ? '轻触消息可以打开消息操作' : null,
        child: Column(
          crossAxisAlignment: _messageColumnAlignment(state),
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 460),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final scale = Tween<double>(
                  begin: 0.98,
                  end: 1,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: scale, child: child),
                );
              },
              child: message.isImageGenerating
                  ? Column(
                      key: ValueKey('image-generating-${widget.index}'),
                      crossAxisAlignment: _messageColumnAlignment(state),
                      children: [
                        ImageGenerationPanel(state: state),
                        const SizedBox(height: 10),
                      ],
                    )
                  : Column(
                      key: ValueKey(
                        'assistant-content-${widget.index}-${message.attachments.length}',
                      ),
                      crossAxisAlignment: _messageColumnAlignment(state),
                      children: [
                        if (message.reasoning.trim().isNotEmpty ||
                            message.isThinking) ...[
                          ReasoningPanel(
                            state: state,
                            reasoning: message.reasoning,
                            thinking: message.isThinking,
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (message.comparisonResults.isNotEmpty)
                          ModelComparisonPanel(
                            state: state,
                            results: message.comparisonResults,
                          )
                        else if (conversationError != null)
                          _AssistantErrorCard(
                            state: state,
                            error: conversationError,
                            onRetry: widget.onRetry,
                            onChooseModel: widget.onChooseModel,
                          )
                        else if (message.attachments.isNotEmpty ||
                            message.content.trim().isNotEmpty ||
                            !message.isThinking)
                          _StyledMessageSurface(
                            state: state,
                            isUser: false,
                            maxWidth: maxWidth,
                            child: Column(
                              crossAxisAlignment: _messageColumnAlignment(
                                state,
                              ),
                              children: [
                                if (showsGeneratedImageGallery) ...[
                                  GeneratedImageGallery(
                                    state: state,
                                    attachments: assistantGeneratedImages,
                                    onDownload: widget.onDownloadAttachment,
                                  ),
                                  if (assistantOtherAttachments.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    MessageAttachmentGrid(
                                      state: state,
                                      attachments: assistantOtherAttachments,
                                      onDownload: widget.onDownloadAttachment,
                                      animateImages: true,
                                    ),
                                  ],
                                  if (message.content.trim().isNotEmpty)
                                    const SizedBox(height: 12),
                                ] else if (message.attachments.isNotEmpty) ...[
                                  MessageAttachmentGrid(
                                    state: state,
                                    attachments: message.attachments,
                                    onDownload: widget.onDownloadAttachment,
                                    imageExtent: 176,
                                    animateImages: true,
                                  ),
                                  if (message.content.trim().isNotEmpty)
                                    const SizedBox(height: 12),
                                ],
                                if (_inlineEditing)
                                  _InlineModelEditor(
                                    state: state,
                                    controller: _inlineEditController!,
                                    onCancel: _cancelInlineEdit,
                                    onSave: _saveInlineEdit,
                                  )
                                else if (message.content.trim().isNotEmpty ||
                                    message.attachments.isEmpty)
                                  _AiMarkdown(
                                    state: state,
                                    data: message.content.isEmpty
                                        ? ' '
                                        : message.content,
                                    textAlign: textAlign,
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            if (showMessageActions)
              _ActionReveal(
                key: _actionsKey,
                visible: _actionsVisible && showMessageActions,
                child: MessageActionBar(
                state: state,
                isModel: true,
                hasText: hasActionText,
                onCopy: widget.onCopy,
                onRetry: widget.onRetry,
                onEdit: _startInlineEdit,
                onTranslate: widget.onTranslate,
                onBranch: widget.onBranch,
                onDelete: widget.onDelete,
                onSpeak: widget.onSpeak,
              ),
            ),
            if (message.translation.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              TranslationBlock(state: state, text: message.translation),
            ],
          ],
        ),
      ),
    );
    return Align(
      alignment: _messageShellAlignment(state, isUser: false),
      child: Column(
        crossAxisAlignment: _messageColumnAlignment(state),
        children: [
          AvatarDot(
            value: widget.assistantAvatar,
            fallbackIcon: Icons.auto_awesome_rounded,
            imageSize: 28,
            accent: state.accents[0],
          ),
          const SizedBox(height: 8),
          assistantContent,
        ],
      ),
    );
  }
}

class _AssistantErrorCard extends StatefulWidget {
  const _AssistantErrorCard({
    required this.state,
    required this.error,
    required this.onRetry,
    this.onChooseModel,
  });

  final WeaviewState state;
  final _ConversationError error;
  final VoidCallback onRetry;
  final VoidCallback? onChooseModel;

  @override
  State<_AssistantErrorCard> createState() => _AssistantErrorCardState();
}

class _AssistantErrorCardState extends State<_AssistantErrorCard> {
  bool _detailsVisible = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final text = state.text(context);
    final dark = state.isDark(context);
    final accent = state.accents[0];
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 58,
      ),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      decoration: BoxDecoration(
        color: state.layer(context).withValues(alpha: dark ? 0.50 : 0.68),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: text.withValues(alpha: 0.075)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.12 : 0.045),
            blurRadius: 18,
            spreadRadius: -8,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: dark ? 0.16 : 0.11),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(widget.error.icon, size: 19, color: accent),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.error.title,
                      style: state.textStyle(
                        context,
                        size: 14.5,
                        weight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.error.summary,
                      style: state.textStyle(
                        context,
                        size: 13,
                        height: 1.5,
                        opacity: 0.66,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (widget.onChooseModel != null)
                OutlinedButton.icon(
                  onPressed: widget.onChooseModel,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 17),
                  label: const Text('切换模型'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: text.withValues(alpha: 0.82),
                    side: BorderSide(color: text.withValues(alpha: 0.10)),
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                ),
              FilledButton.icon(
                onPressed: widget.onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('重试'),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
              TextButton.icon(
                onPressed: () =>
                    setState(() => _detailsVisible = !_detailsVisible),
                icon: Icon(
                  _detailsVisible
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                ),
                label: Text(_detailsVisible ? '收起详情' : '技术详情'),
                style: TextButton.styleFrom(
                  foregroundColor: text.withValues(alpha: 0.52),
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: _detailsVisible
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: text.withValues(alpha: dark ? 0.055 : 0.035),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: SelectableText(
                        widget.error.raw,
                        style: state.textStyle(
                          context,
                          size: 11,
                          height: 1.45,
                          opacity: 0.54,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _ConversationError {
  const _ConversationError({
    required this.title,
    required this.summary,
    required this.raw,
    required this.icon,
  });

  final String title;
  final String summary;
  final String raw;
  final IconData icon;

  static _ConversationError? fromMessage(ChatMessage message) {
    final raw = message.content.trim();
    final isError =
        message.activity == 'requestError' ||
        raw.startsWith('连接织线时出现了问题：') ||
        raw.startsWith('生图失败：');
    if (!isError || raw.isEmpty) return null;

    final lower = raw.toLowerCase();
    final model = RegExp(
      r'''model\s+['"]([^'"]+)['"]''',
      caseSensitive: false,
    ).firstMatch(raw)?.group(1);
    if (lower.contains('http 410') ||
        lower.contains('end of life') ||
        lower.contains('no longer available')) {
      return _ConversationError(
        title: '模型已停止服务',
        summary: model == null
            ? '当前模型已被提供商下线，请切换到可用模型后重试。'
            : '“$model” 已被提供商下线，请切换到可用模型后重试。',
        raw: raw,
        icon: Icons.swap_horiz_rounded,
      );
    }
    if (lower.contains('http 401') || lower.contains('http 403')) {
      return _ConversationError(
        title: '身份验证失败',
        summary: 'API Key 无效、已过期或没有访问当前模型的权限。',
        raw: raw,
        icon: Icons.key_off_outlined,
      );
    }
    if (lower.contains('http 429') || lower.contains('rate limit')) {
      return _ConversationError(
        title: '请求过于频繁',
        summary: '提供商暂时限制了请求，请稍后重试或切换模型。',
        raw: raw,
        icon: Icons.hourglass_top_rounded,
      );
    }
    if (lower.contains('timeout') || raw.contains('请求超时')) {
      return _ConversationError(
        title: '请求超时',
        summary: '模型在限定时间内没有响应，请检查网络后重试。',
        raw: raw,
        icon: Icons.schedule_rounded,
      );
    }
    return _ConversationError(
      title: raw.startsWith('生图失败：') ? '图片生成失败' : '请求失败',
      summary: '请检查网络、API Key 和模型配置，或切换模型后重试。',
      raw: raw,
      icon: Icons.error_outline_rounded,
    );
  }
}

class ModelComparisonPanel extends StatefulWidget {
  const ModelComparisonPanel({
    super.key,
    required this.state,
    required this.results,
  });

  final WeaviewState state;
  final List<ModelComparisonResult> results;

  @override
  State<ModelComparisonPanel> createState() => _ModelComparisonPanelState();
}

class _ModelComparisonPanelState extends State<ModelComparisonPanel> {
  int _currentPage = 0;
  double _dragDx = 0;
  double _dragDy = 0;

  WeaviewState get state => widget.state;
  List<ModelComparisonResult> get results => widget.results;

  @override
  void didUpdateWidget(covariant ModelComparisonPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_currentPage >= results.length && results.isNotEmpty) {
      _currentPage = results.length - 1;
    }
  }

  void _goToPage(int page) {
    if (page < 0 || page >= results.length) return;
    setState(() => _currentPage = page);
  }

  void _handleCardPointerDown(PointerDownEvent event) {
    _dragDx = 0;
    _dragDy = 0;
  }

  void _handleCardPointerMove(PointerMoveEvent event) {
    _dragDx += event.delta.dx;
    _dragDy += event.delta.dy;
  }

  void _handleCardPointerUp(PointerUpEvent event) {
    final dragDx = _dragDx;
    final dragDy = _dragDy;
    _dragDx = 0;
    _dragDy = 0;
    if (dragDx.abs() < 48 || dragDx.abs() < dragDy.abs() * 1.2) return;
    if (dragDx < 0) {
      _goToPage(_currentPage + 1);
    } else {
      _goToPage(_currentPage - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final maxBodyHeight = math
        .min(420.0, math.max(180.0, screenHeight * 0.42))
        .toDouble();
    final panelMaxWidth = math.max(0.0, width - 58);
    final completed = results.where((item) => !item.loading).length;
    final failed = results.where((item) => item.error.trim().isNotEmpty).length;
    final running = results.any((item) => item.loading);
    final statusLabel = running
        ? '生成中 · $completed/${results.length}'
        : failed > 0
        ? '完成 · $failed 个异常'
        : '已完成';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: panelMaxWidth),
        decoration: BoxDecoration(
          color: state
              .layer(context)
              .withValues(alpha: state.isDark(context) ? 0.76 : 0.92),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: state.text(context).withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: state.accents[0].withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.view_carousel_rounded,
                      size: 16,
                      color: state.accents[0],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '多模型对照',
                          style: state.textStyle(
                            context,
                            size: 14,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          statusLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: state.textStyle(
                            context,
                            size: 11.2,
                            opacity: 0.46,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    key: const Key('comparison-page-label'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: state.text(context).withValues(alpha: 0.055),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_currentPage + 1} / ${results.length}',
                      style: state.textStyle(
                        context,
                        size: 11.5,
                        weight: FontWeight.w700,
                        opacity: 0.56,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              label:
                  '左右滑动主卡切换模型。当前第 ${_currentPage + 1} 个模型，共 ${results.length} 个模型',
              child: Listener(
                key: const Key('comparison-card-swipe-zone'),
                behavior: HitTestBehavior.translucent,
                onPointerDown: _handleCardPointerDown,
                onPointerMove: _handleCardPointerMove,
                onPointerUp: _handleCardPointerUp,
                child: AnimatedSwitcher(
                  key: const Key('comparison-page-view'),
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.985, end: 1).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: Padding(
                    key: ValueKey(results[_currentPage].id),
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                    child: _ComparisonResultCard(
                      state: state,
                      result: results[_currentPage],
                      index: _currentPage,
                      maxBodyHeight: maxBodyHeight,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _ComparisonResultCard extends StatelessWidget {
  const _ComparisonResultCard({
    required this.state,
    required this.result,
    required this.index,
    required this.maxBodyHeight,
  });

  final WeaviewState state;
  final ModelComparisonResult result;
  final int index;
  final double maxBodyHeight;

  @override
  Widget build(BuildContext context) {
    final error = result.error.trim();
    final storedContent = result.content.trim();
    final storedReasoning = result.reasoning.trim();
    final visibleSplit = splitReasoning(storedContent);
    final content = visibleSplit.answer.trim();
    final reasoning = storedReasoning.isNotEmpty
        ? storedReasoning
        : visibleSplit.reasoning.trim();
    final dark = state.isDark(context);
    return Container(
      key: Key('comparison-result-card-$index'),
      decoration: BoxDecoration(
        color: state.background(context).withValues(alpha: dark ? 0.48 : 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: state.text(context).withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.18 : 0.055),
            blurRadius: 22,
            spreadRadius: -10,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: state.accents[index % 2].withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 15,
                    color: state.accents[index % 2],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.provider,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: state.textStyle(
                          context,
                          size: 13.5,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        result.model,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: state.textStyle(
                          context,
                          size: 11.5,
                          opacity: 0.46,
                        ),
                      ),
                    ],
                  ),
                ),
                _ComparisonStatusBadge(state: state, result: result),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: state.text(context).withValues(alpha: 0.06),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxBodyHeight),
            child: SingleChildScrollView(
              key: Key('comparison-result-scroll-$index'),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (reasoning.isNotEmpty) ...[
                    ReasoningPanel(
                      state: state,
                      reasoning: reasoning,
                      thinking: false,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (content.isNotEmpty)
                    _AiMarkdown(
                      state: state,
                      data: content,
                      textAlign: TextAlign.left,
                    )
                  else if (error.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        error,
                        style: state
                            .textStyle(context, size: 13.2, height: 1.5)
                            .copyWith(color: Colors.red),
                      ),
                    )
                  else
                    Text(
                      result.loading ? '正在等待模型返回…' : '暂无结果',
                      style: state.textStyle(
                        context,
                        size: 13.2,
                        opacity: 0.46,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonStatusBadge extends StatelessWidget {
  const _ComparisonStatusBadge({required this.state, required this.result});

  final WeaviewState state;
  final ModelComparisonResult result;

  @override
  Widget build(BuildContext context) {
    final failed = result.error.trim().isNotEmpty;
    final color = result.loading
        ? state.accents[0]
        : failed
        ? Colors.red
        : sendGreen;
    final label = result.loading
        ? '生成中'
        : failed
        ? '异常'
        : '${result.elapsedMs}ms';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (result.loading)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.8, color: color),
            )
          else
            Icon(
              failed
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              size: 13,
              color: color,
            ),
          const SizedBox(width: 5),
          Text(
            label,
            style: state
                .textStyle(context, size: 10.8, weight: FontWeight.w700)
                .copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _ActionReveal extends StatelessWidget {
  const _ActionReveal({
    super.key,
    required this.visible,
    required this.child,
    this.alignRight = false,
  });

  final bool visible;
  final Widget child;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: visible
          ? Align(
              alignment: alignRight
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: child,
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

Alignment _messageShellAlignment(WeaviewState state, {required bool isUser}) {
  return switch (state.messageAlignment) {
    'center' => Alignment.center,
    'right' => Alignment.centerRight,
    _ => isUser ? Alignment.centerRight : Alignment.centerLeft,
  };
}

CrossAxisAlignment _messageColumnAlignment(
  WeaviewState state, {
  CrossAxisAlignment fallback = CrossAxisAlignment.start,
}) {
  return switch (state.messageAlignment) {
    'center' => CrossAxisAlignment.center,
    'right' => CrossAxisAlignment.end,
    'left' => CrossAxisAlignment.start,
    _ => fallback,
  };
}

TextAlign _messageTextAlign(WeaviewState state) {
  return switch (state.messageAlignment) {
    'center' => TextAlign.center,
    'right' => TextAlign.right,
    _ => TextAlign.left,
  };
}

WrapAlignment _markdownWrapAlignment(TextAlign align) {
  return switch (align) {
    TextAlign.center => WrapAlignment.center,
    TextAlign.right || TextAlign.end => WrapAlignment.end,
    _ => WrapAlignment.start,
  };
}

EdgeInsets _messageBubblePadding(WeaviewState state) {
  return state.bubbleStyle == 'none'
      ? const EdgeInsets.symmetric(horizontal: 2, vertical: 2)
      : const EdgeInsets.symmetric(horizontal: 18, vertical: 12);
}

BorderRadius _messageBubbleRadius(bool isUser) {
  return isUser
      ? const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(8),
          bottomLeft: Radius.circular(25),
          bottomRight: Radius.circular(25),
        )
      : const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(22),
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
        );
}

BoxDecoration? _messageBubbleDecoration(
  BuildContext context,
  WeaviewState state, {
  required bool isUser,
}) {
  final style = state.bubbleStyle;
  if (style == 'none') return null;
  final dark = state.isDark(context);
  final fallbackColor = isUser
      ? (dark ? Colors.white : accentMint)
      : state.accents[0];
  final configuredColor = isUser
      ? state.userBubbleOverride
      : state.assistantBubbleOverride;
  final color = configuredColor ?? fallbackColor;
  final opacity =
      (isUser ? state.userBubbleOpacity : state.assistantBubbleOpacity)
          .clamp(0.0, 1.0)
          .toDouble();
  final radius = _messageBubbleRadius(isUser);
  final borderColor = color.withValues(
    alpha: style == 'outline' ? 0.55 : (dark ? 0.16 : 0.22),
  );

  if (style == 'minimal' && !isUser && configuredColor == null) return null;
  if (style == 'outline') {
    return BoxDecoration(
      color: color.withValues(alpha: 0.02),
      borderRadius: radius,
      border: Border.all(color: borderColor),
    );
  }

  final fillOpacity = switch (style) {
    'solid' => math.max(opacity, 0.58),
    'glass' => math.max(opacity, 0.10),
    _ => opacity,
  };
  return BoxDecoration(
    color: color.withValues(alpha: fillOpacity),
    borderRadius: radius,
    border: Border.all(color: borderColor),
    boxShadow: style == 'solid'
        ? null
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.10 : 0.04),
              blurRadius: style == 'glass' ? 22 : 18,
              offset: const Offset(0, 8),
            ),
          ],
  );
}

class _StyledMessageSurface extends StatelessWidget {
  const _StyledMessageSurface({
    required this.state,
    required this.isUser,
    required this.maxWidth,
    required this.child,
  });

  final WeaviewState state;
  final bool isUser;
  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final decoration = _messageBubbleDecoration(context, state, isUser: isUser);
    final content = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: _messageBubblePadding(state),
      decoration: decoration,
      child: child,
    );
    if (state.bubbleStyle == 'glass' && decoration != null) {
      return ClipRRect(
        borderRadius: _messageBubbleRadius(isUser),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: content,
        ),
      );
    }
    return content;
  }
}

class _InlineModelEditor extends StatelessWidget {
  const _InlineModelEditor({
    required this.state,
    required this.controller,
    required this.onCancel,
    required this.onSave,
  });

  final WeaviewState state;
  final TextEditingController controller;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final text = state.text(context);
    final dark = state.isDark(context);
    final borderColor = text.withValues(alpha: dark ? 0.14 : 0.10);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: borderColor),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          autofocus: true,
          minLines: 4,
          maxLines: 14,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          style: state.personalizedTextStyle(context, size: 14.5, height: 1.55),
          decoration: InputDecoration(
            hintText: '编辑 AI 回复内容',
            hintStyle: state.personalizedTextStyle(
              context,
              size: 14.5,
              opacity: 0.42,
            ),
            filled: true,
            fillColor: text.withValues(alpha: dark ? 0.08 : 0.035),
            contentPadding: const EdgeInsets.all(13),
            border: inputBorder,
            enabledBorder: inputBorder,
            focusedBorder: inputBorder.copyWith(
              borderSide: BorderSide(
                color: state.accents[0].withValues(alpha: 0.55),
                width: 1.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: onCancel, child: const Text('取消')),
            const SizedBox(width: 8),
            FilledButton(onPressed: onSave, child: const Text('保存')),
          ],
        ),
      ],
    );
  }
}

class _AiMarkdown extends StatelessWidget {
  const _AiMarkdown({
    required this.state,
    required this.data,
    required this.textAlign,
  });

  final WeaviewState state;
  final String data;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final segments = splitMarkdownSegments(data);
    return Column(
      crossAxisAlignment: _messageColumnAlignment(state),
      children: [
        for (var i = 0; i < segments.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          switch (segments[i].kind) {
            MarkdownSegmentKind.markdown => _RichMarkdownBlocks(
              state: state,
              data: _displayMarkdownText(segments[i].text),
              textAlign: textAlign,
            ),
            MarkdownSegmentKind.code => _CodeBlock(
              state: state,
              language: segments[i].language,
              code: segments[i].text,
            ),
            MarkdownSegmentKind.formula => _FormulaBlock(
              state: state,
              formula: segments[i].text,
            ),
          },
        ],
      ],
    );
  }
}

String _displayMarkdownText(String source) {
  if (source.trim().isEmpty) return source;
  final normalized = source.replaceAll('\r\n', '\n');
  return normalized
      .split('\n')
      .map((line) {
        final trimmedLeft = line.trimLeft();
        final leading = line.length - trimmedLeft.length;
        if (trimmedLeft.startsWith('# ')) {
          return '${line.substring(0, leading)}## ${trimmedLeft.substring(2).trimLeft()}';
        }
        return line.trimRight();
      })
      .join('\n')
      .replaceAll(RegExp(r'\n{4,}'), '\n\n\n')
      .trimRight();
}

bool _isMarkdownControlLine(String line) {
  return line.startsWith('#') ||
      line.startsWith('>') ||
      line.startsWith('|') ||
      line.startsWith('- ') ||
      line.startsWith('* ') ||
      line.startsWith('+ ') ||
      RegExp(r'^\d+[.)、]\s').hasMatch(line) ||
      RegExp(r'^[-*_]{3,}$').hasMatch(line);
}

class _RichMarkdownBlocks extends StatelessWidget {
  const _RichMarkdownBlocks({
    required this.state,
    required this.data,
    required this.textAlign,
  });

  final WeaviewState state;
  final String data;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final blocks = _splitRichMarkdownBlocks(data);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          switch (blocks[i].kind) {
            _RichMarkdownBlockKind.prose => _ProseParagraph(
              state: state,
              data: blocks[i].text,
              textAlign: textAlign,
            ),
            _RichMarkdownBlockKind.table => _MarkdownTableBlock(
              state: state,
              table: blocks[i].text,
            ),
            _RichMarkdownBlockKind.markdown => MarkdownBody(
              data: blocks[i].text,
              selectable: true,
              styleSheet: _aiMarkdownStyle(context, state, textAlign),
            ),
          },
        ],
      ],
    );
  }
}

enum _RichMarkdownBlockKind { prose, markdown, table }

class _RichMarkdownBlock {
  const _RichMarkdownBlock(this.kind, this.text);

  final _RichMarkdownBlockKind kind;
  final String text;
}

List<_RichMarkdownBlock> _splitRichMarkdownBlocks(String source) {
  final lines = source.split('\n');
  final blocks = <_RichMarkdownBlock>[];
  final buffer = <String>[];
  _RichMarkdownBlockKind? bufferKind;

  void flush() {
    final text = buffer.join('\n').trimRight();
    if (bufferKind != null && text.trim().isNotEmpty) {
      blocks.add(_RichMarkdownBlock(bufferKind!, text));
    }
    buffer.clear();
    bufferKind = null;
  }

  void addLine(_RichMarkdownBlockKind kind, String line) {
    if (bufferKind != null && bufferKind != kind) flush();
    bufferKind = kind;
    buffer.add(line);
  }

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      flush();
      continue;
    }
    if (_isMarkdownTableStart(lines, i)) {
      flush();
      final tableLines = <String>[line, lines[i + 1]];
      i += 2;
      while (i < lines.length && lines[i].contains('|')) {
        tableLines.add(lines[i]);
        i++;
      }
      i--;
      blocks.add(
        _RichMarkdownBlock(
          _RichMarkdownBlockKind.table,
          tableLines.join('\n').trimRight(),
        ),
      );
      continue;
    }
    addLine(
      _isPlainProseLine(trimmed)
          ? _RichMarkdownBlockKind.prose
          : _RichMarkdownBlockKind.markdown,
      line,
    );
  }
  flush();
  return blocks;
}

bool _isPlainProseLine(String line) {
  if (_isMarkdownControlLine(line)) return false;
  if (RegExp(r'!?\[[^\]]+\]\([^)]+\)').hasMatch(line)) return false;
  if (line.startsWith('<') || line.endsWith('>')) return false;
  return true;
}

bool _isMarkdownTableStart(List<String> lines, int index) {
  if (index + 1 >= lines.length) return false;
  final header = lines[index].trim();
  final divider = lines[index + 1].trim();
  return header.contains('|') &&
      RegExp(r'^\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?$').hasMatch(divider);
}

class _ProseParagraph extends StatelessWidget {
  const _ProseParagraph({
    required this.state,
    required this.data,
    required this.textAlign,
  });

  final WeaviewState state;
  final String data;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final base = _markdownType(context, state, 14.2, height: 1.66);
    final strong = _markdownType(
      context,
      state,
      14.2,
      height: 1.66,
      weight: FontWeight.w600,
    );
    final emphasis = base.copyWith(fontStyle: FontStyle.italic);
    final code =
        _markdownType(
          context,
          state,
          13.2,
          height: 1.52,
          weight: FontWeight.w500,
        ).copyWith(
          fontFamily: 'monospace',
          backgroundColor: state.text(context).withValues(alpha: 0.075),
        );
    return SelectableText.rich(
      TextSpan(
        style: base,
        children: _inlineMarkdownSpans(data, base, strong, emphasis, code),
      ),
      textAlign: _proseTextAlign(textAlign, data),
    );
  }
}

List<InlineSpan> _inlineMarkdownSpans(
  String source,
  TextStyle base,
  TextStyle strong,
  TextStyle emphasis,
  TextStyle code,
) {
  final spans = <InlineSpan>[];
  var index = 0;

  void addPlain(int end) {
    if (end > index) {
      spans.add(TextSpan(text: source.substring(index, end), style: base));
    }
  }

  while (index < source.length) {
    final codeStart = source.indexOf('`', index);
    final strongStart = source.indexOf('**', index);
    final emphasisStart = _nextSingleStar(source, index);
    final starts = <int>[
      codeStart,
      strongStart,
      emphasisStart,
    ].where((value) => value >= 0).toList()..sort();
    if (starts.isEmpty) {
      addPlain(source.length);
      break;
    }
    final start = starts.first;
    addPlain(start);
    if (start == codeStart) {
      final end = source.indexOf('`', start + 1);
      if (end <= start) {
        spans.add(TextSpan(text: source.substring(start), style: base));
        break;
      }
      spans.add(TextSpan(text: source.substring(start + 1, end), style: code));
      index = end + 1;
      continue;
    }
    if (start == strongStart) {
      final end = source.indexOf('**', start + 2);
      if (end <= start) {
        spans.add(TextSpan(text: source.substring(start), style: base));
        break;
      }
      spans.add(
        TextSpan(text: source.substring(start + 2, end), style: strong),
      );
      index = end + 2;
      continue;
    }
    final end = source.indexOf('*', start + 1);
    if (end <= start) {
      spans.add(TextSpan(text: source.substring(start), style: base));
      break;
    }
    spans.add(
      TextSpan(text: source.substring(start + 1, end), style: emphasis),
    );
    index = end + 1;
  }

  return spans;
}

int _nextSingleStar(String source, int start) {
  var index = source.indexOf('*', start);
  while (index >= 0) {
    final previousIsStar = index > 0 && source[index - 1] == '*';
    final nextIsStar = index + 1 < source.length && source[index + 1] == '*';
    if (!previousIsStar && !nextIsStar) return index;
    index = source.indexOf('*', index + 1);
  }
  return -1;
}

TextAlign _proseTextAlign(TextAlign requested, String text) {
  if (requested == TextAlign.center ||
      requested == TextAlign.right ||
      requested == TextAlign.end) {
    return requested;
  }
  return _shouldJustifyParagraph(text) ? TextAlign.justify : TextAlign.left;
}

bool _shouldJustifyParagraph(String text) {
  final plain = text
      .replaceAll(RegExp(r'[`*_#>\-\s]'), '')
      .replaceAll(RegExp(r'https?://\S+'), '');
  if (plain.runes.length < 28) return false;
  final latin = RegExp(r'[A-Za-z0-9/:._-]').allMatches(plain).length;
  return latin / math.max(plain.runes.length, 1) < 0.35;
}

class _MarkdownTableBlock extends StatelessWidget {
  const _MarkdownTableBlock({required this.state, required this.table});

  final WeaviewState state;
  final String table;

  @override
  Widget build(BuildContext context) {
    final rows = _parseMarkdownTable(table);
    if (rows.isEmpty) {
      return MarkdownBody(
        data: table,
        selectable: true,
        styleSheet: _aiMarkdownStyle(context, state, TextAlign.left),
      );
    }
    final text = state.text(context);
    final dark = state.isDark(context);
    final columns = rows.fold<int>(0, (max, row) => math.max(max, row.length));
    final headStyle = _markdownType(
      context,
      state,
      13.2,
      height: 1.42,
      weight: FontWeight.w600,
    );
    final bodyStyle = _markdownType(context, state, 13, height: 1.5);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 9, 12),
      decoration: BoxDecoration(
        color: text.withValues(alpha: dark ? 0.085 : 0.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: text.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.table_chart_rounded,
                size: 16,
                color: text.withValues(alpha: 0.56),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '表格',
                  style: _markdownType(
                    context,
                    state,
                    11.6,
                    weight: FontWeight.w700,
                    opacity: 0.58,
                  ).copyWith(letterSpacing: 1.1),
                ),
              ),
              _CopyMiniButton(
                state: state,
                tooltip: '复制表格',
                onTap: () => _copyText(context, table, '已复制表格。'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final minWidth = math.max(constraints.maxWidth, columns * 126.0);
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: minWidth,
                  child: Table(
                    border: TableBorder.all(
                      color: text.withValues(alpha: dark ? 0.15 : 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      for (var rowIndex = 0; rowIndex < rows.length; rowIndex++)
                        TableRow(
                          decoration: BoxDecoration(
                            color: rowIndex == 0
                                ? state.accents[0].withValues(
                                    alpha: dark ? 0.16 : 0.20,
                                  )
                                : text.withValues(
                                    alpha: rowIndex.isEven ? 0.025 : 0.0,
                                  ),
                          ),
                          children: [
                            for (var column = 0; column < columns; column++)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 9,
                                ),
                                child: SelectableText(
                                  column < rows[rowIndex].length
                                      ? rows[rowIndex][column]
                                      : '',
                                  style: rowIndex == 0 ? headStyle : bodyStyle,
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

List<List<String>> _parseMarkdownTable(String table) {
  final lines = table
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  if (lines.length < 2) return const [];
  final rows = <List<String>>[];
  for (var i = 0; i < lines.length; i++) {
    if (i == 1 &&
        RegExp(
          r'^\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?$',
        ).hasMatch(lines[i])) {
      continue;
    }
    rows.add(_splitMarkdownTableRow(lines[i]));
  }
  return rows.where((row) => row.any((cell) => cell.isNotEmpty)).toList();
}

List<String> _splitMarkdownTableRow(String line) {
  var cleaned = line.trim();
  if (cleaned.startsWith('|')) cleaned = cleaned.substring(1);
  if (cleaned.endsWith('|')) cleaned = cleaned.substring(0, cleaned.length - 1);
  return cleaned
      .split('|')
      .map((cell) => cell.trim().replaceAll(r'\|', '|'))
      .toList();
}

MarkdownStyleSheet _aiMarkdownStyle(
  BuildContext context,
  WeaviewState state,
  TextAlign textAlign,
) {
  final text = state.text(context);
  final dark = state.isDark(context);
  final tableBorder = text.withValues(alpha: dark ? 0.16 : 0.10);
  final wrapAlign = _markdownWrapAlignment(textAlign);
  TextStyle type(
    double size, {
    FontWeight weight = FontWeight.w400,
    double height = 1.6,
    double opacity = 1,
  }) {
    return _markdownType(
      context,
      state,
      size,
      height: height,
      opacity: opacity,
      weight: weight,
    );
  }

  return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
    a: type(
      14,
      height: 1.64,
      weight: FontWeight.w500,
    ).copyWith(color: sendGreen),
    p: type(14, height: 1.64),
    pPadding: const EdgeInsets.only(bottom: 4),
    h1: type(15.8, height: 1.4, weight: FontWeight.w500),
    h1Padding: const EdgeInsets.only(top: 8, bottom: 4),
    h2: type(15.2, height: 1.44, weight: FontWeight.w500),
    h2Padding: const EdgeInsets.only(top: 7, bottom: 3),
    h3: type(14.6, height: 1.48, weight: FontWeight.w500),
    h3Padding: const EdgeInsets.only(top: 6, bottom: 3),
    h4: type(14.2, height: 1.52, weight: FontWeight.w500),
    h4Padding: const EdgeInsets.only(top: 5, bottom: 2),
    h5: type(13.8, height: 1.54, weight: FontWeight.w500),
    h6: type(13.4, height: 1.54, weight: FontWeight.w500, opacity: 0.72),
    strong: type(14, height: 1.64, weight: FontWeight.w500),
    em: type(14, height: 1.64).copyWith(fontStyle: FontStyle.italic),
    blockSpacing: 7,
    textAlign: wrapAlign,
    h1Align: wrapAlign,
    h2Align: wrapAlign,
    h3Align: wrapAlign,
    h4Align: wrapAlign,
    h5Align: wrapAlign,
    h6Align: wrapAlign,
    blockquoteAlign: wrapAlign,
    unorderedListAlign: wrapAlign,
    orderedListAlign: wrapAlign,
    codeblockAlign: wrapAlign,
    listIndent: 18,
    listBullet: type(13.8, height: 1.58),
    listBulletPadding: const EdgeInsets.only(right: 6),
    code: type(13, height: 1.45).copyWith(
      backgroundColor: state.text(context).withValues(alpha: 0.075),
      fontFamily: 'monospace',
      fontStyle: FontStyle.normal,
      color: text.withValues(alpha: 0.88),
    ),
    codeblockPadding: const EdgeInsets.all(12),
    codeblockDecoration: BoxDecoration(
      color: text.withValues(alpha: dark ? 0.10 : 0.055),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: text.withValues(alpha: 0.08)),
    ),
    blockquote: type(13.6, height: 1.6, opacity: 0.8),
    blockquotePadding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
    blockquoteDecoration: BoxDecoration(
      color: state.accents[0].withValues(alpha: dark ? 0.10 : 0.16),
      borderRadius: BorderRadius.circular(14),
      border: Border(
        left: BorderSide(
          color: state.accents[0].withValues(alpha: 0.9),
          width: 4,
        ),
      ),
    ),
    tableColumnWidth: const IntrinsicColumnWidth(),
    tableHead: type(12.8, weight: FontWeight.w500, height: 1.42),
    tableBody: type(12.8, height: 1.48),
    tableHeadAlign: textAlign,
    tablePadding: const EdgeInsets.symmetric(vertical: 6),
    tableBorder: TableBorder.all(
      color: tableBorder,
      borderRadius: BorderRadius.circular(12),
    ),
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    tableHeadCellsPadding: const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 10,
    ),
    tableCellsDecoration: BoxDecoration(
      color: text.withValues(alpha: dark ? 0.045 : 0.028),
    ),
    tableHeadCellsDecoration: BoxDecoration(
      color: state.accents[0].withValues(alpha: dark ? 0.16 : 0.22),
    ),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(
        top: BorderSide(color: text.withValues(alpha: 0.10), width: 1),
      ),
    ),
  );
}

TextStyle _markdownType(
  BuildContext context,
  WeaviewState state,
  double size, {
  FontWeight weight = FontWeight.w400,
  double height = 1.6,
  double opacity = 1,
}) {
  return TextStyle(
    color: state.text(context).withValues(alpha: opacity),
    fontSize: size,
    fontWeight: weight,
    fontStyle: FontStyle.normal,
    height: height,
    fontFamily: state.fontMood == 'serif' ? 'Noto Serif SC' : 'Inter',
    fontFamilyFallback: const [
      'PingFang SC',
      'Microsoft YaHei',
      'Noto Sans CJK SC',
      'Songti SC',
      'serif',
    ],
  );
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({
    required this.state,
    required this.language,
    required this.code,
  });

  final WeaviewState state;
  final String language;
  final String code;

  @override
  Widget build(BuildContext context) {
    final dark = state.isDark(context);
    final text = state.text(context);
    final label = language.trim().isEmpty
        ? 'TEXT'
        : language.trim().toUpperCase();
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: text.withValues(alpha: dark ? 0.09 : 0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: text.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: BoxDecoration(
              color: text.withValues(alpha: dark ? 0.08 : 0.045),
              border: Border(
                bottom: BorderSide(color: text.withValues(alpha: 0.07)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.code_rounded,
                  size: 15,
                  color: text.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: state
                        .textStyle(
                          context,
                          size: 11.5,
                          weight: FontWeight.w800,
                          opacity: 0.58,
                        )
                        .copyWith(letterSpacing: 1.1),
                  ),
                ),
                _CopyMiniButton(
                  state: state,
                  tooltip: '复制代码',
                  onTap: () => _copyText(context, code, '已复制代码。'),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(13),
            child: SelectableText(
              code.isEmpty ? ' ' : code,
              style: state
                  .textStyle(context, size: 13.2, height: 1.55)
                  .copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.normal,
                    color: text.withValues(alpha: 0.88),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormulaBlock extends StatelessWidget {
  const _FormulaBlock({required this.state, required this.formula});

  final WeaviewState state;
  final String formula;

  @override
  Widget build(BuildContext context) {
    final text = state.text(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 11, 9, 13),
      decoration: BoxDecoration(
        color: state.accents[1].withValues(
          alpha: state.isDark(context) ? 0.11 : 0.20,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: state.accents[0].withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.functions_rounded,
                size: 16,
                color: text.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '公式',
                  style: state
                      .textStyle(
                        context,
                        size: 11.5,
                        weight: FontWeight.w800,
                        opacity: 0.56,
                      )
                      .copyWith(letterSpacing: 1.2),
                ),
              ),
              _CopyMiniButton(
                state: state,
                tooltip: '复制公式',
                onTap: () => _copyText(context, formula, '已复制公式。'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(
              formula,
              style: state
                  .textStyle(context, size: 14.2, height: 1.55)
                  .copyWith(
                    fontFamily: 'monospace',
                    fontStyle: FontStyle.normal,
                    fontWeight: FontWeight.w400,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyMiniButton extends StatelessWidget {
  const _CopyMiniButton({
    required this.state,
    required this.tooltip,
    required this.onTap,
  });

  final WeaviewState state;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: state.text(context).withValues(alpha: 0.065),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              Icons.content_copy_rounded,
              size: 15.5,
              color: state.text(context).withValues(alpha: 0.58),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _copyText(
  BuildContext context,
  String text,
  String message,
) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}
