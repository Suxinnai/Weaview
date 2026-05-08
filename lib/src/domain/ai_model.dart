import 'model_capabilities.dart';

class AiModel {
  const AiModel({
    required this.id,
    required this.name,
    this.capabilities = const ['chat'],
  });

  factory AiModel.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    final id = map['id']?.toString() ?? map['name']?.toString() ?? '';
    final name = map['name']?.toString() ?? id;
    return AiModel(
      id: id,
      name: name,
      capabilities: modelCapabilitiesFromRecord({
        ...map,
        'id': id,
        'name': name,
      }),
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
        capabilities: normalizeModelCapabilities(model.capabilities),
      ),
    );
  }
  return result;
}
