// ignore_for_file: use_key_in_widget_constructors

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
                          Widget dragHandle() {
                            return Draggable<String>(
                              data: provider.name,
                              dragAnchorStrategy: pointerDragAnchorStrategy,
                              rootOverlay: true,
                              feedback: Material(
                                color: Colors.transparent,
                                child: SizedBox(
                                  width: cardWidth,
                                  child: _ProviderGridCard(
                                    state: state,
                                    provider: provider,
                                    active: active,
                                    controlsVisible: false,
                                    floating: true,
                                    onDelete: () {},
                                  ),
                                ),
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.35,
                                child: _ProviderDragHandle(state: state),
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
                              child: _ProviderDragHandle(state: state),
                            );
                          }

                          return SizedBox(
                            width: cardWidth,
                            child: AnimatedScale(
                              duration: const Duration(milliseconds: 140),
                              scale: hovering ? 0.972 : 1,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => openProviderConfig(provider),
                                onLongPress: () => updateSheet(() {
                                  providerDeleteTarget = provider.name;
                                }),
                                child: _ProviderGridCard(
                                  state: state,
                                  provider: provider,
                                  active: active,
                                  controlsVisible: controlsVisible,
                                  dragHandle: controlsVisible
                                      ? dragHandle()
                                      : null,
                                  highlighted: hovering,
                                  onDelete: () =>
                                      confirmDeleteProvider(provider.name),
                                ),
                              ),
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

class _ProviderGridCard extends StatelessWidget {
  const _ProviderGridCard({
    required this.state,
    required this.provider,
    required this.active,
    required this.controlsVisible,
    required this.onDelete,
    this.floating = false,
    this.highlighted = false,
    this.dragHandle,
  });

  final WeaviewState state;
  final AiProvider provider;
  final bool active;
  final bool controlsVisible;
  final VoidCallback onDelete;
  final bool floating;
  final bool highlighted;
  final Widget? dragHandle;

  @override
  Widget build(BuildContext context) {
    final connected = provider.status == '已连接' || provider.status == '使用中';
    return Material(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 124,
            padding: const EdgeInsets.fromLTRB(17, 15, 15, 14),
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
                color: highlighted
                    ? provider.color.withValues(alpha: 0.45)
                    : active
                    ? state.accents[0].withValues(alpha: 0.72)
                    : state.text(context).withValues(alpha: 0.06),
                width: highlighted || active ? 1.8 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: active
                      ? state.accents[0].withValues(alpha: 0.16)
                      : Colors.black.withValues(alpha: 0.025),
                  blurRadius: active || floating ? 24 : 14,
                  offset: Offset(0, floating ? 12 : 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: provider.color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: provider.color.withValues(alpha: 0.32),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
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
                const SizedBox(height: 20),
                Text(
                  provider.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: state.textStyle(
                    context,
                    size: 19,
                    weight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
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
                          size: 12,
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
          if (dragHandle != null)
            Positioned(right: 10, bottom: 10, child: dragHandle!),
        ],
      ),
    );
  }
}

class _ProviderDragHandle extends StatelessWidget {
  const _ProviderDragHandle({required this.state});

  final WeaviewState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: state.isDark(context)
            ? Colors.white.withValues(alpha: 0.10)
            : const Color(0xFFF0F3F3),
        shape: BoxShape.circle,
        border: Border.all(color: state.text(context).withValues(alpha: 0.08)),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.drag_indicator_rounded,
        size: 18,
        color: state.text(context).withValues(alpha: 0.48),
      ),
    );
  }
}
