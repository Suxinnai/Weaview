part of '../main.dart';

class WeaviewState extends ChangeNotifier {
  SharedPreferences? _prefs;
  bool loaded = false;
  ThemeMode themeMode = ThemeMode.system;
  Color? backgroundOverride;
  Color? textOverride;
  String fontMood = 'sans';
  List<Color> accents = const [_accentMint, _accentGreen];
  int themePulse = 0;

  String systemPrompt = defaultSystemInstruction;
  bool emotionEnabled = true;
  bool globalMemoryEnabled = true;
  bool referenceHistoryEnabled = false;
  String assistantAvatar = '';
  String userAvatar = '';
  String userName = '织梦者';
  bool isStreaming = false;

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

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final prefs = _prefs!;
    systemPrompt = prefs.getString('system_prompt') ?? defaultSystemInstruction;
    emotionEnabled = prefs.getBool('emotion_enabled') ?? true;
    globalMemoryEnabled = prefs.getBool('global_memory_enabled') ?? true;
    referenceHistoryEnabled =
        prefs.getBool('reference_history_enabled') ?? false;
    assistantAvatar = prefs.getString('assistant_avatar') ?? '';
    userAvatar = prefs.getString('user_avatar') ?? '';
    userName = prefs.getString('user_name') ?? '织梦者';
    themeMode = _decodeThemeMode(prefs.getString('theme_mode'));
    backgroundOverride = colorFromHex(prefs.getString('theme_background'));
    textOverride = colorFromHex(prefs.getString('theme_text'));
    fontMood = prefs.getString('theme_font_family') ?? 'sans';

    final savedSessions = _decodeList(
      prefs.getString('chat_sessions'),
      ChatSession.fromJson,
    );
    chatSessions
      ..clear()
      ..addAll(savedSessions);

    final savedProviders = _decodeList(
      prefs.getString('ai_providers'),
      AiProvider.fromJson,
    );
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
      if (provider.name.toLowerCase().contains('gemini') &&
          provider.apiKey.isEmpty) {
        return provider.copyWith(models: const [], status: '未配置');
      }
      return provider;
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

    final assignmentText = prefs.getString('ai_model_assignments');
    if (assignmentText != null) {
      try {
        final decoded = jsonDecode(assignmentText) as Map<String, dynamic>;
        modelAssignments = {
          ...ModelAssignment.defaults(),
          for (final entry in decoded.entries)
            entry.key: ModelAssignment.fromJson(entry.value),
        };
      } catch (_) {}
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

    final savedMemories = prefs.getString('ai_memories');
    if (savedMemories != null) {
      try {
        memories = (jsonDecode(savedMemories) as List)
            .map((item) => item.toString())
            .toList();
      } catch (_) {}
    }

    final savedSearch = prefs.getString('ai_search_config');
    if (savedSearch != null) {
      try {
        searchConfig = SearchConfig.fromJson(jsonDecode(savedSearch));
      } catch (_) {}
    }

    activeTtsId = prefs.getString('ai_active_tts_id') ?? 'system';
    final savedTts = _decodeList(
      prefs.getString('ai_tts_providers'),
      TtsProviderConfig.fromJson,
    );
    if (savedTts.isNotEmpty) {
      ttsProviders = savedTts;
    }

    loaded = true;
    notifyListeners();
  }

  bool isDark(BuildContext context) {
    if (themeMode == ThemeMode.dark) return true;
    if (themeMode == ThemeMode.light) return false;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }

  Color background(BuildContext context) {
    return backgroundOverride ?? (isDark(context) ? _baseDark : _baseLight);
  }

  Color layer(BuildContext context) {
    return isDark(context) ? _layerDark : _layerLight;
  }

  Color text(BuildContext context) {
    return textOverride ?? (isDark(context) ? _textDark : _textLight);
  }

  Color muted(BuildContext context) {
    return isDark(context) ? _mutedDark : _mutedLight;
  }

  TextStyle textStyle(
    BuildContext context, {
    double size = 14,
    FontWeight weight = FontWeight.w400,
    double opacity = 1,
    double height = 1.35,
  }) {
    return TextStyle(
      color: text(context).withValues(alpha: opacity),
      fontSize: size,
      fontWeight: weight,
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
    _prefs?.setString('theme_mode', mode.name);
    notifyListeners();
  }

  void applyAiTheme(Map<String, dynamic> args) {
    final bg = colorFromHex(args['backgroundColor']?.toString());
    final txt = colorFromHex(args['textColor']?.toString());
    if (bg != null) {
      backgroundOverride = bg;
      _prefs?.setString('theme_background', colorToHex(bg));
    }
    if (txt != null) {
      textOverride = txt;
      _prefs?.setString('theme_text', colorToHex(txt));
    }
    final family = args['fontFamily']?.toString();
    if (family == 'serif' || family == 'sans') {
      fontMood = family!;
      _prefs?.setString('theme_font_family', family);
    }
    if (args['isDark'] is bool) {
      themeMode = args['isDark'] == true ? ThemeMode.dark : ThemeMode.light;
      _prefs?.setString('theme_mode', themeMode.name);
    }
    themePulse++;
    notifyListeners();
  }

  void updateSystemPrompt(String value) {
    systemPrompt = value.isEmpty ? defaultSystemInstruction : value;
    _prefs?.setString('system_prompt', systemPrompt);
    notifyListeners();
  }

  void updateUserName(String value) {
    userName = value;
    _prefs?.setString('user_name', value);
    notifyListeners();
  }

  void updateAssistantAvatar(String value) {
    assistantAvatar = value;
    if (value.isEmpty) {
      _prefs?.remove('assistant_avatar');
    } else {
      _prefs?.setString('assistant_avatar', value);
    }
    notifyListeners();
  }

  void updateUserAvatar(String value) {
    userAvatar = value;
    if (value.isEmpty) {
      _prefs?.remove('user_avatar');
    } else {
      _prefs?.setString('user_avatar', value);
    }
    notifyListeners();
  }

  void setEmotionEnabled(bool value) {
    emotionEnabled = value;
    _prefs?.setBool('emotion_enabled', value);
    notifyListeners();
  }

  void setGlobalMemoryEnabled(bool value) {
    globalMemoryEnabled = value;
    _prefs?.setBool('global_memory_enabled', value);
    notifyListeners();
  }

  void setReferenceHistoryEnabled(bool value) {
    referenceHistoryEnabled = value;
    _prefs?.setBool('reference_history_enabled', value);
    notifyListeners();
  }

  void addMemory(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    memories = [trimmed, ...memories];
    _prefs?.setString('ai_memories', jsonEncode(memories));
    notifyListeners();
  }

  void deleteMemory(int index) {
    memories = [
      for (var i = 0; i < memories.length; i++)
        if (i != index) memories[i],
    ];
    _prefs?.setString('ai_memories', jsonEncode(memories));
    notifyListeners();
  }

  void clearMemories() {
    memories = [];
    _prefs?.setString('ai_memories', jsonEncode(memories));
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
    _prefs?.setString(
      'chat_sessions',
      jsonEncode(chatSessions.map((s) => s.toJson()).toList()),
    );
  }

  Future<void> submitMessage(
    String value, {
    List<MessageAttachment> attachments = const [],
    bool useWebSearch = false,
  }) async {
    final content = value.trim();
    if ((content.isEmpty && attachments.isEmpty) || isStreaming) return;

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
    _persistCurrentSession();
    notifyListeners();

    var lastNotify = DateTime.fromMillisecondsSinceEpoch(0);
    void flush({bool force = false}) {
      final now = DateTime.now();
      if (!force && now.difference(lastNotify).inMilliseconds < 36) return;
      lastNotify = now;
      notifyListeners();
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
        onThemeUpdate: applyAiTheme,
        onSnapshot: (content, reasoning, thinking) {
          final current = messages.last;
          current.content = content;
          current.reasoning = reasoning;
          current.isThinking = thinking;
          flush();
        },
      );
      messages.last.isThinking = false;
      if (messages.last.content.trim().isEmpty) {
        messages.last.content = '我在，但这一缕回应没有形成文字。';
      }
      flush(force: true);
      await _refreshCurrentSessionTitle();
      await _refreshSuggestions();
    } catch (error) {
      messages.last.content =
          '连接织线时出现了问题：${_friendlyAiError(error)}\n\n请检查网络、API Key 或模型配置后重试。';
      messages.last.isThinking = false;
      notifyListeners();
    } finally {
      isStreaming = false;
      _persistCurrentSession();
      notifyListeners();
    }
  }

  Future<String> _expandedSystemPrompt({String? webQuery}) async {
    var prompt = systemPrompt;
    if (emotionEnabled) {
      prompt +=
          '\n\n[System directive: Emotion and poetry mode is ENABLED. Your responses should be highly emotional, vivid, and deeply artistic. Do not just output plain facts.]';
    }
    if (globalMemoryEnabled && memories.isNotEmpty) {
      prompt +=
          '\n\n[System directive: You have the following memories about the user:\n${memories.map((m) => '- $m').join('\n')}\nPlease take them into account when responding.]';
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
        ).timeout(_searchRequestTimeout);
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
      ).timeout(_roleRequestTimeout);
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
      ).timeout(_roleRequestTimeout);
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
    if (assignment.provider.isNotEmpty) {
      final matched = providers.firstWhereOrNull(
        (p) => p.name == assignment.provider,
      );
      if (matched != null) return matched;
    }
    return null;
  }

  String? _modelConfigIssue({
    required ModelAssignment? assignment,
    required AiProvider? provider,
    required String roleLabel,
  }) {
    if (assignment == null ||
        assignment.provider.trim().isEmpty ||
        assignment.model.trim().isEmpty) {
      return '请先在「设置 > 默认模型」中分配$roleLabel。';
    }
    if (provider == null) {
      return '$roleLabel关联的提供商不存在，请重新选择模型。';
    }
    final isGemini = provider.name.toLowerCase().contains('gemini');
    if (provider.apiKey.trim().isEmpty &&
        !(isGemini && _geminiApiKey.isNotEmpty)) {
      return '请先在「设置 > 提供商」中为 ${provider.name} 配置 API Key。';
    }
    return null;
  }

  String _friendlyAiError(Object error) {
    final text = error
        .toString()
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .trim();
    if (text.contains('TimeoutException')) {
      return '请求超时：当前设备网络或提供商在 ${_chatRequestTimeout.inSeconds} 秒内没有返回数据。'
          '如果桌面端可用但真机不可用，请确认手机网络能直接访问当前 Base URL，或为手机配置同一网络代理。';
    }
    if (text.contains('SocketException')) {
      return '网络连接失败：当前设备无法连接到提供商地址。';
    }
    if (text.contains('HandshakeException') || text.contains('CERTIFICATE')) {
      return '安全连接失败：请检查提供商证书或改用有效的 HTTPS 地址。';
    }
    return text.isEmpty ? '未知错误。' : text;
  }

  String _compactConversation(List<ChatMessage> source) {
    final text = source
        .where((m) => m.content.trim().isNotEmpty)
        .map((m) => '${m.role == 'user' ? '用户' : '助手'}：${m.content.trim()}')
        .join('\n');
    return text.characters.take(4000).toString();
  }

  void _renameSession(String sessionId, String title) {
    final index = chatSessions.indexWhere((s) => s.id == sessionId);
    if (index < 0) return;
    chatSessions[index] = chatSessions[index].copyWith(title: title);
    _prefs?.setString(
      'chat_sessions',
      jsonEncode(chatSessions.map((s) => s.toJson()).toList()),
    );
    notifyListeners();
  }

  AiProvider get activeChatProvider {
    final assignment = modelAssignments['chat'];
    if (assignment != null && assignment.provider.isNotEmpty) {
      final matched = providers.firstWhereOrNull(
        (p) => p.name == assignment.provider,
      );
      if (matched != null) return matched;
    }
    return providers.firstWhereOrNull((p) => p.current) ?? providers.first;
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
    ).timeout(_roleRequestTimeout);
    messages[index].translation = translated.trim();
    _persistCurrentSession();
    notifyListeners();
  }

  void saveProviders(List<AiProvider> next) {
    providers = next;
    _prefs?.setString(
      'ai_providers',
      jsonEncode(providers.map((p) => p.toJson()).toList()),
    );
    notifyListeners();
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
    _prefs?.setString(
      'ai_model_assignments',
      jsonEncode(
        modelAssignments.map((key, value) => MapEntry(key, value.toJson())),
      ),
    );
    notifyListeners();
  }

  void saveSearchConfig(SearchConfig next) {
    searchConfig = next;
    _prefs?.setString('ai_search_config', jsonEncode(next.toJson()));
    notifyListeners();
  }

  void saveTtsConfig(List<TtsProviderConfig> providers, String activeId) {
    ttsProviders = providers;
    activeTtsId = activeId;
    _prefs?.setString(
      'ai_tts_providers',
      jsonEncode(providers.map((p) => p.toJson()).toList()),
    );
    _prefs?.setString('ai_active_tts_id', activeId);
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
      'theme_mode': themeMode.name,
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
    fontMood = 'sans';
    notifyListeners();
  }
}
