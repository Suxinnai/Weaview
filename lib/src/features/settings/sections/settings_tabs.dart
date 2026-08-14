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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
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
              style: state.textStyle(context, size: 12, opacity: 0.5),
            ),
            const SizedBox(height: 14),
            _ThemeChoiceRow(
              state: state,
              current: state.themeMode,
              onSelected: state.setThemeModeValue,
            ),
            const SizedBox(height: 18),
            DividerLine(state: state),
            const SizedBox(height: 16),
            Text(
              '强调色',
              style: state.textStyle(
                context,
                size: 15,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '按钮、选中状态与动效使用的颜色',
              style: state.textStyle(context, size: 12, opacity: 0.5),
            ),
            const SizedBox(height: 13),
            _InlineAccentPalette(state: state),
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
    final configuredCount = state.providers.where(_isProviderConfigured).length;

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
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 12.0;
            final cardWidth = (constraints.maxWidth - spacing) / 2;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final provider in state.providers)
                  Builder(
                    key: ValueKey('provider_${provider.name}'),
                    builder: (context) {
                      final actualIndex = state.providers.indexWhere(
                        (item) => item.name == provider.name,
                      );
                      final isCurrent =
                          provider.enabled &&
                          (provider.current || provider.status == '使用中');
                      final controlsVisible =
                          providerDeleteTarget == provider.name;
                      return SizedBox(
                        width: cardWidth,
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
                              active: isCurrent,
                              controlsVisible: controlsVisible,
                              highlighted: hovering,
                              onEdit: () => openProviderConfig(provider),
                              onDelete: () =>
                                  confirmDeleteProvider(provider.name),
                            );
                            return LongPressDraggable<String>(
                              data: provider.name,
                              delay: const Duration(milliseconds: 320),
                              dragAnchorStrategy: childDragAnchorStrategy,
                              rootOverlay: true,
                              feedback: SizedBox(
                                width: cardWidth,
                                child: Material(
                                  color: Colors.transparent,
                                  elevation: 10,
                                  shadowColor: Colors.black.withValues(
                                    alpha: 0.16,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  child: row,
                                ),
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0,
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
                SizedBox(
                  width: cardWidth,
                  child: _AddProviderGridCard(
                    key: const Key('add_custom_provider_card'),
                    state: state,
                    onTap: () => openProviderConfig(null),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        Text(
          '点按配置 · 长按卡片可排序或删除',
          textAlign: TextAlign.center,
          style: state.textStyle(context, size: 12, opacity: 0.4),
        ),
      ]),
    );
  }

  Widget modelsTab() {
    final state = widget.state;
    Widget assignmentCard(List<String> roles) {
      return CardShell(
        state: state,
        child: Column(
          children: [
            for (var index = 0; index < roles.length; index++) ...[
              if (index > 0) DividerLine(state: state),
              Builder(
                builder: (context) {
                  final role = roles[index];
                  final entry = SettingsSheetState.settingsRoles[role]!;
                  final assignment = state.modelAssignments[role]!;
                  return KeyedSubtree(
                    key: ValueKey('model_assignment_$role'),
                    child: _ModelAssignmentRow(
                      state: state,
                      title: entry.$1,
                      description: entry.$2,
                      icon: _roleIcon(role),
                      assignment: assignment,
                      onTap: () {
                        updateSheet(() {
                          editingRole = role;
                          roleDraft = assignment;
                          rolePromptController.text = assignment.prompt;
                          subView = 'model_role_config';
                        });
                      },
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      );
    }

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
                  '为对话和辅助任务分配模型',
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
      const SizedBox(height: 24),
      SectionLabel(state: state, label: '核心模型'),
      assignmentCard(const ['chat', 'image']),
      const SizedBox(height: 24),
      SectionLabel(state: state, label: '辅助任务'),
      assignmentCard(const ['translate', 'title']),
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
                '支持配置 Tavily 联网搜索服务，为对话提供实时信息来源。',
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
    return scrollContent([
      _AboutIdentityPanel(
        state: state,
        versionFuture: appVersionInfoFuture,
        onCheckUpdates: checkForUpdates,
      ),
      const SizedBox(height: 24),
      CardShell(
        state: state,
        child: Column(
          children: [
            SettingsRow(
              state: state,
              title: '反馈与建议',
              subtitle: '提交问题或功能想法',
              leading: _SettingsIconBadge(
                state: state,
                icon: Icons.chat_bubble_outline_rounded,
              ),
              showChevron: true,
              onTap: openFeedback,
            ),
            DividerLine(state: state),
            SettingsRow(
              state: state,
              title: 'GitHub 仓库',
              subtitle: '查看项目源码与问题',
              leading: _SettingsIconBadge(
                state: state,
                icon: Icons.code_rounded,
              ),
              showChevron: true,
              onTap: () => openExternalUrl(githubRepositoryUrl),
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
    ]);
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

class _AboutIdentityPanel extends StatelessWidget {
  const _AboutIdentityPanel({
    required this.state,
    required this.versionFuture,
    required this.onCheckUpdates,
  });

  final WeaviewState state;
  final Future<AppVersionInfo> versionFuture;
  final VoidCallback onCheckUpdates;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppVersionInfo>(
      future: versionFuture,
      builder: (context, snapshot) {
        final version = snapshot.data ?? fallbackAppVersionInfo;
        final versionLabel = version.build.isEmpty
            ? 'v${version.name}'
            : 'v${version.name} · Build ${version.build}';
        return Container(
          key: const ValueKey('about_identity_panel'),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: state.isDark(context)
                  ? [
                      Colors.white.withValues(alpha: 0.07),
                      state.accents[0].withValues(alpha: 0.08),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.96),
                      state.accents[0].withValues(alpha: 0.14),
                      state.accents[1].withValues(alpha: 0.10),
                    ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: state.accents[0].withValues(alpha: 0.24)),
            boxShadow: [
              BoxShadow(
                color: state.accents[0].withValues(alpha: 0.08),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(23),
                      border: Border.all(
                        color: state.accents[0].withValues(alpha: 0.3),
                      ),
                    ),
                    child: Image.asset(
                      'assets/app_icon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 17),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '织境 Weaview',
                          style: state.textStyle(
                            context,
                            size: 21,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '在对话中编织想法',
                          style: state.textStyle(
                            context,
                            size: 13.5,
                            opacity: 0.58,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          versionLabel,
                          style: state
                              .textStyle(
                                context,
                                size: 12.5,
                                weight: FontWeight.w600,
                              )
                              .copyWith(color: state.accents[0]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onCheckUpdates,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh_rounded,
                          size: 19,
                          color: state.accents[0],
                        ),
                        const SizedBox(width: 9),
                        Text(
                          '检查更新',
                          style: state.textStyle(
                            context,
                            size: 13.5,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: state.text(context).withValues(alpha: 0.38),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThemeChoiceRow extends StatelessWidget {
  const _ThemeChoiceRow({
    required this.state,
    required this.current,
    required this.onSelected,
  });

  final WeaviewState state;
  final ThemeMode current;
  final ValueChanged<ThemeMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ThemeChoiceCard(
            key: const ValueKey('theme_choice_light'),
            state: state,
            mode: ThemeMode.light,
            label: '浅色',
            selected: current == ThemeMode.light,
            onTap: () => onSelected(ThemeMode.light),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ThemeChoiceCard(
            key: const ValueKey('theme_choice_dark'),
            state: state,
            mode: ThemeMode.dark,
            label: '深色',
            selected: current == ThemeMode.dark,
            onTap: () => onSelected(ThemeMode.dark),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ThemeChoiceCard(
            key: const ValueKey('theme_choice_system'),
            state: state,
            mode: ThemeMode.system,
            label: '跟随系统',
            selected: current == ThemeMode.system,
            onTap: () => onSelected(ThemeMode.system),
          ),
        ),
      ],
    );
  }
}

class _ThemeChoiceCard extends StatelessWidget {
  const _ThemeChoiceCard({
    super.key,
    required this.state,
    required this.mode,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final WeaviewState state;
  final ThemeMode mode;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = state.accents[0];
    return Semantics(
      button: true,
      selected: selected,
      label: '$label主题',
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: state.isDark(context) ? 0.16 : 0.10)
              : state.text(context).withValues(alpha: 0.025),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.88)
                : state.text(context).withValues(alpha: 0.08),
            width: selected ? 1.35 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 9, 8, 10),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _ThemePreview(state: state, mode: mode),
                    if (selected)
                      Positioned(
                        right: -3,
                        bottom: -3,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: state.layer(context),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  style: state.textStyle(
                    context,
                    size: 11.5,
                    weight: selected ? FontWeight.w700 : FontWeight.w600,
                    opacity: selected ? 0.96 : 0.62,
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

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.state, required this.mode});

  final WeaviewState state;
  final ThemeMode mode;

  @override
  Widget build(BuildContext context) {
    final dark = mode == ThemeMode.dark;
    final surface = dark ? const Color(0xFF182334) : const Color(0xFFF8FAFC);
    final line = dark ? const Color(0xFF5C6B7E) : const Color(0xFFD8DFE8);
    final accent = state.accents[0];
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: SizedBox(
        height: 50,
        child: Row(
          children: [
            for (final previewDark
                in mode == ThemeMode.system ? const [false, true] : [dark])
              Expanded(
                child: ColoredBox(
                  color: previewDark ? const Color(0xFF182334) : surface,
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 18,
                          height: 3,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        const Spacer(),
                        for (var i = 0; i < 2; i++) ...[
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Container(
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: previewDark
                                        ? const Color(0xFF5C6B7E)
                                        : line,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (i == 0) const SizedBox(height: 5),
                        ],
                      ],
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

class _InlineAccentPalette extends StatelessWidget {
  const _InlineAccentPalette({required this.state});

  final WeaviewState state;

  static const options = <({String label, Color color})>[
    (label: '薄荷', color: Color(0xFF70D8C7)),
    (label: '海蓝', color: Color(0xFF3487F3)),
    (label: '紫罗兰', color: Color(0xFF7C6CF2)),
    (label: '珊瑚', color: Color(0xFFF06A73)),
    (label: '琥珀', color: Color(0xFFE49A32)),
    (label: '墨绿', color: Color(0xFF167D68)),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final option in options)
          Semantics(
            button: true,
            selected: state.accents.first.toARGB32() == option.color.toARGB32(),
            label: '${option.label}强调色',
            child: Tooltip(
              message: option.label,
              child: InkResponse(
                key: ValueKey('accent_${option.label}'),
                onTap: () => state.setAccentColor(option.color),
                radius: 24,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: option.color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          state.accents.first.toARGB32() ==
                              option.color.toARGB32()
                          ? state.layer(context)
                          : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow:
                        state.accents.first.toARGB32() ==
                            option.color.toARGB32()
                        ? [
                            BoxShadow(
                              color: option.color.withValues(alpha: 0.36),
                              blurRadius: 0,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child:
                      state.accents.first.toARGB32() == option.color.toARGB32()
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
            ),
          ),
      ],
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
      constraints: const BoxConstraints(maxWidth: 116),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active
                ? state.accents[0].withValues(alpha: 0.34)
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

class _ModelAssignmentRow extends StatelessWidget {
  const _ModelAssignmentRow({
    required this.state,
    required this.title,
    required this.description,
    required this.icon,
    required this.assignment,
    required this.onTap,
  });

  final WeaviewState state;
  final String title;
  final String description;
  final IconData icon;
  final ModelAssignment assignment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final assigned = assignment.model.trim().isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 78),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                _SettingsIconBadge(state: state, icon: icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: state.textStyle(
                          context,
                          size: 15.5,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        assigned && assignment.provider.trim().isNotEmpty
                            ? assignment.provider
                            : description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: state.textStyle(
                          context,
                          size: 11.5,
                          opacity: 0.48,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _ModelAssignmentBadge(
                  state: state,
                  provider: assignment.provider,
                  model: assignment.model,
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 21,
                  color: state.text(context).withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
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

class _ProviderGridCard extends StatelessWidget {
  const _ProviderGridCard({
    required this.state,
    required this.provider,
    required this.active,
    required this.controlsVisible,
    required this.onEdit,
    required this.onDelete,
    this.highlighted = false,
  });

  final WeaviewState state;
  final AiProvider provider;
  final bool active;
  final bool controlsVisible;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final configured = _isProviderConfigured(provider);
    final connected = provider.enabled && configured;
    final solidBorderColor = active
        ? state.accents[0].withValues(alpha: 0.82)
        : connected
        ? state.accents[0].withValues(alpha: 0.42)
        : highlighted
        ? provider.color.withValues(alpha: 0.38)
        : state.text(context).withValues(alpha: 0.07);
    final cardFill = state.isDark(context)
        ? Colors.white.withValues(alpha: 0.055)
        : Colors.white.withValues(alpha: 0.82);
    final statusPillFg = connected
        ? sendGreen
        : state.text(context).withValues(alpha: 0.5);
    final statusText = !configured
        ? '未配置'
        : !provider.enabled
        ? '已禁用'
        : active
        ? '当前 · ${provider.models.length} 个模型'
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
              width: double.infinity,
              height: 134,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
              decoration: BoxDecoration(
                color: cardFill,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: solidBorderColor,
                  width: active
                      ? 1.65
                      : connected || highlighted
                      ? 1.15
                      : 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: connected
                        ? state.accents[0].withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.02),
                    blurRadius: connected ? 16 : 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BrandIcon.provider(
                    provider: provider,
                    size: 42,
                    radius: 14,
                    padding: 5,
                  ),
                  const Spacer(),
                  Text(
                    provider.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: state.textStyle(
                      context,
                      size: 15.5,
                      weight: FontWeight.w600,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (active) ...[
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: state.accents[0],
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 5),
                      ] else ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: connected ? sendGreen : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          statusText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: state
                              .textStyle(
                                context,
                                size: 10.5,
                                weight: active
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                height: 1.1,
                              )
                              .copyWith(
                                color: active ? state.accents[0] : statusPillFg,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (controlsVisible)
            Positioned(
              top: 9,
              right: 9,
              child: Semantics(
                key: ValueKey('provider_delete_${provider.name}'),
                button: true,
                label: '删除提供商',
                child: Material(
                  color: state.isDark(context)
                      ? const Color(0xFF381F25).withValues(alpha: 0.92)
                      : const Color(0xFFFFF5F5).withValues(alpha: 0.96),
                  shape: CircleBorder(
                    side: BorderSide(color: Colors.red.withValues(alpha: 0.36)),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onDelete,
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: Icon(
                        Icons.close_rounded,
                        size: 17,
                        color: Colors.red.withValues(alpha: 0.86),
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

class _AddProviderGridCard extends StatelessWidget {
  const _AddProviderGridCard({
    super.key,
    required this.state,
    required this.onTap,
  });

  final WeaviewState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = state.text(context);
    return Semantics(
      button: true,
      label: '添加自定义提供商',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            height: 134,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: state.accents[0].withValues(alpha: 0.045),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: state.accents[0].withValues(alpha: 0.34),
                width: 1.1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: state.accents[0].withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: state.accents[0],
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '自定义提供商',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: state.textStyle(
                    context,
                    size: 13.5,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '连接兼容 API',
                  style: state
                      .textStyle(context, size: 10.5, opacity: 0.5)
                      .copyWith(color: text.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
