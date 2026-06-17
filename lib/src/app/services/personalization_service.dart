import 'dart:async';
import 'dart:convert';

import '../../data/ai/ai_gateway.dart';
import '../../domain/models.dart';
import '../app_constants.dart';
import '../model_config_resolver.dart';
import '../weaview_preferences.dart';

class PersonalizationService {
  String systemPrompt = defaultSystemInstruction;
  bool emotionEnabled = true;
  bool globalMemoryEnabled = true;
  bool referenceHistoryEnabled = false;
  String assistantAvatar = '';
  String userAvatar = '';
  String userName = '织梦者';
  String assistantName = '织境';
  String userProfile = '';
  List<MemoryItem> memoryItems = [];
  bool profileRefreshInFlight = false;
  int lastProfileRefreshMessageCount = 0;

  bool get hasProfileDetails => _hasProfileDetails();

  List<String> get memories => memoryItems.map((item) => item.content).toList();
  set memories(List<String> values) {
    memoryItems = _memoryItemsFromStrings(values, source: '导入记忆');
  }

  List<MemoryItem> get sortedMemoryItems {
    final items = [...memoryItems];
    items.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return items;
  }

  List<MemoryItem> get activeMemoryItems =>
      sortedMemoryItems.where((item) => item.enabled).toList();

  List<String> get activeMemories =>
      activeMemoryItems.map((item) => item.content).toList();

  void load(WeaviewPreferences prefs) {
    systemPrompt = prefs.systemPrompt;
    emotionEnabled = prefs.emotionEnabled;
    globalMemoryEnabled = prefs.globalMemoryEnabled;
    referenceHistoryEnabled = prefs.referenceHistoryEnabled;
    assistantAvatar = prefs.assistantAvatar;
    userAvatar = prefs.userAvatar;
    userName = prefs.userName;
    assistantName = prefs.assistantName;
    userProfile = prefs.userProfile;
    memoryItems = prefs.loadMemoryItems();
  }

  void updateSystemPrompt(String value, WeaviewPreferences? prefs) {
    systemPrompt = value.isEmpty ? defaultSystemInstruction : value;
    prefs?.saveSystemPrompt(systemPrompt);
  }

  void updateUserName(String value, WeaviewPreferences? prefs) {
    userName = value.trim().isEmpty ? '织梦者' : value.trim();
    prefs?.saveUserName(userName);
    syncUserNameIntoProfile(notify: false, prefs: prefs);
  }

  void updateAssistantName(String value, WeaviewPreferences? prefs) {
    assistantName = value.trim().isEmpty ? '织境' : value.trim();
    prefs?.saveAssistantName(assistantName);
  }

  void updateUserProfile(String value, WeaviewPreferences? prefs) {
    userProfile = value.trim();
    prefs?.saveUserProfile(userProfile);
  }

  void syncUserNameIntoProfile({
    bool notify = true,
    WeaviewPreferences? prefs,
  }) {
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
    prefs?.saveUserProfile(userProfile);
  }

  void updateAssistantAvatar(String value, WeaviewPreferences? prefs) {
    assistantAvatar = value;
    prefs?.saveAssistantAvatar(value);
  }

  void updateUserAvatar(String value, WeaviewPreferences? prefs) {
    userAvatar = value;
    prefs?.saveUserAvatar(value);
  }

  void setEmotionEnabled(bool value, WeaviewPreferences? prefs) {
    emotionEnabled = value;
    prefs?.saveEmotionEnabled(value);
  }

  void setGlobalMemoryEnabled(bool value, WeaviewPreferences? prefs) {
    globalMemoryEnabled = value;
    prefs?.saveGlobalMemoryEnabled(value);
  }

  void setReferenceHistoryEnabled(bool value, WeaviewPreferences? prefs) {
    referenceHistoryEnabled = value;
    prefs?.saveReferenceHistoryEnabled(value);
  }

  void addMemory(String value, WeaviewPreferences? prefs) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    final key = trimmed.toLowerCase();
    final existingIndex = memoryItems.indexWhere(
      (item) => item.content.trim().toLowerCase() == key,
    );
    final nextItem = existingIndex >= 0
        ? memoryItems[existingIndex].copyWith(
            content: trimmed,
            enabled: true,
            source: '手动添加',
            touch: true,
          )
        : MemoryItem.manual(trimmed);
    memoryItems = [
      nextItem,
      for (final item in memoryItems)
        if (item.content.trim().toLowerCase() != key) item,
    ];
    prefs?.saveMemoryItems(memoryItems);
  }

  void deleteMemory(int index, WeaviewPreferences? prefs) {
    final items = sortedMemoryItems;
    if (index < 0 || index >= items.length) return;
    deleteMemoryById(items[index].id, prefs);
  }

  void deleteMemoryById(String id, WeaviewPreferences? prefs) {
    memoryItems = [
      for (final item in memoryItems)
        if (item.id != id) item,
    ];
    prefs?.saveMemoryItems(memoryItems);
  }

  void setMemoryEnabled(String id, bool value, WeaviewPreferences? prefs) {
    memoryItems = [
      for (final item in memoryItems)
        if (item.id == id) item.copyWith(enabled: value, touch: true) else item,
    ];
    prefs?.saveMemoryItems(memoryItems);
  }

  void toggleMemoryPinned(String id, WeaviewPreferences? prefs) {
    memoryItems = [
      for (final item in memoryItems)
        if (item.id == id)
          item.copyWith(pinned: !item.pinned, touch: true)
        else
          item,
    ];
    prefs?.saveMemoryItems(memoryItems);
  }

  void clearMemories(WeaviewPreferences? prefs) {
    memoryItems = [];
    prefs?.saveMemoryItems(memoryItems);
  }

  Future<void> completeUserProfileWithToolModel({
    required Map<String, ModelAssignment> modelAssignments,
    required List<AiProvider> providers,
    required List<ChatMessage> messages,
    required List<ChatSession> chatSessions,
    required WeaviewPreferences? prefs,
  }) async {
    final assignment = modelAssignments['tool'];
    final provider = assignment == null
        ? null
        : ModelConfigResolver.providerForAssignment(providers, assignment);
    final configIssue = ModelConfigResolver.modelConfigIssue(
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
- 不要编造不存在的隐私信息，不确定就写"未明确"。

当前画像：
${userProfile.trim().isEmpty ? '无' : userProfile.trim()}

用户称呼：
${userName.trim().isEmpty ? '未明确' : userName.trim()}

长期记忆：
${_memoryLines(activeMemories)}

最近对话：
${_compactConversation(messages.isNotEmpty ? messages : chatSessions.expand((s) => s.messages).take(20).toList())}
''';
    final result = await AiGateway.generateRoleText(
      provider: provider!,
      assignment: assignment!,
      input: input,
    ).timeout(roleRequestTimeout);
    updateUserProfile(result, prefs);
  }

  Future<void> organizeMemoriesWithToolModel({
    required Map<String, ModelAssignment> modelAssignments,
    required List<AiProvider> providers,
    required List<ChatMessage> messages,
    required List<ChatSession> chatSessions,
    required WeaviewPreferences? prefs,
  }) async {
    final assignment = modelAssignments['tool'];
    final provider = assignment == null
        ? null
        : ModelConfigResolver.providerForAssignment(providers, assignment);
    final configIssue = ModelConfigResolver.modelConfigIssue(
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
${_memoryLines(activeMemories)}

最近对话：
${_compactConversation(messages.isNotEmpty ? messages : chatSessions.expand((s) => s.messages).take(20).toList())}
''';
    final raw = await AiGateway.generateRoleText(
      provider: provider!,
      assignment: assignment!,
      input: input,
    ).timeout(roleRequestTimeout);
    _replaceActiveMemories(_decodeMemoryList(raw), source: 'AI 整理');
    prefs?.saveMemoryItems(memoryItems);
  }

  Future<void> refreshMemoryFromConversation({
    required List<ChatMessage> messages,
    required Map<String, ModelAssignment> modelAssignments,
    required List<AiProvider> providers,
    required WeaviewPreferences? prefs,
  }) async {
    if (!globalMemoryEnabled || messages.length < 4) return;
    final assignment = modelAssignments['tool'];
    final provider = assignment == null
        ? null
        : ModelConfigResolver.providerForAssignment(providers, assignment);
    if (ModelConfigResolver.modelConfigIssue(
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
${_memoryLines(activeMemories)}

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
      _replaceActiveMemories(next, source: '对话整理');
      prefs?.saveMemoryItems(memoryItems);
    } catch (_) {}
  }

  Future<void> refreshUserProfileFromConversation({
    required List<ChatMessage> messages,
    required List<ChatSession> chatSessions,
    required Map<String, ModelAssignment> modelAssignments,
    required List<AiProvider> providers,
    required WeaviewPreferences? prefs,
    bool force = false,
  }) async {
    if (profileRefreshInFlight) return;
    final source = _personalizationSourceMessages(messages, chatSessions);
    final hasUserSignal = source.any(
      (m) =>
          m.role == 'user' &&
          (m.content.trim().isNotEmpty || m.attachments.isNotEmpty),
    );
    if (!hasUserSignal) return;
    final hasProfileDetails = _hasProfileDetails();
    if (!force) {
      final messageDelta = messages.length - lastProfileRefreshMessageCount;
      if (hasProfileDetails && messageDelta < 6) return;
      if (!hasProfileDetails && messages.length < 2) return;
    }

    final assignment = modelAssignments['tool'];
    final provider = assignment == null
        ? null
        : ModelConfigResolver.providerForAssignment(providers, assignment);
    if (ModelConfigResolver.modelConfigIssue(
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
- 合并当前画像和长期记忆，不要重复；不要编造隐私，不确定就写"未明确"。
- 如果画像为空，也必须基于用户称呼和已有对话生成初始画像。

用户称呼：
${userName.trim().isEmpty ? '未明确' : userName.trim()}

当前人物画像：
${userProfile.trim().isEmpty ? '无' : userProfile.trim()}

长期记忆：
${_memoryLines(activeMemories)}

最新对话：
${_compactConversation(source)}
''';

    profileRefreshInFlight = true;
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
        syncUserNameIntoProfile(notify: false, prefs: prefs);
        prefs?.saveUserProfile(userProfile);
      }
      lastProfileRefreshMessageCount = messages.length;
    } catch (_) {
    } finally {
      profileRefreshInFlight = false;
    }
  }

  Future<void> refreshPersonalizationFromConversation({
    required List<ChatMessage> messages,
    required List<ChatSession> chatSessions,
    required Map<String, ModelAssignment> modelAssignments,
    required List<AiProvider> providers,
    required WeaviewPreferences? prefs,
  }) async {
    await refreshMemoryFromConversation(
      messages: messages,
      modelAssignments: modelAssignments,
      providers: providers,
      prefs: prefs,
    );
    await refreshUserProfileFromConversation(
      messages: messages,
      chatSessions: chatSessions,
      modelAssignments: modelAssignments,
      providers: providers,
      prefs: prefs,
    );
  }

  String expandedSystemPrompt({
    String? webQuery,
    required List<ChatSession> chatSessions,
    required SearchConfig searchConfig,
    required String appearanceDirective,
  }) {
    var prompt = systemPrompt;
    if (emotionEnabled) {
      prompt +=
          '\n\n[System directive: Emotion and poetry mode is ENABLED. Your responses should be highly emotional, vivid, and deeply artistic. Do not just output plain facts.]';
    }
    prompt += appearanceDirective;
    if (globalMemoryEnabled && activeMemories.isNotEmpty) {
      prompt +=
          '\n\n[System directive: You have the following memories about the user:\n${activeMemories.map((m) => '- $m').join('\n')}\nPlease take them into account when responding.]';
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
    return prompt;
  }

  List<MemoryItem> _memoryItemsFromStrings(
    Iterable<String> values, {
    required String source,
  }) {
    final seen = <String>{};
    return [
      for (final value in values)
        if (value.trim().isNotEmpty && seen.add(value.trim().toLowerCase()))
          MemoryItem.fromText(value, source: source),
    ];
  }

  void _replaceActiveMemories(List<String> values, {required String source}) {
    final existingByContent = {
      for (final item in memoryItems) item.content.trim().toLowerCase(): item,
    };
    final seen = <String>{};
    final nextActive = <MemoryItem>[];
    for (final value in values) {
      final trimmed = value.trim();
      final key = trimmed.toLowerCase();
      if (trimmed.isEmpty || !seen.add(key)) continue;
      final existing = existingByContent[key];
      nextActive.add(
        (existing ?? MemoryItem.fromText(trimmed, source: source)).copyWith(
          content: trimmed,
          source: existing?.source ?? source,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
    final disabled = memoryItems.where(
      (item) => !item.enabled && !seen.contains(item.content.toLowerCase()),
    );
    memoryItems = [...nextActive.take(12), ...disabled];
  }

  String _memoryLines(List<String> values) {
    if (values.isEmpty) return '无';
    return values.map((m) => '- $m').join('\n');
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
    return _takeRunes(text, 260).trim();
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

  List<ChatMessage> _personalizationSourceMessages(
    List<ChatMessage> messages,
    List<ChatSession> chatSessions,
  ) {
    if (messages.isNotEmpty) return messages;
    return chatSessions.expand((session) => session.messages).take(24).toList();
  }

  String _compactConversation(List<ChatMessage> source) {
    final text = source
        .where((m) => m.content.trim().isNotEmpty)
        .map((m) => '${m.role == 'user' ? '用户' : '助手'}：${m.content.trim()}')
        .join('\n');
    return _takeRunes(text, 4000);
  }

  String _takeRunes(String text, int maxLength) {
    return String.fromCharCodes(text.runes.take(maxLength));
  }
}
