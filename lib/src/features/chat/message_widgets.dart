// ignore_for_file: use_key_in_widget_constructors

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../app/app_constants.dart';
import '../../app/weaview_state.dart';
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

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  final GlobalKey _actionsKey = GlobalKey();
  bool _actionsVisible = false;
  bool _inlineEditing = false;
  TextEditingController? _inlineEditController;

  void _toggleActions() {
    final nextVisible = !_actionsVisible;
    setState(() => _actionsVisible = nextVisible);
    if (nextVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = _actionsKey.currentContext;
        if (context == null || !mounted) return;
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
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
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = isUser ? width * 0.82 : width - 58;
    final textAlign = _messageTextAlign(state);
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
            _ActionReveal(
              key: _actionsKey,
              visible: _actionsVisible,
              alignRight: true,
              child: MessageActionBar(
                state: state,
                isModel: false,
                hasText: message.content.trim().isNotEmpty,
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

    return Align(
      alignment: _messageShellAlignment(state, isUser: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvatarDot(
            value: widget.assistantAvatar,
            fallbackIcon: Icons.auto_awesome_rounded,
            imageSize: 28,
            accent: state.accents[0],
          ),
          const SizedBox(height: 8),
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerUp: (_) {
              if (!message.isThinking && !_inlineEditing) _toggleActions();
            },
            child: Column(
              crossAxisAlignment: _messageColumnAlignment(state),
              children: [
                if (message.isImageGenerating) ...[
                  ImageGenerationPanel(state: state),
                  const SizedBox(height: 10),
                ] else if (message.reasoning.trim().isNotEmpty ||
                    message.isThinking) ...[
                  ReasoningPanel(
                    state: state,
                    reasoning: message.reasoning,
                    thinking: message.isThinking,
                  ),
                  const SizedBox(height: 10),
                ],
                if (message.attachments.isNotEmpty ||
                    message.content.trim().isNotEmpty ||
                    !message.isThinking)
                  _StyledMessageSurface(
                    state: state,
                    isUser: false,
                    maxWidth: maxWidth,
                    child: Column(
                      crossAxisAlignment: _messageColumnAlignment(state),
                      children: [
                        if (message.attachments.isNotEmpty) ...[
                          MessageAttachmentGrid(
                            state: state,
                            attachments: message.attachments,
                            onDownload: widget.onDownloadAttachment,
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
                _ActionReveal(
                  key: _actionsKey,
                  visible: _actionsVisible,
                  child: MessageActionBar(
                    state: state,
                    isModel: true,
                    hasText: message.content.trim().isNotEmpty,
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
                padding: const EdgeInsets.only(top: 8),
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
      : const EdgeInsets.symmetric(horizontal: 18, vertical: 13);
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
          style: state.textStyle(context, size: 14.5, height: 1.55),
          decoration: InputDecoration(
            hintText: '编辑 AI 回复内容',
            hintStyle: state.textStyle(context, size: 14.5, opacity: 0.42),
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
          if (i > 0) const SizedBox(height: 12),
          switch (segments[i].kind) {
            MarkdownSegmentKind.markdown => MarkdownBody(
              data: segments[i].text,
              selectable: true,
              styleSheet: _aiMarkdownStyle(context, state, textAlign),
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

MarkdownStyleSheet _aiMarkdownStyle(
  BuildContext context,
  WeaviewState state,
  TextAlign textAlign,
) {
  final text = state.text(context);
  final dark = state.isDark(context);
  final tableBorder = text.withValues(alpha: dark ? 0.16 : 0.10);
  final wrapAlign = _markdownWrapAlignment(textAlign);
  return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
    a: state
        .textStyle(context, size: 15, height: 1.7, weight: FontWeight.w600)
        .copyWith(color: sendGreen),
    p: state.textStyle(context, size: 15, height: 1.76),
    h1: state.textStyle(context, size: 23, weight: FontWeight.w700),
    h2: state.textStyle(context, size: 20, weight: FontWeight.w700),
    h3: state.textStyle(context, size: 17, weight: FontWeight.w700),
    blockSpacing: 10,
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
    listIndent: 22,
    listBullet: state.textStyle(context, size: 15, height: 1.6),
    listBulletPadding: const EdgeInsets.only(right: 7),
    code: state
        .textStyle(context, size: 13.5)
        .copyWith(
          backgroundColor: state.text(context).withValues(alpha: 0.075),
          fontFamily: 'monospace',
          color: text,
        ),
    codeblockPadding: const EdgeInsets.all(12),
    codeblockDecoration: BoxDecoration(
      color: text.withValues(alpha: dark ? 0.10 : 0.055),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: text.withValues(alpha: 0.08)),
    ),
    blockquote: state.textStyle(
      context,
      size: 14.5,
      height: 1.65,
      opacity: 0.8,
    ),
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
    tableHead: state.textStyle(context, size: 13, weight: FontWeight.w800),
    tableBody: state.textStyle(context, size: 13, height: 1.45),
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
                  .textStyle(context, size: 16, height: 1.55)
                  .copyWith(
                    fontFamily: 'monospace',
                    fontStyle: FontStyle.italic,
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
            width: 30,
            height: 30,
            child: Icon(
              Icons.content_copy_rounded,
              size: 15,
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
