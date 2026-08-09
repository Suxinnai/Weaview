import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_utils.dart';
import '../core/zip_writer.dart';
import '../data/ai/ai_gateway.dart';
import '../data/ai/ai_response_parsers.dart';
import '../data/ai/image_tool_call_parser.dart';
import '../data/ai/openai_compatible_client.dart' show GeneratedImageResult;
import '../domain/models.dart';
import 'app_constants.dart';
import 'model_config_resolver.dart';
import 'services/personalization_service.dart';
import 'services/provider_config_service.dart';
import 'services/session_manager.dart';
import 'services/theme_service.dart';
import 'token_pricing.dart';
import 'weaview_preferences.dart';

class _ImageAspect {
  const _ImageAspect({required this.label, required this.ratio});

  final String label;
  final double ratio;
}

class _PreparedImageRequest {
  const _PreparedImageRequest({
    required this.prompt,
    required this.size,
    this.aspectRatio,
  });

  final String prompt;
  final String size;
  final String? aspectRatio;
}

class _ComparisonTarget {
  const _ComparisonTarget({required this.provider, required this.assignment});

  final AiProvider provider;
  final ModelAssignment assignment;
}

class BackupImportResult {
  const BackupImportResult({
    required this.sessions,
    required this.memories,
    required this.providers,
    this.workCards = 0,
    this.tokenUsageRecords = 0,
  });

  final int sessions;
  final int memories;
  final int providers;
  final int workCards;
  final int tokenUsageRecords;

  String get summary {
    final cardText = workCards > 0 ? '、$workCards 张作品卡' : '';
    final usageText = tokenUsageRecords > 0 ? '、$tokenUsageRecords 条用量记录' : '';
    return '已合并 $sessions 个会话、$memories 条记忆、$providers 个提供商$cardText$usageText。';
  }
}

class WeaviewState extends ChangeNotifier {
  static const int maxBackupArchiveBytes = 32 * 1024 * 1024;
  static const int maxBackupJsonBytes = 16 * 1024 * 1024;

  static const MethodChannel _nativeMedia = MethodChannel(
    'weaview/native_media',
  );

  static const MethodChannel _nativeNotifications = MethodChannel(
    'weaview/native_notifications',
  );

  WeaviewPreferences? _prefs;
  bool loaded = false;

  // Services
  final ThemeService _theme = ThemeService();
  final PersonalizationService _personal = PersonalizationService();
  final SessionManager _sessions = SessionManager();
  final ProviderConfigService _providers = ProviderConfigService();

  // Streaming state
  bool isStreaming = false;
  int _streamRunId = 0;
  bool _cancelStreamRequested = false;
  int _activeImageGenerationCount = 0;
  final Set<int> _cancelledImageRuns = {};
  final Set<int> _backgroundedImageRuns = {};

  // Chat state
  final List<ChatMessage> messages = [];
  List<String> suggestions = [];
  List<WorkCard> workCards = [];
  List<TokenUsageRecord> tokenUsageRecords = [];

  List<Color> get accents => [_theme.accentColor, _theme.secondaryAccent];

  // ── Backward-compatible getters/setters ──────────────────────────

  // Theme
  ThemeMode get themeMode => _theme.themeMode;
  set themeMode(ThemeMode v) => _theme.themeMode = v;
  Color? get backgroundOverride => _theme.backgroundOverride;
  set backgroundOverride(Color? v) => _theme.backgroundOverride = v;
  Color? get textOverride => _theme.textOverride;
  set textOverride(Color? v) => _theme.textOverride = v;
  Color? get assistantBubbleOverride => _theme.assistantBubbleOverride;
  set assistantBubbleOverride(Color? v) => _theme.assistantBubbleOverride = v;
  Color? get userBubbleOverride => _theme.userBubbleOverride;
  set userBubbleOverride(Color? v) => _theme.userBubbleOverride = v;
  String get fontMood => _theme.fontMood;
  set fontMood(String v) => _theme.fontMood = v;
  String get fontStyleMood => _theme.fontStyleMood;
  set fontStyleMood(String v) => _theme.fontStyleMood = v;
  String get fontWeightMood => _theme.fontWeightMood;
  set fontWeightMood(String v) => _theme.fontWeightMood = v;
  String get bubbleStyle => _theme.bubbleStyle;
  set bubbleStyle(String v) => _theme.bubbleStyle = v;
  String get messageAlignment => _theme.messageAlignment;
  set messageAlignment(String v) => _theme.messageAlignment = v;
  double get assistantBubbleOpacity => _theme.assistantBubbleOpacity;
  set assistantBubbleOpacity(double v) => _theme.assistantBubbleOpacity = v;
  double get userBubbleOpacity => _theme.userBubbleOpacity;
  set userBubbleOpacity(double v) => _theme.userBubbleOpacity = v;
  int get themePulse => _theme.themePulse;

  // Personalization
  String get systemPrompt => _personal.systemPrompt;
  set systemPrompt(String v) => _personal.systemPrompt = v;
  bool get emotionEnabled => _personal.emotionEnabled;
  set emotionEnabled(bool v) => _personal.emotionEnabled = v;
  bool get globalMemoryEnabled => _personal.globalMemoryEnabled;
  set globalMemoryEnabled(bool v) => _personal.globalMemoryEnabled = v;
  bool get referenceHistoryEnabled => _personal.referenceHistoryEnabled;
  set referenceHistoryEnabled(bool v) => _personal.referenceHistoryEnabled = v;
  String get assistantAvatar => _personal.assistantAvatar;
  set assistantAvatar(String v) => _personal.assistantAvatar = v;
  String get userAvatar => _personal.userAvatar;
  set userAvatar(String v) => _personal.userAvatar = v;
  String get userName => _personal.userName;
  set userName(String v) => _personal.userName = v;
  String get assistantName => _personal.assistantName;
  set assistantName(String v) => _personal.assistantName = v;
  String get userProfile => _personal.userProfile;
  set userProfile(String v) => _personal.userProfile = v;
  List<String> get memories => _personal.memories;
  set memories(List<String> v) => _personal.memories = v;
  List<MemoryItem> get memoryItems => _personal.sortedMemoryItems;
  set memoryItems(List<MemoryItem> v) => _personal.memoryItems = v;

  // Sessions
  List<ChatSession> get chatSessions => _sessions.chatSessions;
  String? get currentSessionId => _sessions.currentSessionId;
  set currentSessionId(String? v) => _sessions.currentSessionId = v;
  String get currentSessionTitle =>
      chatSessions
          .firstWhereOrNull((session) => session.id == currentSessionId)
          ?.title ??
      '';

  List<WorkCard> get sortedWorkCards {
    final cards = [...workCards];
    cards.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return cards;
  }

  List<TokenUsageRecord> get sortedTokenUsageRecords {
    final records = [...tokenUsageRecords];
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  int get totalTokenUsage =>
      tokenUsageRecords.fold(0, (sum, record) => sum + record.totalTokens);

  double get totalEstimatedCostUsd =>
      tokenUsageRecords.fold(0, (sum, record) => sum + record.estimatedCostUsd);

  // Providers / config
  List<AiProvider> get providers => _providers.providers;
  set providers(List<AiProvider> v) => _providers.providers = v;
  Map<String, ModelAssignment> get modelAssignments =>
      _providers.modelAssignments;
  set modelAssignments(Map<String, ModelAssignment> v) =>
      _providers.modelAssignments = v;
  SearchConfig get searchConfig => _providers.searchConfig;
  set searchConfig(SearchConfig v) => _providers.searchConfig = v;
  String get activeTtsId => _providers.activeTtsId;
  set activeTtsId(String v) => _providers.activeTtsId = v;
  List<TtsProviderConfig> get ttsProviders => _providers.ttsProviders;
  set ttsProviders(List<TtsProviderConfig> v) => _providers.ttsProviders = v;

  // ── Derived getters ──────────────────────────────────────────────

  bool get hasActiveImageGeneration =>
      _activeImageGenerationCount > 0 ||
      messages.any((message) => message.isImageGenerating);

  void markAppBackgrounded() {
    if (hasActiveImageGeneration) {
      _backgroundedImageRuns.add(_streamRunId);
    }
  }

  ThemeMode get effectiveThemeMode => _theme.effectiveThemeMode;

  AiProvider get activeChatProvider => _providers.activeChatProvider;

  List<AiProvider> get enabledModelProviders =>
      _providers.enabledModelProviders;

  bool get hasActiveSearchKey => _providers.hasActiveSearchKey;

  bool get ttsEnabled => _providers.ttsEnabled;

  TtsProviderConfig? get activeTtsProvider => _providers.activeTtsProvider;

  // ── Load ─────────────────────────────────────────────────────────

  Future<void> load() async {
    _prefs = await WeaviewPreferences.open();
    final prefs = _prefs!;

    _personal.load(prefs);
    _personal.syncUserNameIntoProfile(prefs: prefs);
    _theme.load(prefs);

    final savedSessions = await _migrateGeneratedImageAttachments(
      prefs.loadChatSessions(),
    );
    _sessions.load(savedSessions);
    final savedSessionId = prefs.lastSessionId;
    final shouldResumeSession =
        savedSessionId == null || savedSessionId.trim().isNotEmpty;
    ChatSession? sessionToResume;
    if (savedSessions.isNotEmpty && shouldResumeSession) {
      sessionToResume = savedSessions.firstWhereOrNull(
        (session) => session.id == savedSessionId,
      );
      sessionToResume ??= savedSessions.reduce(
        (latest, session) =>
            session.updatedAt > latest.updatedAt ? session : latest,
      );
    }
    if (sessionToResume != null) {
      _sessions.selectSession(sessionToResume, messages, suggestions);
      prefs.saveLastSessionId(sessionToResume.id);
    }
    workCards = prefs.loadWorkCards();
    tokenUsageRecords = prefs.loadTokenUsageRecords();

    _providers.load(prefs);

    loaded = true;
    notifyListeners();
    if (!_personal.hasProfileDetails && chatSessions.isNotEmpty) {
      unawaited(
        _personal.refreshUserProfileFromConversation(
          messages: messages,
          chatSessions: chatSessions,
          modelAssignments: modelAssignments,
          providers: providers,
          prefs: _prefs,
          force: true,
        ),
      );
    }
  }

  // ── Theme delegation ─────────────────────────────────────────────

  bool isDark(BuildContext context) => _theme.isDark(context);

  Color background(BuildContext context) => _theme.background(context);

  Color layer(BuildContext context) => _theme.layer(context);

  Color text(BuildContext context) => _theme.text(context);

  Color muted(BuildContext context) => _theme.muted(context);

  TextStyle textStyle(
    BuildContext context, {
    double size = 14,
    FontWeight weight = FontWeight.w400,
    double opacity = 1,
    double height = 1.35,
  }) => _theme.textStyle(
    context,
    size: size,
    weight: weight,
    opacity: opacity,
    height: height,
  );

  void setThemeModeValue(ThemeMode mode) {
    _theme.setThemeModeValue(mode, _prefs);
    notifyListeners();
  }

  void setAccentColor(Color color) {
    _theme.setAccentColor(color, _prefs);
    notifyListeners();
  }

  void applyAiTheme(Map<String, dynamic> args, {String? userPrompt}) {
    _theme.applyAiTheme(args, userPrompt: userPrompt, prefs: _prefs);
    notifyListeners();
  }

  void resetAiTheme() {
    _theme.resetAiTheme(_prefs);
    notifyListeners();
  }

  bool _applyPromptAppearanceIntent(String value) {
    final result = _theme.applyPromptAppearanceIntent(value, _prefs);
    if (result) notifyListeners();
    return result;
  }

  // ── Personalization delegation ────────────────────────────────────

  void updateSystemPrompt(String value) {
    _personal.updateSystemPrompt(value, _prefs);
    notifyListeners();
  }

  void updateUserName(String value) {
    _personal.updateUserName(value, _prefs);
    notifyListeners();
  }

  void updateAssistantName(String value) {
    _personal.updateAssistantName(value, _prefs);
    notifyListeners();
  }

  void updateUserProfile(String value) {
    _personal.updateUserProfile(value, _prefs);
    notifyListeners();
  }

  void updateAssistantAvatar(String value) {
    _personal.updateAssistantAvatar(value, _prefs);
    notifyListeners();
  }

  void updateUserAvatar(String value) {
    _personal.updateUserAvatar(value, _prefs);
    notifyListeners();
  }

  void setEmotionEnabled(bool value) {
    _personal.setEmotionEnabled(value, _prefs);
    notifyListeners();
  }

  void setGlobalMemoryEnabled(bool value) {
    _personal.setGlobalMemoryEnabled(value, _prefs);
    notifyListeners();
  }

  void setReferenceHistoryEnabled(bool value) {
    _personal.setReferenceHistoryEnabled(value, _prefs);
    notifyListeners();
  }

  void addMemory(String value) {
    _personal.addMemory(value, _prefs);
    notifyListeners();
  }

  void deleteMemory(int index) {
    _personal.deleteMemory(index, _prefs);
    notifyListeners();
  }

  void deleteMemoryById(String id) {
    _personal.deleteMemoryById(id, _prefs);
    notifyListeners();
  }

  void setMemoryEnabled(String id, bool value) {
    _personal.setMemoryEnabled(id, value, _prefs);
    notifyListeners();
  }

  void toggleMemoryPinned(String id) {
    _personal.toggleMemoryPinned(id, _prefs);
    notifyListeners();
  }

  void clearMemories() {
    _personal.clearMemories(_prefs);
    notifyListeners();
  }

  void saveWorkCard(WorkCard card) {
    final key = card.id;
    final existingIndex = workCards.indexWhere((item) => item.id == key);
    if (existingIndex >= 0) {
      workCards[existingIndex] = card.copyWith(touch: true);
    } else {
      workCards = [card, ...workCards];
    }
    _prefs?.saveWorkCards(workCards);
    notifyListeners();
  }

  void toggleWorkCardPinned(String id) {
    workCards = [
      for (final card in workCards)
        if (card.id == id)
          card.copyWith(pinned: !card.pinned, touch: true)
        else
          card,
    ];
    _prefs?.saveWorkCards(workCards);
    notifyListeners();
  }

  void deleteWorkCard(String id) {
    workCards = [
      for (final card in workCards)
        if (card.id != id) card,
    ];
    _prefs?.saveWorkCards(workCards);
    notifyListeners();
  }

  void createWorkCardFromMessage(int index) {
    if (index < 0 || index >= messages.length) return;
    final message = messages[index];
    final body = [
      if (message.content.trim().isNotEmpty) message.content.trim(),
      if (message.comparisonResults.isNotEmpty)
        for (final result in message.comparisonResults)
          if (result.content.trim().isNotEmpty)
            '[${result.provider}/${result.model}]\n${result.content.trim()}',
    ].join('\n\n');
    if (body.trim().isEmpty) return;
    final sourceMessageIndex = messages
        .take(index)
        .toList()
        .lastIndexWhere((item) => item.role == 'user');
    final sourceTitle = sourceMessageIndex >= 0
        ? messages[sourceMessageIndex].content.trim()
        : currentSessionTitle;
    final title = body.trim().split(RegExp(r'\r?\n')).first.trim();
    saveWorkCard(
      WorkCard.create(
        title: title.isEmpty ? '未命名作品' : title,
        body: body,
        kind: message.isModelComparison ? 'comparison' : 'text',
        sourceSessionId: currentSessionId ?? '',
        sourceSessionTitle: sourceTitle,
      ),
    );
  }

  void clearTokenUsageRecords() {
    tokenUsageRecords = [];
    _prefs?.saveTokenUsageRecords(tokenUsageRecords);
    notifyListeners();
  }

  void _recordTokenUsage({
    required AiProvider provider,
    required ModelAssignment assignment,
    required List<ChatMessage> promptMessages,
    required String systemInstruction,
    required String outputText,
    required String source,
    String? sessionId,
  }) {
    final promptTokens = _estimateTokensForPrompt(
      promptMessages,
      systemInstruction,
    );
    final completionTokens = _estimateTokensForText(outputText);
    if (promptTokens <= 0 && completionTokens <= 0) return;
    final pricing = tokenPricingFor(provider.name, assignment.model);
    final cost =
        (promptTokens * pricing.inputPerMillionUsd +
            completionTokens * pricing.outputPerMillionUsd) /
        1000000;
    final record = TokenUsageRecord.create(
      provider: provider.name,
      model: assignment.model.trim().isEmpty
          ? provider.models.firstOrNull?.id ?? ''
          : assignment.model,
      source: source,
      sessionId: sessionId ?? currentSessionId ?? '',
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      estimatedCostUsd: cost,
    );
    tokenUsageRecords = [record, ...tokenUsageRecords].take(1000).toList();
    _prefs?.saveTokenUsageRecords(tokenUsageRecords);
  }

  int _estimateTokensForPrompt(
    List<ChatMessage> promptMessages,
    String systemInstruction,
  ) {
    var total = _estimateTokensForText(systemInstruction);
    for (final message in promptMessages) {
      total += 4;
      total += _estimateTokensForText(message.content);
      total += _estimateTokensForText(message.reasoning);
      for (final attachment in message.attachments) {
        total += attachment.isImage ? 85 : 24;
        total += _estimateTokensForText(attachment.name);
      }
    }
    return total;
  }

  int _estimateTokensForText(String value) {
    final text = value.trim();
    if (text.isEmpty) return 0;
    var tokens = 0;
    var asciiRun = 0;

    void flushAscii() {
      if (asciiRun <= 0) return;
      tokens += (asciiRun / 4).ceil();
      asciiRun = 0;
    }

    for (final rune in text.runes) {
      if (_isWhitespaceRune(rune)) {
        flushAscii();
        continue;
      }
      if (_isAsciiRune(rune)) {
        asciiRun++;
        continue;
      }
      flushAscii();
      tokens += _isCjkRune(rune) ? 1 : 2;
    }
    flushAscii();
    return tokens;
  }

  bool _isWhitespaceRune(int rune) =>
      rune == 0x20 || rune == 0x0A || rune == 0x0D || rune == 0x09;

  bool _isAsciiRune(int rune) => rune >= 0x20 && rune <= 0x7E;

  bool _isCjkRune(int rune) =>
      (rune >= 0x3400 && rune <= 0x9FFF) ||
      (rune >= 0xF900 && rune <= 0xFAFF) ||
      (rune >= 0x20000 && rune <= 0x2A6DF);

  Future<void> completeUserProfileWithToolModel() async {
    await _personal.completeUserProfileWithToolModel(
      modelAssignments: modelAssignments,
      providers: providers,
      messages: messages,
      chatSessions: chatSessions,
      prefs: _prefs,
    );
    notifyListeners();
  }

  Future<void> organizeMemoriesWithToolModel() async {
    await _personal.organizeMemoriesWithToolModel(
      modelAssignments: modelAssignments,
      providers: providers,
      messages: messages,
      chatSessions: chatSessions,
      prefs: _prefs,
    );
    notifyListeners();
  }

  Future<void> _refreshPersonalizationFromConversation() async {
    await _personal.refreshPersonalizationFromConversation(
      messages: messages,
      chatSessions: chatSessions,
      modelAssignments: modelAssignments,
      providers: providers,
      prefs: _prefs,
    );
    notifyListeners();
  }

  // ── Session delegation ───────────────────────────────────────────

  void newSession() {
    _sessions.newSession(messages, suggestions);
    _prefs?.saveLastSessionId(null);
    notifyListeners();
  }

  void selectSession(ChatSession session) {
    _sessions.selectSession(session, messages, suggestions);
    _prefs?.saveLastSessionId(currentSessionId);
    notifyListeners();
  }

  void togglePinSession(String sessionId) {
    _sessions.togglePinSession(sessionId, _prefs);
    notifyListeners();
  }

  void deleteSession(String sessionId) {
    _sessions.deleteSession(sessionId, messages, suggestions, _prefs);
    _prefs?.saveLastSessionId(currentSessionId);
    notifyListeners();
  }

  Future<bool> regenerateSessionTitle(String sessionId) async {
    final result = await _sessions.regenerateSessionTitle(
      sessionId,
      modelAssignments: modelAssignments,
      providers: providers,
      prefs: _prefs,
    );
    if (result) notifyListeners();
    return result;
  }

  void createBranchAt(int index) {
    _sessions.createBranchAt(
      index,
      messages: messages,
      suggestions: suggestions,
      prefs: _prefs,
    );
    _prefs?.saveLastSessionId(currentSessionId);
    notifyListeners();
  }

  void deleteMessageAt(int index) {
    _sessions.deleteMessageAt(
      index,
      messages: messages,
      suggestions: suggestions,
      prefs: _prefs,
    );
    _prefs?.saveLastSessionId(currentSessionId);
    notifyListeners();
  }

  void editMessageAt(int index, String content) {
    _sessions.editMessageAt(
      index,
      content,
      messages: messages,
      suggestions: suggestions,
      prefs: _prefs,
    );
    notifyListeners();
  }

  void _persistCurrentSession() {
    _sessions.persistCurrentSession(messages: messages, prefs: _prefs);
    _prefs?.saveLastSessionId(currentSessionId);
  }

  // ── Provider / config delegation ─────────────────────────────────

  void saveProviders(List<AiProvider> next) {
    _providers.saveProviders(next, _prefs);
    notifyListeners();
  }

  void reorderProvider(int oldIndex, int newIndex) {
    _providers.reorderProvider(oldIndex, newIndex, _prefs);
    notifyListeners();
  }

  void upsertProvider(AiProvider provider, {bool makeCurrent = false}) {
    _providers.upsertProvider(
      provider,
      makeCurrent: makeCurrent,
      prefs: _prefs,
    );
    notifyListeners();
  }

  void setProviderEnabled(String name, bool enabled) {
    _providers.setProviderEnabled(name, enabled, _prefs);
    notifyListeners();
  }

  void deleteProvider(String name) {
    _providers.deleteProvider(name, _prefs);
    notifyListeners();
  }

  void saveModelAssignment(String role, ModelAssignment assignment) {
    _providers.saveModelAssignment(role, assignment, _prefs);
    notifyListeners();
  }

  void saveSearchConfig(SearchConfig next) {
    _providers.saveSearchConfig(next, _prefs);
    notifyListeners();
  }

  void saveTtsConfig(List<TtsProviderConfig> providers, String activeId) {
    _providers.saveTtsConfig(providers, activeId, _prefs);
    notifyListeners();
  }

  // ── Chat / streaming ─────────────────────────────────────────────

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
    final taskSessionId = currentSessionId;
    final responseIndex = messages.length - 1;
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
            _mutateModelMessageInSession(
              sessionId: taskSessionId,
              targetIndex: responseIndex,
              persist: false,
              notify: false,
              mutate: (current) {
                current.isThinking =
                    current.content.trim().isEmpty && remoteThinking;
              },
            );
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

          _mutateModelMessageInSession(
            sessionId: taskSessionId,
            targetIndex: responseIndex,
            persist: false,
            notify: false,
            mutate: (current) {
              current.content = targetContent.characters
                  .take(visibleContentChars)
                  .toString();
              current.reasoning = targetReasoning.characters
                  .take(visibleReasoningChars)
                  .toString();
              current.isThinking =
                  current.content.trim().isEmpty &&
                  remoteThinking &&
                  !streamDone;
            },
          );
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
        _mutateModelMessageInSession(
          sessionId: taskSessionId,
          targetIndex: responseIndex,
          persist: true,
          mutate: (current) {
            current.isThinking = false;
          },
        );
        flush(force: true);
        return;
      }
      _recordTokenUsage(
        provider: chatProvider,
        assignment: chatAssignment,
        promptMessages: conversation,
        systemInstruction: prompt,
        outputText: rawTargetContent.trim().isEmpty
            ? '$targetReasoning\n$targetContent'
            : rawTargetContent,
        source: useWebSearch ? 'chat_web' : 'chat',
        sessionId: taskSessionId,
      );
      final imageToolCall = parseImageToolCall(rawTargetContent);
      if (imageToolCall != null) {
        _mutateModelMessageInSession(
          sessionId: taskSessionId,
          targetIndex: responseIndex,
          persist: true,
          mutate: (current) {
            current
              ..content = ''
              ..isThinking = true
              ..activity = 'imageGeneration';
          },
        );
        flush(force: true);
        final requestAttachments = _contextualImageAttachments(
          imageToolCall.prompt,
          const [],
        );
        final prepared = await _prepareImageGenerationRequest(
          imageToolCall.prompt,
          imageAttachments: requestAttachments,
        );
        await _generateImageIntoCurrentResponse(
          prompt: prepared.prompt,
          size: prepared.size,
          aspectRatio: prepared.aspectRatio,
          attachments: requestAttachments,
          runId: runId,
          sessionId: taskSessionId,
          targetIndex: responseIndex,
        );
        return;
      }
      _mutateModelMessageInSession(
        sessionId: taskSessionId,
        targetIndex: responseIndex,
        persist: false,
        mutate: (current) {
          current.isThinking = false;
          if (current.content.trim().isEmpty) {
            current.content = '我在，但这一缕回应没有形成文字。';
          }
        },
      );
      flush(force: true);
      if (runId == _streamRunId) {
        isStreaming = false;
        _persistSessionMessages(taskSessionId);
        notifyListeners();
      }
      if (taskSessionId == currentSessionId) {
        await _refreshCurrentSessionTitle();
        await _refreshSuggestions();
        unawaited(_refreshPersonalizationFromConversation());
      }
    } catch (error) {
      if (runId != _streamRunId || _cancelStreamRequested) {
        _mutateModelMessageInSession(
          sessionId: taskSessionId,
          targetIndex: responseIndex,
          persist: true,
          mutate: (current) {
            current.isThinking = false;
          },
        );
        return;
      }
      _mutateModelMessageInSession(
        sessionId: taskSessionId,
        targetIndex: responseIndex,
        persist: true,
        mutate: (current) {
          current
            ..content =
                '连接织线时出现了问题：${_friendlyAiError(error)}\n\n请检查网络、API Key 或模型配置后重试。'
            ..isThinking = false;
        },
      );
    } finally {
      if (runId == _streamRunId) {
        if (isStreaming) isStreaming = false;
        _cancelStreamRequested = false;
        _persistSessionMessages(taskSessionId);
        notifyListeners();
      }
    }
  }

  Future<void> submitModelComparison(
    String value, {
    List<MessageAttachment> attachments = const [],
    List<ModelAssignment> selectedModels = const [],
  }) async {
    final content = value.trim();
    if ((content.isEmpty && attachments.isEmpty) || isStreaming) return;
    _applyPromptAppearanceIntent(content);

    final availableTargets = _comparisonTargets();
    final targets = <_ComparisonTarget>[];
    if (selectedModels.isEmpty) {
      targets.addAll(availableTargets.take(3));
    } else {
      for (final selected in selectedModels.take(3)) {
        final target = availableTargets.firstWhereOrNull(
          (candidate) =>
              candidate.assignment.provider == selected.provider &&
              candidate.assignment.model == selected.model,
        );
        if (target != null) targets.add(target);
      }
    }
    if (targets.length < 2) {
      messages
        ..add(ChatMessage.user(content, attachments: attachments))
        ..add(
          ChatMessage.model(
            '至少需要配置 2 个可用聊天模型，才能开启多模型对照。请在「设置 > 提供商」中启用模型并配置 API Key。',
          ),
        );
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
      ..add(
        ChatMessage.modelComparison(
          results: [
            for (final target in targets)
              ModelComparisonResult.pending(
                provider: target.provider.name,
                model: target.assignment.model,
              ),
          ],
        ),
      );
    isStreaming = true;
    _cancelStreamRequested = false;
    final runId = ++_streamRunId;
    _persistCurrentSession();
    final taskSessionId = currentSessionId;
    final responseIndex = messages.length - 1;
    notifyListeners();

    final prompt = await _expandedSystemPrompt();
    await Future.wait([
      for (var i = 0; i < targets.length; i++)
        () async {
          final target = targets[i];
          final started = DateTime.now();
          try {
            final raw = await AiGateway.generate(
              messages: conversation,
              systemInstruction: prompt,
              provider: target.provider,
              assignment: target.assignment,
              onThemeUpdate: (_) {},
            );
            if (runId != _streamRunId || _cancelStreamRequested) return;
            final split = splitReasoning(stripImageToolCalls(raw));
            final content = split.answer.trim();
            final reasoning = split.reasoning.trim();
            _recordTokenUsage(
              provider: target.provider,
              assignment: target.assignment,
              promptMessages: conversation,
              systemInstruction: prompt,
              outputText: [
                content,
                reasoning,
              ].where((item) => item.isNotEmpty).join('\n'),
              source: 'comparison',
              sessionId: taskSessionId,
            );
            _replaceComparisonResult(
              sessionId: taskSessionId,
              targetIndex: responseIndex,
              resultIndex: i,
              result: ModelComparisonResult(
                id: ModelComparisonResult.pending(
                  provider: target.provider.name,
                  model: target.assignment.model,
                ).id,
                provider: target.provider.name,
                model: target.assignment.model,
                content: content,
                reasoning: reasoning,
                elapsedMs: DateTime.now().difference(started).inMilliseconds,
              ),
            );
          } catch (error) {
            if (runId != _streamRunId || _cancelStreamRequested) return;
            _replaceComparisonResult(
              sessionId: taskSessionId,
              targetIndex: responseIndex,
              resultIndex: i,
              result: ModelComparisonResult(
                id: ModelComparisonResult.pending(
                  provider: target.provider.name,
                  model: target.assignment.model,
                ).id,
                provider: target.provider.name,
                model: target.assignment.model,
                error: error.toString().replaceFirst('Exception: ', ''),
                elapsedMs: DateTime.now().difference(started).inMilliseconds,
              ),
            );
          }
        }(),
    ]);

    if (runId == _streamRunId) {
      _mutateModelMessageInSession(
        sessionId: taskSessionId,
        targetIndex: responseIndex,
        persist: true,
        mutate: (current) {
          current.isThinking = false;
          current.comparisonResults = [
            for (final result in current.comparisonResults)
              result.copyWith(loading: false),
          ];
        },
      );
      isStreaming = false;
      _cancelStreamRequested = false;
      notifyListeners();
      if (taskSessionId == currentSessionId) {
        await _refreshCurrentSessionTitle();
        await _refreshSuggestions();
        unawaited(_refreshPersonalizationFromConversation());
      }
    }
  }

  Future<void> replaceUserMessageAndSubmit(
    int index,
    String value, {
    List<MessageAttachment> attachments = const [],
    bool useWebSearch = false,
  }) async {
    if (index < 0 ||
        index >= messages.length ||
        messages[index].role != 'user' ||
        isStreaming) {
      return;
    }
    final content = value.trim();
    if (content.isEmpty && attachments.isEmpty) return;
    final preservedAttachments = attachments.isEmpty
        ? messages[index].attachments
              .map((attachment) => attachment.copy())
              .toList()
        : attachments;
    messages.removeRange(index, messages.length);
    await submitMessage(
      content,
      attachments: preservedAttachments,
      useWebSearch: useWebSearch,
    );
  }

  Future<void> submitImageGeneration(
    String value, {
    List<MessageAttachment> attachments = const [],
    int imageCount = 1,
  }) async {
    final content = value.trim();
    if (content.isEmpty || isStreaming) return;
    final requestAttachments = _contextualImageAttachments(
      content,
      attachments,
    );
    final prepared = await _prepareImageGenerationRequest(
      content,
      imageAttachments: requestAttachments,
    );

    messages
      ..add(ChatMessage.user(content, attachments: requestAttachments))
      ..add(
        ChatMessage.model(
          '',
          isThinking: true,
          activity: 'imageGeneration',
          imageCount: imageCount.clamp(1, 4).toInt(),
        ),
      );
    suggestions = [];
    isStreaming = true;
    _cancelStreamRequested = false;
    final runId = ++_streamRunId;
    unawaited(_ensureNativeNotificationPermission());
    _persistCurrentSession();
    final taskSessionId = currentSessionId;
    final responseIndex = messages.length - 1;
    notifyListeners();

    try {
      await _generateImageIntoCurrentResponse(
        prompt: prepared.prompt,
        size: prepared.size,
        aspectRatio: prepared.aspectRatio,
        outputCount: imageCount,
        attachments: requestAttachments,
        runId: runId,
        sessionId: taskSessionId,
        targetIndex: responseIndex,
      );
    } finally {
      if (runId == _streamRunId) {
        isStreaming = false;
        _cancelStreamRequested = false;
        notifyListeners();
      }
    }
  }

  Future<void> replaceUserImageGenerationAndSubmit(
    int index,
    String value, {
    List<MessageAttachment> attachments = const [],
    int imageCount = 1,
  }) async {
    if (index < 0 ||
        index >= messages.length ||
        messages[index].role != 'user' ||
        isStreaming) {
      return;
    }
    final content = value.trim();
    if (content.isEmpty && attachments.isEmpty) return;
    final preservedAttachments = attachments.isEmpty
        ? messages[index].attachments
              .map((attachment) => attachment.copy())
              .toList()
        : attachments;
    messages.removeRange(index, messages.length);
    await submitImageGeneration(
      content,
      attachments: preservedAttachments,
      imageCount: imageCount,
    );
  }

  Future<void> resumeInterruptedImageGeneration({
    bool retryLastFailure = false,
  }) async {
    if (isStreaming || _activeImageGenerationCount > 0 || messages.isEmpty) {
      return;
    }
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
    final attachments = _contextualImageAttachments(
      prompt,
      messages[userIndex].attachments,
      beforeIndex: userIndex,
    );
    final prepared = await _prepareImageGenerationRequest(
      prompt,
      imageAttachments: attachments,
      beforeIndex: userIndex,
    );
    final outputCount = messages[targetIndex].imageCount;

    suggestions = [];
    isStreaming = true;
    _cancelStreamRequested = false;
    final runId = ++_streamRunId;
    _persistCurrentSession();
    final taskSessionId = currentSessionId;
    notifyListeners();

    try {
      await _generateImageIntoCurrentResponse(
        prompt: prepared.prompt,
        size: prepared.size,
        aspectRatio: prepared.aspectRatio,
        outputCount: outputCount,
        attachments: attachments,
        runId: runId,
        sessionId: taskSessionId,
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
    String? aspectRatio,
    int outputCount = 1,
    List<MessageAttachment> attachments = const [],
    required int runId,
    String? sessionId,
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
      _mutateModelMessageInSession(
        sessionId: sessionId,
        targetIndex: targetIndex,
        persist: true,
        mutate: (current) {
          current
            ..content = configIssue
            ..isThinking = false
            ..activity = 'imageGeneration';
        },
      );
      return;
    }

    _activeImageGenerationCount += 1;
    try {
      final result = await AiGateway.generateImages(
        provider: imageProvider!,
        assignment: imageAssignment!,
        prompt: prompt,
        attachments: attachments,
        size: size,
        aspectRatio: aspectRatio,
        outputCount: outputCount,
      );
      if (_cancelledImageRuns.contains(runId)) {
        _mutateModelMessageInSession(
          sessionId: sessionId,
          targetIndex: targetIndex,
          persist: true,
          mutate: (current) {
            current
              ..isThinking = false
              ..activity = 'imageGeneration';
          },
        );
        return;
      }
      final generatedAttachments = <MessageAttachment>[];
      for (final image in result.images) {
        generatedAttachments.add(await _writeGeneratedImageAttachment(image));
      }
      final updated = _mutateModelMessageInSession(
        sessionId: sessionId,
        targetIndex: targetIndex,
        persist: true,
        mutate: (current) {
          current
            ..content = result.isPartial
                ? '已生成 ${generatedAttachments.length}/${result.requestedCount} 张图片；部分请求未完成，可重试补充。'
                : ''
            ..attachments = generatedAttachments
            ..isThinking = false
            ..activity = 'imageGeneration'
            ..imageCount = result.requestedCount;
        },
      );
      if (!updated) return;
      if (sessionId == currentSessionId) {
        await _refreshCurrentSessionTitle();
        unawaited(_refreshPersonalizationFromConversation());
      }
      await _showNativeNotification(
        title: '织境生图完成',
        body: '${generatedAttachments.length} 张图片已生成，回到织境查看结果。',
      );
    } catch (error) {
      if (_cancelledImageRuns.contains(runId)) {
        _mutateModelMessageInSession(
          sessionId: sessionId,
          targetIndex: targetIndex,
          persist: true,
          mutate: (current) {
            current
              ..isThinking = false
              ..activity = 'imageGeneration';
          },
        );
        return;
      }
      if (_backgroundedImageRuns.contains(runId)) {
        _mutateModelMessageInSession(
          sessionId: sessionId,
          targetIndex: targetIndex,
          persist: true,
          mutate: (current) {
            current
              ..content = '后台期间生图被系统中断，回到前台后会继续生成。'
              ..attachments = []
              ..isThinking = true
              ..activity = 'imageGeneration';
          },
        );
        return;
      }
      final updated = _mutateModelMessageInSession(
        sessionId: sessionId,
        targetIndex: targetIndex,
        persist: true,
        mutate: (current) {
          current
            ..content =
                '生图失败：${_friendlyAiError(error, timeout: imageRequestTimeout)}\n\n请确认当前模型支持生图接口，模型能力已标记为 image，并检查 Base URL、证书和 API Key。'
            ..isThinking = false
            ..activity = 'imageGeneration';
        },
      );
      if (!updated) return;
      await _showNativeNotification(
        title: '织境生图失败',
        body: '图片生成未完成，请回到织境查看详情。',
      );
    } finally {
      if (_activeImageGenerationCount > 0) {
        _activeImageGenerationCount -= 1;
      }
      _cancelledImageRuns.remove(runId);
      _backgroundedImageRuns.remove(runId);
    }
  }

  Future<_PreparedImageRequest> _prepareImageGenerationRequest(
    String value, {
    required List<MessageAttachment> imageAttachments,
    int? beforeIndex,
  }) async {
    final basePrompt = value.trim();
    final hasImageAttachments = imageAttachments.any(
      (attachment) => attachment.isImage,
    );
    final contextualPrompt = _contextualImagePrompt(
      basePrompt,
      hasImageAttachments: hasImageAttachments,
      beforeIndex: beforeIndex,
    );
    final promptAspect =
        _imageAspectRatioFromPrompt(contextualPrompt) ??
        _imageAspectRatioFromPrompt(basePrompt);
    final imageAspect = promptAspect == null
        ? await _imageAspectRatioFromAttachments(
            imageAttachments,
            preferLast: _requestsOriginalImageAspect(contextualPrompt),
          )
        : null;
    final aspect = promptAspect ?? imageAspect;
    return _PreparedImageRequest(
      prompt: _imagePromptWithAspectHint(contextualPrompt, aspect),
      size: _imageSizeForAspect(aspect),
      aspectRatio: aspect?.label,
    );
  }

  @visibleForTesting
  Future<Map<String, String>> debugPrepareImageGenerationRequest(
    String value, {
    List<MessageAttachment> attachments = const [],
    int? beforeIndex,
  }) async {
    final requestAttachments = _contextualImageAttachments(
      value,
      attachments,
      beforeIndex: beforeIndex,
    );
    final prepared = await _prepareImageGenerationRequest(
      value,
      imageAttachments: requestAttachments,
      beforeIndex: beforeIndex,
    );
    return {
      'prompt': prepared.prompt,
      'size': prepared.size,
      'attachmentPaths': requestAttachments.map((item) => item.path).join('|'),
    };
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
如果本轮是继续修改上一轮生成图，请把自动附带的上一轮生成图当作待编辑结果，把原始参考图当作构图、主体和宽高比约束。
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
    final reference = _lastUserImageAttachment(beforeIndex: beforeIndex);
    final contextual = [
      if (previous != null) previous.copy(),
      if (reference != null) reference.copy(),
    ];
    final seen = <String>{};
    for (final attachment in contextual) {
      final key = attachment.path.isNotEmpty
          ? attachment.path
          : attachment.name;
      if (seen.add(key)) copied.add(attachment);
    }
    return copied;
  }

  bool _shouldCarryImageContext(
    String prompt,
    bool hasImageAttachments, {
    int? beforeIndex,
  }) {
    if (!hasImageAttachments && !_isImageFollowUpPrompt(prompt)) return false;
    if (!hasImageAttachments &&
        _lastGeneratedImageAttachment(beforeIndex: beforeIndex) == null &&
        _lastUserImageAttachment(beforeIndex: beforeIndex) == null) {
      return false;
    }
    return _isImageFollowUpPrompt(prompt);
  }

  bool _isImageFollowUpPrompt(String prompt) {
    final text = prompt.toLowerCase();
    return text.contains('不要改') ||
        text.contains('不改比例') ||
        text.contains('不要改比例') ||
        text.contains('原比例') ||
        text.contains('原始比例') ||
        text.contains('原图比例') ||
        text.contains('原画幅') ||
        text.contains('原尺寸') ||
        text.contains('原始尺寸') ||
        text.contains('宽高比') ||
        text.contains('比例') ||
        text.contains('画幅') ||
        text.contains('尺寸') ||
        text.contains('分辨率') ||
        text.contains('构图') ||
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
        text.contains('添加') ||
        text.contains('加上') ||
        text.contains('增加') ||
        text.contains('补充') ||
        text.contains('减少') ||
        text.contains('删掉') ||
        text.contains('删除') ||
        text.contains('去掉') ||
        text.contains('移除') ||
        text.contains('擦除') ||
        text.contains('替换') ||
        text.contains('优化') ||
        text.contains('细化') ||
        text.contains('增强') ||
        text.contains('弱化') ||
        text.contains('文字') ||
        text.contains('背景') ||
        text.contains('颜色') ||
        text.contains('人物') ||
        text.contains('主体') ||
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
        text.contains('风格') ||
        text.contains('add') ||
        text.contains('remove') ||
        text.contains('replace') ||
        text.contains('change') ||
        text.contains('edit') ||
        text.contains('modify') ||
        text.contains('keep');
  }

  MessageAttachment? _lastGeneratedImageAttachment({int? beforeIndex}) {
    final end = (beforeIndex ?? messages.length).clamp(0, messages.length);
    for (var i = end - 1; i >= 0; i--) {
      final message = messages[i];
      if (message.role != 'model') continue;
      for (final attachment in message.attachments) {
        if (!attachment.isImage) continue;
        if (attachment.path.isEmpty || !File(attachment.path).existsSync()) {
          continue;
        }
        return attachment;
      }
    }
    return null;
  }

  MessageAttachment? _lastUserImageAttachment({int? beforeIndex}) {
    final end = (beforeIndex ?? messages.length).clamp(0, messages.length);
    for (var i = end - 1; i >= 0; i--) {
      final message = messages[i];
      if (message.role != 'user') continue;
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

  bool _requestsOriginalImageAspect(String prompt) {
    final text = prompt.toLowerCase();
    return text.contains('原比例') ||
        text.contains('原始比例') ||
        text.contains('原图比例') ||
        text.contains('原画幅') ||
        text.contains('原尺寸') ||
        text.contains('原始尺寸') ||
        text.contains('宽高比') ||
        text.contains('不改比例') ||
        text.contains('不要改比例') ||
        text.contains('保持比例') ||
        text.contains('保持原比例');
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

  Future<_ImageAspect?> _imageAspectRatioFromAttachments(
    List<MessageAttachment> attachments, {
    required bool preferLast,
  }) async {
    final images = attachments
        .where(
          (attachment) =>
              attachment.isImage &&
              attachment.path.isNotEmpty &&
              File(attachment.path).existsSync(),
        )
        .toList();
    final ordered = preferLast ? images.reversed : images;
    for (final attachment in ordered) {
      try {
        final bytes = await File(attachment.path).readAsBytes();
        final dimensions = _imageDimensionsFromBytes(bytes);
        if (dimensions == null) continue;
        final (width, height) = dimensions;
        return _ImageAspect(
          label: _aspectLabelFromDimensions(width, height),
          ratio: width / height,
        );
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  (int width, int height)? _imageDimensionsFromBytes(List<int> bytes) {
    if (bytes.length >= 24 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return (_readUint32BigEndian(bytes, 16), _readUint32BigEndian(bytes, 20));
    }

    if (bytes.length >= 10 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      var offset = 2;
      while (offset + 9 < bytes.length) {
        if (bytes[offset] != 0xFF) {
          offset += 1;
          continue;
        }
        final marker = bytes[offset + 1];
        final hasSize =
            marker >= 0xC0 &&
            marker <= 0xCF &&
            marker != 0xC4 &&
            marker != 0xC8 &&
            marker != 0xCC;
        final length = _readUint16BigEndian(bytes, offset + 2);
        if (hasSize && offset + 8 < bytes.length) {
          return (
            _readUint16BigEndian(bytes, offset + 7),
            _readUint16BigEndian(bytes, offset + 5),
          );
        }
        if (length <= 0) break;
        offset += 2 + length;
      }
    }

    if (bytes.length >= 30 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      if (bytes[12] == 0x56 &&
          bytes[13] == 0x50 &&
          bytes[14] == 0x38 &&
          bytes[15] == 0x58 &&
          bytes.length >= 30) {
        final width = 1 + _readUint24LittleEndian(bytes, 24);
        final height = 1 + _readUint24LittleEndian(bytes, 27);
        return (width, height);
      }
      if (bytes[12] == 0x56 &&
          bytes[13] == 0x50 &&
          bytes[14] == 0x38 &&
          bytes[15] == 0x20 &&
          bytes.length >= 30) {
        return (
          _readUint16LittleEndian(bytes, 26) & 0x3FFF,
          _readUint16LittleEndian(bytes, 28) & 0x3FFF,
        );
      }
      if (bytes[12] == 0x56 &&
          bytes[13] == 0x50 &&
          bytes[14] == 0x38 &&
          bytes[15] == 0x4C &&
          bytes.length >= 25) {
        final b0 = bytes[21];
        final b1 = bytes[22];
        final b2 = bytes[23];
        final b3 = bytes[24];
        final width = 1 + (((b1 & 0x3F) << 8) | b0);
        final height = 1 + (((b3 & 0x0F) << 10) | (b2 << 2) | (b1 >> 6));
        return (width, height);
      }
    }

    return null;
  }

  int _readUint16BigEndian(List<int> bytes, int offset) =>
      (bytes[offset] << 8) | bytes[offset + 1];

  int _readUint32BigEndian(List<int> bytes, int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];

  int _readUint16LittleEndian(List<int> bytes, int offset) =>
      bytes[offset] | (bytes[offset + 1] << 8);

  int _readUint24LittleEndian(List<int> bytes, int offset) =>
      bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16);

  String _aspectLabelFromDimensions(int width, int height) {
    final divisor = _greatestCommonDivisor(width, height);
    final ratioWidth = width ~/ divisor;
    final ratioHeight = height ~/ divisor;
    if (ratioWidth <= 64 && ratioHeight <= 64) {
      return '$ratioWidth:$ratioHeight';
    }
    return '${width}x$height';
  }

  int _greatestCommonDivisor(int a, int b) {
    var x = a.abs();
    var y = b.abs();
    while (y != 0) {
      final next = x % y;
      x = y;
      y = next;
    }
    return x == 0 ? 1 : x;
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

  ChatMessage? _modelMessageFrom(List<ChatMessage> source, int? targetIndex) {
    if (targetIndex != null &&
        targetIndex >= 0 &&
        targetIndex < source.length &&
        source[targetIndex].role == 'model') {
      return source[targetIndex];
    }
    if (source.isNotEmpty && source.last.role == 'model') {
      return source.last;
    }
    return null;
  }

  bool _mutateModelMessageInSession({
    required String? sessionId,
    required int? targetIndex,
    required void Function(ChatMessage message) mutate,
    bool persist = false,
    bool notify = true,
  }) {
    if (sessionId == null || sessionId == currentSessionId) {
      final message = _modelMessageFrom(messages, targetIndex);
      if (message == null) return false;
      mutate(message);
      if (persist) _persistCurrentSession();
      if (notify) notifyListeners();
      return true;
    }

    final index = chatSessions.indexWhere((session) => session.id == sessionId);
    if (index < 0) return false;
    final session = chatSessions[index];
    final updatedMessages = session.messages
        .map((message) => message.copy())
        .toList();
    final message = _modelMessageFrom(updatedMessages, targetIndex);
    if (message == null) return false;
    mutate(message);
    chatSessions[index] = session.copyWith(
      updatedAt: persist
          ? DateTime.now().millisecondsSinceEpoch
          : session.updatedAt,
      messages: updatedMessages,
    );
    if (persist) {
      _sessions.sortSessions();
      _prefs?.saveChatSessions(chatSessions);
    }
    if (notify) notifyListeners();
    return true;
  }

  void _replaceComparisonResult({
    required String? sessionId,
    required int? targetIndex,
    required int resultIndex,
    required ModelComparisonResult result,
  }) {
    _mutateModelMessageInSession(
      sessionId: sessionId,
      targetIndex: targetIndex,
      persist: true,
      mutate: (current) {
        if (resultIndex < 0 ||
            resultIndex >= current.comparisonResults.length) {
          return;
        }
        final next = [...current.comparisonResults];
        next[resultIndex] = result;
        current.comparisonResults = next;
        current.isThinking = next.any((item) => item.loading);
      },
    );
  }

  List<_ComparisonTarget> _comparisonTargets() {
    final targets = <_ComparisonTarget>[];
    final seen = <String>{};
    final chatAssignment = modelAssignments['chat'];

    void addTarget(AiProvider provider, AiModel model, {String? prompt}) {
      if (!provider.enabled || provider.apiKey.trim().isEmpty) return;
      if (_looksLikeImageModel(model)) return;
      final modelId = model.id.trim().isEmpty ? model.name : model.id;
      if (modelId.trim().isEmpty) return;
      final key = '${provider.name.toLowerCase()}|${modelId.toLowerCase()}';
      if (!seen.add(key)) return;
      targets.add(
        _ComparisonTarget(
          provider: provider,
          assignment: ModelAssignment(
            provider: provider.name,
            model: modelId,
            prompt: prompt ?? chatAssignment?.prompt ?? '',
          ),
        ),
      );
    }

    if (chatAssignment != null &&
        chatAssignment.provider.trim().isNotEmpty &&
        chatAssignment.model.trim().isNotEmpty) {
      final provider = _providerForAssignment(chatAssignment);
      final model = provider?.models.firstWhereOrNull(
        (item) =>
            item.id == chatAssignment.model ||
            item.name == chatAssignment.model,
      );
      if (provider != null && model != null) {
        addTarget(provider, model, prompt: chatAssignment.prompt);
      }
    }

    final orderedProviders = [
      ...providers.where((provider) => provider.current),
      ...providers.where((provider) => !provider.current),
    ];
    for (final provider in orderedProviders) {
      for (final model in provider.models) {
        addTarget(provider, model);
      }
    }
    return targets;
  }

  List<ModelAssignment> get comparisonModelOptions => [
    for (final target in _comparisonTargets()) target.assignment,
  ];

  bool _looksLikeImageModel(AiModel model) {
    return looksLikeImageGenerationModel(
      id: model.id,
      name: model.name,
      capabilities: model.capabilities,
    );
  }

  void _persistSessionMessages(String? sessionId) {
    if (sessionId == null || sessionId == currentSessionId) {
      _persistCurrentSession();
      return;
    }
    final index = chatSessions.indexWhere((session) => session.id == sessionId);
    if (index < 0) return;
    final session = chatSessions[index];
    chatSessions[index] = session.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      messages: session.messages.map((message) => message.copy()).toList(),
    );
    _sessions.sortSessions();
    _prefs?.saveChatSessions(chatSessions);
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
    _cancelledImageRuns.add(_streamRunId);
    _cancelStreamRequested = true;
    _streamRunId++;
    if (messages.isNotEmpty && messages.last.role == 'model') {
      final current = messages.last;
      current.isThinking = false;
      if (current.isModelComparison) {
        current.comparisonResults = [
          for (final result in current.comparisonResults)
            result.copyWith(loading: false),
        ];
      } else {
        current.activity = '';
      }
      if (current.content.trim().isEmpty && !current.isModelComparison) {
        current.content = '已停止本次回复。';
      }
    }
    isStreaming = false;
    _persistCurrentSession();
    notifyListeners();
  }

  Future<String> _expandedSystemPrompt({String? webQuery}) async {
    var prompt = _personal.expandedSystemPrompt(
      webQuery: null,
      chatSessions: chatSessions,
      searchConfig: searchConfig,
      appearanceDirective: _theme.currentAppearanceDirective(),
    );
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

  Future<void> _refreshCurrentSessionTitle() async {
    final sessionId = currentSessionId;
    if (sessionId == null) return;
    if (messages.where((m) => m.role == 'user').length != 1) return;
    final result = await _sessions.regenerateSessionTitle(
      sessionId,
      modelAssignments: modelAssignments,
      providers: providers,
      prefs: _prefs,
    );
    if (result) notifyListeners();
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
      final input =
          '基于下面这段对话，给出3个用户可能继续追问的简短中文问题。每行一个，不要编号。\n\n${_compactConversation(messages)}';
      final raw = await AiGateway.generateRoleText(
        provider: provider!,
        assignment: assignment,
        input: input,
      ).timeout(roleRequestTimeout);
      _recordTokenUsage(
        provider: provider,
        assignment: assignment,
        promptMessages: [ChatMessage.user(input)],
        systemInstruction: assignment.prompt,
        outputText: raw,
        source: 'suggest',
      );
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
    final name = _uniqueGeneratedImageName(
      directory,
      'weaview_image_${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
    final file = File('${directory.path}${Platform.pathSeparator}$name');
    await file.writeAsBytes(result.bytes, flush: true);
    final dimensions = _imageDimensionsFromBytes(result.bytes);
    return MessageAttachment(
      path: file.path,
      name: name,
      mimeType: result.mimeType,
      kind: 'image',
      size: result.bytes.lengthInBytes,
      pixelWidth: dimensions?.$1,
      pixelHeight: dimensions?.$2,
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
              pixelWidth: attachment.pixelWidth,
              pixelHeight: attachment.pixelHeight,
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

  // ── Retry / translate ────────────────────────────────────────────

  Future<void> retryMessageAt(
    int index, {
    bool useWebSearch = false,
    bool imageGeneration = false,
  }) async {
    if (isStreaming || index < 0 || index >= messages.length) return;
    final retryAsImageGeneration =
        imageGeneration || _looksLikeImageGenerationRetry(index);
    final retryImageCount = _imageGenerationCountForRetry(index);
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
    if (retryAsImageGeneration) {
      await submitImageGeneration(
        original.content,
        attachments: original.attachments.map((item) => item.copy()).toList(),
        imageCount: retryImageCount,
      );
      return;
    }
    await submitMessage(
      original.content,
      attachments: original.attachments.map((item) => item.copy()).toList(),
      useWebSearch: useWebSearch,
    );
  }

  bool _looksLikeImageGenerationRetry(int index) {
    if (index < 0 || index >= messages.length) return false;
    final target = messages[index];
    if (_isImageGenerationReply(target)) return true;
    if (target.role == 'user' && index + 1 < messages.length) {
      final next = messages[index + 1];
      if (next.role == 'model' && _isImageGenerationReply(next)) {
        return true;
      }
    }
    return false;
  }

  int _imageGenerationCountForRetry(int index) {
    if (index < 0 || index >= messages.length) return 1;
    final target = messages[index];
    if (_isImageGenerationReply(target)) return target.imageCount;
    if (target.role == 'user' && index + 1 < messages.length) {
      final reply = messages[index + 1];
      if (_isImageGenerationReply(reply)) return reply.imageCount;
    }
    return 1;
  }

  bool _isImageGenerationReply(ChatMessage message) {
    return message.activity == 'imageGeneration' ||
        message.attachments.any((attachment) => attachment.isImage) ||
        message.content.trim().startsWith('生图失败');
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
    final input = '请将下面文本翻译成流畅自然的中文；如果原文已经是中文，则翻译成英文。\n\n$source';
    final translated = await AiGateway.generateRoleText(
      provider: provider!,
      assignment: assignment!,
      input: input,
    ).timeout(roleRequestTimeout);
    _recordTokenUsage(
      provider: provider,
      assignment: assignment,
      promptMessages: [ChatMessage.user(input)],
      systemInstruction: assignment.prompt,
      outputText: translated,
      source: 'translate',
    );
    messages[index].translation = translated.trim();
    _persistCurrentSession();
    notifyListeners();
  }

  // ── Export / clear ───────────────────────────────────────────────

  String exportJson() {
    return const JsonEncoder.withIndent('  ').convert({
      'chat_sessions': chatSessions.map((s) => s.toJson()).toList(),
      'ai_providers': providers.map((p) => p.safeJson()).toList(),
      'ai_model_assignments': modelAssignments.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'ai_memories': memories,
      'ai_memory_items': memoryItems.map((item) => item.toJson()).toList(),
      'work_cards': workCards.map((item) => item.toJson()).toList(),
      'token_usage_records': tokenUsageRecords
          .map((item) => item.toJson())
          .toList(),
      'ai_search_config': searchConfig.safeJson(),
      'ai_active_tts_id': activeTtsId,
      'ai_tts_providers': ttsProviders.map((p) => p.safeJson()).toList(),
      'system_prompt': systemPrompt,
      'emotion_enabled': emotionEnabled,
      'global_memory_enabled': globalMemoryEnabled,
      'reference_history_enabled': referenceHistoryEnabled,
      'assistant_avatar': assistantAvatar,
      'user_avatar': userAvatar,
      'user_name': userName,
      'assistant_name': assistantName,
      'user_profile': userProfile,
      'theme_mode': themeMode.name,
      'theme_background': _colorToHex(backgroundOverride),
      'theme_text': _colorToHex(textOverride),
      'theme_accent': _colorToHex(accents.first),
      'theme_assistant_bubble': _colorToHex(assistantBubbleOverride),
      'theme_user_bubble': _colorToHex(userBubbleOverride),
      'theme_font_family': fontMood,
      'theme_font_style': fontStyleMood,
      'theme_font_weight': fontWeightMood,
      'theme_bubble_style': bubbleStyle,
      'theme_message_alignment': messageAlignment,
      'theme_assistant_bubble_opacity': assistantBubbleOpacity,
      'theme_user_bubble_opacity': userBubbleOpacity,
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
          'Weaview local data export\nExported at: $exportedAt\nFormat: UTF-8 JSON\nNote: original attachment/image/audio files are not included in this backup.\n',
        ),
      ),
    ]);
  }

  Future<BackupImportResult> importBackupBytes(
    Uint8List bytes, {
    String fileName = '',
  }) async {
    if (bytes.length > maxBackupArchiveBytes) {
      throw FormatException(
        '备份文件超过 ${_formatBackupLimit(maxBackupArchiveBytes)} 限制。',
      );
    }
    final lowerName = fileName.toLowerCase();
    final isZip =
        lowerName.endsWith('.zip') ||
        (bytes.length >= 4 &&
            bytes[0] == 0x50 &&
            bytes[1] == 0x4B &&
            bytes[2] == 0x03 &&
            bytes[3] == 0x04);
    final text = isZip
        ? readZipUtf8Entry(
            bytes,
            'weaview-export.json',
            maxCompressedBytes: maxBackupJsonBytes,
            maxUncompressedBytes: maxBackupJsonBytes,
          )
        : bytes.length > maxBackupJsonBytes
        ? throw FormatException(
            '备份 JSON 超过 ${_formatBackupLimit(maxBackupJsonBytes)} 限制。',
          )
        : utf8.decode(bytes, allowMalformed: true);
    if (text == null || text.trim().isEmpty) {
      throw const FormatException('备份文件中未找到 weaview-export.json。');
    }
    return importBackupJson(text);
  }

  Future<BackupImportResult> importBackupJson(String text) async {
    if (utf8.encode(text).length > maxBackupJsonBytes) {
      throw FormatException(
        '备份 JSON 超过 ${_formatBackupLimit(maxBackupJsonBytes)} 限制。',
      );
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw const FormatException('备份 JSON 格式无效。');
    }
    final data = decoded.cast<String, dynamic>();

    final importedSessions = _decodeImportList(
      data['chat_sessions'],
      ChatSession.fromJson,
    );
    final importedMemoryItems = _decodeMemoryItems(
      data['ai_memory_items'],
      legacy: data['ai_memories'],
    );
    final importedProviders = _decodeImportList(
      data['ai_providers'],
      AiProvider.fromJson,
    );
    final importedWorkCards = _decodeImportList(
      data['work_cards'],
      WorkCard.fromJson,
    );
    final importedTokenUsageRecords = _decodeImportList(
      data['token_usage_records'],
      TokenUsageRecord.fromJson,
    );
    final mergedSessions = _mergeSessions(chatSessions, importedSessions);
    final mergedMemoryItems = _mergeMemoryItems(
      memoryItems,
      importedMemoryItems,
    );
    final mergedProviders = _mergeProviders(providers, importedProviders);
    final mergedWorkCards = _mergeWorkCards(workCards, importedWorkCards);
    final mergedTokenUsageRecords = _mergeTokenUsageRecords(
      tokenUsageRecords,
      importedTokenUsageRecords,
    );

    _sessions.chatSessions
      ..clear()
      ..addAll(mergedSessions);
    memoryItems = mergedMemoryItems;
    workCards = mergedWorkCards;
    tokenUsageRecords = mergedTokenUsageRecords;
    _providers.saveProviders(mergedProviders, _prefs);

    final importedAssignments = _decodeAssignments(
      data['ai_model_assignments'],
    );
    if (importedAssignments.isNotEmpty) {
      modelAssignments = {...modelAssignments, ...importedAssignments};
      _prefs?.saveModelAssignments(modelAssignments);
    }

    final importedSearch = _decodeSearchConfig(data['ai_search_config']);
    if (importedSearch != null) {
      final mergedKeys = _mergeMaskedMap(
        searchConfig.keys,
        importedSearch.keys,
      );
      searchConfig = importedSearch.copyWith(keys: mergedKeys);
      _prefs?.saveSearchConfig(searchConfig);
    }

    final importedTts = _decodeImportList(
      data['ai_tts_providers'],
      TtsProviderConfig.fromJson,
    );
    if (importedTts.isNotEmpty) {
      final mergedTts = _mergeTtsProviders(ttsProviders, importedTts);
      final importedActiveTts = data['ai_active_tts_id']?.toString() ?? '';
      _providers.saveTtsConfig(
        mergedTts,
        importedActiveTts.trim().isEmpty ? activeTtsId : importedActiveTts,
        _prefs,
      );
    }

    _applyImportedPreferences(data);
    final prefs = _prefs;
    if (prefs != null) {
      prefs.saveChatSessions(chatSessions);
      prefs.saveMemoryItems(memoryItems);
      prefs.saveWorkCards(workCards);
      prefs.saveTokenUsageRecords(tokenUsageRecords);
    }
    notifyListeners();

    return BackupImportResult(
      sessions: importedSessions.length,
      memories: importedMemoryItems.length,
      providers: importedProviders.length,
      workCards: importedWorkCards.length,
      tokenUsageRecords: importedTokenUsageRecords.length,
    );
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
    memoryItems = [];
    workCards = [];
    tokenUsageRecords = [];
    searchConfig = const SearchConfig(active: 'tavily', keys: {});
    activeTtsId = '';
    ttsProviders = TtsProviderConfig.defaults();
    themeMode = ThemeMode.system;
    backgroundOverride = null;
    textOverride = null;
    assistantBubbleOverride = null;
    userBubbleOverride = null;
    _theme.accentColor = accentMint;
    fontMood = 'sans';
    fontStyleMood = 'normal';
    fontWeightMood = 'normal';
    bubbleStyle = 'minimal';
    messageAlignment = 'left';
    assistantBubbleOpacity = 0.08;
    userBubbleOpacity = 0.12;
    notifyListeners();
  }

  List<T> _decodeImportList<T>(dynamic value, T Function(dynamic) fromJson) {
    if (value is! List) return const [];
    final items = <T>[];
    for (final item in value) {
      try {
        items.add(fromJson(item));
      } catch (_) {
        continue;
      }
    }
    return items;
  }

  List<MemoryItem> _decodeMemoryItems(dynamic value, {dynamic legacy}) {
    final source = value is List ? value : legacy;
    if (source is! List) return const [];
    final items = <MemoryItem>[];
    for (final item in source) {
      try {
        final decoded = MemoryItem.fromJson(item);
        if (decoded.content.trim().isNotEmpty) items.add(decoded);
      } catch (_) {
        final text = item.toString().trim();
        if (text.isNotEmpty) {
          items.add(MemoryItem.fromText(text, source: '导入记忆'));
        }
      }
    }
    return items;
  }

  Map<String, ModelAssignment> _decodeAssignments(dynamic value) {
    if (value is! Map) return const {};
    final result = <String, ModelAssignment>{};
    for (final entry in value.entries) {
      try {
        result[entry.key.toString()] = ModelAssignment.fromJson(entry.value);
      } catch (_) {
        continue;
      }
    }
    return result;
  }

  SearchConfig? _decodeSearchConfig(dynamic value) {
    if (value == null) return null;
    try {
      return SearchConfig.fromJson(value);
    } catch (_) {
      return null;
    }
  }

  List<ChatSession> _mergeSessions(
    List<ChatSession> current,
    List<ChatSession> imported,
  ) {
    final byId = {for (final session in current) session.id: session};
    for (final session in imported) {
      final existing = byId[session.id];
      if (existing == null || session.updatedAt >= existing.updatedAt) {
        byId[session.id] = session;
      }
    }
    final sessions = byId.values.toList()
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    return sessions;
  }

  List<MemoryItem> _mergeMemoryItems(
    List<MemoryItem> current,
    List<MemoryItem> imported,
  ) {
    final byContent = {
      for (final item in current) item.content.trim().toLowerCase(): item,
    };
    for (final item in imported) {
      final key = item.content.trim().toLowerCase();
      if (key.isEmpty) continue;
      final existing = byContent[key];
      if (existing == null || item.updatedAt >= existing.updatedAt) {
        byContent[key] = item;
      }
    }
    final items = byContent.values.toList()
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    return items;
  }

  List<WorkCard> _mergeWorkCards(
    List<WorkCard> current,
    List<WorkCard> imported,
  ) {
    final byId = {for (final item in current) item.id: item};
    for (final item in imported) {
      if (item.body.trim().isEmpty) continue;
      final existing = byId[item.id];
      if (existing == null || item.updatedAt >= existing.updatedAt) {
        byId[item.id] = item;
      }
    }
    final items = byId.values.toList()
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    return items;
  }

  List<TokenUsageRecord> _mergeTokenUsageRecords(
    List<TokenUsageRecord> current,
    List<TokenUsageRecord> imported,
  ) {
    final byId = {for (final item in current) item.id: item};
    for (final item in imported) {
      if (item.totalTokens <= 0) continue;
      final existing = byId[item.id];
      if (existing == null || item.createdAt >= existing.createdAt) {
        byId[item.id] = item;
      }
    }
    final items = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items.take(1000).toList();
  }

  List<AiProvider> _mergeProviders(
    List<AiProvider> current,
    List<AiProvider> imported,
  ) {
    final byName = {
      for (final provider in current) provider.name.toLowerCase(): provider,
    };
    for (final provider in imported) {
      final key = provider.name.toLowerCase();
      final existing = byName[key];
      if (existing == null) {
        byName[key] = provider.copyWith(
          apiKey: _isMaskedSecret(provider.apiKey) ? '' : provider.apiKey,
          status: provider.enabled
              ? provider.apiKey.isEmpty || _isMaskedSecret(provider.apiKey)
                    ? '未配置'
                    : provider.status
              : '已禁用',
        );
        continue;
      }
      final apiKey =
          provider.apiKey.trim().isEmpty || _isMaskedSecret(provider.apiKey)
          ? existing.apiKey
          : provider.apiKey;
      byName[key] = provider.copyWith(
        apiKey: apiKey,
        baseUrl: provider.baseUrl.trim().isEmpty
            ? existing.baseUrl
            : provider.baseUrl,
        models: provider.models.isEmpty ? existing.models : provider.models,
        current: provider.enabled && provider.current,
        status: !provider.enabled
            ? '已禁用'
            : provider.current
            ? '使用中'
            : apiKey.isEmpty
            ? '未配置'
            : '已连接',
      );
    }
    return byName.values.toList();
  }

  List<TtsProviderConfig> _mergeTtsProviders(
    List<TtsProviderConfig> current,
    List<TtsProviderConfig> imported,
  ) {
    final byId = {for (final provider in current) provider.id: provider};
    for (final provider in imported) {
      final existing = byId[provider.id];
      if (existing == null) {
        byId[provider.id] = provider.copyWith(
          apiKey: _isMaskedSecret(provider.apiKey) ? '' : provider.apiKey,
        );
        continue;
      }
      byId[provider.id] = provider.copyWith(
        apiKey:
            provider.apiKey.trim().isEmpty || _isMaskedSecret(provider.apiKey)
            ? existing.apiKey
            : provider.apiKey,
        baseUrl: provider.baseUrl.trim().isEmpty
            ? existing.baseUrl
            : provider.baseUrl,
        model: provider.model.trim().isEmpty ? existing.model : provider.model,
        voice: provider.voice.trim().isEmpty ? existing.voice : provider.voice,
      );
    }
    return byId.values.toList();
  }

  Map<String, String> _mergeMaskedMap(
    Map<String, String> current,
    Map<String, String> imported,
  ) {
    return {
      ...current,
      for (final entry in imported.entries)
        entry.key: _isMaskedSecret(entry.value) || entry.value.trim().isEmpty
            ? current[entry.key] ?? ''
            : entry.value,
    };
  }

  bool _isMaskedSecret(String value) => value.trim() == '***';

  void _applyImportedPreferences(Map<String, dynamic> data) {
    final importedSystemPrompt = data['system_prompt']?.toString();
    if (importedSystemPrompt != null &&
        importedSystemPrompt.trim().isNotEmpty) {
      systemPrompt = importedSystemPrompt;
      _prefs?.saveSystemPrompt(systemPrompt);
    }
    final importedEmotionEnabled = data['emotion_enabled'];
    if (importedEmotionEnabled is bool) {
      emotionEnabled = importedEmotionEnabled;
      _prefs?.saveEmotionEnabled(emotionEnabled);
    }
    final importedGlobalMemoryEnabled = data['global_memory_enabled'];
    if (importedGlobalMemoryEnabled is bool) {
      globalMemoryEnabled = importedGlobalMemoryEnabled;
      _prefs?.saveGlobalMemoryEnabled(globalMemoryEnabled);
    }
    final importedReferenceHistoryEnabled = data['reference_history_enabled'];
    if (importedReferenceHistoryEnabled is bool) {
      referenceHistoryEnabled = importedReferenceHistoryEnabled;
      _prefs?.saveReferenceHistoryEnabled(referenceHistoryEnabled);
    }
    final importedAssistantAvatar = data['assistant_avatar']?.toString().trim();
    if (importedAssistantAvatar != null) {
      assistantAvatar = importedAssistantAvatar;
      _prefs?.saveAssistantAvatar(assistantAvatar);
    }
    final importedUserAvatar = data['user_avatar']?.toString().trim();
    if (importedUserAvatar != null) {
      userAvatar = importedUserAvatar;
      _prefs?.saveUserAvatar(userAvatar);
    }
    final importedUserName = data['user_name']?.toString().trim();
    if (importedUserName != null && importedUserName.isNotEmpty) {
      userName = importedUserName;
      _prefs?.saveUserName(userName);
    }
    final importedAssistantName = data['assistant_name']?.toString().trim();
    if (importedAssistantName != null && importedAssistantName.isNotEmpty) {
      assistantName = importedAssistantName;
      _prefs?.saveAssistantName(assistantName);
    }
    final importedProfile = data['user_profile']?.toString().trim();
    if (importedProfile != null && importedProfile.isNotEmpty) {
      userProfile = importedProfile;
      _prefs?.saveUserProfile(userProfile);
    }
    final importedThemeMode = data['theme_mode']?.toString().trim();
    if (importedThemeMode != null && importedThemeMode.isNotEmpty) {
      themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.name == importedThemeMode,
        orElse: () => themeMode,
      );
      _prefs?.saveThemeMode(themeMode);
    }
    final importedThemeBackground = _decodeImportedColor(
      data['theme_background'],
    );
    if (importedThemeBackground != null) {
      backgroundOverride = importedThemeBackground;
      _prefs?.saveThemeBackground(importedThemeBackground);
    }
    final importedThemeText = _decodeImportedColor(data['theme_text']);
    if (importedThemeText != null) {
      textOverride = importedThemeText;
      _prefs?.saveThemeText(importedThemeText);
    }
    final importedThemeAccent = _decodeImportedColor(data['theme_accent']);
    if (importedThemeAccent != null) {
      _theme.setAccentColor(importedThemeAccent, _prefs);
    }
    final importedAssistantBubble = _decodeImportedColor(
      data['theme_assistant_bubble'],
    );
    if (importedAssistantBubble != null) {
      assistantBubbleOverride = importedAssistantBubble;
      _prefs?.saveAssistantBubble(importedAssistantBubble);
    }
    final importedUserBubble = _decodeImportedColor(data['theme_user_bubble']);
    if (importedUserBubble != null) {
      userBubbleOverride = importedUserBubble;
      _prefs?.saveUserBubble(importedUserBubble);
    }
    final importedFontFamily = data['theme_font_family']?.toString().trim();
    if (importedFontFamily != null &&
        ['sans', 'serif'].contains(importedFontFamily)) {
      fontMood = importedFontFamily;
      _prefs?.saveFontFamily(fontMood);
    }
    final importedFontStyle = data['theme_font_style']?.toString().trim();
    if (importedFontStyle != null &&
        ['normal', 'italic'].contains(importedFontStyle)) {
      fontStyleMood = importedFontStyle;
      _prefs?.saveFontStyle(fontStyleMood);
    }
    final importedFontWeight = data['theme_font_weight']?.toString().trim();
    if (importedFontWeight != null &&
        ['normal', 'medium', 'bold'].contains(importedFontWeight)) {
      fontWeightMood = importedFontWeight;
      _prefs?.saveFontWeight(fontWeightMood);
    }
    final importedBubbleStyle = data['theme_bubble_style']?.toString().trim();
    if (importedBubbleStyle != null &&
        [
          'minimal',
          'none',
          'glass',
          'solid',
          'outline',
        ].contains(importedBubbleStyle)) {
      bubbleStyle = importedBubbleStyle;
      _prefs?.saveBubbleStyle(bubbleStyle);
    }
    final importedAssistantBubbleOpacity = _decodeImportedOpacity(
      data['theme_assistant_bubble_opacity'],
    );
    if (importedAssistantBubbleOpacity != null) {
      assistantBubbleOpacity = importedAssistantBubbleOpacity;
      _prefs?.saveAssistantBubbleOpacity(assistantBubbleOpacity);
    }
    final importedUserBubbleOpacity = _decodeImportedOpacity(
      data['theme_user_bubble_opacity'],
    );
    if (importedUserBubbleOpacity != null) {
      userBubbleOpacity = importedUserBubbleOpacity;
      _prefs?.saveUserBubbleOpacity(userBubbleOpacity);
    }
    final importedAlignment = data['theme_message_alignment']
        ?.toString()
        .trim();
    if (importedAlignment != null &&
        ['left', 'center', 'right'].contains(importedAlignment)) {
      messageAlignment = importedAlignment;
      _prefs?.saveMessageAlignment(messageAlignment);
    }
  }

  Color? _decodeImportedColor(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return colorFromHex(text);
  }

  double? _decodeImportedOpacity(dynamic value) {
    final parsed = switch (value) {
      num number => number.toDouble(),
      String text => double.tryParse(text),
      _ => null,
    };
    if (parsed == null || parsed.isNaN) return null;
    return parsed.clamp(0.0, 1.0).toDouble();
  }

  String? _colorToHex(Color? color) => color == null ? null : colorToHex(color);

  String _formatBackupLimit(int bytes) {
    final megaBytes = bytes / (1024 * 1024);
    return megaBytes == megaBytes.roundToDouble()
        ? '${megaBytes.toInt()} MB'
        : '${megaBytes.toStringAsFixed(1)} MB';
  }
}
