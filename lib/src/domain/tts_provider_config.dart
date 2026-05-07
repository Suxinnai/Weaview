import '../core/app_utils.dart';

class TtsProviderConfig {
  const TtsProviderConfig({
    required this.id,
    required this.type,
    required this.name,
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    required this.voice,
  });

  factory TtsProviderConfig.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    final rawBaseUrl = map['baseUrl']?.toString() ?? '';
    return TtsProviderConfig(
      id:
          map['id']?.toString() ??
          'custom_${DateTime.now().millisecondsSinceEpoch}',
      type: map['type']?.toString() ?? 'openai',
      name: map['name']?.toString() ?? '自定义 TTS',
      apiKey: map['apiKey']?.toString() ?? '',
      baseUrl: rawBaseUrl.trim().isEmpty ? '' : normalizeBaseUrl(rawBaseUrl),
      model: map['model']?.toString() ?? '',
      voice: map['voice']?.toString() ?? '',
    );
  }

  final String id;
  final String type;
  final String name;
  final String apiKey;
  final String baseUrl;
  final String model;
  final String voice;

  static List<TtsProviderConfig> defaults() {
    return const [
      TtsProviderConfig(
        id: 'openai',
        type: 'openai',
        name: 'OpenAI TTS',
        apiKey: '',
        baseUrl: 'https://api.openai.com/v1',
        model: 'gpt-4o-mini-tts',
        voice: 'alloy',
      ),
      TtsProviderConfig(
        id: 'xiaomi',
        type: 'custom',
        name: 'Xiaomi MiMo TTS',
        apiKey: '',
        baseUrl: '',
        model: '',
        voice: '',
      ),
    ];
  }

  TtsProviderConfig copyWith({
    String? id,
    String? type,
    String? name,
    String? apiKey,
    String? baseUrl,
    String? model,
    String? voice,
  }) {
    return TtsProviderConfig(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      voice: voice ?? this.voice,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'name': name,
    'apiKey': apiKey,
    'baseUrl': baseUrl,
    'model': model,
    'voice': voice,
  };

  Map<String, dynamic> safeJson() => {
    ...toJson(),
    'apiKey': apiKey.isEmpty ? '' : '***',
  };
}
