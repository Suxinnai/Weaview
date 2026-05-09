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
              ? Center(
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
                        Text(
                          '今天，你想编织什么梦境？',
                          textAlign: TextAlign.center,
                          style: state
                              .textStyle(
                                context,
                                size: 17,
                                weight: FontWeight.w300,
                                opacity: 0.82,
                              )
                              .copyWith(letterSpacing: 1.8),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'What dream shall we weave today?',
                          textAlign: TextAlign.center,
                          style: state
                              .textStyle(
                                context,
                                size: 12,
                                weight: FontWeight.w400,
                                opacity: 0.38,
                              )
                              .copyWith(letterSpacing: 0.7),
                        ),
                      ],
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
