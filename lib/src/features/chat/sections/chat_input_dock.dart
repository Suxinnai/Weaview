import 'dart:math' as math;

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
    required this.wave,
    required this.recording,
    required this.webSearchEnabled,
    required this.imageGenerationMode,
    required this.dockExpanded,
    required this.pendingAttachments,
    required this.onToggleExpanded,
    required this.onToggleWebSearch,
    required this.onSubmit,
    required this.onToggleRecording,
    required this.onPickChatImages,
    required this.onPickChatFiles,
    required this.onRemoveAttachment,
    required this.onTextChanged,
  });

  final WeaviewState state;
  final TextEditingController inputController;
  final FocusNode inputFocusNode;
  final Animation<double> wave;
  final bool recording;
  final bool webSearchEnabled;
  final bool imageGenerationMode;
  final bool dockExpanded;
  final List<MessageAttachment> pendingAttachments;
  final VoidCallback onToggleExpanded;
  final VoidCallback onToggleWebSearch;
  final Future<void> Function() onSubmit;
  final Future<void> Function() onToggleRecording;
  final Future<void> Function() onPickChatImages;
  final Future<void> Function() onPickChatFiles;
  final ValueChanged<MessageAttachment> onRemoveAttachment;
  final VoidCallback onTextChanged;

  @override
  Widget build(BuildContext context) {
    final dark = state.isDark(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpen = keyboardInset > 0;
    final hasText = inputController.text.trim().isNotEmpty;
    final canSubmit = imageGenerationMode
        ? hasText
        : hasText || pendingAttachments.isNotEmpty;
    final dockSurface = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: (dark ? Colors.black : state.layer(context)).withValues(
          alpha: dark ? 0.44 : 0.30,
        ),
        borderRadius: BorderRadius.circular(dockExpanded ? 22 : 28),
        border: Border.all(
          color: (dark ? Colors.white : Colors.black).withValues(
            alpha: dark ? 0.06 : 0.07,
          ),
        ),
        boxShadow: [
          if (!keyboardOpen)
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.14 : 0.055),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: recording
                ? _RecordingStrip(state: state, wave: wave)
                : const SizedBox.shrink(),
          ),
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
              crossAxisAlignment: CrossAxisAlignment.center,
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
                IconCircleButton(
                  icon: webSearchEnabled
                      ? Icons.travel_explore_rounded
                      : Icons.public_rounded,
                  onTap: onToggleWebSearch,
                  color: webSearchEnabled ? sendGreen : state.text(context),
                  background: webSearchEnabled
                      ? sendGreen.withValues(alpha: 0.14)
                      : Colors.transparent,
                  opacity: webSearchEnabled ? 1 : 0.42,
                  size: 38,
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: TextField(
                    controller: inputController,
                    focusNode: inputFocusNode,
                    minLines: 1,
                    maxLines: 5,
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
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) => onSubmit(),
                    onChanged: (_) => onTextChanged(),
                  ),
                ),
                const SizedBox(width: 4),
                if ((inputController.text.trim().isEmpty || recording) &&
                    !state.isStreaming)
                  IconCircleButton(
                    icon: Icons.mic_none_rounded,
                    onTap: onToggleRecording,
                    color: recording ? sendGreen : state.text(context),
                    background: recording
                        ? sendGreen.withValues(alpha: 0.18)
                        : Colors.transparent,
                    opacity: recording ? 1 : 0.42,
                    size: 38,
                  ),
                const SizedBox(width: 3),
                SendButton(
                  streaming: state.isStreaming,
                  enabled:
                      state.isStreaming ||
                      (canSubmit && !state.isStreaming && !recording),
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
                          onTap: onToggleWebSearch,
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
    final dock = ClipRRect(
      borderRadius: BorderRadius.circular(dockExpanded ? 22 : 28),
      child: dockSurface,
    );
    return AnimatedPadding(
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: dock,
          ),
        ),
      ),
    );
  }
}

class _RecordingStrip extends StatelessWidget {
  const _RecordingStrip({required this.state, required this.wave});

  final WeaviewState state;
  final Animation<double> wave;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: sendGreen.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(
            color: state.text(context).withValues(alpha: 0.06),
          ),
        ),
      ),
      child: AnimatedBuilder(
        animation: wave,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 7; i++)
                Container(
                  width: 5,
                  height:
                      10 +
                      (math.sin((wave.value * math.pi * 2) + i * 0.75) + 1) * 8,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: sendGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              const SizedBox(width: 10),
              Text(
                '聆听中...',
                style: state
                    .textStyle(context, size: 12, weight: FontWeight.w600)
                    .copyWith(color: sendGreen, letterSpacing: 1.5),
              ),
            ],
          );
        },
      ),
    );
  }
}
