class MemoryItem {
  const MemoryItem({
    required this.id,
    required this.content,
    this.enabled = true,
    this.pinned = false,
    this.source = '手动添加',
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  factory MemoryItem.manual(String content) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return MemoryItem(
      id: _stableId(content, now),
      content: content.trim(),
      source: '手动添加',
      createdAt: now,
      updatedAt: now,
    );
  }

  factory MemoryItem.fromText(String content, {String source = '旧版记忆'}) {
    final trimmed = content.trim();
    final now = DateTime.now().millisecondsSinceEpoch;
    return MemoryItem(
      id: _stableId(trimmed, now),
      content: trimmed,
      source: source,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory MemoryItem.fromJson(dynamic json) {
    if (json is String) return MemoryItem.fromText(json);
    final map = json as Map<String, dynamic>;
    final content = map['content']?.toString().trim() ?? '';
    final now = DateTime.now().millisecondsSinceEpoch;
    return MemoryItem(
      id: map['id']?.toString().trim().isNotEmpty == true
          ? map['id'].toString()
          : _stableId(content, now),
      content: content,
      enabled: map['enabled'] != false,
      pinned: map['pinned'] == true,
      source: map['source']?.toString().trim().isNotEmpty == true
          ? map['source'].toString().trim()
          : '旧版记忆',
      createdAt: _intValue(map['createdAt']) ?? now,
      updatedAt: _intValue(map['updatedAt']) ?? now,
    );
  }

  final String id;
  final String content;
  final bool enabled;
  final bool pinned;
  final String source;
  final int createdAt;
  final int updatedAt;

  MemoryItem copyWith({
    String? id,
    String? content,
    bool? enabled,
    bool? pinned,
    String? source,
    int? createdAt,
    int? updatedAt,
    bool touch = false,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return MemoryItem(
      id: id ?? this.id,
      content: content ?? this.content,
      enabled: enabled ?? this.enabled,
      pinned: pinned ?? this.pinned,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? (touch ? now : this.updatedAt),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'enabled': enabled,
    'pinned': pinned,
    'source': source,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  static int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static String _stableId(String content, int fallback) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return 'memory_$fallback';
    var hash = 0x811C9DC5;
    for (final unit in trimmed.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return 'memory_${hash.toRadixString(16)}';
  }
}
