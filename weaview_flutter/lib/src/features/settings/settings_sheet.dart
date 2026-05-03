// ignore_for_file: use_key_in_widget_constructors

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_constants.dart';
import '../../app/weaview_state.dart';
import '../../core/app_utils.dart';
import '../../data/ai/ai_gateway.dart';
import '../../domain/models.dart';
import '../../shared/widgets/shared_widgets.dart';

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({
    required this.state,
    required this.open,
    required this.onClose,
    required this.onPickAvatar,
    required this.showSnack,
  });

  final WeaviewState state;
  final bool open;
  final VoidCallback onClose;
  final Future<void> Function(bool userAvatar) onPickAvatar;
  final ValueChanged<String> showSnack;

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  String _activeTab = 'general';
  String _subView = 'main';
  String? _editingRole;
  AiProvider? _editingProvider;
  String _providerName = '';
  String _providerKey = '';
  String _providerBaseUrl = '';
  List<AiModel> _providerModels = [];
  String _providerTab = 'config';
  String _statusText = '';
  TtsProviderConfig? _editingTts;
  final TextEditingController _memory = TextEditingController();
  final TextEditingController _systemPrompt = TextEditingController();
  late ModelAssignment _roleDraft;

  static const _tabs = [
    ('general', '通用', Icons.settings_outlined),
    ('providers', '提供商', Icons.cloud_outlined),
    ('models', '默认模型', Icons.memory_outlined),
    ('services', '扩展服务', Icons.layers_outlined),
    ('data', '数据管理', Icons.storage_outlined),
    ('about', '关于织境', Icons.info_outline_rounded),
  ];

  static const _roles = {
    'chat': ('主对话模型', '用于处理主要对话和生成内容'),
    'title': ('标题总结模型', '用于生成历史记录标题 (需要快速)'),
    'suggest': ('聊天建议模型', '生成后续对话建议'),
    'translate': ('翻译模型', '用于语言翻译功能'),
  };

  static const _engines = [
    ('tavily', 'Tavily AI', 'Tavily 提供专为 AI 打造的快速搜索服务。'),
    ('brave', 'Brave Search', 'Brave Search 提供完整的独立索引。'),
    ('perplexity', 'Perplexity', 'Perplexity 提供强大的智能问答引擎。'),
  ];

  @override
  void initState() {
    super.initState();
    _systemPrompt.text = widget.state.systemPrompt;
    _roleDraft = widget.state.modelAssignments['chat']!;
  }

  @override
  void didUpdateWidget(covariant SettingsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.open && widget.open) {
      _systemPrompt.text = widget.state.systemPrompt;
    }
  }

  @override
  void dispose() {
    _memory.dispose();
    _systemPrompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return PopScope(
      canPop: _subView == 'main',
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _back();
      },
      child: Scaffold(
        backgroundColor: state.background(context),
        body: Column(
          children: [
            _sheetHeader(),
            Expanded(child: _sheetBody()),
          ],
        ),
      ),
    );
  }

  Widget _sheetHeader() {
    final state = widget.state;
    final title = switch (_subView) {
      'system_prompt' => '全局系统提示词',
      'memory_management' => '记忆管理',
      'provider_config' => '供应商配置',
      'model_role_config' =>
        _editingRole == null ? '默认模型' : _roles[_editingRole!]!.$1,
      'search_engine_config' => '搜索服务配置',
      'tts_config' => '语音服务配置',
      _ => '设置',
    };
    return SafeArea(
      bottom: false,
      child: Container(
        decoration: BoxDecoration(
          color: state.background(context),
          border: Border(
            bottom: BorderSide(
              color: state.text(context).withValues(alpha: 0.06),
            ),
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 58,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: _subView == 'main' ? _close : _back,
                    icon: Icon(
                      _subView == 'main'
                          ? Icons.close_rounded
                          : Icons.chevron_left_rounded,
                      size: 22,
                    ),
                    label: Text(_subView == 'main' ? '关闭' : '返回'),
                    style: TextButton.styleFrom(
                      foregroundColor: state
                          .text(context)
                          .withValues(alpha: 0.82),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: state.textStyle(
                          context,
                          size: _subView == 'main' ? 20 : 17,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 92),
                ],
              ),
            ),
            if (_subView == 'main')
              SizedBox(
                height: 50,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 5,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: _tabs.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final tab = _tabs[index];
                    final active = _activeTab == tab.$1;
                    final activeColor = state.accents[0].withValues(
                      alpha: state.isDark(context) ? 0.18 : 0.22,
                    );
                    final inactiveColor = state
                        .text(context)
                        .withValues(alpha: 0.055);
                    return ChoiceChip(
                      selected: active,
                      showCheckmark: false,
                      avatar: Icon(
                        tab.$3,
                        size: 17,
                        color: active
                            ? (state.isDark(context)
                                  ? accentMint
                                  : const Color(0xFF007A78))
                            : state.text(context).withValues(alpha: 0.62),
                      ),
                      label: Text(tab.$2),
                      onSelected: (_) => setState(() => _activeTab = tab.$1),
                      labelStyle: state
                          .textStyle(
                            context,
                            size: 13,
                            weight: FontWeight.w600,
                            opacity: active ? 1 : 0.72,
                          )
                          .copyWith(
                            color: state
                                .text(context)
                                .withValues(alpha: active ? 0.96 : 0.72),
                          ),
                      selectedColor: activeColor,
                      disabledColor: inactiveColor,
                      backgroundColor: inactiveColor,
                      surfaceTintColor: Colors.transparent,
                      elevation: 0,
                      pressElevation: 0,
                      side: BorderSide(
                        color: active
                            ? state.accents[0].withValues(alpha: 0.45)
                            : Colors.transparent,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sheetBody() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      child: _subView == 'main'
          ? _mainTabBody()
          : switch (_subView) {
              'system_prompt' => _systemPromptView(),
              'memory_management' => _memoryView(),
              'provider_config' => _providerConfigView(),
              'model_role_config' => _modelRoleConfigView(),
              'search_engine_config' => _searchConfigView(),
              'tts_config' => _ttsConfigView(),
              _ => const SizedBox.shrink(),
            },
    );
  }

  Widget _mainTabBody() {
    return switch (_activeTab) {
      'general' => _generalTab(),
      'providers' => _providersTab(),
      'models' => _modelsTab(),
      'services' => _servicesTab(),
      'data' => _dataTab(),
      'about' => _aboutTab(),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _scroll(List<Widget> children, {double bottomPadding = 28}) {
    return ListView(
      key: ValueKey('$_activeTab-$_subView-$_providerTab'),
      padding: EdgeInsets.fromLTRB(
        22,
        22,
        22,
        bottomPadding + MediaQuery.paddingOf(context).bottom,
      ),
      physics: const BouncingScrollPhysics(),
      children: children,
    );
  }

  Widget _bottomActionPage({
    required List<Widget> children,
    required Widget actions,
    String? status,
  }) {
    final state = widget.state;
    return Column(
      key: ValueKey('$_activeTab-$_subView-$_providerTab-actions'),
      children: [
        Expanded(child: _scroll(children, bottomPadding: 18)),
        SettingsActionBar(state: state, status: status, child: actions),
      ],
    );
  }

  Widget _generalTab() {
    final state = widget.state;
    return _scroll([
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
              onTap: () => setState(() {
                _systemPrompt.text = state.systemPrompt;
                _subView = 'system_prompt';
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
              onTap: () => setState(() => _subView = 'memory_management'),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _providersTab() {
    final state = widget.state;
    return _scroll([
      Row(
        children: [
          Expanded(
            child: SectionLabel(state: state, label: '模型提供商'),
          ),
          TextButton.icon(
            onPressed: () => _openProviderConfig(null),
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
            onTap: () => _openProviderConfig(provider),
            onLongPress: () => _confirmDeleteProvider(provider.name),
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

  Widget _modelsTab() {
    final state = widget.state;
    return _scroll([
      SectionLabel(state: state, label: '默认模型分配'),
      for (final entry in _roles.entries)
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
                setState(() {
                  _editingRole = entry.key;
                  _roleDraft = state.modelAssignments[entry.key]!;
                  _subView = 'model_role_config';
                });
              },
            ),
          ),
        ),
    ]);
  }

  Widget _servicesTab() {
    final state = widget.state;
    return _scroll([
      SectionLabel(state: state, label: '搜索服务', icon: Icons.public_rounded),
      CardShell(
        state: state,
        child: Column(
          children: [
            SettingsRow(
              state: state,
              title: '默认搜索引擎',
              subtitle:
                  '正在使用: ${_engines.firstWhere((e) => e.$1 == state.searchConfig.active, orElse: () => _engines.first).$2}',
              showChevron: true,
              onTap: () => setState(() => _subView = 'search_engine_config'),
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
                  setState(() {
                    _editingTts = tts;
                    _subView = 'tts_config';
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
                setState(() {
                  _editingTts = TtsProviderConfig(
                    id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                    type: 'openai',
                    name: '自定义 TTS',
                    apiKey: '',
                    baseUrl: '',
                    model: '',
                    voice: '',
                  );
                  _subView = 'tts_config';
                });
              },
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _dataTab() {
    final state = widget.state;
    final sessionBytes = utf8.encode(jsonEncode(state.chatSessions)).length;
    final providerBytes = utf8
        .encode(jsonEncode(state.providers.map((p) => p.safeJson()).toList()))
        .length;
    final memoryBytes = utf8.encode(jsonEncode(state.memories)).length;
    final total = sessionBytes + providerBytes + memoryBytes;
    return _scroll([
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
              onTap: _confirmClearData,
            ),
          ),
        ],
      ),
    ]);
  }

  Widget _aboutTab() {
    final state = widget.state;
    return _scroll([
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

  Widget _systemPromptView() {
    final state = widget.state;
    return _scroll([
      Text(
        '修改此提示词将改变AI在此环境中的表现形态与语言风格。如果您想恢复，请清空内容。',
        style: state.textStyle(context, size: 13, opacity: 0.55, height: 1.5),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.48,
        child: TextField(
          controller: _systemPrompt,
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
          _systemPrompt.text = defaultSystemInstruction;
          state.updateSystemPrompt(defaultSystemInstruction);
        },
      ),
    ]);
  }

  Widget _memoryView() {
    final state = widget.state;
    return _scroll([
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
      SectionLabel(state: state, label: '用户记忆'),
      if (state.memories.isEmpty)
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
        for (var i = 0; i < state.memories.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CardShell(
              state: state,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: state.accents[0].withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 15,
                      color: state.text(context).withValues(alpha: 0.56),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      state.memories[i],
                      style: state.textStyle(context, size: 14, height: 1.45),
                    ),
                  ),
                  TinyIcon(
                    icon: Icons.delete_outline_rounded,
                    color: Colors.red,
                    onTap: () => state.deleteMemory(i),
                  ),
                ],
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
                controller: _memory,
                style: state.textStyle(context, size: 14),
                decoration: inputDecoration(state, hint: '输入需要记住的信息...'),
                onSubmitted: (_) => _addMemory(),
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
                onTap: _addMemory,
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

  Widget _providerConfigView() {
    final state = widget.state;
    final content = [
      SegmentedPills(
        state: state,
        value: _providerTab,
        items: const {'config': '配置', 'models': '模型'},
        onChanged: (value) => setState(() => _providerTab = value),
      ),
      const SizedBox(height: 24),
      Center(
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: state.text(context).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.cloud_outlined,
                size: 32,
                color: state.text(context).withValues(alpha: 0.62),
              ),
            ),
            const SizedBox(height: 14),
            if (_editingProvider == null)
              SizedBox(
                width: 220,
                child: TextField(
                  textAlign: TextAlign.center,
                  controller: TextEditingController(text: _providerName)
                    ..selection = TextSelection.collapsed(
                      offset: _providerName.length,
                    ),
                  onChanged: (value) => _providerName = value,
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
                _providerName,
                style: state.textStyle(
                  context,
                  size: 20,
                  weight: FontWeight.w500,
                ),
              ),
            const SizedBox(height: 6),
            Text(
              '配置此提供商的API凭据以启用相关模型',
              style: state.textStyle(context, size: 13, opacity: 0.52),
            ),
          ],
        ),
      ),
      const SizedBox(height: 26),
      if (_providerTab == 'config') ...[
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
          controller: TextEditingController(text: _providerKey)
            ..selection = TextSelection.collapsed(offset: _providerKey.length),
          obscureText: true,
          onChanged: (value) => _providerKey = value,
          style: state.textStyle(context, size: 14),
          decoration: inputDecoration(state, hint: '请输入 Provider API Key...'),
        ),
        const SizedBox(height: 18),
        Text(
          'Base URL (可选)',
          style: state.textStyle(
            context,
            size: 13,
            weight: FontWeight.w600,
            opacity: 0.62,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: TextEditingController(text: _providerBaseUrl)
            ..selection = TextSelection.collapsed(
              offset: _providerBaseUrl.length,
            ),
          onChanged: (value) => _providerBaseUrl = value,
          style: state.textStyle(context, size: 14),
          decoration: inputDecoration(
            state,
            hint: 'https://api.example.com/v1',
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'API Key 仅存储在本机 SharedPreferences 中，不会被发送给除所选模型服务外的第三方。',
          style: state.textStyle(
            context,
            size: 11,
            opacity: 0.42,
            height: 1.45,
          ),
        ),
      ] else ...[
        if (_providerModels.isEmpty)
          Padding(
            padding: const EdgeInsets.all(28),
            child: Text(
              '暂无可用模型，请拉取或手动添加',
              textAlign: TextAlign.center,
              style: state.textStyle(context, size: 13, opacity: 0.42),
            ),
          )
        else
          for (final model in _providerModels)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CardShell(
                state: state,
                child: SettingsRow(
                  state: state,
                  title: model.name,
                  subtitle: model.id,
                  leading: Icon(
                    Icons.memory_rounded,
                    color: state.text(context).withValues(alpha: 0.55),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TinyIcon(
                        icon: Icons.edit_outlined,
                        color: state.text(context),
                        onTap: () => _editModel(model),
                      ),
                      TinyIcon(
                        icon: Icons.close_rounded,
                        color: Colors.red,
                        onTap: () => setState(
                          () => _providerModels = _providerModels
                              .where((m) => m.id != model.id)
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    ];

    return _bottomActionPage(
      children: content,
      status: _statusText,
      actions: _providerTab == 'config'
          ? Row(
              children: [
                Expanded(
                  child: SoftButton(
                    state: state,
                    label: '保存配置',
                    accent: true,
                    onTap: () => _saveProvider(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SoftButton(
                    state: state,
                    label: '启用',
                    onTap: () => _saveProvider(true),
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
                    onTap: _addManualModel,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SoftButton(
                    state: state,
                    label: '拉取',
                    onTap: _pullModels,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SoftButton(
                    state: state,
                    label: '测试',
                    onTap: _testProvider,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _modelRoleConfigView() {
    final state = widget.state;
    final providers = state.providers;
    final providerModels =
        providers
            .firstWhereOrNull((p) => p.name == _roleDraft.provider)
            ?.models ??
        const <AiModel>[];
    return _scroll([
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
              value: _roleDraft.provider.isEmpty ? '未选择' : _roleDraft.provider,
              items: ['未选择', ...providers.map((p) => p.name)],
              onChanged: (value) => setState(() {
                _roleDraft = _roleDraft.copyWith(
                  provider: value == '未选择' ? '' : value,
                  model: '',
                );
              }),
            ),
            const SizedBox(height: 14),
            DropdownField(
              state: state,
              label: '模型',
              value: _roleDraft.model.isEmpty ? '未选择' : _roleDraft.model,
              items: ['未选择', ...providerModels.map((m) => m.name)],
              enabled: _roleDraft.provider.isNotEmpty,
              onChanged: (value) => setState(() {
                _roleDraft = _roleDraft.copyWith(
                  model: value == '未选择' ? '' : value,
                );
              }),
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
              controller: TextEditingController(text: _roleDraft.prompt)
                ..selection = TextSelection.collapsed(
                  offset: _roleDraft.prompt.length,
                ),
              maxLines: 7,
              style: state.textStyle(context, size: 14, height: 1.55),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '输入自定义提示词...',
              ),
              onChanged: (value) =>
                  _roleDraft = _roleDraft.copyWith(prompt: value),
            ),
            DividerLine(state: state),
            Row(
              children: [
                Text(
                  '${_roleDraft.prompt.length} 字符',
                  style: state.textStyle(context, size: 11, opacity: 0.42),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() {
                    _roleDraft = _roleDraft.copyWith(
                      prompt: ModelAssignment.defaults()[_editingRole]!.prompt,
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
          if (_editingRole != null) {
            state.saveModelAssignment(_editingRole!, _roleDraft);
          }
          _back();
        },
      ),
    ]);
  }

  Widget _searchConfigView() {
    final state = widget.state;
    return _scroll([
      Text(
        '配置默认的搜索引擎与对应的API Key。您可以自行注册并获取各个厂商的密钥。',
        style: state.textStyle(context, size: 13, opacity: 0.55, height: 1.5),
      ),
      const SizedBox(height: 20),
      for (final engine in _engines)
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
                  TextField(
                    obscureText: true,
                    controller: TextEditingController(
                      text: state.searchConfig.keys[engine.$1] ?? '',
                    ),
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

  Widget _ttsConfigView() {
    final state = widget.state;
    var draft =
        _editingTts ??
        TtsProviderConfig(
          id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
          type: 'openai',
          name: '自定义 TTS',
          apiKey: '',
          baseUrl: '',
          model: '',
          voice: '',
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
              TextField(
                controller: TextEditingController(text: value)
                  ..selection = TextSelection.collapsed(offset: value.length),
                obscureText: obscure,
                onChanged: (value) => setLocal(() => onChanged(value)),
                style: state.textStyle(context, size: 15),
                decoration: inputDecoration(state, hint: hint),
              ),
              const SizedBox(height: 16),
            ],
          );
        }

        return _scroll([
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
              DropdownMenuItem(value: 'azure', child: Text('Azure TTS')),
              DropdownMenuItem(value: 'edge', child: Text('Edge TTS')),
              DropdownMenuItem(value: 'custom', child: Text('自定义 (Custom)')),
            ],
            onChanged: (value) => setLocal(() {
              draft = draft.copyWith(type: value ?? draft.type);
              _editingTts = draft;
            }),
          ),
          const SizedBox(height: 16),
          field(
            label: '显示名称',
            value: draft.name,
            hint: '例如：OpenAI 语音',
            onChanged: (value) {
              draft = draft.copyWith(name: value);
              _editingTts = draft;
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
                _editingTts = draft;
              },
            ),
          field(
            label: 'Base URL',
            value: draft.baseUrl,
            hint: 'https://api.openai.com/v1',
            onChanged: (value) {
              draft = draft.copyWith(baseUrl: value);
              _editingTts = draft;
            },
          ),
          field(
            label: '模型名称 (Model)',
            value: draft.model,
            hint: '例如: tts-1, tts-1-hd',
            onChanged: (value) {
              draft = draft.copyWith(model: value);
              _editingTts = draft;
            },
          ),
          field(
            label: '合成语音 (Voice)',
            value: draft.voice,
            hint: '例如: alloy, echo, fable',
            onChanged: (value) {
              draft = draft.copyWith(voice: value);
              _editingTts = draft;
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
                  state.activeTtsId == draft.id ? 'system' : state.activeTtsId,
                );
                _back();
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
              final next = [...state.ttsProviders];
              final index = next.indexWhere((t) => t.id == draft.id);
              if (index >= 0) {
                next[index] = draft;
              } else {
                next.add(draft);
              }
              state.saveTtsConfig(next, state.activeTtsId);
              _back();
            },
          ),
        ]);
      },
    );
  }

  void _close() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_subView == 'provider_config') {
      _saveProvider(false, pop: false);
    }
    widget.onClose();
    Future<void>.delayed(const Duration(milliseconds: 260), () {
      if (mounted) setState(() => _subView = 'main');
    });
  }

  void _back() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_subView == 'provider_config') {
      _saveProvider(false, pop: false);
    }
    setState(() {
      _subView = 'main';
      _editingRole = null;
      _editingProvider = null;
      _editingTts = null;
      _statusText = '';
    });
  }

  void _addMemory() {
    widget.state.addMemory(_memory.text);
    _memory.clear();
  }

  void _openProviderConfig(AiProvider? provider) {
    setState(() {
      _editingProvider = provider;
      _providerName = provider?.name ?? '';
      _providerKey = provider?.apiKey ?? '';
      _providerBaseUrl = provider == null || provider.baseUrl.trim().isEmpty
          ? ''
          : AiGateway.normalizeBaseUrl(provider.baseUrl);
      _providerModels = [...provider?.models ?? const <AiModel>[]];
      _providerTab = 'config';
      _statusText = '';
      _subView = 'provider_config';
    });
  }

  void _saveProvider(bool makeCurrent, {bool pop = true}) {
    final name = (_editingProvider?.name ?? _providerName).trim();
    if (name.isEmpty) {
      if (pop) widget.showSnack('请输入提供商名称。');
      return;
    }
    final keepCurrent = makeCurrent || (_editingProvider?.current ?? false);
    final status = keepCurrent
        ? '使用中'
        : _providerKey.trim().isEmpty
        ? '未配置'
        : '已连接';
    widget.state.upsertProvider(
      AiProvider(
        name: name,
        status: status,
        current: keepCurrent,
        color: _editingProvider?.color ?? providerFallbackColor(name),
        apiKey: _providerKey.trim(),
        baseUrl: _providerBaseUrl.trim().isEmpty
            ? ''
            : AiGateway.normalizeBaseUrl(_providerBaseUrl),
        models: _providerModels,
      ),
      makeCurrent: makeCurrent,
    );
    if (pop) _back();
  }

  Future<void> _pullModels() async {
    if (_providerKey.trim().isEmpty) {
      setState(() => _statusText = '需要 API Key 才能拉取。');
      return;
    }
    setState(() => _statusText = '正在拉取模型列表...');
    try {
      final models = await AiGateway.fetchModels(
        apiKey: _providerKey.trim(),
        baseUrl: _providerBaseUrl.trim().isEmpty
            ? 'https://api.openai.com/v1'
            : _providerBaseUrl.trim(),
      );
      if (!mounted) return;
      final selected = await showDialog<List<AiModel>>(
        context: context,
        builder: (context) =>
            ModelPickerDialog(state: widget.state, models: models),
      );
      if (selected != null && selected.isNotEmpty) {
        setState(() {
          final existing = _providerModels.map((m) => m.id).toSet();
          _providerModels = [
            ..._providerModels,
            for (final model in selected)
              if (!existing.contains(model.id)) model,
          ];
          _statusText = '已添加 ${selected.length} 个模型。';
        });
      } else {
        setState(() => _statusText = '未选择模型。');
      }
    } catch (error) {
      setState(() => _statusText = '拉取失败：$error');
    }
  }

  Future<void> _testProvider() async {
    if (_providerKey.trim().isEmpty || _providerModels.isEmpty) {
      setState(() => _statusText = '请先配置 API Key 并添加至少一个模型。');
      return;
    }
    final model = await showDialog<AiModel>(
      context: context,
      builder: (context) =>
          TestModelDialog(state: widget.state, models: _providerModels),
    );
    if (model == null) return;
    setState(() => _statusText = '正在测试连接...');
    try {
      final message = await AiGateway.testConnection(
        apiKey: _providerKey.trim(),
        baseUrl: _providerBaseUrl.trim().isEmpty
            ? 'https://api.openai.com/v1'
            : _providerBaseUrl.trim(),
        model: model.id,
      );
      setState(() => _statusText = message);
    } catch (error) {
      setState(() => _statusText = '连接失败：$error');
    }
  }

  Future<void> _addManualModel() async {
    final name = await _textDialog('添加新模型', '例如: gpt-4-turbo');
    if (name == null || name.trim().isEmpty) return;
    setState(() {
      _providerModels = [
        ..._providerModels,
        AiModel(
          id: name.trim(),
          name: name.trim(),
          capabilities: const ['chat'],
        ),
      ];
    });
  }

  Future<void> _editModel(AiModel model) async {
    final edited = await showDialog<AiModel>(
      context: context,
      builder: (context) => EditModelDialog(state: widget.state, model: model),
    );
    if (edited == null) return;
    setState(() {
      _providerModels = _providerModels
          .map((m) => m.id == edited.id ? edited : m)
          .toList();
    });
  }

  Future<String?> _textDialog(String title, String hint) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteProvider(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除提供商'),
        content: Text('确定要删除提供商 "$name" 吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.state.deleteProvider(name);
    }
  }

  Future<void> _confirmClearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空所有缓存'),
        content: const Text('这会删除本地对话、记忆和配置。确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.state.clearAllLocalData();
      widget.showSnack('本地缓存已清空。');
    }
  }
}
