// ignore_for_file: use_key_in_widget_constructors

import 'package:flutter/material.dart';

import '../../app/app_constants.dart';
import '../../app/weaview_state.dart';
import '../../core/app_utils.dart';
import '../../domain/models.dart';
import 'brand_icon.dart';
import 'model_capability_chips.dart';

const _settingsCornerRadius = 20.0;
const _settingsRowMinHeight = 72.0;
const _settingsControlHeight = 44.0;

Color _settingsBorderColor(WeaviewState state, BuildContext context) {
  return state.isDark(context)
      ? Colors.white.withValues(alpha: 0.08)
      : const Color(0xFFDEE5EF);
}

Color _settingsSurfaceColor(WeaviewState state, BuildContext context) {
  return state.isDark(context)
      ? Colors.white.withValues(alpha: 0.045)
      : Colors.white.withValues(alpha: 0.92);
}

class SectionLabel extends StatelessWidget {
  const SectionLabel({required this.state, required this.label, this.icon});

  final WeaviewState state;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: state.text(context).withValues(alpha: 0.48),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: state
                .poeticTextStyle(
                  context,
                  size: 15,
                  weight: FontWeight.w500,
                  opacity: 0.68,
                )
                .copyWith(height: 1.15, letterSpacing: 1.2),
          ),
        ],
      ),
    );
  }
}

class CardShell extends StatelessWidget {
  const CardShell({
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
        color: _settingsSurfaceColor(state, context),
        borderRadius: BorderRadius.circular(_settingsCornerRadius),
        border: Border.all(
          color: borderColor ?? _settingsBorderColor(state, context),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: state.isDark(context) ? 0.0 : 0.02,
            ),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class SettingsActionBar extends StatelessWidget {
  const SettingsActionBar({
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
        color: state.background(context),
        border: Border(
          top: BorderSide(color: _settingsBorderColor(state, context)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: state.isDark(context) ? 0.0 : 0.025,
            ),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(22, 12, 22, 12 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status != null && status!.isNotEmpty) ...[
              Text(
                status!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: state.textStyle(context, size: 12.5, opacity: 0.62),
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

class SettingsRow extends StatelessWidget {
  const SettingsRow({
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
    final resolvedLeading = leading is Icon
        ? _SettingsIconContainer(state: state, icon: leading as Icon)
        : leading;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _settingsRowMinHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            if (resolvedLeading != null) ...[
              resolvedLeading,
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: state.textStyle(
                      context,
                      size: 16,
                      weight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: state.textStyle(
                        context,
                        size: 12.5,
                        opacity: 0.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            if (showChevron) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: state.text(context).withValues(alpha: 0.32),
              ),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      enabled: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(_settingsCornerRadius - 2),
          onTap: onTap,
          child: row,
        ),
      ),
    );
  }
}

class _SettingsIconContainer extends StatelessWidget {
  const _SettingsIconContainer({required this.state, required this.icon});

  final WeaviewState state;
  final Icon icon;

  @override
  Widget build(BuildContext context) {
    final baseColor =
        icon.color ?? (state.isDark(context) ? accentMint : sendGreen);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: state.isDark(context) ? 0.16 : 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: baseColor.withValues(alpha: 0.14)),
      ),
      alignment: Alignment.center,
      child: Icon(icon.icon, size: icon.size ?? 19, color: baseColor),
    );
  }
}

class DividerLine extends StatelessWidget {
  const DividerLine({required this.state});

  final WeaviewState state;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 18,
      endIndent: 18,
      color: _settingsBorderColor(state, context),
    );
  }
}

class ThemeChoice extends StatefulWidget {
  const ThemeChoice({
    super.key,
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
  State<ThemeChoice> createState() => _ThemeChoiceState();
}

class _ThemeChoiceState extends State<ThemeChoice> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final selectedBackground = state.isDark(context)
        ? Colors.white.withValues(alpha: 0.10)
        : state.accents[0].withValues(alpha: 0.13);
    final selectedFg = state.isDark(context) ? accentMint : sendGreen;
    return Expanded(
      child: Semantics(
        button: true,
        selected: widget.selected,
        child: Listener(
          onPointerDown: (_) => setState(() => _pressed = true),
          onPointerUp: (_) => setState(() => _pressed = false),
          onPointerCancel: (_) => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.95 : 1,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOutCubic,
            child: GestureDetector(
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.selected
                      ? selectedBackground
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: widget.selected
                        ? state.accents[0].withValues(alpha: 0.26)
                        : Colors.transparent,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.icon,
                      size: 18,
                      color: widget.selected
                          ? selectedFg
                          : state.text(context).withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.label,
                      style: state.textStyle(
                        context,
                        size: 12,
                        weight: FontWeight.w600,
                        opacity: widget.selected ? 0.96 : 0.55,
                      ),
                    ),
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

class WeaveSwitch extends StatelessWidget {
  const WeaveSwitch({
    required this.state,
    required this.value,
    required this.onChanged,
  });

  final WeaviewState state;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final inactiveTrack = state.isDark(context)
        ? Colors.white.withValues(alpha: 0.16)
        : const Color(0xFFDCE3EE);
    return Semantics(
      button: true,
      enabled: true,
      toggled: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: SizedBox(
          width: 56,
          height: _settingsControlHeight,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 48,
              height: 30,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: value ? sendGreen : inactiveTrack,
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
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

class TinyIcon extends StatelessWidget {
  const TinyIcon({
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
      constraints: const BoxConstraints.tightFor(
        width: _settingsControlHeight,
        height: _settingsControlHeight,
      ),
      padding: EdgeInsets.zero,
      splashRadius: 22,
      onPressed: onTap,
      icon: Icon(icon, size: 20, color: color.withValues(alpha: 0.72)),
    );
  }
}

class ModelBadge extends StatelessWidget {
  const ModelBadge({
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
      constraints: const BoxConstraints(maxWidth: 168),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? state.accents[0].withValues(
                  alpha: state.isDark(context) ? 0.16 : 0.12,
                )
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? state.accents[0].withValues(alpha: 0.18)
                : _settingsBorderColor(state, context),
          ),
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
                opacity: active ? 0.96 : 0.56,
              )
              .copyWith(color: active ? sendGreen : null),
        ),
      ),
    );
  }
}

class SoftButton extends StatefulWidget {
  const SoftButton({
    super.key,
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
  State<SoftButton> createState() => _SoftButtonState();
}

class _SoftButtonState extends State<SoftButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final bg = widget.danger
        ? Colors.red.withValues(alpha: 0.09)
        : widget.accent
        ? state.accents[0]
        : state.isDark(context)
        ? Colors.white.withValues(alpha: 0.065)
        : Colors.white;
    final borderColor = widget.danger
        ? Colors.red.withValues(alpha: 0.18)
        : widget.accent
        ? Colors.transparent
        : _settingsBorderColor(state, context);
    final fg = widget.danger
        ? Colors.red
        : widget.accent
        ? Colors.white
        : state.text(context);
    return Semantics(
      button: true,
      enabled: true,
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.965 : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              enableFeedback: true,
              onTap: widget.onTap,
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                  boxShadow: widget.accent
                      ? [
                          BoxShadow(
                            color: state.accents[0].withValues(alpha: 0.16),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 18, color: fg),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: state
                              .textStyle(
                                context,
                                size: 14.5,
                                weight: FontWeight.w600,
                              )
                              .copyWith(color: fg),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SegmentedPills extends StatelessWidget {
  const SegmentedPills({
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
        color: state.isDark(context)
            ? Colors.white.withValues(alpha: 0.045)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _settingsBorderColor(state, context)),
      ),
      child: Row(
        children: [
          for (final item in items.entries)
            Expanded(
              child: Semantics(
                button: true,
                selected: value == item.key,
                child: GestureDetector(
                  onTap: () => onChanged(item.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    constraints: const BoxConstraints(minHeight: 48),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: value == item.key
                          ? state.accents[0].withValues(
                              alpha: state.isDark(context) ? 0.16 : 0.12,
                            )
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      item.value,
                      style: state.textStyle(
                        context,
                        size: 13.5,
                        weight: FontWeight.w600,
                        opacity: value == item.key ? 0.96 : 0.58,
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

class DropdownField extends StatelessWidget {
  const DropdownField({
    required this.state,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.itemDescriptions = const {},
    this.enabled = true,
  });

  final WeaviewState state;
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final Map<String, String> itemDescriptions;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final safeItems = items.isEmpty ? ['未选择'] : items.toSet().toList();
    final safeValue = safeItems.contains(value) ? value : safeItems.first;
    final description = itemDescriptions[safeValue];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: state.textStyle(
            context,
            size: 13.5,
            weight: FontWeight.w600,
            opacity: 0.62,
          ),
        ),
        const SizedBox(height: 10),
        Material(
          color: enabled
              ? _settingsSurfaceColor(state, context)
              : state.text(context).withValues(alpha: 0.025),
          borderRadius: BorderRadius.circular(_settingsCornerRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(_settingsCornerRadius),
            onTap: enabled
                ? () async {
                    final selected = await _openPicker(
                      context,
                      safeItems,
                      safeValue,
                    );
                    if (selected != null) onChanged(selected);
                  }
                : null,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 60),
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_settingsCornerRadius),
                border: Border.all(color: _settingsBorderColor(state, context)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          safeValue,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: state.textStyle(
                            context,
                            size: 15,
                            weight: FontWeight.w600,
                            opacity: enabled ? 0.9 : 0.38,
                          ),
                        ),
                        if (description != null &&
                            description != safeValue) ...[
                          const SizedBox(height: 3),
                          Text(
                            description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: state.textStyle(
                              context,
                              size: 12,
                              opacity: enabled ? 0.42 : 0.28,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: state
                        .text(context)
                        .withValues(alpha: enabled ? 0.48 : 0.22),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<String?> _openPicker(
    BuildContext context,
    List<String> safeItems,
    String safeValue,
  ) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final height = MediaQuery.sizeOf(context).height;
        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(maxHeight: height * 0.62),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: state.background(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border.all(color: _settingsBorderColor(state, context)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: state.text(context).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  label,
                  style: state.textStyle(
                    context,
                    size: 18,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: safeItems.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = safeItems[index];
                      final selected = item == safeValue;
                      final description = itemDescriptions[item];
                      return Material(
                        color: selected
                            ? state.accents[0].withValues(
                                alpha: state.isDark(context) ? 0.16 : 0.12,
                              )
                            : _settingsSurfaceColor(state, context),
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => Navigator.pop(context, item),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: state.textStyle(
                                          context,
                                          size: 14.5,
                                          weight: FontWeight.w700,
                                          height: 1.25,
                                        ),
                                      ),
                                      if (description != null &&
                                          description != item) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          description,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: state.textStyle(
                                            context,
                                            size: 11.5,
                                            opacity: 0.48,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  selected
                                      ? Icons.check_circle_rounded
                                      : Icons.circle_outlined,
                                  color: selected
                                      ? state.accents[0]
                                      : state
                                            .text(context)
                                            .withValues(alpha: 0.22),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class RadioDot extends StatelessWidget {
  const RadioDot({required this.active, required this.color});

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

class StorageRow extends StatelessWidget {
  const StorageRow({
    required this.state,
    required this.label,
    required this.color,
    required this.bytes,
    this.description,
    this.ratio,
  });

  final WeaviewState state;
  final String label;
  final Color color;
  final int bytes;
  final String? description;
  final double? ratio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: state.textStyle(
                    context,
                    size: 13,
                    weight: FontWeight.w700,
                    opacity: 0.84,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    description!,
                    style: state.textStyle(context, size: 11, opacity: 0.42),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatBytes(bytes),
                style: state.textStyle(
                  context,
                  size: 13,
                  weight: FontWeight.w700,
                ),
              ),
              if (ratio != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${(ratio!.clamp(0, 1) * 100).toStringAsFixed(1)}%',
                  style: state.textStyle(context, size: 11, opacity: 0.42),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class AboutButton extends StatelessWidget {
  const AboutButton({
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
        child: SoftButton(
          state: state,
          label: label,
          accent: accent,
          onTap: onTap,
        ),
      ),
    );
  }
}

class ModelPickerDialog extends StatefulWidget {
  const ModelPickerDialog({required this.state, required this.models});

  final WeaviewState state;
  final List<AiModel> models;

  @override
  State<ModelPickerDialog> createState() => _ModelPickerDialogState();
}

class _ModelPickerDialogState extends State<ModelPickerDialog> {
  final Set<String> selected = {};
  String query = '';

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final models = widget.models.where((m) {
      final q = query.toLowerCase();
      return q.isEmpty ||
          m.id.toLowerCase().contains(q) ||
          m.name.toLowerCase().contains(q);
    }).toList();
    final allVisibleSelected =
        models.isNotEmpty && models.every((m) => selected.contains(m.id));
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 30),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        width: 430,
        height: MediaQuery.sizeOf(context).height * 0.76,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        decoration: BoxDecoration(
          color: state.background(context),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '可用模型',
                    style: state.textStyle(
                      context,
                      size: 19,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: models.isEmpty
                      ? null
                      : () => setState(() {
                          if (allVisibleSelected) {
                            for (final model in models) {
                              selected.remove(model.id);
                            }
                          } else {
                            selected.addAll(models.map((m) => m.id));
                          }
                        }),
                  child: Text(
                    '${allVisibleSelected ? '取消全选' : '全选'} (${models.length})',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) => setState(() => query = value),
              style: state.textStyle(context, size: 14),
              decoration: inputDecoration(state, hint: '输入模型名称筛选'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: models.length,
                itemBuilder: (context, index) {
                  final model = models[index];
                  final active = selected.contains(model.id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: active
                          ? state.accents[0].withValues(alpha: 0.14)
                          : state.text(context).withValues(alpha: 0.045),
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => setState(() {
                          active
                              ? selected.remove(model.id)
                              : selected.add(model.id);
                        }),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(13, 12, 10, 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              BrandIcon.model(
                                model: model,
                                size: 34,
                                radius: 12,
                                padding: 6,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      model.name,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: state.textStyle(
                                        context,
                                        size: 14.5,
                                        weight: FontWeight.w600,
                                        height: 1.25,
                                      ),
                                    ),
                                    if (model.id != model.name) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        model.id,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: state.textStyle(
                                          context,
                                          size: 11,
                                          opacity: 0.44,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    ModelCapabilityChips(
                                      state: state,
                                      capabilities: model.capabilities,
                                      compact: true,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(
                                active
                                    ? Icons.check_circle_rounded
                                    : Icons.add_circle_outline_rounded,
                                size: 26,
                                color: active
                                    ? state.accents[0]
                                    : state
                                          .text(context)
                                          .withValues(alpha: 0.46),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SoftButton(
                    state: state,
                    label: '取消',
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SoftButton(
                    state: state,
                    label: '添加 ${selected.length}',
                    accent: true,
                    onTap: () => Navigator.pop(
                      context,
                      widget.models
                          .where((m) => selected.contains(m.id))
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TestModelDialog extends StatelessWidget {
  const TestModelDialog({required this.state, required this.models});

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
            child: Row(
              children: [
                BrandIcon.model(model: model, size: 30, radius: 10, padding: 5),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    model.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class EditModelDialog extends StatefulWidget {
  const EditModelDialog({required this.state, required this.model});

  final WeaviewState state;
  final AiModel model;

  @override
  State<EditModelDialog> createState() => _EditModelDialogState();
}

class _EditModelDialogState extends State<EditModelDialog> {
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
      ('chat', Icons.chat_bubble_outline_rounded, '聊天'),
      ('vision', Icons.visibility_outlined, '视觉'),
      ('image', Icons.image_outlined, '图像'),
      ('tool', Icons.build_outlined, '工具'),
      ('reason', Icons.psychology_outlined, '推理'),
    ];
    final state = widget.state;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: Container(
        width: 390,
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        decoration: BoxDecoration(
          color: state.background(context),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: state.text(context).withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                BrandIcon.model(
                  model: widget.model,
                  size: 44,
                  radius: 16,
                  padding: 8,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '编辑模型',
                    style: state.textStyle(
                      context,
                      size: 24,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '调整显示名称和能力标签，保存后会用于模型列表与默认模型选择。',
              style: state.textStyle(context, size: 12.5, opacity: 0.5),
            ),
            const SizedBox(height: 22),
            Text(
              '模型标识名 (ID)',
              style: state.textStyle(
                context,
                size: 13,
                weight: FontWeight.w700,
                opacity: 0.58,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              readOnly: true,
              initialValue: widget.model.id,
              style: state.textStyle(context, size: 14.5, opacity: 0.72),
              decoration: inputDecoration(state).copyWith(
                prefixIcon: Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: state.text(context).withValues(alpha: 0.42),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '显示名称',
              style: state.textStyle(
                context,
                size: 13,
                weight: FontWeight.w700,
                opacity: 0.58,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: name,
              style: state.textStyle(context, size: 14.5),
              decoration: inputDecoration(state, hint: '输入展示给用户的模型名称'),
            ),
            const SizedBox(height: 18),
            Text(
              '模型能力',
              style: state.textStyle(
                context,
                size: 13,
                weight: FontWeight.w700,
                opacity: 0.58,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in options)
                  _ModelCapabilityToggle(
                    state: state,
                    icon: option.$2,
                    label: option.$3,
                    selected: caps.contains(option.$1),
                    onTap: () => setState(() {
                      caps.contains(option.$1)
                          ? caps.remove(option.$1)
                          : caps.add(option.$1);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SoftButton(
                    state: state,
                    label: '取消',
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SoftButton(
                    state: state,
                    label: '保存配置',
                    accent: true,
                    onTap: () => Navigator.pop(
                      context,
                      widget.model.copyWith(
                        name: name.text.trim().isEmpty
                            ? widget.model.id
                            : name.text.trim(),
                        capabilities: caps.isEmpty
                            ? const ['chat']
                            : caps.toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelCapabilityToggle extends StatelessWidget {
  const _ModelCapabilityToggle({
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
    final activeColor = state.accents[0];
    return Material(
      color: selected
          ? activeColor.withValues(alpha: 0.18)
          : state.text(context).withValues(alpha: 0.055),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 94),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.check_circle_rounded : icon,
                size: 17,
                color: selected
                    ? activeColor
                    : state.text(context).withValues(alpha: 0.58),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: state
                    .textStyle(
                      context,
                      size: 12.5,
                      weight: FontWeight.w700,
                      opacity: selected ? 0.95 : 0.62,
                    )
                    .copyWith(
                      color: selected ? activeColor : state.text(context),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration inputDecoration(WeaviewState state, {String? hint}) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: state.accents[0].withValues(alpha: 0.08),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_settingsCornerRadius),
      borderSide: BorderSide(color: state.accents[0].withValues(alpha: 0.16)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_settingsCornerRadius),
      borderSide: BorderSide(color: state.accents[0].withValues(alpha: 0.14)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_settingsCornerRadius),
      borderSide: BorderSide(color: state.accents[0].withValues(alpha: 0.55)),
    ),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}
