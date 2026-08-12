import 'dart:math' as math;

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
        : _ModelFilter.all;
  }

  @override
  void didUpdateWidget(covariant ChatModelDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageGenerationMode != oldWidget.imageGenerationMode &&
        widget.open &&
        _filter != _ModelFilter.all) {
      _filter = widget.imageGenerationMode
          ? _ModelFilter.image
          : _ModelFilter.chat;
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    final panelWidth = math.min(
      344.0,
      math.max(0.0, MediaQuery.sizeOf(context).width - 30),
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
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              top: safeTop + 42,
              left: 0,
              right: 0,
              child: Center(
                child: GlassPanel(
                  state: widget.state,
                  radius: 22,
                  child: SizedBox(
                    width: panelWidth,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _DropdownHeader(
                            state: widget.state,
                            onClose: widget.onClose,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: widget.modelSearchController,
                            autofocus: false,
                            onChanged: (_) {
                              setState(() {});
                              widget.onSearchChanged();
                            },
                            style: widget.state.textStyle(context, size: 12.5),
                            decoration: InputDecoration(
                              hintText: '搜索模型或提供商',
                              hintStyle: widget.state.textStyle(
                                context,
                                size: 12.5,
                                opacity: 0.38,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                size: 18,
                                color: widget.state
                                    .text(context)
                                    .withValues(alpha: 0.4),
                              ),
                              isDense: true,
                              filled: true,
                              fillColor: widget.state
                                  .text(context)
                                  .withValues(alpha: 0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _FilterRow(
                            state: widget.state,
                            filter: _filter,
                            onChanged: (next) => setState(() => _filter = next),
                          ),
                          const SizedBox(height: 8),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: math.min(
                                300.0,
                                MediaQuery.sizeOf(context).height * 0.42,
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
                                      for (final entry in grouped.entries) ...[
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            6,
                                            10,
                                            6,
                                            6,
                                          ),
                                          child: Text(
                                            entry.key,
                                            style: widget.state
                                                .textStyle(
                                                  context,
                                                  size: 10.5,
                                                  weight: FontWeight.w700,
                                                  opacity: 0.42,
                                                )
                                                .copyWith(letterSpacing: 1.2),
                                          ),
                                        ),
                                        for (final item in entry.value)
                                          ModelDropdownItem(
                                            state: widget.state,
                                            item: item,
                                            selected: _isSelected(item),
                                            onTap: () => widget.onSelectModel(
                                              item,
                                              _selectionRole(item),
                                            ),
                                          ),
                                      ],
                                    ],
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: widget.state
                                        .text(context)
                                        .withValues(alpha: 0.06),
                                  ),
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                minTileHeight: 42,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                onTap: widget.onOpenSettings,
                                leading: Icon(
                                  Icons.settings_outlined,
                                  size: 19,
                                  color: widget.state
                                      .text(context)
                                      .withValues(alpha: 0.62),
                                ),
                                title: Text(
                                  '管理模型',
                                  style: widget.state.textStyle(
                                    context,
                                    size: 13,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.chevron_right_rounded,
                                  color: widget.state
                                      .text(context)
                                      .withValues(alpha: 0.38),
                                ),
                              ),
                            ),
                          ),
                        ],
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

class _DropdownHeader extends StatelessWidget {
  const _DropdownHeader({required this.state, required this.onClose});

  final WeaviewState state;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 1, 2, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '选择模型',
                  style: state.textStyle(
                    context,
                    size: 13.5,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '按用途与提供商快速切换',
                  style: state.textStyle(context, size: 10.5, opacity: 0.42),
                ),
              ],
            ),
          ),
          IconCircleButton(
            icon: Icons.close_rounded,
            onTap: onClose,
            color: state.text(context),
            size: 32,
            opacity: 0.72,
            background: state.text(context).withValues(alpha: 0.055),
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
    return Row(
      children: [
        Expanded(
          child: _FilterChip(
            state: state,
            selected: filter == _ModelFilter.all,
            label: '全部',
            onTap: () => onChanged(_ModelFilter.all),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _FilterChip(
            state: state,
            selected: filter == _ModelFilter.chat,
            label: '对话',
            onTap: () => onChanged(_ModelFilter.chat),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _FilterChip(
            state: state,
            selected: filter == _ModelFilter.image,
            label: '生图',
            onTap: () => onChanged(_ModelFilter.image),
          ),
        ),
      ],
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
      color: selected
          ? state.accents[0].withValues(alpha: 0.18)
          : state.text(context).withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 34,
          child: Center(
            child: Text(
              label,
              style: state.textStyle(
                context,
                size: 12,
                weight: selected ? FontWeight.w700 : FontWeight.w600,
                opacity: selected ? 0.96 : 0.68,
              ),
            ),
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
