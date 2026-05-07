import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_utils.dart';
import '../domain/models.dart';
import 'app_constants.dart';

class WeaviewPreferences {
  WeaviewPreferences._(this._prefs);

  final SharedPreferences _prefs;

  static Future<WeaviewPreferences> open() async {
    return WeaviewPreferences._(await SharedPreferences.getInstance());
  }

  String get systemPrompt =>
      _prefs.getString(_PrefsKey.systemPrompt) ?? defaultSystemInstruction;
  bool get emotionEnabled => _prefs.getBool(_PrefsKey.emotionEnabled) ?? true;
  bool get globalMemoryEnabled =>
      _prefs.getBool(_PrefsKey.globalMemoryEnabled) ?? true;
  bool get referenceHistoryEnabled =>
      _prefs.getBool(_PrefsKey.referenceHistoryEnabled) ?? false;
  String get assistantAvatar =>
      _prefs.getString(_PrefsKey.assistantAvatar) ?? '';
  String get userAvatar => _prefs.getString(_PrefsKey.userAvatar) ?? '';
  String get userName => _prefs.getString(_PrefsKey.userName) ?? '织梦者';
  String get assistantName => _prefs.getString(_PrefsKey.assistantName) ?? '织境';
  String get userProfile => _prefs.getString(_PrefsKey.userProfile) ?? '';

  ThemeMode get themeMode =>
      decodeThemeMode(_prefs.getString(_PrefsKey.themeMode));
  Color? get themeBackground =>
      colorFromHex(_prefs.getString(_PrefsKey.themeBackground));
  Color? get themeText => colorFromHex(_prefs.getString(_PrefsKey.themeText));
  Color? get assistantBubble =>
      colorFromHex(_prefs.getString(_PrefsKey.themeAssistantBubble));
  Color? get userBubble =>
      colorFromHex(_prefs.getString(_PrefsKey.themeUserBubble));
  String get fontFamily =>
      _prefs.getString(_PrefsKey.themeFontFamily) ?? 'sans';
  String get fontStyle => enumPref(
    _prefs.getString(_PrefsKey.themeFontStyle),
    const ['normal', 'italic'],
    'normal',
  );
  String get fontWeight => enumPref(
    _prefs.getString(_PrefsKey.themeFontWeight),
    const ['normal', 'medium', 'bold'],
    'normal',
  );
  String get bubbleStyle => enumPref(
    _prefs.getString(_PrefsKey.themeBubbleStyle),
    const ['minimal', 'none', 'glass', 'solid', 'outline'],
    'minimal',
  );
  String get messageAlignment => enumPref(
    _prefs.getString(_PrefsKey.themeMessageAlignment),
    const ['left', 'center', 'right'],
    'left',
  );
  double get assistantBubbleOpacity =>
      _prefs.getDouble(_PrefsKey.themeAssistantBubbleOpacity) ?? 0.08;
  double get userBubbleOpacity =>
      _prefs.getDouble(_PrefsKey.themeUserBubbleOpacity) ?? 0.12;

  List<ChatSession> loadChatSessions() {
    return decodeList(
      _prefs.getString(_PrefsKey.chatSessions),
      ChatSession.fromJson,
    );
  }

  List<AiProvider> loadProviders() {
    return decodeList(
      _prefs.getString(_PrefsKey.aiProviders),
      AiProvider.fromJson,
    );
  }

  Map<String, ModelAssignment>? loadModelAssignments() {
    final assignmentText = _prefs.getString(_PrefsKey.aiModelAssignments);
    if (assignmentText == null) return null;
    try {
      final decoded = jsonDecode(assignmentText) as Map<String, dynamic>;
      return {
        for (final entry in decoded.entries)
          entry.key: ModelAssignment.fromJson(entry.value),
      };
    } catch (_) {
      return null;
    }
  }

  List<String> loadMemories() {
    final savedMemories = _prefs.getString(_PrefsKey.aiMemories);
    if (savedMemories == null) return [];
    try {
      return (jsonDecode(savedMemories) as List)
          .map((item) => item.toString())
          .toList();
    } catch (_) {
      return [];
    }
  }

  SearchConfig? loadSearchConfig() {
    final savedSearch = _prefs.getString(_PrefsKey.aiSearchConfig);
    if (savedSearch == null) return null;
    try {
      return SearchConfig.fromJson(jsonDecode(savedSearch));
    } catch (_) {
      return null;
    }
  }

  String get activeTtsId => _prefs.getString(_PrefsKey.aiActiveTtsId) ?? '';

  List<TtsProviderConfig> loadTtsProviders() {
    return decodeList(
      _prefs.getString(_PrefsKey.aiTtsProviders),
      TtsProviderConfig.fromJson,
    );
  }

  void saveThemeMode(ThemeMode value) {
    _prefs.setString(_PrefsKey.themeMode, value.name);
  }

  void saveThemeBackground(Color value) {
    _prefs.setString(_PrefsKey.themeBackground, colorToHex(value));
  }

  void saveThemeText(Color value) {
    _prefs.setString(_PrefsKey.themeText, colorToHex(value));
  }

  void clearGlobalThemeOverrides() {
    _prefs
      ..remove(_PrefsKey.themeBackground)
      ..remove(_PrefsKey.themeText);
  }

  void saveFontFamily(String value) {
    _prefs.setString(_PrefsKey.themeFontFamily, value);
  }

  void saveAssistantBubble(Color value) {
    _prefs.setString(_PrefsKey.themeAssistantBubble, colorToHex(value));
  }

  void saveUserBubble(Color value) {
    _prefs.setString(_PrefsKey.themeUserBubble, colorToHex(value));
  }

  void saveAssistantBubbleOpacity(double value) {
    _prefs.setDouble(_PrefsKey.themeAssistantBubbleOpacity, value);
  }

  void saveUserBubbleOpacity(double value) {
    _prefs.setDouble(_PrefsKey.themeUserBubbleOpacity, value);
  }

  void saveBubbleStyle(String value) {
    _prefs.setString(_PrefsKey.themeBubbleStyle, value);
  }

  void saveMessageAlignment(String value) {
    _prefs.setString(_PrefsKey.themeMessageAlignment, value);
  }

  void saveFontStyle(String value) {
    _prefs.setString(_PrefsKey.themeFontStyle, value);
  }

  void saveFontWeight(String value) {
    _prefs.setString(_PrefsKey.themeFontWeight, value);
  }

  void resetThemeControls({
    required String fontFamily,
    required String fontStyle,
    required String fontWeight,
    required String bubbleStyle,
    required String messageAlignment,
    required double assistantBubbleOpacity,
    required double userBubbleOpacity,
    required ThemeMode themeMode,
  }) {
    _prefs
      ..remove(_PrefsKey.themeBackground)
      ..remove(_PrefsKey.themeText)
      ..remove(_PrefsKey.themeAssistantBubble)
      ..remove(_PrefsKey.themeUserBubble)
      ..setString(_PrefsKey.themeFontFamily, fontFamily)
      ..setString(_PrefsKey.themeFontStyle, fontStyle)
      ..setString(_PrefsKey.themeFontWeight, fontWeight)
      ..setString(_PrefsKey.themeBubbleStyle, bubbleStyle)
      ..setString(_PrefsKey.themeMessageAlignment, messageAlignment)
      ..setDouble(_PrefsKey.themeAssistantBubbleOpacity, assistantBubbleOpacity)
      ..setDouble(_PrefsKey.themeUserBubbleOpacity, userBubbleOpacity)
      ..setString(_PrefsKey.themeMode, themeMode.name);
  }

  void saveSystemPrompt(String value) {
    _prefs.setString(_PrefsKey.systemPrompt, value);
  }

  void saveUserName(String value) {
    _prefs.setString(_PrefsKey.userName, value);
  }

  void saveAssistantName(String value) {
    _prefs.setString(
      _PrefsKey.assistantName,
      value.trim().isEmpty ? '织境' : value.trim(),
    );
  }

  void saveUserProfile(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _prefs.remove(_PrefsKey.userProfile);
    } else {
      _prefs.setString(_PrefsKey.userProfile, trimmed);
    }
  }

  void saveAssistantAvatar(String value) {
    if (value.isEmpty) {
      _prefs.remove(_PrefsKey.assistantAvatar);
    } else {
      _prefs.setString(_PrefsKey.assistantAvatar, value);
    }
  }

  void saveUserAvatar(String value) {
    if (value.isEmpty) {
      _prefs.remove(_PrefsKey.userAvatar);
    } else {
      _prefs.setString(_PrefsKey.userAvatar, value);
    }
  }

  void saveEmotionEnabled(bool value) {
    _prefs.setBool(_PrefsKey.emotionEnabled, value);
  }

  void saveGlobalMemoryEnabled(bool value) {
    _prefs.setBool(_PrefsKey.globalMemoryEnabled, value);
  }

  void saveReferenceHistoryEnabled(bool value) {
    _prefs.setBool(_PrefsKey.referenceHistoryEnabled, value);
  }

  void saveMemories(List<String> memories) {
    _prefs.setString(_PrefsKey.aiMemories, jsonEncode(memories));
  }

  void saveChatSessions(List<ChatSession> sessions) {
    _prefs.setString(
      _PrefsKey.chatSessions,
      jsonEncode(sessions.map((session) => session.toJson()).toList()),
    );
  }

  void saveProviders(List<AiProvider> providers) {
    _prefs.setString(
      _PrefsKey.aiProviders,
      jsonEncode(providers.map((provider) => provider.toJson()).toList()),
    );
  }

  void saveModelAssignments(Map<String, ModelAssignment> assignments) {
    _prefs.setString(
      _PrefsKey.aiModelAssignments,
      jsonEncode(
        assignments.map((key, value) => MapEntry(key, value.toJson())),
      ),
    );
  }

  void saveSearchConfig(SearchConfig config) {
    _prefs.setString(_PrefsKey.aiSearchConfig, jsonEncode(config.toJson()));
  }

  void saveTtsConfig(List<TtsProviderConfig> providers, String activeId) {
    _prefs
      ..setString(
        _PrefsKey.aiTtsProviders,
        jsonEncode(providers.map((provider) => provider.toJson()).toList()),
      )
      ..setString(_PrefsKey.aiActiveTtsId, activeId);
  }

  Future<void> clear() => _prefs.clear();
}

abstract final class _PrefsKey {
  static const systemPrompt = 'system_prompt';
  static const emotionEnabled = 'emotion_enabled';
  static const globalMemoryEnabled = 'global_memory_enabled';
  static const referenceHistoryEnabled = 'reference_history_enabled';
  static const assistantAvatar = 'assistant_avatar';
  static const userAvatar = 'user_avatar';
  static const userName = 'user_name';
  static const assistantName = 'assistant_name';
  static const userProfile = 'user_profile';
  static const themeMode = 'theme_mode';
  static const themeBackground = 'theme_background';
  static const themeText = 'theme_text';
  static const themeAssistantBubble = 'theme_assistant_bubble';
  static const themeUserBubble = 'theme_user_bubble';
  static const themeFontFamily = 'theme_font_family';
  static const themeFontStyle = 'theme_font_style';
  static const themeFontWeight = 'theme_font_weight';
  static const themeBubbleStyle = 'theme_bubble_style';
  static const themeMessageAlignment = 'theme_message_alignment';
  static const themeAssistantBubbleOpacity = 'theme_assistant_bubble_opacity';
  static const themeUserBubbleOpacity = 'theme_user_bubble_opacity';
  static const chatSessions = 'chat_sessions';
  static const aiProviders = 'ai_providers';
  static const aiModelAssignments = 'ai_model_assignments';
  static const aiMemories = 'ai_memories';
  static const aiSearchConfig = 'ai_search_config';
  static const aiActiveTtsId = 'ai_active_tts_id';
  static const aiTtsProviders = 'ai_tts_providers';
}
