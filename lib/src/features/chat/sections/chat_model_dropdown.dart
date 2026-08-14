import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../app/weaview_state.dart';
import '../../../domain/model_capabilities.dart';
import '../../../shared/view_models/provider_model.dart';
import '../../../shared/widgets/shared_widgets.dart';

enum _ModelFilter { all, chat, image }

typedef ChatModelSelection = void Function(ProviderModel item, String role);

class ChatModelDropdown extends StatefulWidget {
  const ChatModelDropdown({
    super.key,
    required this.state,
    required this.modelSearchController,
    required this.open,
    required this.imageGenerationMode,
    required this.onClose,
    required this.onOpenSettings,
    required this.onSearchChanged,
    required this.onSelectModel,
  });

  final WeaviewState state;
  final TextEditingController modelSearchController;
  final bool open;
  final bool imageGenerationMode;
  final VoidCallback onClose;
  final VoidCallback onOpenSettings;
  final VoidCallback onSearchChanged;
  final ChatModelSelection onSelectModel;

  @override
  State<ChatModelDropdown> createState() => _ChatModelDropdownState();
}

class _ChatModelDropdownState extends State<ChatModelDropdown> {
  late _ModelFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.imageGenerationMode
        ? _ModelFilter.image
        : _ModelFilter.chat;
  }

  @override
  void didUpdateWidget(covariant ChatModelDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageGenerationMode != oldWidget.imageGenerationMode) {
      _filter = widget.imageGenerationMode
          ? _ModelFilter.image
          : _ModelFilter.chat;
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    final panelWidth = math.min(
      354.0,
      math.max(0.0, MediaQuery.sizeOf(context).width - 24),
    );
    final enabledProviders = widget.state.enabledModelProviders;
    final allModels = [
      for (final provider in enabledProviders)
        for (final model in provider.models)
          ProviderModel(provider: provider, model: model),
    ];
    final query = widget.modelSearchController.text.trim().toLowerCase();
    final filtered = allModels.where((item) {
      final matchesQuery =
          query.isEmpty ||
          item.model.name.toLowerCase().contains(query) ||
          item.provider.name.toLowerCase().contains(query) ||
          item.model.id.toLowerCase().contains(query);
      if (!matchesQuery) return false;
      return switch (_filter) {
        _ModelFilter.all => true,
        _ModelFilter.chat => supportsModelRole(
          role: 'chat',
          id: item.model.id,
          name: item.model.name,
          capabilities: item.model.capabilities,
        ),
        _ModelFilter.image => supportsModelRole(
          role: 'image',
          id: item.model.id,
          name: item.model.name,
          capabilities: item.model.capabilities,
        ),
      };
    }).toList();
    final grouped = <String, List<ProviderModel>>{};
    for (final item in filtered) {
      grouped.putIfAbsent(item.provider.name, () => []).add(item);
    }

    return IgnorePointer(
      ignoring: !widget.open,
      child: AnimatedOpacity(
        opacity: widget.open ? 1 : 0,
        duration: const Duration(milliseconds: 160),
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: widget.onClose,
                child: ColoredBox(
                  color: Colors.black.withValues(
                    alpha: widget.state.isDark(context) ? 0.13 : 0.035,
                  ),
                ),
              ),
            ),
            Positioned(
              top: safeTop + 46,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: 1,
                child: AnimatedSlide(
                  offset: widget.open ? Offset.zero : const Offset(0, -0.025),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: AnimatedScale(
                    scale: widget.open ? 1 : 0.985,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: _ModelPickerGlass(
                      state: widget.state,
                      child: SizedBox(
                        width: panelWidth,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _DropdownHeader(
                                state: widget.state,
                                modelCount: filtered.length,
                                providerCount: grouped.length,
                                onClose: widget.onClose,
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                key: const ValueKey('model_picker_search'),
                                controller: widget.modelSearchController,
                                autofocus: false,
                                onChanged: (_) {
                                  setState(() {});
                                  widget.onSearchChanged();
                                },
                                style: widget.state.textStyle(
                                  context,
                                  size: 13,
                                ),
                                decoration: InputDecoration(
                                  hintText: '搜索模型或提供商',
                                  hintStyle: widget.state.textStyle(
                                    context,
                                    size: 13,
                                    opacity: 0.38,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    size: 19,
                                    color: widget.state
                                        .text(context)
                                        .withValues(alpha: 0.4),
                                  ),
                                  suffixIcon:
                                      widget.modelSearchController.text.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: '清空搜索',
                                          onPressed: () {
                                            widget.modelSearchController
                                                .clear();
                                            setState(() {});
                                            widget.onSearchChanged();
                                          },
                                          icon: Icon(
                                            Icons.cancel_rounded,
                                            size: 17,
                                            color: widget.state
                                                .text(context)
                                                .withValues(alpha: 0.34),
                                          ),
                                        ),
                                  isDense: true,
                                  filled: true,
                                  fillColor: widget.state
                                      .layer(context)
                                      .withValues(
                                        alpha: widget.state.isDark(context)
                                            ? 0.24
                                            : 0.42,
                                      ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(17),
                                    borderSide: BorderSide(
                                      color: widget.state
                                          .text(context)
                                          .withValues(alpha: 0.07),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(17),
                                    borderSide: BorderSide(
                                      color: widget.state
                                          .text(context)
                                          .withValues(alpha: 0.07),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(17),
                                    borderSide: BorderSide(
                                      color: widget.state.accents[0].withValues(
                                        alpha: 0.52,
                                      ),
                                      width: 1.2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 13,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _FilterRow(
                                state: widget.state,
                                filter: _filter,
                                onChanged: (next) =>
                                    setState(() => _filter = next),
                              ),
                              const SizedBox(height: 10),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: math.min(
                                    316.0,
                                    MediaQuery.sizeOf(context).height * 0.41,
                                  ),
                                ),
                                child: filtered.isEmpty
                                    ? _EmptyState(
                                        state: widget.state,
                                        onOpenSettings: widget.onOpenSettings,
                                      )
                                    : ListView(
                                        padding: EdgeInsets.zero,
                                        primary: false,
                                        shrinkWrap: true,
                                        children: [
                                          for (final entry
                                              in grouped.entries) ...[
                                            _ProviderSectionHeader(
                                              state: widget.state,
                                              name: entry.key,
                                              count: entry.value.length,
                                            ),
                                            for (final item in entry.value)
                                              ModelDropdownItem(
                                                state: widget.state,
                                                item: item,
                                                selected: _isSelected(item),
                                                onTap: () =>
                                                    widget.onSelectModel(
                                                      item,
                                                      _selectionRole(item),
                                                    ),
                                              ),
                                          ],
                                        ],
                                      ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: _ManageModelsButton(
                                  state: widget.state,
                                  onTap: widget.onOpenSettings,
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
            ),
          ],
        ),
      ),
    );
  }

  bool _isSelected(ProviderModel item) {
    final role = _selectionRole(item);
    return widget.state.modelAssignments[role]?.provider ==
            item.provider.name &&
        widget.state.modelAssignments[role]?.model == item.model.name &&
        widget.imageGenerationMode == (role == 'image');
  }

  String _selectionRole(ProviderModel item) {
    if (_filter == _ModelFilter.image) return 'image';
    if (_filter == _ModelFilter.chat) return 'chat';
    if (widget.imageGenerationMode && item.supportsImageGeneration) {
      return 'image';
    }
    final supportsChat = supportsModelRole(
      role: 'chat',
      id: item.model.id,
      name: item.model.name,
      capabilities: item.model.capabilities,
    );
    return supportsChat ? 'chat' : 'image';
  }
}

class _ModelPickerGlass extends StatelessWidget {
  const _ModelPickerGlass({required this.state, required this.child});

  final WeaviewState state;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = state.isDark(context);
    final surface = state.layer(context);
    final tintedSurface = Color.alphaBlend(
      state.accents[0].withValues(alpha: dark ? 0.08 : 0.055),
      surface,
    );
    return RepaintBoundary(
      key: const ValueKey('model_picker_glass'),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(27),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.34 : 0.13),
              blurRadius: 38,
              spreadRadius: -8,
              offset: const Offset(0, 18),
            ),
            BoxShadow(
              color: state.accents[0].withValues(alpha: dark ? 0.08 : 0.12),
              blurRadius: 34,
              spreadRadius: -12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(27),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    surface.withValues(alpha: dark ? 0.74 : 0.70),
                    tintedSurface.withValues(alpha: dark ? 0.66 : 0.56),
                  ],
                ),
                borderRadius: BorderRadius.circular(27),
                border: Border.all(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.10)
                      : Colors.white.withValues(alpha: 0.68),
                  width: 1,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _DropdownHeader extends StatelessWidget {
  const _DropdownHeader({
    required this.state,
    required this.modelCount,
    required this.providerCount,
    required this.onClose,
  });

  final WeaviewState state;
  final int modelCount;
  final int providerCount;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 1, 0, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '选择模型',
                      style: state.textStyle(
                        context,
                        size: 15.5,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: state.accents[0].withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: state.accents[0].withValues(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        '$modelCount 个可用',
                        style: state
                            .textStyle(
                              context,
                              size: 9.5,
                              weight: FontWeight.w700,
                            )
                            .copyWith(color: state.accents[0]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  providerCount == 0
                      ? '连接提供商后即可切换'
                      : '$providerCount 个提供商 · 按用途快速筛选',
                  style: state.textStyle(context, size: 10.5, opacity: 0.46),
                ),
              ],
            ),
          ),
          IconCircleButton(
            icon: Icons.close_rounded,
            onTap: onClose,
            color: state.text(context),
            size: 34,
            opacity: 0.64,
            background: state.layer(context).withValues(alpha: 0.46),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.state,
    required this.filter,
    required this.onChanged,
  });

  final WeaviewState state;
  final _ModelFilter filter;
  final ValueChanged<_ModelFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('model_picker_filters'),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: state
            .layer(context)
            .withValues(alpha: state.isDark(context) ? 0.24 : 0.36),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: state.text(context).withValues(alpha: 0.055)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _FilterChip(
              state: state,
              selected: filter == _ModelFilter.all,
              label: '全部',
              onTap: () => onChanged(_ModelFilter.all),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _FilterChip(
              state: state,
              selected: filter == _ModelFilter.chat,
              label: '对话',
              onTap: () => onChanged(_ModelFilter.chat),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _FilterChip(
              state: state,
              selected: filter == _ModelFilter.image,
              label: '生图',
              onTap: () => onChanged(_ModelFilter.image),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.state,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final WeaviewState state;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          key: ValueKey('model_filter_$label'),
          height: 38,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected
                ? state.accents[0].withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            border: selected
                ? Border.all(color: state.accents[0].withValues(alpha: 0.22))
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: state.accents[0].withValues(alpha: 0.10),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: state.textStyle(
                context,
                size: 11.5,
                weight: selected ? FontWeight.w700 : FontWeight.w600,
                opacity: selected ? 0.96 : 0.58,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderSectionHeader extends StatelessWidget {
  const _ProviderSectionHeader({
    required this.state,
    required this.name,
    required this.count,
  });

  final WeaviewState state;
  final String name;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(7, 11, 7, 7),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: state.accents[0],
              boxShadow: [
                BoxShadow(
                  color: state.accents[0].withValues(alpha: 0.42),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: state
                  .textStyle(
                    context,
                    size: 10.5,
                    weight: FontWeight.w700,
                    opacity: 0.48,
                  )
                  .copyWith(letterSpacing: 1.1),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: state.text(context).withValues(alpha: 0.045),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: state.textStyle(
                context,
                size: 9,
                weight: FontWeight.w700,
                opacity: 0.38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManageModelsButton extends StatelessWidget {
  const _ManageModelsButton({required this.state, required this.onTap});

  final WeaviewState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('manage_models_button'),
      color: state
          .layer(context)
          .withValues(alpha: state.isDark(context) ? 0.22 : 0.34),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 31,
                height: 31,
                decoration: BoxDecoration(
                  color: state.accents[0].withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  size: 17,
                  color: state.accents[0].withValues(alpha: 0.84),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '管理模型',
                      style: state.textStyle(
                        context,
                        size: 12.5,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '提供商与默认模型',
                      style: state.textStyle(context, size: 9.5, opacity: 0.4),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 19,
                color: state.text(context).withValues(alpha: 0.34),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.state, required this.onOpenSettings});

  final WeaviewState state;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        children: [
          Icon(
            Icons.hub_outlined,
            size: 20,
            color: state.text(context).withValues(alpha: 0.34),
          ),
          const SizedBox(height: 8),
          Text(
            '当前筛选条件下没有可用模型',
            textAlign: TextAlign.center,
            style: state.textStyle(context, size: 12.5, opacity: 0.58),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onOpenSettings, child: const Text('前往提供商设置')),
        ],
      ),
    );
  }
}
