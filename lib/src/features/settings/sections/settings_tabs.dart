// ignore_for_file: use_key_in_widget_constructors

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import '../../../app/app_constants.dart';
import '../../../app/weaview_state.dart';
import '../../../core/app_utils.dart';
import '../../../domain/models.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../settings_sheet.dart';

extension SettingsTabs on SettingsSheetState {
  Widget generalTab() {
    final state = widget.state;
    return scrollContent([
      SectionLabel(state: state, label: '外观与主题'),
      CardShell(
        state: state,
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            ThemeChoice(
              state: state,
              icon: Icons.light_mode_outlined,
              label: '浅色',
              selected: state.themeMode == ThemeMode.light,
              onTap: () => state.setThemeModeValue(ThemeMode.light),
            ),
            ThemeChoice(
              state: state,
              icon: Icons.dark_mode_outlined,
              label: '深色',
              selected: state.themeMode == ThemeMode.dark,
              onTap: () => state.setThemeModeValue(ThemeMode.dark),
            ),
            ThemeChoice(
              state: state,
              icon: Icons.monitor_rounded,
              label: '跟随系统',
              selected: state.themeMode == ThemeMode.system,
              onTap: () => state.setThemeModeValue(ThemeMode.system),
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
              subtitle: '你的专属代号',
              trailing: SizedBox(
                width: 128,
                child: TextFormField(
                  initialValue: state.userName,
                  onChanged: state.updateUserName,
                  textAlign: TextAlign.right,
                  style: state.textStyle(context, size: 14),
                  decoration: inputDecoration(state, hint: '织梦者'),
                ),
              ),
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
      SectionLabel(state: state, label: '人设设置'),
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
              subtitle: '自定义AI伙伴的形象',
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
              subtitle: '梦境的感性程度',
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

  Widget providersTab() {
    final state = widget.state;
    void clearDeleteTarget() {
      if (providerDeleteTarget == null && draggingProviderName == null) return;
      updateSheet(() {
        providerDeleteTarget = null;
        draggingProviderName = null;
      });
    }

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
      onTap: clearDeleteTarget,
      child: scrollContent([
        Row(
          children: [
            Expanded(
              child: SectionLabel(state: state, label: '模型提供商'),
            ),
            TextButton.icon(
              onPressed: () => openProviderConfig(null),
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('自定义提供商'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 14.0;
            final cardWidth = (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: 14,
              children: [
                for (var index = 0; index < state.providers.length; index++)
                  Builder(
                    key: ValueKey('provider_${state.providers[index].name}'),
                    builder: (context) {
                      final provider = state.providers[index];
                      final active =
                          provider.current || provider.status == '使用中';
                      final controlsVisible =
                          providerDeleteTarget == provider.name;
                      return DragTarget<String>(
                        onWillAcceptWithDetails: (details) =>
                            details.data != provider.name,
                        onAcceptWithDetails: (details) {
                          dropProviderOn(details.data, index);
                          updateSheet(() {
                            providerDeleteTarget = details.data;
                            draggingProviderName = null;
                          });
                        },
                        builder: (context, candidateData, rejectedData) {
                          final hovering = candidateData.isNotEmpty;
                          final card = AnimatedScale(
                            duration: const Duration(milliseconds: 140),
                            curve: Curves.easeOutCubic,
                            scale: draggingProviderName == provider.name
                                ? 0.96
                                : hovering
                                ? 0.98
                                : 1,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                if (controlsVisible) {
                                  clearDeleteTarget();
                                } else {
                                  openProviderConfig(provider);
                                }
                              },
                              child: _ProviderGridCard(
                                state: state,
                                provider: provider,
                                active: active,
                                controlsVisible: controlsVisible,
                                highlighted: hovering || controlsVisible,
                                onDelete: () =>
                                    confirmDeleteProvider(provider.name),
                              ),
                            ),
                          );

                          return SizedBox(
                            width: cardWidth,
                            child: LongPressDraggable<String>(
                              data: provider.name,
                              delay: const Duration(milliseconds: 360),
                              dragAnchorStrategy: pointerDragAnchorStrategy,
                              rootOverlay: true,
                              feedback: SizedBox(width: cardWidth, height: 124),
                              childWhenDragging: card,
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
                              child: card,
                            ),
                          );
                        },
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ]),
    );
  }

  Widget modelsTab() {
    final state = widget.state;
    return scrollContent([
      SectionLabel(state: state, label: '默认模型分配'),
      for (final entry in SettingsSheetState.settingsRoles.entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: CardShell(
            state: state,
            child: SettingsRow(
              state: state,
              title: entry.value.$1,
              subtitle: entry.value.$2,
              showChevron: true,
              trailing: ModelBadge(
                state: state,
                label:
                    state.modelAssignments[entry.key]?.model.isNotEmpty == true
                    ? state.modelAssignments[entry.key]!.model
                    : '未分配',
                active:
                    state.modelAssignments[entry.key]?.model.isNotEmpty == true,
              ),
              onTap: () {
                updateSheet(() {
                  editingRole = entry.key;
                  roleDraft = state.modelAssignments[entry.key]!;
                  subView = 'model_role_config';
                });
              },
            ),
          ),
        ),
    ]);
  }

  Widget servicesTab() {
    final state = widget.state;
    return scrollContent([
      SectionLabel(state: state, label: '搜索服务', icon: Icons.public_rounded),
      CardShell(
        state: state,
        child: Column(
          children: [
            SettingsRow(
              state: state,
              title: '默认搜索引擎',
              subtitle:
                  '正在使用: ${SettingsSheetState.settingsEngines.firstWhere((e) => e.$1 == state.searchConfig.active, orElse: () => SettingsSheetState.settingsEngines.first).$2}',
              showChevron: true,
              onTap: () => updateSheet(() => subView = 'search_engine_config'),
            ),
            DividerLine(state: state),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              child: Text(
                '支持配置 Tavily、Brave、Perplexity 等联网搜索服务，为模型提供实时信息支持。',
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
      SectionLabel(state: state, label: '语音服务 (TTS)', icon: Icons.mic_none),
      CardShell(
        state: state,
        child: Column(
          children: [
            SettingsRow(
              state: state,
              title: '系统 TTS',
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
              leading: Icon(Icons.add_rounded, color: state.accents[0]),
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
    final memoryBytes = utf8.encode(jsonEncode(state.memories)).length;
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
    final total = sessionBytes + providerBytes + memoryBytes + configBytes;
    int segmentFlex(int bytes) {
      if (total <= 0) return 1;
      return math.max((bytes / total * 100).round(), 1);
    }

    return scrollContent([
      SectionLabel(state: state, label: '本地数据概览'),
      CardShell(
        state: state,
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatBytes(total),
                  style: state.textStyle(
                    context,
                    size: 31,
                    weight: FontWeight.w300,
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text(
                    '总已用空间',
                    style: state.textStyle(context, size: 13, opacity: 0.52),
                  ),
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
                      child: Container(color: Colors.blue),
                    ),
                    Expanded(
                      flex: segmentFlex(memoryBytes),
                      child: Container(color: state.accents[0]),
                    ),
                    Expanded(
                      flex: segmentFlex(providerBytes),
                      child: Container(color: Colors.purple),
                    ),
                    Expanded(
                      flex: segmentFlex(configBytes),
                      child: Container(color: const Color(0xFFF59E0B)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            StorageRow(
              state: state,
              label: '对话记录',
              description: '历史梦境与消息内容',
              color: Colors.blue,
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
              label: '提供商与模型',
              description: 'API 配置摘要、模型列表和能力标记',
              color: Colors.purple,
              bytes: providerBytes,
              ratio: total == 0 ? 0 : providerBytes / total,
            ),
            StorageRow(
              state: state,
              label: '应用偏好',
              description: '默认模型、搜索/TTS、主题与表单设置',
              color: const Color(0xFFF59E0B),
              bytes: configBytes,
              ratio: total == 0 ? 0 : configBytes / total,
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
              icon: Icons.tune_rounded,
              title: '模型与服务配置',
              body: '包含提供商、模型能力、默认模型分配、搜索和 TTS 配置摘要。',
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      SectionLabel(state: state, label: '数据操作'),
      CardShell(
        state: state,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '导出备份会生成 ZIP 文件，包含本地 JSON 数据和说明文件。敏感 API Key 会以星号脱敏。',
              style: state.textStyle(
                context,
                size: 13,
                opacity: 0.58,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            SoftButton(
              state: state,
              label: '导出备份',
              icon: Icons.backup_outlined,
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
                  await Clipboard.setData(
                    ClipboardData(text: state.exportJson()),
                  );
                  widget.showSnack('未选择保存位置，已复制脱敏 JSON 到剪贴板。');
                }
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      SectionLabel(state: state, label: '危险操作'),
      CardShell(
        state: state,
        padding: const EdgeInsets.all(18),
        borderColor: Colors.red.withValues(alpha: 0.24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '清空所有本地数据会删除对话记录、记忆数据、应用配置、提供商和模型分配。操作前请先导出备份。',
              style: state.textStyle(
                context,
                size: 13,
                opacity: 0.64,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            SoftButton(
              state: state,
              label: '清空所有本地数据',
              icon: Icons.delete_forever_outlined,
              danger: true,
              onTap: confirmClearData,
            ),
          ],
        ),
      ),
    ]);
  }

  Widget aboutTab() {
    final state = widget.state;
    return scrollContent([
      const SizedBox(height: 22),
      Center(
        child: Column(
          children: [
            Container(
              width: 96,
              height: 96,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: state.accents[0].withValues(alpha: 0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: state.accents[0].withValues(alpha: 0.18),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Image.asset('assets/app_icon.png', fit: BoxFit.cover),
            ),
            const SizedBox(height: 22),
            Text(
              'WEAVIEW',
              style: state
                  .textStyle(context, size: 30, weight: FontWeight.w300)
                  .copyWith(letterSpacing: 4),
            ),
            const SizedBox(height: 8),
            Text(
              appVersionDisplay,
              style: state.textStyle(context, size: 13, opacity: 0.5),
            ),
            const SizedBox(height: 30),
            AboutButton(state: state, label: '检查更新', onTap: checkForUpdates),
            AboutButton(
              state: state,
              label: '开源许可',
              onTap: () =>
                  showLicensePage(context: context, applicationName: 'Weaview'),
            ),
            AboutButton(
              state: state,
              label: '报告问题 / 提供反馈',
              accent: true,
              onTap: openFeedback,
            ),
            const SizedBox(height: 40),
            Text(
              'Crafted with intentionality.\n© 2026 Weaview App.',
              textAlign: TextAlign.center,
              style: state.textStyle(
                context,
                size: 11,
                opacity: 0.3,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    ]);
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

class _ProviderGridCard extends StatelessWidget {
  const _ProviderGridCard({
    required this.state,
    required this.provider,
    required this.active,
    required this.controlsVisible,
    required this.onDelete,
    this.highlighted = false,
  });

  final WeaviewState state;
  final AiProvider provider;
  final bool active;
  final bool controlsVisible;
  final VoidCallback onDelete;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final connected = provider.status == '已连接' || provider.status == '使用中';
    final showWaveBorder = controlsVisible;
    final solidBorderColor = active
        ? state.accents[0].withValues(alpha: 0.48)
        : highlighted
        ? provider.color.withValues(alpha: 0.38)
        : state.text(context).withValues(alpha: 0.06);
    return Material(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 124,
            padding: const EdgeInsets.fromLTRB(17, 14, 15, 13),
            decoration: BoxDecoration(
              color: active
                  ? (state.isDark(context)
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.white.withValues(alpha: 0.88))
                  : (state.isDark(context)
                        ? Colors.white.withValues(alpha: 0.055)
                        : Colors.white.withValues(alpha: 0.70)),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: showWaveBorder ? Colors.transparent : solidBorderColor,
                width: active || highlighted ? 1.35 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: active
                      ? state.accents[0].withValues(alpha: 0.16)
                      : Colors.black.withValues(alpha: 0.025),
                  blurRadius: active ? 24 : 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    BrandIcon.provider(
                      provider: provider,
                      size: 30,
                      radius: 11,
                      padding: 5,
                    ),
                    const Spacer(),
                    if (active && !controlsVisible)
                      Text(
                        'CURRENT',
                        style: state
                            .textStyle(
                              context,
                              size: 10,
                              weight: FontWeight.w800,
                            )
                            .copyWith(
                              color: state.accents[0].withValues(alpha: 0.58),
                              letterSpacing: 2,
                            ),
                      ),
                    if (controlsVisible) const SizedBox(width: 36),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  provider.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: state.textStyle(
                    context,
                    size: 18,
                    weight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: connected ? sendGreen : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        provider.status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: state.textStyle(
                          context,
                          size: 11,
                          opacity: 0.54,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
          Positioned(
            top: 10,
            right: 10,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 140),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeInCubic,
              child: controlsVisible
                  ? Semantics(
                      key: ValueKey('provider_delete_${provider.name}'),
                      button: true,
                      label: '删除提供商',
                      child: GestureDetector(
                        onTap: onDelete,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: state.isDark(context)
                                ? Colors.white.withValues(alpha: 0.11)
                                : Colors.white.withValues(alpha: 0.82),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.24),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: Colors.red.withValues(alpha: 0.78),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(
                      key: ValueKey('provider_delete_empty'),
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
