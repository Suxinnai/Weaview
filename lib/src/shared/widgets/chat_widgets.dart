// ignore_for_file: use_key_in_widget_constructors

import 'dart:collection';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_constants.dart';
import '../../app/weaview_state.dart';
import '../../core/app_utils.dart';
import '../../domain/models.dart';
import '../view_models/provider_model.dart';
import 'brand_icon.dart';
import 'model_capability_chips.dart';

const _nativeMedia = MethodChannel('weaview/native_media');

class SendButton extends StatelessWidget {
  const SendButton({
    required this.enabled,
    required this.streaming,
    required this.onTap,
    required this.state,
    this.idleLabel = '编织',
    this.streamingLabel = '编织中',
  });

  final bool enabled;
  final bool streaming;
  final VoidCallback onTap;
  final WeaviewState state;
  final String idleLabel;
  final String streamingLabel;

  @override
  Widget build(BuildContext context) {
    final label = streaming ? streamingLabel : idleLabel;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 42),
            padding: const EdgeInsets.symmetric(horizontal: 17),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: enabled
                  ? streaming
                        ? const Color(0xFFF97316)
                        : sendGreen
                  : state.accents[0].withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(999),
              border: enabled
                  ? null
                  : Border.all(color: state.accents[0].withValues(alpha: 0.16)),
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
              label,
              style: state
                  .textStyle(
                    context,
                    size: 13,
                    weight: FontWeight.w600,
                    opacity: enabled ? 1 : 0.62,
                  )
                  .copyWith(
                    color: enabled ? Colors.white : state.text(context),
                  ),
            ),
          ),
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
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final WeaviewState state;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected
            ? state.accents[0].withValues(alpha: 0.16)
            : state.text(context).withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: selected
                        ? state.accents[0]
                        : state.text(context).withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: state.textStyle(
                      context,
                      size: 13,
                      weight: FontWeight.w600,
                      opacity: selected ? 1 : 0.82,
                    ),
                  ),
                ],
              ),
            ),
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
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 230, minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: state.layer(context).withValues(alpha: dark ? 0.22 : 0.34),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: state.accents[0].withValues(alpha: 0.32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.14 : 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: state.textStyle(context, size: 12.5, opacity: 0.78),
              ),
            ),
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
          Positioned.fill(
            child: _AttachmentVisual(attachment: attachment, animate: false),
          ),
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
            child: Tooltip(
              message: '移除附件',
              child: Material(
                color: Colors.black.withValues(alpha: 0.5),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onRemove,
                  child: const SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
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
    this.imageExtent = 118,
    this.animateImages = false,
  });

  final WeaviewState state;
  final List<MessageAttachment> attachments;
  final ValueChanged<MessageAttachment>? onDownload;
  final double imageExtent;
  final bool animateImages;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const ValueKey('message-attachment-grid'),
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final attachment in attachments)
          _AttachmentTile(
            state: state,
            attachment: attachment,
            onDownload: onDownload,
            imageExtent: imageExtent,
            animateImages: animateImages,
          ),
      ],
    );
  }
}

class GeneratedImageGallery extends StatefulWidget {
  const GeneratedImageGallery({
    required this.state,
    required this.attachments,
    this.onDownload,
    this.animateImages = true,
  });

  final WeaviewState state;
  final List<MessageAttachment> attachments;
  final ValueChanged<MessageAttachment>? onDownload;
  final bool animateImages;

  @override
  State<GeneratedImageGallery> createState() => _GeneratedImageGalleryState();
}

class _GeneratedImageGalleryState extends State<GeneratedImageGallery> {
  final Set<int> _selectedIndices = {0};

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final images = widget.attachments
        .where((attachment) => attachment.isImage)
        .toList();
    if (images.isEmpty) {
      return const SizedBox.shrink();
    }
    final dark = state.isDark(context);
    final columns = images.length == 1 ? 1 : 2;
    final single = images.length == 1;
    return Container(
      key: const ValueKey('generated-image-gallery'),
      width: double.infinity,
      padding: EdgeInsets.all(single ? 4 : 12),
      decoration: BoxDecoration(
        color: state.layer(context).withValues(alpha: dark ? 0.48 : 0.72),
        borderRadius: BorderRadius.circular(single ? 18 : 20),
        border: Border.all(
          color: state.text(context).withValues(alpha: dark ? 0.08 : 0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!single)
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '已生成 ${images.length} 张',
                    style: state.textStyle(
                      context,
                      size: 14,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  _selectedIndices.isEmpty
                      ? '点按选择'
                      : '已选 ${_selectedIndices.length} 张',
                  style: state.textStyle(context, size: 11.5, opacity: 0.52),
                ),
              ],
            ),
          if (!single) const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final spacing = 10.0;
              final tileWidth = columns == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - spacing) / 2;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (var index = 0; index < images.length; index++)
                    _GeneratedGridTile(
                      state: state,
                      attachments: images,
                      attachment: images[index],
                      index: index,
                      width: tileWidth,
                      selected: single || _selectedIndices.contains(index),
                      single: single,
                      animateImages: widget.animateImages,
                      onToggleSelected: single
                          ? () => _openImagePreview(
                              context,
                              state,
                              attachments: images,
                              initialIndex: index,
                              onDownload: widget.onDownload,
                            )
                          : () {
                              setState(() {
                                if (!_selectedIndices.add(index)) {
                                  _selectedIndices.remove(index);
                                }
                              });
                            },
                      onPreview: () => _openImagePreview(
                        context,
                        state,
                        attachments: images,
                        initialIndex: index,
                        onDownload: widget.onDownload,
                      ),
                    ),
                ],
              );
            },
          ),
          if (!single) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _GalleryActionButton(
                    state: state,
                    icon: Icons.download_rounded,
                    label: '保存所选',
                    enabled: widget.onDownload != null &&
                        _selectedIndices.isNotEmpty,
                    onTap: () {
                      for (final index in _selectedIndices) {
                        widget.onDownload?.call(images[index]);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _GalleryActionButton(
                    state: state,
                    icon: Icons.open_in_full_rounded,
                    label: '查看大图',
                    enabled: _selectedIndices.isNotEmpty,
                    emphasized: true,
                    onTap: () {
                      final index = _selectedIndices.isEmpty
                          ? 0
                          : _selectedIndices.first;
                      _openImagePreview(
                        context,
                        state,
                        attachments: images,
                        initialIndex: index,
                        onDownload: widget.onDownload,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _GalleryActionButton extends StatelessWidget {
  const _GalleryActionButton({
    required this.state,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.emphasized = false,
  });

  final WeaviewState state;
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: emphasized
            ? color.withValues(alpha: enabled ? 0.12 : 0.05)
            : state.text(context).withValues(alpha: enabled ? 0.05 : 0.025),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: emphasized
                      ? color.withValues(alpha: enabled ? 1 : 0.35)
                      : state
                            .text(context)
                            .withValues(alpha: enabled ? 0.68 : 0.28),
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: state.textStyle(
                    context,
                    size: 12.5,
                    weight: FontWeight.w600,
                    opacity: enabled ? 0.78 : 0.32,
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

class _GeneratedGridTile extends StatelessWidget {
  const _GeneratedGridTile({
    required this.state,
    required this.attachments,
    required this.attachment,
    required this.index,
    required this.width,
    required this.selected,
    required this.animateImages,
    required this.onToggleSelected,
    required this.onPreview,
    this.single = false,
  });

  final WeaviewState state;
  final List<MessageAttachment> attachments;
  final MessageAttachment attachment;
  final int index;
  final double width;
  final bool selected;
  final bool animateImages;
  final VoidCallback onToggleSelected;
  final VoidCallback onPreview;
  final bool single;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final radius = BorderRadius.circular(16);
    return SizedBox(
      width: width,
      height: width,
      child: Stack(
        children: [
          Positioned.fill(
            child: Material(
              color: state.text(context).withValues(alpha: 0.04),
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onToggleSelected,
                borderRadius: radius,
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color: selected
                          ? primary
                          : state.text(context).withValues(alpha: 0.08),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: _AttachmentVisual(
                    attachment: attachment,
                    animate: animateImages,
                  ),
                ),
              ),
            ),
          ),
          if (!single)
            Positioned(
              top: 8,
              right: 8,
              child: Semantics(
                button: true,
                selected: selected,
                label: '选择图片 ${index + 1}，共 ${attachments.length} 张',
                child: GestureDetector(
                  onTap: onToggleSelected,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? primary
                          : Colors.black.withValues(alpha: 0.24),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
              ),
            ),
          if (!single)
            Positioned(
              right: 8,
              bottom: 8,
              child: Tooltip(
                message: '查看大图',
                child: Material(
                  color: Colors.black.withValues(alpha: 0.36),
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: onPreview,
                    customBorder: const CircleBorder(),
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.open_in_full_rounded,
                        size: 17,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.state,
    required this.attachment,
    required this.onDownload,
    required this.imageExtent,
    required this.animateImages,
  });

  final WeaviewState state;
  final MessageAttachment attachment;
  final ValueChanged<MessageAttachment>? onDownload;
  final double imageExtent;
  final bool animateImages;

  @override
  Widget build(BuildContext context) {
    if (attachment.isImage) {
      return _ImageAttachmentTile(
        state: state,
        attachment: attachment,
        imageExtent: imageExtent,
        animateImages: animateImages,
      );
    }

    final card = Container(
      width: 190,
      height: 54,
      decoration: BoxDecoration(
        color: state.text(context).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: state.text(context).withValues(alpha: 0.07)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
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
                  style: state.textStyle(context, size: 10, opacity: 0.45),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );

    return Stack(
      children: [
        card,
        if (onDownload != null && !attachment.isImage)
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
    );
  }
}

class _ImageAttachmentTile extends StatelessWidget {
  const _ImageAttachmentTile({
    required this.state,
    required this.attachment,
    required this.imageExtent,
    required this.animateImages,
  });

  final WeaviewState state;
  final MessageAttachment attachment;
  final double imageExtent;
  final bool animateImages;

  @override
  Widget build(BuildContext context) {
    final knownSize = attachment.hasPixelSize
        ? Size(
            attachment.pixelWidth!.toDouble(),
            attachment.pixelHeight!.toDouble(),
          )
        : null;
    return FutureBuilder<Size>(
      initialData: knownSize,
      future: knownSize == null ? _readImageSize(attachment.path) : null,
      builder: (context, snapshot) {
        final ratio = snapshot.data == null
            ? 1.0
            : (snapshot.data!.width / snapshot.data!.height).clamp(0.62, 1.7);
        final height = imageExtent;
        final width = height * ratio;
        final radius = BorderRadius.circular(22);
        final card = Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: state.text(context).withValues(alpha: 0.06),
            borderRadius: radius,
            border: Border.all(
              color: state.text(context).withValues(alpha: 0.07),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: _AttachmentVisual(
            attachment: attachment,
            animate: animateImages,
          ),
        );
        return Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: Tooltip(
            message: '预览图片',
            child: Semantics(
              button: true,
              label: '预览图片 ${attachment.name}',
              child: InkWell(
                borderRadius: radius,
                onTap: () => _openImagePreview(
                  context,
                  state,
                  attachments: [attachment],
                  initialIndex: 0,
                ),
                child: card,
              ),
            ),
          ),
        );
      },
    );
  }
}

final _imageSizeCache = _ImageSizeCache(maxEntries: 64);

Future<Size> _readImageSize(String path) => _imageSizeCache.read(path);

class _ImageSizeCache {
  _ImageSizeCache({required this.maxEntries});

  final int maxEntries;
  final LinkedHashMap<String, Future<Size>> _entries = LinkedHashMap();

  Future<Size> read(String path) {
    final cached = _entries.remove(path);
    if (cached != null) {
      _entries[path] = cached;
      return cached;
    }
    final future = _readDescriptorSize(path);
    _entries[path] = future;
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
    return future;
  }

  Future<Size> _readDescriptorSize(String path) async {
    final buffer = await ui.ImmutableBuffer.fromFilePath(path);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        return Size(descriptor.width.toDouble(), descriptor.height.toDouble());
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
  }
}

void _openImagePreview(
  BuildContext context,
  WeaviewState state, {
  required List<MessageAttachment> attachments,
  int initialIndex = 0,
  ValueChanged<MessageAttachment>? onDownload,
}) {
  final images = attachments
      .where(
        (attachment) =>
            attachment.isImage && File(attachment.path).existsSync(),
      )
      .toList();
  if (images.isEmpty) return;
  final rootContext = context;
  FocusManager.instance.primaryFocus?.unfocus(
    disposition: UnfocusDisposition.scope,
  );
  SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.82),
    builder: (context) {
      return Dialog.fullscreen(
        backgroundColor: const Color(0xFF101A27),
        child: _ImagePreviewCarousel(
          rootContext: rootContext,
          state: state,
          attachments: images,
          initialIndex: initialIndex.clamp(0, images.length - 1),
          onDownload: onDownload,
        ),
      );
    },
  ).whenComplete(() {
    FocusManager.instance.primaryFocus?.unfocus(
      disposition: UnfocusDisposition.scope,
    );
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  });
}

class _ImagePreviewCarousel extends StatefulWidget {
  const _ImagePreviewCarousel({
    required this.rootContext,
    required this.state,
    required this.attachments,
    required this.initialIndex,
    this.onDownload,
  });

  final BuildContext rootContext;
  final WeaviewState state;
  final List<MessageAttachment> attachments;
  final int initialIndex;
  final ValueChanged<MessageAttachment>? onDownload;

  @override
  State<_ImagePreviewCarousel> createState() => _ImagePreviewCarouselState();
}

class _ImagePreviewCarouselState extends State<_ImagePreviewCarousel> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _currentIndex = widget.initialIndex;

  MessageAttachment get _currentAttachment => widget.attachments[_currentIndex];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            bottom: widget.attachments.length > 1 ? 104 : 58,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.attachments.length,
              onPageChanged: (value) => setState(() => _currentIndex = value),
              itemBuilder: (context, index) {
                final attachment = widget.attachments[index];
                return Semantics(
                  label:
                      '图片预览 ${index + 1} / ${widget.attachments.length}：${attachment.name}',
                  hint: '支持缩放。更多操作在右上角菜单。',
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onLongPress: () => _showImagePreviewActions(
                      widget.rootContext,
                      context,
                      widget.state,
                      attachment,
                    ),
                    child: InteractiveViewer(
                      minScale: 0.7,
                      maxScale: 4,
                      child: Center(
                        child: Image.file(
                          File(attachment.path),
                          fit: BoxFit.contain,
                          cacheWidth: previewDecodeWidth(context),
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                IconButton.filledTonal(
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: '关闭预览',
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.36),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.attachments.length}',
                    style: widget.state
                        .textStyle(context, size: 12, weight: FontWeight.w700)
                        .copyWith(color: Colors.white),
                  ),
                ),
                if (widget.onDownload != null) ...[
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    onPressed: () => widget.onDownload!(_currentAttachment),
                    tooltip: '下载图片',
                    icon: const Icon(Icons.download_rounded),
                  ),
                ],
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: () => _showImagePreviewActions(
                    widget.rootContext,
                    context,
                    widget.state,
                    _currentAttachment,
                  ),
                  tooltip: '更多图片操作',
                  icon: const Icon(Icons.more_horiz_rounded),
                ),
              ],
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: widget.attachments.length > 1 ? 82 : 18,
            child: Text(
              _currentAttachment.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: widget.state
                  .textStyle(context, size: 12, weight: FontWeight.w600)
                  .copyWith(color: Colors.white70),
            ),
          ),
          if (widget.attachments.length > 1)
            Positioned(
              left: 18,
              right: 18,
              bottom: 14,
              height: 58,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: widget.attachments.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final selected = index == _currentIndex;
                  final attachment = widget.attachments[index];
                  return Semantics(
                    button: true,
                    selected: selected,
                    label: '查看图片 ${index + 1}',
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _controller.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 58,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.white.withValues(alpha: 0.18),
                              width: selected ? 2 : 1,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.file(
                            File(attachment.path),
                            fit: BoxFit.cover,
                            cacheWidth: 180,
                            filterQuality: FilterQuality.low,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _AttachmentVisual extends StatelessWidget {
  const _AttachmentVisual({required this.attachment, required this.animate});

  final MessageAttachment attachment;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    if (attachment.isImage && File(attachment.path).existsSync()) {
      final image = Image.file(
        File(attachment.path),
        fit: BoxFit.cover,
        cacheWidth: thumbnailDecodeWidth(context),
        filterQuality: FilterQuality.medium,
      );
      if (!animate) return image;
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.scale(scale: 0.96 + value * 0.04, child: child),
          );
        },
        child: image,
      );
    }
    return const Center(child: Icon(Icons.description_outlined, size: 24));
  }
}

Future<void> _showImagePreviewActions(
  BuildContext rootContext,
  BuildContext sheetContext,
  WeaviewState state,
  MessageAttachment attachment,
) async {
  FocusManager.instance.primaryFocus?.unfocus(
    disposition: UnfocusDisposition.scope,
  );
  SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  final action = await showModalBottomSheet<String>(
    context: sheetContext,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final dark = state.isDark(context);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: state.layer(context).withValues(alpha: dark ? 0.92 : 0.96),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: state.text(context).withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.30 : 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text(
                    '保存到手机相册',
                    style: state.textStyle(
                      context,
                      size: 14,
                      weight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '长按图片即可打开此菜单',
                    style: state.textStyle(context, size: 11.5, opacity: 0.48),
                  ),
                  onTap: () => Navigator.of(context).pop('save'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  if (action == 'save' && rootContext.mounted) {
    await _saveImageToGallery(rootContext, attachment);
  }
}

Future<void> _saveImageToGallery(
  BuildContext context,
  MessageAttachment attachment,
) async {
  try {
    final savedPath = await _nativeMedia
        .invokeMethod<String>('saveImageToGallery', {
          'path': attachment.path,
          'name': attachment.name,
          'mimeType': attachment.mimeType,
        });
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          savedPath == null || savedPath.isEmpty
              ? '已保存到手机相册'
              : '已保存到手机相册：$savedPath',
        ),
      ),
    );
  } on PlatformException catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(error.message ?? '保存图片失败')));
  } on MissingPluginException {
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(const SnackBar(content: Text('当前平台暂不支持直接保存到相册')));
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
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          child: Row(
            children: [
              BrandIcon.model(
                model: item.model,
                provider: item.provider,
                size: 30,
                radius: 11,
                padding: 5,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.model.name,
                      overflow: TextOverflow.ellipsis,
                      style: state.textStyle(
                        context,
                        size: 13,
                        weight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.provider.name,
                      overflow: TextOverflow.ellipsis,
                      style: state
                          .textStyle(
                            context,
                            size: 9.5,
                            weight: FontWeight.w600,
                            opacity: 0.4,
                          )
                          .copyWith(letterSpacing: 1.1),
                    ),
                    const SizedBox(height: 4),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: ModelCapabilityChips(
                        state: state,
                        capabilities: item.model.capabilities,
                        compact: true,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: state.accents[0],
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
    this.onLongPress,
  });

  final WeaviewState state;
  final ChatSession session;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<BuildContext>? onLongPress;

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
          onLongPress: onLongPress == null ? null : () => onLongPress!(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: Row(
              children: [
                if (session.pinned) ...[
                  Icon(
                    Icons.push_pin_rounded,
                    size: 14,
                    color: state.accents[0].withValues(alpha: 0.72),
                  ),
                  const SizedBox(width: 7),
                ],
                Expanded(
                  child: Text(
                    session.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: state.textStyle(
                      context,
                      size: 14,
                      weight: selected ? FontWeight.w600 : FontWeight.w400,
                      opacity: selected ? 1 : 0.7,
                      height: 1.22,
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
