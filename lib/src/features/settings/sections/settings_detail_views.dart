// ignore_for_file: use_key_in_widget_constructors

import 'package:flutter/material.dart';

import '../../../app/app_constants.dart';
import '../../../app/weaview_state.dart';
import '../../../core/app_utils.dart';
import '../../../domain/models.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../settings_sheet.dart';

String _roleLabel(String role) {
  return SettingsSheetState.settingsRoles[role]?.$1 ?? role;
}

String _roleCapabilityHint(String role) {
  switch (role) {
    case 'image':
      return '仅显示支持图片生成的模型。';
    case 'tool':
      return '优先使用支持工具调用的聊天模型；纯生图模型不会出现在这里。';
    case 'title':
    case 'suggest':
    case 'translate':
    case 'chat':
      return '仅显示可用于文本对话的模型；纯生图模型不会出现在这里。';
    default:
      return '将根据角色能力自动过滤模型。';
  }
}

String? _validateRoleDraft({
  required String role,
  required ModelAssignment draft,
  required Iterable<AiProvider> providers,
}) {
  if (draft.provider.trim().isEmpty || draft.model.trim().isEmpty) return null;
  final provider = providers.firstWhereOrNull((p) => p.name == draft.provider);
  if (provider == null) {
    return '已选提供商不可用，请重新选择。';
  }
  final model = provider.models.firstWhereOrNull((m) => m.name == draft.model);
  if (model == null) {
    return '已选模型不存在，请重新选择。';
  }
  if (!supportsModelRole(
    role: role,
    id: model.id,
    name: model.name,
    capabilities: model.capabilities,
  )) {
    return '${_roleLabel(role)}不能使用当前模型，请改选兼容模型。';
  }
  return null;
}

extension SettingsDetailViews on SettingsSheetState {
  bool get _providerReadyForModels {
    final saved = editingProvider;
    final hasSavedKey = saved != null &&
        (saved.apiKey.trim().isNotEmpty ||
            saved.status == '已连接' ||
            saved.status == '使用中');
    return providerKey.trim().isNotEmpty || hasSavedKey;
  }

  Widget systemPromptView() {
    final state = widget.state;
    return scrollContent([
      Text(
        '修改此提示词将改变AI在此环境中的表现形态与语言风格。如果您想恢复，请清空内容。',
        style: state.textStyle(context, size: 13, opacity: 0.55, height: 1.5),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.48,
        child: TextField(
          controller: systemPromptController,
          expands: true,
          maxLines: null,
          minLines: null,
          textAlignVertical: TextAlignVertical.top,
          style: state.textStyle(context, size: 14, height: 1.65),
          decoration: inputDecoration(
            state,
            hint: '在此输入全局系统提示词...',
          ).copyWith(contentPadding: const EdgeInsets.all(18)),
          onChanged: state.updateSystemPrompt,
        ),
      ),
      const SizedBox(height: 12),
      SoftButton(
        state: state,
        label: '恢复默认提示词',
        onTap: () {
          systemPromptController.text = defaultSystemInstruction;
          state.updateSystemPrompt(defaultSystemInstruction);
        },
      ),
    ]);
  }

  Widget userProfileView() {
    final state = widget.state;
    final editorHeight = (MediaQuery.sizeOf(context).height * 0.56)
        .clamp(360.0, 520.0)
        .toDouble();
    return bottomActionPage(
      status: statusText,
      children: [
        Text(
          '人物画像会作为长期上下文的一部分，用于让AI理解你的偏好、项目背景和沟通方式。',
          style: state.textStyle(
            context,
            size: 13,
            opacity: 0.55,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: 320, maxHeight: editorHeight),
          child: TextField(
            controller: profileController,
            expands: true,
            maxLines: null,
            minLines: null,
            textAlignVertical: TextAlignVertical.top,
            scrollPhysics: const BouncingScrollPhysics(),
            style: state.textStyle(context, size: 13.5, height: 1.6),
            decoration: inputDecoration(
              state,
              hint: '记录你的偏好、项目、沟通方式等...',
            ).copyWith(contentPadding: const EdgeInsets.all(20)),
            onChanged: state.updateUserProfile,
          ),
        ),
      ],
      actions: Row(
        children: [
          Expanded(
            child: SoftButton(
              state: state,
              label: '清空',
              danger: true,
              onTap: () {
                profileController.clear();
                state.updateUserProfile('');
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: SoftButton(
              state: state,
              label: 'AI 补全人物画像',
              icon: Icons.auto_fix_high_rounded,
              accent: true,
              onTap: completeUserProfile,
            ),
          ),
        ],
      ),
    );
  }

  Widget memoryView() {
    final state = widget.state;
    final memories = state.memoryItems;

    Widget memoryChip(
      String label,
      IconData icon, {
      Color? color,
      bool filled = false,
    }) {
      final chipColor = color ?? state.text(context).withValues(alpha: 0.52);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: filled
              ? chipColor.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: chipColor.withValues(alpha: 0.16)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: chipColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: state.textStyle(
                context,
                size: 11.5,
                weight: FontWeight.w600,
                opacity: color == null ? 0.52 : 1,
              ),
            ),
          ],
        ),
      );
    }

    return scrollContent([
      Text(
        'AI将会记住关于您的重要信息，以便提供更个性化的回应。',
        textAlign: TextAlign.center,
        style: state.textStyle(context, size: 13, opacity: 0.55),
      ),
      const SizedBox(height: 22),
      CardShell(
        state: state,
        child: Column(
          children: [
            SettingsRow(
              state: state,
              title: '全局记忆',
              subtitle: '将记录的记忆应用于所有对话',
              trailing: WeaveSwitch(
                state: state,
                value: state.globalMemoryEnabled,
                onChanged: state.setGlobalMemoryEnabled,
              ),
            ),
            DividerLine(state: state),
            SettingsRow(
              state: state,
              title: '参考历史记忆',
              subtitle: '将最近的历史聊天用于当前上下文',
              trailing: WeaveSwitch(
                state: state,
                value: state.referenceHistoryEnabled,
                onChanged: state.setReferenceHistoryEnabled,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      Row(
        children: [
          Expanded(
            child: SectionLabel(state: state, label: '用户记忆'),
          ),
          TextButton.icon(
            onPressed: organizeMemories,
            icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
            label: const Text('AI 整理'),
          ),
        ],
      ),
      if (memories.isEmpty)
        CardShell(
          state: state,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
          child: Center(
            child: Text(
              '暂无记忆',
              style: state.textStyle(context, size: 13, opacity: 0.42),
            ),
          ),
        )
      else
        for (final item in memories)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CardShell(
              state: state,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Opacity(
                opacity: item.enabled ? 1 : 0.48,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: state.accents[0].withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        item.pinned
                            ? Icons.push_pin_rounded
                            : Icons.auto_awesome_rounded,
                        size: 16,
                        color: state.text(context).withValues(alpha: 0.58),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.content,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: state.textStyle(
                              context,
                              size: 14,
                              height: 1.45,
                              weight: item.pinned
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              memoryChip(
                                item.enabled ? '参与上下文' : '已停用',
                                item.enabled
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_outlined,
                                color: item.enabled
                                    ? sendGreen
                                    : state
                                          .text(context)
                                          .withValues(alpha: 0.42),
                                filled: item.enabled,
                              ),
                              memoryChip(
                                item.source,
                                Icons.sell_outlined,
                                color: state
                                    .text(context)
                                    .withValues(alpha: 0.58),
                              ),
                              if (item.pinned)
                                memoryChip(
                                  '置顶',
                                  Icons.push_pin_rounded,
                                  color: state.accents[0],
                                  filled: true,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                item.enabled ? '启用中' : '已停用',
                                style: state.textStyle(
                                  context,
                                  size: 11.5,
                                  opacity: 0.45,
                                ),
                              ),
                              const Spacer(),
                              WeaveSwitch(
                                state: state,
                                value: item.enabled,
                                onChanged: (value) =>
                                    state.setMemoryEnabled(item.id, value),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TinyIcon(
                          icon: item.pinned
                              ? Icons.push_pin_rounded
                              : Icons.push_pin_outlined,
                          color: item.pinned
                              ? state.accents[0]
                              : state.text(context),
                          onTap: () => state.toggleMemoryPinned(item.id),
                        ),
                        TinyIcon(
                          icon: Icons.delete_outline_rounded,
                          color: Colors.red,
                          onTap: () => state.deleteMemoryById(item.id),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      const SizedBox(height: 24),
      SectionLabel(state: state, label: '手动添加记忆'),
      CardShell(
        state: state,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: memoryController,
                style: state.textStyle(context, size: 14),
                decoration: inputDecoration(state, hint: '输入需要记住的信息...'),
                onSubmitted: (_) => addMemory(),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 112,
              child: SoftButton(
                state: state,
                label: '添加',
                icon: Icons.add_rounded,
                accent: true,
                onTap: addMemory,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      SoftButton(
        state: state,
        label: '清空所有记忆',
        icon: Icons.delete_sweep_outlined,
        danger: true,
        onTap: state.clearMemories,
      ),
    ]);
  }

  Widget providerConfigView() {
    final state = widget.state;
    final content = [
      SegmentedPills(
        state: state,
        value: providerTab,
        items: const {'config': '配置', 'models': '模型'},
        onChanged: (value) => updateSheet(() => providerTab = value),
      ),
      const SizedBox(height: 24),
      Center(
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              child: editingProvider == null
                  ? BrandIcon.named(
                      label: providerName.isEmpty ? 'Provider' : providerName,
                      color: state.accents[0],
                      size: 64,
                      radius: 24,
                      padding: 13,
                    )
                  : BrandIcon.provider(
                      provider: editingProvider!,
                      size: 64,
                      radius: 24,
                      padding: 13,
                    ),
            ),
            const SizedBox(height: 14),
            if (editingProvider == null)
              SizedBox(
                width: 220,
                child: TextField(
                  textAlign: TextAlign.center,
                  controller: providerNameController,
                  onChanged: (value) => updateSheet(() {
                    providerName = value;
                  }),
                  style: state.textStyle(
                    context,
                    size: 20,
                    weight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    hintText: '自定义提供商名称',
                    border: UnderlineInputBorder(),
                  ),
                ),
              )
            else
              Text(
                providerName,
                style: state.textStyle(
                  context,
                  size: 20,
                  weight: FontWeight.w500,
                ),
              ),
            const SizedBox(height: 6),
            Text(
              editingProvider?.enabled == false
                  ? '此提供商已禁用，模型不会参与默认选择'
                  : '配置此提供商的API凭据以启用相关模型',
              style: state.textStyle(context, size: 13, opacity: 0.52),
            ),
          ],
        ),
      ),
      const SizedBox(height: 26),
      if (providerTab == 'config') ...[
        Text(
          'API Key',
          style: state.textStyle(
            context,
            size: 13,
            weight: FontWeight.w600,
            opacity: 0.62,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: providerKeyController,
          obscureText: true,
          onChanged: (value) => providerKey = value,
          style: state.textStyle(context, size: 14),
          decoration: inputDecoration(state, hint: '请输入 Provider API Key...'),
        ),
        const SizedBox(height: 18),
        Text(
          'Base URL',
          style: state.textStyle(
            context,
            size: 13,
            weight: FontWeight.w600,
            opacity: 0.62,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: providerBaseUrlController,
          onChanged: (value) => providerBaseUrl = value,
          style: state.textStyle(context, size: 14),
          decoration: inputDecoration(
            state,
            hint: 'https://api.example.com/v1',
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'API Key 仅存储在本机；Android 上由 Keystore 加密，不会被发送给除所选模型服务外的第三方。',
          style: state.textStyle(
            context,
            size: 11,
            opacity: 0.42,
            height: 1.45,
          ),
        ),
      ] else ...[
        if (!_providerReadyForModels)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 34, 10, 34),
            child: Column(
              children: [
                Icon(
                  Icons.key_off_outlined,
                  size: 28,
                  color: state.text(context).withValues(alpha: 0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  '请先在「配置」中填写 API Key 并保存',
                  textAlign: TextAlign.center,
                  style: state.textStyle(context, size: 13.5, opacity: 0.6),
                ),
                const SizedBox(height: 5),
                Text(
                  '保存成功后即可拉取或手动添加模型。',
                  textAlign: TextAlign.center,
                  style: state.textStyle(
                    context,
                    size: 12,
                    opacity: 0.44,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          )
        else if (providerModels.isEmpty)
          Padding(
            padding: const EdgeInsets.all(28),
            child: Text(
              '暂无可用模型，请拉取或手动添加',
              textAlign: TextAlign.center,
              style: state.textStyle(context, size: 13, opacity: 0.42),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 126,
            ),
            itemCount: providerModels.length,
            itemBuilder: (context, index) {
              final model = providerModels[index];
              return DragTarget<String>(
                onWillAcceptWithDetails: (details) =>
                    details.data != model.id,
                onAcceptWithDetails: (details) {
                  final fromIndex = providerModels.indexWhere(
                    (m) => m.id == details.data,
                  );
                  if (fromIndex < 0 || fromIndex == index) return;
                  updateSheet(() {
                    final target = providerModels.removeAt(fromIndex);
                    providerModels.insert(index, target);
                  });
                },
                builder: (context, candidateData, rejectedData) {
                  final hovering = candidateData.isNotEmpty;
                  return LongPressDraggable<String>(
                    data: model.id,
                    delay: const Duration(milliseconds: 260),
                    dragAnchorStrategy: pointerDragAnchorStrategy,
                    rootOverlay: true,
                    feedback: SizedBox(
                      width: 210,
                      child: Material(
                        color: Colors.transparent,
                        child: _ProviderModelGridCard(
                          state: state,
                          model: model,
                          providerName: providerName,
                          onTap: () => editModel(model),
                          highlighted: true,
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.4,
                      child: _ProviderModelGridCard(
                        state: state,
                        model: model,
                        providerName: providerName,
                        onTap: () => editModel(model),
                      ),
                    ),
                    child: Dismissible(
                      key: ValueKey('provider_model_${model.id}'),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        updateSheet(
                          () => providerModels = providerModels
                              .where((m) => m.id != model.id)
                              .toList(),
                        );
                        return false;
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 14),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.red.withValues(alpha: 0.82),
                        ),
                      ),
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 140),
                        curve: Curves.easeOutCubic,
                        scale: hovering ? 0.97 : 1,
                        child: _ProviderModelGridCard(
                          state: state,
                          model: model,
                          providerName: providerName,
                          onTap: () => editModel(model),
                          highlighted: hovering,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
      ],
    ];

    return bottomActionPage(
      children: content,
      status: statusText,
      actions: providerTab == 'config'
          ? Row(
              children: [
                Expanded(
                  child: SoftButton(
                    state: state,
                    label: '保存配置',
                    accent: true,
                    onTap: () => saveProvider(false),
                  ),
                ),
                if (editingProvider != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: SoftButton(
                      state: state,
                      label: editingProvider!.enabled ? '禁用提供商' : '重新启用',
                      danger: editingProvider!.enabled,
                      onTap: () => saveProvider(
                        false,
                        enabledOverride: !editingProvider!.enabled,
                      ),
                    ),
                  ),
                ],
              ],
            )
          : !_providerReadyForModels
          ? Row(
              children: [
                Expanded(
                  child: SoftButton(
                    state: state,
                    label: '填写 API Key',
                    icon: Icons.key_rounded,
                    accent: true,
                    onTap: () => updateSheet(() => providerTab = 'config'),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: SoftButton(
                    state: state,
                    label: '添加模型',
                    icon: Icons.add_rounded,
                    accent: true,
                    onTap: addManualModel,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SoftButton(
                    state: state,
                    label: '拉取',
                    onTap: pullModels,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SoftButton(
                    state: state,
                    label: '测试',
                    onTap: testProvider,
                  ),
                ),
              ],
            ),
    );
  }

  Widget modelRoleConfigView() {
    final state = widget.state;
    final role = editingRole ?? 'chat';
    final providers = [
      ...state.enabledModelProviders,
      if (roleDraft.provider.isNotEmpty &&
          !state.enabledModelProviders.any((p) => p.name == roleDraft.provider))
        ...state.providers.where((p) => p.name == roleDraft.provider),
    ];
    final allProviderModels =
        providers
            .firstWhereOrNull((p) => p.name == roleDraft.provider)
            ?.models ??
        const <AiModel>[];
    final providerModels = allProviderModels
        .where(
          (model) => supportsModelRole(
            role: role,
            id: model.id,
            name: model.name,
            capabilities: model.capabilities,
          ),
        )
        .toList();
    final incompatibleSelection = _validateRoleDraft(
      role: role,
      draft: roleDraft,
      providers: providers,
    );
    return scrollContent([
      SectionLabel(state: state, label: '默认模型'),
      CardShell(
        state: state,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownField(
              state: state,
              label: '提供商',
              value: roleDraft.provider.isEmpty ? '未选择' : roleDraft.provider,
              items: ['未选择', ...providers.map((p) => p.name)],
              itemDescriptions: {
                for (final provider in providers)
                  provider.name: (() {
                    final compatibleCount = provider.models
                        .where(
                          (model) => supportsModelRole(
                            role: role,
                            id: model.id,
                            name: model.name,
                            capabilities: model.capabilities,
                          ),
                        )
                        .length;
                    if (compatibleCount == 0) {
                      return '无兼容模型';
                    }
                    if (provider.status == '使用中') {
                      return '当前启用 · $compatibleCount 个兼容模型';
                    }
                    return '$compatibleCount 个兼容模型';
                  })(),
              },
              onChanged: (value) => updateSheet(() {
                roleDraft = roleDraft.copyWith(
                  provider: value == '未选择' ? '' : value,
                  model: '',
                );
              }),
            ),
            const SizedBox(height: 14),
            DropdownField(
              state: state,
              label: '模型',
              value: roleDraft.model.isEmpty ? '未选择' : roleDraft.model,
              items: ['未选择', ...providerModels.map((m) => m.name)],
              itemDescriptions: {
                for (final model in providerModels) model.name: model.id,
              },
              enabled: roleDraft.provider.isNotEmpty,
              onChanged: (value) => updateSheet(() {
                roleDraft = roleDraft.copyWith(
                  model: value == '未选择' ? '' : value,
                );
              }),
            ),
            const SizedBox(height: 12),
            Text(
              incompatibleSelection ??
                  (roleDraft.provider.isNotEmpty && providerModels.isEmpty
                      ? '当前提供商没有适合${_roleLabel(role)}的模型。'
                      : _roleCapabilityHint(role)),
              style: state.textStyle(
                context,
                size: 12,
                opacity: incompatibleSelection == null ? 0.5 : 0.82,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      SectionLabel(state: state, label: '系统提示词 (System Prompt)'),
      CardShell(
        state: state,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              key: const ValueKey('role-prompt-field'),
              controller: rolePromptController,
              maxLines: 7,
              style: state.textStyle(context, size: 14, height: 1.55),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '输入自定义提示词...',
              ),
              onChanged: (value) => updateSheet(
                () => roleDraft = roleDraft.copyWith(prompt: value),
              ),
            ),
            DividerLine(state: state),
            Row(
              children: [
                Text(
                  '${roleDraft.prompt.length} 字符',
                  style: state.textStyle(context, size: 11, opacity: 0.42),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => updateSheet(() {
                    final prompt =
                        ModelAssignment.defaults()[editingRole]!.prompt;
                    roleDraft = roleDraft.copyWith(prompt: prompt);
                    rolePromptController
                      ..text = prompt
                      ..selection = TextSelection.collapsed(
                        offset: prompt.length,
                      );
                  }),
                  child: const Text('恢复默认'),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      SoftButton(
        state: state,
        label: '保存设置',
        accent: true,
        onTap: () {
          final currentRole = editingRole;
          if (currentRole == null) return;
          final validationMessage = _validateRoleDraft(
            role: currentRole,
            draft: roleDraft,
            providers: providers,
          );
          if (validationMessage != null) {
            updateSheet(() => statusText = validationMessage);
            widget.showSnack(validationMessage);
            return;
          }
          state.saveModelAssignment(currentRole, roleDraft);
          goBack();
        },
      ),
    ]);
  }

  Widget searchConfigView() {
    final state = widget.state;
    return scrollContent([
      Text(
        '配置 Tavily API Key。您可以在 Tavily 控制台注册并获取密钥。',
        style: state.textStyle(context, size: 13, opacity: 0.55, height: 1.5),
      ),
      const SizedBox(height: 20),
      for (final engine in SettingsSheetState.settingsEngines)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: CardShell(
            state: state,
            padding: const EdgeInsets.all(16),
            borderColor: state.searchConfig.active == engine.$1
                ? state.accents[0]
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => state.saveSearchConfig(
                    state.searchConfig.copyWith(active: engine.$1),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: Row(
                      children: [
                        RadioDot(
                          active: state.searchConfig.active == engine.$1,
                          color: state.accents[0],
                        ),
                        const SizedBox(width: 12),
                        Text(
                          engine.$2,
                          style: state.textStyle(
                            context,
                            size: 15,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (state.searchConfig.active == engine.$1) ...[
                  const SizedBox(height: 16),
                  DividerLine(state: state),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: ValueKey('search-key-${engine.$1}'),
                    initialValue: state.searchConfig.keys[engine.$1] ?? '',
                    obscureText: true,
                    onChanged: (value) {
                      state.saveSearchConfig(
                        state.searchConfig.copyWith(
                          keys: {...state.searchConfig.keys, engine.$1: value},
                        ),
                      );
                    },
                    style: state.textStyle(context, size: 14),
                    decoration: inputDecoration(
                      state,
                      hint: '输入 ${engine.$2} 的 API Key',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    engine.$3,
                    style: state.textStyle(context, size: 12, opacity: 0.42),
                  ),
                ],
              ],
            ),
          ),
        ),
    ]);
  }

  Widget ttsConfigView() {
    final state = widget.state;
    TtsProviderConfig withTtsPreset(TtsProviderConfig source, String type) {
      if (type == 'xiaomi') {
        return source.copyWith(
          type: type,
          name: source.name.trim().isEmpty ? 'Xiaomi MiMo TTS' : source.name,
          baseUrl: source.baseUrl.trim().isEmpty
              ? 'https://api.xiaomimimo.com/v1'
              : source.baseUrl,
          model: source.model.trim().isEmpty ? 'mimo-v2-tts' : source.model,
          voice: source.voice.trim().isEmpty ? 'default_en' : source.voice,
        );
      }
      if (type == 'openai') {
        return source.copyWith(
          type: type,
          baseUrl: source.baseUrl.trim().isEmpty
              ? 'https://api.openai.com/v1'
              : source.baseUrl,
          model: source.model.trim().isEmpty ? 'gpt-4o-mini-tts' : source.model,
          voice: source.voice.trim().isEmpty ? 'alloy' : source.voice,
        );
      }
      return source.copyWith(type: type);
    }

    var draft =
        editingTts ??
        TtsProviderConfig(
          id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
          type: 'openai',
          name: '自定义 TTS',
          apiKey: '',
          baseUrl: 'https://api.openai.com/v1',
          model: 'gpt-4o-mini-tts',
          voice: 'alloy',
        );
    return StatefulBuilder(
      builder: (context, setLocal) {
        Widget field({
          required String label,
          required String value,
          required ValueChanged<String> onChanged,
          String hint = '',
          bool obscure = false,
        }) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: state.textStyle(
                  context,
                  size: 14,
                  weight: FontWeight.w600,
                  opacity: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: ValueKey('tts-${draft.id}-${draft.type}-$label'),
                initialValue: value,
                obscureText: obscure,
                onChanged: (value) => setLocal(() => onChanged(value)),
                style: state.textStyle(context, size: 15),
                decoration: inputDecoration(state, hint: hint),
              ),
              const SizedBox(height: 16),
            ],
          );
        }

        return scrollContent([
          Text(
            '提供商类型',
            style: state.textStyle(
              context,
              size: 14,
              weight: FontWeight.w600,
              opacity: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: draft.type,
            decoration: inputDecoration(state),
            items: const [
              DropdownMenuItem(value: 'xiaomi', child: Text('Xiaomi MiMo TTS')),
              DropdownMenuItem(value: 'openai', child: Text('OpenAI TTS')),
              DropdownMenuItem(value: 'custom', child: Text('自定义 (Custom)')),
            ],
            onChanged: (value) => setLocal(() {
              final nextType = value ?? draft.type;
              draft = withTtsPreset(draft, nextType);
              editingTts = draft;
            }),
          ),
          const SizedBox(height: 16),
          field(
            label: '显示名称',
            value: draft.name,
            hint: '例如：OpenAI 语音',
            onChanged: (value) {
              draft = draft.copyWith(name: value);
              editingTts = draft;
            },
          ),
          if (draft.type != 'edge')
            field(
              label: 'API Key',
              value: draft.apiKey,
              hint: 'Bearer Token 或 API 密钥',
              obscure: true,
              onChanged: (value) {
                draft = draft.copyWith(apiKey: value);
                editingTts = draft;
              },
            ),
          field(
            label: 'Base URL',
            value: draft.baseUrl,
            hint: draft.type == 'xiaomi'
                ? 'https://api.xiaomimimo.com/v1'
                : 'https://api.openai.com/v1',
            onChanged: (value) {
              draft = draft.copyWith(baseUrl: value);
              editingTts = draft;
            },
          ),
          field(
            label: '模型名称 (Model)',
            value: draft.model,
            hint: draft.type == 'xiaomi'
                ? 'mimo-v2-tts'
                : '例如: tts-1, tts-1-hd',
            onChanged: (value) {
              draft = draft.copyWith(model: value);
              editingTts = draft;
            },
          ),
          field(
            label: '合成语音 (Voice)',
            value: draft.voice,
            hint: draft.type == 'xiaomi'
                ? 'default_en'
                : '例如: alloy, echo, fable',
            onChanged: (value) {
              draft = draft.copyWith(voice: value);
              editingTts = draft;
            },
          ),
          if (draft.id != 'xiaomi')
            TextButton.icon(
              onPressed: () {
                final next = state.ttsProviders
                    .where((t) => t.id != draft.id)
                    .toList();
                state.saveTtsConfig(
                  next,
                  state.activeTtsId == draft.id ? '' : state.activeTtsId,
                );
                goBack();
              },
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('删除此提供商'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          const SizedBox(height: 12),
          SoftButton(
            state: state,
            label: '保存设置',
            accent: true,
            onTap: () {
              final normalizedDraft = draft.copyWith(
                baseUrl: normalizeBaseUrl(draft.baseUrl),
              );
              final baseUrlIssue = secureBaseUrlIssue(normalizedDraft.baseUrl);
              if (baseUrlIssue != null) {
                widget.showSnack(baseUrlIssue);
                return;
              }
              final next = [...state.ttsProviders];
              final index = next.indexWhere((t) => t.id == normalizedDraft.id);
              if (index >= 0) {
                next[index] = normalizedDraft;
              } else {
                next.add(normalizedDraft);
              }
              state.saveTtsConfig(next, state.activeTtsId);
              goBack();
            },
          ),
        ]);
      },
    );
  }

  Widget feedbackView() {
    final state = widget.state;
    Widget field({
      required String label,
      required TextEditingController controller,
      required String hint,
      int minLines = 1,
      int maxLines = 1,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: state.textStyle(
              context,
              size: 13,
              weight: FontWeight.w700,
              opacity: 0.62,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            minLines: minLines,
            maxLines: maxLines,
            style: state.textStyle(context, size: 14, height: 1.55),
            decoration: inputDecoration(state, hint: hint),
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    Widget typeButton(String value, String label, IconData icon) {
      final selected = feedbackType == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => updateSheet(() => feedbackType = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? state.accents[0].withValues(alpha: 0.18)
                  : state.text(context).withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? state.accents[0].withValues(alpha: 0.62)
                    : state.text(context).withValues(alpha: 0.055),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: selected
                      ? state.accents[0]
                      : state.text(context).withValues(alpha: 0.46),
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: state.textStyle(
                    context,
                    size: 13,
                    weight: FontWeight.w700,
                    opacity: selected ? 0.94 : 0.54,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return bottomActionPage(
      status: statusText,
      children: [
        Text(
          '把问题、建议或体验反馈整理成结构化表单。后续接入邮箱后，这里会直接发送到反馈邮箱。',
          style: state.textStyle(
            context,
            size: 13,
            opacity: 0.56,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 18),
        SectionLabel(state: state, label: '反馈类型'),
        Row(
          children: [
            typeButton('问题反馈', '问题', Icons.bug_report_outlined),
            const SizedBox(width: 10),
            typeButton('功能建议', '建议', Icons.lightbulb_outline_rounded),
            const SizedBox(width: 10),
            typeButton('体验优化', '体验', Icons.auto_awesome_outlined),
          ],
        ),
        const SizedBox(height: 22),
        field(
          label: '标题',
          controller: feedbackTitleController,
          hint: '例如：设置页面切换异常',
        ),
        field(
          label: '详细描述',
          controller: feedbackDetailController,
          hint: '描述你遇到的问题、期望效果或改进建议...',
          minLines: 5,
          maxLines: 8,
        ),
        field(
          label: '复现步骤 / 建议说明',
          controller: feedbackStepsController,
          hint: '1. 打开...\n2. 点击...\n3. 出现...',
          minLines: 4,
          maxLines: 7,
        ),
        field(
          label: '联系方式（可选）',
          controller: feedbackContactController,
          hint: '邮箱、QQ 或其他联系方式',
        ),
      ],
      actions: Row(
        children: [
          Expanded(
            child: SoftButton(state: state, label: '取消', onTap: goBack),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: SoftButton(
              state: state,
              label: '提交',
              icon: Icons.send_rounded,
              accent: true,
              onTap: submitFeedbackForm,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderModelGridCard extends StatelessWidget {
  const _ProviderModelGridCard({
    required this.state,
    required this.model,
    required this.providerName,
    required this.onTap,
    this.highlighted = false,
  });

  final WeaviewState state;
  final AiModel model;
  final String providerName;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final dark = state.isDark(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          decoration: BoxDecoration(
            color: highlighted
                ? state.accents[0].withValues(alpha: dark ? 0.14 : 0.09)
                : (dark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.white.withValues(alpha: 0.82)),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: highlighted
                  ? state.accents[0].withValues(alpha: 0.5)
                  : state.text(context).withValues(alpha: 0.07),
              width: highlighted ? 1.2 : 0.8,
            ),
            boxShadow: highlighted
                ? [
                    BoxShadow(
                      color: state.accents[0].withValues(alpha: 0.14),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BrandIcon.model(
                    model: model,
                    providerName: providerName,
                    size: 30,
                    radius: 10,
                    padding: 5,
                  ),
                  const Spacer(),
                  if (highlighted)
                    Icon(
                      Icons.drag_indicator_rounded,
                      size: 14,
                      color: state.accents[0].withValues(alpha: 0.7),
                    )
                  else
                    Icon(
                      Icons.drag_indicator_rounded,
                      size: 13,
                      color: state.text(context).withValues(alpha: 0.22),
                    ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                model.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: state.textStyle(
                  context,
                  size: 12.5,
                  weight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              if (model.id != model.name) ...[
                const SizedBox(height: 2),
                Text(
                  model.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: state.textStyle(
                    context,
                    size: 9.5,
                    opacity: 0.42,
                  ),
                ),
              ],
              const SizedBox(height: 7),
              ModelCapabilityChips(
                state: state,
                capabilities: model.capabilities,
                compact: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
