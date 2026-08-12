// ignore_for_file: use_key_in_widget_constructors

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../../app/app_constants.dart';
import '../../../app/app_version.dart';
import '../../../app/weaview_state.dart';
import '../../../core/app_utils.dart';
import '../../../domain/models.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../settings_sheet.dart';

extension SettingsTabs on SettingsSheetState {
  Widget generalTab() {
    final state = widget.state;
    return scrollContent([
      SectionLabel(state: state, label: '外观'),
      CardShell(
        state: state,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '主题',
                          style: state.textStyle(
                            context,
                            size: 15,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '选择浅色、深色或跟随系统',
                          style: state.textStyle(
                            context,
                            size: 12,
                            opacity: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: _ThemeSegmentedControl(
                      state: state,
                      current: state.themeMode,
                      onSelected: state.setThemeModeValue,
                    ),
                  ),
                ],
              ),
            ),
            DividerLine(state: state),
            SettingsRow(
              state: state,
              title: '强调色',
              subtitle: '按钮、选中状态与动效使用的颜色',
              showChevron: true,
              onTap: () {
                _showAccentPalette();
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: state.accents.first,
                      border: Border.all(
                        color: state.text(context).withValues(alpha: 0.10),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: state.accents.first.withValues(alpha: 0.22),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 28),
      SectionLabel(state: state, label: '个人资料'),
      CardShell(
        state: state,
        child: Column(
          children: [
            SettingsRow(
              state: state,
              title: '昵称',
              subtitle: '在对话与侧边栏中显示',
              showChevron: true,
              onTap: () {
                _showNicknameEditor();
              },
              trailing: _ValuePill(state: state, text: state.userName),
            ),
            DividerLine(state: state),
            SettingsRow(
              state: state,
              title: '个人头像',
              subtitle: '用于展示你的个人形象',
              onTap: () => widget.onPickAvatar(true),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.userAvatar.isNotEmpty)
                    TinyIcon(
                      icon: Icons.delete_outline_rounded,
                      color: Colors.red,
                      onTap: () => state.updateUserAvatar(''),
                    ),
                  AvatarDot(
                    value: state.userAvatar,
                    fallbackIcon: Icons.person_outline_rounded,
                    imageSize: 42,
                    accent: state.accents[0],
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: state.text(context).withValues(alpha: 0.35),
                  ),
                ],
              ),
            ),
            DividerLine(state: state),
            SettingsRow(
              state: state,
              title: '人物画像',
              subtitle: state.userProfile.trim().isEmpty
                  ? '记录偏好、项目和沟通方式'
                  : state.userProfile.replaceAll('\n', ' '),
              showChevron: true,
              onTap: () => updateSheet(() {
                profileController.text = state.userProfile;
                subView = 'user_profile';
              }),
            ),
          ],
        ),
      ),
      const SizedBox(height: 28),
      SectionLabel(state: state, label: 'AI 个性化'),
      CardShell(
        state: state,
        child: Column(
          children: [
            SettingsRow(
              state: state,
              title: '全局系统提示词',
              subtitle: state.systemPrompt.replaceAll('\n', ' '),
              leading: AvatarDot(
                value: state.assistantAvatar,
                fallbackIcon: Icons.person_outline_rounded,
                imageSize: 42,
                accent: state.accents[0],
              ),
              showChevron: true,
              onTap: () => updateSheet(() {
                systemPromptController.text = state.systemPrompt;
                subView = 'system_prompt';
              }),
            ),
            DividerLine(state: state),
            SettingsRow(
              state: state,
              title: '助手头像',
              subtitle: '自定义 AI 伙伴的形象',
              showChevron: false,
              onTap: () => widget.onPickAvatar(false),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.assistantAvatar.isNotEmpty)
                    TinyIcon(
                      icon: Icons.delete_outline_rounded,
                      color: Colors.red,
                      onTap: () => state.updateAssistantAvatar(''),
                    ),
                  TinyIcon(
                    icon: Icons.edit_outlined,
                    color: state.text(context),
                    onTap: () => widget.onPickAvatar(false),
                  ),
                ],
              ),
            ),
            DividerLine(state: state),
            SettingsRow(
              state: state,
              title: '情绪化回应',
              subtitle: '控制回应中的感性表达',
              showChevron: false,
              onTap: () => state.setEmotionEnabled(!state.emotionEnabled),
              trailing: WeaveSwitch(
                state: state,
                value: state.emotionEnabled,
                onChanged: state.setEmotionEnabled,
              ),
            ),
            DividerLine(state: state),
            SettingsRow(
              state: state,
              title: '记忆管理',
              subtitle: '查看或清除AI长效记忆',
              showChevron: true,
              onTap: () => updateSheet(() => subView = 'memory_management'),
            ),
          ],
        ),
      ),
    ]);
  }

  Future<void> _showAccentPalette() async {
    final state = widget.state;
    const options = <({String label, Color color})>[
      (label: '薄荷', color: Color(0xFF70D8C7)),
      (label: '海蓝', color: Color(0xFF3487F3)),
      (label: '紫罗兰', color: Color(0xFF7C6CF2)),
      (label: '珊瑚', color: Color(0xFFF06A73)),
      (label: '琥珀', color: Color(0xFFE49A32)),
      (label: '墨绿', color: Color(0xFF167D68)),
    ];
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Container(
        key: const ValueKey('accent_palette_sheet'),
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '选择强调色',
              style: state.textStyle(
                sheetContext,
                size: 20,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '会同步更新按钮、选中状态和界面光晕。',
              style: state.textStyle(sheetContext, size: 13, opacity: 0.56),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final option in options)
                  _AccentChoice(
                    state: state,
                    label: option.label,
                    color: option.color,
                    selected:
                        state.accents.first.toARGB32() ==
                        option.color.toARGB32(),
                    onTap: () {
                      state.setAccentColor(option.color);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNicknameEditor() async {
    final state = widget.state;
    var draft = state.userName;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextFormField(
          key: const ValueKey('nickname_editor_field'),
          initialValue: draft,
          autofocus: true,
          maxLength: 20,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: '昵称', hintText: '织梦者'),
          onChanged: (value) => draft = value,
          onFieldSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(draft),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result == null) return;
    state.updateUserName(result);
  }

  Widget providersTab() {
    final state = widget.state;
    final query = providerSearchController.text.trim().toLowerCase();
    final matchingProviders = state.providers.where((provider) {
      if (query.isEmpty) return true;
      return provider.name.toLowerCase().contains(query) ||
          provider.status.toLowerCase().contains(query) ||
          provider.models.any(
            (model) =>
                model.name.toLowerCase().contains(query) ||
                model.id.toLowerCase().contains(query),
          );
    }).toList();
    final assignedProviderNames = state.modelAssignments.values
        .map((assignment) => assignment.provider.trim())
        .where((provider) => provider.isNotEmpty)
        .toSet();
    final configuredCount = state.providers.where(_isProviderConfigured).length;
    final prioritizedProviders = <AiProvider>[];
    if (query.isEmpty && !showAllProviders) {
      const featuredNames = [
        'OpenAI',
        'Gemini',
        'Anthropic',
        'DeepSeek',
        'Grok',
        'Kimi',
      ];
      for (final provider in state.providers) {
        if (_isProviderConfigured(provider) ||
            provider.current ||
            assignedProviderNames.contains(provider.name)) {
          prioritizedProviders.add(provider);
        }
      }
      for (final name in featuredNames) {
        final provider = state.providers.firstWhereOrNull(
          (item) => item.name == name,
        );
        if (provider != null &&
            !prioritizedProviders.any((item) => item.name == provider.name)) {
          prioritizedProviders.add(provider);
        }
      }
      for (final provider in state.providers) {
        if (!prioritizedProviders.any((item) => item.name == provider.name)) {
          prioritizedProviders.add(provider);
        }
      }
    }
    final visibleProviders = query.isNotEmpty || showAllProviders
        ? matchingProviders
        : prioritizedProviders.take(6).toList();
    final hiddenProviderCount =
        matchingProviders.length - visibleProviders.length;

    void dropProviderOn(String providerName, int targetIndex) {
      final fromIndex = state.providers.indexWhere(
        (provider) => provider.name == providerName,
      );
      if (fromIndex < 0 || fromIndex == targetIndex) return;
      updateSheet(() {
        final newIndex = targetIndex > fromIndex
            ? targetIndex + 1
            : targetIndex;
        state.reorderProvider(fromIndex, newIndex);
      });
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => updateSheet(() {
        providerDeleteTarget = null;
        draggingProviderName = null;
      }),
      child: scrollContent([
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '模型提供商',
                    style: state.poeticTextStyle(
                      context,
                      size: 23,
                      weight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '已配置 $configuredCount / ${state.providers.length} 个提供商',
                    style: state.textStyle(context, size: 13, opacity: 0.56),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: () => openProviderConfig(null),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('自定义提供商'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: providerSearchController,
          onChanged: (_) => updateSheet(() {}),
          style: state.textStyle(context, size: 13.5),
          decoration: InputDecoration(
            hintText: '搜索提供商',
            hintStyle: state.textStyle(context, size: 13.5, opacity: 0.36),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 19,
              color: state.text(context).withValues(alpha: 0.42),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 42,
              minHeight: 42,
            ),
            isDense: true,
            filled: true,
            fillColor: state.isDark(context)
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.72),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: state.text(context).withValues(alpha: 0.07),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: state.text(context).withValues(alpha: 0.07),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: state.accents[0].withValues(alpha: 0.42),
                width: 1.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSize(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                if (visibleProviders.isEmpty)
                  CardShell(
                    state: state,
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Text(
                        '没有匹配的提供商',
                        style: state.textStyle(
                          context,
                          size: 14,
                          opacity: 0.56,
                        ),
                      ),
                    ),
                  ),
                for (
                  var index = 0;
                  index < visibleProviders.length;
                  index++
                ) ...[
                  Builder(
                    key: ValueKey('provider_${visibleProviders[index].name}'),
                    builder: (context) {
                      final provider = visibleProviders[index];
                      final actualIndex = state.providers.indexWhere(
                        (item) => item.name == provider.name,
                      );
                      final isCurrent =
                          provider.enabled &&
                          (provider.current || provider.status == '使用中');
                      final assigned = assignedProviderNames.contains(
                        provider.name,
                      );
                      final active =
                          provider.enabled && (isCurrent || assigned);
                      final activeLabel = isCurrent
                          ? '当前'
                          : assigned
                          ? '已选择'
                          : null;
                      final controlsVisible =
                          providerDeleteTarget == provider.name;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: DragTarget<String>(
                          onWillAcceptWithDetails: (details) =>
                              details.data != provider.name,
                          onAcceptWithDetails: (details) {
                            dropProviderOn(details.data, actualIndex);
                            updateSheet(() {
                              draggingProviderName = null;
                            });
                          },
                          builder: (context, candidateData, rejectedData) {
                            final hovering = candidateData.isNotEmpty;
                            final row = _ProviderGridCard(
                              state: state,
                              provider: provider,
                              active: active,
                              activeLabel: activeLabel,
                              controlsVisible: controlsVisible,
                              highlighted: hovering,
                              onEdit: () => openProviderConfig(provider),
                              onDelete: () =>
                                  confirmDeleteProvider(provider.name),
                              onToggle: (value) =>
                                  state.setProviderEnabled(provider.name, value),
                            );
                            return LongPressDraggable<String>(
                              data: provider.name,
                              delay: const Duration(milliseconds: 320),
                              dragAnchorStrategy: pointerDragAnchorStrategy,
                              rootOverlay: true,
                              feedback: SizedBox(
                                width: 420,
                                child: Material(
                                  color: Colors.transparent,
                                  child: row,
                                ),
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.46,
                                child: row,
                              ),
                              onDragStarted: () => updateSheet(() {
                                providerDeleteTarget = provider.name;
                                draggingProviderName = provider.name;
                              }),
                              onDraggableCanceled: (_, _) => updateSheet(() {
                                draggingProviderName = null;
                              }),
                              onDragEnd: (_) => updateSheet(() {
                                draggingProviderName = null;
                              }),
                              child: AnimatedScale(
                                duration: const Duration(milliseconds: 140),
                                curve: Curves.easeOutCubic,
                                scale: draggingProviderName == provider.name
                                    ? 0.98
                                    : hovering
                                    ? 0.992
                                    : 1,
                                child: row,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        if (query.isEmpty && (hiddenProviderCount > 0 || showAllProviders)) ...[
          const SizedBox(height: 10),
          Center(
            child: TextButton.icon(
              key: const ValueKey('toggle_all_providers'),
              onPressed: () => updateSheet(() {
                showAllProviders = !showAllProviders;
              }),
              icon: Icon(
                showAllProviders
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
              ),
              label: Text(
                showAllProviders
                    ? '收起提供商'
                    : '查看全部 ${matchingProviders.length} 个',
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Text(
          '点按进入配置，长按可调整顺序；仅已连接且启用的提供商参与模型分配。',
          style: state.textStyle(context, size: 12, opacity: 0.46),
        ),
        const SizedBox(height: 16),
        CardShell(
          state: state,
          child: SettingsRow(
            state: state,
            title: '导入备份配置',
            subtitle: '前往数据管理恢复提供商与默认模型分配',
            leading: Icon(
              Icons.upload_file_outlined,
              color: state.text(context).withValues(alpha: 0.66),
            ),
            showChevron: true,
            onTap: () => updateSheet(() => subView = 'more_data'),
          ),
        ),
      ]),
    );
  }

  Widget modelsTab() {
    final state = widget.state;
    return scrollContent([
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '默认模型',
                  style: state.textStyle(
                    context,
                    size: 23,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '设置主对话与生图模型',
                  style: state.textStyle(context, size: 13, opacity: 0.56),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton.icon(
            onPressed: () {
              for (final entry in ModelAssignment.defaults().entries) {
                state.saveModelAssignment(entry.key, entry.value);
              }
              updateSheet(() {});
            },
            icon: const Icon(Icons.undo_rounded, size: 18),
            label: const Text('恢复默认'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      CardShell(
        state: state,
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: state.text(context).withValues(alpha: 0.46),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '标题、建议、翻译与工具任务会自动复用主对话模型，保持配置简单。',
                style: state.textStyle(context, size: 13, opacity: 0.62),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      SectionLabel(state: state, label: '常用模型'),
      CardShell(
        state: state,
        child: Column(
          children: [
            for (var index = 0; index < 2; index++) ...[
              if (index > 0) DividerLine(state: state),
              Builder(
                builder: (context) {
                  final role = index == 0 ? 'chat' : 'image';
                  final entry = SettingsSheetState.settingsRoles[role]!;
                  final assignment = state.modelAssignments[role]!;
                  return SettingsRow(
                    state: state,
                    title: entry.$1,
                    subtitle: assignment.model.trim().isEmpty
                        ? entry.$2
                        : _assignmentSubtitle(assignment),
                    leading: _SettingsIconBadge(
                      state: state,
                      icon: _roleIcon(role),
                    ),
                    showChevron: true,
                    trailing: _ModelAssignmentBadge(
                      state: state,
                      provider: assignment.provider,
                      model: assignment.model,
                    ),
                    onTap: () {
                      updateSheet(() {
                        editingRole = role;
                        roleDraft = assignment;
                        subView = 'model_role_config';
                      });
                    },
                  );
                },
              ),
            ],
          ],
        ),
      ),
    ]);
  }

  Widget moreTab() {
    final state = widget.state;
    return scrollContent([
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '更多',
                  style: state.textStyle(
                    context,
                    size: 23,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '常用之外的一切',
                  style: state.textStyle(context, size: 13, opacity: 0.56),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      CardShell(
        state: state,
        child: Column(
          children: [
            SettingsRow(
              state: state,
              title: '联网与语音',
              subtitle: '搜索服务、朗读与自定义 TTS',
              leading: _SettingsIconBadge(
                state: state,
                icon: Icons.language_rounded,
              ),
              showChevron: true,
              onTap: () => updateSheet(() => subView = 'more_services'),
            ),
            DividerLine(state: state),
            SettingsRow(
              state: state,
              title: '数据与备份',
              subtitle: '导入导出、缓存与本地数据',
              leading: _SettingsIconBadge(
                state: state,
                icon: Icons.inventory_2_outlined,
              ),
              showChevron: true,
              onTap: () => updateSheet(() => subView = 'more_data'),
            ),
            DividerLine(state: state),
            SettingsRow(
              state: state,
              title: '关于与反馈',
              subtitle: '版本信息、开源许可与问题反馈',
              leading: _SettingsIconBadge(
                state: state,
                icon: Icons.info_outline_rounded,
              ),
              showChevron: true,
              onTap: () => updateSheet(() => subView = 'more_about'),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget servicesTab() {
    final state = widget.state;
    final activeSearchEngine = SettingsSheetState.settingsEngines.firstWhere(
      (engine) => engine.$1 == state.searchConfig.active,
      orElse: () => SettingsSheetState.settingsEngines.first,
    );
    final searchConnected =
        (state.searchConfig.keys[state.searchConfig.active]
            ?.trim()
            .isNotEmpty ??
        false);
    return scrollContent([
      SectionLabel(state: state, label: '联网与检索'),
      CardShell(
        state: state,
        child: Column(
          children: [
            SettingsRow(
              state: state,
              title: '搜索服务',
              subtitle: searchConnected
                  ? '${activeSearchEngine.$2} · 已连接'
                  : '${activeSearchEngine.$2} · 待配置 API Key',
              leading: _SettingsIconBadge(
                state: state,
                icon: Icons.public_rounded,
              ),
              showChevron: true,
              trailing: _StatusPill(
                state: state,
                text: searchConnected ? '已连接' : '未完成',
                active: searchConnected,
              ),
              onTap: () => updateSheet(() => subView = 'search_engine_config'),
            ),
            DividerLine(state: state),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              child: Text(
                '支持配置 Tavily、Brave、Perplexity 等联网搜索服务，为对话提供实时信息来源。',
                style: state.textStyle(
                  context,
                  size: 12,
                  opacity: 0.58,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 28),
      SectionLabel(state: state, label: '语音服务'),
      CardShell(
        state: state,
        child: Column(
          children: [
            SettingsRow(
              state: state,
              title: '系统 TTS',
              leading: _SettingsIconBadge(
                state: state,
                icon: Icons.volume_up_outlined,
              ),
              subtitle: state.activeTtsId == 'system'
                  ? '已手动启用设备默认语音引擎'
                  : '使用设备默认语音引擎，需手动启用',
              trailing: WeaveSwitch(
                state: state,
                value: state.activeTtsId == 'system',
                onChanged: (value) => state.saveTtsConfig(
                  state.ttsProviders,
                  value ? 'system' : '',
                ),
              ),
            ),
            for (final tts in state.ttsProviders) ...[
              DividerLine(state: state),
              SettingsRow(
                state: state,
                title: tts.name,
                leading: _SettingsIconBadge(
                  state: state,
                  icon: state.activeTtsId == tts.id
                      ? Icons.record_voice_over_outlined
                      : Icons.graphic_eq_rounded,
                ),
                subtitle: state.activeTtsId == tts.id
                    ? '已启用 · ${tts.model.isNotEmpty ? tts.model : '待配置模型'}'
                    : tts.apiKey.isNotEmpty || tts.baseUrl.isNotEmpty
                    ? (tts.model.isNotEmpty ? tts.model : '已配置')
                    : '未配置',
                onTap: () {
                  updateSheet(() {
                    editingTts = tts;
                    subView = 'tts_config';
                  });
                },
                trailing: WeaveSwitch(
                  state: state,
                  value: state.activeTtsId == tts.id,
                  onChanged: (value) => state.saveTtsConfig(
                    state.ttsProviders,
                    value ? tts.id : '',
                  ),
                ),
              ),
            ],
            DividerLine(state: state),
            SettingsRow(
              state: state,
              title: '添加自定义 TTS 提供商',
              leading: _SettingsIconBadge(
                state: state,
                icon: Icons.add_rounded,
              ),
              onTap: () {
                updateSheet(() {
                  editingTts = TtsProviderConfig(
                    id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                    type: 'openai',
                    name: '自定义 TTS',
                    apiKey: '',
                    baseUrl: 'https://api.openai.com/v1',
                    model: 'gpt-4o-mini-tts',
                    voice: 'alloy',
                  );
                  subView = 'tts_config';
                });
              },
            ),
          ],
        ),
      ),
    ]);
  }

  Widget dataTab() {
    final state = widget.state;
    final sessionBytes = utf8
        .encode(jsonEncode(state.chatSessions.map((s) => s.toJson()).toList()))
        .length;
    final providerBytes = utf8
        .encode(jsonEncode(state.providers.map((p) => p.safeJson()).toList()))
        .length;
    final memoryBytes = utf8
        .encode(
          jsonEncode(state.memoryItems.map((item) => item.toJson()).toList()),
        )
        .length;
    final tokenUsageBytes = utf8
        .encode(
          jsonEncode(
            state.tokenUsageRecords.map((item) => item.toJson()).toList(),
          ),
        )
        .length;
    final configBytes = utf8
        .encode(
          jsonEncode({
            'modelAssignments': state.modelAssignments.map(
              (key, value) => MapEntry(key, value.toJson()),
            ),
            'searchConfig': state.searchConfig.safeJson(),
            'ttsProviders': state.ttsProviders
                .map((p) => p.safeJson())
                .toList(),
            'activeTtsId': state.activeTtsId,
            'userName': state.userName,
            'assistantName': state.assistantName,
            'userProfile': state.userProfile,
            'themeMode': state.themeMode.name,
            'bubbleStyle': state.bubbleStyle,
            'messageAlignment': state.messageAlignment,
          }),
        )
        .length;
    final total =
        sessionBytes +
        providerBytes +
        memoryBytes +
        tokenUsageBytes +
        configBytes;
    int segmentFlex(int bytes) {
      if (total <= 0) return 1;
      return math.max((bytes / total * 100).round(), 1);
    }

    return scrollContent([
      SectionLabel(state: state, label: '存储概览'),
      CardShell(
        state: state,
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '已使用 ${formatBytes(total)}',
                        style: state.textStyle(
                          context,
                          size: 28,
                          weight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '本地保存对话、记忆、用量与配置摘要',
                        style: state.textStyle(context, size: 12, opacity: 0.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _ValuePill(
                  state: state,
                  text: '${state.chatSessions.length} 个会话',
                ),
              ],
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    Expanded(
                      flex: segmentFlex(sessionBytes),
                      child: Container(color: const Color(0xFF0F9FA7)),
                    ),
                    Expanded(
                      flex: segmentFlex(memoryBytes),
                      child: Container(color: state.accents[0]),
                    ),
                    Expanded(
                      flex: segmentFlex(tokenUsageBytes),
                      child: Container(color: const Color(0xFFDDE6F4)),
                    ),
                    Expanded(
                      flex: segmentFlex(providerBytes),
                      child: Container(color: const Color(0xFF8FD7D3)),
                    ),
                    Expanded(
                      flex: segmentFlex(configBytes),
                      child: Container(color: const Color(0xFFC8D5EE)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            StorageRow(
              state: state,
              label: '对话记录',
              description: '历史会话、消息分支与消息内容',
              color: const Color(0xFF0F9FA7),
              bytes: sessionBytes,
              ratio: total == 0 ? 0 : sessionBytes / total,
            ),
            StorageRow(
              state: state,
              label: '记忆数据',
              description: '长期记忆与人物画像素材',
              color: state.accents[0],
              bytes: memoryBytes,
              ratio: total == 0 ? 0 : memoryBytes / total,
            ),
            StorageRow(
              state: state,
              label: 'Token 用量统计',
              description: '本地估算的 token 与花费记录',
              color: const Color(0xFFDDE6F4),
              bytes: tokenUsageBytes,
              ratio: total == 0 ? 0 : tokenUsageBytes / total,
            ),
            StorageRow(
              state: state,
              label: '提供商与模型',
              description: 'API 配置摘要、模型列表和能力标记',
              color: const Color(0xFF8FD7D3),
              bytes: providerBytes,
              ratio: total == 0 ? 0 : providerBytes / total,
            ),
            StorageRow(
              state: state,
              label: '应用偏好',
              description: '默认模型、搜索/TTS 与外观偏好',
              color: const Color(0xFFC8D5EE),
              bytes: configBytes,
              ratio: total == 0 ? 0 : configBytes / total,
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      SectionLabel(state: state, label: '备份与迁移'),
      CardShell(
        state: state,
        child: Column(
          children: [
            SettingsRow(
              state: state,
              title: '创建备份',
              subtitle: '导出本地 JSON 数据与说明文件',
              leading: _SettingsIconBadge(
                state: state,
                icon: Icons.backup_outlined,
              ),
              trailing: _InlineActionButton(
                state: state,
                label: '导出',
                accent: true,
                onTap: () async {
                  final fileName =
                      'weaview_backup_${DateTime.now().millisecondsSinceEpoch}.zip';
                  final path = await FilePicker.saveFile(
                    dialogTitle: '导出 Weaview 备份',
                    fileName: fileName,
                    bytes: state.exportZipBytes(),
                  );
                  if (path != null) {
                    widget.showSnack('备份已导出。');
                  } else {
                    widget.showSnack('已取消导出。');
                  }
                },
              ),
            ),
            DividerLine(state: state),
            SettingsRow(
              state: state,
              title: '导入备份',
              subtitle: '从 JSON 或 ZIP 恢复本地设置与历史',
              leading: _SettingsIconBadge(
                state: state,
                icon: Icons.upload_file_outlined,
              ),
              trailing: _InlineActionButton(
                state: state,
                label: '导入',
                onTap: _importBackup,
              ),
              onTap: _importBackup,
            ),
            DividerLine(state: state),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              child: Text(
                '备份文件会对敏感 API Key 进行脱敏处理，原始附件文件不会打包进备份。',
                style: state.textStyle(
                  context,
                  size: 12,
                  opacity: 0.54,
                  height: 1.48,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      SectionLabel(state: state, label: '数据内容说明'),
      CardShell(
        state: state,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
        child: Column(
          children: [
            _DataInfoLine(
              state: state,
              icon: Icons.chat_bubble_outline_rounded,
              title: '对话与历史梦境',
              body: '保存本机历史会话、消息分支、附件引用和置顶状态。',
            ),
            _DataInfoLine(
              state: state,
              icon: Icons.auto_awesome_rounded,
              title: '记忆与画像',
              body: '用于个性化回复的长期记忆、人物画像和相关开关状态。',
            ),
            _DataInfoLine(
              state: state,
              icon: Icons.payments_outlined,
              title: 'Token 用量统计',
              body: '保存本地估算的输入/输出 token、调用来源、模型和美元花费。',
            ),
            _DataInfoLine(
              state: state,
              icon: Icons.tune_rounded,
              title: '模型与服务配置',
              body: '包含提供商、模型能力、默认模型分配、搜索和 TTS 配置摘要。',
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      SectionLabel(state: state, label: '危险操作'),
      CardShell(
        state: state,
        borderColor: Colors.red.withValues(alpha: 0.20),
        child: Column(
          children: [
            SettingsRow(
              state: state,
              title: '清空所有本地数据',
              subtitle: '删除对话、记忆、提供商、模型分配与应用偏好',
              leading: _SettingsIconBadge(
                state: state,
                icon: Icons.warning_amber_rounded,
                danger: true,
              ),
              showChevron: true,
              onTap: confirmClearData,
            ),
            DividerLine(state: state),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              child: Text(
                '该操作不可撤销。执行前建议先导出备份。',
                style: state.textStyle(
                  context,
                  size: 12,
                  opacity: 0.58,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Center(
        child: Text(
          '数据默认仅保存在当前设备。',
          style: state.textStyle(context, size: 12, opacity: 0.44),
        ),
      ),
    ]);
  }

  Future<void> _importBackup() async {
    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: '导入 Weaview 备份',
        type: FileType.custom,
        allowedExtensions: const ['json', 'zip'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      if (file.size > WeaviewState.maxBackupArchiveBytes) {
        widget.showSnack(
          '备份文件超过 ${WeaviewState.maxBackupArchiveBytes ~/ (1024 * 1024)} MB 限制。',
        );
        return;
      }
      final bytes =
          file.bytes ??
          (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes == null || bytes.isEmpty) {
        widget.showSnack('备份文件为空或无法读取。');
        return;
      }
      final summary = await widget.state.importBackupBytes(
        Uint8List.fromList(bytes),
        fileName: file.name,
      );
      widget.showSnack(summary.summary);
    } catch (error) {
      widget.showSnack(
        '导入失败：${error.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  Widget aboutTab() {
    final state = widget.state;
    void openSuggestionFeedback() {
      FocusManager.instance.primaryFocus?.unfocus();
      updateSheet(() {
        feedbackType = '功能建议';
        feedbackTitleController.clear();
        feedbackDetailController.clear();
        feedbackStepsController.clear();
        feedbackContactController.clear();
        statusText = '';
        subView = 'feedback_form';
      });
    }

    return scrollContent([
      CardShell(
        state: state,
        child: FutureBuilder<AppVersionInfo>(
          future: appVersionInfoFuture,
          builder: (context, snapshot) {
            final version = snapshot.data ?? fallbackAppVersionInfo;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  child: Row(
                    children: [
                      Container(
                        width: 78,
                        height: 78,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: state.accents[0].withValues(alpha: 0.30),
                          ),
                        ),
                        child: Image.asset(
                          'assets/app_icon.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '织境 Weaview',
                              style: state.textStyle(
                                context,
                                size: 22,
                                weight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '在对话中编织想法',
                              style: state.textStyle(
                                context,
                                size: 14,
                                opacity: 0.58,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              version.display,
                              style: state.textStyle(
                                context,
                                size: 13,
                                opacity: 0.46,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                DividerLine(state: state),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: SoftButton(
                          state: state,
                          label: '检查更新',
                          icon: Icons.refresh_rounded,
                          onTap: checkForUpdates,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _StatusPill(
                        state: state,
                        text: '发布源 GitHub',
                        active: true,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      const SizedBox(height: 24),
      SectionLabel(state: state, label: '支持'),
      CardShell(
        state: state,
        child: Column(
          children: [
            SettingsRow(
              state: state,
              title: '报告问题',
              subtitle: '提交结构化问题反馈',
              leading: _SettingsIconBadge(
                state: state,
                icon: Icons.error_outline_rounded,
              ),
              showChevron: true,
              onTap: openFeedback,
            ),
            DividerLine(state: state),
            SettingsRow(
              state: state,
              title: '功能建议',
              subtitle: '提交想法或改进建议',
              leading: _SettingsIconBadge(
                state: state,
                icon: Icons.lightbulb_outline_rounded,
              ),
              showChevron: true,
              onTap: openSuggestionFeedback,
            ),
            DividerLine(state: state),
            SettingsRow(
              state: state,
              title: 'GitHub Issues',
              subtitle: '在仓库中查看或新建问题单',
              leading: _SettingsIconBadge(
                state: state,
                icon: Icons.open_in_new_rounded,
              ),
              showChevron: true,
              onTap: () => openExternalUrl(githubFeedbackUrl),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      SectionLabel(state: state, label: '应用信息'),
      CardShell(
        state: state,
        child: Column(
          children: [
            FutureBuilder<AppVersionInfo>(
              future: appVersionInfoFuture,
              builder: (context, snapshot) {
                final version = snapshot.data ?? fallbackAppVersionInfo;
                return SettingsRow(
                  state: state,
                  title: '当前版本',
                  subtitle: version.full,
                  leading: _SettingsIconBadge(
                    state: state,
                    icon: Icons.info_outline_rounded,
                  ),
                  trailing: _ValuePill(state: state, text: version.tag),
                );
              },
            ),
            DividerLine(state: state),
            SettingsRow(
              state: state,
              title: '发布日志',
              subtitle: '查看 GitHub Releases',
              leading: _SettingsIconBadge(
                state: state,
                icon: Icons.history_rounded,
              ),
              showChevron: true,
              onTap: () => openExternalUrl(githubReleasesUrl),
            ),
            DividerLine(state: state),
            SettingsRow(
              state: state,
              title: '开源许可',
              subtitle: '查看第三方依赖许可证',
              leading: _SettingsIconBadge(
                state: state,
                icon: Icons.code_rounded,
              ),
              showChevron: true,
              onTap: () =>
                  showLicensePage(context: context, applicationName: 'Weaview'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 28),
      Center(
        child: Text(
          'Made with care for thoughtful conversations.',
          textAlign: TextAlign.center,
          style: state.textStyle(context, size: 12, opacity: 0.34, height: 1.6),
        ),
      ),
    ]);
  }

  String _assignmentSubtitle(ModelAssignment assignment) {
    if (assignment.model.trim().isEmpty) return '未分配';
    if (assignment.provider.trim().isEmpty) return assignment.model;
    return '${assignment.provider} · ${assignment.model}';
  }

  IconData _roleIcon(String role) => switch (role) {
    'chat' => Icons.chat_bubble_outline_rounded,
    'title' => Icons.short_text_rounded,
    'suggest' => Icons.lightbulb_outline_rounded,
    'translate' => Icons.translate_rounded,
    'tool' => Icons.handyman_outlined,
    'image' => Icons.image_outlined,
    _ => Icons.memory_outlined,
  };
}

class _ThemeSegmentedControl extends StatelessWidget {
  const _ThemeSegmentedControl({
    required this.state,
    required this.current,
    required this.onSelected,
  });

  final WeaviewState state;
  final ThemeMode current;
  final ValueChanged<ThemeMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: state.isDark(context)
            ? Colors.white.withValues(alpha: 0.06)
            : state.text(context).withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: state.text(context).withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ThemeSegmentButton(
              state: state,
              icon: Icons.light_mode_outlined,
              label: '浅色',
              selected: current == ThemeMode.light,
              onTap: () => onSelected(ThemeMode.light),
            ),
          ),
          Expanded(
            child: _ThemeSegmentButton(
              state: state,
              icon: Icons.dark_mode_outlined,
              label: '深色',
              selected: current == ThemeMode.dark,
              onTap: () => onSelected(ThemeMode.dark),
            ),
          ),
          Expanded(
            child: _ThemeSegmentButton(
              state: state,
              icon: Icons.brightness_auto_outlined,
              label: '跟随',
              selected: current == ThemeMode.system,
              onTap: () => onSelected(ThemeMode.system),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeSegmentButton extends StatelessWidget {
  const _ThemeSegmentButton({
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
    final accent = state.accents[0];
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? accent.withValues(alpha: 0.20) : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: SizedBox(
            height: 38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: state.text(context).withValues(
                        alpha: selected ? 0.96 : 0.5,
                      ),
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  maxLines: 1,
                  style: state.textStyle(
                    context,
                    size: 12,
                    weight: FontWeight.w500,
                    opacity: selected ? 0.96 : 0.56,
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

class _AccentChoice extends StatelessWidget {
  const _AccentChoice({
    required this.state,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final WeaviewState state;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label 强调色',
      child: Material(
        color: selected
            ? color.withValues(alpha: state.isDark(context) ? 0.18 : 0.12)
            : state.text(context).withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minWidth: 104, minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? color.withValues(alpha: 0.72)
                    : state.text(context).withValues(alpha: 0.07),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.24),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 9),
                Text(
                  label,
                  style: state.textStyle(
                    context,
                    size: 13,
                    weight: selected ? FontWeight.w700 : FontWeight.w600,
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

class _ValuePill extends StatelessWidget {
  const _ValuePill({required this.state, required this.text});

  final WeaviewState state;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: state.isDark(context)
            ? Colors.white.withValues(alpha: 0.08)
            : state.text(context).withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: state.text(context).withValues(alpha: 0.08)),
      ),
      child: Text(
        text,
        style: state.textStyle(context, size: 12, weight: FontWeight.w600),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.state,
    required this.text,
    required this.active,
  });

  final WeaviewState state;
  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? sendGreen
        : state.text(context).withValues(alpha: 0.34);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: active ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: state
            .textStyle(context, size: 12, weight: FontWeight.w700)
            .copyWith(color: active ? sendGreen : null),
      ),
    );
  }
}

class _SettingsIconBadge extends StatelessWidget {
  const _SettingsIconBadge({
    required this.state,
    required this.icon,
    this.danger = false,
  });

  final WeaviewState state;
  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final tint = danger ? Colors.red : state.accents[0];
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: danger ? 0.10 : 0.16),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(
        icon,
        size: 20,
        color: danger
            ? Colors.red.withValues(alpha: 0.82)
            : state.text(context).withValues(alpha: 0.72),
      ),
    );
  }
}

class _InlineActionButton extends StatelessWidget {
  const _InlineActionButton({
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
    return SizedBox(
      width: 82,
      child: SoftButton(
        state: state,
        label: label,
        accent: accent,
        onTap: onTap,
      ),
    );
  }
}

class _ModelAssignmentBadge extends StatelessWidget {
  const _ModelAssignmentBadge({
    required this.state,
    required this.provider,
    required this.model,
  });

  final WeaviewState state;
  final String provider;
  final String model;

  @override
  Widget build(BuildContext context) {
    final active = model.trim().isNotEmpty;
    final label = active ? model : '未分配';
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 188),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? state.accents[0].withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active
                ? state.accents[0].withValues(alpha: 0.20)
                : state.text(context).withValues(alpha: 0.10),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (provider.trim().isNotEmpty) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: state.accents[0],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: state.textStyle(
                  context,
                  size: 12,
                  weight: FontWeight.w600,
                  opacity: active ? 0.94 : 0.44,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DataInfoLine extends StatelessWidget {
  const _DataInfoLine({
    required this.state,
    required this.icon,
    required this.title,
    required this.body,
  });

  final WeaviewState state;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: state.accents[0].withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              size: 18,
              color: state.text(context).withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: state.textStyle(
                    context,
                    size: 14,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: state.textStyle(
                    context,
                    size: 12,
                    opacity: 0.5,
                    height: 1.42,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

bool _isProviderConfigured(AiProvider provider) {
  return provider.apiKey.trim().isNotEmpty ||
      provider.status == '已连接' ||
      provider.status == '使用中';
}

class _ActivePill extends StatelessWidget {
  const _ActivePill({
    required this.state,
    required this.label,
    required this.color,
  });

  final WeaviewState state;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: state.isDark(context) ? 0.16 : 0.10,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: state
            .textStyle(
              context,
              size: 10,
              weight: FontWeight.w600,
            )
            .copyWith(color: color, letterSpacing: 0.6),
      ),
    );
  }
}

class _ProviderGridCard extends StatelessWidget {
  const _ProviderGridCard({
    required this.state,
    required this.provider,
    required this.active,
    required this.activeLabel,
    required this.controlsVisible,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
    this.highlighted = false,
  });

  final WeaviewState state;
  final AiProvider provider;
  final bool active;
  final String? activeLabel;
  final bool controlsVisible;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final configured = _isProviderConfigured(provider);
    final connected = provider.enabled && configured;
    final showWaveBorder = controlsVisible;
    final solidBorderColor = active
        ? state.accents[0].withValues(alpha: 0.46)
        : highlighted
        ? provider.color.withValues(alpha: 0.38)
        : state.text(context).withValues(alpha: 0.07);
    final cardFill = state.isDark(context)
        ? (active
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.055))
        : (active
              ? Colors.white.withValues(alpha: 0.96)
              : Colors.white.withValues(alpha: 0.78));
    final statusPillBg = connected
        ? sendGreen.withValues(alpha: state.isDark(context) ? 0.16 : 0.10)
        : state.text(context).withValues(alpha: 0.05);
    final statusPillFg = connected
        ? sendGreen
        : state.text(context).withValues(alpha: 0.5);
    final statusText = !configured
        ? '未配置'
        : !provider.enabled
        ? '已禁用 · ${provider.models.length} 个模型'
        : '已连接 · ${provider.models.length} 个模型';
    return Material(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 80,
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              decoration: BoxDecoration(
                color: cardFill,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: showWaveBorder ? Colors.transparent : solidBorderColor,
                  width: active || highlighted ? 1.15 : 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: active
                        ? state.accents[0].withValues(alpha: 0.14)
                        : Colors.black.withValues(alpha: 0.02),
                    blurRadius: active ? 22 : 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  BrandIcon.provider(
                    provider: provider,
                    size: 46,
                    radius: 15,
                    padding: 6,
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                provider.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: state.textStyle(
                                  context,
                                  size: 16.5,
                                  weight: FontWeight.w600,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            if (activeLabel != null && !controlsVisible) ...[
                              const SizedBox(width: 8),
                              _ActivePill(
                                state: state,
                                label: activeLabel!,
                                color: state.accents[0],
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusPillBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: connected ? sendGreen : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                statusText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: state.textStyle(
                                  context,
                                  size: 10.5,
                                  weight: FontWeight.w500,
                                  height: 1.1,
                                ).copyWith(color: statusPillFg),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (configured) ...[
                        WeaveSwitch(
                          state: state,
                          value: provider.enabled,
                          onChanged: onToggle,
                        ),
                        const SizedBox(width: 2),
                      ],
                      PopupMenuButton<String>(
                        key: ValueKey('provider_menu_${provider.name}'),
                        tooltip: '提供商操作',
                        padding: EdgeInsets.zero,
                        splashRadius: 18,
                        icon: Icon(
                          Icons.more_horiz_rounded,
                          size: 22,
                          color: state.text(context).withValues(alpha: 0.5),
                        ),
                        onSelected: (value) {
                          if (value == 'edit') {
                            onEdit();
                          } else if (value == 'delete') {
                            onDelete();
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.edit_outlined),
                              title: Text('编辑'),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.red,
                              ),
                              title: Text('删除'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 6),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (showWaveBorder)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ProviderWaveBorderPainter(
                    color: (active ? state.accents[0] : provider.color)
                        .withValues(alpha: active ? 0.78 : 0.56),
                  ),
                ),
              ),
            ),
          if (controlsVisible)
            Positioned(
              top: 8,
              right: 8,
              child: Semantics(
                key: ValueKey('provider_delete_${provider.name}'),
                button: true,
                label: '删除提供商',
                child: Material(
                  color: state.isDark(context)
                      ? Colors.white.withValues(alpha: 0.11)
                      : Colors.white.withValues(alpha: 0.82),
                  shape: CircleBorder(
                    side: BorderSide(color: Colors.red.withValues(alpha: 0.24)),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onDelete,
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: Colors.red.withValues(alpha: 0.78),
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

class _ProviderWaveBorderPainter extends CustomPainter {
  const _ProviderWaveBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final inset = paint.strokeWidth / 2;
    final left = inset;
    final top = inset;
    final right = size.width - inset;
    final bottom = size.height - inset;
    final radius = 22.0 - inset;
    const amplitude = 1.45;
    final path = Path()..moveTo(left + radius, top);

    _addHorizontalWave(
      path,
      fromX: left + radius,
      toX: right - radius,
      y: top,
      amplitude: -amplitude,
    );
    path.quadraticBezierTo(right, top, right, top + radius);
    _addVerticalWave(
      path,
      x: right,
      fromY: top + radius,
      toY: bottom - radius,
      amplitude: amplitude,
    );
    path.quadraticBezierTo(right, bottom, right - radius, bottom);
    _addHorizontalWave(
      path,
      fromX: right - radius,
      toX: left + radius,
      y: bottom,
      amplitude: amplitude,
    );
    path.quadraticBezierTo(left, bottom, left, bottom - radius);
    _addVerticalWave(
      path,
      x: left,
      fromY: bottom - radius,
      toY: top + radius,
      amplitude: -amplitude,
    );
    path.quadraticBezierTo(left, top, left + radius, top);
    path.close();
    canvas.drawPath(path, paint);
  }

  void _addHorizontalWave(
    Path path, {
    required double fromX,
    required double toX,
    required double y,
    required double amplitude,
  }) {
    final distance = (toX - fromX).abs();
    final segments = math.max(4, (distance / 22).round());
    final step = (toX - fromX) / segments;
    var x = fromX;
    var direction = 1.0;
    for (var i = 0; i < segments; i += 1) {
      final nextX = i == segments - 1 ? toX : x + step;
      path.quadraticBezierTo(
        (x + nextX) / 2,
        y + amplitude * direction,
        nextX,
        y,
      );
      x = nextX;
      direction = -direction;
    }
  }

  void _addVerticalWave(
    Path path, {
    required double x,
    required double fromY,
    required double toY,
    required double amplitude,
  }) {
    final distance = (toY - fromY).abs();
    final segments = math.max(3, (distance / 22).round());
    final step = (toY - fromY) / segments;
    var y = fromY;
    var direction = 1.0;
    for (var i = 0; i < segments; i += 1) {
      final nextY = i == segments - 1 ? toY : y + step;
      path.quadraticBezierTo(
        x + amplitude * direction,
        (y + nextY) / 2,
        x,
        nextY,
      );
      y = nextY;
      direction = -direction;
    }
  }

  @override
  bool shouldRepaint(covariant _ProviderWaveBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
