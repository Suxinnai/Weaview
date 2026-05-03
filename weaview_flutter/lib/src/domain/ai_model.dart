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

List<AiModel> dedupeModels(Iterable<AiModel> models) {
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
