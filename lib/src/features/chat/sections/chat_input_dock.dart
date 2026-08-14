import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../app/app_constants.dart';
import '../../../app/weaview_state.dart';
import '../../../domain/models.dart';
import '../../../shared/widgets/shared_widgets.dart';

class ChatInputDock extends StatelessWidget {
  const ChatInputDock({
    super.key,
    required this.state,
    required this.inputController,
    required this.inputFocusNode,
    required this.webSearchEnabled,
    required this.imageGenerationMode,
    required this.comparisonMode,
    required this.dockExpanded,
    required this.pendingAttachments,
    required this.onToggleExpanded,
    required this.onToggleWebSearch,
    required this.onToggleComparison,
    required this.onConfigureComparison,
    required this.onSubmit,
    required this.onPickChatImages,
    required this.onPickChatFiles,
    required this.onRemoveAttachment,
    required this.onTextChanged,
    required this.onHeightChanged,
    this.imageCount = 1,
    this.onImageCountChanged,
  });

  final WeaviewState state;
  final TextEditingController inputController;
  final FocusNode inputFocusNode;
  final bool webSearchEnabled;
  final bool imageGenerationMode;
  final bool comparisonMode;
  final bool dockExpanded;
  final List<MessageAttachment> pendingAttachments;
  final VoidCallback onToggleExpanded;
  final VoidCallback onToggleWebSearch;
  final VoidCallback onToggleComparison;
  final VoidCallback onConfigureComparison;
  final Future<void> Function() onSubmit;
  final Future<void> Function() onPickChatImages;
  final Future<void> Function() onPickChatFiles;
  final ValueChanged<MessageAttachment> onRemoveAttachment;
  final VoidCallback onTextChanged;
  final ValueChanged<Size> onHeightChanged;
  final int imageCount;
  final ValueChanged<int>? onImageCountChanged;

  @override
  Widget build(BuildContext context) {
    final dark = state.isDark(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpen = keyboardInset > 0;
    final hasText = inputController.text.trim().isNotEmpty;
    final rawInput = inputController.text;
    final explicitLineCount = rawInput.isEmpty
        ? 1
        : rawInput.split('\n').length;
    final estimatedLineCount = math.max(
      explicitLineCount,
      (rawInput.characters.length / 18).ceil(),
    );
    final needsExpandedEditor = estimatedLineCount > 3;
    final imageAttachmentCount = pendingAttachments
        .where((item) => item.isImage)
        .length;
    final fileAttachmentCount =
        pendingAttachments.length - imageAttachmentCount;
    final activeToolIcon = comparisonMode
        ? Icons.view_column_rounded
        : webSearchEnabled
        ? Icons.travel_explore_rounded
        : null;
    final activeToolLabel = comparisonMode
        ? '多模型对照'
        : webSearchEnabled
        ? '联网搜索'
        : '';
    final activeToolTap = comparisonMode
        ? onConfigureComparison
        : webSearchEnabled
        ? onToggleWebSearch
        : onToggleExpanded;
    final canSubmit = imageGenerationMode
        ? hasText
        : hasText || pendingAttachments.isNotEmpty;
    final radius = BorderRadius.circular(dockExpanded ? 22 : 26);
    final glassBase = dark ? Colors.black : Colors.white;
    final dockSurface = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: glassBase.withValues(alpha: dark ? 0.27 : 0.31),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: dark ? 0.07 : 0.28),
            glassBase.withValues(alpha: dark ? 0.19 : 0.12),
          ],
        ),
        borderRadius: radius,
        border: Border.all(
          color: state.text(context).withValues(alpha: dark ? 0.1 : 0.11),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.18 : 0.065),
            blurRadius: keyboardOpen ? 14 : 20,
            spreadRadius: -9,
            offset: Offset(0, keyboardOpen ? 8 : 13),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: pendingAttachments.isEmpty
                ? const SizedBox.shrink()
                : AttachmentPreviewStrip(
                    state: state,
                    attachments: pendingAttachments,
                    onRemove: onRemoveAttachment,
                  ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.12),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: imageGenerationMode
                  ? _ImageModeStrip(
                      state: state,
                      imageCount: clampImageGenerationCount(imageCount),
                      onImageCountChanged: onImageCountChanged,
                    )
                  : const SizedBox.shrink(
                      key: ValueKey('image-mode-strip-hidden'),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              crossAxisAlignment: needsExpandedEditor
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.center,
              children: [
                Tooltip(
                  message: dockExpanded ? '收起附件与工具' : '添加附件与工具',
                  child: Semantics(
                    button: true,
                    expanded: dockExpanded,
                    label: dockExpanded ? '收起附件与工具' : '添加附件与工具',
                    child: Material(
                      color: dockExpanded
                          ? state.text(context).withValues(alpha: 0.06)
                          : Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onToggleExpanded,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: AnimatedRotation(
                            duration: const Duration(milliseconds: 220),
                            turns: dockExpanded ? 0.125 : 0,
                            child: Icon(
                              Icons.add_rounded,
                              size: 23,
                              color: state
                                  .text(context)
                                  .withValues(alpha: dockExpanded ? 1 : 0.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  child: activeToolIcon == null || needsExpandedEditor
                      ? const SizedBox(
                          key: ValueKey('active_tool_hidden'),
                          width: 2,
                        )
                      : Padding(
                          key: ValueKey('active_tool_$activeToolLabel'),
                          padding: const EdgeInsets.only(left: 2, right: 2),
                          child: _ActiveToolIndicator(
                            state: state,
                            icon: activeToolIcon,
                            label: activeToolLabel,
                            onTap: activeToolTap,
                          ),
                        ),
                ),
                Expanded(
                  child: TextField(
                    controller: inputController,
                    focusNode: inputFocusNode,
                    minLines: 1,
                    maxLines: needsExpandedEditor ? 4 : 5,
                    textInputAction: TextInputAction.newline,
                    style: state.textStyle(context, size: 15, height: 1.45),
                    decoration: InputDecoration(
                      hintText: imageGenerationMode
                          ? '描述要生成或修改的画面…'
                          : '今天想编织什么？',
                      hintStyle: state.textStyle(
                        context,
                        size: 15,
                        opacity: 0.38,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      filled: false,
                      fillColor: Colors.transparent,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 7,
                      ),
                    ),
                    onSubmitted: (_) => onSubmit(),
                    onChanged: (_) => onTextChanged(),
                  ),
                ),
                const SizedBox(width: 4),
                if (needsExpandedEditor)
                  IconCircleButton(
                    icon: Icons.open_in_full_rounded,
                    onTap: () => _openExpandedComposer(context),
                    color: state.text(context),
                    background: state.text(context).withValues(alpha: 0.055),
                    opacity: 0.62,
                    size: 38,
                  ),
                const SizedBox(width: 3),
                SendButton(
                  streaming: state.isStreaming,
                  enabled:
                      state.isStreaming || (canSubmit && !state.isStreaming),
                  onTap: onSubmit,
                  state: state,
                  idleLabel: imageGenerationMode ? '织梦' : '编织',
                  streamingLabel: imageGenerationMode ? '织梦中' : '编织中',
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: dockExpanded
                ? _DockActionSheet(
                    state: state,
                    webSearchEnabled: webSearchEnabled,
                    comparisonMode: comparisonMode,
                    imageAttachmentCount: imageAttachmentCount,
                    fileAttachmentCount: fileAttachmentCount,
                    onPickChatImages: onPickChatImages,
                    onPickChatFiles: onPickChatFiles,
                    onToggleWebSearch: onToggleWebSearch,
                    onToggleComparison: onToggleComparison,
                    onConfigureComparison: onConfigureComparison,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
    final dock = MeasureSize(
      onChange: onHeightChanged,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: dockSurface,
        ),
      ),
    );
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.25,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Padding(padding: EdgeInsets.zero, child: dock),
          ),
        ),
      ),
    );
  }

  Future<void> _openExpandedComposer(BuildContext context) async {
    final editor = TextEditingController(text: inputController.text);
    try {
      final result = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          final bottom = MediaQuery.viewInsetsOf(context).bottom;
          final dark = state.isDark(context);
          return Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, bottom + 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: state
                    .layer(context)
                    .withValues(alpha: dark ? 0.94 : 0.98),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: state.text(context).withValues(alpha: 0.08),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: dark ? 0.30 : 0.12),
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          '展开输入',
                          style: state.textStyle(
                            context,
                            size: 15,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: editor,
                      autofocus: true,
                      minLines: 6,
                      maxLines: 12,
                      style: state.textStyle(context, size: 16, height: 1.5),
                      decoration: InputDecoration(
                        hintText: '今天想编织什么？',
                        hintStyle: state.textStyle(
                          context,
                          size: 16,
                          opacity: 0.36,
                        ),
                        filled: true,
                        fillColor: state.text(context).withValues(alpha: 0.045),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('取消'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () =>
                                Navigator.of(context).pop(editor.text),
                            child: const Text('完成'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
      if (result == null) return;
      inputController.text = result;
      inputController.selection = TextSelection.collapsed(
        offset: inputController.text.length,
      );
      onTextChanged();
      inputFocusNode.requestFocus();
    } finally {
      editor.dispose();
    }
  }
}

class _ImageModeStrip extends StatelessWidget {
  const _ImageModeStrip({
    required this.state,
    required this.imageCount,
    required this.onImageCountChanged,
  });

  final WeaviewState state;
  final int imageCount;
  final ValueChanged<int>? onImageCountChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('image-mode-strip'),
      margin: const EdgeInsets.fromLTRB(8, 7, 8, 1),
      padding: const EdgeInsets.fromLTRB(9, 4, 5, 4),
      decoration: BoxDecoration(
        color: sendGreen.withValues(alpha: state.isDark(context) ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: sendGreen.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 13,
            color: sendGreen.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              '图片生成',
              style: state.textStyle(
                context,
                size: 11.5,
                weight: FontWeight.w500,
                opacity: 0.72,
              ),
            ),
          ),
          _ImageCountSelector(
            state: state,
            value: imageCount,
            onChanged: onImageCountChanged,
          ),
        ],
      ),
    );
  }
}

class _ImageCountSelector extends StatelessWidget {
  const _ImageCountSelector({
    required this.state,
    required this.value,
    required this.onChanged,
  });

  final WeaviewState state;
  final int value;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = state.isDark(context);
    final base = state.text(context);
    return Tooltip(
      message: '输出张数',
      child: Container(
        key: const ValueKey('image-count-selector'),
        height: 36,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: base.withValues(alpha: dark ? 0.085 : 0.06),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: base.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (
              var option = minImageGenerationCount;
              option <= maxImageGenerationCount;
              option++
            )
              Padding(
                padding: EdgeInsets.only(
                  right: option == maxImageGenerationCount ? 0 : 1,
                ),
                child: Semantics(
                  button: true,
                  selected: option == value,
                  label: '输出 $option 张图片',
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      key: ValueKey('image-count-option-$option'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: onChanged == null
                          ? null
                          : () => onChanged!(option),
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutBack,
                        scale: option == value ? 1 : 0.96,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: option == value
                                ? sendGreen
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: option == value
                                ? [
                                    BoxShadow(
                                      color: sendGreen.withValues(alpha: 0.22),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 160),
                            style: state
                                .textStyle(
                                  context,
                                  size: 11,
                                  weight: FontWeight.w600,
                                  opacity: option == value ? 1 : 0.56,
                                )
                                .copyWith(
                                  color: option == value ? Colors.white : base,
                                ),
                            child: Text('$option'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DockActionSheet extends StatelessWidget {
  const _DockActionSheet({
    required this.state,
    required this.webSearchEnabled,
    required this.comparisonMode,
    required this.imageAttachmentCount,
    required this.fileAttachmentCount,
    required this.onPickChatImages,
    required this.onPickChatFiles,
    required this.onToggleWebSearch,
    required this.onToggleComparison,
    required this.onConfigureComparison,
  });

  final WeaviewState state;
  final bool webSearchEnabled;
  final bool comparisonMode;
  final int imageAttachmentCount;
  final int fileAttachmentCount;
  final Future<void> Function() onPickChatImages;
  final Future<void> Function() onPickChatFiles;
  final VoidCallback onToggleWebSearch;
  final VoidCallback onToggleComparison;
  final VoidCallback onConfigureComparison;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 11),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
            child: _DashedDockDivider(state: state),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemSize = ((constraints.maxWidth - 24) / 4).clamp(
                68.0,
                84.0,
              );
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _DockQuickAction(
                    state: state,
                    icon: Icons.image_outlined,
                    label: '相册',
                    size: itemSize,
                    badgeCount: imageAttachmentCount,
                    onTap: onPickChatImages,
                  ),
                  _DockQuickAction(
                    state: state,
                    icon: Icons.description_outlined,
                    label: '文件',
                    size: itemSize,
                    badgeCount: fileAttachmentCount,
                    onTap: onPickChatFiles,
                  ),
                  _DockQuickAction(
                    state: state,
                    icon: Icons.travel_explore_rounded,
                    label: '联网',
                    size: itemSize,
                    selected: webSearchEnabled,
                    onTap: onToggleWebSearch,
                  ),
                  _DockQuickAction(
                    state: state,
                    icon: Icons.view_column_rounded,
                    label: '对比',
                    size: itemSize,
                    selected: comparisonMode,
                    onTap: onToggleComparison,
                    onSecondaryTap: comparisonMode
                        ? onConfigureComparison
                        : null,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DashedDockDivider extends StatelessWidget {
  const _DashedDockDivider({required this.state});

  final WeaviewState state;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      width: double.infinity,
      child: CustomPaint(
        painter: _DashedDockDividerPainter(
          color: state.text(context).withValues(alpha: 0.16),
        ),
      ),
    );
  }
}

class _DashedDockDividerPainter extends CustomPainter {
  const _DashedDockDividerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    const dash = 4.0;
    const gap = 5.0;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(
        Offset(x, 0.5),
        Offset(math.min(x + dash, size.width), 0.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedDockDividerPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _DockQuickAction extends StatelessWidget {
  const _DockQuickAction({
    required this.state,
    required this.icon,
    required this.label,
    required this.size,
    required this.onTap,
    this.selected = false,
    this.badgeCount = 0,
    this.onSecondaryTap,
  });

  final WeaviewState state;
  final IconData icon;
  final String label;
  final double size;
  final VoidCallback onTap;
  final bool selected;
  final int badgeCount;
  final VoidCallback? onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    final dark = state.isDark(context);
    final text = state.text(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Ink(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: selected
                  ? state.accents[0].withValues(alpha: dark ? 0.08 : 0.035)
                  : text.withValues(alpha: dark ? 0.045 : 0.025),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: selected
                    ? state.accents[0].withValues(alpha: 0.62)
                    : text.withValues(alpha: 0.085),
                width: selected ? 1.25 : 0.8,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 22,
                        color: selected
                            ? state.accents[0]
                            : text.withValues(alpha: 0.62),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        label,
                        maxLines: 1,
                        style: state.textStyle(
                          context,
                          size: 11,
                          weight: selected ? FontWeight.w700 : FontWeight.w600,
                          opacity: selected ? 0.96 : 0.62,
                        ),
                      ),
                    ],
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: 7,
                    right: 7,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: state.accents[0],
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        '$badgeCount',
                        style: state
                            .textStyle(
                              context,
                              size: 9,
                              weight: FontWeight.w700,
                            )
                            .copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                if (onSecondaryTap != null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onSecondaryTap,
                        child: SizedBox(
                          width: 25,
                          height: 25,
                          child: Icon(
                            Icons.tune_rounded,
                            size: 14,
                            color: state.accents[0],
                          ),
                        ),
                      ),
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

class _ActiveToolIndicator extends StatelessWidget {
  const _ActiveToolIndicator({
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
    return Tooltip(
      message: label,
      child: Material(
        color: sendGreen.withValues(alpha: 0.14),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 20, color: sendGreen),
          ),
        ),
      ),
    );
  }
}
