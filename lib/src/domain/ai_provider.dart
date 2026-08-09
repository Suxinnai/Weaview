import 'package:flutter/material.dart';

import '../core/app_utils.dart';
import 'ai_model.dart';
import 'gemini_image_models.dart';
import 'image_model_catalog.dart';

enum ImageApiKind {
  automatic,
  openAi,
  gemini,
  ark,
  stability,
  bfl,
  ideogram,
  replicate,
}

ImageApiKind imageApiKindFromName(String? value) {
  final normalized = value?.trim().toLowerCase() ?? '';
  return ImageApiKind.values.firstWhere(
    (kind) => kind.name.toLowerCase() == normalized,
    orElse: () => ImageApiKind.automatic,
  );
}

class AiProvider {
  const AiProvider({
    required this.name,
    required this.status,
    required this.current,
    required this.color,
    this.enabled = true,
    this.apiKey = '',
    this.baseUrl = '',
    this.models = const [],
    this.imageApi = ImageApiKind.automatic,
  });

  factory AiProvider.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    final name = map['name']?.toString() ?? 'Provider';
    final rawBaseUrl = map['baseUrl']?.toString() ?? '';
    return AiProvider(
      name: name,
      status: map['status']?.toString() ?? '未配置',
      current: map['current'] == true,
      enabled: map['enabled'] != false,
      color:
          colorFromHex(map['colorHex']?.toString()) ??
          providerFallbackColor(name),
      apiKey: map['apiKey']?.toString() ?? '',
      baseUrl: rawBaseUrl.trim().isEmpty ? '' : normalizeBaseUrl(rawBaseUrl),
      models: dedupeModels(
        (map['models'] as List? ?? []).map(AiModel.fromJson),
      ),
      imageApi: imageApiKindFromName(map['imageApi']?.toString()),
    );
  }

  final String name;
  final String status;
  final bool current;
  final bool enabled;
  final Color color;
  final String apiKey;
  final String baseUrl;
  final List<AiModel> models;
  final ImageApiKind imageApi;

  static List<AiProvider> defaults() {
    return const [
      AiProvider(
        name: 'OpenAI',
        status: '未配置',
        current: false,
        color: Color(0xFF10B981),
        baseUrl: 'https://api.openai.com/v1',
        models: openAiImageModels,
        imageApi: ImageApiKind.openAi,
      ),
      AiProvider(
        name: 'Gemini',
        status: '未配置',
        current: false,
        color: Color(0xFF3B82F6),
        baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
        models: geminiImageModels,
        imageApi: ImageApiKind.gemini,
      ),
      AiProvider(
        name: '火山方舟',
        status: '未配置',
        current: false,
        color: Color(0xFF3370FF),
        baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
        models: seedreamImageModels,
        imageApi: ImageApiKind.ark,
      ),
      AiProvider(
        name: 'Recraft',
        status: '未配置',
        current: false,
        color: Color(0xFF6D5DFB),
        baseUrl: 'https://external.api.recraft.ai/v1',
        models: recraftImageModels,
        imageApi: ImageApiKind.openAi,
      ),
      AiProvider(
        name: 'Stability AI',
        status: '未配置',
        current: false,
        color: Color(0xFF7A5AF8),
        baseUrl: 'https://api.stability.ai',
        models: stabilityImageModels,
        imageApi: ImageApiKind.stability,
      ),
      AiProvider(
        name: 'Black Forest Labs',
        status: '未配置',
        current: false,
        color: Color(0xFF151515),
        baseUrl: 'https://api.bfl.ai/v1',
        models: bflImageModels,
        imageApi: ImageApiKind.bfl,
      ),
      AiProvider(
        name: 'Ideogram',
        status: '未配置',
        current: false,
        color: Color(0xFF1D4ED8),
        baseUrl: 'https://api.ideogram.ai',
        models: ideogramImageModels,
        imageApi: ImageApiKind.ideogram,
      ),
      AiProvider(
        name: 'Replicate',
        status: '未配置',
        current: false,
        color: Color(0xFF111827),
        baseUrl: 'https://api.replicate.com/v1',
        models: replicateImageModels,
        imageApi: ImageApiKind.replicate,
      ),
      AiProvider(
        name: 'Anthropic',
        status: '未配置',
        current: false,
        color: Color(0xFFB45309),
        baseUrl: 'https://api.anthropic.com/v1',
      ),
      AiProvider(
        name: 'DeepSeek',
        status: '未配置',
        current: false,
        color: Color(0xFF2563EB),
        baseUrl: 'https://api.deepseek.com',
      ),
      AiProvider(
        name: 'Kimi',
        status: '未配置',
        current: false,
        color: Color(0xFF4B5563),
        baseUrl: 'https://api.moonshot.cn/v1',
      ),
      AiProvider(
        name: 'MiniMax',
        status: '未配置',
        current: false,
        color: Color(0xFF8B5CF6),
        baseUrl: 'https://api.minimaxi.com/v1',
      ),
      AiProvider(
        name: 'Grok',
        status: '未配置',
        current: false,
        color: Color(0xFF111111),
        baseUrl: 'https://api.x.ai/v1',
        models: grokImageModels,
        imageApi: ImageApiKind.openAi,
      ),
    ];
  }

  AiProvider copyWith({
    String? name,
    String? status,
    bool? current,
    bool? enabled,
    Color? color,
    String? apiKey,
    String? baseUrl,
    List<AiModel>? models,
    ImageApiKind? imageApi,
  }) {
    return AiProvider(
      name: name ?? this.name,
      status: status ?? this.status,
      current: current ?? this.current,
      enabled: enabled ?? this.enabled,
      color: color ?? this.color,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      models: models == null ? this.models : dedupeModels(models),
      imageApi: imageApi ?? this.imageApi,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'status': status,
    'current': current,
    'enabled': enabled,
    'colorHex': colorToHex(color),
    'apiKey': apiKey,
    'baseUrl': baseUrl,
    'models': models.map((m) => m.toJson()).toList(),
    'imageApi': imageApi.name,
  };

  Map<String, dynamic> safeJson() => {
    ...toJson(),
    'apiKey': apiKey.isEmpty ? '' : '***',
  };
}
