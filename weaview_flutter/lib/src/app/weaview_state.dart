import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/app_utils.dart';
import '../data/ai/ai_gateway.dart';
import '../domain/models.dart';
import 'ai_theme_guard.dart';
import 'app_constants.dart';
import 'model_config_resolver.dart';
import 'prompt_appearance_intent.dart';
import 'weaview_preferences.dart';

class WeaviewState extends ChangeNotifier {
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
  bool isStreaming = false;
  int _streamRunId = 0;
  bool _cancelStreamRequested = false;

  final List<ChatMessage> messages = [];
  final List<ChatSession> chatSessions = [];
  List<String> suggestions = [];
  String? currentSessionId;

  List<AiProvider> providers = AiProvider.defaults();
  Map<String, ModelAssignment> modelAssignments = ModelAssignment.defaults();
  List<String> memories = [];
  SearchConfig searchConfig = const SearchConfig(active: 'tavily', keys: {});
  String activeTtsId = 'system';
  List<TtsProviderConfig> ttsProviders = [
    const TtsProviderConfig(
      id: 'xiaomi',
      type: 'xiaomi',
      name: 'Xiaomi MiMo TTS',
      apiKey: '',
      baseUrl: '',
      model: '',
      voice: '',
    ),
  ];

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

    final savedSessions = prefs.loadChatSessions();
    chatSessions
      ..clear()
      ..addAll(savedSessions);

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
    providers = providers.map((provider) {
      final normalized = provider.copyWith(models: provider.models);
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

    activeTtsId = prefs.activeTtsId;
    final savedTts = prefs.loadTtsProviders();
    if (savedTts.isNotEmpty) {
      ttsProviders = savedTts;
    }

    loaded = true;
    notifyListeners();
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
    userName = value;
    _prefs?.saveUserName(value);
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
    try {
      final decoded = jsonDecode(raw) as List;
      memories = decoded
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .take(12)
          .toList();
    } catch (_) {
      memories = raw
          .split(RegExp(r'[\n\r]+'))
          .map(
            (line) =>
                line.replaceFirst(RegExp(r'^\s*[-*0-9.、]+\s*'), '').trim(),
          )
          .where((line) => line.isNotEmpty)
          .take(12)
          .toList();
    }
    _prefs?.saveMemories(memories);
    notifyListeners();
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
    );
    final index = chatSessions.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      chatSessions.removeAt(index);
    }
    chatSessions.insert(0, session);
    _prefs?.saveChatSessions(chatSessions);
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
          targetContent = content;
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
      messages.last.isThinking = false;
      if (messages.last.content.trim().isEmpty) {
        messages.last.content = '我在，但这一缕回应没有形成文字。';
      }
      flush(force: true);
      await _refreshCurrentSessionTitle();
      await _refreshSuggestions();
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
        isStreaming = false;
        _cancelStreamRequested = false;
        _persistCurrentSession();
        notifyListeners();
      }
    }
  }

  void cancelStreaming() {
    if (!isStreaming) return;
    _cancelStreamRequested = true;
    _streamRunId++;
    if (messages.isNotEmpty && messages.last.role == 'model') {
      final current = messages.last;
      current.isThinking = false;
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
    final assignment = modelAssignments['title'];
    if (assignment == null) return;
    final provider = _providerForAssignment(assignment);
    if (_modelConfigIssue(
          assignment: assignment,
          provider: provider,
          roleLabel: '标题总结模型',
        ) !=
        null) {
      return;
    }
    try {
      final title = await AiGateway.generateRoleText(
        provider: provider!,
        assignment: assignment,
        input: '请为下面这段对话生成一个不超过10个中文字的标题。\n\n${_compactConversation(messages)}',
      ).timeout(roleRequestTimeout);
      final cleaned = title
          .replaceAll(RegExp(r'["“”「」#：:]'), '')
          .trim()
          .split('\n')
          .first
          .trim();
      if (cleaned.isEmpty) return;
      _renameSession(
        sessionId,
        cleaned.length > 18 ? cleaned.substring(0, 18) : cleaned,
      );
    } catch (_) {
      // 标题生成是辅助功能，失败时保留首条用户消息作为标题。
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

  String _friendlyAiError(Object error) {
    return ModelConfigResolver.friendlyAiError(
      error,
      chatRequestTimeout: chatRequestTimeout,
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
    _prefs?.saveChatSessions(chatSessions);
    notifyListeners();
  }

  AiProvider get activeChatProvider {
    return ModelConfigResolver.activeChatProvider(
      providers: providers,
      assignments: modelAssignments,
    );
  }

  bool get hasActiveSearchKey =>
      (searchConfig.keys[searchConfig.active]?.trim().isNotEmpty ?? false);

  Future<void> retryMessageAt(int index, {bool useWebSearch = false}) async {
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
    ttsProviders = providers;
    activeTtsId = activeId;
    _prefs?.saveTtsConfig(providers, activeId);
    notifyListeners();
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
    activeTtsId = 'system';
    ttsProviders = [
      const TtsProviderConfig(
        id: 'xiaomi',
        type: 'xiaomi',
        name: 'Xiaomi MiMo TTS',
        apiKey: '',
        baseUrl: '',
        model: '',
        voice: '',
      ),
    ];
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
