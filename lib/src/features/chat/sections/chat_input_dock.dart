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
    final activeToolIcon = comparisonMode
        ? Icons.view_column_rounded
        : webSearchEnabled
        ? Icons.travel_explore_rounded
        : imageGenerationMode
        ? Icons.image_outlined
        : null;
    final activeToolLabel = comparisonMode
        ? '多模型对照'
        : webSearchEnabled
        ? '联网搜索'
        : imageGenerationMode
        ? '图像生成'
        : '';
    final activeToolTap = comparisonMode
        ? onConfigureComparison
        : webSearchEnabled
        ? onToggleWebSearch
        : onToggleExpanded;
    final canSubmit = imageGenerationMode
        ? hasText
        : hasText || pendingAttachments.isNotEmpty;
    final radius = BorderRadius.circular(dockExpanded ? 22 : 28);
    final glassBase = dark ? Colors.black : Colors.white;
    final textColor = state.text(context);
    final dockSurface = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: glassBase.withValues(alpha: dark ? 0.24 : 0.30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: dark ? 0.05 : 0.26),
            glassBase.withValues(alpha: dark ? 0.18 : 0.12),
          ],
        ),
        borderRadius: radius,
        border: Border.all(
          color: textColor.withValues(alpha: dark ? 0.08 : 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.18 : 0.065),
            blurRadius: keyboardOpen ? 16 : 24,
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
          Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              crossAxisAlignment: needsExpandedEditor
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: onToggleExpanded,
                  child: AnimatedRotation(
                    duration: const Duration(milliseconds: 260),
                    turns: dockExpanded ? 0.125 : 0,
                    child: Container(
                      width: 40,
                      height: 38,
                      decoration: BoxDecoration(
                        color: dockExpanded
                            ? state.text(context).withValues(alpha: 0.06)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
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
                      hintText: '今天想编织什么？',
                      hintStyle: state.textStyle(
                        context,
                        size: 15,
                        opacity: 0.38,
                      ),
                      border: InputBorder.none,
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
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: dockExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Wrap(
                      spacing: 9,
                      runSpacing: 9,
                      children: [
                        ToolChip(
                          icon: Icons.image_outlined,
                          label: '图片',
                          state: state,
                          onTap: onPickChatImages,
                        ),
                        ToolChip(
                          icon: Icons.description_outlined,
                          label: '文件',
                          state: state,
                          onTap: onPickChatFiles,
                        ),
                        ToolChip(
                          icon: Icons.public_rounded,
                          label: webSearchEnabled ? '关闭联网' : '联网搜索',
                          state: state,
                          selected: webSearchEnabled,
                          onTap: onToggleWebSearch,
                        ),
                        ToolChip(
                          icon: Icons.view_column_rounded,
                          label: comparisonMode ? '关闭对照' : '多模型对照',
                          state: state,
                          selected: comparisonMode,
                          onTap: onToggleComparison,
                        ),
                      ],
                    ),
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
    return AnimatedPadding(
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
            width: 38,
            height: 38,
            child: Icon(icon, size: 20, color: sendGreen),
          ),
        ),
      ),
    );
  }
}
