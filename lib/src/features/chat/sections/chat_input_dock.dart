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
    final activeToolIcon = imageGenerationMode
        ? Icons.auto_awesome_rounded
        : comparisonMode
        ? Icons.view_column_rounded
        : webSearchEnabled
        ? Icons.travel_explore_rounded
        : null;
    final activeToolLabel = imageGenerationMode
        ? '图片生成'
        : comparisonMode
        ? '多模型对照'
        : webSearchEnabled
        ? '联网搜索'
        : '';
    final activeToolTap = imageGenerationMode
        ? onToggleExpanded
        : comparisonMode
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
            child: imageGenerationMode
                ? _ImageModeStrip(
                    state: state,
                    imageCount: imageCount.clamp(1, 4),
                    onImageCountChanged: onImageCountChanged,
                  )
                : const SizedBox.shrink(),
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
                  idleLabel: imageGenerationMode
                      ? '生成 ${imageCount.clamp(1, 4)} 张'
                      : '编织',
                  streamingLabel: imageGenerationMode ? '生成中' : '编织中',
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
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 2),
      padding: const EdgeInsets.fromLTRB(10, 5, 7, 5),
      decoration: BoxDecoration(
        color: sendGreen.withValues(
          alpha: state.isDark(context) ? 0.10 : 0.06,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: sendGreen.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 14,
            color: sendGreen.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '图片生成',
              style: state.textStyle(
                context,
                size: 12,
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
        height: 44,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: base.withValues(alpha: dark ? 0.085 : 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: base.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var option = 1; option <= 4; option++)
              Padding(
                padding: EdgeInsets.only(right: option == 4 ? 0 : 2),
                child: Semantics(
                  button: true,
                  selected: option == value,
                  label: '输出 $option 张图片',
                  child: Material(
                    color: option == value ? sendGreen : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    child: InkWell(
                      key: ValueKey('image-count-option-$option'),
                      borderRadius: BorderRadius.circular(7),
                      onTap: onChanged == null
                          ? null
                          : () => onChanged!(option),
                      child: SizedBox(
                        width: 40,
                        child: Center(
                          child: Text(
                            '$option',
                            style: state
                                .textStyle(
                                  context,
                                  size: 11.5,
                                  weight: FontWeight.w500,
                                  opacity: option == value ? 1 : 0.6,
                                )
                                .copyWith(
                                  color: option == value ? Colors.white : base,
                                ),
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DockSectionLabel(state: state, label: '添加到对话'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DockAttachmentTile(
                  state: state,
                  icon: Icons.image_outlined,
                  label: '从相册选择',
                  subtitle: imageAttachmentCount > 0
                      ? '已添加 $imageAttachmentCount 张图片'
                      : '图片会作为对话附件或参考图',
                  onTap: onPickChatImages,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DockAttachmentTile(
                  state: state,
                  icon: Icons.description_outlined,
                  label: '选择文件',
                  subtitle: fileAttachmentCount > 0
                      ? '已添加 $fileAttachmentCount 个文件'
                      : 'PDF、文档与表格分析',
                  onTap: onPickChatFiles,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DockSectionLabel(state: state, label: '工具'),
          const SizedBox(height: 10),
          _DockActionRow(
            state: state,
            icon: Icons.public_rounded,
            title: '联网搜索',
            subtitle: '查找最新信息并带回对话',
            selected: webSearchEnabled,
            statusLabel: webSearchEnabled ? '已开启' : '未开启',
            onTap: onToggleWebSearch,
          ),
          const SizedBox(height: 10),
          _DockActionRow(
            state: state,
            icon: Icons.view_column_rounded,
            title: '多模型对比',
            subtitle: comparisonMode ? '当前会并行比较多个模型回答' : '最多同时选择 3 个模型',
            selected: comparisonMode,
            statusLabel: comparisonMode ? '已开启' : '未开启',
            onTap: onToggleComparison,
            trailingAction: comparisonMode
                ? TextButton(
                    onPressed: onConfigureComparison,
                    child: const Text('配置'),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _DockSectionLabel extends StatelessWidget {
  const _DockSectionLabel({required this.state, required this.label});

  final WeaviewState state;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: state.textStyle(
        context,
        size: 11.5,
        weight: FontWeight.w700,
        opacity: 0.54,
      ),
    );
  }
}

class _DockAttachmentTile extends StatelessWidget {
  const _DockAttachmentTile({
    required this.state,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final WeaviewState state;
  final IconData icon;
  final String label;
  final String subtitle;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final dark = state.isDark(context);
    final text = state.text(context);
    return Semantics(
      button: true,
      label: label,
      hint: subtitle,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: text.withValues(alpha: dark ? 0.055 : 0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: text.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: state.accents[0].withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 20, color: state.accents[0]),
                ),
                const SizedBox(height: 16),
                Text(
                  label,
                  style: state.textStyle(
                    context,
                    size: 13.5,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: state.textStyle(context, size: 11.5, opacity: 0.54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DockActionRow extends StatelessWidget {
  const _DockActionRow({
    required this.state,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.statusLabel,
    this.onTap,
    this.trailingAction,
  });

  final WeaviewState state;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final String statusLabel;
  final VoidCallback? onTap;
  final Widget? trailingAction;

  @override
  Widget build(BuildContext context) {
    final dark = state.isDark(context);
    final text = state.text(context);
    final content = Ink(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: selected
            ? state.accents[0].withValues(alpha: dark ? 0.14 : 0.10)
            : text.withValues(alpha: dark ? 0.055 : 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? state.accents[0].withValues(alpha: 0.28)
              : text.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: dark ? 0.08 : 0.56)
                  : Colors.white.withValues(alpha: dark ? 0.04 : 0.48),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 20,
              color: selected ? state.accents[0] : text.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: state.textStyle(
                    context,
                    size: 13.5,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: state.textStyle(context, size: 11.5, opacity: 0.54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _DockStatusPill(state: state, label: statusLabel, selected: selected),
          if (trailingAction != null) ...[
            const SizedBox(width: 4),
            trailingAction!,
          ],
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: title,
      hint: subtitle,
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: onTap,
                child: content,
              ),
            ),
    );
  }
}

class _DockStatusPill extends StatelessWidget {
  const _DockStatusPill({
    required this.state,
    required this.label,
    this.selected = false,
  });

  final WeaviewState state;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final text = state.text(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: selected
            ? state.accents[0].withValues(alpha: 0.12)
            : text.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected
              ? state.accents[0].withValues(alpha: 0.24)
              : text.withValues(alpha: 0.08),
        ),
      ),
      child: Text(
        label,
        style: state
            .textStyle(
              context,
              size: 11,
              weight: FontWeight.w700,
              opacity: selected ? 1 : 0.58,
            )
            .copyWith(color: selected ? state.accents[0] : text),
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
