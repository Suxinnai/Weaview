class WorkCard {
  const WorkCard({
    required this.id,
    required this.title,
    required this.body,
    this.kind = 'text',
    this.sourceSessionId = '',
    this.sourceSessionTitle = '',
    this.createdAt = 0,
    this.updatedAt = 0,
    this.pinned = false,
  });

  factory WorkCard.create({
    required String title,
    required String body,
    String kind = 'text',
    String sourceSessionId = '',
    String sourceSessionTitle = '',
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return WorkCard(
      id: _stableId('$sourceSessionId|$title|$now'),
      title: title.trim().isEmpty ? '未命名作品' : title.trim(),
      body: body.trim(),
      kind: kind,
      sourceSessionId: sourceSessionId,
      sourceSessionTitle: sourceSessionTitle.trim(),
      createdAt: now,
      updatedAt: now,
    );
  }

  factory WorkCard.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    final title = map['title']?.toString().trim() ?? '未命名作品';
    final body = map['body']?.toString().trim() ?? '';
    final now = DateTime.now().millisecondsSinceEpoch;
    return WorkCard(
      id: map['id']?.toString().trim().isNotEmpty == true
          ? map['id'].toString()
          : _stableId('$title|$now'),
      title: title.isEmpty ? '未命名作品' : title,
      body: body,
      kind: map['kind']?.toString().trim().isNotEmpty == true
          ? map['kind'].toString().trim()
          : 'text',
      sourceSessionId: map['sourceSessionId']?.toString().trim() ?? '',
      sourceSessionTitle: map['sourceSessionTitle']?.toString().trim() ?? '',
      createdAt: _intValue(map['createdAt']) ?? now,
      updatedAt: _intValue(map['updatedAt']) ?? now,
      pinned: map['pinned'] == true,
    );
  }

  final String id;
  final String title;
  final String body;
  final String kind;
  final String sourceSessionId;
  final String sourceSessionTitle;
  final int createdAt;
  final int updatedAt;
  final bool pinned;

  WorkCard copyWith({
    String? id,
    String? title,
    String? body,
    String? kind,
    String? sourceSessionId,
    String? sourceSessionTitle,
    int? createdAt,
    int? updatedAt,
    bool? pinned,
    bool touch = false,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return WorkCard(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      kind: kind ?? this.kind,
      sourceSessionId: sourceSessionId ?? this.sourceSessionId,
      sourceSessionTitle: sourceSessionTitle ?? this.sourceSessionTitle,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? (touch ? now : this.updatedAt),
      pinned: pinned ?? this.pinned,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'kind': kind,
    'sourceSessionId': sourceSessionId,
    'sourceSessionTitle': sourceSessionTitle,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'pinned': pinned,
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
    return 'work_${hash.toRadixString(16)}';
  }
}
