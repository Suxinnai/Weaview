// ignore_for_file: use_key_in_widget_constructors

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_constants.dart';
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
    return scrollContent([
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
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: state.providers.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: MediaQuery.sizeOf(context).width > 430 ? 3 : 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.55,
        ),
        itemBuilder: (context, index) {
          final provider = state.providers[index];
          final active = provider.current || provider.status == '使用中';
          return GestureDetector(
            onTap: () => openProviderConfig(provider),
            onLongPress: () => confirmDeleteProvider(provider.name),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: active
                    ? (state.isDark(context)
                          ? Colors.white.withValues(alpha: 0.10)
                          : Colors.white)
                    : (state.isDark(context)
                          ? Colors.white.withValues(alpha: 0.055)
                          : Colors.white.withValues(alpha: 0.58)),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: active
                      ? state.accents[0]
                      : state.text(context).withValues(alpha: 0.06),
                  width: active ? 1.8 : 1,
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: state.accents[0].withValues(alpha: 0.20),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: provider.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const Spacer(),
                      if (active)
                        Text(
                          'CURRENT',
                          style: state
                              .textStyle(
                                context,
                                size: 10,
                                weight: FontWeight.w800,
                              )
                              .copyWith(
                                color: state.accents[0],
                                letterSpacing: 0.8,
                              ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    provider.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: state.textStyle(
                      context,
                      size: 15.5,
                      weight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color:
                              provider.status == '已连接' ||
                                  provider.status == '使用中'
                              ? Colors.green
                              : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        provider.status,
                        style: state.textStyle(
                          context,
                          size: 10.5,
                          opacity: 0.52,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ]);
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
              subtitle: '使用设备默认语音播报',
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
                subtitle: tts.apiKey.isNotEmpty || tts.baseUrl.isNotEmpty
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
                    baseUrl: '',
                    model: '',
                    voice: '',
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
    final sessionBytes = utf8.encode(jsonEncode(state.chatSessions)).length;
    final providerBytes = utf8
        .encode(jsonEncode(state.providers.map((p) => p.safeJson()).toList()))
        .length;
    final memoryBytes = utf8.encode(jsonEncode(state.memories)).length;
    final total = sessionBytes + providerBytes + memoryBytes;
    return scrollContent([
      SectionLabel(state: state, label: '本地数据存储'),
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
                      flex: math.max(sessionBytes, 1),
                      child: Container(color: Colors.blue),
                    ),
                    Expanded(
                      flex: math.max(memoryBytes, 1),
                      child: Container(color: state.accents[0]),
                    ),
                    Expanded(
                      flex: math.max(providerBytes, 1),
                      child: Container(color: Colors.purple),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            StorageRow(
              state: state,
              label: '对话记录',
              color: Colors.blue,
              bytes: sessionBytes,
            ),
            StorageRow(
              state: state,
              label: '记忆数据',
              color: state.accents[0],
              bytes: memoryBytes,
            ),
            StorageRow(
              state: state,
              label: '应用配置',
              color: Colors.purple,
              bytes: providerBytes,
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: SoftButton(
              state: state,
              label: '导出数据',
              onTap: () async {
                await Clipboard.setData(
                  ClipboardData(text: state.exportJson()),
                );
                widget.showSnack('数据已复制到剪贴板。');
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SoftButton(
              state: state,
              label: '清空所有缓存',
              danger: true,
              onTap: confirmClearData,
            ),
          ),
        ],
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
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: state.isDark(context)
                      ? [const Color(0xFF1A1C1E), baseDark]
                      : [Colors.white, const Color(0xFFF4F5F7)],
                ),
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
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: state.accents),
                ),
              ),
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
              'v1.2.0 (Build 20260501)',
              style: state.textStyle(context, size: 13, opacity: 0.5),
            ),
            const SizedBox(height: 30),
            AboutButton(
              state: state,
              label: '检查更新',
              onTap: () => widget.showSnack('当前已是最新版本。'),
            ),
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
              onTap: () => widget.showSnack('反馈入口已预留。'),
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
