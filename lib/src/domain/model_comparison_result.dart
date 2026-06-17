class ModelComparisonResult {
  const ModelComparisonResult({
    required this.id,
    required this.provider,
    required this.model,
    this.content = '',
    this.error = '',
    this.elapsedMs = 0,
    this.loading = false,
  });

  factory ModelComparisonResult.pending({
    required String provider,
    required String model,
  }) {
    return ModelComparisonResult(
      id: _stableId('$provider|$model'),
      provider: provider,
      model: model,
      loading: true,
    );
  }

  factory ModelComparisonResult.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return ModelComparisonResult(
      id: map['id']?.toString().trim().isNotEmpty == true
          ? map['id'].toString()
          : _stableId('${map['provider']}|${map['model']}'),
      provider: map['provider']?.toString() ?? '',
      model: map['model']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      error: map['error']?.toString() ?? '',
      elapsedMs: _intValue(map['elapsedMs']) ?? 0,
      loading: map['loading'] == true,
    );
  }

  final String id;
  final String provider;
  final String model;
  final String content;
  final String error;
  final int elapsedMs;
  final bool loading;

  bool get hasText => content.trim().isNotEmpty || error.trim().isNotEmpty;

  ModelComparisonResult copyWith({
    String? id,
    String? provider,
    String? model,
    String? content,
    String? error,
    int? elapsedMs,
    bool? loading,
  }) {
    return ModelComparisonResult(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      model: model ?? this.model,
      content: content ?? this.content,
      error: error ?? this.error,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      loading: loading ?? this.loading,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'provider': provider,
    'model': model,
    'content': content,
    'error': error,
    'elapsedMs': elapsedMs,
    'loading': loading,
  };

  static int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static String _stableId(String value) {
    final trimmed = value.trim();
    var hash = 0x811C9DC5;
    for (final unit in trimmed.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return 'compare_${hash.toRadixString(16)}';
  }
}
