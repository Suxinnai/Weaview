// ignore_for_file: use_key_in_widget_constructors

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../app/app_constants.dart';
import '../../app/app_version.dart';
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
  static const MethodChannel _nativeLinks = MethodChannel(
    'weaview/native_links',
  );

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
  final TextEditingController rolePromptController = TextEditingController();
  final TextEditingController feedbackTitleController = TextEditingController();
  final TextEditingController feedbackDetailController =
      TextEditingController();
  final TextEditingController feedbackStepsController = TextEditingController();
  final TextEditingController feedbackContactController =
      TextEditingController();
  final TextEditingController providerNameController = TextEditingController();
  final TextEditingController providerKeyController = TextEditingController();
  final TextEditingController providerBaseUrlController =
      TextEditingController();
  late final Future<AppVersionInfo> appVersionInfoFuture;
  late ModelAssignment roleDraft;
  final Set<String> deletingProviders = {};
  String? providerDeleteTarget;
  String? draggingProviderName;
  String feedbackType = '问题反馈';

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
    'title': ('标题生成模型', '用于生成简短的对话标题'),
    'suggest': ('聊天建议模型', '生成后续对话建议'),
    'translate': ('翻译模型', '用于语言翻译功能'),
    'tool': ('工具模型', '用于人物画像补全与记忆整理'),
    'image': ('生图模型', '用于对话空间中的图片生成模式'),
  };

  static const settingsEngines = [
    ('tavily', 'Tavily AI', 'Tavily 提供专为 AI 打造的快速搜索服务。'),
  ];

  @override
  void initState() {
    super.initState();
    systemPromptController.text = widget.state.systemPrompt;
    profileController.text = widget.state.userProfile;
    appVersionInfoFuture = loadAppVersionInfo();
    roleDraft = widget.state.modelAssignments['chat']!;
    rolePromptController.text = roleDraft.prompt;
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
    rolePromptController.dispose();
    feedbackTitleController.dispose();
    feedbackDetailController.dispose();
    feedbackStepsController.dispose();
    feedbackContactController.dispose();
    providerNameController.dispose();
    providerKeyController.dispose();
    providerBaseUrlController.dispose();
    super.dispose();
  }

  void updateSheet(VoidCallback fn) => setState(fn);

  Color get _headerTextColor =>
      widget.state.text(context).withValues(alpha: 0.92);

  Color get _headerMutedColor =>
      widget.state.text(context).withValues(alpha: 0.62);

  Widget _headerLeadingAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 22),
        label: Text(label),
        style: TextButton.styleFrom(
          foregroundColor: _headerTextColor,
          minimumSize: const Size(84, 44),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          textStyle: widget.state.textStyle(
            context,
            size: 14.5,
            weight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _headerTrailingSpacer() {
    return const SizedBox(width: 96, height: 44);
  }

  Widget _settingsTabButton((String, String, IconData) tab) {
    return _SettingsTabButton(
      tab: tab,
      active: activeTab == tab.$1,
      mutedColor: _headerMutedColor,
      onTap: () => setState(() => activeTab = tab.$1),
      state: widget.state,
    );
  }

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
      'feedback_form' => '报告问题 / 提供反馈',
      _ => '设置',
    };
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: SafeArea(
        bottom: false,
        child: Container(
          decoration: BoxDecoration(
            color: state.background(context),
            border: Border(
              bottom: BorderSide(
                color: state.text(context).withValues(alpha: 0.08),
              ),
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 62,
                child: Row(
                  children: [
                    const SizedBox(width: 10),
                    _headerLeadingAction(
                      icon: subView == 'main'
                          ? Icons.close_rounded
                          : Icons.arrow_back_rounded,
                      label: subView == 'main' ? '关闭' : '返回',
                      onTap: subView == 'main' ? closeSheet : goBack,
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: state.poeticTextStyle(
                            context,
                            size: subView == 'main' ? 19 : 16.5,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    _headerTrailingSpacer(),
                  ],
                ),
              ),
              if (subView == 'main')
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    scrollDirection: Axis.horizontal,
                    itemCount: SettingsSheetState.settingsTabs.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 3),
                    itemBuilder: (context, index) {
                      return _settingsTabButton(
                        SettingsSheetState.settingsTabs[index],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget sheetBody() {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return AnimatedSwitcher(
      duration: duration,
      reverseDuration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          alignment: Alignment.topCenter,
          children: [...previousChildren, ?currentChild],
        );
      },
      transitionBuilder: (child, animation) {
        if (reduceMotion) return child;
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final offset = Tween<Offset>(
          begin: const Offset(0.035, 0),
          end: Offset.zero,
        ).animate(curved);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(position: offset, child: child),
        );
      },
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
              'feedback_form' => feedbackView(),
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

  void closeSheet({bool persistProviderDraft = true}) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (persistProviderDraft && subView == 'provider_config') {
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

  void goBack({bool persistProviderDraft = true}) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (persistProviderDraft && subView == 'provider_config') {
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
      providerNameController.text = providerName;
      providerKeyController.text = providerKey;
      providerBaseUrlController.text = providerBaseUrl;
      providerTab = 'config';
      statusText = '';
      subView = 'provider_config';
    });
  }

  void _syncProviderDraftFromControllers() {
    providerName = providerNameController.text;
    providerKey = providerKeyController.text;
    providerBaseUrl = providerBaseUrlController.text;
  }

  void saveProvider(
    bool makeCurrent, {
    bool pop = true,
    bool? enabledOverride,
  }) {
    _syncProviderDraftFromControllers();
    final name = (editingProvider?.name ?? providerName).trim();
    if (name.isEmpty) {
      if (pop) widget.showSnack('请输入提供商名称。');
      return;
    }
    final enabled = enabledOverride ?? editingProvider?.enabled ?? true;
    final normalizedBaseUrl = providerBaseUrl.trim().isEmpty
        ? ''
        : AiGateway.normalizeBaseUrl(providerBaseUrl);
    final baseUrlIssue = secureBaseUrlIssue(
      normalizedBaseUrl,
      allowEmpty: name.toLowerCase().contains('gemini'),
    );
    if (enabled && baseUrlIssue != null) {
      widget.showSnack(baseUrlIssue);
      return;
    }
    final keepCurrent =
        enabled && (makeCurrent || (editingProvider?.current ?? false));
    final status = !enabled
        ? '已禁用'
        : keepCurrent
        ? '使用中'
        : providerKey.trim().isEmpty
        ? '未配置'
        : '已连接';
    final provider = AiProvider(
      name: name,
      status: status,
      current: keepCurrent,
      enabled: enabled,
      color: editingProvider?.color ?? providerFallbackColor(name),
      apiKey: providerKey.trim(),
      baseUrl: normalizedBaseUrl,
      models: providerModels,
      imageApi: editingProvider?.imageApi ?? ImageApiKind.automatic,
    );
    widget.state.upsertProvider(provider, makeCurrent: makeCurrent);
    editingProvider = widget.state.providers.firstWhereOrNull(
      (item) => item.name == name,
    );
    if (pop) {
      widget.showSnack(
        makeCurrent
            ? '已设为当前提供商。'
            : enabled
            ? '提供商配置已保存。'
            : '提供商已禁用。',
      );
      goBack(persistProviderDraft: false);
    }
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
            ? (providerName.toLowerCase().contains('gemini')
                  ? ''
                  : 'https://api.openai.com/v1')
            : providerBaseUrl.trim(),
        providerName: providerName,
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
            ? (providerName.toLowerCase().contains('gemini')
                  ? ''
                  : 'https://api.openai.com/v1')
            : providerBaseUrl.trim(),
        model: model.id,
        capabilities: model.capabilities,
        providerName: providerName,
      );
      setState(() => statusText = message);
    } catch (error) {
      final message = '连接失败：$error';
      setState(() => statusText = message);
      if (!mounted) return;
      unawaited(
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('连接测试失败'),
            content: SingleChildScrollView(child: SelectableText(message)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('关闭'),
              ),
            ],
          ),
        ),
      );
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

  Future<String?> textDialog(String title, String hint) async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
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
    } finally {
      controller.dispose();
    }
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
        title: const Text('清空所有本地数据'),
        content: const Text(
          '这会删除本机保存的对话记录、长期记忆、模型提供商、默认模型、搜索/TTS 配置和外观偏好。'
          '应用管理的生成图片与备份恢复附件也会删除。'
          '导出的备份不会被删除。确定继续吗？',
        ),
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

  Future<void> openExternalUrl(String url) async {
    try {
      await _nativeLinks.invokeMethod<void>('openUrl', {'url': url});
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: url));
      widget.showSnack('无法直接打开链接，已复制到剪贴板。');
    }
  }

  void openFeedback() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      feedbackType = '问题反馈';
      feedbackTitleController.clear();
      feedbackDetailController.clear();
      feedbackStepsController.clear();
      feedbackContactController.clear();
      statusText = '';
      subView = 'feedback_form';
    });
  }

  Future<void> submitFeedbackForm() async {
    final title = feedbackTitleController.text.trim();
    final detail = feedbackDetailController.text.trim();
    if (title.isEmpty || detail.isEmpty) {
      widget.showSnack('请填写标题和详细描述。');
      return;
    }
    final version = await appVersionInfoFuture;
    final text =
        '''
[$feedbackType] $title

版本：${version.display} (${version.tag})

详细描述：
$detail

复现步骤 / 建议说明：
${feedbackStepsController.text.trim().isEmpty ? '未填写' : feedbackStepsController.text.trim()}

联系方式：
${feedbackContactController.text.trim().isEmpty ? '未填写' : feedbackContactController.text.trim()}
''';
    await Clipboard.setData(ClipboardData(text: text.trim()));
    setState(() {
      statusText = '邮箱通道接入前，已生成一份可提交的反馈内容。';
    });
    widget.showSnack('反馈已提交，已复制一份备用内容。');
  }

  Future<void> checkForUpdates() async {
    final version = await appVersionInfoFuture;
    widget.showSnack('正在检查 GitHub Releases...');
    try {
      final response = await http
          .get(
            Uri.parse(githubReleasesApiUrl),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'Weaview-App',
            },
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('GitHub 返回 ${response.statusCode}');
      }
      final releases = jsonDecode(response.body);
      if (releases is! List || releases.isEmpty) {
        throw Exception('未找到发布记录');
      }
      final latest =
          releases.cast<dynamic>().firstWhere(
                (item) => item is Map && item['draft'] != true,
                orElse: () => releases.first,
              )
              as Map;
      final latestName = latest['name']?.toString().trim().isNotEmpty == true
          ? latest['name'].toString()
          : latest['tag_name']?.toString() ?? '未知版本';
      final latestTag = latest['tag_name']?.toString() ?? '';
      final latestUrl = latest['html_url']?.toString() ?? githubReleasesUrl;
      final publishedAt = latest['published_at']?.toString() ?? '';
      final body = latest['body']?.toString().trim() ?? '';
      final current = latestTag == version.tag;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(current ? '当前已是最新版本' : '发现新版本'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前版本：${version.display}'),
              const SizedBox(height: 8),
              Text('GitHub 最新：$latestName'),
              if (publishedAt.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('发布时间：${publishedAt.split('T').first}'),
              ],
              if (body.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  body
                      .replaceAll(RegExp(r'\s+'), ' ')
                      .characters
                      .take(180)
                      .toString(),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                openExternalUrl(latestUrl);
              },
              child: const Text('查看发布页'),
            ),
          ],
        ),
      );
    } catch (error) {
      widget.showSnack(
        '检查更新失败：${error.toString().replaceFirst('Exception: ', '')}',
      );
      await openExternalUrl(githubReleasesUrl);
    }
  }
}

class _SettingsTabButton extends StatefulWidget {
  const _SettingsTabButton({
    required this.tab,
    required this.active,
    required this.mutedColor,
    required this.onTap,
    required this.state,
  });

  final (String, String, IconData) tab;
  final bool active;
  final Color mutedColor;
  final VoidCallback onTap;
  final WeaviewState state;

  @override
  State<_SettingsTabButton> createState() => _SettingsTabButtonState();
}

class _SettingsTabButtonState extends State<_SettingsTabButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final activeColor = state.isDark(context) ? accentMint : sendGreen;
    return Semantics(
      button: true,
      selected: widget.active,
      label: widget.tab.$2,
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                constraints: const BoxConstraints(minWidth: 58, minHeight: 38),
                padding: const EdgeInsets.fromLTRB(8, 5, 8, 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.tab.$2,
                      style: state
                          .textStyle(
                            context,
                            size: 12.5,
                            weight: widget.active
                                ? FontWeight.w700
                                : FontWeight.w500,
                            opacity: widget.active ? 0.96 : 0.58,
                          )
                          .copyWith(
                            color: widget.active
                                ? activeColor
                                : widget.mutedColor,
                          ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: widget.active ? 20 : 0,
                      height: 2,
                      decoration: BoxDecoration(
                        color: activeColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
