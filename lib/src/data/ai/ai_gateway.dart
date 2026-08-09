import 'package:flutter/foundation.dart';

import '../../core/app_utils.dart' as app_utils;
import '../../domain/models.dart';
import '../search/tavily_search_client.dart';
import 'ai_response_parsers.dart';
import 'anthropic_client.dart';
import 'gemini_client.dart';
import 'image_prompt_guard.dart';
import 'native_image_provider_client.dart';
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

class GeneratedImageBatchResult {
  const GeneratedImageBatchResult({
    required this.images,
    required this.requestedCount,
    this.failedCount = 0,
  });

  final List<GeneratedImageResult> images;
  final int requestedCount;
  final int failedCount;

  bool get isPartial => images.length < requestedCount;
}

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
  static const _nativeImageClient = NativeImageProviderClient();

  // ── Routing helpers ────────────────────────────────────────────

  static _ResolvedRoute _resolveRoute({
    required AiProvider provider,
    required ModelAssignment assignment,
  }) {
    final providerName = assignment.provider.isNotEmpty
        ? assignment.provider
        : provider.name;
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
    final batch = await generateImages(
      provider: provider,
      assignment: assignment,
      prompt: prompt,
      attachments: attachments,
      size: size,
    );
    return batch.images.first;
  }

  static Future<GeneratedImageBatchResult> generateImages({
    required AiProvider provider,
    required ModelAssignment assignment,
    required String prompt,
    List<MessageAttachment> attachments = const [],
    String size = '1024x1024',
    String? aspectRatio,
    int outputCount = 1,
  }) async {
    final route = _resolveRoute(provider: provider, assignment: assignment);
    _assertApiKey(route);

    final requestedCount = outputCount.clamp(1, 4).toInt();
    final guardedPrompt = imagePromptWithDefaultQualityGuard(prompt);
    final imageApi = _effectiveImageApi(route);
    if (_usesNativeImageClient(imageApi)) {
      final images = await _nativeImageClient.generate(
        kind: imageApi,
        apiKey: route.apiKey,
        baseUrl: provider.baseUrl,
        model: route.modelId,
        prompt: guardedPrompt,
        attachments: attachments,
        timeout: imageRequestTimeout,
        outputCount: requestedCount,
        aspectRatio: aspectRatio,
        size: size,
      );
      return GeneratedImageBatchResult(
        images: images,
        requestedCount: requestedCount,
        failedCount: requestedCount - images.length,
      );
    }
    if (_shouldUseNativeGeminiImage(route)) {
      final images = await _geminiClient.generateImages(
        apiKey: route.apiKey,
        baseUrl: provider.baseUrl,
        model: route.modelId,
        prompt: guardedPrompt,
        attachments: attachments,
        timeout: imageRequestTimeout,
        outputCount: requestedCount,
        aspectRatio: _geminiAspectRatio(aspectRatio, size),
        imageSize: _geminiImageSize(route.modelId, guardedPrompt),
      );
      return GeneratedImageBatchResult(
        images: images,
        requestedCount: requestedCount,
        failedCount: requestedCount - images.length,
      );
    }

    final openAiOptions = _openAiImageOptions(
      provider: provider,
      aspectRatio: aspectRatio,
      size: size,
      prompt: guardedPrompt,
    );

    final attempts = await Future.wait([
      for (var index = 0; index < requestedCount; index++)
        _openAiClient
            .generateImage(
              apiKey: route.apiKey,
              baseUrl: route.baseUrl,
              prompt: guardedPrompt,
              attachments: attachments,
              responseModel: _responseModelForImageTool(route.modelId),
              imageModel: route.modelId,
              timeout: imageRequestTimeout,
              size: openAiOptions.size,
              imageRequestExtraBody: openAiOptions.extraBody,
              includeImageSize: openAiOptions.includeSize,
            )
            .then(
              (image) => _GeneratedImageAttempt(image: image),
              onError: (Object error, StackTrace _) =>
                  _GeneratedImageAttempt(error: error),
            ),
    ]);
    final images = [
      for (final attempt in attempts)
        if (attempt.image != null) attempt.image!,
    ];
    if (images.isEmpty) {
      final error = attempts
          .map((attempt) => attempt.error)
          .whereType<Object>()
          .firstOrNull;
      throw error ?? Exception('生图请求未返回任何图片。');
    }
    return GeneratedImageBatchResult(
      images: images,
      requestedCount: requestedCount,
      failedCount: attempts.where((attempt) => attempt.error != null).length,
    );
  }

  // ── Model fetch / test ────────────────────────────────────────

  static Future<List<AiModel>> fetchModels({
    required String apiKey,
    required String baseUrl,
    String providerName = '',
  }) async {
    final preset = _providerPreset(providerName);
    if (preset != null && _usesNativeImageClient(preset.imageApi)) {
      return preset.models;
    }
    if (_isGeminiProvider(providerName)) {
      final fetched = await _geminiClient.fetchModels(
        apiKey: apiKey,
        baseUrl: baseUrl,
        timeout: modelFetchTimeout,
      );
      return preset == null
          ? fetched
          : dedupeModels([...fetched, ...preset.models]);
    }
    final fetched = await _openAiClient.fetchModels(
      apiKey: apiKey,
      baseUrl: baseUrl,
      timeout: modelFetchTimeout,
    );
    return preset == null
        ? fetched
        : dedupeModels([...fetched, ...preset.models]);
  }

  static Future<String> testConnection({
    required String apiKey,
    required String baseUrl,
    required String model,
    Iterable<String> capabilities = const [],
    String providerName = '',
  }) async {
    if (looksLikeImageGenerationModel(
      id: model,
      name: model,
      capabilities: capabilities,
    )) {
      final preset = _providerPreset(providerName);
      final imageApi = preset?.imageApi ?? ImageApiKind.automatic;
      if (_usesNativeImageClient(imageApi)) {
        final result = await _nativeImageClient.generate(
          kind: imageApi,
          apiKey: apiKey,
          baseUrl: baseUrl,
          model: model,
          prompt:
              'Generate a tiny clean app test image: one mint dot on white.',
          timeout: imageRequestTimeout,
          outputCount: 1,
        );
        return '连接成功，生图接口响应正常：${result.first.route}';
      }
      if (_isGeminiProvider(providerName)) {
        return _geminiClient.testImageConnection(
          apiKey: apiKey,
          baseUrl: baseUrl,
          model: model,
          timeout: imageRequestTimeout,
        );
      }
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

  static ImageApiKind _effectiveImageApi(_ResolvedRoute route) {
    if (route.provider.imageApi != ImageApiKind.automatic) {
      return route.provider.imageApi;
    }
    if (route.type == _ProviderType.gemini) return ImageApiKind.gemini;
    return _providerPreset(route.provider.name)?.imageApi ??
        ImageApiKind.openAi;
  }

  static bool _usesNativeImageClient(ImageApiKind kind) {
    return kind == ImageApiKind.ark ||
        kind == ImageApiKind.stability ||
        kind == ImageApiKind.bfl ||
        kind == ImageApiKind.ideogram ||
        kind == ImageApiKind.replicate;
  }

  static AiProvider? _providerPreset(String providerName) {
    final normalized = providerName.trim().toLowerCase();
    return AiProvider.defaults().firstWhereOrNull(
      (provider) => provider.name.toLowerCase() == normalized,
    );
  }

  static ({String size, bool includeSize, Map<String, dynamic> extraBody})
  _openAiImageOptions({
    required AiProvider provider,
    required String? aspectRatio,
    required String size,
    required String prompt,
  }) {
    final name = provider.name.toLowerCase();
    if (name.contains('grok') || name.contains('xai')) {
      final wantsHighResolution =
          prompt.toLowerCase().contains('2k') ||
          prompt.toLowerCase().contains('4k');
      return (
        size: size,
        includeSize: false,
        extraBody: {
          if (aspectRatio?.trim().isNotEmpty == true)
            'aspect_ratio': aspectRatio!.trim(),
          'resolution': wantsHighResolution ? '2k' : '1k',
        },
      );
    }
    if (name.contains('recraft') && aspectRatio?.trim().isNotEmpty == true) {
      return (
        size: aspectRatio!.trim(),
        includeSize: true,
        extraBody: const {},
      );
    }
    return (size: size, includeSize: true, extraBody: const {});
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

  static String? _geminiImageSize(String modelId, String prompt) {
    final model = modelId.toLowerCase();
    if (model.contains('flash-lite-image') ||
        model.contains('2.5-flash-image')) {
      return null;
    }
    final text = prompt.toLowerCase();
    if (RegExp(r'(^|[^a-z0-9])4k([^a-z0-9]|$)').hasMatch(text) ||
        text.contains('超高清') ||
        text.contains('商业级高清')) {
      return '4K';
    }
    if (RegExp(r'(^|[^a-z0-9])2k([^a-z0-9]|$)').hasMatch(text) ||
        text.contains('高清')) {
      return '2K';
    }
    return null;
  }

  static String _geminiAspectRatio(String? requested, String size) {
    final parsed = _parseAspectRatio(requested);
    final sizeParts = size.toLowerCase().split('x');
    final sizeRatio = sizeParts.length == 2
        ? (double.tryParse(sizeParts[0]) ?? 1) /
              (double.tryParse(sizeParts[1]) ?? 1)
        : 1.0;
    final target = parsed ?? sizeRatio;
    const supported = <String, double>{
      '1:1': 1,
      '2:3': 2 / 3,
      '3:2': 3 / 2,
      '3:4': 3 / 4,
      '4:3': 4 / 3,
      '4:5': 4 / 5,
      '5:4': 5 / 4,
      '9:16': 9 / 16,
      '16:9': 16 / 9,
      '21:9': 21 / 9,
    };
    return supported.entries.reduce((best, candidate) {
      final bestDistance = (best.value - target).abs();
      final candidateDistance = (candidate.value - target).abs();
      return candidateDistance < bestDistance ? candidate : best;
    }).key;
  }

  static double? _parseAspectRatio(String? value) {
    final match = RegExp(
      r'^(\d+(?:\.\d+)?)\s*[:x×/]\s*(\d+(?:\.\d+)?)$',
    ).firstMatch(value?.trim() ?? '');
    if (match == null) return null;
    final width = double.tryParse(match.group(1) ?? '');
    final height = double.tryParse(match.group(2) ?? '');
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return width / height;
  }
}

class _GeneratedImageAttempt {
  const _GeneratedImageAttempt({this.image, this.error});

  final GeneratedImageResult? image;
  final Object? error;
}
