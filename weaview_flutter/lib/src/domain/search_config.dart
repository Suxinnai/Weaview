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
