import 'package:flutter/foundation.dart';

import '../../core/app_utils.dart' as app_utils;
import '../../domain/models.dart';
import '../search/tavily_search_client.dart';
import 'ai_response_parsers.dart';
import 'gemini_client.dart';
import 'openai_compatible_client.dart';
import 'openai_stream_parser.dart' as openai_stream_parser;

typedef AiStreamSnapshotHandler =
    void Function(String content, String reasoning, bool thinking);

const searchRequestTimeout = Duration(seconds: 30);
const chatRequestTimeout = Duration(seconds: 180);
const roleRequestTimeout = Duration(seconds: 75);
const modelFetchTimeout = Duration(seconds: 45);

class AiGateway {
  static const _geminiClient = GeminiClient();
  static const _openAiClient = OpenAiCompatibleClient();

  static Future<String> generate({
    required List<ChatMessage> messages,
    required String systemInstruction,
    required AiProvider provider,
    required ModelAssignment assignment,
    required ValueChanged<Map<String, dynamic>> onThemeUpdate,
  }) async {
    final providerName = assignment.provider.isNotEmpty
        ? assignment.provider
        : provider.name;
    if (_isGeminiProvider(providerName)) {
      if (provider.apiKey.isEmpty) {
        return '请先在「设置 > 提供商 > Gemini」中配置 Gemini API Key。';
      }
      return _geminiClient.generate(
        apiKey: provider.apiKey,
        model: _geminiModelId(assignment, provider),
        messages: messages,
        systemInstruction: systemInstruction,
        onThemeUpdate: onThemeUpdate,
        timeout: chatRequestTimeout,
      );
    }

    final apiKey = provider.apiKey;
    if (apiKey.isEmpty) {
      return '请先在「设置 > 提供商」中为 ${provider.name} 配置 API Key。';
    }
    return _openAiClient.generate(
      apiKey: apiKey,
      baseUrl: _effectiveOpenAiBaseUrl(provider),
      model: _providerModelId(assignment, provider),
      messages: messages,
      systemInstruction: systemInstruction,
      onThemeUpdate: onThemeUpdate,
      timeout: chatRequestTimeout,
    );
  }

  static Future<void> generateStream({
    required List<ChatMessage> messages,
    required String systemInstruction,
    required AiProvider provider,
    required ModelAssignment assignment,
    required ValueChanged<Map<String, dynamic>> onThemeUpdate,
    required AiStreamSnapshotHandler onSnapshot,
    bool Function()? shouldCancel,
  }) async {
    final providerName = assignment.provider.isNotEmpty
        ? assignment.provider
        : provider.name;
    if (_isGeminiProvider(providerName)) {
      final text = await generate(
        messages: messages,
        systemInstruction: systemInstruction,
        provider: provider,
        assignment: assignment,
        onThemeUpdate: onThemeUpdate,
      );
      if (shouldCancel?.call() == true) return;
      final parsed = splitReasoning(text);
      onSnapshot(parsed.answer, parsed.reasoning, false);
      return;
    }

    final apiKey = provider.apiKey;
    if (apiKey.isEmpty) {
      throw Exception('请先在「设置 > 提供商」中为 ${provider.name} 配置 API Key。');
    }
    await _openAiClient.generateStream(
      apiKey: apiKey,
      baseUrl: _effectiveOpenAiBaseUrl(provider),
      model: _providerModelId(assignment, provider),
      messages: messages,
      systemInstruction: systemInstruction,
      onThemeUpdate: onThemeUpdate,
      onSnapshot: onSnapshot,
      shouldCancel: shouldCancel,
      timeout: chatRequestTimeout,
    );
  }

  static Future<String> searchWeb({
    required SearchConfig config,
    required String query,
  }) async {
    return const TavilySearchClient().search(
      config: config,
      query: query,
      timeout: searchRequestTimeout,
    );
  }

  static Future<String> generateRoleText({
    required AiProvider provider,
    required ModelAssignment assignment,
    required String input,
  }) async {
    final text = await generate(
      messages: [ChatMessage.user(input)],
      systemInstruction: assignment.prompt,
      provider: provider,
      assignment: assignment,
      onThemeUpdate: (_) {},
    );
    return splitReasoning(text).answer.trim();
  }

  static Future<List<AiModel>> fetchModels({
    required String apiKey,
    required String baseUrl,
  }) async {
    return _openAiClient.fetchModels(
      apiKey: apiKey,
      baseUrl: baseUrl,
      timeout: modelFetchTimeout,
    );
  }

  static Future<String> testConnection({
    required String apiKey,
    required String baseUrl,
    required String model,
  }) async {
    return _openAiClient.testConnection(
      apiKey: apiKey,
      baseUrl: baseUrl,
      model: model,
      timeout: roleRequestTimeout,
    );
  }

  static String _geminiModelId(
    ModelAssignment assignment,
    AiProvider provider,
  ) {
    if (assignment.model.isNotEmpty) {
      final matched = provider.models.firstWhereOrNull(
        (m) => m.name == assignment.model || m.id == assignment.model,
      );
      if (matched != null) return matched.id;
    }
    return 'gemini-2.5-pro';
  }

  static String _providerModelId(
    ModelAssignment assignment,
    AiProvider provider,
  ) {
    if (assignment.model.isNotEmpty) {
      final matched = provider.models.firstWhereOrNull(
        (m) => m.name == assignment.model || m.id == assignment.model,
      );
      return matched?.id ?? assignment.model;
    }
    return provider.models.isNotEmpty
        ? provider.models.first.id
        : 'gpt-4o-mini';
  }

  static ({String contentDelta, String reasoningDelta}) parseOpenAiStreamData(
    String data,
  ) {
    return openai_stream_parser.parseOpenAiStreamData(data);
  }

  static String normalizeBaseUrl(String value) {
    return app_utils.normalizeBaseUrl(value);
  }

  static bool _isGeminiProvider(String providerName) {
    return providerName.toLowerCase().contains('gemini');
  }

  static String _effectiveOpenAiBaseUrl(AiProvider provider) {
    return provider.baseUrl.isEmpty
        ? 'https://api.openai.com/v1'
        : provider.baseUrl;
  }
}
