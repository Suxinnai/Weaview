import 'package:flutter/material.dart';

import '../core/app_utils.dart';
import 'ai_model.dart';

class AiProvider {
  const AiProvider({
    required this.name,
    required this.status,
    required this.current,
    required this.color,
    this.apiKey = '',
    this.baseUrl = '',
    this.models = const [],
  });

  factory AiProvider.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    final name = map['name']?.toString() ?? 'Provider';
    final rawBaseUrl = map['baseUrl']?.toString() ?? '';
    return AiProvider(
      name: name,
      status: map['status']?.toString() ?? '未配置',
      current: map['current'] == true,
      color:
          colorFromHex(map['colorHex']?.toString()) ??
          providerFallbackColor(name),
      apiKey: map['apiKey']?.toString() ?? '',
      baseUrl: rawBaseUrl.trim().isEmpty ? '' : normalizeBaseUrl(rawBaseUrl),
      models: dedupeModels(
        (map['models'] as List? ?? []).map(AiModel.fromJson),
      ),
    );
  }

  final String name;
  final String status;
  final bool current;
  final Color color;
  final String apiKey;
  final String baseUrl;
  final List<AiModel> models;

  static List<AiProvider> defaults() {
    return const [
      AiProvider(
        name: 'OpenAI',
        status: '未配置',
        current: false,
        color: Color(0xFF10B981),
        baseUrl: 'https://api.openai.com/v1',
      ),
      AiProvider(
        name: 'Gemini',
        status: '未配置',
        current: false,
        color: Color(0xFF3B82F6),
      ),
      AiProvider(
        name: 'Anthropic',
        status: '未配置',
        current: false,
        color: Color(0xFFB45309),
      ),
      AiProvider(
        name: 'DeepSeek',
        status: '未配置',
        current: false,
        color: Color(0xFF2563EB),
      ),
      AiProvider(
        name: 'Kimi',
        status: '未配置',
        current: false,
        color: Color(0xFF4B5563),
      ),
      AiProvider(
        name: 'MiniMax',
        status: '未配置',
        current: false,
        color: Color(0xFF8B5CF6),
      ),
      AiProvider(
        name: 'Grok',
        status: '未配置',
        current: false,
        color: Color(0xFF111111),
      ),
    ];
  }

  AiProvider copyWith({
    String? name,
    String? status,
    bool? current,
    Color? color,
    String? apiKey,
    String? baseUrl,
    List<AiModel>? models,
  }) {
    return AiProvider(
      name: name ?? this.name,
      status: status ?? this.status,
      current: current ?? this.current,
      color: color ?? this.color,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      models: models == null ? this.models : dedupeModels(models),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'status': status,
    'current': current,
    'colorHex': colorToHex(color),
    'apiKey': apiKey,
    'baseUrl': baseUrl,
    'models': models.map((m) => m.toJson()).toList(),
  };

  Map<String, dynamic> safeJson() => {
    ...toJson(),
    'apiKey': apiKey.isEmpty ? '' : '***',
  };
}
