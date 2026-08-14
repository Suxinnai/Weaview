import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app/weaview_state.dart';
import '../../domain/models.dart';
import '../../shared/widgets/brand_icon.dart';

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
  late final Set<String> _availableKeys = widget.options.map(_modelKey).toSet();
  late final Set<String> _selected = widget.initialSelection
      .map(_modelKey)
      .where(_availableKeys.contains)
      .take(3)
      .toSet();
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _providerFilter = _allProvidersKey;
  String? _validationMessage;

  List<String> get _providerOptions {
    final providers = <String>{};
    for (final option in widget.options) {
      final provider = option.provider.trim();
      if (provider.isNotEmpty) providers.add(provider);
    }
    final sorted = providers.toList()..sort((a, b) => a.compareTo(b));
    return [_allProvidersKey, ...sorted];
  }

  List<ModelAssignment> get _visibleOptions {
    final normalized = _query.trim().toLowerCase();
    return widget.options.where((option) {
      if (_providerFilter != _allProvidersKey &&
          option.provider != _providerFilter) {
        return false;
      }
      if (normalized.isEmpty) return true;
      final haystack = '${option.provider} ${option.model}'.toLowerCase();
      return haystack.contains(normalized);
    }).toList();
  }

  void _toggle(ModelAssignment option) {
    final key = _modelKey(option);
    setState(() {
      _validationMessage = null;
      if (_selected.remove(key)) return;
      if (_selected.length >= 3) {
        _validationMessage = '最多选择 3 个模型';
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final dark = state.isDark(context);
    final textColor = state.text(context);
    final visibleOptions = _visibleOptions;
    final selectedItems = [
      for (final option in widget.options)
        if (_selected.contains(_modelKey(option))) option,
    ];
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Material(
          color: state.layer(context).withValues(alpha: dark ? 0.90 : 0.88),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 12, 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '选择对比模型',
                              style: state.textStyle(
                                context,
                                size: 18,
                                weight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '最多同时选择 3 个模型',
                              style: state.textStyle(
                                context,
                                size: 11.5,
                                opacity: 0.52,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 3, right: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: state.accents[0].withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: state.accents[0].withValues(alpha: 0.22),
                          ),
                        ),
                        child: Text(
                          '已选 ${_selected.length}/3',
                          key: const Key('comparison-selection-count'),
                          style: state
                              .textStyle(
                                context,
                                size: 11.5,
                                weight: FontWeight.w700,
                              )
                              .copyWith(color: state.accents[0]),
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        constraints: const BoxConstraints.tightFor(
                          width: 44,
                          height: 44,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 5),
                  child: TextField(
                    controller: _searchController,
                    minLines: 1,
                    maxLines: 1,
                    decoration: InputDecoration(
                      hintText: '搜索模型',
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: textColor.withValues(alpha: 0.42),
                      ),
                      filled: true,
                      fillColor: textColor.withValues(
                        alpha: dark ? 0.07 : 0.045,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 5, 18, 5),
                    scrollDirection: Axis.horizontal,
                    itemCount: _providerOptions.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final provider = _providerOptions[index];
                      final selected = provider == _providerFilter;
                      final label = provider == _allProvidersKey
                          ? '全部'
                          : provider;
                      return _ProviderFilterChip(
                        state: state,
                        label: label,
                        selected: selected,
                        onTap: () => setState(() => _providerFilter = provider),
                      );
                    },
                  ),
                ),
                if (_validationMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _validationMessage!,
                        key: const Key('comparison-selection-error'),
                        style: state
                            .textStyle(context, size: 12.5)
                            .copyWith(color: Colors.red),
                      ),
                    ),
                  ),
                const SizedBox(height: 5),
                Expanded(
                  child: visibleOptions.isEmpty
                      ? _EmptyComparisonState(state: state, query: _query)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                          itemCount: visibleOptions.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final option = visibleOptions[index];
                            final selected = _selected.contains(
                              _modelKey(option),
                            );
                            return _ComparisonOptionCard(
                              state: state,
                              option: option,
                              selected: selected,
                              onTap: () => _toggle(option),
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: textColor.withValues(alpha: 0.08)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SelectedComparisonSummary(
                          state: state,
                          selectedItems: selectedItems,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 132,
                        height: 48,
                        child: FilledButton(
                          key: const Key('comparison-selection-confirm'),
                          onPressed: _selected.length >= 2 ? _confirm : null,
                          child: const Text('开始对比'),
                        ),
                      ),
                    ],
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

class _ProviderFilterChip extends StatelessWidget {
  const _ProviderFilterChip({
    required this.state,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final WeaviewState state;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = state.text(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? state.accents[0].withValues(alpha: 0.12)
                  : textColor.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? state.accents[0].withValues(alpha: 0.26)
                    : textColor.withValues(alpha: 0.08),
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: state
                    .textStyle(
                      context,
                      size: 12,
                      weight: FontWeight.w600,
                      opacity: selected ? 1 : 0.62,
                    )
                    .copyWith(color: selected ? state.accents[0] : textColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ComparisonOptionCard extends StatelessWidget {
  const _ComparisonOptionCard({
    required this.state,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final WeaviewState state;
  final ModelAssignment option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final providerColor = _providerColor(option.provider);
    final textColor = state.text(context);
    return Semantics(
      selected: selected,
      button: true,
      label: '${option.provider} ${option.model}${selected ? '，已选择' : ''}',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: Key('comparison-option-${_modelKey(option)}'),
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: selected
                  ? state.accents[0].withValues(alpha: 0.08)
                  : textColor.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? state.accents[0].withValues(alpha: 0.24)
                    : textColor.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                BrandIcon.named(
                  label: option.provider,
                  color: providerColor,
                  size: 44,
                  radius: 14,
                  padding: 8,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.model,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: state.textStyle(
                          context,
                          size: 15,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        option.provider,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: state.textStyle(
                          context,
                          size: 11.5,
                          opacity: 0.54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? state.accents[0] : Colors.transparent,
                    border: Border.all(
                      color: selected
                          ? state.accents[0]
                          : textColor.withValues(alpha: 0.18),
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 18,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedComparisonSummary extends StatelessWidget {
  const _SelectedComparisonSummary({
    required this.state,
    required this.selectedItems,
  });

  final WeaviewState state;
  final List<ModelAssignment> selectedItems;

  @override
  Widget build(BuildContext context) {
    if (selectedItems.isEmpty) {
      return Text(
        '请至少选择 2 个模型开始对比',
        style: state.textStyle(context, size: 12.5, opacity: 0.52),
      );
    }
    return Row(
      children: [
        SizedBox(
          width: 72,
          height: 36,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var index = 0; index < selectedItems.length; index++)
                Positioned(
                  left: index * 20,
                  child: BrandIcon.named(
                    label: selectedItems[index].provider,
                    color: _providerColor(selectedItems[index].provider),
                    size: 36,
                    radius: 14,
                    padding: 7,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _selectionSummary(selectedItems),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: state.textStyle(context, size: 12.8, height: 1.35),
          ),
        ),
      ],
    );
  }
}

class _EmptyComparisonState extends StatelessWidget {
  const _EmptyComparisonState({required this.state, required this.query});

  final WeaviewState state;
  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 36,
              color: state.text(context).withValues(alpha: 0.34),
            ),
            const SizedBox(height: 12),
            Text(
              query.trim().isEmpty ? '没有可用模型' : '没有找到匹配的模型',
              style: state.textStyle(
                context,
                size: 15,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              query.trim().isEmpty ? '请先在提供商页面配置模型。' : '换个关键词或提供商筛选试试。',
              textAlign: TextAlign.center,
              style: state.textStyle(context, size: 12.5, opacity: 0.52),
            ),
          ],
        ),
      ),
    );
  }
}

String _selectionSummary(List<ModelAssignment> items) {
  return items.map((item) => item.model).join(' + ');
}

Color _providerColor(String providerName) {
  for (final provider in AiProvider.defaults()) {
    if (provider.name.toLowerCase() == providerName.toLowerCase()) {
      return provider.color;
    }
  }
  return BrandIconRegistry.fallbackColorFor(providerName);
}

String _modelKey(ModelAssignment assignment) =>
    '${assignment.provider}\u0000${assignment.model}';

const _allProvidersKey = '__all__';
