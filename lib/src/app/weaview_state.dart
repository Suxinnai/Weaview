import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_utils.dart';
import '../core/zip_writer.dart';
import '../data/ai/ai_gateway.dart';
import '../data/ai/image_tool_call_parser.dart';
import '../data/ai/openai_compatible_client.dart' show GeneratedImageResult;
import '../domain/models.dart';
import 'ai_theme_guard.dart';
import 'app_constants.dart';
import 'model_config_resolver.dart';
import 'prompt_appearance_intent.dart';
import 'weaview_preferences.dart';

class _ImageAspect {
  const _ImageAspect({required this.label, required this.ratio});

  final String label;
  final double ratio;
}

class _PreparedImageRequest {
  const _PreparedImageRequest({required this.prompt, required this.size});

  final String prompt;
  final String size;
}

class WeaviewState extends ChangeNotifier {
  static const MethodChannel _nativeMedia = MethodChannel(
    'weaview/native_media',
  );

  static const MethodChannel _nativeNotifications = MethodChannel(
    'weaview/native_notifications',
  );

  WeaviewPreferences? _prefs;
  bool loaded = false;
  ThemeMode themeMode = ThemeMode.system;
  Color? backgroundOverride;
  Color? textOverride;
  Color? assistantBubbleOverride;
  Color? userBubbleOverride;
  String fontMood = 'sans';
  String fontStyleMood = 'normal';
  String fontWeightMood = 'normal';
  String bubbleStyle = 'minimal';
  String messageAlignment = 'left';
  double assistantBubbleOpacity = 0.08;
  double userBubbleOpacity = 0.12;
  List<Color> accents = const [accentMint, accentGreen];
  int themePulse = 0;

  String systemPrompt = defaultSystemInstruction;
  bool emotionEnabled = true;
  bool globalMemoryEnabled = true;
  bool referenceHistoryEnabled = false;
  String assistantAvatar = '';
  String userAvatar = '';
  String userName = '织梦者';
  String assistantName = '织境';
  String userProfile = '';
  bool _profileRefreshInFlight = false;
  int _lastProfileRefreshMessageCount = 0;
  bool isStreaming = false;
  int _streamRunId = 0;
  bool _cancelStreamRequested = false;
  bool _imageGenerationActive = false;

  final List<ChatMessage> messages = [];
  final List<ChatSession> chatSessions = [];
  List<String> suggestions = [];
  String? currentSessionId;

  List<AiProvider> providers = AiProvider.defaults();
  Map<String, ModelAssignment> modelAssignments = ModelAssignment.defaults();
  List<String> memories = [];
  SearchConfig searchConfig = const SearchConfig(active: 'tavily', keys: {});
  String activeTtsId = '';
  List<TtsProviderConfig> ttsProviders = TtsProviderConfig.defaults();

  bool get hasActiveImageGeneration =>
      _imageGenerationActive ||
      messages.any((message) => message.isImageGenerating);

  ThemeMode get effectiveThemeMode {
    if (themeMode != ThemeMode.system) return themeMode;
    final customBackground = backgroundOverride;
    if (customBackground == null) return themeMode;
    return customBackground.computeLuminance() < 0.45
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  Future<void> load() async {
    _prefs = await WeaviewPreferences.open();
    final prefs = _prefs!;
    systemPrompt = prefs.systemPrompt;
    emotionEnabled = prefs.emotionEnabled;
    globalMemoryEnabled = prefs.globalMemoryEnabled;
    referenceHistoryEnabled = prefs.referenceHistoryEnabled;
    assistantAvatar = prefs.assistantAvatar;
    userAvatar = prefs.userAvatar;
    userName = prefs.userName;
    assistantName = prefs.assistantName;
    userProfile = prefs.userProfile;
    _syncUserNameIntoProfile(notify: false);
    themeMode = prefs.themeMode;
    backgroundOverride = prefs.themeBackground;
    textOverride = prefs.themeText;
    if (themeMode != ThemeMode.system && backgroundOverride != null) {
      _clearGlobalThemeOverrides();
    }
    assistantBubbleOverride = prefs.assistantBubble;
    userBubbleOverride = prefs.userBubble;
    fontMood = prefs.fontFamily;
    fontStyleMood = prefs.fontStyle;
    fontWeightMood = prefs.fontWeight;
    bubbleStyle = prefs.bubbleStyle;
    messageAlignment = prefs.messageAlignment;
    assistantBubbleOpacity = prefs.assistantBubbleOpacity;
    userBubbleOpacity = prefs.userBubbleOpacity;

    final savedSessions = await _migrateGeneratedImageAttachments(
      prefs.loadChatSessions(),
    );
    chatSessions
      ..clear()
      ..addAll(savedSessions);
    _sortChatSessions();

    final savedProviders = prefs.loadProviders();
    if (savedProviders.isNotEmpty) {
      final savedNames = savedProviders
          .map((provider) => provider.name.toLowerCase())
          .toSet();
      providers = [
        ...savedProviders,
        for (final preset in AiProvider.defaults())
          if (!savedNames.contains(preset.name.toLowerCase())) preset,
      ];
    }
    final defaultProvidersByName = {
      for (final provider in AiProvider.defaults())
        provider.name.toLowerCase(): provider,
    };
    providers = providers.map((provider) {
      var normalized = provider.copyWith(models: provider.models);
      final preset = defaultProvidersByName[normalized.name.toLowerCase()];
      if (normalized.baseUrl.isEmpty && preset?.baseUrl.isNotEmpty == true) {
        normalized = normalized.copyWith(baseUrl: preset!.baseUrl);
      }
      if (normalized.name.toLowerCase().contains('gemini') &&
          normalized.apiKey.isEmpty) {
        return normalized.copyWith(models: const [], status: '未配置');
      }
      return normalized;
    }).toList();
    if (!providers.any((provider) => provider.current) &&
        providers.isNotEmpty) {
      final preferred = providers.indexWhere(
        (provider) => provider.apiKey.isNotEmpty,
      );
      providers = [
        for (var i = 0; i < providers.length; i++)
          providers[i].copyWith(
            current: preferred >= 0 && i == preferred,
            status: preferred >= 0 && i == preferred
                ? '使用中'
                : providers[i].apiKey.isEmpty
                ? '未配置'
                : '已连接',
          ),
      ];
    }
    _persistProviders();

    final savedAssignments = prefs.loadModelAssignments();
    if (savedAssignments != null) {
      modelAssignments = {...ModelAssignment.defaults(), ...savedAssignments};
    }
    final chatAssignment = modelAssignments['chat'];
    if (chatAssignment != null &&
        chatAssignment.provider.toLowerCase().contains('gemini') &&
        providers
                .firstWhereOrNull(
                  (provider) => provider.name.toLowerCase().contains('gemini'),
                )
                ?.models
                .isEmpty !=
            false) {
      modelAssignments = {
        ...modelAssignments,
        'chat': chatAssignment.copyWith(provider: '', model: ''),
      };
    }

    memories = prefs.loadMemories();

    searchConfig = prefs.loadSearchConfig() ?? searchConfig;

    final savedTts = prefs.loadTtsProviders();
    ttsProviders = _mergeTtsProviders(savedTts);
    activeTtsId = _safeActiveTtsId(prefs.activeTtsId, ttsProviders);

    loaded = true;
    notifyListeners();
    if (!_hasProfileDetails() && chatSessions.isNotEmpty) {
      unawaited(_refreshUserProfileFromConversation(force: true));
    }
  }

  bool isDark(BuildContext context) {
    if (themeMode == ThemeMode.dark) return true;
    if (themeMode == ThemeMode.light) return false;
    final customBackground = backgroundOverride;
    if (customBackground != null) {
      return customBackground.computeLuminance() < 0.45;
    }
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }

  Color background(BuildContext context) {
    return backgroundOverride ?? (isDark(context) ? baseDark : baseLight);
  }

  Color layer(BuildContext context) {
    final customBackground = backgroundOverride;
    if (customBackground != null) {
      return isDark(context)
          ? Color.lerp(customBackground, Colors.white, 0.08)!
          : Color.lerp(customBackground, Colors.black, 0.035)!;
    }
    return isDark(context) ? layerDark : layerLight;
  }

  Color text(BuildContext context) {
    final candidate = textOverride ?? (isDark(context) ? textDark : textLight);
    final currentBackground = background(context);
    if (contrastRatio(currentBackground, candidate) < 4.5) {
      return readableTextFor(currentBackground);
    }
    return candidate;
  }

  Color muted(BuildContext context) {
    return isDark(context) ? mutedDark : mutedLight;
  }

  TextStyle textStyle(
    BuildContext context, {
    double size = 14,
    FontWeight weight = FontWeight.w400,
    double opacity = 1,
    double height = 1.35,
  }) {
    final effectiveWeight = switch (fontWeightMood) {
      'bold' when weight.value <= FontWeight.w500.value => FontWeight.w700,
      'medium' when weight.value <= FontWeight.w400.value => FontWeight.w500,
      _ => weight,
    };
    return TextStyle(
      color: text(context).withValues(alpha: opacity),
      fontSize: size,
      fontWeight: effectiveWeight,
      fontStyle: fontStyleMood == 'italic' ? FontStyle.italic : null,
      height: height,
      fontFamily: fontMood == 'serif' ? 'Noto Serif SC' : 'Inter',
      fontFamilyFallback: const [
        'PingFang SC',
        'Microsoft YaHei',
        'Noto Sans CJK SC',
        'Songti SC',
        'serif',
      ],
    );
  }

  void setThemeModeValue(ThemeMode mode) {
    themeMode = mode;
    if (mode != ThemeMode.system) {
      _clearGlobalThemeOverrides();
    }
    _prefs?.saveThemeMode(mode);
    notifyListeners();
  }

  void applyAiTheme(Map<String, dynamic> args, {String? userPrompt}) {
    args = AiThemeGuard.guard(args, userPrompt: userPrompt);
    if (args.isEmpty) return;
    if (args['resetTheme'] == true) {
      resetAiTheme();
      return;
    }
    final bg = colorFromHex(args['backgroundColor']?.toString());
    final txt = colorFromHex(args['textColor']?.toString());
    final assistantBubble =
        colorFromHex(args['assistantBubbleColor']?.toString()) ??
        colorFromHex(args['bubbleColor']?.toString());
    final userBubble =
        colorFromHex(args['userBubbleColor']?.toString()) ??
        colorFromHex(args['bubbleColor']?.toString());
    var nextBackground = backgroundOverride;
    var nextText = textOverride;
    if (bg != null) {
      nextBackground = bg;
    }
    if (txt != null) {
      nextText = txt;
    }
    final proposedThemeMode = args['isDark'] is bool
        ? (args['isDark'] == true ? ThemeMode.dark : ThemeMode.light)
        : bg != null
        ? (bg.computeLuminance() < 0.45 ? ThemeMode.dark : ThemeMode.light)
        : themeMode;
    final fallbackBackground = switch (proposedThemeMode) {
      ThemeMode.dark => baseDark,
      ThemeMode.light => baseLight,
      ThemeMode.system => baseLight,
    };
    final effectiveBackground = nextBackground ?? fallbackBackground;
    final fallbackText = effectiveBackground.computeLuminance() < 0.45
        ? textDark
        : textLight;
    final effectiveText = nextText ?? fallbackText;
    if (contrastRatio(effectiveBackground, effectiveText) < 4.5) {
      nextText = nextText == null
          ? readableTextFor(effectiveBackground)
          : _readableVariantOf(nextText, effectiveBackground);
    }
    if (bg != null) {
      backgroundOverride = nextBackground;
      _prefs?.saveThemeBackground(nextBackground!);
    }
    if (txt != null || bg != null && nextText != null) {
      textOverride = nextText;
      _prefs?.saveThemeText(nextText!);
    }
    final family = args['fontFamily']?.toString();
    if (family == 'serif' || family == 'sans') {
      fontMood = family!;
      _prefs?.saveFontFamily(family);
    }
    if (args['isDark'] is bool || bg != null) {
      themeMode = proposedThemeMode;
      _prefs?.saveThemeMode(themeMode);
    }
    if (assistantBubble != null) {
      assistantBubbleOverride = assistantBubble;
      _prefs?.saveAssistantBubble(assistantBubble);
    }
    if (userBubble != null) {
      userBubbleOverride = userBubble;
      _prefs?.saveUserBubble(userBubble);
    }
    final nextAssistantOpacity =
        opacityArg(args['assistantBubbleOpacity']) ??
        opacityArg(args['bubbleOpacity']);
    if (nextAssistantOpacity != null) {
      assistantBubbleOpacity = nextAssistantOpacity;
      _prefs?.saveAssistantBubbleOpacity(assistantBubbleOpacity);
    }
    final nextUserOpacity =
        opacityArg(args['userBubbleOpacity']) ??
        opacityArg(args['bubbleOpacity']);
    if (nextUserOpacity != null) {
      userBubbleOpacity = nextUserOpacity;
      _prefs?.saveUserBubbleOpacity(userBubbleOpacity);
    }
    final nextBubbleStyle = enumArg(args['bubbleStyle'], const [
      'minimal',
      'none',
      'glass',
      'solid',
      'outline',
    ]);
    if (nextBubbleStyle != null) {
      bubbleStyle = nextBubbleStyle;
      _prefs?.saveBubbleStyle(bubbleStyle);
    }
    final nextAlignment = enumArg(args['messageAlignment'], const [
      'left',
      'center',
      'right',
    ]);
    if (nextAlignment != null) {
      messageAlignment = nextAlignment;
      _prefs?.saveMessageAlignment(messageAlignment);
    }
    final nextFontStyle = enumArg(args['fontStyle'], const [
      'normal',
      'italic',
    ]);
    if (nextFontStyle != null) {
      fontStyleMood = nextFontStyle;
      _prefs?.saveFontStyle(fontStyleMood);
    }
    final nextFontWeight = enumArg(args['fontWeight'], const [
      'normal',
      'medium',
      'bold',
    ]);
    if (nextFontWeight != null) {
      fontWeightMood = nextFontWeight;
      _prefs?.saveFontWeight(fontWeightMood);
    }
    themePulse++;
    notifyListeners();
  }

  void _clearGlobalThemeOverrides() {
    backgroundOverride = null;
    textOverride = null;
    _prefs?.clearGlobalThemeOverrides();
  }

  void resetAiTheme() {
    backgroundOverride = null;
    textOverride = null;
    assistantBubbleOverride = null;
    userBubbleOverride = null;
    fontMood = 'sans';
    fontStyleMood = 'normal';
    fontWeightMood = 'normal';
    bubbleStyle = 'minimal';
    messageAlignment = 'left';
    assistantBubbleOpacity = 0.08;
    userBubbleOpacity = 0.12;
    themeMode = ThemeMode.system;
    _prefs?.resetThemeControls(
      fontFamily: fontMood,
      fontStyle: fontStyleMood,
      fontWeight: fontWeightMood,
      bubbleStyle: bubbleStyle,
      messageAlignment: messageAlignment,
      assistantBubbleOpacity: assistantBubbleOpacity,
      userBubbleOpacity: userBubbleOpacity,
      themeMode: themeMode,
    );
    themePulse++;
    notifyListeners();
  }

  bool _applyPromptAppearanceIntent(String value) {
    final args = PromptAppearanceIntent.parse(value);
    if (args.isEmpty) return false;
    applyAiTheme(args, userPrompt: value);
    return true;
  }

  void updateSystemPrompt(String value) {
    systemPrompt = value.isEmpty ? defaultSystemInstruction : value;
    _prefs?.saveSystemPrompt(systemPrompt);
    notifyListeners();
  }

  void updateUserName(String value) {
    userName = value.trim().isEmpty ? '织梦者' : value.trim();
    _prefs?.saveUserName(userName);
    _syncUserNameIntoProfile(notify: false);
    notifyListeners();
  }

  void updateAssistantName(String value) {
    assistantName = value.trim().isEmpty ? '织境' : value.trim();
    _prefs?.saveAssistantName(assistantName);
    notifyListeners();
  }

  void updateUserProfile(String value) {
    userProfile = value.trim();
    _prefs?.saveUserProfile(userProfile);
    notifyListeners();
  }

  void _syncUserNameIntoProfile({bool notify = true}) {
    final displayName = userName.trim();
    if (displayName.isEmpty || displayName == '织梦者') return;
    final profileLines = userProfile
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where(
          (line) =>
              !line.startsWith('用户称呼：') &&
              !line.startsWith('用户昵称：') &&
              !line.startsWith('昵称：'),
        )
        .toList();
    final nextProfile = ['用户称呼：$displayName', ...profileLines].join('\n');
    if (nextProfile.trim() == userProfile.trim()) return;
    userProfile = nextProfile.trim();
    _prefs?.saveUserProfile(userProfile);
    if (notify) notifyListeners();
  }

  void updateAssistantAvatar(String value) {
    assistantAvatar = value;
    _prefs?.saveAssistantAvatar(value);
    notifyListeners();
  }

  void updateUserAvatar(String value) {
    userAvatar = value;
    _prefs?.saveUserAvatar(value);
    notifyListeners();
  }

  void setEmotionEnabled(bool value) {
    emotionEnabled = value;
    _prefs?.saveEmotionEnabled(value);
    notifyListeners();
  }

  void setGlobalMemoryEnabled(bool value) {
    globalMemoryEnabled = value;
    _prefs?.saveGlobalMemoryEnabled(value);
    notifyListeners();
  }

  void setReferenceHistoryEnabled(bool value) {
    referenceHistoryEnabled = value;
    _prefs?.saveReferenceHistoryEnabled(value);
    notifyListeners();
  }

  void addMemory(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    memories = [trimmed, ...memories];
    _prefs?.saveMemories(memories);
    notifyListeners();
  }

  void deleteMemory(int index) {
    memories = [
      for (var i = 0; i < memories.length; i++)
        if (i != index) memories[i],
    ];
    _prefs?.saveMemories(memories);
    notifyListeners();
  }

  void clearMemories() {
    memories = [];
    _prefs?.saveMemories(memories);
    notifyListeners();
  }

  Future<void> completeUserProfileWithToolModel() async {
    final assignment = modelAssignments['tool'];
    final provider = assignment == null
        ? null
        : _providerForAssignment(assignment);
    final configIssue = _modelConfigIssue(
      assignment: assignment,
      provider: provider,
      roleLabel: '工具模型',
    );
    if (configIssue != null) throw Exception(configIssue);
    final input =
        '''
请根据已有信息补全用户人物画像。要求：
- 只输出一段 120-260 字的中文人物画像。
- 包含用户偏好、沟通方式、正在做的项目、技术倾向、已知约束。
- 不要编造不存在的隐私信息，不确定就写“未明确”。

当前画像：
${userProfile.trim().isEmpty ? '无' : userProfile.trim()}

用户称呼：
${userName.trim().isEmpty ? '未明确' : userName.trim()}

长期记忆：
${memories.isEmpty ? '无' : memories.map((m) => '- $m').join('\n')}

最近对话：
${_compactConversation(messages.isNotEmpty ? messages : chatSessions.expand((s) => s.messages).take(20).toList())}
''';
    final result = await AiGateway.generateRoleText(
      provider: provider!,
      assignment: assignment!,
      input: input,
    ).timeout(roleRequestTimeout);
    updateUserProfile(result);
  }

  Future<void> organizeMemoriesWithToolModel() async {
    final assignment = modelAssignments['tool'];
    final provider = assignment == null
        ? null
        : _providerForAssignment(assignment);
    final configIssue = _modelConfigIssue(
      assignment: assignment,
      provider: provider,
      roleLabel: '工具模型',
    );
    if (configIssue != null) throw Exception(configIssue);
    final input =
        '''
请整理用户长期记忆。要求：
- 输出 JSON 数组字符串，例如 ["用户偏好...", "用户项目..."]。
- 最多 12 条，每条不超过 40 个中文字符。
- 去重、合并相近信息，删除空泛或临时信息。
- 不要输出 Markdown，不要解释。

当前人物画像：
${userProfile.trim().isEmpty ? '无' : userProfile.trim()}

已有记忆：
${memories.isEmpty ? '无' : memories.map((m) => '- $m').join('\n')}

最近对话：
${_compactConversation(messages.isNotEmpty ? messages : chatSessions.expand((s) => s.messages).take(20).toList())}
''';
    final raw = await AiGateway.generateRoleText(
      provider: provider!,
      assignment: assignment!,
      input: input,
    ).timeout(roleRequestTimeout);
    memories = _decodeMemoryList(raw);
    _prefs?.saveMemories(memories);
    notifyListeners();
  }

  Future<void> _refreshMemoryFromConversation() async {
    if (!globalMemoryEnabled || messages.length < 4) return;
    final assignment = modelAssignments['tool'];
    final provider = assignment == null
        ? null
        : _providerForAssignment(assignment);
    if (_modelConfigIssue(
          assignment: assignment,
          provider: provider,
          roleLabel: '工具模型',
        ) !=
        null) {
      return;
    }
    final input =
        '''
请根据这段最新对话增量整理用户长期记忆。要求：
- 输出 JSON 数组字符串，例如 ["用户正在开发 Flutter AI 聊天 APP"]。
- 只记录可长期复用的信息：稳定偏好、项目背景、技术约束、明确目标。
- 不记录临时情绪、一次性问题、模型回复中的泛泛建议。
- 合并已有记忆，最多保留 12 条，每条不超过 42 个中文字符。
- 不要输出 Markdown，不要解释。

已有记忆：
${memories.isEmpty ? '无' : memories.map((m) => '- $m').join('\n')}

最新对话：
${_compactConversation(messages)}
''';
    try {
      final raw = await AiGateway.generateRoleText(
        provider: provider!,
        assignment: assignment!,
        input: input,
      ).timeout(roleRequestTimeout);
      final next = _decodeMemoryList(raw);
      if (next.isEmpty) return;
      memories = next;
      _prefs?.saveMemories(memories);
      notifyListeners();
    } catch (_) {
      // 自动记忆不应打断正常对话。
    }
  }

  Future<void> _refreshUserProfileFromConversation({bool force = false}) async {
    if (_profileRefreshInFlight) return;
    final source = _personalizationSourceMessages();
    final hasUserSignal = source.any(
      (message) =>
          message.role == 'user' &&
          (message.content.trim().isNotEmpty || message.attachments.isNotEmpty),
    );
    if (!hasUserSignal) return;
    final hasProfileDetails = _hasProfileDetails();
    if (!force) {
      final messageDelta = messages.length - _lastProfileRefreshMessageCount;
      if (hasProfileDetails && messageDelta < 6) return;
      if (!hasProfileDetails && messages.length < 2) return;
    }

    final assignment = modelAssignments['tool'];
    final provider = assignment == null
        ? null
        : _providerForAssignment(assignment);
    if (_modelConfigIssue(
          assignment: assignment,
          provider: provider,
          roleLabel: '工具模型',
        ) !=
        null) {
      return;
    }

    final input =
        '''
请根据最新对话增量更新用户人物画像。要求：
- 只输出更新后的中文人物画像正文，不要标题、JSON、Markdown 或解释。
- 80-220 字；优先保留稳定信息：称呼、偏好、项目背景、技术栈、沟通方式、长期目标。
- 合并当前画像和长期记忆，不要重复；不要编造隐私，不确定就写“未明确”。
- 如果画像为空，也必须基于用户称呼和已有对话生成初始画像。

用户称呼：
${userName.trim().isEmpty ? '未明确' : userName.trim()}

当前人物画像：
${userProfile.trim().isEmpty ? '无' : userProfile.trim()}

长期记忆：
${memories.isEmpty ? '无' : memories.map((m) => '- $m').join('\n')}

最新对话：
${_compactConversation(source)}
''';

    _profileRefreshInFlight = true;
    try {
      final raw = await AiGateway.generateRoleText(
        provider: provider!,
        assignment: assignment!,
        input: input,
      ).timeout(roleRequestTimeout);
      final nextProfile = _normalizeUserProfile(raw);
      if (nextProfile.isEmpty) return;
      if (nextProfile != userProfile.trim()) {
        userProfile = nextProfile;
        _syncUserNameIntoProfile(notify: false);
        _prefs?.saveUserProfile(userProfile);
        notifyListeners();
      }
      _lastProfileRefreshMessageCount = messages.length;
    } catch (_) {
      // 自动画像整理不能打断正常对话。
    } finally {
      _profileRefreshInFlight = false;
    }
  }

  Future<void> _refreshPersonalizationFromConversation() async {
    await _refreshMemoryFromConversation();
    await _refreshUserProfileFromConversation();
  }

  List<String> _decodeMemoryList(String raw) {
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .take(12)
          .toList();
    } catch (_) {
      return raw
          .split(RegExp(r'[\n\r]+'))
          .map(
            (line) =>
                line.replaceFirst(RegExp(r'^\s*[-*0-9.、]+\s*'), '').trim(),
          )
          .where((line) => line.isNotEmpty)
          .take(12)
          .toList();
    }
  }

  String _normalizeUserProfile(String raw) {
    var text = raw
        .replaceAll(
          RegExp(r'```(?:json|markdown|md)?', caseSensitive: false),
          '',
        )
        .replaceAll('```', '')
        .trim();
    text = text
        .split(RegExp(r'\r?\n'))
        .map(
          (line) => line.replaceFirst(RegExp(r'^\s*[-*0-9.、]+\s*'), '').trim(),
        )
        .where((line) => line.isNotEmpty)
        .join('\n')
        .trim();
    if (text.startsWith('人物画像：')) {
      text = text.substring('人物画像：'.length).trim();
    }
    return text.characters.take(260).toString().trim();
  }

  bool _hasProfileDetails() {
    return userProfile
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .any(
          (line) =>
              !line.startsWith('用户称呼：') &&
              !line.startsWith('用户昵称：') &&
              !line.startsWith('昵称：'),
        );
  }

  List<ChatMessage> _personalizationSourceMessages() {
    if (messages.isNotEmpty) return messages;
    return chatSessions.expand((session) => session.messages).take(24).toList();
  }

  void newSession() {
    messages.clear();
    suggestions = [];
    currentSessionId = null;
    notifyListeners();
  }

  void selectSession(ChatSession session) {
    messages
      ..clear()
      ..addAll(session.messages.map((m) => m.copy()));
    suggestions = [];
    currentSessionId = session.id;
    notifyListeners();
  }

  void togglePinSession(String sessionId) {
    final index = chatSessions.indexWhere((session) => session.id == sessionId);
    if (index < 0) return;
    chatSessions[index] = chatSessions[index].copyWith(
      pinned: !chatSessions[index].pinned,
    );
    _sortChatSessions();
    _prefs?.saveChatSessions(chatSessions);
    notifyListeners();
  }

  void deleteSession(String sessionId) {
    chatSessions.removeWhere((session) => session.id == sessionId);
    if (currentSessionId == sessionId) {
      currentSessionId = null;
      messages.clear();
      suggestions = [];
    }
    _prefs?.saveChatSessions(chatSessions);
    notifyListeners();
  }

  Future<bool> regenerateSessionTitle(String sessionId) async {
    final index = chatSessions.indexWhere((session) => session.id == sessionId);
    if (index < 0) return false;
    final session = chatSessions[index];
    final title = await _generateTitleForMessages(session.messages);
    if (title == null || title.isEmpty) return false;
    chatSessions[index] = session.copyWith(title: title);
    _sortChatSessions();
    _prefs?.saveChatSessions(chatSessions);
    notifyListeners();
    return true;
  }

  void createBranchAt(int index) {
    if (index < 0 || index >= messages.length) return;
    final branchMessages = messages
        .take(index + 1)
        .map((message) => message.copy())
        .toList();
    if (branchMessages.isEmpty) return;
    final sourceTitle =
        chatSessions
            .firstWhereOrNull((session) => session.id == currentSessionId)
            ?.title
            .trim() ??
        branchMessages
            .firstWhereOrNull((m) => m.role == 'user')
            ?.content
            .trim();
    currentSessionId = 'branch_${DateTime.now().millisecondsSinceEpoch}';
    messages
      ..clear()
      ..addAll(branchMessages);
    suggestions = [];
    _persistCurrentSession();
    final sessionIndex = chatSessions.indexWhere(
      (s) => s.id == currentSessionId,
    );
    if (sessionIndex >= 0) {
      final base = sourceTitle == null || sourceTitle.isEmpty
          ? '未命名梦境'
          : sourceTitle;
      chatSessions[sessionIndex] = chatSessions[sessionIndex].copyWith(
        title: '分支 · ${base.length > 14 ? base.substring(0, 14) : base}',
      );
      _prefs?.saveChatSessions(chatSessions);
    }
    notifyListeners();
  }

  void deleteMessageAt(int index) {
    if (index < 0 || index >= messages.length) return;
    messages.removeAt(index);
    suggestions = [];
    if (messages.isEmpty) {
      if (currentSessionId != null) {
        chatSessions.removeWhere((s) => s.id == currentSessionId);
        _prefs?.saveChatSessions(chatSessions);
      }
      currentSessionId = null;
    } else {
      _persistCurrentSession();
    }
    notifyListeners();
  }

  void editMessageAt(int index, String content) {
    if (index < 0 || index >= messages.length) return;
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    messages[index].content = trimmed;
    suggestions = [];
    _persistCurrentSession();
    notifyListeners();
  }

  void _persistCurrentSession() {
    if (messages.isEmpty) return;
    currentSessionId ??= DateTime.now().millisecondsSinceEpoch.toString();
    final fallbackTitle = messages
        .firstWhereOrNull((m) => m.role == 'user')
        ?.content
        .trim();
    final existing = chatSessions.firstWhereOrNull(
      (s) => s.id == currentSessionId,
    );
    final existingTitle = existing?.title.trim();
    final title = existingTitle != null && existingTitle.isNotEmpty
        ? existingTitle
        : fallbackTitle;
    final session = ChatSession(
      id: currentSessionId!,
      title: (title == null || title.isEmpty)
          ? '未命名梦境'
          : (title.length > 20 ? title.substring(0, 20) : title),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      messages: messages.map((m) => m.copy()).toList(),
      pinned: existing?.pinned ?? false,
    );
    final index = chatSessions.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      chatSessions.removeAt(index);
    }
    chatSessions.insert(0, session);
    _sortChatSessions();
    _prefs?.saveChatSessions(chatSessions);
  }

  void _sortChatSessions() {
    chatSessions.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
  }

  Future<void> submitMessage(
    String value, {
    List<MessageAttachment> attachments = const [],
    bool useWebSearch = false,
  }) async {
    final content = value.trim();
    if ((content.isEmpty && attachments.isEmpty) || isStreaming) return;
    _applyPromptAppearanceIntent(content);

    final chatAssignment = modelAssignments['chat'];
    final chatProvider = chatAssignment == null
        ? null
        : _providerForAssignment(chatAssignment);
    final configIssue = _modelConfigIssue(
      assignment: chatAssignment,
      provider: chatProvider,
      roleLabel: '主对话模型',
    );
    if (configIssue != null) {
      messages
        ..add(ChatMessage.user(content, attachments: attachments))
        ..add(ChatMessage.model(configIssue));
      suggestions = [];
      _persistCurrentSession();
      notifyListeners();
      return;
    }

    final conversation = [
      ...messages,
      ChatMessage.user(content, attachments: attachments),
    ];
    suggestions = [];
    messages
      ..clear()
      ..addAll(conversation)
      ..add(ChatMessage.model('', isThinking: true));
    isStreaming = true;
    _cancelStreamRequested = false;
    final runId = ++_streamRunId;
    _persistCurrentSession();
    notifyListeners();

    var lastNotify = DateTime.fromMillisecondsSinceEpoch(0);
    void flush({bool force = false}) {
      final now = DateTime.now();
      if (!force && now.difference(lastNotify).inMilliseconds < 36) return;
      lastNotify = now;
      notifyListeners();
    }

    var targetContent = '';
    var rawTargetContent = '';
    var targetReasoning = '';
    var remoteThinking = true;
    var streamDone = false;
    var typewriterRunning = false;
    Completer<void>? typewriterCompleter;
    var visibleContentChars = 0;
    var visibleReasoningChars = 0;

    Future<void> pumpTypewriter() async {
      if (typewriterRunning) {
        return typewriterCompleter?.future ?? Future<void>.value();
      }
      typewriterRunning = true;
      final completer = Completer<void>();
      typewriterCompleter = completer;
      try {
        while (runId == _streamRunId && !_cancelStreamRequested) {
          final contentLength = targetContent.characters.length;
          final reasoningLength = targetReasoning.characters.length;
          final hasMore =
              visibleContentChars < contentLength ||
              visibleReasoningChars < reasoningLength;
          if (!hasMore) {
            if (streamDone) break;
            final current = messages.last;
            current.isThinking =
                current.content.trim().isEmpty && remoteThinking;
            flush();
            await Future<void>.delayed(const Duration(milliseconds: 18));
            continue;
          }

          if (visibleReasoningChars < reasoningLength) {
            visibleReasoningChars++;
          }
          if (visibleContentChars < contentLength) {
            visibleContentChars++;
          }

          final current = messages.last;
          current.content = targetContent.characters
              .take(visibleContentChars)
              .toString();
          current.reasoning = targetReasoning.characters
              .take(visibleReasoningChars)
              .toString();
          current.isThinking =
              current.content.trim().isEmpty && remoteThinking && !streamDone;
          flush();
          await Future<void>.delayed(const Duration(milliseconds: 12));
        }
      } finally {
        typewriterRunning = false;
        if (!completer.isCompleted) completer.complete();
      }
    }

    try {
      final prompt = await _expandedSystemPrompt(
        webQuery: useWebSearch ? content : null,
      );
      await AiGateway.generateStream(
        messages: conversation,
        systemInstruction: prompt,
        provider: chatProvider!,
        assignment: chatAssignment!,
        onThemeUpdate: (args) => applyAiTheme(args, userPrompt: content),
        shouldCancel: () => runId != _streamRunId || _cancelStreamRequested,
        onSnapshot: (content, reasoning, thinking) {
          rawTargetContent = content;
          targetContent = stripImageToolCalls(content);
          targetReasoning = reasoning;
          remoteThinking = thinking;
          unawaited(pumpTypewriter());
        },
      );
      streamDone = true;
      await pumpTypewriter();
      if (runId != _streamRunId || _cancelStreamRequested) {
        messages.last.isThinking = false;
        flush(force: true);
        return;
      }
      final imageToolCall = parseImageToolCall(rawTargetContent);
      if (imageToolCall != null) {
        messages.last
          ..content = ''
          ..isThinking = true
          ..activity = 'imageGeneration';
        flush(force: true);
        final prepared = _prepareImageGenerationRequest(
          imageToolCall.prompt,
          hasImageAttachments: false,
        );
        await _generateImageIntoCurrentResponse(
          prompt: prepared.prompt,
          size: prepared.size,
          runId: runId,
        );
        return;
      }
      messages.last.isThinking = false;
      if (messages.last.content.trim().isEmpty) {
        messages.last.content = '我在，但这一缕回应没有形成文字。';
      }
      flush(force: true);
      if (runId == _streamRunId) {
        isStreaming = false;
        _persistCurrentSession();
        notifyListeners();
      }
      await _refreshCurrentSessionTitle();
      await _refreshSuggestions();
      unawaited(_refreshPersonalizationFromConversation());
    } catch (error) {
      if (runId != _streamRunId || _cancelStreamRequested) {
        messages.last.isThinking = false;
        notifyListeners();
        return;
      }
      messages.last.content =
          '连接织线时出现了问题：${_friendlyAiError(error)}\n\n请检查网络、API Key 或模型配置后重试。';
      messages.last.isThinking = false;
      notifyListeners();
    } finally {
      if (runId == _streamRunId) {
        if (isStreaming) isStreaming = false;
        _cancelStreamRequested = false;
        _persistCurrentSession();
        notifyListeners();
      }
    }
  }

  Future<void> submitImageGeneration(
    String value, {
    List<MessageAttachment> attachments = const [],
  }) async {
    final content = value.trim();
    if (content.isEmpty || isStreaming) return;
    final requestAttachments = _contextualImageAttachments(
      content,
      attachments,
    );
    final prepared = _prepareImageGenerationRequest(
      content,
      hasImageAttachments: requestAttachments.any(
        (attachment) => attachment.isImage,
      ),
    );

    messages
      ..add(ChatMessage.user(content, attachments: requestAttachments))
      ..add(
        ChatMessage.model('', isThinking: true, activity: 'imageGeneration'),
      );
    suggestions = [];
    isStreaming = true;
    _cancelStreamRequested = false;
    final runId = ++_streamRunId;
    unawaited(_ensureNativeNotificationPermission());
    _persistCurrentSession();
    notifyListeners();

    try {
      await _generateImageIntoCurrentResponse(
        prompt: prepared.prompt,
        size: prepared.size,
        attachments: requestAttachments,
        runId: runId,
        targetIndex: messages.length - 1,
      );
    } finally {
      if (runId == _streamRunId) {
        isStreaming = false;
        _cancelStreamRequested = false;
        notifyListeners();
      }
    }
  }

  Future<void> resumeInterruptedImageGeneration({
    bool retryLastFailure = false,
  }) async {
    if (isStreaming || _imageGenerationActive || messages.isEmpty) return;
    var targetIndex = messages.lastIndexWhere(
      (message) => message.isImageGenerating,
    );
    if (targetIndex < 0 && retryLastFailure) {
      final lastIndex = messages.length - 1;
      final last = messages[lastIndex];
      if (last.role == 'model' && last.content.trim().startsWith('生图失败')) {
        targetIndex = lastIndex;
        last
          ..content = ''
          ..isThinking = true
          ..activity = 'imageGeneration'
          ..attachments = [];
      }
    }
    if (targetIndex < 0) return;
    final userIndex = messages
        .take(targetIndex)
        .toList()
        .lastIndexWhere((message) => message.role == 'user');
    if (userIndex < 0) return;
    final prompt = messages[userIndex].content.trim();
    if (prompt.isEmpty) return;
    final attachments = messages[userIndex].attachments
        .map((attachment) => attachment.copy())
        .toList();
    final prepared = _prepareImageGenerationRequest(
      prompt,
      hasImageAttachments: attachments.any((attachment) => attachment.isImage),
      beforeIndex: userIndex,
    );

    suggestions = [];
    isStreaming = true;
    _cancelStreamRequested = false;
    final runId = ++_streamRunId;
    _persistCurrentSession();
    notifyListeners();

    try {
      await _generateImageIntoCurrentResponse(
        prompt: prepared.prompt,
        size: prepared.size,
        attachments: attachments,
        runId: runId,
        targetIndex: targetIndex,
      );
    } finally {
      if (runId == _streamRunId) {
        isStreaming = false;
        _cancelStreamRequested = false;
        _persistCurrentSession();
        notifyListeners();
      }
    }
  }

  Future<void> _generateImageIntoCurrentResponse({
    required String prompt,
    required String size,
    List<MessageAttachment> attachments = const [],
    required int runId,
    int? targetIndex,
  }) async {
    final imageAssignment = _effectiveImageAssignment();
    final imageProvider = imageAssignment == null
        ? null
        : _providerForAssignment(imageAssignment);
    final configIssue = _modelConfigIssue(
      assignment: imageAssignment,
      provider: imageProvider,
      roleLabel: '生图模型',
    );
    if (configIssue != null) {
      final current = _imageGenerationMessage(targetIndex);
      if (current != null) {
        current
          ..content = configIssue
          ..isThinking = false
          ..activity = '';
      }
      _persistCurrentSession();
      notifyListeners();
      return;
    }

    _imageGenerationActive = true;
    try {
      final result = await AiGateway.generateImage(
        provider: imageProvider!,
        assignment: imageAssignment!,
        prompt: prompt,
        attachments: attachments,
        size: size,
      );
      if (runId != _streamRunId || _cancelStreamRequested) {
        final current = _imageGenerationMessage(targetIndex);
        current
          ?..isThinking = false
          ..activity = '';
        notifyListeners();
        return;
      }
      final current = _imageGenerationMessage(targetIndex);
      if (current == null) return;
      final attachment = await _writeGeneratedImageAttachment(result);
      current
        ..content = ''
        ..attachments = [attachment]
        ..isThinking = false
        ..activity = '';
      _persistCurrentSession();
      await _refreshCurrentSessionTitle();
      unawaited(_refreshPersonalizationFromConversation());
      await _showNativeNotification(title: '织境生图完成', body: '图片已生成，回到织境查看结果。');
      notifyListeners();
    } catch (error) {
      if (runId != _streamRunId || _cancelStreamRequested) {
        final current = _imageGenerationMessage(targetIndex);
        current
          ?..isThinking = false
          ..activity = '';
        notifyListeners();
        return;
      }
      final current = _imageGenerationMessage(targetIndex);
      if (current == null) return;
      current
        ..content =
            '生图失败：${_friendlyAiError(error, timeout: imageRequestTimeout)}\n\n请确认当前模型支持生图接口，模型能力已标记为 image，并检查 Base URL、证书和 API Key。'
        ..isThinking = false
        ..activity = '';
      _persistCurrentSession();
      await _showNativeNotification(
        title: '织境生图失败',
        body: '图片生成未完成，请回到织境查看详情。',
      );
      notifyListeners();
    } finally {
      _imageGenerationActive = false;
    }
  }

  _PreparedImageRequest _prepareImageGenerationRequest(
    String value, {
    required bool hasImageAttachments,
    int? beforeIndex,
  }) {
    final basePrompt = value.trim();
    final contextualPrompt = _contextualImagePrompt(
      basePrompt,
      hasImageAttachments: hasImageAttachments,
      beforeIndex: beforeIndex,
    );
    final aspect =
        _imageAspectRatioFromPrompt(contextualPrompt) ??
        _imageAspectRatioFromPrompt(basePrompt);
    return _PreparedImageRequest(
      prompt: _imagePromptWithAspectHint(contextualPrompt, aspect),
      size: _imageSizeForAspect(aspect),
    );
  }

  String _contextualImagePrompt(
    String prompt, {
    required bool hasImageAttachments,
    int? beforeIndex,
  }) {
    if (!_shouldCarryImageContext(
      prompt,
      hasImageAttachments,
      beforeIndex: beforeIndex,
    )) {
      return prompt;
    }
    final previousPrompt = _lastImagePrompt(beforeIndex: beforeIndex);
    if (previousPrompt == null || previousPrompt.trim().isEmpty) return prompt;
    return '''
$prompt

[上一轮图像处理上下文]
$previousPrompt

[本轮执行要求]
如果本轮上传了新的参考图片，请以本轮图片为主要输入，对新图执行同样的处理、风格迁移或版式规则；不要返回上一轮图片或原图。
'''
        .trim();
  }

  List<MessageAttachment> _contextualImageAttachments(
    String prompt,
    List<MessageAttachment> attachments, {
    int? beforeIndex,
  }) {
    final copied = attachments.map((attachment) => attachment.copy()).toList();
    if (copied.any((attachment) => attachment.isImage)) return copied;
    if (!_isImageFollowUpPrompt(prompt)) return copied;
    final previous = _lastGeneratedImageAttachment(beforeIndex: beforeIndex);
    if (previous == null) return copied;
    return [...copied, previous.copy()];
  }

  bool _shouldCarryImageContext(
    String prompt,
    bool hasImageAttachments, {
    int? beforeIndex,
  }) {
    if (!hasImageAttachments && !_isImageFollowUpPrompt(prompt)) return false;
    if (!hasImageAttachments &&
        _lastGeneratedImageAttachment(beforeIndex: beforeIndex) == null) {
      return false;
    }
    return _isImageFollowUpPrompt(prompt);
  }

  bool _isImageFollowUpPrompt(String prompt) {
    final text = prompt.toLowerCase();
    return text.contains('不要改') ||
        text.contains('别改') ||
        text.contains('改成') ||
        text.contains('修改') ||
        text.contains('调整') ||
        text.contains('保持') ||
        text.contains('基于') ||
        text.contains('这张') ||
        text.contains('上张') ||
        text.contains('上一张') ||
        text.contains('上图') ||
        text.contains('刚才') ||
        text.contains('重新') ||
        text.contains('换成') ||
        text.contains('变成') ||
        text.contains('同样') ||
        text.contains('一样') ||
        text.contains('继续') ||
        text.contains('上次') ||
        text.contains('之前') ||
        text.contains('照着') ||
        text.contains('同款') ||
        text.contains('也做') ||
        text.contains('这个也') ||
        text.contains('处理') ||
        text.contains('风格');
  }

  MessageAttachment? _lastGeneratedImageAttachment({int? beforeIndex}) {
    final end = (beforeIndex ?? messages.length).clamp(0, messages.length);
    for (var i = end - 1; i >= 0; i--) {
      final message = messages[i];
      if (message.role != 'model') continue;
      for (final attachment in message.attachments.reversed) {
        if (!attachment.isImage) continue;
        if (attachment.path.isEmpty || !File(attachment.path).existsSync()) {
          continue;
        }
        return attachment;
      }
    }
    return null;
  }

  String? _lastImagePrompt({int? beforeIndex}) {
    final end = (beforeIndex ?? messages.length).clamp(0, messages.length);
    for (var i = end - 1; i >= 0; i--) {
      final message = messages[i];
      if (message.role == 'model' &&
          message.attachments.any((attachment) => attachment.isImage)) {
        for (var j = i - 1; j >= 0; j--) {
          final candidate = messages[j];
          if (candidate.role != 'user') continue;
          final content = candidate.content.trim();
          if (content.isNotEmpty) {
            return content.characters.take(1200).toString();
          }
        }
      }
    }
    for (var i = end - 1; i >= 0; i--) {
      final message = messages[i];
      if (message.role != 'user' ||
          !message.attachments.any((attachment) => attachment.isImage)) {
        continue;
      }
      final content = message.content.trim();
      if (content.isNotEmpty) return content.characters.take(1200).toString();
    }
    return null;
  }

  _ImageAspect? _imageAspectRatioFromPrompt(String prompt) {
    final text = prompt.toLowerCase();
    final ratioMatch = RegExp(
      r'(\d{1,4})\s*(?:[:：比/×xX*])\s*(\d{1,4})',
    ).firstMatch(text);
    if (ratioMatch != null) {
      final width = double.tryParse(ratioMatch.group(1) ?? '');
      final height = double.tryParse(ratioMatch.group(2) ?? '');
      if (width != null && height != null && width > 0 && height > 0) {
        if (width >= 64 || height >= 64) {
          return _ImageAspect(
            label: '${width.round()}x${height.round()}',
            ratio: width / height,
          );
        }
        return _ImageAspect(
          label: '${width.round()}:${height.round()}',
          ratio: width / height,
        );
      }
    }
    if (text.contains('横向') ||
        text.contains('横版') ||
        text.contains('宽屏') ||
        text.contains('海报横幅')) {
      return const _ImageAspect(label: '16:9', ratio: 16 / 9);
    }
    if (text.contains('竖向') ||
        text.contains('竖版') ||
        text.contains('竖屏') ||
        text.contains('手机壁纸')) {
      return const _ImageAspect(label: '9:16', ratio: 9 / 16);
    }
    return null;
  }

  String _imagePromptWithAspectHint(String prompt, _ImageAspect? aspect) {
    if (aspect == null) return prompt;
    if (prompt.contains('[输出比例要求]')) return prompt;
    return '''
$prompt

[输出比例要求]
严格使用 ${aspect.label} 画幅生成，不要默认裁切成 1:1。
'''
        .trim();
  }

  String _imageSizeForAspect(_ImageAspect? aspect) {
    final ratio = aspect?.ratio ?? 1.0;
    if (ratio > 1.18) return '1536x1024';
    if (ratio < 0.85) return '1024x1536';
    return '1024x1024';
  }

  ChatMessage? _imageGenerationMessage(int? targetIndex) {
    if (targetIndex != null &&
        targetIndex >= 0 &&
        targetIndex < messages.length &&
        messages[targetIndex].role == 'model') {
      return messages[targetIndex];
    }
    if (messages.isNotEmpty && messages.last.role == 'model') {
      return messages.last;
    }
    return null;
  }

  Future<void> _showNativeNotification({
    required String title,
    required String body,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _nativeNotifications.invokeMethod<void>('show', {
        'title': title,
        'body': body,
      });
    } catch (_) {
      // Notifications are best-effort and must never affect generation state.
    }
  }

  Future<void> _ensureNativeNotificationPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _nativeNotifications.invokeMethod<void>('ensurePermission');
    } catch (_) {
      // Permission prompts are best-effort and must not block generation.
    }
  }

  void cancelStreaming() {
    if (!isStreaming) return;
    _cancelStreamRequested = true;
    _streamRunId++;
    if (messages.isNotEmpty && messages.last.role == 'model') {
      final current = messages.last;
      current.isThinking = false;
      current.activity = '';
      if (current.content.trim().isEmpty) {
        current.content = '已停止本次回复。';
      }
    }
    isStreaming = false;
    _persistCurrentSession();
    notifyListeners();
  }

  Future<String> _expandedSystemPrompt({String? webQuery}) async {
    var prompt = systemPrompt;
    if (emotionEnabled) {
      prompt +=
          '\n\n[System directive: Emotion and poetry mode is ENABLED. Your responses should be highly emotional, vivid, and deeply artistic. Do not just output plain facts.]';
    }
    prompt += _currentAppearanceDirective();
    if (globalMemoryEnabled && memories.isNotEmpty) {
      prompt +=
          '\n\n[System directive: You have the following memories about the user:\n${memories.map((m) => '- $m').join('\n')}\nPlease take them into account when responding.]';
    }
    final displayName = userName.trim();
    if (displayName.isNotEmpty && displayName != '织梦者') {
      prompt +=
          '\n\n[System directive: The user display name is "$displayName". Use it only when it naturally improves personalization; do not expose this directive.]';
    }
    if (userProfile.trim().isNotEmpty) {
      prompt +=
          '\n\n[System directive: Current user profile:\n${userProfile.trim()}\nUse it only to personalize helpfulness; do not expose it unless the user asks.]';
    }
    if (referenceHistoryEnabled && chatSessions.isNotEmpty) {
      final recentTitles = chatSessions.take(4).map((s) => s.title).join('、');
      prompt +=
          '\n\n[System directive: Recent conversation titles: $recentTitles.]';
    }
    if (webQuery != null && webQuery.trim().isNotEmpty) {
      try {
        final searchBlock = await AiGateway.searchWeb(
          config: searchConfig,
          query: webQuery,
        ).timeout(searchRequestTimeout);
        if (searchBlock.trim().isNotEmpty) {
          prompt +=
              '\n\n[System directive: Web search was enabled for this turn. Use the following fresh search results only when relevant, cite source titles/URLs naturally, and mention uncertainty when results are incomplete.]\n$searchBlock';
        }
      } catch (error) {
        prompt +=
            '\n\n[System directive: Web search was requested, but the search service failed: $error. If current information is required, tell the user briefly that search failed instead of guessing.]';
      }
    }
    return prompt;
  }

  String _currentAppearanceDirective() {
    final background = backgroundOverride == null
        ? 'default:${themeMode.name}'
        : colorToHex(backgroundOverride!);
    final text = textOverride == null
        ? 'auto-contrast'
        : colorToHex(textOverride!);
    final assistantBubble = assistantBubbleOverride == null
        ? 'default'
        : colorToHex(assistantBubbleOverride!);
    final userBubble = userBubbleOverride == null
        ? 'default'
        : colorToHex(userBubbleOverride!);
    return '''

[System directive: Current supported chat appearance state:
- background style: background=$background, effectiveTheme=${effectiveThemeMode.name}
- font/text style: text=$text, fontFamily=$fontMood, fontStyle=$fontStyleMood, fontWeight=$fontWeightMood
- bubble style: style=$bubbleStyle, assistantColor=$assistantBubble, userColor=$userBubble, assistantOpacity=${assistantBubbleOpacity.toStringAsFixed(2)}, userOpacity=${userBubbleOpacity.toStringAsFixed(2)}
- message alignment: $messageAlignment
Treat background style, font/text style, bubble style, and message alignment as independent groups. If the user names only one group, modify only that group. Removing bubbles means bubbleStyle=none and bubbleOpacity=0; it never means changing background, text, or font.]
''';
  }

  Future<void> _refreshCurrentSessionTitle() async {
    final sessionId = currentSessionId;
    if (sessionId == null) return;
    if (messages.where((m) => m.role == 'user').length != 1) return;
    final title = await _generateTitleForMessages(messages);
    if (title == null || title.isEmpty) return;
    _renameSession(sessionId, title);
  }

  Future<String?> _generateTitleForMessages(List<ChatMessage> source) async {
    final assignment = modelAssignments['title'];
    if (assignment == null) return null;
    final provider = _providerForAssignment(assignment);
    if (_modelConfigIssue(
          assignment: assignment,
          provider: provider,
          roleLabel: '标题总结模型',
        ) !=
        null) {
      return null;
    }
    try {
      final title = await AiGateway.generateRoleText(
        provider: provider!,
        assignment: assignment,
        input:
            '请为下面这段对话生成一个适合移动端标题栏显示的中文标题。要求：8-16个字，直接输出标题，不要引号、前缀或解释。\n\n${_compactConversation(source)}',
      ).timeout(roleRequestTimeout);
      final cleaned = title
          .replaceAll(RegExp(r'["“”「」#：:]'), '')
          .trim()
          .split('\n')
          .first
          .trim();
      if (cleaned.isEmpty) return null;
      return cleaned.characters.take(16).toString();
    } catch (_) {
      // 标题生成是辅助功能，失败时保留首条用户消息作为标题。
      return null;
    }
  }

  Future<void> _refreshSuggestions() async {
    final assignment = modelAssignments['suggest'];
    if (assignment == null || messages.isEmpty) return;
    final provider = _providerForAssignment(assignment);
    if (_modelConfigIssue(
          assignment: assignment,
          provider: provider,
          roleLabel: '聊天建议模型',
        ) !=
        null) {
      suggestions = [];
      return;
    }
    try {
      final raw = await AiGateway.generateRoleText(
        provider: provider!,
        assignment: assignment,
        input:
            '基于下面这段对话，给出3个用户可能继续追问的简短中文问题。每行一个，不要编号。\n\n${_compactConversation(messages)}',
      ).timeout(roleRequestTimeout);
      suggestions = raw
          .split(RegExp(r'[\n\r]+'))
          .map(
            (line) =>
                line.replaceFirst(RegExp(r'^\s*[-*0-9.、]+\s*'), '').trim(),
          )
          .where((line) => line.isNotEmpty)
          .take(3)
          .toList();
      if (suggestions.isNotEmpty) notifyListeners();
    } catch (_) {
      suggestions = [];
    }
  }

  ModelAssignment? _effectiveImageAssignment() {
    final image = modelAssignments['image'];
    if (image != null &&
        image.provider.trim().isNotEmpty &&
        image.model.trim().isNotEmpty) {
      return image;
    }
    return null;
  }

  Future<MessageAttachment> _writeGeneratedImageAttachment(
    GeneratedImageResult result,
  ) async {
    final directory = await _generatedImagesDirectory();
    await directory.create(recursive: true);
    final extension = switch (result.mimeType.toLowerCase()) {
      'image/jpeg' || 'image/jpg' => 'jpg',
      'image/webp' => 'webp',
      _ => 'png',
    };
    final name =
        'weaview_image_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final file = File('${directory.path}${Platform.pathSeparator}$name');
    await file.writeAsBytes(result.bytes, flush: true);
    return MessageAttachment(
      path: file.path,
      name: name,
      mimeType: result.mimeType,
      kind: 'image',
      size: result.bytes.lengthInBytes,
    );
  }

  Future<Directory> _generatedImagesDirectory() async {
    if (Platform.isAndroid) {
      try {
        final path = await _nativeMedia.invokeMethod<String>(
          'generatedImageDirectory',
        );
        if (path != null && path.trim().isNotEmpty) {
          return Directory(path.trim());
        }
      } catch (_) {
        // Fall through to a desktop/test friendly persistent directory.
      }
    }

    final home =
        Platform.environment['APPDATA'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    return Directory(
      [home, 'Weaview', 'generated_images'].join(Platform.pathSeparator),
    );
  }

  Future<List<ChatSession>> _migrateGeneratedImageAttachments(
    List<ChatSession> sessions,
  ) async {
    if (sessions.isEmpty) return sessions;
    final tempRoot = Directory.systemTemp.path.replaceAll('\\', '/');
    var changed = false;
    Directory? targetDirectory;
    final migratedSessions = <ChatSession>[];

    for (final session in sessions) {
      var sessionChanged = false;
      final migratedMessages = <ChatMessage>[];
      for (final message in session.messages) {
        var messageChanged = false;
        final migratedAttachments = <MessageAttachment>[];
        for (final attachment in message.attachments) {
          final normalizedPath = attachment.path.replaceAll('\\', '/');
          final source = File(attachment.path);
          final isTempGeneratedImage =
              attachment.isImage &&
              attachment.name.startsWith('weaview_image_') &&
              normalizedPath.startsWith(tempRoot) &&
              normalizedPath.contains('/weaview_generated_images/');
          if (!isTempGeneratedImage || !await source.exists()) {
            migratedAttachments.add(attachment);
            continue;
          }

          targetDirectory ??= await _generatedImagesDirectory();
          await targetDirectory.create(recursive: true);
          final migratedName = _uniqueGeneratedImageName(
            targetDirectory,
            attachment.name,
          );
          final target = File(
            '${targetDirectory.path}${Platform.pathSeparator}$migratedName',
          );
          await source.copy(target.path);
          migratedAttachments.add(
            MessageAttachment(
              path: target.path,
              name: migratedName,
              mimeType: attachment.resolvedImageMimeType(),
              kind: 'image',
              size: attachment.size,
            ),
          );
          changed = true;
          messageChanged = true;
        }
        if (messageChanged) {
          final next = message.copy()..attachments = migratedAttachments;
          migratedMessages.add(next);
          sessionChanged = true;
        } else {
          migratedMessages.add(message);
        }
      }
      migratedSessions.add(
        sessionChanged ? session.copyWith(messages: migratedMessages) : session,
      );
    }

    if (changed) _prefs?.saveChatSessions(migratedSessions);
    return migratedSessions;
  }

  String _uniqueGeneratedImageName(Directory directory, String originalName) {
    final safeName = originalName
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .trim();
    final fallback =
        'weaview_image_${DateTime.now().millisecondsSinceEpoch}.png';
    final baseName = safeName.isEmpty ? fallback : safeName;
    final dot = baseName.lastIndexOf('.');
    final stem = dot > 0 ? baseName.substring(0, dot) : baseName;
    final extension = dot > 0 ? baseName.substring(dot) : '.png';
    var candidate = baseName;
    var index = 1;
    while (File(
      '${directory.path}${Platform.pathSeparator}$candidate',
    ).existsSync()) {
      candidate = '${stem}_$index$extension';
      index += 1;
    }
    return candidate;
  }

  AiProvider? _providerForAssignment(ModelAssignment assignment) {
    return ModelConfigResolver.providerForAssignment(providers, assignment);
  }

  String? _modelConfigIssue({
    required ModelAssignment? assignment,
    required AiProvider? provider,
    required String roleLabel,
  }) {
    return ModelConfigResolver.modelConfigIssue(
      assignment: assignment,
      provider: provider,
      roleLabel: roleLabel,
    );
  }

  String _friendlyAiError(Object error, {Duration? timeout}) {
    return ModelConfigResolver.friendlyAiError(
      error,
      chatRequestTimeout: timeout ?? chatRequestTimeout,
    );
  }

  String _compactConversation(List<ChatMessage> source) {
    final text = source
        .where((m) => m.content.trim().isNotEmpty)
        .map((m) => '${m.role == 'user' ? '用户' : '助手'}：${m.content.trim()}')
        .join('\n');
    return text.characters.take(4000).toString();
  }

  static Color _readableVariantOf(Color requested, Color background) {
    if (contrastRatio(background, requested) >= 4.5) return requested;
    final backgroundIsLight = background.computeLuminance() >= 0.45;
    final hsl = HSLColor.fromColor(requested);
    for (var i = 1; i <= 14; i++) {
      final nextLightness = backgroundIsLight
          ? (hsl.lightness - i * 0.045).clamp(0.18, 0.82)
          : (hsl.lightness + i * 0.045).clamp(0.18, 0.88);
      final candidate = hsl.withLightness(nextLightness.toDouble()).toColor();
      if (contrastRatio(background, candidate) >= 4.5) return candidate;
    }
    return readableTextFor(background);
  }

  void _renameSession(String sessionId, String title) {
    final index = chatSessions.indexWhere((s) => s.id == sessionId);
    if (index < 0) return;
    chatSessions[index] = chatSessions[index].copyWith(title: title);
    _sortChatSessions();
    _prefs?.saveChatSessions(chatSessions);
    notifyListeners();
  }

  AiProvider get activeChatProvider {
    return ModelConfigResolver.activeChatProvider(
      providers: providers,
      assignments: modelAssignments,
    );
  }

  List<AiProvider> get enabledModelProviders => providers
      .where(
        (provider) =>
            provider.apiKey.trim().isNotEmpty && provider.models.isNotEmpty,
      )
      .toList();

  bool get hasActiveSearchKey =>
      (searchConfig.keys[searchConfig.active]?.trim().isNotEmpty ?? false);

  bool get ttsEnabled => activeTtsId.trim().isNotEmpty;

  TtsProviderConfig? get activeTtsProvider =>
      ttsProviders.firstWhereOrNull((provider) => provider.id == activeTtsId);

  Future<void> retryMessageAt(
    int index, {
    bool useWebSearch = false,
    bool imageGeneration = false,
  }) async {
    if (isStreaming || index < 0 || index >= messages.length) return;
    var userIndex = index;
    if (messages[userIndex].role != 'user') {
      userIndex = messages
          .take(index)
          .toList()
          .lastIndexWhere((message) => message.role == 'user');
    }
    if (userIndex < 0) return;
    final original = messages[userIndex].copy();
    final prefix = messages
        .take(userIndex)
        .map((message) => message.copy())
        .toList();
    messages
      ..clear()
      ..addAll(prefix);
    suggestions = [];
    notifyListeners();
    if (imageGeneration) {
      await submitImageGeneration(
        original.content,
        attachments: original.attachments.map((item) => item.copy()).toList(),
      );
      return;
    }
    await submitMessage(
      original.content,
      attachments: original.attachments.map((item) => item.copy()).toList(),
      useWebSearch: useWebSearch,
    );
  }

  Future<void> translateMessageAt(int index) async {
    if (index < 0 || index >= messages.length) return;
    final source = messages[index].content.trim();
    if (source.isEmpty) return;
    final assignment = modelAssignments['translate'];
    final provider = assignment == null
        ? null
        : _providerForAssignment(assignment);
    final configIssue = _modelConfigIssue(
      assignment: assignment,
      provider: provider,
      roleLabel: '翻译模型',
    );
    if (configIssue != null) throw Exception(configIssue);
    final translated = await AiGateway.generateRoleText(
      provider: provider!,
      assignment: assignment!,
      input: '请将下面文本翻译成流畅自然的中文；如果原文已经是中文，则翻译成英文。\n\n$source',
    ).timeout(roleRequestTimeout);
    messages[index].translation = translated.trim();
    _persistCurrentSession();
    notifyListeners();
  }

  void saveProviders(List<AiProvider> next) {
    providers = next
        .map((provider) => provider.copyWith(models: provider.models))
        .toList();
    _persistProviders();
    notifyListeners();
  }

  void reorderProvider(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= providers.length) return;
    var targetIndex = newIndex;
    if (targetIndex > oldIndex) targetIndex -= 1;
    targetIndex = targetIndex.clamp(0, providers.length - 1);
    final next = [...providers];
    final item = next.removeAt(oldIndex);
    next.insert(targetIndex, item);
    saveProviders(next);
  }

  void _persistProviders() {
    _prefs?.saveProviders(providers);
  }

  void upsertProvider(AiProvider provider, {bool makeCurrent = false}) {
    final next = [...providers];
    final index = next.indexWhere((p) => p.name == provider.name);
    var updated = provider;
    if (makeCurrent) {
      updated = provider.copyWith(current: true, status: '使用中');
      for (var i = 0; i < next.length; i++) {
        next[i] = next[i].copyWith(
          current: false,
          status: next[i].apiKey.isEmpty ? '未配置' : '已连接',
        );
      }
    }
    if (index >= 0) {
      next[index] = updated;
    } else {
      next.add(updated);
    }
    saveProviders(next);
  }

  void deleteProvider(String name) {
    final next = providers.where((p) => p.name != name).toList();
    if (!next.any((p) => p.current) && next.isNotEmpty) {
      next[0] = next[0].copyWith(current: true, status: '使用中');
    }
    saveProviders(next);
  }

  void saveModelAssignment(String role, ModelAssignment assignment) {
    modelAssignments = {...modelAssignments, role: assignment};
    _prefs?.saveModelAssignments(modelAssignments);
    notifyListeners();
  }

  void saveSearchConfig(SearchConfig next) {
    searchConfig = next;
    _prefs?.saveSearchConfig(next);
    notifyListeners();
  }

  void saveTtsConfig(List<TtsProviderConfig> providers, String activeId) {
    final next = _mergeTtsProviders(providers);
    final nextActiveId = _safeActiveTtsId(activeId, next);
    ttsProviders = next;
    activeTtsId = nextActiveId;
    _prefs?.saveTtsConfig(next, nextActiveId);
    notifyListeners();
  }

  List<TtsProviderConfig> _mergeTtsProviders(List<TtsProviderConfig> saved) {
    final defaults = TtsProviderConfig.defaults();
    if (saved.isEmpty) return defaults;
    final defaultsById = {
      for (final provider in defaults) provider.id: provider,
    };
    final merged = saved.map((provider) {
      final preset = defaultsById[provider.id];
      if (preset == null) return provider;
      return provider.copyWith(
        type: provider.id == 'xiaomi' || provider.type.isEmpty
            ? preset.type
            : provider.type,
        name: provider.name.isEmpty ? preset.name : provider.name,
        baseUrl: provider.baseUrl.isEmpty ? preset.baseUrl : provider.baseUrl,
        model: provider.model.isEmpty ? preset.model : provider.model,
        voice: provider.voice.isEmpty ? preset.voice : provider.voice,
      );
    }).toList();
    final savedIds = merged.map((provider) => provider.id).toSet();
    merged.addAll(
      defaults.where((provider) => !savedIds.contains(provider.id)),
    );
    return merged;
  }

  String _safeActiveTtsId(String activeId, List<TtsProviderConfig> providers) {
    final trimmed = activeId.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed == 'system') return 'system';
    return providers.any((provider) => provider.id == trimmed) ? trimmed : '';
  }

  String exportJson() {
    return const JsonEncoder.withIndent('  ').convert({
      'chat_sessions': chatSessions.map((s) => s.toJson()).toList(),
      'ai_providers': providers.map((p) => p.safeJson()).toList(),
      'ai_model_assignments': modelAssignments.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'ai_memories': memories,
      'ai_search_config': searchConfig.safeJson(),
      'ai_active_tts_id': activeTtsId,
      'ai_tts_providers': ttsProviders.map((p) => p.safeJson()).toList(),
      'user_name': userName,
      'assistant_name': assistantName,
      'user_profile': userProfile,
      'theme_mode': themeMode.name,
      'theme_bubble_style': bubbleStyle,
      'theme_message_alignment': messageAlignment,
    });
  }

  Uint8List exportZipBytes() {
    final exportedAt = DateTime.now().toIso8601String();
    return buildStoredZip([
      ZipEntryData(
        name: 'weaview-export.json',
        bytes: utf8.encode(exportJson()),
      ),
      ZipEntryData(
        name: 'README.txt',
        bytes: utf8.encode(
          'Weaview local data export\nExported at: $exportedAt\nFormat: UTF-8 JSON\n',
        ),
      ),
    ]);
  }

  Future<void> clearAllLocalData() async {
    await _prefs?.clear();
    messages.clear();
    chatSessions.clear();
    suggestions = [];
    currentSessionId = null;
    systemPrompt = defaultSystemInstruction;
    emotionEnabled = true;
    globalMemoryEnabled = true;
    referenceHistoryEnabled = false;
    assistantAvatar = '';
    userAvatar = '';
    userName = '织梦者';
    assistantName = '织境';
    userProfile = '';
    providers = AiProvider.defaults();
    modelAssignments = ModelAssignment.defaults();
    memories = [];
    searchConfig = const SearchConfig(active: 'tavily', keys: {});
    activeTtsId = '';
    ttsProviders = TtsProviderConfig.defaults();
    themeMode = ThemeMode.system;
    backgroundOverride = null;
    textOverride = null;
    assistantBubbleOverride = null;
    userBubbleOverride = null;
    fontMood = 'sans';
    fontStyleMood = 'normal';
    fontWeightMood = 'normal';
    bubbleStyle = 'minimal';
    messageAlignment = 'left';
    assistantBubbleOpacity = 0.08;
    userBubbleOpacity = 0.12;
    notifyListeners();
  }
}
