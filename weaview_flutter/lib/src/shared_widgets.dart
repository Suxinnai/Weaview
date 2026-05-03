part of '../main.dart';

class _AmbientBlob extends StatelessWidget {
  const _AmbientBlob({
    required this.alignment,
    required this.color,
    required this.size,
    required this.opacity,
  });

  final Alignment alignment;
  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: RepaintBoundary(
        child: Transform.translate(
          offset: Offset(
            alignment.x < 0 ? -size * 0.28 : size * 0.16,
            alignment.y < 0 ? -size * 0.28 : size * 0.16,
          ),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    color.withValues(alpha: opacity),
                    color.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeRipple extends StatefulWidget {
  const _ThemeRipple({super.key, required this.color});

  final Color color;

  @override
  State<_ThemeRipple> createState() => _ThemeRippleState();
}

class _ThemeRippleState extends State<_ThemeRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    )..forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context).longestSide;
    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final value = Curves.easeOutCubic.transform(controller.value);
            return Opacity(
              opacity: (1 - value) * 0.28,
              child: Transform.scale(
                scale: 0.2 + value * 2.8,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  const _IconCircleButton({
    required this.icon,
    required this.onTap,
    required this.color,
    this.background,
    this.size = 40,
    this.opacity = 0.62,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final Color? background;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background ?? Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: size * 0.52,
            color: color.withValues(alpha: opacity),
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.enabled,
    required this.onTap,
    required this.state,
  });

  final bool enabled;
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
              ? _sendGreen
              : state.text(context).withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(999),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: _sendGreen.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          '编织',
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

class _ToolChip extends StatelessWidget {
  const _ToolChip({
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

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
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

class _AttachmentPreviewStrip extends StatelessWidget {
  const _AttachmentPreviewStrip({
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
                      _formatBytes(attachment.size ?? 0),
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

class _MessageAttachmentGrid extends StatelessWidget {
  const _MessageAttachmentGrid({
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
                                  _formatBytes(attachment.size ?? 0),
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

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.state,
    required this.child,
    this.radius = 24,
  });

  final WeaviewState state;
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: (state.isDark(context) ? _layerDark : Colors.white)
                .withValues(alpha: state.isDark(context) ? 0.9 : 0.94),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: state.text(context).withValues(alpha: 0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: state.isDark(context) ? 0.3 : 0.12,
                ),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ModelDropdownItem extends StatelessWidget {
  const _ModelDropdownItem({
    required this.state,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final WeaviewState state;
  final _ProviderModel item;
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

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
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

class _AvatarDot extends StatelessWidget {
  const _AvatarDot({
    required this.value,
    required this.accent,
    this.fallbackIcon,
    this.imageSize = 28,
  });

  final String value;
  final Color accent;
  final IconData? fallbackIcon;
  final double imageSize;

  @override
  Widget build(BuildContext context) {
    final image = avatarImage(value);
    if (image != null) {
      return Container(
        width: imageSize,
        height: imageSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: accent.withValues(alpha: 0.35)),
          image: DecorationImage(image: image, fit: BoxFit.cover),
        ),
      );
    }
    if (fallbackIcon != null) {
      return Container(
        width: imageSize,
        height: imageSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [accent.withValues(alpha: 0.5), _accentGreen],
          ),
        ),
        child: Icon(
          fallbackIcon,
          size: imageSize * 0.48,
          color: Colors.white.withValues(alpha: 0.78),
        ),
      );
    }
    return Container(
      width: imageSize,
      height: imageSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [_accentMint, _accentGreen]),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.85), blurRadius: 10),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.state, required this.label, this.icon});

  final WeaviewState state;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 15,
              color: state.text(context).withValues(alpha: 0.42),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: state
                .textStyle(
                  context,
                  size: 12,
                  weight: FontWeight.w800,
                  opacity: 0.42,
                )
                .copyWith(letterSpacing: 1.7),
          ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.state,
    required this.child,
    this.padding,
    this.borderColor,
  });

  final WeaviewState state;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: state.isDark(context)
            ? Colors.white.withValues(alpha: 0.055)
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: borderColor ?? state.text(context).withValues(alpha: 0.06),
        ),
      ),
      child: child,
    );
  }
}

class _SettingsActionBar extends StatelessWidget {
  const _SettingsActionBar({
    required this.state,
    required this.child,
    this.status,
  });

  final WeaviewState state;
  final Widget child;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: state.isDark(context) ? _baseDark : const Color(0xFFF8F9FA),
        border: Border(
          top: BorderSide(color: state.text(context).withValues(alpha: 0.06)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: state.isDark(context) ? 0.2 : 0.06,
            ),
            blurRadius: 22,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 10, 18, 12 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status != null && status!.isNotEmpty) ...[
              Text(
                status!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: state.textStyle(context, size: 12, opacity: 0.66),
              ),
              const SizedBox(height: 8),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.state,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.showChevron = false,
    this.onTap,
  });

  final WeaviewState state;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: state.textStyle(
                    context,
                    size: 15,
                    weight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: state.textStyle(context, size: 12, opacity: 0.5),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
          if (showChevron)
            Icon(
              Icons.chevron_right_rounded,
              color: state.text(context).withValues(alpha: 0.35),
            ),
        ],
      ),
    );
    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

class _DividerLine extends StatelessWidget {
  const _DividerLine({required this.state});

  final WeaviewState state;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: state.text(context).withValues(alpha: 0.055),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.state,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final WeaviewState state;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? state.text(context).withValues(alpha: 0.065)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 25,
                color: state
                    .text(context)
                    .withValues(alpha: selected ? 0.92 : 0.58),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: state.textStyle(
                  context,
                  size: 12,
                  weight: FontWeight.w600,
                  opacity: selected ? 0.92 : 0.58,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeaveSwitch extends StatelessWidget {
  const _WeaveSwitch({
    required this.state,
    required this.value,
    required this.onChanged,
  });

  final WeaviewState state;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 48,
        height: 26,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value
              ? _sendGreen
              : state.text(context).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
        ),
      ),
    );
  }
}

class _TinyIcon extends StatelessWidget {
  const _TinyIcon({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: color.withValues(alpha: 0.68)),
    );
  }
}

class _ModelBadge extends StatelessWidget {
  const _ModelBadge({
    required this.state,
    required this.label,
    required this.active,
  });

  final WeaviewState state;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 122),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? _sendGreen.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: active
              ? null
              : Border.all(color: state.text(context).withValues(alpha: 0.12)),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: state
              .textStyle(
                context,
                size: 12.5,
                weight: FontWeight.w600,
                opacity: active ? 1 : 0.42,
              )
              .copyWith(color: active ? _sendGreen : null),
        ),
      ),
    );
  }
}

class _SoftButton extends StatelessWidget {
  const _SoftButton({
    required this.state,
    required this.label,
    required this.onTap,
    this.icon,
    this.accent = false,
    this.danger = false,
  });

  final WeaviewState state;
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool accent;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? Colors.red.withValues(alpha: 0.11)
        : accent
        ? state.accents[0]
        : state.text(context).withValues(alpha: 0.06);
    final fg = danger
        ? Colors.red
        : accent
        ? Colors.white
        : state.text(context);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: state
                      .textStyle(context, size: 14, weight: FontWeight.w600)
                      .copyWith(color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentedPills extends StatelessWidget {
  const _SegmentedPills({
    required this.state,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final WeaviewState state;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: state.text(context).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (final item in items.entries)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(item.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == item.key
                        ? (state.isDark(context) ? _layerDark : Colors.white)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item.value,
                    style: state.textStyle(
                      context,
                      size: 13,
                      weight: FontWeight.w600,
                      opacity: value == item.key ? 1 : 0.58,
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

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.state,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  final WeaviewState state;
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final safeItems = items.isEmpty ? ['未选择'] : items.toSet().toList();
    final safeValue = safeItems.contains(value) ? value : safeItems.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: state.textStyle(context, size: 14, opacity: 0.6)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: safeValue,
          items: safeItems
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(item, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: enabled ? (value) => onChanged(value ?? safeValue) : null,
          decoration: _inputDecoration(state),
        ),
      ],
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.active, required this.color});

  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? color : Colors.grey.withValues(alpha: 0.45),
          width: 2,
        ),
      ),
      child: active
          ? DecoratedBox(
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            )
          : null,
    );
  }
}

class _StorageRow extends StatelessWidget {
  const _StorageRow({
    required this.state,
    required this.label,
    required this.color,
    required this.bytes,
  });

  final WeaviewState state;
  final String label;
  final Color color;
  final int bytes;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label, style: state.textStyle(context, size: 13, opacity: 0.82)),
          const Spacer(),
          Text(
            _formatBytes(bytes),
            style: state.textStyle(context, size: 13, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _AboutButton extends StatelessWidget {
  const _AboutButton({
    required this.state,
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  final WeaviewState state;
  final String label;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: 286,
        child: _SoftButton(
          state: state,
          label: label,
          accent: false,
          onTap: onTap,
        ),
      ),
    );
  }
}

class _ModelPickerDialog extends StatefulWidget {
  const _ModelPickerDialog({required this.state, required this.models});

  final WeaviewState state;
  final List<AiModel> models;

  @override
  State<_ModelPickerDialog> createState() => _ModelPickerDialogState();
}

class _ModelPickerDialogState extends State<_ModelPickerDialog> {
  final Set<String> selected = {};
  String query = '';

  @override
  Widget build(BuildContext context) {
    final models = widget.models.where((m) {
      final q = query.toLowerCase();
      return q.isEmpty ||
          m.id.toLowerCase().contains(q) ||
          m.name.toLowerCase().contains(q);
    }).toList();
    return AlertDialog(
      title: const Text('模型列表'),
      content: SizedBox(
        width: 360,
        height: 430,
        child: Column(
          children: [
            TextField(
              onChanged: (value) => setState(() => query = value),
              decoration: const InputDecoration(hintText: '搜索模型名称或ID...'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: models.length,
                itemBuilder: (context, index) {
                  final model = models[index];
                  return CheckboxListTile(
                    value: selected.contains(model.id),
                    title: Text(model.name, overflow: TextOverflow.ellipsis),
                    subtitle: Text(model.id, overflow: TextOverflow.ellipsis),
                    onChanged: (_) => setState(() {
                      selected.contains(model.id)
                          ? selected.remove(model.id)
                          : selected.add(model.id);
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            widget.models.where((m) => selected.contains(m.id)).toList(),
          ),
          child: const Text('确认添加'),
        ),
      ],
    );
  }
}

class _TestModelDialog extends StatelessWidget {
  const _TestModelDialog({required this.state, required this.models});

  final WeaviewState state;
  final List<AiModel> models;

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('选择测试模型'),
      children: [
        for (final model in models)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, model),
            child: Text(model.name),
          ),
      ],
    );
  }
}

class _EditModelDialog extends StatefulWidget {
  const _EditModelDialog({required this.state, required this.model});

  final WeaviewState state;
  final AiModel model;

  @override
  State<_EditModelDialog> createState() => _EditModelDialogState();
}

class _EditModelDialogState extends State<_EditModelDialog> {
  late TextEditingController name;
  late Set<String> caps;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.model.name);
    caps = widget.model.capabilities.toSet();
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const options = [
      ('vision', Icons.visibility_outlined, 'Vision (视觉处理)'),
      ('image', Icons.image_outlined, 'Image Output (图像生成)'),
      ('tool', Icons.build_outlined, 'Tool Calling (函数调用)'),
      ('reason', Icons.psychology_outlined, 'Reasoning (深度推理)'),
    ];
    return AlertDialog(
      title: const Text('编辑模型'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              readOnly: true,
              controller: TextEditingController(text: widget.model.id),
              decoration: const InputDecoration(labelText: '模型标识名 (ID)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: '显示名称'),
            ),
            const SizedBox(height: 16),
            for (final option in options)
              SwitchListTile(
                value: caps.contains(option.$1),
                secondary: Icon(option.$2),
                title: Text(option.$3),
                onChanged: (value) => setState(
                  () => value ? caps.add(option.$1) : caps.remove(option.$1),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            widget.model.copyWith(
              name: name.text.trim(),
              capabilities: caps.toList(),
            ),
          ),
          child: const Text('保存配置'),
        ),
      ],
    );
  }
}

InputDecoration _inputDecoration(WeaviewState state, {String? hint}) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.black.withValues(alpha: 0.045),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(17),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(17),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(17),
      borderSide: BorderSide(color: _accentMint.withValues(alpha: 0.55)),
    ),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
  );
}

ThemeMode _decodeThemeMode(String? value) {
  return switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

List<T> _decodeList<T>(String? value, T Function(dynamic) decoder) {
  if (value == null) return [];
  try {
    final decoded = jsonDecode(value);
    if (decoded is List) return decoded.map(decoder).toList();
    if (decoded is Map) return [decoder(decoded)];
    return [];
  } catch (_) {
    return [];
  }
}

extension FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T item) test) {
    for (final item in this) {
      if (test(item)) return item;
    }
    return null;
  }
}

Color? colorFromHex(String? value) {
  if (value == null || value.isEmpty) return null;
  final trimmed = value.trim();
  if (!trimmed.startsWith('#')) return null;
  final hex = trimmed.substring(1);
  if (hex.length != 6 && hex.length != 8) return null;
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) return null;
  return Color(hex.length == 6 ? 0xFF000000 | parsed : parsed);
}

String colorToHex(Color color) {
  final value = color.toARGB32() & 0xFFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

Color providerFallbackColor(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('gemini')) return const Color(0xFF3B82F6);
  if (lower.contains('openai')) return const Color(0xFF10B981);
  if (lower.contains('deepseek')) return const Color(0xFF2563EB);
  if (lower.contains('mini')) return const Color(0xFF8B5CF6);
  if (lower.contains('anthropic')) return const Color(0xFFB45309);
  return Colors.indigo;
}

ImageProvider? avatarImage(String value) {
  if (value.isEmpty) return null;
  if (value.startsWith('data:image')) {
    final comma = value.indexOf(',');
    if (comma < 0) return null;
    return MemoryImage(base64Decode(value.substring(comma + 1)));
  }
  final file = File(value);
  if (!file.existsSync()) return null;
  return FileImage(file);
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '${bytes}B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)}KB';
  return '${(kb / 1024).toStringAsFixed(1)}MB';
}
