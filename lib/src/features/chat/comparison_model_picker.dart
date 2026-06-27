import 'package:flutter/material.dart';

import '../../app/weaview_state.dart';
import '../../domain/models.dart';

class ComparisonModelPicker extends StatefulWidget {
  const ComparisonModelPicker({
    super.key,
    required this.state,
    required this.options,
    required this.initialSelection,
  });

  final WeaviewState state;
  final List<ModelAssignment> options;
  final List<ModelAssignment> initialSelection;

  @override
  State<ComparisonModelPicker> createState() => _ComparisonModelPickerState();
}

class _ComparisonModelPickerState extends State<ComparisonModelPicker> {
  late final Set<String> _selected = widget.initialSelection
      .map(_modelKey)
      .where(widget.options.map(_modelKey).toSet().contains)
      .take(5)
      .toSet();
  String? _validationMessage;

  void _toggle(ModelAssignment option) {
    final key = _modelKey(option);
    setState(() {
      _validationMessage = null;
      if (_selected.remove(key)) return;
      if (_selected.length >= 5) {
        _validationMessage = '最多选择 5 个模型';
        return;
      }
      _selected.add(key);
    });
  }

  void _confirm() {
    if (_selected.length < 2) {
      setState(() => _validationMessage = '请至少选择 2 个模型');
      return;
    }
    Navigator.of(context).pop([
      for (final option in widget.options)
        if (_selected.contains(_modelKey(option))) option,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final dark = state.isDark(context);
    return Material(
      color: state.layer(context).withValues(alpha: dark ? 0.98 : 1),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: state.text(context).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '选择对照模型',
                          style: state.textStyle(
                            context,
                            size: 18,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '选择 2–5 个已配置的聊天模型',
                          style: state.textStyle(
                            context,
                            size: 13,
                            opacity: 0.52,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  Text(
                    '已选择 ${_selected.length}/5',
                    key: const Key('comparison-selection-count'),
                    style: state
                        .textStyle(context, size: 12.5, weight: FontWeight.w600)
                        .copyWith(color: state.accents[0]),
                  ),
                  if (_validationMessage != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _validationMessage!,
                        key: const Key('comparison-selection-error'),
                        textAlign: TextAlign.end,
                        style: state
                            .textStyle(context, size: 12.5)
                            .copyWith(color: Colors.red),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Divider(
              height: 1,
              color: state.text(context).withValues(alpha: 0.07),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                itemCount: widget.options.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final option = widget.options[index];
                  final selected = _selected.contains(_modelKey(option));
                  return Semantics(
                    selected: selected,
                    button: true,
                    label:
                        '${option.provider} ${option.model}${selected ? '，已选择' : ''}',
                    child: Material(
                      color: selected
                          ? state.accents[0].withValues(alpha: 0.10)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        key: Key('comparison-option-${_modelKey(option)}'),
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _toggle(option),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 56),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: state.accents[index % 2].withValues(
                                      alpha: 0.12,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 17,
                                    color: state.accents[index % 2],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        option.model,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: state.textStyle(
                                          context,
                                          size: 14,
                                          weight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        option.provider,
                                        style: state.textStyle(
                                          context,
                                          size: 12,
                                          opacity: 0.50,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Checkbox(
                                  value: selected,
                                  onChanged: (_) => _toggle(option),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  key: const Key('comparison-selection-confirm'),
                  onPressed: _selected.length >= 2 ? _confirm : null,
                  child: const Text('开始对照'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _modelKey(ModelAssignment assignment) =>
    '${assignment.provider}\u0000${assignment.model}';
