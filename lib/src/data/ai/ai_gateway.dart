import 'package:flutter/foundation.dart';

import '../../core/app_utils.dart' as app_utils;
import '../../domain/models.dart';
import '../search/tavily_search_client.dart';
import 'ai_response_parsers.dart';
import 'anthropic_client.dart';
import 'gemini_client.dart';
import 'image_prompt_guard.dart';
import 'openai_compatible_client.dart';
import 'openai_stream_parser.dart' as openai_stream_parser;
import 'tts_client.dart';

typedef AiStreamSnapshotHandler =
    void Function(String content, String reasoning, bool thinking);

const searchRequestTimeout = Duration(seconds: 30);
const chatRequestTimeout = Duration(seconds: 180);
const roleRequestTimeout = Duration(seconds: 75);
const modelFetchTimeout = Duration(seconds: 45);
const imageRequestTimeout = Duration(seconds: 300);
const ttsRequestTimeout = Duration(seconds: 75);

enum _ProviderType { gemini, anthropic, openAi }

class _ResolvedRoute {
  const _ResolvedRoute({
    required this.type,
    required this.provider,
    required this.assignment,
    required this.apiKey,
    required this.baseUrl,
    required this.modelId,
  });

  final _ProviderType type;
  final AiProvider provider;
  final ModelAssignment assignment;
  final String apiKey;
  final String baseUrl;
  final String modelId;
}

class AiGateway {
  static const _geminiClient = GeminiClient();
  static const _openAiClient = OpenAiCompatibleClient();
  static const _anthropicClient = AnthropicClient();
  static const _ttsClient = TtsClient();

  // ── Routing helpers ────────────────────────────────────────────

  static _ResolvedRoute _resolveRoute({
    required AiProvider provider,
    required ModelAssignment assignment,
  }) {
    final providerName =
        assignment.provider.isNotEmpty ? assignment.provider : provider.name;
    if (_isGeminiProvider(providerName)) {
      return _ResolvedRoute(
        type: _ProviderType.gemini,
        provider: provider,
        assignment: assignment,
        apiKey: provider.apiKey,
        baseUrl: '',
        modelId: _geminiModelId(assignment, provider),
      );
    }
    if (_isAnthropicProvider(providerName)) {
      return _ResolvedRoute(
        type: _ProviderType.anthropic,
        provider: provider,
        assignment: assignment,
        apiKey: provider.apiKey,
        baseUrl: _effectiveAnthropicBaseUrl(provider),
        modelId: _providerModelId(assignment, provider),
      );
    }
    return _ResolvedRoute(
      type: _ProviderType.openAi,
      provider: provider,
      assignment: assignment,
      apiKey: provider.apiKey,
      baseUrl: _effectiveOpenAiBaseUrl(provider),
      modelId: _providerModelId(assignment, provider),
    );
  }

  static void _assertApiKey(_ResolvedRoute route) {
    if (route.apiKey.isEmpty) {
      final label = switch (route.type) {
        _ProviderType.gemini => 'Gemini',
        _ProviderType.anthropic => 'Anthropic',
        _ProviderType.openAi => route.provider.name,
      };
      throw Exception('请先在「设置 > 提供商」中为 $label 配置 API Key。');
    }
  }

  // ── Chat ──────────────────────────────────────────────────────

  static Future<String> generate({
    required List<ChatMessage> messages,
    required String systemInstruction,
    required AiProvider provider,
    required ModelAssignment assignment,
    required ValueChanged<Map<String, dynamic>> onThemeUpdate,
  }) async {
    final route = _resolveRoute(provider: provider, assignment: assignment);

    if (route.type == _ProviderType.gemini && route.apiKey.isEmpty) {
      return '请先在「设置 > 提供商 > Gemini」中配置 Gemini API Key。';
    }
    _assertApiKey(route);

    return switch (route.type) {
      _ProviderType.gemini => _geminiClient.generate(
        apiKey: route.apiKey,
        model: route.modelId,
        messages: messages,
        systemInstruction: systemInstruction,
        onThemeUpdate: onThemeUpdate,
        timeout: chatRequestTimeout,
      ),
      _ProviderType.anthropic => _anthropicClient.generate(
        apiKey: route.apiKey,
        baseUrl: route.baseUrl,
        model: route.modelId,
        messages: messages,
        systemInstruction: systemInstruction,
        onThemeUpdate: onThemeUpdate,
        timeout: chatRequestTimeout,
      ),
      _ProviderType.openAi => _openAiClient.generate(
        apiKey: route.apiKey,
        baseUrl: route.baseUrl,
        model: route.modelId,
        messages: messages,
        systemInstruction: systemInstruction,
        onThemeUpdate: onThemeUpdate,
        timeout: chatRequestTimeout,
      ),
    };
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
    final route = _resolveRoute(provider: provider, assignment: assignment);

    if (route.type == _ProviderType.gemini) {
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

    _assertApiKey(route);

    if (route.type == _ProviderType.anthropic) {
      await _anthropicClient.generateStream(
        apiKey: route.apiKey,
        baseUrl: route.baseUrl,
        model: route.modelId,
        messages: messages,
        systemInstruction: systemInstruction,
        onThemeUpdate: onThemeUpdate,
        onSnapshot: onSnapshot,
        shouldCancel: shouldCancel,
        timeout: chatRequestTimeout,
      );
      return;
    }

    await _openAiClient.generateStream(
      apiKey: route.apiKey,
      baseUrl: route.baseUrl,
      model: route.modelId,
      messages: messages,
      systemInstruction: systemInstruction,
      onThemeUpdate: onThemeUpdate,
      onSnapshot: onSnapshot,
      shouldCancel: shouldCancel,
      timeout: chatRequestTimeout,
    );
  }

  // ── Role text / search ────────────────────────────────────────

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

  // ── Image ─────────────────────────────────────────────────────

  static Future<GeneratedImageResult> generateImage({
    required AiProvider provider,
    required ModelAssignment assignment,
    required String prompt,
    List<MessageAttachment> attachments = const [],
    String size = '1024x1024',
  }) async {
    final route = _resolveRoute(provider: provider, assignment: assignment);
    _assertApiKey(route);

    final guardedPrompt = imagePromptWithDefaultQualityGuard(prompt);
    if (_shouldUseNativeGeminiImage(route)) {
      return _geminiClient.generateImage(
        apiKey: route.apiKey,
        baseUrl: provider.baseUrl,
        model: route.modelId,
        prompt: guardedPrompt,
        attachments: attachments,
        timeout: imageRequestTimeout,
      );
    }
    return _openAiClient.generateImage(
      apiKey: route.apiKey,
      baseUrl: route.baseUrl,
      prompt: guardedPrompt,
      attachments: attachments,
      responseModel: _responseModelForImageTool(route.modelId),
      imageModel: route.modelId,
      timeout: imageRequestTimeout,
      size: size,
    );
  }

  // ── Model fetch / test ────────────────────────────────────────

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
    Iterable<String> capabilities = const [],
  }) async {
    if (looksLikeImageGenerationModel(
      id: model,
      name: model,
      capabilities: capabilities,
    )) {
      return _openAiClient.testImageConnection(
        apiKey: apiKey,
        baseUrl: baseUrl,
        imageModel: model,
        responseModel: _responseModelForImageTool(model),
        timeout: imageRequestTimeout,
      );
    }
    return _openAiClient.testConnection(
      apiKey: apiKey,
      baseUrl: baseUrl,
      model: model,
      timeout: roleRequestTimeout,
    );
  }

  // ── TTS ───────────────────────────────────────────────────────

  static Future<TtsAudioResult> synthesizeSpeech({
    required TtsProviderConfig config,
    required String text,
  }) {
    return _ttsClient.synthesize(
      config: config,
      text: text,
      timeout: ttsRequestTimeout,
    );
  }

  static Future<void> streamSpeechPcm16({
    required TtsProviderConfig config,
    required String text,
    required Pcm16ChunkHandler onChunk,
  }) {
    return _ttsClient.streamPcm16(
      config: config,
      text: text,
      timeout: ttsRequestTimeout,
      onChunk: onChunk,
    );
  }

  // ── Internal helpers ──────────────────────────────────────────

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

  static bool _isAnthropicProvider(String providerName) {
    return providerName.toLowerCase().contains('anthropic') ||
        providerName.toLowerCase().contains('claude');
  }

  static String _responseModelForImageTool(String imageModel) {
    return shouldUseResponsesImageTool(imageModel) ? 'gpt-5.5' : imageModel;
  }

  static bool _shouldUseNativeGeminiImage(_ResolvedRoute route) {
    if (route.type != _ProviderType.gemini) return false;
    return looksLikeImageGenerationModel(
      id: route.modelId,
      name: route.modelId,
    );
  }

  static String _effectiveOpenAiBaseUrl(AiProvider provider) {
    return provider.baseUrl.isEmpty
        ? 'https://api.openai.com/v1'
        : provider.baseUrl;
  }

  static String _effectiveAnthropicBaseUrl(AiProvider provider) {
    return provider.baseUrl.isEmpty
        ? 'https://api.anthropic.com'
        : provider.baseUrl;
  }
}
