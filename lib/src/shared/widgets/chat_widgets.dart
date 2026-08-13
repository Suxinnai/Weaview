// ignore_for_file: use_key_in_widget_constructors

import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;
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
                  child: const SizedBox.square(
                    dimension: 44,
                    child: Center(
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
  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final images = widget.attachments
        .where((attachment) => attachment.isImage)
        .toList();
    if (images.isEmpty) {
      return const SizedBox.shrink();
    }
    final single = images.length == 1;
    if (single) {
      return Align(
        key: const ValueKey('generated-image-gallery'),
        alignment: Alignment.centerLeft,
        child: _GeneratedSingleImageCard(
          state: state,
          attachment: images.first,
          animateImages: widget.animateImages,
          onTap: () => _openImagePreview(
            context,
            state,
            attachments: images,
            initialIndex: 0,
            onDownload: widget.onDownload,
          ),
        ),
      );
    }
    return _StackedPhotoCard(
      key: const ValueKey('generated-image-gallery'),
      state: state,
      images: images,
      onTapImage: (index) => _openImagePreview(
        context,
        state,
        attachments: images,
        initialIndex: index,
        onDownload: widget.onDownload,
      ),
    );
  }
}

class _GeneratedSingleImageCard extends StatelessWidget {
  const _GeneratedSingleImageCard({
    required this.state,
    required this.attachment,
    required this.animateImages,
    required this.onTap,
  });

  final WeaviewState state;
  final MessageAttachment attachment;
  final bool animateImages;
  final VoidCallback onTap;

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
            : (snapshot.data!.width / snapshot.data!.height).clamp(0.62, 1.9);
        return LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width - 72;
            const maxHeight = 320.0;
            final maxWidth = math.min(availableWidth, 320.0);
            var width = maxWidth;
            var height = width / ratio;
            if (height > maxHeight) {
              height = maxHeight;
              width = height * ratio;
            }
            final radius = BorderRadius.circular(18);
            return Material(
              color: Colors.transparent,
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: Semantics(
                button: true,
                label: '查看生成图片 ${attachment.name}',
                child: InkWell(
                  onTap: onTap,
                  child: Ink(
                    key: const ValueKey('generated-image-single'),
                    width: width,
                    height: height,
                    decoration: BoxDecoration(
                      color: state.text(context).withValues(alpha: 0.05),
                      borderRadius: radius,
                      border: Border.all(
                        color: state.text(context).withValues(alpha: 0.09),
                      ),
                    ),
                    child: _AttachmentVisual(
                      attachment: attachment,
                      animate: animateImages,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StackedPhotoCard extends StatefulWidget {
  const _StackedPhotoCard({
    super.key,
    required this.state,
    required this.images,
    required this.onTapImage,
  });

  final WeaviewState state;
  final List<MessageAttachment> images;
  final ValueChanged<int> onTapImage;

  @override
  State<_StackedPhotoCard> createState() => _StackedPhotoCardState();
}

class _StackedPhotoCardState extends State<_StackedPhotoCard>
    with SingleTickerProviderStateMixin {
  static const double _cardWidth = 212;
  static const double _fallbackAspectRatio = 0.84;
  static const double _peek = 15;
  static const double _peekStep = 11;
  static const double _rotStep = 2.2;
  static const double _scaleStep = 0.065;
  static const double _edgeBounce = 24;
  static const double _flingVelocity = 400;

  int _index = 0;
  double _drag = 0;
  double _velocity = 0;
  bool _dragging = false;
  int _flipDirection = 0;
  DateTime? _lastDragUpdate;
  Animation<double>? _snapBack;
  late final AnimationController _controller;

  List<MessageAttachment> get _images => widget.images;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 320),
          )
          ..addListener(() {
            final snapBack = _snapBack;
            if (_flipDirection == 0 && snapBack != null) {
              _drag = snapBack.value;
            }
            setState(() {});
          })
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              setState(() {
                if (_flipDirection != 0) {
                  _index = (_index + _flipDirection).clamp(
                    0,
                    _images.length - 1,
                  );
                }
                _drag = 0;
                _flipDirection = 0;
                _snapBack = null;
              });
              _controller.reset();
            }
          });
  }

  @override
  void didUpdateWidget(covariant _StackedPhotoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= _images.length) {
      _controller.stop();
      _controller.reset();
      _index = math.max(0, _images.length - 1);
      _drag = 0;
      _flipDirection = 0;
      _snapBack = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _aspectRatio {
    if (_images.isEmpty) return _fallbackAspectRatio;
    final first = _images.first;
    if (!first.hasPixelSize) return _fallbackAspectRatio;
    return (first.pixelWidth! / first.pixelHeight!).clamp(0.72, 1.7);
  }

  void _handleDragStart(DragStartDetails details) {
    if (_controller.isAnimating) return;
    _dragging = true;
    _velocity = 0;
    _lastDragUpdate = null;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    final now = DateTime.now();
    final last = _lastDragUpdate;
    if (last != null) {
      final dt = now.difference(last).inMicroseconds / 1e6;
      if (dt > 0) {
        final instantaneous = details.delta.dx / dt;
        _velocity = instantaneous * 0.7 + _velocity * 0.3;
      }
    }
    _lastDragUpdate = now;
    var next = _drag + details.delta.dx;
    final atStart = _index == 0 && next > 0;
    final atEnd = _index == _images.length - 1 && next < 0;
    if (atStart || atEnd) {
      next = next.clamp(-_edgeBounce, _edgeBounce);
    }
    setState(() => _drag = next);
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    _velocity = details.primaryVelocity ?? _velocity;
    final atStart = _index == 0 && _drag > 0;
    final atEnd = _index == _images.length - 1 && _drag < 0;
    if (atStart || atEnd) {
      _animateBack();
      return;
    }
    final fling =
        _velocity.abs() > _flingVelocity &&
        (_velocity > 0) == (_drag > 0) &&
        _drag.abs() > 10;
    final threshold = _drag.abs() > _cardWidth * 0.28;
    if ((fling || threshold) && _drag != 0) {
      _startFlip(_drag > 0 ? -1 : 1);
    } else {
      _animateBack();
    }
  }

  void _handleDragCancel() {
    if (!_dragging) return;
    _dragging = false;
    _animateBack();
  }

  void _startFlip(int direction) {
    final target = _index + direction;
    if (_controller.isAnimating || target < 0 || target >= _images.length) {
      _animateBack();
      return;
    }
    _flipDirection = direction;
    _snapBack = null;
    _controller.duration = const Duration(milliseconds: 320);
    _controller.forward(from: 0);
  }

  void _animateBack() {
    if (_drag == 0) return;
    _controller.stop();
    _flipDirection = 0;
    _controller.duration = const Duration(milliseconds: 220);
    _snapBack = Tween<double>(
      begin: _drag,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward(from: 0);
  }

  Widget _card(MessageAttachment attachment, int cacheWidth, double radius) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.file(
        File(attachment.path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: cacheWidth,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => Container(
          color: const Color(0xFF2A3442),
          alignment: Alignment.center,
          child: Icon(
            Icons.broken_image_outlined,
            size: 28,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _images.length;
    final flipping = _flipDirection != 0;
    final dir = _flipDirection;
    final p = flipping ? _controller.value : 0.0;
    final rightPeek = _peek + _peekStep;
    final rightPeek2 = _peek + _peekStep * 2;

    final slots =
        <
          ({
            MessageAttachment image,
            double dx,
            double rot,
            double scale,
            int z,
          })
        >[];
    void add(int index, double dx, double rot, double scale, int z) {
      if (index < 0 || index >= count) return;
      slots.add((image: _images[index], dx: dx, rot: rot, scale: scale, z: z));
    }

    if (!flipping) {
      final i = _index;
      add(i + 1, rightPeek, _rotStep, 1 - _scaleStep, 2);
      if (i == 0) {
        add(i + 2, rightPeek2, _rotStep * 2, 1 - _scaleStep * 2, 1);
      }
      add(i - 1, -rightPeek, -_rotStep, 1 - _scaleStep, 2);
      if (i == count - 1) {
        add(i - 2, -rightPeek2, -_rotStep * 2, 1 - _scaleStep * 2, 1);
      }
      add(i, _drag, _drag * 0.045, 1, 4);
    } else {
      final swipeSign = -dir.toDouble();
      final peak = _cardWidth * 0.58;
      final frontPhase = p < 0.55 ? p / 0.55 : 1.0;
      final settle = p < 0.55 ? 0.0 : (p - 0.55) / 0.45;
      final frontDx = p < 0.55
          ? _lerp(
              _drag,
              swipeSign * peak,
              Curves.easeOutCubic.transform(frontPhase),
            )
          : _lerp(
              swipeSign * peak,
              -dir * rightPeek,
              Curves.easeInOutCubic.transform(settle),
            );
      final frontRotation = p < 0.55
          ? _lerp(
              _drag * 0.045,
              swipeSign * 4.2,
              Curves.easeOutCubic.transform(frontPhase),
            )
          : _lerp(
              swipeSign * 4.2,
              -dir * _rotStep,
              Curves.easeInOutCubic.transform(settle),
            );
      final frontScale = p < 0.55
          ? _lerp(1, 0.94, Curves.easeOutCubic.transform(frontPhase))
          : _lerp(
              0.94,
              1 - _scaleStep,
              Curves.easeInOutCubic.transform(settle),
            );
      final pastPeak = p >= 0.55;
      add(_index, frontDx, frontRotation, frontScale, pastPeak ? 2 : 4);
      add(
        _index + dir,
        _lerp(dir * rightPeek, 0, Curves.easeInOutCubic.transform(p)),
        _lerp(dir * _rotStep, 0, Curves.easeInOutCubic.transform(p)),
        _lerp(1 - _scaleStep, 1, Curves.easeInOutCubic.transform(p)),
        pastPeak ? 4 : 3,
      );
      add(
        _index + 2 * dir,
        _lerp(dir * rightPeek2, dir * rightPeek, p),
        _lerp(dir * _rotStep * 2, dir * _rotStep, p),
        _lerp(1 - _scaleStep * 2, 1 - _scaleStep, p),
        1,
      );
      add(
        _index - dir,
        _lerp(-dir * rightPeek, -dir * rightPeek2, p),
        _lerp(-dir * _rotStep, -dir * _rotStep * 2, p),
        _lerp(1 - _scaleStep, 1 - _scaleStep * 2, p),
        1,
      );
    }
    slots.sort((a, b) => a.z.compareTo(b.z));

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 72;
        const leadingInset = 0.0;
        final trailingInset = rightPeek2 + 12;
        final width = math.min(
          _cardWidth,
          math.max(1.0, available - leadingInset - trailingInset),
        );
        final height = width / _aspectRatio;
        final stageWidth = width + leadingInset + trailingInset;
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            key: const ValueKey('generated-image-stack-stage'),
            width: stageWidth,
            height: height + 28,
            child: Semantics(
              container: true,
              button: true,
              label: '生成的图片，共 $count 张',
              value: '第 ${_index + 1} 张',
              increasedValue: _index < count - 1 ? '第 ${_index + 2} 张' : null,
              decreasedValue: _index > 0 ? '第 $_index 张' : null,
              hint: '左右滑动切换，轻触查看大图',
              onTap: () => widget.onTapImage(_index),
              onIncrease: _index < count - 1 ? () => _startFlip(1) : null,
              onDecrease: _index > 0 ? () => _startFlip(-1) : null,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onTapImage(_index),
                onHorizontalDragStart: _handleDragStart,
                onHorizontalDragUpdate: _handleDragUpdate,
                onHorizontalDragEnd: _handleDragEnd,
                onHorizontalDragCancel: _handleDragCancel,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final slot in slots)
                      Positioned(
                        left: leadingInset,
                        top: 4,
                        width: width,
                        height: height,
                        child: Transform.translate(
                          offset: Offset(slot.dx, 0),
                          child: Transform.rotate(
                            angle: slot.rot * math.pi / 180,
                            child: Transform.scale(
                              scale: slot.scale,
                              child: slot.z == 4
                                  ? Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.34,
                                          ),
                                          width: 1.2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.16,
                                            ),
                                            blurRadius: 18,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: _card(slot.image, 440, 18),
                                    )
                                  : Opacity(
                                      opacity: slot.z == 1 ? 0.72 : 0.9,
                                      child: _card(slot.image, 260, 16),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: trailingInset + 10,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.46),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${_index + 1}/$count',
                          style: widget.state
                              .textStyle(
                                context,
                                size: 11,
                                weight: FontWeight.w700,
                              )
                              .copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
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
            right: 0,
            top: 5,
            child: Semantics(
              button: true,
              label: '下载附件 ${attachment.name}',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onDownload!(attachment),
                child: SizedBox.square(
                  dimension: 44,
                  child: Center(
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
    final text = state.text(context);
    return AnimatedContainer(
      key: ValueKey('model_picker_item_${item.provider.name}_${item.model.id}'),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        gradient: selected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  state.accents[0].withValues(alpha: 0.18),
                  state.accents[1].withValues(alpha: 0.075),
                ],
              )
            : null,
        color: selected ? null : text.withValues(alpha: 0.018),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? state.accents[0].withValues(alpha: 0.28)
              : text.withValues(alpha: 0.035),
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: state.accents[0].withValues(alpha: 0.09),
                  blurRadius: 18,
                  spreadRadius: -8,
                  offset: const Offset(0, 7),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(11, 9, 10, 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                BrandIcon.model(
                  model: item.model,
                  provider: item.provider,
                  size: 36,
                  radius: 13,
                  padding: 6,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.model.name,
                        overflow: TextOverflow.ellipsis,
                        style: state.textStyle(
                          context,
                          size: 13.2,
                          weight: selected ? FontWeight.w700 : FontWeight.w500,
                          opacity: selected ? 0.98 : 0.82,
                        ),
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
                if (selected) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: state.accents[0].withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: state.accents[0].withValues(alpha: 0.24),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_rounded,
                          size: 12,
                          color: state.accents[0],
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '当前',
                          style: state
                              .textStyle(
                                context,
                                size: 9,
                                weight: FontWeight.w700,
                              )
                              .copyWith(color: state.accents[0]),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
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
