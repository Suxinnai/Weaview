// ignore_for_file: use_key_in_widget_constructors

import 'package:flutter/material.dart';

import '../../app/app_constants.dart';
import '../../app/weaview_state.dart';
import '../../core/app_utils.dart';
import '../../data/ai/ai_gateway.dart';
import '../../domain/models.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'sections/settings_detail_views.dart';
import 'sections/settings_tabs.dart';

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
  State<SettingsSheet> createState() => SettingsSheetState();
}

class SettingsSheetState extends State<SettingsSheet> {
  String activeTab = 'general';
  String subView = 'main';
  String? editingRole;
  AiProvider? editingProvider;
  String providerName = '';
  String providerKey = '';
  String providerBaseUrl = '';
  List<AiModel> providerModels = [];
  String providerTab = 'config';
  String statusText = '';
  TtsProviderConfig? editingTts;
  final TextEditingController memoryController = TextEditingController();
  final TextEditingController systemPromptController = TextEditingController();
  final TextEditingController profileController = TextEditingController();
  late ModelAssignment roleDraft;
  final Set<String> deletingProviders = {};
  String? providerDeleteTarget;
  String? draggingProviderName;

  static const settingsTabs = [
    ('general', '通用', Icons.settings_outlined),
    ('providers', '提供商', Icons.cloud_outlined),
    ('models', '默认模型', Icons.memory_outlined),
    ('services', '扩展服务', Icons.layers_outlined),
    ('data', '数据管理', Icons.storage_outlined),
    ('about', '关于织境', Icons.info_outline_rounded),
  ];

  static const settingsRoles = {
    'chat': ('主对话模型', '用于处理主要对话和生成内容'),
    'title': ('标题总结模型', '用于生成历史记录标题 (需要快速)'),
    'suggest': ('聊天建议模型', '生成后续对话建议'),
    'translate': ('翻译模型', '用于语言翻译功能'),
    'tool': ('工具模型', '用于人物画像补全与记忆整理'),
  };

  static const settingsEngines = [
    ('tavily', 'Tavily AI', 'Tavily 提供专为 AI 打造的快速搜索服务。'),
    ('brave', 'Brave Search', 'Brave Search 提供完整的独立索引。'),
    ('perplexity', 'Perplexity', 'Perplexity 提供强大的智能问答引擎。'),
  ];

  @override
  void initState() {
    super.initState();
    systemPromptController.text = widget.state.systemPrompt;
    profileController.text = widget.state.userProfile;
    roleDraft = widget.state.modelAssignments['chat']!;
  }

  @override
  void didUpdateWidget(covariant SettingsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.open && widget.open) {
      systemPromptController.text = widget.state.systemPrompt;
      profileController.text = widget.state.userProfile;
    }
  }

  @override
  void dispose() {
    memoryController.dispose();
    systemPromptController.dispose();
    profileController.dispose();
    super.dispose();
  }

  void updateSheet(VoidCallback fn) => setState(fn);

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return PopScope(
      canPop: subView == 'main',
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        goBack();
      },
      child: Scaffold(
        backgroundColor: state.background(context),
        body: Column(
          children: [
            sheetHeader(),
            Expanded(child: sheetBody()),
          ],
        ),
      ),
    );
  }

  Widget sheetHeader() {
    final state = widget.state;
    final title = switch (subView) {
      'system_prompt' => '全局系统提示词',
      'user_profile' => '人物画像',
      'memory_management' => '记忆管理',
      'provider_config' => '供应商配置',
      'model_role_config' =>
        editingRole == null
            ? '默认模型'
            : SettingsSheetState.settingsRoles[editingRole!]!.$1,
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
                    onPressed: subView == 'main' ? closeSheet : goBack,
                    icon: Icon(
                      subView == 'main'
                          ? Icons.close_rounded
                          : Icons.chevron_left_rounded,
                      size: 22,
                    ),
                    label: Text(subView == 'main' ? '关闭' : '返回'),
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
                          size: subView == 'main' ? 20 : 17,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 92),
                ],
              ),
            ),
            if (subView == 'main')
              SizedBox(
                height: 50,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 5,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: SettingsSheetState.settingsTabs.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final tab = SettingsSheetState.settingsTabs[index];
                    final active = activeTab == tab.$1;
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
                      onSelected: (_) => setState(() => activeTab = tab.$1),
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

  Widget sheetBody() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      child: subView == 'main'
          ? mainTabBody()
          : switch (subView) {
              'system_prompt' => systemPromptView(),
              'user_profile' => userProfileView(),
              'memory_management' => memoryView(),
              'provider_config' => providerConfigView(),
              'model_role_config' => modelRoleConfigView(),
              'search_engine_config' => searchConfigView(),
              'tts_config' => ttsConfigView(),
              _ => const SizedBox.shrink(),
            },
    );
  }

  Widget mainTabBody() {
    return switch (activeTab) {
      'general' => generalTab(),
      'providers' => providersTab(),
      'models' => modelsTab(),
      'services' => servicesTab(),
      'data' => dataTab(),
      'about' => aboutTab(),
      _ => const SizedBox.shrink(),
    };
  }

  Widget scrollContent(List<Widget> children, {double bottomPadding = 28}) {
    return ListView(
      key: ValueKey('$activeTab-$subView-$providerTab'),
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

  Widget bottomActionPage({
    required List<Widget> children,
    required Widget actions,
    String? status,
  }) {
    final state = widget.state;
    return Column(
      key: ValueKey('$activeTab-$subView-$providerTab-actions'),
      children: [
        Expanded(child: scrollContent(children, bottomPadding: 18)),
        SettingsActionBar(state: state, status: status, child: actions),
      ],
    );
  }

  void closeSheet() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (subView == 'provider_config') {
      saveProvider(false, pop: false);
    }
    widget.onClose();
    Future<void>.delayed(const Duration(milliseconds: 260), () {
      if (mounted) {
        setState(() {
          subView = 'main';
          providerDeleteTarget = null;
          draggingProviderName = null;
        });
      }
    });
  }

  void goBack() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (subView == 'provider_config') {
      saveProvider(false, pop: false);
    }
    setState(() {
      subView = 'main';
      editingRole = null;
      editingProvider = null;
      editingTts = null;
      statusText = '';
      providerDeleteTarget = null;
      draggingProviderName = null;
    });
  }

  void addMemory() {
    widget.state.addMemory(memoryController.text);
    memoryController.clear();
  }

  Future<void> completeUserProfile() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => statusText = '正在调用工具模型补全人物画像...');
    try {
      await widget.state.completeUserProfileWithToolModel();
      profileController.text = widget.state.userProfile;
      setState(() => statusText = '');
      widget.showSnack('人物画像已补全。');
    } catch (error) {
      setState(() => statusText = '');
      widget.showSnack(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> organizeMemories() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => statusText = '正在调用工具模型整理记忆...');
    try {
      await widget.state.organizeMemoriesWithToolModel();
      setState(() => statusText = '');
      widget.showSnack('记忆已整理。');
    } catch (error) {
      setState(() => statusText = '');
      widget.showSnack(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void openProviderConfig(AiProvider? provider) {
    setState(() {
      providerDeleteTarget = null;
      draggingProviderName = null;
      editingProvider = provider;
      providerName = provider?.name ?? '';
      providerKey = provider?.apiKey ?? '';
      providerBaseUrl = provider == null || provider.baseUrl.trim().isEmpty
          ? ''
          : AiGateway.normalizeBaseUrl(provider.baseUrl);
      providerModels = [...provider?.models ?? const <AiModel>[]];
      providerTab = 'config';
      statusText = '';
      subView = 'provider_config';
    });
  }

  void saveProvider(bool makeCurrent, {bool pop = true}) {
    final name = (editingProvider?.name ?? providerName).trim();
    if (name.isEmpty) {
      if (pop) widget.showSnack('请输入提供商名称。');
      return;
    }
    final keepCurrent = makeCurrent || (editingProvider?.current ?? false);
    final status = keepCurrent
        ? '使用中'
        : providerKey.trim().isEmpty
        ? '未配置'
        : '已连接';
    widget.state.upsertProvider(
      AiProvider(
        name: name,
        status: status,
        current: keepCurrent,
        color: editingProvider?.color ?? providerFallbackColor(name),
        apiKey: providerKey.trim(),
        baseUrl: providerBaseUrl.trim().isEmpty
            ? ''
            : AiGateway.normalizeBaseUrl(providerBaseUrl),
        models: providerModels,
      ),
      makeCurrent: makeCurrent,
    );
    if (pop) goBack();
  }

  Future<void> pullModels() async {
    if (providerKey.trim().isEmpty) {
      setState(() => statusText = '需要 API Key 才能拉取。');
      return;
    }
    setState(() => statusText = '正在拉取模型列表...');
    try {
      final models = await AiGateway.fetchModels(
        apiKey: providerKey.trim(),
        baseUrl: providerBaseUrl.trim().isEmpty
            ? 'https://api.openai.com/v1'
            : providerBaseUrl.trim(),
      );
      if (!mounted) return;
      final selected = await showDialog<List<AiModel>>(
        context: context,
        builder: (context) =>
            ModelPickerDialog(state: widget.state, models: models),
      );
      if (selected != null && selected.isNotEmpty) {
        setState(() {
          final existing = providerModels.map((m) => m.id).toSet();
          providerModels = [
            ...providerModels,
            for (final model in selected)
              if (!existing.contains(model.id)) model,
          ];
          statusText = '已添加 ${selected.length} 个模型。';
        });
      } else {
        setState(() => statusText = '未选择模型。');
      }
    } catch (error) {
      setState(() => statusText = '拉取失败：$error');
    }
  }

  Future<void> testProvider() async {
    if (providerKey.trim().isEmpty || providerModels.isEmpty) {
      setState(() => statusText = '请先配置 API Key 并添加至少一个模型。');
      return;
    }
    final model = await showDialog<AiModel>(
      context: context,
      builder: (context) =>
          TestModelDialog(state: widget.state, models: providerModels),
    );
    if (model == null) return;
    setState(() => statusText = '正在测试连接...');
    try {
      final message = await AiGateway.testConnection(
        apiKey: providerKey.trim(),
        baseUrl: providerBaseUrl.trim().isEmpty
            ? 'https://api.openai.com/v1'
            : providerBaseUrl.trim(),
        model: model.id,
      );
      setState(() => statusText = message);
    } catch (error) {
      setState(() => statusText = '连接失败：$error');
    }
  }

  Future<void> addManualModel() async {
    final name = await textDialog('添加新模型', '例如: gpt-4-turbo');
    if (name == null || name.trim().isEmpty) return;
    setState(() {
      providerModels = [
        ...providerModels,
        AiModel(
          id: name.trim(),
          name: name.trim(),
          capabilities: const ['chat'],
        ),
      ];
    });
  }

  Future<void> editModel(AiModel model) async {
    final edited = await showDialog<AiModel>(
      context: context,
      builder: (context) => EditModelDialog(state: widget.state, model: model),
    );
    if (edited == null) return;
    setState(() {
      providerModels = providerModels
          .map((m) => m.id == edited.id ? edited : m)
          .toList();
    });
  }

  Future<String?> textDialog(String title, String hint) {
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

  Future<void> confirmDeleteProvider(String name) async {
    if (deletingProviders.contains(name)) return;
    deletingProviders.add(name);
    try {
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
        if (mounted) {
          setState(() {
            providerDeleteTarget = null;
            draggingProviderName = null;
          });
        }
      }
    } finally {
      deletingProviders.remove(name);
    }
  }

  Future<void> confirmClearData() async {
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
