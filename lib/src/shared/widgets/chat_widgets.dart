// ignore_for_file: use_key_in_widget_constructors

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
          streaming ? streamingLabel : idleLabel,
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
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final WeaviewState state;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? state.accents[0].withValues(alpha: 0.16)
          : state.text(context).withValues(alpha: 0.055),
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
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 230),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: state.layer(context).withValues(alpha: dark ? 0.22 : 0.34),
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
    return FutureBuilder<Size>(
      future: _readImageSize(attachment.path),
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
          child: InkWell(
            borderRadius: radius,
            onTap: () => _openImagePreview(context, state, attachment),
            child: card,
          ),
        );
      },
    );
  }
}

Future<Size> _readImageSize(String path) async {
  final bytes = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  return Size(image.width.toDouble(), image.height.toDouble());
}

void _openImagePreview(
  BuildContext context,
  WeaviewState state,
  MessageAttachment attachment,
) {
  final file = File(attachment.path);
  if (!attachment.isImage || !file.existsSync()) return;
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
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onLongPress: () => _showImagePreviewActions(
                    rootContext,
                    context,
                    state,
                    attachment,
                  ),
                  child: InteractiveViewer(
                    minScale: 0.7,
                    maxScale: 4,
                    child: Center(
                      child: Image.file(
                        file,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: Text(
                  attachment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: state
                      .textStyle(context, size: 12, weight: FontWeight.w600)
                      .copyWith(color: Colors.white70),
                ),
              ),
            ],
          ),
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

class _AttachmentVisual extends StatelessWidget {
  const _AttachmentVisual({required this.attachment, required this.animate});

  final MessageAttachment attachment;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    if (attachment.isImage && File(attachment.path).existsSync()) {
      final image = Image.file(File(attachment.path), fit: BoxFit.cover);
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
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          child: Row(
            children: [
              BrandIcon.model(
                model: item.model,
                provider: item.provider,
                size: 34,
                radius: 12,
                padding: 6,
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
                        size: 14,
                        weight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.provider.name,
                      overflow: TextOverflow.ellipsis,
                      style: state
                          .textStyle(
                            context,
                            size: 10,
                            weight: FontWeight.w600,
                            opacity: 0.4,
                          )
                          .copyWith(letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 6),
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
