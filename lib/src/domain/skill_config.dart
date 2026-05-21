class SkillEntrypoint {
  const SkillEntrypoint({
    required this.id,
    required this.label,
    this.description = '',
  });

  factory SkillEntrypoint.fromJson(dynamic json) {
    final map = json is Map ? json : const {};
    final id = map['id']?.toString().trim() ?? '';
    return SkillEntrypoint(
      id: id.isEmpty ? 'default' : id,
      label: map['label']?.toString().trim().isNotEmpty == true
          ? map['label'].toString().trim()
          : id.isEmpty
          ? '默认入口'
          : id,
      description: map['description']?.toString().trim() ?? '',
    );
  }

  final String id;
  final String label;
  final String description;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'description': description,
  };
}

class SkillConfig {
  const SkillConfig({
    required this.id,
    required this.name,
    required this.description,
    required this.sourceUrl,
    this.localPath = '',
    this.enabled = true,
    this.triggers = const [],
    this.systemPrompt = '',
    this.entrypoints = const [SkillEntrypoint(id: 'default', label: '默认入口')],
    required this.createdAt,
    required this.updatedAt,
  });

  factory SkillConfig.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    final id = map['id']?.toString().trim() ?? '';
    final name = map['name']?.toString().trim() ?? '';
    if (id.isEmpty || name.isEmpty) {
      throw const FormatException('Invalid skill config.');
    }
    final createdAt =
        int.tryParse(map['createdAt']?.toString() ?? '') ??
        DateTime.now().millisecondsSinceEpoch;
    final updatedAt =
        int.tryParse(map['updatedAt']?.toString() ?? '') ?? createdAt;
    final entrypoints = (map['entrypoints'] as List? ?? const [])
        .map(SkillEntrypoint.fromJson)
        .where((entrypoint) => entrypoint.id.trim().isNotEmpty)
        .toList();
    return SkillConfig(
      id: id,
      name: name,
      description: map['description']?.toString().trim() ?? '',
      sourceUrl: map['sourceUrl']?.toString().trim() ?? '',
      localPath: map['localPath']?.toString().trim() ?? '',
      enabled: map['enabled'] != false,
      triggers: _stringList(map['triggers']),
      systemPrompt: map['systemPrompt']?.toString().trim() ?? '',
      entrypoints: entrypoints.isEmpty
          ? const [SkillEntrypoint(id: 'default', label: '默认入口')]
          : entrypoints,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  final String id;
  final String name;
  final String description;
  final String sourceUrl;
  final String localPath;
  final bool enabled;
  final List<String> triggers;
  final String systemPrompt;
  final List<SkillEntrypoint> entrypoints;
  final int createdAt;
  final int updatedAt;

  String get primaryEntrypoint =>
      entrypoints.isEmpty ? 'default' : entrypoints.first.id;

  SkillConfig copyWith({
    String? id,
    String? name,
    String? description,
    String? sourceUrl,
    String? localPath,
    bool? enabled,
    List<String>? triggers,
    String? systemPrompt,
    List<SkillEntrypoint>? entrypoints,
    int? createdAt,
    int? updatedAt,
  }) {
    return SkillConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      localPath: localPath ?? this.localPath,
      enabled: enabled ?? this.enabled,
      triggers: triggers ?? this.triggers,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      entrypoints: entrypoints ?? this.entrypoints,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'sourceUrl': sourceUrl,
    'localPath': localPath,
    'enabled': enabled,
    'triggers': triggers,
    'systemPrompt': systemPrompt,
    'entrypoints': entrypoints
        .map((entrypoint) => entrypoint.toJson())
        .toList(),
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }
}
