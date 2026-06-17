class TokenUsageRecord {
  const TokenUsageRecord({
    required this.id,
    required this.provider,
    required this.model,
    required this.source,
    required this.sessionId,
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    required this.estimatedCostUsd,
    required this.createdAt,
  });

  factory TokenUsageRecord.create({
    required String provider,
    required String model,
    required String source,
    required String sessionId,
    required int promptTokens,
    required int completionTokens,
    required double estimatedCostUsd,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return TokenUsageRecord(
      id: _stableId('$provider|$model|$source|$sessionId|$now'),
      provider: provider,
      model: model,
      source: source,
      sessionId: sessionId,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: promptTokens + completionTokens,
      estimatedCostUsd: estimatedCostUsd,
      createdAt: now,
    );
  }

  factory TokenUsageRecord.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    final promptTokens = _intValue(map['promptTokens']) ?? 0;
    final completionTokens = _intValue(map['completionTokens']) ?? 0;
    final totalTokens =
        _intValue(map['totalTokens']) ?? promptTokens + completionTokens;
    final createdAt =
        _intValue(map['createdAt']) ?? DateTime.now().millisecondsSinceEpoch;
    return TokenUsageRecord(
      id: map['id']?.toString().trim().isNotEmpty == true
          ? map['id'].toString()
          : _stableId('${map['provider']}|${map['model']}|$createdAt'),
      provider: map['provider']?.toString() ?? '',
      model: map['model']?.toString() ?? '',
      source: map['source']?.toString() ?? 'chat',
      sessionId: map['sessionId']?.toString() ?? '',
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: totalTokens,
      estimatedCostUsd: _doubleValue(map['estimatedCostUsd']) ?? 0,
      createdAt: createdAt,
    );
  }

  final String id;
  final String provider;
  final String model;
  final String source;
  final String sessionId;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final double estimatedCostUsd;
  final int createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'provider': provider,
    'model': model,
    'source': source,
    'sessionId': sessionId,
    'promptTokens': promptTokens,
    'completionTokens': completionTokens,
    'totalTokens': totalTokens,
    'estimatedCostUsd': estimatedCostUsd,
    'createdAt': createdAt,
  };

  static int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _doubleValue(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static String _stableId(String value) {
    final trimmed = value.trim();
    var hash = 0x811C9DC5;
    for (final unit in trimmed.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return 'usage_${hash.toRadixString(16)}';
  }
}
