// ignore_for_file: use_key_in_widget_constructors

import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_constants.dart';
import '../../app/weaview_state.dart';
import '../../core/app_utils.dart';
import '../../domain/models.dart';
import '../view_models/provider_model.dart';

class SendButton extends StatelessWidget {
  const SendButton({
    required this.enabled,
    required this.streaming,
    required this.onTap,
    required this.state,
  });

  final bool enabled;
  final bool streaming;
  final VoidCallback onTap;
  final WeaviewState state;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled
              ? streaming
                    ? const Color(0xFFF97316)
                    : sendGreen
              : state.text(context).withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(999),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: (streaming ? const Color(0xFFF97316) : sendGreen)
                        .withValues(alpha: 0.32),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          streaming ? '编织中' : '编织',
          style: state
              .textStyle(
                context,
                size: 14,
                weight: FontWeight.w600,
                opacity: enabled ? 1 : 0.34,
              )
              .copyWith(color: enabled ? Colors.white : state.text(context)),
        ),
      ),
    );
  }
}

class ToolChip extends StatelessWidget {
  const ToolChip({
    required this.icon,
    required this.label,
    required this.state,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final WeaviewState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: state.text(context).withValues(alpha: 0.055),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: state.text(context).withValues(alpha: 0.7),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: state.textStyle(
                  context,
                  size: 13,
                  weight: FontWeight.w600,
                  opacity: 0.82,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SuggestionChip extends StatelessWidget {
  const SuggestionChip({
    required this.state,
    required this.label,
    required this.onTap,
  });

  final WeaviewState state;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = state.isDark(context);
    return Material(
      color: state.text(context).withValues(alpha: dark ? 0.07 : 0.045),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 230),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: state.accents[0].withValues(alpha: 0.32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.14 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: state.textStyle(context, size: 12.5, opacity: 0.78),
          ),
        ),
      ),
    );
  }
}

class AttachmentPreviewStrip extends StatelessWidget {
  const AttachmentPreviewStrip({
    required this.state,
    required this.attachments,
    required this.onRemove,
  });

  final WeaviewState state;
  final List<MessageAttachment> attachments;
  final ValueChanged<MessageAttachment> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: state.text(context).withValues(alpha: 0.055),
          ),
        ),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final attachment = attachments[index];
          return _PendingAttachmentChip(
            state: state,
            attachment: attachment,
            onRemove: () => onRemove(attachment),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemCount: attachments.length,
      ),
    );
  }
}

class _PendingAttachmentChip extends StatelessWidget {
  const _PendingAttachmentChip({
    required this.state,
    required this.attachment,
    required this.onRemove,
  });

  final WeaviewState state;
  final MessageAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: attachment.isImage ? 64 : 166,
      decoration: BoxDecoration(
        color: state.text(context).withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: state.text(context).withValues(alpha: 0.06)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: _AttachmentVisual(attachment: attachment)),
          if (!attachment.isImage)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 30, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      attachment.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: state.textStyle(
                        context,
                        size: 12,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatBytes(attachment.size ?? 0),
                      style: state.textStyle(context, size: 10, opacity: 0.45),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            right: 4,
            top: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MessageAttachmentGrid extends StatelessWidget {
  const MessageAttachmentGrid({
    required this.state,
    required this.attachments,
    this.onDownload,
  });

  final WeaviewState state;
  final List<MessageAttachment> attachments;
  final ValueChanged<MessageAttachment>? onDownload;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final attachment in attachments)
          Stack(
            children: [
              Container(
                width: attachment.isImage ? 118 : 190,
                height: attachment.isImage ? 118 : 54,
                decoration: BoxDecoration(
                  color: state.text(context).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: state.text(context).withValues(alpha: 0.07),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: attachment.isImage
                    ? _AttachmentVisual(attachment: attachment)
                    : Row(
                        children: [
                          const SizedBox(width: 12),
                          Icon(
                            Icons.description_outlined,
                            size: 22,
                            color: state.text(context).withValues(alpha: 0.56),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  attachment.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: state.textStyle(
                                    context,
                                    size: 12,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  formatBytes(attachment.size ?? 0),
                                  style: state.textStyle(
                                    context,
                                    size: 10,
                                    opacity: 0.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                      ),
              ),
              if (onDownload != null)
                Positioned(
                  right: 6,
                  top: 6,
                  child: GestureDetector(
                    onTap: () => onDownload!(attachment),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.48),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.download_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _AttachmentVisual extends StatelessWidget {
  const _AttachmentVisual({required this.attachment});

  final MessageAttachment attachment;

  @override
  Widget build(BuildContext context) {
    if (attachment.isImage && File(attachment.path).existsSync()) {
      return Image.file(File(attachment.path), fit: BoxFit.cover);
    }
    return const Center(child: Icon(Icons.description_outlined, size: 24));
  }
}

class ModelDropdownItem extends StatelessWidget {
  const ModelDropdownItem({
    required this.state,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final WeaviewState state;
  final ProviderModel item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? state.accents[0].withValues(alpha: 0.12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.model.name,
                      overflow: TextOverflow.ellipsis,
                      style: state.textStyle(
                        context,
                        size: 14,
                        weight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.provider.name,
                      style: state
                          .textStyle(
                            context,
                            size: 10,
                            weight: FontWeight.w600,
                            opacity: 0.4,
                          )
                          .copyWith(letterSpacing: 1.2),
                    ),
                  ],
                ),
              ),
              if (selected)
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: state.accents[0],
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class HistoryTile extends StatelessWidget {
  const HistoryTile({
    required this.state,
    required this.session,
    required this.selected,
    required this.onTap,
  });

  final WeaviewState state;
  final ChatSession session;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? state.text(context).withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: Text(
              session.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: state.textStyle(
                context,
                size: 14,
                weight: selected ? FontWeight.w600 : FontWeight.w400,
                opacity: selected ? 1 : 0.7,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
