// ignore_for_file: use_key_in_widget_constructors

import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/app_constants.dart';
import '../../app/weaview_state.dart';
import '../../core/app_utils.dart';

class AmbientBlob extends StatelessWidget {
  const AmbientBlob({
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

class ThemeRipple extends StatefulWidget {
  const ThemeRipple({super.key, required this.color});

  final Color color;

  @override
  State<ThemeRipple> createState() => _ThemeRippleState();
}

class _ThemeRippleState extends State<ThemeRipple>
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

class IconCircleButton extends StatelessWidget {
  const IconCircleButton({
    super.key,
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

class GlassPanel extends StatelessWidget {
  const GlassPanel({
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
        filter: ImageFilter.blur(sigmaX: 38, sigmaY: 38),
        child: Container(
          decoration: BoxDecoration(
            color: state
                .layer(context)
                .withValues(alpha: state.isDark(context) ? 0.68 : 0.78),
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

class AvatarDot extends StatelessWidget {
  const AvatarDot({
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
            colors: [accent.withValues(alpha: 0.5), accentGreen],
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
        gradient: const LinearGradient(colors: [accentMint, accentGreen]),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.85), blurRadius: 10),
        ],
      ),
    );
  }
}
