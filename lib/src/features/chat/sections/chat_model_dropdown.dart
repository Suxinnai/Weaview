import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/weaview_state.dart';
import '../../../shared/view_models/provider_model.dart';
import '../../../shared/widgets/shared_widgets.dart';

class ChatModelDropdown extends StatelessWidget {
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
  final ValueChanged<ProviderModel> onSelectModel;

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    final enabledProviders = state.enabledModelProviders;
    final allModels = [
      for (final provider in enabledProviders)
        for (final model in provider.models)
          ProviderModel(provider: provider, model: model),
    ];
    final query = modelSearchController.text.trim().toLowerCase();
    final filtered = allModels.where((item) {
      if (query.isEmpty) return true;
      return item.model.name.toLowerCase().contains(query) ||
          item.provider.name.toLowerCase().contains(query) ||
          item.model.id.toLowerCase().contains(query);
    }).toList();

    return IgnorePointer(
      ignoring: !open,
      child: AnimatedOpacity(
        opacity: open ? 1 : 0,
        duration: const Duration(milliseconds: 160),
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: onClose,
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              top: safeTop + 62,
              left: 0,
              right: 0,
              child: Center(
                child: GlassPanel(
                  state: state,
                  radius: 22,
                  child: SizedBox(
                    width: math.min(
                      352.0,
                      MediaQuery.sizeOf(context).width - 34,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(6, 2, 6, 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '选择对话 / 生图模型',
                                  style: state
                                      .textStyle(
                                        context,
                                        size: 11,
                                        weight: FontWeight.w700,
                                        opacity: 0.42,
                                      )
                                      .copyWith(letterSpacing: 1.6),
                                ),
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 14,
                                  color: state
                                      .text(context)
                                      .withValues(alpha: 0.35),
                                ),
                              ],
                            ),
                          ),
                          TextField(
                            controller: modelSearchController,
                            autofocus: false,
                            onChanged: (_) => onSearchChanged(),
                            style: state.textStyle(context, size: 12),
                            decoration: InputDecoration(
                              hintText: '搜索模型...',
                              hintStyle: state.textStyle(
                                context,
                                size: 12,
                                opacity: 0.38,
                              ),
                              isDense: true,
                              filled: true,
                              fillColor: state
                                  .text(context)
                                  .withValues(alpha: 0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: math.min(
                                286.0,
                                MediaQuery.sizeOf(context).height * 0.34,
                              ),
                            ),
                            child: filtered.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      children: [
                                        Text(
                                          enabledProviders.isEmpty
                                              ? '仅显示已启用提供商中添加的模型'
                                              : '未找到匹配模型',
                                          style: state.textStyle(
                                            context,
                                            size: 13,
                                            opacity: 0.52,
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: onOpenSettings,
                                          child: const Text('前往设置配置'),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: filtered.length,
                                    itemBuilder: (context, index) {
                                      final item = filtered[index];
                                      final role = item.supportsImageGeneration
                                          ? 'image'
                                          : 'chat';
                                      final selected =
                                          state
                                                  .modelAssignments[role]
                                                  ?.provider ==
                                              item.provider.name &&
                                          state.modelAssignments[role]?.model ==
                                              item.model.name &&
                                          imageGenerationMode ==
                                              item.supportsImageGeneration;
                                      return ModelDropdownItem(
                                        state: state,
                                        item: item,
                                        selected: selected,
                                        onTap: () => onSelectModel(item),
                                      );
                                    },
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
}
