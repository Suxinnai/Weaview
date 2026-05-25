import '../../core/app_utils.dart';
import '../../data/ai/ai_gateway.dart';
import '../../domain/models.dart';
import '../model_config_resolver.dart';
import '../weaview_preferences.dart';

class SessionManager {
  final List<ChatSession> chatSessions = [];
  String? currentSessionId;

  void load(List<ChatSession> savedSessions) {
    chatSessions
      ..clear()
      ..addAll(savedSessions);
    sortSessions();
  }

  void newSession(List<ChatMessage> messages, List<String> suggestions) {
    messages.clear();
    suggestions.clear();
    currentSessionId = null;
  }

  void selectSession(
    ChatSession session,
    List<ChatMessage> messages,
    List<String> suggestions,
  ) {
    messages
      ..clear()
      ..addAll(session.messages.map((m) => m.copy()));
    suggestions.clear();
    currentSessionId = session.id;
  }

  void togglePinSession(String sessionId, WeaviewPreferences? prefs) {
    final index = chatSessions.indexWhere((session) => session.id == sessionId);
    if (index < 0) return;
    chatSessions[index] = chatSessions[index].copyWith(
      pinned: !chatSessions[index].pinned,
    );
    sortSessions();
    prefs?.saveChatSessions(chatSessions);
  }

  void deleteSession(
    String sessionId,
    List<ChatMessage> messages,
    List<String> suggestions,
    WeaviewPreferences? prefs,
  ) {
    chatSessions.removeWhere((session) => session.id == sessionId);
    if (currentSessionId == sessionId) {
      currentSessionId = null;
      messages.clear();
      suggestions.clear();
    }
    prefs?.saveChatSessions(chatSessions);
  }

  Future<bool> regenerateSessionTitle(
    String sessionId, {
    required Map<String, ModelAssignment> modelAssignments,
    required List<AiProvider> providers,
    required WeaviewPreferences? prefs,
  }) async {
    final index = chatSessions.indexWhere((session) => session.id == sessionId);
    if (index < 0) return false;
    final session = chatSessions[index];
    final title = await _generateTitleForMessages(
      session.messages,
      modelAssignments: modelAssignments,
      providers: providers,
    );
    if (title == null || title.isEmpty) return false;
    chatSessions[index] = session.copyWith(title: title);
    sortSessions();
    prefs?.saveChatSessions(chatSessions);
    return true;
  }

  void createBranchAt(
    int index, {
    required List<ChatMessage> messages,
    required List<String> suggestions,
    required WeaviewPreferences? prefs,
  }) {
    if (index < 0 || index >= messages.length) return;
    final branchMessages = messages
        .take(index + 1)
        .map((m) => m.copy())
        .toList();
    if (branchMessages.isEmpty) return;
    final sourceTitle =
        chatSessions
            .firstWhereOrNull((s) => s.id == currentSessionId)
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
    suggestions.clear();
    persistCurrentSession(messages: messages, prefs: prefs);
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
      prefs?.saveChatSessions(chatSessions);
    }
  }

  void deleteMessageAt(
    int index, {
    required List<ChatMessage> messages,
    required List<String> suggestions,
    required WeaviewPreferences? prefs,
  }) {
    if (index < 0 || index >= messages.length) return;
    messages.removeAt(index);
    suggestions.clear();
    if (messages.isEmpty) {
      if (currentSessionId != null) {
        chatSessions.removeWhere((s) => s.id == currentSessionId);
        prefs?.saveChatSessions(chatSessions);
      }
      currentSessionId = null;
    } else {
      persistCurrentSession(messages: messages, prefs: prefs);
    }
  }

  void editMessageAt(
    int index,
    String content, {
    required List<ChatMessage> messages,
    required List<String> suggestions,
    required WeaviewPreferences? prefs,
  }) {
    if (index < 0 || index >= messages.length) return;
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    messages[index].content = trimmed;
    suggestions.clear();
    persistCurrentSession(messages: messages, prefs: prefs);
  }

  void persistCurrentSession({
    required List<ChatMessage> messages,
    required WeaviewPreferences? prefs,
  }) {
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
    if (index >= 0) chatSessions.removeAt(index);
    chatSessions.insert(0, session);
    sortSessions();
    prefs?.saveChatSessions(chatSessions);
  }

  void sortSessions() {
    chatSessions.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
  }

  Future<void> refreshCurrentSessionTitle({
    required List<ChatMessage> messages,
    required Map<String, ModelAssignment> modelAssignments,
    required List<AiProvider> providers,
    required WeaviewPreferences? prefs,
  }) async {
    final sessionId = currentSessionId;
    if (sessionId == null) return;
    if (messages.where((m) => m.role == 'user').length != 1) return;
    final title = await _generateTitleForMessages(
      messages,
      modelAssignments: modelAssignments,
      providers: providers,
    );
    if (title == null || title.isEmpty) return;
    _renameSession(sessionId, title, prefs: prefs);
  }

  Future<String?> _generateTitleForMessages(
    List<ChatMessage> source, {
    required Map<String, ModelAssignment> modelAssignments,
    required List<AiProvider> providers,
  }) async {
    final assignment = modelAssignments['title'];
    if (assignment == null) return null;
    final provider = ModelConfigResolver.providerForAssignment(
      providers,
      assignment,
    );
    if (ModelConfigResolver.modelConfigIssue(
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
          .replaceAll(RegExp(r'[""「」#：:]'), '')
          .trim()
          .split('\n')
          .first
          .trim();
      if (cleaned.isEmpty) return null;
      return _takeRunes(cleaned, 16);
    } catch (_) {
      return null;
    }
  }

  void _renameSession(
    String sessionId,
    String title, {
    WeaviewPreferences? prefs,
  }) {
    final index = chatSessions.indexWhere((s) => s.id == sessionId);
    if (index < 0) return;
    chatSessions[index] = chatSessions[index].copyWith(title: title);
    sortSessions();
    prefs?.saveChatSessions(chatSessions);
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
