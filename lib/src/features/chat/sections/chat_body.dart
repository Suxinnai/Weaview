import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/weaview_state.dart';
import '../../../domain/models.dart';
import '../message_widgets.dart';

class ChatBody extends StatelessWidget {
  const ChatBody({
    super.key,
    required this.state,
    required this.scrollController,
    required this.dockExpanded,
    required this.dockHeight,
    required this.pendingAttachments,
    required this.onCopyMessage,
    required this.onRetryMessage,
    required this.onEditMessage,
    required this.onTranslateMessage,
    required this.onBranchMessage,
    required this.onDeleteMessage,
    required this.onSpeakMessage,
    required this.onDownloadAttachment,
    required this.onQuickPrompt,
  });

  final WeaviewState state;
  final ScrollController scrollController;
  final bool dockExpanded;
  final double dockHeight;
  final List<MessageAttachment> pendingAttachments;
  final Future<void> Function(ChatMessage message) onCopyMessage;
  final Future<void> Function(int index) onRetryMessage;
  final Future<void> Function(int index) onEditMessage;
  final Future<void> Function(int index) onTranslateMessage;
  final void Function(int index) onBranchMessage;
  final Future<void> Function(int index) onDeleteMessage;
  final Future<void> Function(ChatMessage message) onSpeakMessage;
  final Future<void> Function(MessageAttachment attachment)
  onDownloadAttachment;
  final ValueChanged<String> onQuickPrompt;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final navBarHeight = MediaQuery.paddingOf(context).bottom;
    final suggestionsVisible =
        state.suggestions.isNotEmpty &&
        !state.isStreaming &&
        !dockExpanded &&
        keyboardInset == 0;
    final measuredDockHeight = math.max(
      dockHeight,
      dockExpanded ? 132.0 : 104.0,
    );
    final bottomPad = keyboardInset > 0
        ? keyboardInset + measuredDockHeight + 18.0
        : suggestionsVisible
        ? measuredDockHeight + navBarHeight + 58.0
        : measuredDockHeight + navBarHeight + 42.0;
    return Positioned.fill(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 64),
          child: state.messages.isEmpty
              ? AnimatedPadding(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.only(
                    bottom: keyboardInset > 0
                        ? keyboardInset + measuredDockHeight
                        : 0,
                  ),
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 18 * (1 - value)),
                          child: Opacity(opacity: value, child: child),
                        );
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: state.accents[0].withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: state
                                    .text(context)
                                    .withValues(alpha: 0.08),
                              ),
                            ),
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              color: state
                                  .text(context)
                                  .withValues(alpha: 0.68),
                              size: 30,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            '织境 Agent 已就绪',
                            textAlign: TextAlign.center,
                            style: state
                                .textStyle(
                                  context,
                                  size: 18,
                                  weight: FontWeight.w700,
                                  opacity: 0.82,
                                )
                                .copyWith(letterSpacing: 0.2),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '把任务、图片、文件或链接交给它处理',
                            textAlign: TextAlign.center,
                            style: state
                                .textStyle(
                                  context,
                                  size: 13,
                                  weight: FontWeight.w400,
                                  opacity: 0.46,
                                )
                                .copyWith(letterSpacing: 0),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _AgentHintChip(
                                state: state,
                                label: '总结网页',
                                onTap: () => onQuickPrompt('总结这个链接的重点：'),
                              ),
                              _AgentHintChip(
                                state: state,
                                label: '分析图片',
                                onTap: () => onQuickPrompt('分析这张图片并给出结论：'),
                              ),
                              _AgentHintChip(
                                state: state,
                                label: '运行 Skills',
                                onTap: () => onQuickPrompt('用合适的 Skill 处理：'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad),
                  itemCount: state.messages.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 32),
                  itemBuilder: (context, index) {
                    final message = state.messages[index];
                    return MessageBubble(
                      state: state,
                      message: message,
                      index: index,
                      assistantAvatar: state.assistantAvatar,
                      userAvatar: state.userAvatar,
                      onCopy: () => onCopyMessage(message),
                      onRetry: () => onRetryMessage(index),
                      onEdit: () => onEditMessage(index),
                      onTranslate: () => onTranslateMessage(index),
                      onBranch: () => onBranchMessage(index),
                      onDelete: () => onDeleteMessage(index),
                      onSpeak: () => onSpeakMessage(message),
                      onDownloadAttachment: onDownloadAttachment,
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _AgentHintChip extends StatelessWidget {
  const _AgentHintChip({
    required this.state,
    required this.label,
    required this.onTap,
  });

  final WeaviewState state;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: state.text(context).withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: state.text(context).withValues(alpha: 0.06),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: state.textStyle(
                context,
                size: 12,
                weight: FontWeight.w600,
                opacity: 0.62,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
