part of '../main.dart';

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.content,
    this.attachments = const [],
    this.reasoning = '',
    this.translation = '',
    this.isThinking = false,
  });

  factory ChatMessage.user(
    String content, {
    List<MessageAttachment> attachments = const [],
  }) => ChatMessage(role: 'user', content: content, attachments: attachments);

  factory ChatMessage.model(
    String content, {
    String reasoning = '',
    bool isThinking = false,
  }) => ChatMessage(
    role: 'model',
    content: content,
    reasoning: reasoning,
    isThinking: isThinking,
  );

  factory ChatMessage.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return ChatMessage(
      role: map['role']?.toString() == 'model' ? 'model' : 'user',
      content: map['content']?.toString() ?? '',
      reasoning: map['reasoning']?.toString() ?? '',
      translation: map['translation']?.toString() ?? '',
      attachments: (map['attachments'] as List? ?? [])
          .map(MessageAttachment.fromJson)
          .toList(),
    );
  }

  String role;
  String content;
  String reasoning;
  String translation;
  bool isThinking;
  List<MessageAttachment> attachments;

  ChatMessage copy() => ChatMessage(
    role: role,
    content: content,
    reasoning: reasoning,
    translation: translation,
    isThinking: isThinking,
    attachments: attachments.map((a) => a.copy()).toList(),
  );

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    'reasoning': reasoning,
    'translation': translation,
    'attachments': attachments.map((a) => a.toJson()).toList(),
  };
}

class MessageAttachment {
  const MessageAttachment({
    required this.path,
    required this.name,
    required this.mimeType,
    required this.kind,
    this.size,
  });

  factory MessageAttachment.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return MessageAttachment(
      path: map['path']?.toString() ?? '',
      name: map['name']?.toString() ?? '未命名文件',
      mimeType: map['mimeType']?.toString() ?? 'application/octet-stream',
      kind: map['kind']?.toString() == 'image' ? 'image' : 'file',
      size: (map['size'] as num?)?.toInt(),
    );
  }

  final String path;
  final String name;
  final String mimeType;
  final String kind;
  final int? size;

  bool get isImage => kind == 'image' || mimeType.startsWith('image/');

  MessageAttachment copy() => MessageAttachment(
    path: path,
    name: name,
    mimeType: mimeType,
    kind: kind,
    size: size,
  );

  Map<String, dynamic> toJson() => {
    'path': path,
    'name': name,
    'mimeType': mimeType,
    'kind': kind,
    'size': size,
  };
}

class ChatSession {
  const ChatSession({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.messages,
  });

  factory ChatSession.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return ChatSession(
      id: map['id']?.toString() ?? DateTime.now().toString(),
      title: map['title']?.toString() ?? '未命名梦境',
      updatedAt: (map['updatedAt'] as num?)?.toInt() ?? 0,
      messages: (map['messages'] as List? ?? [])
          .map(ChatMessage.fromJson)
          .toList(),
    );
  }

  final String id;
  final String title;
  final int updatedAt;
  final List<ChatMessage> messages;

  ChatSession copyWith({
    String? id,
    String? title,
    int? updatedAt,
    List<ChatMessage>? messages,
  }) {
    return ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'updatedAt': updatedAt,
    'messages': messages.map((m) => m.toJson()).toList(),
  };
}

class AiModel {
  const AiModel({
    required this.id,
    required this.name,
    this.capabilities = const ['chat'],
  });

  factory AiModel.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return AiModel(
      id: map['id']?.toString() ?? map['name']?.toString() ?? '',
      name: map['name']?.toString() ?? map['id']?.toString() ?? '',
      capabilities: (map['capabilities'] as List? ?? ['chat'])
          .map((item) => item.toString())
          .toList(),
    );
  }

  final String id;
  final String name;
  final List<String> capabilities;

  AiModel copyWith({String? id, String? name, List<String>? capabilities}) {
    return AiModel(
      id: id ?? this.id,
      name: name ?? this.name,
      capabilities: capabilities ?? this.capabilities,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'capabilities': capabilities,
  };
}

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
      baseUrl: rawBaseUrl.trim().isEmpty
          ? ''
          : AiGateway.normalizeBaseUrl(rawBaseUrl),
      models: _dedupeModels(
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
      models: models == null ? this.models : _dedupeModels(models),
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

List<AiModel> _dedupeModels(Iterable<AiModel> models) {
  final seen = <String>{};
  final result = <AiModel>[];
  for (final model in models) {
    final id = model.id.trim();
    final name = model.name.trim();
    if (id.isEmpty && name.isEmpty) continue;
    final key = (id.isEmpty ? name : id).toLowerCase();
    if (!seen.add(key)) continue;
    result.add(
      model.copyWith(
        id: id.isEmpty ? name : id,
        name: name.isEmpty ? id : name,
        capabilities: model.capabilities.toSet().toList(),
      ),
    );
  }
  return result;
}

class ModelAssignment {
  const ModelAssignment({
    required this.provider,
    required this.model,
    required this.prompt,
  });

  factory ModelAssignment.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return ModelAssignment(
      provider: map['provider']?.toString() ?? '',
      model: map['model']?.toString() ?? '',
      prompt: map['prompt']?.toString() ?? '',
    );
  }

  final String provider;
  final String model;
  final String prompt;

  static Map<String, ModelAssignment> defaults() {
    return const {
      'chat': ModelAssignment(
        provider: '',
        model: '',
        prompt: '你是一个有用、有条理、有创造力的人工智能助手。',
      ),
      'title': ModelAssignment(
        provider: '',
        model: '',
        prompt: '请用不超过10个字概括以下对话的核心内容，直接输出标题，不需要前缀。',
      ),
      'suggest': ModelAssignment(
        provider: '',
        model: '',
        prompt: '根据对话历史，简明扼要地提供3个用户可能想说的简短后续问题。',
      ),
      'translate': ModelAssignment(
        provider: '',
        model: '',
        prompt: '你是一个专业的翻译人员，请将输入的文本翻译成目标语言，保持原意，语言流畅。',
      ),
    };
  }

  ModelAssignment copyWith({String? provider, String? model, String? prompt}) {
    return ModelAssignment(
      provider: provider ?? this.provider,
      model: model ?? this.model,
      prompt: prompt ?? this.prompt,
    );
  }

  Map<String, dynamic> toJson() => {
    'provider': provider,
    'model': model,
    'prompt': prompt,
  };
}

class SearchConfig {
  const SearchConfig({required this.active, required this.keys});

  factory SearchConfig.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return SearchConfig(
      active: map['active']?.toString() ?? 'tavily',
      keys: (map['keys'] as Map? ?? {}).map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
    );
  }

  final String active;
  final Map<String, String> keys;

  SearchConfig copyWith({String? active, Map<String, String>? keys}) {
    return SearchConfig(active: active ?? this.active, keys: keys ?? this.keys);
  }

  Map<String, dynamic> toJson() => {'active': active, 'keys': keys};

  Map<String, dynamic> safeJson() => {
    'active': active,
    'keys': keys.map((key, value) => MapEntry(key, value.isEmpty ? '' : '***')),
  };
}

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
      baseUrl: rawBaseUrl.trim().isEmpty
          ? ''
          : AiGateway.normalizeBaseUrl(rawBaseUrl),
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
