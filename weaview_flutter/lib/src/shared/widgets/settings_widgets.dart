// ignore_for_file: use_key_in_widget_constructors

import 'package:flutter/material.dart';

import '../../app/app_constants.dart';
import '../../app/weaview_state.dart';
import '../../core/app_utils.dart';
import '../../domain/models.dart';

class SectionLabel extends StatelessWidget {
  const SectionLabel({required this.state, required this.label, this.icon});

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

class DividerLine extends StatelessWidget {
  const DividerLine({required this.state});

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

class ThemeChoice extends StatelessWidget {
  const ThemeChoice({
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
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 48,
        height: 26,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value
              ? sendGreen
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
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: color.withValues(alpha: 0.68)),
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
      constraints: const BoxConstraints(maxWidth: 122),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? sendGreen.withValues(alpha: 0.12)
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
              .copyWith(color: active ? sendGreen : null),
        ),
      ),
    );
  }
}

class ModelCapabilityChips extends StatelessWidget {
  const ModelCapabilityChips({
    required this.state,
    required this.capabilities,
    this.compact = false,
  });

  final WeaviewState state;
  final List<String> capabilities;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final caps = capabilities.isEmpty ? const ['chat'] : capabilities;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final cap in caps)
          _CapabilityChip(state: state, cap: cap, compact: compact),
      ],
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({
    required this.state,
    required this.cap,
    required this.compact,
  });

  final WeaviewState state;
  final String cap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final meta = switch (cap) {
      'vision' => (Icons.image_search_outlined, '视觉', const Color(0xFF60A5FA)),
      'image' => (Icons.image_outlined, '图像', const Color(0xFFA78BFA)),
      'tool' => (Icons.build_outlined, '工具', const Color(0xFFF59E0B)),
      'reason' => (Icons.psychology_outlined, '推理', const Color(0xFF34D399)),
      'chat' => (
        Icons.chat_bubble_outline_rounded,
        '聊天',
        const Color(0xFF38BDF8),
      ),
      _ => (Icons.tune_rounded, cap, state.accents[0]),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: meta.$3.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            meta.$1,
            size: compact ? 13 : 15,
            color: state.text(context).withValues(alpha: 0.72),
          ),
          const SizedBox(width: 4),
          Text(
            meta.$2,
            style: state.textStyle(
              context,
              size: compact ? 10.5 : 11.5,
              weight: FontWeight.w700,
              opacity: 0.74,
            ),
          ),
        ],
      ),
    );
  }
}

class SoftButton extends StatelessWidget {
  const SoftButton({
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
                        ? state.layer(context)
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

class DropdownField extends StatelessWidget {
  const DropdownField({
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
          decoration: inputDecoration(state),
        ),
      ],
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
            formatBytes(bytes),
            style: state.textStyle(context, size: 13, weight: FontWeight.w600),
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
          accent: false,
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
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: state.accents[0].withValues(
                                    alpha: 0.14,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.memory_rounded,
                                  size: 19,
                                  color: state
                                      .text(context)
                                      .withValues(alpha: 0.62),
                                ),
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
            child: Text(model.name),
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
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '模型能力',
                style: state.textStyle(
                  context,
                  size: 13,
                  weight: FontWeight.w700,
                  opacity: 0.62,
                ),
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
    return Material(
      color: selected
          ? state.accents[0].withValues(alpha: 0.18)
          : state.text(context).withValues(alpha: 0.055),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 100,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected
                    ? state.accents[0]
                    : state.text(context).withValues(alpha: 0.58),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: state.textStyle(
                    context,
                    size: 12.5,
                    weight: FontWeight.w700,
                    opacity: selected ? 0.95 : 0.62,
                  ),
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
      borderSide: BorderSide(color: accentMint.withValues(alpha: 0.55)),
    ),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
  );
}
